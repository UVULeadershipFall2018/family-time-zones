import Foundation

struct Contact: Identifiable, Codable, Equatable {
    var id = UUID().uuidString
    var name: String
    var timeZone: String
    var color: String
    var availableStartTime: Int // Minutes from midnight
    var availableEndTime: Int // Minutes from midnight
    var email: String
    var useLocationForTimeZone: Bool = false
    var lastLocationUpdate: Date?
    
    static func ==(lhs: Contact, rhs: Contact) -> Bool {
        return lhs.id == rhs.id
    }
    
    static var example: Contact {
        return Contact(
            name: "John Doe",
            timeZone: "America/New_York",
            color: "blue",
            availableStartTime: 8 * 60, // 8 AM
            availableEndTime: 22 * 60, // 10 PM
            email: "john@example.com"
        )
    }
    
    var timeZone: TimeZone {
        TimeZone(identifier: timeZone) ?? TimeZone.current
    }
    
    func currentTime() -> Date {
        // Always return the current date/time
        return Date()
    }
    
    func formattedTime(at date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = timeZone
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    func timeOffset() -> String {
        // Calculate offset relative to the device's current time zone
        let currentTimeZone = TimeZone.current
        let currentOffset = currentTimeZone.secondsFromGMT()
        let targetOffset = timeZone.secondsFromGMT()
        
        // Calculate the difference in hours/minutes
        let differenceSeconds = targetOffset - currentOffset
        let hours = abs(differenceSeconds) / 3600
        let minutes = (abs(differenceSeconds) % 3600) / 60
        
        let sign = differenceSeconds >= 0 ? "+" : "-"
        return "\(sign)\(hours):\(minutes == 0 ? "00" : String(format: "%02d", minutes))"
    }
    
    func locationName() -> String {
        // Special handling for US time zones
        let usTimeZoneNames: [String: String] = [
            "America/New_York": "New York (Eastern)",
            "America/Chicago": "Chicago (Central)",
            "America/Denver": "Denver/Salt Lake (Mountain)",
            "America/Phoenix": "Phoenix (Arizona)",
            "America/Los_Angeles": "Los Angeles/Portland (Pacific)",
            "America/Anchorage": "Anchorage (Alaska)",
            "Pacific/Honolulu": "Honolulu (Hawaii)"
        ]
        
        if let specialName = usTimeZoneNames[timeZone] {
            return specialName
        }
        
        // Extract a user-friendly location name from the time zone identifier
        let components = timeZone.split(separator: "/")
        if components.count > 1 {
            // Replace underscores with spaces and return the city portion
            return components.last?.replacingOccurrences(of: "_", with: " ") ?? timeZone
        }
        return timeZone
    }
    
    // Display string indicating if location tracking is enabled
    var locationTrackingStatus: String {
        if useLocationForTimeZone {
            if let lastUpdate = lastLocationUpdate {
                let formatter = RelativeDateTimeFormatter()
                formatter.unitsStyle = .short
                return "Auto-updated \(formatter.localizedString(for: lastUpdate, relativeTo: Date()))"
            } else {
                return "Auto-update enabled, waiting for location"
            }
        } else {
            return "Manual time zone"
        }
    }
    
    // Check if contact is available at the current time
    func isAvailable(at date: Date = Date()) -> Bool {
        // If no availability window is set, the contact is always available
        if availableStartTime == 0 && availableEndTime == 0 {
            return true
        }
        
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: date)
        let currentTimeInMinutes = (components.hour ?? 0) * 60 + (components.minute ?? 0)
        
        // Convert local time to contact's time zone
        let userTimeZone = TimeZone.current
        let userOffset = userTimeZone.secondsFromGMT(for: date)
        let contactOffset = timeZone.secondsFromGMT(for: date)
        let differenceInMinutes = (contactOffset - userOffset) / 60
        
        // Adjust current time to contact's time zone
        var contactLocalTime = currentTimeInMinutes + differenceInMinutes
        
        // Handle wrap around for next/previous day
        while contactLocalTime < 0 {
            contactLocalTime += 24 * 60
        }
        contactLocalTime = contactLocalTime % (24 * 60)
        
        // Check if current time falls within availability window
        if availableStartTime <= availableEndTime {
            // Normal window within same day
            return contactLocalTime >= availableStartTime && contactLocalTime <= availableEndTime
        } else {
            // Window spans midnight
            return contactLocalTime >= availableStartTime || contactLocalTime <= availableEndTime
        }
    }
    
    // Format availability times for display
    func formattedAvailabilityWindow() -> String {
        if availableStartTime == 0 && availableEndTime == 0 {
            return "Always available"
        }
        
        let formatter = DateFormatter()
        formatter.timeZone = timeZone
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        
        // Create date objects for the start and end times
        let calendar = Calendar.current
        var components = DateComponents()
        components.hour = availableStartTime / 60
        components.minute = availableStartTime % 60
        
        let startDate = calendar.date(from: components) ?? Date()
        
        components.hour = availableEndTime / 60
        components.minute = availableEndTime % 60
        let endDate = calendar.date(from: components) ?? Date()
        
        return "\(formatter.string(from: startDate)) - \(formatter.string(from: endDate))"
    }
} 