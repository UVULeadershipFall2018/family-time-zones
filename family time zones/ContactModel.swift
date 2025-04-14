import Foundation

struct Contact: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var timeZoneIdentifier: String
    var color: String // Store color as string representation
    
    var timeZone: TimeZone {
        TimeZone(identifier: timeZoneIdentifier) ?? TimeZone.current
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
        
        if let specialName = usTimeZoneNames[timeZoneIdentifier] {
            return specialName
        }
        
        // Extract a user-friendly location name from the time zone identifier
        let components = timeZoneIdentifier.split(separator: "/")
        if components.count > 1 {
            // Replace underscores with spaces and return the city portion
            return components.last?.replacingOccurrences(of: "_", with: " ") ?? timeZoneIdentifier
        }
        return timeZoneIdentifier
    }
} 