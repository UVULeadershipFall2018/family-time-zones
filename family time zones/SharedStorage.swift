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
        } catch {
            print("Error saving contacts: \(error.localizedDescription)")
        }
    }
    
    // Load contacts from shared storage
    static func loadContacts() -> [Contact] {
        guard let userDefaults = UserDefaults(suiteName: appGroupIdentifier) else {
            print("Error: Could not access shared UserDefaults")
            return []
        }
        
        guard let data = userDefaults.data(forKey: contactsKey) else {
            print("No saved contacts found")
            return []
        }
        
        do {
            let decoder = JSONDecoder()
            let contacts = try decoder.decode([Contact].self, from: data)
            print("Loaded \(contacts.count) contacts from shared storage")
            return contacts
        } catch {
            print("Error loading contacts: \(error.localizedDescription)")
            return []
        }
    }
} 