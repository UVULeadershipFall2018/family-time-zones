import Foundation
import CoreLocation
import Contacts
import ContactsUI
import MapKit
import MessageUI
import UIKit
import CloudKit

/// Local invitation row; `remoteTimeZoneIdentifier` is merged from CloudKit replies on the inviter's device.
class LocationSharingInvitation: Identifiable, Codable {
    var id: String
    var contactName: String
    var contactEmail: String
    var invitationStatus: InvitationStatus
    var lastLocationUpdate: Date?
    var lastKnownLocation: LocationData?
    /// Latest IANA time zone from invitee's CloudKit reply (inviter side).
    var remoteTimeZoneIdentifier: String?

    enum InvitationStatus: String, Codable {
        case pending
        case accepted
        case declined
    }

    struct LocationData: Codable {
        let latitude: Double
        let longitude: Double

        func toCLLocation() -> CLLocation {
            CLLocation(latitude: latitude, longitude: longitude)
        }
    }

    init(id: String, contactName: String, contactEmail: String) {
        self.id = id
        self.contactName = contactName
        self.contactEmail = contactEmail
        self.invitationStatus = .pending
        self.remoteTimeZoneIdentifier = nil
    }
}

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate, MFMessageComposeViewControllerDelegate {
    @Published var currentLocation: CLLocation?
    @Published var errorMessage: String?
    @Published var permissionStatus: CLAuthorizationStatus = .notDetermined
    @Published var locationSharedContacts: [SharedLocationContact] = []
    @Published var isLocationServicesEnabled: Bool = false

    private let locationManager = CLLocationManager()
    private var locationInvitations: [LocationSharingInvitation] = []
    private static let inboundInviteeIdsKey = "inboundInviteeInvitationIds"
    private static let lastPublishedInboundTZKey = "lastPublishedInboundDeviceTZ"
    private var cloudPollTimer: Timer?
    private var timeZoneChangeObserver: NSObjectProtocol?
    private var lastInboundGeocodeAt: Date?

    static let shared = LocationManager()

    struct SharedLocationContact: Identifiable {
        var id: String
        var name: String
        var email: String
        var lastLocation: CLLocation?
        var lastUpdated: Date?
        var resolvedTimeZoneIdentifier: String?

        var timeZone: TimeZone? {
            if let rid = resolvedTimeZoneIdentifier, let tz = TimeZone(identifier: rid) { return tz }
            if let location = lastLocation { return LocationManager.lookupTimeZone(for: location) }
            return nil
        }

        init(
            id: String,
            name: String,
            email: String,
            lastLocation: CLLocation? = nil,
            lastUpdated: Date? = nil,
            resolvedTimeZoneIdentifier: String? = nil
        ) {
            self.id = id
            self.name = name
            self.email = email
            self.lastLocation = lastLocation
            self.lastUpdated = lastUpdated
            self.resolvedTimeZoneIdentifier = resolvedTimeZoneIdentifier
        }
    }

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyReduced
        locationManager.allowsBackgroundLocationUpdates = false
        locationManager.pausesLocationUpdatesAutomatically = false
        locationManager.activityType = .other

        timeZoneChangeObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name.NSSystemTimeZoneDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.publishInboundTimeZoneToCloudIfChanged(TimeZone.current.identifier, location: self?.currentLocation)
        }

        checkLocationServicesStatus()
        loadSavedInvitations()
        startCloudPollingIfNeeded()
    }

    deinit {
        if let timeZoneChangeObserver {
            NotificationCenter.default.removeObserver(timeZoneChangeObserver)
        }
    }

    func handleAppBecameActive() {
        pollCloudKitInvitations()
        publishInboundTimeZoneToCloudIfChanged(TimeZone.current.identifier, location: currentLocation)
    }

    func checkLocationServicesStatus() {
        DispatchQueue.global().async { [weak self] in
            guard let self else { return }
            if CLLocationManager.locationServicesEnabled() {
                DispatchQueue.main.async {
                    self.isLocationServicesEnabled = true
                    let status = self.locationManager.authorizationStatus
                    self.permissionStatus = status
                    if status == .authorizedWhenInUse || status == .authorizedAlways {
                        self.locationManager.allowsBackgroundLocationUpdates = (status == .authorizedAlways)
                        self.startLocationUpdates()
                    }
                }
            } else {
                DispatchQueue.main.async {
                    self.isLocationServicesEnabled = false
                    self.errorMessage = "Location services are disabled on this device. Please enable them in Settings."
                }
            }
        }
    }

    func requestLocationPermission() {
        locationManager.requestAlwaysAuthorization()
    }

    func requestAlwaysPermission() {
        locationManager.requestAlwaysAuthorization()
    }

    func startLocationUpdates() {
        locationManager.allowsBackgroundLocationUpdates = (permissionStatus == .authorizedAlways)
        locationManager.startUpdatingLocation()
        if CLLocationManager.significantLocationChangeMonitoringAvailable() {
            locationManager.startMonitoringSignificantLocationChanges()
        }
        handleAppBecameActive()
    }

    func stopLocationUpdates() {
        locationManager.stopUpdatingLocation()
        if CLLocationManager.significantLocationChangeMonitoringAvailable() {
            locationManager.stopMonitoringSignificantLocationChanges()
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        permissionStatus = manager.authorizationStatus
        switch permissionStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.allowsBackgroundLocationUpdates = (permissionStatus == .authorizedAlways)
            locationManager.startUpdatingLocation()
            refreshSharedLocationContacts()
        case .denied:
            locationManager.allowsBackgroundLocationUpdates = false
            errorMessage = "Location permission denied. Please enable location access in Settings to use this feature."
        case .restricted:
            locationManager.allowsBackgroundLocationUpdates = false
            errorMessage = "Location access is restricted, possibly due to parental controls."
        case .notDetermined:
            locationManager.allowsBackgroundLocationUpdates = false
        @unknown default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        currentLocation = location
        maybeGeocodeAndPublishInboundTimeZone(from: location)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        errorMessage = error.localizedDescription
    }

    func refreshSharedLocationContacts() {
        updateSharedLocationContacts()
    }

    // MARK: - Time zone for contacts

    func updateTimeZoneForContact(_ contact: Contact) -> Contact? {
        guard contact.useLocationTracking else { return nil }
        let email = contact.appleIdEmail?.lowercased() ?? ""
        let phoneDigits = Self.digitsOnly(contact.phoneNumber)

        guard let shared = locationSharedContacts.first(where: { sc in
            let se = sc.email.lowercased()
            if !email.isEmpty, se == email { return true }
            if !phoneDigits.isEmpty, Self.digitsOnly(sc.email) == phoneDigits { return true }
            return false
        }), let timeZone = shared.timeZone else { return nil }

        var updatedContact = contact
        updatedContact.timeZoneIdentifier = timeZone.identifier
        updatedContact.lastLocationUpdate = shared.lastUpdated ?? Date()
        return updatedContact
    }

    static func lookupTimeZone(for location: CLLocation) -> TimeZone? {
        if location.coordinate.longitude < -30 {
            if location.coordinate.longitude < -115 { return TimeZone(identifier: "America/Los_Angeles") }
            if location.coordinate.longitude < -90 { return TimeZone(identifier: "America/Denver") }
            if location.coordinate.longitude < -75 { return TimeZone(identifier: "America/Chicago") }
            return TimeZone(identifier: "America/New_York")
        }
        if location.coordinate.longitude > 100 {
            if location.coordinate.longitude > 135 { return TimeZone(identifier: "Asia/Tokyo") }
            return TimeZone(identifier: "Asia/Shanghai")
        }
        if location.coordinate.longitude > 0 { return TimeZone(identifier: "Europe/London") }
        return TimeZone.current
    }

    func getTimeZoneWithGeocoder(for location: CLLocation, completion: @escaping (TimeZone?) -> Void) {
        let geocoder = CLGeocoder()
        geocoder.reverseGeocodeLocation(location) { placemarks, error in
            if error != nil {
                completion(nil)
                return
            }
            completion(placemarks?.first?.timeZone)
        }
    }

    func lookupTimeZoneFromCurrentLocation(completion: @escaping (String?) -> Void) {
        guard let currentLocation else {
            completion(nil)
            return
        }
        fallbackTimeZoneLookup(for: currentLocation, completion: completion)
    }

    private func fallbackTimeZoneLookup(for location: CLLocation, completion: @escaping (String?) -> Void) {
        let geocoder = CLGeocoder()
        geocoder.reverseGeocodeLocation(location) { placemarks, error in
            if error != nil {
                completion(nil)
                return
            }
            completion(placemarks?.first?.timeZone?.identifier)
        }
    }

    func lookupTimeZoneFromLocation(_ location: CLLocation, completion: @escaping (String?) -> Void) {
        fallbackTimeZoneLookup(for: location, completion: completion)
    }

    // MARK: - Invitations

    func sendLocationSharingInvitation(contact: CNContact) {
        let rawEmail = (contact.emailAddresses.first?.value as String?)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let phone = Self.preferredSMSPhone(from: contact)
        guard !rawEmail.isEmpty || phone != nil else {
            errorMessage = "Add an email or phone number to this contact to send an invite."
            return
        }

        let rowEmail = rawEmail.isEmpty ? (phone ?? "") : rawEmail

        let invitation = LocationSharingInvitation(
            id: UUID().uuidString,
            contactName: "\(contact.givenName) \(contact.familyName)",
            contactEmail: rowEmail
        )

        locationInvitations.append(invitation)
        saveInvitations()
        startCloudPollingIfNeeded()

        let displayName = invitation.contactName.trimmingCharacters(in: .whitespacesAndNewlines)
        CloudKitInvitationSync.shared.uploadInvitation(
            id: invitation.id,
            inviterDisplayName: displayName.isEmpty ? "Friend" : displayName,
            inviteeEmail: rawEmail.isEmpty ? "" : rawEmail
        ) { [weak self] error in
            guard let self else { return }
            if let error {
                self.errorMessage = "Could not sync invitation to iCloud: \(error.localizedDescription)"
                self.presentInvitationShareFallback(messageBody: self.invitationMessageBody(for: invitation))
                return
            }
            self.startCloudPollingIfNeeded()
            self.presentPrefilledInvitationMessages(to: invitation, contact: contact)
        }
    }

    private func invitationMessageBody(for invitation: LocationSharingInvitation) -> String {
        let appScheme = "familytimezones://"
        let invitationParameter = "invitation=\(invitation.id)"
        let deepLinkURLString = "\(appScheme)accept?\(invitationParameter)"
        return """
        Hi — I’m using Family Time Zones so you can see my local time.

        1) Tap this link once (Family Time Zones must be installed; stay signed into iCloud):
        \(deepLinkURLString)

        That’s it. Your time zone updates sync when it changes — no need to paste anything in the app.
        """
    }

    /// After CloudKit succeeds: open Messages with text ready (user taps Send). Otherwise share sheet.
    private func presentPrefilledInvitationMessages(to invitation: LocationSharingInvitation, contact: CNContact) {
        let messageBody = invitationMessageBody(for: invitation)
        let smsRecipient = Self.preferredSMSPhone(from: contact)

        if MFMessageComposeViewController.canSendText() {
            let compose = MFMessageComposeViewController()
            compose.messageComposeDelegate = self
            if let smsRecipient {
                compose.recipients = [smsRecipient]
            }
            compose.body = messageBody
            guard let host = topPresentingViewController() else {
                presentInvitationShareFallback(messageBody: messageBody)
                return
            }
            host.present(compose, animated: true)
            return
        }

        presentInvitationShareFallback(messageBody: messageBody)
    }

    private func presentInvitationShareFallback(messageBody: String) {
        guard let host = topPresentingViewController() else { return }
        let activityVC = UIActivityViewController(activityItems: [messageBody], applicationActivities: nil)
        host.present(activityVC, animated: true)
    }

    private func topPresentingViewController() -> UIViewController? {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController
                ?? scene.windows.first?.rootViewController else {
            return nil
        }
        return Self.topMostViewController(from: root)
    }

    private static func topMostViewController(from vc: UIViewController) -> UIViewController {
        if let presented = vc.presentedViewController {
            return topMostViewController(from: presented)
        }
        if let nav = vc as? UINavigationController, let visible = nav.visibleViewController {
            return topMostViewController(from: visible)
        }
        if let tab = vc as? UITabBarController, let selected = tab.selectedViewController {
            return topMostViewController(from: selected)
        }
        return vc
    }

    private static func preferredSMSPhone(from contact: CNContact) -> String? {
        guard !contact.phoneNumbers.isEmpty else { return nil }
        for labeled in contact.phoneNumbers {
            let label = labeled.label
            if label == CNLabelPhoneNumberiPhone || label == CNLabelPhoneNumberMobile {
                return labeled.value.stringValue
            }
        }
        return contact.phoneNumbers.first?.value.stringValue
    }

    private static func digitsOnly(_ string: String) -> String {
        string.filter(\.isNumber)
    }

    func loadSavedInvitations() {
        if let data = UserDefaults.standard.data(forKey: "locationSharingInvitations") {
            do {
                locationInvitations = try JSONDecoder().decode([LocationSharingInvitation].self, from: data)
                updateSharedLocationContacts()
            } catch {
                print("Error loading invitations: \(error.localizedDescription)")
            }
        }
        startCloudPollingIfNeeded()
    }

    private func saveInvitations() {
        if let data = try? JSONEncoder().encode(locationInvitations) {
            UserDefaults.standard.set(data, forKey: "locationSharingInvitations")
        }
    }

    func updateInvitationStatus(id: String, status: LocationSharingInvitation.InvitationStatus) {
        if let index = locationInvitations.firstIndex(where: { $0.id == id }) {
            locationInvitations[index].invitationStatus = status
            saveInvitations()
            updateSharedLocationContacts()
        }
    }

    func updateContactLocation(id: String, location: CLLocation) {
        if let index = locationInvitations.firstIndex(where: { $0.id == id }) {
            locationInvitations[index].lastLocationUpdate = Date()
            locationInvitations[index].lastKnownLocation = LocationSharingInvitation.LocationData(
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude
            )
            saveInvitations()
            updateSharedLocationContacts()
        }
    }

    private func updateSharedLocationContacts() {
        let acceptedContacts = locationInvitations
            .filter {
                $0.invitationStatus == .accepted
                    && ($0.lastKnownLocation != nil || !($0.remoteTimeZoneIdentifier ?? "").isEmpty)
            }
            .map { invitation -> SharedLocationContact in
                SharedLocationContact(
                    id: invitation.id,
                    name: invitation.contactName,
                    email: invitation.contactEmail,
                    lastLocation: invitation.lastKnownLocation?.toCLLocation(),
                    lastUpdated: invitation.lastLocationUpdate,
                    resolvedTimeZoneIdentifier: invitation.remoteTimeZoneIdentifier
                )
            }

        DispatchQueue.main.async {
            self.locationSharedContacts = acceptedContacts
        }
    }

    func getPendingInvitations() -> [LocationSharingInvitation] {
        locationInvitations.filter { $0.invitationStatus == .pending }
    }

    func getAcceptedInvitations() -> [LocationSharingInvitation] {
        locationInvitations.filter { $0.invitationStatus == .accepted }
    }

    // MARK: - CloudKit (inviter pull)

    private func inboundInviteeIds() -> [String] {
        UserDefaults.standard.stringArray(forKey: Self.inboundInviteeIdsKey) ?? []
    }

    private func registerInboundInvitee(id: String) {
        var ids = inboundInviteeIds()
        if !ids.contains(id) {
            ids.append(id)
            UserDefaults.standard.set(ids, forKey: Self.inboundInviteeIdsKey)
        }
        startCloudPollingIfNeeded()
    }

    func startCloudPollingIfNeeded() {
        cloudPollTimer?.invalidate()
        cloudPollTimer = nil
        let hasOutbound = !locationInvitations.isEmpty
        let hasInbound = !inboundInviteeIds().isEmpty
        guard hasOutbound || hasInbound else { return }
        cloudPollTimer = Timer.scheduledTimer(withTimeInterval: 120, repeats: true) { [weak self] _ in
            self?.pollCloudKitInvitations()
        }
        if let timer = cloudPollTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    func pollCloudKitInvitations() {
        for invitation in locationInvitations {
            let id = invitation.id
            CloudKitInvitationSync.shared.fetchReplies(invitationId: id) { [weak self] records, error in
                guard let self else { return }
                if let error {
                    print("CloudKit fetchReplies: \(error.localizedDescription)")
                    return
                }
                self.applyRepliesToLocalInvitation(invitationId: id, replies: records)
            }
        }
    }

    private func applyRepliesToLocalInvitation(invitationId: String, replies: [CKRecord]) {
        guard let index = locationInvitations.firstIndex(where: { $0.id == invitationId }) else { return }
        guard let best = replies.max(by: { replyDate($0) < replyDate($1) }) else { return }

        let tzRaw = (best["timeZoneIdentifier"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let lat = (best["latitude"] as? NSNumber)?.doubleValue
        let lon = (best["longitude"] as? NSNumber)?.doubleValue
        guard !tzRaw.isEmpty || (lat != nil && lon != nil) else { return }

        let when = replyDate(best)
        var inv = locationInvitations[index]
        inv.invitationStatus = .accepted
        if !tzRaw.isEmpty {
            inv.remoteTimeZoneIdentifier = tzRaw
        }
        if let lat, let lon {
            inv.lastKnownLocation = LocationSharingInvitation.LocationData(latitude: lat, longitude: lon)
        }
        inv.lastLocationUpdate = when
        locationInvitations[index] = inv
        saveInvitations()
        updateSharedLocationContacts()
    }

    private func replyDate(_ record: CKRecord) -> Date {
        (record["updatedAt"] as? Date) ?? record.modificationDate ?? .distantPast
    }

    // MARK: - Invitee: publish time zone only when it changes

    private func publishInboundTimeZoneToCloudIfChanged(_ timeZoneIdentifier: String, location: CLLocation?) {
        let ids = inboundInviteeIds()
        guard !ids.isEmpty else { return }
        let last = UserDefaults.standard.string(forKey: Self.lastPublishedInboundTZKey)
        guard last != timeZoneIdentifier else { return }

        let group = DispatchGroup()
        var failed = false
        for id in ids {
            group.enter()
            CloudKitInvitationSync.shared.uploadReply(
                invitationId: id,
                location: location,
                timeZoneIdentifier: timeZoneIdentifier
            ) { error in
                if error != nil { failed = true }
                group.leave()
            }
        }
        group.notify(queue: .main) {
            if !failed {
                UserDefaults.standard.set(timeZoneIdentifier, forKey: Self.lastPublishedInboundTZKey)
            }
        }
    }

    private func maybeGeocodeAndPublishInboundTimeZone(from location: CLLocation) {
        guard !inboundInviteeIds().isEmpty else { return }
        let now = Date()
        if let last = lastInboundGeocodeAt, now.timeIntervalSince(last) < 120 { return }
        lastInboundGeocodeAt = now

        lookupTimeZoneFromLocation(location) { [weak self] tzId in
            guard let self, let tzId else { return }
            self.publishInboundTimeZoneToCloudIfChanged(tzId, location: location)
        }
    }

    // MARK: - Deep link

    func handleInvitationDeepLink(url: URL) -> Bool {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
              components.scheme == "familytimezones",
              components.host == "accept",
              let invitationID = components.queryItems?.first(where: { $0.name == "invitation" })?.value else {
            return false
        }

        CloudKitInvitationSync.shared.fetchInvitation(id: invitationID) { [weak self] record, error in
            guard let self else { return }
            if record == nil || error != nil {
                DispatchQueue.main.async {
                    self.errorMessage = "Invitation not found. Ask them to resend after you’re signed into iCloud."
                }
                return
            }
            let tz = TimeZone.current.identifier
            CloudKitInvitationSync.shared.uploadReply(
                invitationId: invitationID,
                location: self.currentLocation,
                timeZoneIdentifier: tz
            ) { err in
                DispatchQueue.main.async {
                    if let err {
                        self.errorMessage = "Could not connect: \(err.localizedDescription)"
                        return
                    }
                    UserDefaults.standard.removeObject(forKey: Self.lastPublishedInboundTZKey)
                    self.registerInboundInvitee(id: invitationID)
                    if self.locationInvitations.contains(where: { $0.id == invitationID }) {
                        self.updateInvitationStatus(id: invitationID, status: .accepted)
                        if let loc = self.currentLocation {
                            self.updateContactLocation(id: invitationID, location: loc)
                        }
                    }
                    self.publishInboundTimeZoneToCloudIfChanged(tz, location: self.currentLocation)
                    NotificationCenter.default.post(name: .locationSharingInvitationHandled, object: nil)
                }
            }
        }

        return true
    }

    func messageComposeViewController(_ controller: MFMessageComposeViewController, didFinishWith result: MessageComposeResult) {
        controller.dismiss(animated: true)
    }
}
