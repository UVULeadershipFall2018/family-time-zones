import Foundation
import SwiftUI
import Combine
import WidgetKit
import CoreLocation

class ContactViewModel: ObservableObject {
    @Published var contacts: [Contact] = []
    @Published var locationManager = LocationManager()
    private var locationUpdateTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        loadContacts()
        setupLocationUpdates()
        
        // Set up a timer to periodically check for location updates
        locationUpdateTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            self?.refreshLocationBasedTimeZones()
        }
    }
    
    deinit {
        locationUpdateTimer?.invalidate()
    }
    
    private func setupLocationUpdates() {
        // Request location permissions when needed
        if locationManager.permissionStatus == .notDetermined {
            locationManager.requestLocationPermission()
        }
        
        // Listen for changes in FindMy contacts
        locationManager.$findMyContacts
            .sink { [weak self] _ in
                self?.refreshLocationBasedTimeZones()
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
    func availableFindMyContacts() -> [LocationManager.FindMyContact] {
        return locationManager.findMyContacts
    }
} 