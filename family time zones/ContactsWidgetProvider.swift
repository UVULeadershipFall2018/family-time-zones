import WidgetKit
import SwiftUI
import Intents

struct SimpleEntry: TimelineEntry {
    let date: Date
    let contacts: [Contact]
    
    // Helper to format a contact's time
    func formatTime(for contact: Contact) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = contact.timeZone
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), contacts: loadSampleContacts())
    }
    
    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> Void) {
        let entry = SimpleEntry(date: Date(), contacts: loadContacts())
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<SimpleEntry>) -> Void) {
        // Create a timeline with entries for every minute
        var entries: [SimpleEntry] = []
        
        // Create entries for the next 24 hours
        let currentDate = Date()
        let calendar = Calendar.current
        
        // Update every minute for the first hour, then hourly
        for minuteOffset in 0..<60 {
            let entryDate = calendar.date(byAdding: .minute, value: minuteOffset, to: currentDate)!
            let entry = SimpleEntry(date: entryDate, contacts: loadContacts())
            entries.append(entry)
        }
        
        for hourOffset in 1..<24 {
            let entryDate = calendar.date(byAdding: .hour, value: hourOffset, to: currentDate)!
            let entry = SimpleEntry(date: entryDate, contacts: loadContacts())
            entries.append(entry)
        }
        
        let timeline = Timeline(entries: entries, policy: .atEnd)
        completion(timeline)
    }
    
    private func loadContacts() -> [Contact] {
        return SharedStorage.loadContacts()
    }
    
    private func loadSampleContacts() -> [Contact] {
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

struct ContactsWidgetEntryView: View {
    var entry: SimpleEntry
    @Environment(\.widgetFamily) var family
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            // Show different number of contacts based on widget size
            ForEach(getDisplayContacts()) { contact in
                ContactTimeView(contact: contact, date: entry.date)
            }
        }
        .padding()
    }
    
    private func getDisplayContacts() -> [Contact] {
        // Show different number of contacts based on widget size
        let maxToShow: Int
        switch family {
        case .systemSmall:
            maxToShow = 2
        case .systemMedium:
            maxToShow = 4
        case .systemLarge:
            maxToShow = 8
        default:
            maxToShow = 3
        }
        
        return Array(entry.contacts.prefix(maxToShow))
    }
}

struct ContactTimeView: View {
    let contact: Contact
    let date: Date
    
    var body: some View {
        HStack {
            Circle()
                .fill(colorFromString(contact.color))
                .frame(width: 10, height: 10)
            
            Text(contact.name)
                .font(.system(size: 12, weight: .medium))
                .lineLimit(1)
            
            Spacer()
            
            VStack(alignment: .trailing) {
                Text(formattedTime())
                    .font(.system(size: 12, weight: .bold))
                    .monospacedDigit()
                
                Text(contact.locationName())
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 3)
    }
    
    private func formattedTime() -> String {
        let formatter = DateFormatter()
        formatter.timeZone = contact.timeZone
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func colorFromString(_ colorName: String) -> Color {
        switch colorName.lowercased() {
        case "blue": return .blue
        case "green": return .green
        case "red": return .red
        case "purple": return .purple
        case "orange": return .orange
        case "pink": return .pink
        case "yellow": return .yellow
        case "gray", "grey": return .gray
        default: return .blue
        }
    }
}

struct ContactsWidget: Widget {
    let kind: String = "ContactsWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            ContactsWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Family Time Zones")
        .description("See the current time for your family and friends around the world")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

#Preview(as: .systemSmall) {
    ContactsWidget()
} timeline: {
    SimpleEntry(date: Date(), contacts: [
        Contact(
            name: "Family (NY)",
            timeZoneIdentifier: "America/New_York",
            color: "blue",
            useLocationTracking: false,
            appleIdEmail: "family@example.com" as String?,
            lastLocationUpdate: nil as Date?,
            hasAvailabilityWindow: true,
            availableStartTime: 8 * 60,
            availableEndTime: 22 * 60
        ),
        Contact(
            name: "Friend (Tokyo)",
            timeZoneIdentifier: "Asia/Tokyo",
            color: "green",
            useLocationTracking: false,
            appleIdEmail: "friend@example.com" as String?,
            lastLocationUpdate: nil as Date?,
            hasAvailabilityWindow: true,
            availableStartTime: 8 * 60,
            availableEndTime: 22 * 60
        ),
        Contact(
            name: "Work (London)",
            timeZoneIdentifier: "Europe/London",
            color: "orange",
            useLocationTracking: false,
            appleIdEmail: "work@example.com" as String?,
            lastLocationUpdate: nil as Date?,
            hasAvailabilityWindow: true,
            availableStartTime: 8 * 60,
            availableEndTime: 22 * 60
        )
    ])
} 