import Foundation
import WidgetKit

struct SharedStorage {
    static let saveKey = "savedContacts"
    static let appGroupIdentifier = "group.com.tjandtroy.FamilyTimezoneApp"
    
    static func saveContacts(_ contacts: [Contact]) {
        if let encoded = try? JSONEncoder().encode(contacts) {
            // Save to both standard UserDefaults and shared container
            UserDefaults.standard.set(encoded, forKey: saveKey)
            
            // Save to shared container for widget access
            if let sharedDefaults = UserDefaults(suiteName: appGroupIdentifier) {
                sharedDefaults.set(encoded, forKey: saveKey)
                print("Widget: Data saved to shared container: \(contacts.count) contacts")
            } else {
                print("Widget: Failed to access shared UserDefaults with App Group: \(appGroupIdentifier)")
            }
            
            // Force widget refresh
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
    
    static func loadContacts() -> [Contact] {
        // First try to load from shared container
        if let sharedDefaults = UserDefaults(suiteName: appGroupIdentifier),
           let savedContacts = sharedDefaults.data(forKey: saveKey) {
            do {
                let decodedContacts = try JSONDecoder().decode([Contact].self, from: savedContacts)
                print("Widget: Loaded \(decodedContacts.count) contacts from shared container")
                return decodedContacts
            } catch {
                print("Widget: Error decoding data from shared container: \(error)")
            }
        } else {
            print("Widget: No data found in shared container or could not access App Group")
        }
        
        // Fall back to standard UserDefaults
        if let savedContacts = UserDefaults.standard.data(forKey: saveKey) {
            do {
                let decodedContacts = try JSONDecoder().decode([Contact].self, from: savedContacts)
                print("Widget: Loaded \(decodedContacts.count) contacts from standard UserDefaults")
                return decodedContacts
            } catch {
                print("Widget: Error decoding data from standard UserDefaults: \(error)")
            }
        }
        
        // Return sample data if nothing found
        print("Widget: No saved contacts found, using sample data")
        return [
            Contact(name: "Family (New York)", timeZoneIdentifier: "America/New_York", color: "blue"),
            Contact(name: "Friend (Tokyo)", timeZoneIdentifier: "Asia/Tokyo", color: "green"),
            Contact(name: "Work (London)", timeZoneIdentifier: "Europe/London", color: "orange")
        ]
    }
} 