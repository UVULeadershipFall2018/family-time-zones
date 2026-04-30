import Foundation
import CoreLocation
import Contacts
import ContactsUI
import MapKit
import MessageUI
import UIKit

// Friend locations: v1 uses on-device invitation state only (no Find My API). See README "Location sharing".
class LocationSharingInvitation: Identifiable, Codable {
    var id: String
    var contactName: String
    var contactEmail: String
    var invitationStatus: InvitationStatus
    var lastLocationUpdate: Date?
    var lastKnownLocation: LocationData?
    
    enum InvitationStatus: String, Codable {
        case pending
        case accepted
        case declined
    }
    
    struct LocationData: Codable {
        let latitude: Double
        let longitude: Double
        
        func toCLLocation() -> CLLocation {
            return CLLocation(latitude: latitude, longitude: longitude)
        }
    }
    
    init(id: String, contactName: String, contactEmail: String) {
        self.id = id
        self.contactName = contactName
        self.contactEmail = contactEmail
        self.invitationStatus = .pending
    }
}

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var currentLocation: CLLocation?
    @Published var errorMessage: String?
    @Published var permissionStatus: CLAuthorizationStatus = .notDetermined
    @Published var locationSharedContacts: [SharedLocationContact] = []
    @Published var isLocationServicesEnabled: Bool = false
    
    private let locationManager = CLLocationManager()
    private var locationInvitations: [LocationSharingInvitation] = []
    
    // Create a shared instance for deep linking
    static let shared = LocationManager()
    
    // Object to store contact details with shared location
    struct SharedLocationContact: Identifiable {
        var id: String
        var name: String
        var email: String
        var lastLocation: CLLocation?
        var timeZone: TimeZone?
        var lastUpdated: Date?
        
        init(id: String, name: String, email: String, lastLocation: CLLocation? = nil, lastUpdated: Date? = nil) {
            self.id = id
            self.name = name
            self.email = email
            self.lastLocation = lastLocation
            self.lastUpdated = lastUpdated
            
            // Try to determine time zone from location
            if let location = lastLocation {
                self.timeZone = LocationManager.lookupTimeZone(for: location)
            }
        }
    }
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyReduced
        
        locationManager.allowsBackgroundLocationUpdates = false
        locationManager.pausesLocationUpdatesAutomatically = false
        
        // Set location activity type for better location services
        locationManager.activityType = .other
        
        checkLocationServicesStatus()
        loadSavedInvitations()
    }
    
    // Check if location services are enabled and authorized
    func checkLocationServicesStatus() {
        // Perform authorization check on a background thread
        DispatchQueue.global().async { [weak self] in
            guard let self = self else { return }
            
            // First check if location services are enabled at the device level
            if CLLocationManager.locationServicesEnabled() {
                DispatchQueue.main.async {
                    self.isLocationServicesEnabled = true
                    
                    // Then check the authorization status for this app
                    let status = self.locationManager.authorizationStatus
                    self.permissionStatus = status
                    
                    // If already authorized, start location updates
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
    
    // Request location permissions
    func requestLocationPermission() {
        // Always request the highest level of permissions first
        locationManager.requestAlwaysAuthorization()
    }
    
    // Request "always" permission after "when in use" is granted
    func requestAlwaysPermission() {
        locationManager.requestAlwaysAuthorization()
    }
    
    // Start monitoring user's location
    func startLocationUpdates() {
        locationManager.allowsBackgroundLocationUpdates = (permissionStatus == .authorizedAlways)
        locationManager.startUpdatingLocation()
        
        // Also start significant location change monitoring for background updates
        if CLLocationManager.significantLocationChangeMonitoringAvailable() {
            locationManager.startMonitoringSignificantLocationChanges()
        }
    }
    
    // Stop monitoring user's location
    func stopLocationUpdates() {
        locationManager.stopUpdatingLocation()
        
        // Also stop significant location monitoring
        if CLLocationManager.significantLocationChangeMonitoringAvailable() {
            locationManager.stopMonitoringSignificantLocationChanges()
        }
    }
    
    // MARK: - CLLocationManagerDelegate methods
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        permissionStatus = manager.authorizationStatus
        
        switch permissionStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            print("Location authorization granted: \(permissionStatus.rawValue)")
            locationManager.allowsBackgroundLocationUpdates = (permissionStatus == .authorizedAlways)
            locationManager.startUpdatingLocation()
            refreshSharedLocationContacts()
        case .denied:
            locationManager.allowsBackgroundLocationUpdates = false
            errorMessage = "Location permission denied. Please enable location access in Settings to use this feature."
            print("Location permission denied")
        case .restricted:
            locationManager.allowsBackgroundLocationUpdates = false
            errorMessage = "Location access is restricted, possibly due to parental controls."
            print("Location access restricted")
        case .notDetermined:
            locationManager.allowsBackgroundLocationUpdates = false
            print("Location permission not determined yet")
        @unknown default:
            print("Unknown authorization status")
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.last {
            currentLocation = location
            print("Got user's current location: \(location.coordinate.latitude), \(location.coordinate.longitude)")
            
            // Try to determine the time zone from the current location
            if let timeZone = LocationManager.lookupTimeZone(for: location) {
                print("Determined time zone: \(timeZone.identifier)")
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        errorMessage = error.localizedDescription
        print("Location error: \(error.localizedDescription)")
    }
    
    func refreshSharedLocationContacts() {
        updateSharedLocationContacts()
    }
    
    // MARK: - Time Zone Lookup
    
    /// Uses `locationSharedContacts` (invitation / on-device list), not Apple Find My.
    func updateTimeZoneForContact(_ contact: Contact) -> Contact? {
        guard contact.useLocationTracking,
              let email = contact.appleIdEmail?.lowercased(), !email.isEmpty else {
            return nil
        }
        
        guard let shared = locationSharedContacts.first(where: { $0.email.lowercased() == email }),
              let timeZone = shared.timeZone else {
            return nil
        }
        
        var updatedContact = contact
        updatedContact.timeZoneIdentifier = timeZone.identifier
        updatedContact.lastLocationUpdate = shared.lastUpdated ?? Date()
        return updatedContact
    }
    
    /// Coarse fallback when geocoding is not available (e.g. sync UI). Prefer `lookupTimeZoneFromLocation`.
    static func lookupTimeZone(for location: CLLocation) -> TimeZone? {
        if location.coordinate.longitude < -30 {
            if location.coordinate.longitude < -115 {
                return TimeZone(identifier: "America/Los_Angeles")
            } else if location.coordinate.longitude < -90 {
                return TimeZone(identifier: "America/Denver")
            } else if location.coordinate.longitude < -75 {
                return TimeZone(identifier: "America/Chicago")
            } else {
                return TimeZone(identifier: "America/New_York")
            }
        } else if location.coordinate.longitude > 100 {
            if location.coordinate.longitude > 135 {
                return TimeZone(identifier: "Asia/Tokyo")
            } else {
                return TimeZone(identifier: "Asia/Shanghai")
            }
        } else if location.coordinate.longitude > 0 {
            return TimeZone(identifier: "Europe/London")
        }
        
        return TimeZone.current
    }
    
    func getTimeZoneWithGeocoder(for location: CLLocation, completion: @escaping (TimeZone?) -> Void) {
        let geocoder = CLGeocoder()
        
        geocoder.reverseGeocodeLocation(location) { (placemarks, error) in
            if let error = error {
                print("Geocoding error: \(error.localizedDescription)")
                completion(nil)
                return
            }
            
            if let placemark = placemarks?.first, let timeZone = placemark.timeZone {
                print("Geocoder determined time zone: \(timeZone.identifier)")
                completion(timeZone)
            } else {
                print("Could not determine time zone from location")
                completion(nil)
            }
        }
    }
    
    func lookupTimeZoneFromCurrentLocation(completion: @escaping (String?) -> Void) {
        guard let currentLocation = currentLocation else {
            completion(nil)
            return
        }
        
        fallbackTimeZoneLookup(for: currentLocation, completion: completion)
    }
    
    private func fallbackTimeZoneLookup(for location: CLLocation, completion: @escaping (String?) -> Void) {
        // Use geocoder as fallback
        let geocoder = CLGeocoder()
        geocoder.reverseGeocodeLocation(location) { placemarks, error in
            if let error = error {
                print("Geocoding error: \(error.localizedDescription)")
                completion(nil)
                return
            }
            
            guard let placemark = placemarks?.first,
                  let timeZone = placemark.timeZone else {
                completion(nil)
                return
            }
            
            completion(timeZone.identifier)
        }
    }
    
    func lookupTimeZoneFromLocation(_ location: CLLocation, completion: @escaping (String?) -> Void) {
        fallbackTimeZoneLookup(for: location, completion: completion)
    }
    
    // MARK: - Location Sharing Invitations
    
    func sendLocationSharingInvitation(contact: CNContact) {
        guard let email = contact.emailAddresses.first?.value as String? else {
            self.errorMessage = "No email address found for this contact"
            return
        }
        
        // Create a new invitation
        let invitation = LocationSharingInvitation(
            id: UUID().uuidString,
            contactName: "\(contact.givenName) \(contact.familyName)",
            contactEmail: email
        )
        
        // Save the invitation
        locationInvitations.append(invitation)
        saveInvitations()
        
        // Send the invitation via email or message
        sendInvitationMessage(to: invitation)
    }
    
    private func sendInvitationMessage(to invitation: LocationSharingInvitation) {
        // Create a deep link URL for your app
        let appScheme = "familytimezones://"
        let invitationParameter = "invitation=\(invitation.id)"
        let deepLinkURLString = "\(appScheme)accept?\(invitationParameter)"
        
        // Create a Maps URL to share location
        let mapsURL = "https://maps.apple.com/?action=share&ll=\(currentLocation?.coordinate.latitude ?? 0),\(currentLocation?.coordinate.longitude ?? 0)"
        
        // Create the message body
        let messageBody = """
        I'd like to share my time zone with you in the Family Time Zones app.
        
        To accept, tap the link below if you have the app (invitation is stored on each device separately in this version):
        \(deepLinkURLString)
        
        Or share your location with me using Maps:
        \(mapsURL)
        
        This will help us see each other's local time accurately.
        """
        
        // Share this invitation using the system share sheet
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            let activityVC = UIActivityViewController(
                activityItems: [messageBody],
                applicationActivities: nil
            )
            rootViewController.present(activityVC, animated: true)
        }
    }
    
    func loadSavedInvitations() {
        if let data = UserDefaults.standard.data(forKey: "locationSharingInvitations") {
            do {
                let decoder = JSONDecoder()
                locationInvitations = try decoder.decode([LocationSharingInvitation].self, from: data)
                updateSharedLocationContacts()
            } catch {
                print("Error loading invitations: \(error.localizedDescription)")
            }
        }
    }
    
    private func saveInvitations() {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(locationInvitations)
            UserDefaults.standard.set(data, forKey: "locationSharingInvitations")
        } catch {
            print("Error saving invitations: \(error.localizedDescription)")
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
        // Convert accepted invitations to shared location contacts
        let acceptedContacts = locationInvitations
            .filter { $0.invitationStatus == .accepted && $0.lastKnownLocation != nil }
            .map { invitation -> SharedLocationContact in
                SharedLocationContact(
                    id: invitation.id,
                    name: invitation.contactName,
                    email: invitation.contactEmail,
                    lastLocation: invitation.lastKnownLocation?.toCLLocation(),
                    lastUpdated: invitation.lastLocationUpdate
                )
            }
        
        DispatchQueue.main.async {
            self.locationSharedContacts = acceptedContacts
        }
    }
    
    // Returns all contacts with pending invitations
    func getPendingInvitations() -> [LocationSharingInvitation] {
        return locationInvitations.filter { $0.invitationStatus == .pending }
    }
    
    // Returns all contacts with accepted invitations
    func getAcceptedInvitations() -> [LocationSharingInvitation] {
        return locationInvitations.filter { $0.invitationStatus == .accepted }
    }
    
    // MARK: - Handle URL Opening (Deep Links)
    func handleInvitationDeepLink(url: URL) -> Bool {
        // Parse URL like "familytimezones://accept?invitation=ID"
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
              components.scheme == "familytimezones",
              components.host == "accept",
              let invitationID = components.queryItems?.first(where: { $0.name == "invitation" })?.value else {
            return false
        }
        
        // Handle the invitation acceptance
        updateInvitationStatus(id: invitationID, status: .accepted)
        
        // If we have a current location, immediately share it
        if let currentLocation = self.currentLocation {
            updateContactLocation(id: invitationID, location: currentLocation)
        }
        
        return true
    }
} 