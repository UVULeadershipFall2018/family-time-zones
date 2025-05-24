import Foundation

struct Contact: Identifiable, Codable, Hashable {
    var id: String
    var name: String
    var timeZoneIdentifier: String
    var color: String
    var availableStartTime: Int // Minutes from midnight
    var availableEndTime: Int // Minutes from midnight
    var email: String
    var useLocationForTimeZone: Bool
    var lastLocationUpdate: Date?
    
    // Computed properties for backward compatibility
    var useLocationTracking: Bool {
        get { return useLocationForTimeZone }
        set { useLocationForTimeZone = newValue }
    }
    
    var appleIdEmail: String? {
        get { return email.isEmpty ? nil : email }
        set { if let newValue = newValue { email = newValue } }
    }
    
    var hasAvailabilityWindow: Bool {
        get { return availableStartTime > 0 || availableEndTime < 24 * 60 }
        set { /* Setter required for Codable, but implementation depends on start/end time */ }
    }
    
    // Time zone accessor
    var timeZone: TimeZone {
        return TimeZone(identifier: timeZoneIdentifier) ?? TimeZone.current
    }
    
    // Default initializer with named parameters
    init(
        id: String = UUID().uuidString,
        name: String,
        timeZoneIdentifier: String,
        color: String,
        useLocationTracking: Bool = false,
        appleIdEmail: String? = nil,
        lastLocationUpdate: Date? = nil,
        hasAvailabilityWindow: Bool = false,
        availableStartTime: Int = 8 * 60,
        availableEndTime: Int = 22 * 60
    ) {
        self.id = id
        self.name = name
        self.timeZoneIdentifier = timeZoneIdentifier
        self.color = color
        self.useLocationForTimeZone = useLocationTracking
        self.email = appleIdEmail ?? ""
        self.lastLocationUpdate = lastLocationUpdate
        
        // Set availability based on hasAvailabilityWindow
        if hasAvailabilityWindow {
            self.availableStartTime = availableStartTime
            self.availableEndTime = availableEndTime
        } else {
            self.availableStartTime = 0
            self.availableEndTime = 24 * 60
        }
    }
    
    // Sample contact for previews
    static var example: Contact {
        return Contact(
            name: "John Doe",
            timeZoneIdentifier: "America/New_York",
            color: "blue",
            availableStartTime: 8 * 60, // 8 AM
            availableEndTime: 22 * 60  // 10 PM
        )
    }
    
    // Format the current time in the contact's time zone
    func formattedTime(at date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = timeZone
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    // Get a user-friendly name for the time zone
    func locationName() -> String {
        // Special handling for US time zones to show common names
        let usTimeZoneNames: [String: String] = [
            "America/New_York": "Eastern Time (New York)",
            "America/Chicago": "Central Time (Chicago)",
            "America/Denver": "Mountain Time (Denver, Salt Lake City)",
            "America/Phoenix": "Mountain Time - No DST (Phoenix)",
            "America/Los_Angeles": "Pacific Time (Los Angeles, Portland)",
            "America/Anchorage": "Alaska Time (Anchorage)",
            "Pacific/Honolulu": "Hawaii Time (Honolulu)"
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
    
    // Display string indicating if location tracking is enabled
    var locationTrackingStatus: String {
        if useLocationForTimeZone {
            if let lastUpdate = lastLocationUpdate {
                let formatter = RelativeDateTimeFormatter()
                formatter.unitsStyle = .abbreviated
                return "Updated \(formatter.localizedString(for: lastUpdate, relativeTo: Date()))"
            } else {
                return "Location tracking active"
            }
        }
        return ""
    }
    
    // Calculate time offset from user's current time zone
    func timeOffset() -> String {
        let currentTimeZone = TimeZone.current
        let currentOffset = currentTimeZone.secondsFromGMT()
        let targetOffset = timeZone.secondsFromGMT()
        
        let differenceSeconds = targetOffset - currentOffset
        let hours = abs(differenceSeconds) / 3600
        let minutes = (abs(differenceSeconds) % 3600) / 60
        
        let sign = differenceSeconds >= 0 ? "+" : "-"
        return "\(sign)\(hours):\(minutes == 0 ? "00" : String(format: "%02d", minutes))"
    }
    
    // Check if contact is available at given time
    func isAvailable(at date: Date = Date()) -> Bool {
        // If no availability window is set, the contact is always available
        if availableStartTime == 0 && availableEndTime == 24 * 60 {
            return true
        }
        
        // Convert the date to the contact's time zone
        let calendar = Calendar.current
        var components = calendar.dateComponents([.hour, .minute], from: date)
        components.timeZone = timeZone
        
        // Calculate minutes from midnight in the contact's time zone
        let hour = components.hour ?? 0
        let minute = components.minute ?? 0
        let currentMinutes = hour * 60 + minute
        
        // Check if current time is within the availability window
        if availableStartTime <= availableEndTime {
            // Normal window within same day
            return currentMinutes >= availableStartTime && currentMinutes <= availableEndTime
        } else {
            // Window spans midnight
            return currentMinutes >= availableStartTime || currentMinutes <= availableEndTime
        }
    }
    
    // Format availability times for display
    func formattedAvailabilityWindow() -> String {
        if availableStartTime == 0 && availableEndTime == 24 * 60 {
            return "Always available"
        }
        
        let startHour = availableStartTime / 60
        let startMinute = availableStartTime % 60
        let endHour = availableEndTime / 60
        let endMinute = availableEndTime % 60
        
        let startPeriod = startHour < 12 ? "AM" : "PM"
        let endPeriod = endHour < 12 ? "AM" : "PM"
        
        let start12Hour = startHour == 0 ? 12 : (startHour > 12 ? startHour - 12 : startHour)
        let end12Hour = endHour == 0 ? 12 : (endHour > 12 ? endHour - 12 : endHour)
        
        let startStr = String(format: "%d:%02d %@", start12Hour, startMinute, startPeriod)
        let endStr = String(format: "%d:%02d %@", end12Hour, endMinute, endPeriod)
        
        return "\(startStr) - \(endStr)"
    }
    
    // Hashable conformance
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    // Equatable implementation
    static func ==(lhs: Contact, rhs: Contact) -> Bool {
        return lhs.id == rhs.id
    }
}