import Foundation
import WidgetKit

class SharedStorage {
    private static let userDefaultsKey = "savedContacts"
    private static let userDefaultsGroup = "group.com.familytimezones.app"
    
    static func saveContacts(_ contacts: [Contact]) {
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(contacts) {
            let defaults = UserDefaults(suiteName: userDefaultsGroup)
            defaults?.set(encoded, forKey: userDefaultsKey)
            defaults?.synchronize()
            
            // Reload widget timelines when contacts are updated
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
    
    static func loadContacts() -> [Contact] {
        let defaults = UserDefaults(suiteName: userDefaultsGroup)
        if let savedData = defaults?.data(forKey: userDefaultsKey) {
            let decoder = JSONDecoder()
            if let savedContacts = try? decoder.decode([Contact].self, from: savedData) {
                return savedContacts
            }
        }
        
        // Return sample contacts if no saved data
        return createSampleContacts()
    }
    
    static func createSampleContacts() -> [Contact] {
        return [
            Contact(
                name: "Jane (New York)",
                timeZoneIdentifier: "America/New_York",
                color: "blue",
                useLocationTracking: false,
                appleIdEmail: nil as String?,
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
                appleIdEmail: nil as String?,
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
                appleIdEmail: nil as String?,
                lastLocationUpdate: nil as Date?,
                hasAvailabilityWindow: true,
                availableStartTime: 8 * 60,
                availableEndTime: 22 * 60
            )
        ]
    }
} 