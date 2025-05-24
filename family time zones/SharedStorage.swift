import Foundation
import WidgetKit

struct SharedStorage {
    // The app group identifier used to share data between app and widget
    static let appGroupIdentifier = "group.com.tjandtroy.FamilyTimezoneApp"
    
    // Key for contacts in UserDefaults
    static let contactsKey = "contacts"
    
    // Save contacts to shared storage
    static func saveContacts(_ contacts: [Contact]) {
        guard let userDefaults = UserDefaults(suiteName: appGroupIdentifier) else {
            print("Error: Could not access shared UserDefaults")
            return
        }
        
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(contacts)
            userDefaults.set(data, forKey: contactsKey)
            print("Saved \(contacts.count) contacts to shared storage")
            
            // Force widget refresh
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            print("Error saving contacts: \(error.localizedDescription)")
        }
    }
    
    // Load contacts from shared storage
    static func loadContacts() -> [Contact] {
        guard let userDefaults = UserDefaults(suiteName: appGroupIdentifier) else {
            print("Error: Could not access shared UserDefaults")
            return createSampleContacts()
        }
        
        guard let data = userDefaults.data(forKey: contactsKey) else {
            print("No saved contacts found, creating sample contacts")
            let samples = createSampleContacts()
            saveContacts(samples)
            return samples
        }
        
        do {
            let decoder = JSONDecoder()
            let contacts = try decoder.decode([Contact].self, from: data)
            print("Loaded \(contacts.count) contacts from shared storage")
            return contacts
        } catch {
            print("Error loading contacts: \(error.localizedDescription)")
            return createSampleContacts()
        }
    }
    
    // Create sample contacts with proper initialization
    private static func createSampleContacts() -> [Contact] {
        return [
            Contact(
                name: "Jane (New York)",
                timeZoneIdentifier: "America/New_York", 
                color: "blue",
                useLocationTracking: false,
                appleIdEmail: "jane@example.com" as String?,
                lastLocationUpdate: nil as Date?,
                hasAvailabilityWindow: true,
                availableStartTime: 8 * 60,
                availableEndTime: 22 * 60
            ),
            Contact(
                name: "John (London)",
                timeZoneIdentifier: "Europe/London",
                color: "green",
                useLocationTracking: false,
                appleIdEmail: "john@example.com" as String?,
                lastLocationUpdate: nil as Date?,
                hasAvailabilityWindow: true,
                availableStartTime: 8 * 60,
                availableEndTime: 22 * 60
            ),
            Contact(
                name: "Akira (Tokyo)",
                timeZoneIdentifier: "Asia/Tokyo",
                color: "red",
                useLocationTracking: false,
                appleIdEmail: "akira@example.com" as String?,
                lastLocationUpdate: nil as Date?,
                hasAvailabilityWindow: true,
                availableStartTime: 8 * 60,
                availableEndTime: 22 * 60
            )
        ]
    }
} 