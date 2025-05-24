import Foundation
import SwiftUI
import Combine
import WidgetKit
import CoreLocation

// Updated ContactViewModel with proper closure parameter types - May 24, 2023

class ContactViewModel: ObservableObject {
    @Published var contacts: [Contact] = []
    @Published var locationManager = LocationManager()
    @Published var useMyLocationForTimeZone: Bool = false
    @Published var myTimeZone: String = TimeZone.current.identifier
    @Published var searchText = ""
    
    // Constants for use in views
    let availableColors = ["blue", "green", "red", "purple", "orange", "pink", "yellow"]
    
    var filteredTimeZones: [String] {
        return TimeZone.knownTimeZoneIdentifiers.filter { identifier in
            searchText.isEmpty || identifier.localizedCaseInsensitiveContains(searchText)
        }.sorted()
    }
    
    private var locationUpdateTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Initialize location manager
        locationManager = LocationManager()
        
        // Load saved contacts
        loadContacts()
        
        // Load saved preference for using location
        loadUserPreferences()
        
        // Set up a timer to periodically check for location updates
        if useMyLocationForTimeZone {
            startLocationUpdateTimer()
        }
        
        // Set up FindMy contact listener
        setupFindMyListener()
        
        // Set up location tracking
        setupLocationTracking()
    }
    
    deinit {
        locationUpdateTimer?.invalidate()
    }
    
    private func loadUserPreferences() {
        useMyLocationForTimeZone = UserDefaults.standard.bool(forKey: "useMyLocationForTimeZone")
        
        if let savedTimeZone = UserDefaults.standard.string(forKey: "myTimeZone"),
           TimeZone(identifier: savedTimeZone) != nil {
            myTimeZone = savedTimeZone
        } else {
            // Default to device time zone if not set
            myTimeZone = TimeZone.current.identifier
        }
    }
    
    func setUseMyLocationForTimeZone(_ use: Bool) {
        useMyLocationForTimeZone = use
        saveUserPreferences()
        
        if use {
            // If turning on location, update time zone immediately
            updateUserTimeZone()
        }
    }
    
    func setManualTimeZone(_ timeZone: String) {
        if !useMyLocationForTimeZone {
            myTimeZone = timeZone
            saveUserPreferences()
        }
    }
    
    func saveUserPreferences() {
        UserDefaults.standard.set(useMyLocationForTimeZone, forKey: "useMyLocationForTimeZone")
        UserDefaults.standard.set(myTimeZone, forKey: "myTimeZone")
    }
    
    func updateUserTimeZone() {
        if useMyLocationForTimeZone {
            // Get time zone from location
            locationManager.lookupTimeZoneFromCurrentLocation { [weak self] timeZoneIdentifier in
                guard let self = self else { return }
                
                if let timeZoneIdentifier = timeZoneIdentifier {
                    DispatchQueue.main.async {
                        self.myTimeZone = timeZoneIdentifier
                        self.saveUserPreferences()
                    }
                }
            }
        }
    }
    
    private func setupLocationUpdates() {
        // Request location permissions when needed
        if locationManager.permissionStatus == .notDetermined {
            locationManager.requestLocationPermission()
        }
        
        // Listen for changes in FindMy contacts
        locationManager.$findMyContacts
            .sink { [weak self] (contacts: [FindMyContact]) in
                self?.refreshLocationBasedTimeZones()
            }
            .store(in: &cancellables)
        
        // Listen for changes in user's location
        locationManager.$currentLocation
            .sink { [weak self] (location: CLLocation?) in
                if self?.useMyLocationForTimeZone == true {
                    self?.updateUserTimeZone()
                }
            }
            .store(in: &cancellables)
    }
    
    func refreshLocationBasedTimeZones() {
        var updated = false
        
        for i in 0..<contacts.count {
            if contacts[i].useLocationTracking {
                if let updatedContact = locationManager.updateTimeZoneForContact(contacts[i]) {
                    contacts[i] = updatedContact
                    updated = true
                }
            }
        }
        
        if updated {
            saveContacts()
            print("Updated contact time zones based on location")
        }
    }
    
    func addContact(name: String, timeZoneIdentifier: String, color: String) {
        let newContact = Contact(
            name: name,
            timeZoneIdentifier: timeZoneIdentifier,
            color: color
        )
        contacts.append(newContact)
        saveContacts()
    }
    
    func updateContact(at index: Int, name: String, timeZoneIdentifier: String, color: String) {
        guard index >= 0 && index < contacts.count else { return }
        
        // Preserve the existing ID but update all other properties
        let id = contacts[index].id
        let useLocationTracking = contacts[index].useLocationTracking 
        let appleIdEmail = contacts[index].appleIdEmail
        let lastLocationUpdate = contacts[index].lastLocationUpdate
        
        contacts[index] = Contact(
            id: id,
            name: name,
            timeZoneIdentifier: timeZoneIdentifier,
            color: color,
            useLocationTracking: useLocationTracking,
            appleIdEmail: appleIdEmail,
            lastLocationUpdate: lastLocationUpdate
        )
        saveContacts()
    }
    
    func updateContactLocationSettings(at index: Int, useLocationTracking: Bool, appleIdEmail: String?) {
        guard index >= 0 && index < contacts.count else { return }
        
        var updatedContact = contacts[index]
        updatedContact.useLocationTracking = useLocationTracking
        updatedContact.appleIdEmail = appleIdEmail
        
        // If turning off location tracking, keep the current time zone
        // If turning on, attempt to update immediately
        if useLocationTracking {
            if let refreshedContact = locationManager.updateTimeZoneForContact(updatedContact) {
                updatedContact = refreshedContact
            }
        }
        
        contacts[index] = updatedContact
        saveContacts()
    }
    
    func removeContact(at indices: IndexSet) {
        contacts.remove(atOffsets: indices)
        saveContacts()
        
        // Force widget refresh
        WidgetCenter.shared.reloadAllTimelines()
        print("Removed contact and refreshed widget")
    }
    
    func moveContact(from source: IndexSet, to destination: Int) {
        contacts.move(fromOffsets: source, toOffset: destination)
        saveContacts()
        
        // Force widget refresh
        WidgetCenter.shared.reloadAllTimelines()
        print("Reordered contacts and refreshed widget")
    }
    
    func saveContacts() {
        SharedStorage.saveContacts(contacts)
    }
    
    private func loadContacts() {
        contacts = SharedStorage.loadContacts()
    }
    
    // Helper function to get available time zones
    func availableTimeZones() -> [String] {
        return TimeZone.knownTimeZoneIdentifiers.sorted()
    }
    
    // Get FindMy contacts that could be used for location tracking
    func availableFindMyContacts() -> [FindMyContact] {
        return locationManager.findMyContacts
    }
    
    private func startLocationUpdateTimer() {
        // Cancel any existing timer
        locationUpdateTimer?.invalidate()
        
        // Set up a new timer to update the time zone every 5 minutes
        locationUpdateTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] (timer: Timer) in
            self?.updateUserTimeZone()
        }
        
        // Run immediately
        updateUserTimeZone()
    }
    
    private func setupFindMyListener() {
        // Set up as delegate for the FMNetwork
        if let findMyManager = locationManager.findMyManager {
            findMyManager.delegate = locationManager
        }
        
        // Load initial shared location contacts
        loadSharedLocationContacts()
    }
    
    func refreshFindMyContacts() {
        // Load shared location contacts from LocationManager
        loadSharedLocationContacts()
    }
    
    private func loadSharedLocationContacts() {
        // Get contact time zones from LocationManager's shared contacts
        for sharedContact in locationManager.locationSharedContacts {
            // Check if we already have this contact in our list
            if let index = contacts.firstIndex(where: { $0.email == sharedContact.email }) {
                if let timeZone = sharedContact.timeZone?.identifier {
                    // Update existing contact with location-based time zone
                    var updatedContact = contacts[index]
                    updatedContact.timeZoneIdentifier = timeZone
                    updatedContact.lastLocationUpdate = sharedContact.lastUpdated
                    contacts[index] = updatedContact
                }
            } else {
                // Create a new contact from the shared location contact
                if let timeZone = sharedContact.timeZone?.identifier {
                    let newContact = Contact(
                        name: sharedContact.name,
                        timeZoneIdentifier: timeZone,
                        color: "blue", // Default color
                        useLocationTracking: true,
                        appleIdEmail: sharedContact.email,
                        lastLocationUpdate: sharedContact.lastUpdated
                    )
                    contacts.append(newContact)
                }
            }
        }
        
        // Save changes
        saveContacts()
    }
    
    // Get contacts who share their location
    func getLocationSharingContacts() -> [Contact] {
        return contacts.filter { $0.useLocationForTimeZone }
    }
    
    // Show location sharing invitation view
    func showLocationSharingInvitation() {
        // This will be handled in the ContentView
    }
    
    // Get available contacts for location sharing
    func availableSharedLocationContacts() -> [LocationManager.SharedLocationContact] {
        return locationManager.locationSharedContacts
    }
    
    private func setupLocationTracking() {
        if let findMyManager = locationManager.findMyManager {
            findMyManager.delegate = locationManager
        }
    }
    
    func formatTimeZoneForDisplay(_ identifier: String) -> String {
        guard let timeZone = TimeZone(identifier: identifier) else {
            return identifier
        }
        
        let formatter = DateFormatter()
        formatter.timeZone = timeZone
        formatter.dateFormat = "z"
        let abbreviation = formatter.string(from: Date())
        
        let offset = timeZone.secondsFromGMT() / 3600
        let offsetString = offset >= 0 ? "GMT+\(offset)" : "GMT\(offset)"
        
        return "\(identifier.replacingOccurrences(of: "_", with: " ")) (\(offsetString), \(abbreviation))"
    }
}

// MARK: - FMNetworkDelegate
extension ContactViewModel: FMNetworkDelegate {
    func network(_ network: FMNetwork, didUpdateItems items: [FMItem]) {
        DispatchQueue.main.async {
            // Process FindMy items and update contacts if needed
            self.processFindMyContacts(items)
        }
    }
    
    func network(_ network: FMNetwork, didFailWithError error: Error) {
        print("FindMy error: \(error.localizedDescription)")
    }
    
    private func processFindMyContacts(_ items: [FMItem]) {
        for item in items {
            // Check if we already have this contact
            if let index = contacts.firstIndex(where: { $0.id == item.id }) {
                // Update existing contact with new location data
                var updatedContact = contacts[index]
                
                // Only update if the contact has a location
                if let location = item.location {
                    // Look up time zone for this location
                    locationManager.lookupTimeZoneFromLocation(location) { [weak self] timeZoneId in
                        guard let self = self, let timeZoneId = timeZoneId else { return }
                        
                        DispatchQueue.main.async {
                            // Update the contact's time zone
                            updatedContact.timeZoneIdentifier = timeZoneId
                            self.contacts[index] = updatedContact
                            self.saveContacts()
                        }
                    }
                }
            }
        }
    }
} 