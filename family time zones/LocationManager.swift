import Foundation
import CoreLocation
import Contacts
import ContactsUI
import MapKit
import UIKit
import CloudKit

struct IncomingInvitation: Identifiable, Codable {
    let id: String
    let inviterDisplayName: String
    let createdAt: Date
}

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

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var currentLocation: CLLocation?
    @Published var errorMessage: String?
    @Published var permissionStatus: CLAuthorizationStatus = .notDetermined
    @Published var locationSharedContacts: [SharedLocationContact] = []
    @Published var isLocationServicesEnabled: Bool = false
    /// Incoming location-sharing requests found in CloudKit for this user's email.
    @Published var incomingInvitations: [IncomingInvitation] = []

    private let locationManager = CLLocationManager()
    private var locationInvitations: [LocationSharingInvitation] = []
    private static let inboundInviteeIdsKey = "inboundInviteeInvitationIds"
    private static let lastPublishedInboundTZKey = "lastPublishedInboundDeviceTZ"
    private static let respondedInvitationIdsKey = "respondedInvitationIds"
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
        checkForIncomingInvitations()
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

    // MARK: - Sending invitations (inviter side)

    func sendLocationSharingInvitation(contact: CNContact) {
        guard let rawPhone = Self.preferredPhone(from: contact) else {
            errorMessage = "This contact doesn't have a phone number. Add one in Contacts first."
            return
        }

        let normalized = CloudKitInvitationSync.normalizePhone(rawPhone)
        guard !normalized.isEmpty else {
            errorMessage = "Could not read a phone number for this contact."
            return
        }

        let contactFullName = "\(contact.givenName) \(contact.familyName)".trimmingCharacters(in: .whitespaces)
        let invitation = LocationSharingInvitation(
            id: UUID().uuidString,
            contactName: contactFullName.isEmpty ? rawPhone : contactFullName,
            contactEmail: normalized   // stored in contactEmail field for compatibility
        )

        locationInvitations.append(invitation)
        saveInvitations()
        startCloudPollingIfNeeded()

        let myName = UserDefaults.standard.string(forKey: "myDisplayName") ?? UIDevice.current.name
        CloudKitInvitationSync.shared.uploadInvitation(
            id: invitation.id,
            inviterDisplayName: myName,
            inviteePhone: normalized
        ) { [weak self] error in
            if let error {
                self?.errorMessage = "Could not send request: \(error.localizedDescription)"
            }
        }
    }

    /// Returns the best available phone number from a contact (mobile preferred).
    private static func preferredPhone(from contact: CNContact) -> String? {
        guard !contact.phoneNumbers.isEmpty else { return nil }
        let preferred = contact.phoneNumbers.first {
            $0.label == CNLabelPhoneNumberiPhone || $0.label == CNLabelPhoneNumberMobile
        }
        return (preferred ?? contact.phoneNumbers.first)?.value.stringValue
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

    func getDeclinedInvitations() -> [LocationSharingInvitation] {
        locationInvitations.filter { $0.invitationStatus == .declined }
    }

    // MARK: - Incoming invitations (invitee side)

    /// Queries CloudKit for invitations addressed to the user's registered phone number.
    /// Requires a Queryable index on `inviteePhone` in CloudKit Dashboard for the Invitation record type.
    func checkForIncomingInvitations() {
        let raw = UserDefaults.standard.string(forKey: "myPhoneNumber") ?? ""
        let myPhone = CloudKitInvitationSync.normalizePhone(raw)
        guard !myPhone.isEmpty else { return }

        let responded = UserDefaults.standard.stringArray(forKey: Self.respondedInvitationIdsKey) ?? []

        CloudKitInvitationSync.shared.fetchIncomingInvitations(forPhone: myPhone) { [weak self] records, _ in
            guard let self else { return }
            let pending = records
                .filter { !responded.contains($0.recordID.recordName) }
                .map { record -> IncomingInvitation in
                    IncomingInvitation(
                        id: record.recordID.recordName,
                        inviterDisplayName: (record["inviterDisplayName"] as? String) ?? "Someone",
                        createdAt: (record["createdAt"] as? Date) ?? record.creationDate ?? Date()
                    )
                }
                .sorted { $0.createdAt < $1.createdAt }
            DispatchQueue.main.async {
                self.incomingInvitations = pending
            }
        }
    }

    func acceptIncomingInvitation(id: String) {
        let tz = TimeZone.current.identifier
        CloudKitInvitationSync.shared.uploadReply(
            invitationId: id,
            location: currentLocation,
            timeZoneIdentifier: tz
        ) { [weak self] error in
            guard let self, error == nil else { return }
            self.registerInboundInvitee(id: id)
            self.markInvitationResponded(id: id)
            UserDefaults.standard.removeObject(forKey: Self.lastPublishedInboundTZKey)
            self.publishInboundTimeZoneToCloudIfChanged(tz, location: self.currentLocation)
        }
    }

    func declineIncomingInvitation(id: String) {
        CloudKitInvitationSync.shared.uploadDeclineReply(invitationId: id) { [weak self] _ in
            self?.markInvitationResponded(id: id)
        }
    }

    private func markInvitationResponded(id: String) {
        var responded = UserDefaults.standard.stringArray(forKey: Self.respondedInvitationIdsKey) ?? []
        if !responded.contains(id) { responded.append(id) }
        UserDefaults.standard.set(responded, forKey: Self.respondedInvitationIdsKey)
        DispatchQueue.main.async {
            self.incomingInvitations.removeAll { $0.id == id }
        }
    }

    // MARK: - CloudKit polling (inviter side)

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
        for invitation in locationInvitations where invitation.invitationStatus == .pending {
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

        // Check if invitee declined
        if (best["replyStatus"] as? String) == "declined" {
            locationInvitations[index].invitationStatus = .declined
            saveInvitations()
            updateSharedLocationContacts()
            return
        }

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
}
