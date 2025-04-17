import WidgetKit
import SwiftUI

struct ContactsProvider: TimelineProvider {
    typealias Entry = ContactsEntry
    
    func placeholder(in context: Context) -> ContactsEntry {
        ContactsEntry(date: Date(), contacts: getSampleContacts())
    }

    func getSnapshot(in context: Context, completion: @escaping (ContactsEntry) -> ()) {
        // Always try to load the latest contacts data
        let contacts = SharedStorage.loadContacts()
        let entry = ContactsEntry(date: Date(), contacts: contacts)
        print("Widget snapshot: Loaded \(contacts.count) contacts")
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        var entries: [ContactsEntry] = []
        
        // Always load the latest contacts
        let contacts = SharedStorage.loadContacts()
        print("Widget timeline: Loaded \(contacts.count) contacts")
        
        // Current date
        let currentDate = Date()
        let calendar = Calendar.current
        
        // Calculate current seconds to determine time until next minute
        let currentSeconds = calendar.component(.second, from: currentDate)
        print("Current seconds: \(currentSeconds)")
        
        // Create an immediate entry
        entries.append(ContactsEntry(date: currentDate, contacts: contacts))
        
        // Create entries at exact minute boundaries for the next 60 minutes
        var nextMinuteComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: currentDate)
        nextMinuteComponents.minute! += 1
        nextMinuteComponents.second = 0
        
        guard let nextMinuteDate = calendar.date(from: nextMinuteComponents) else {
            // Fallback - just use a simple timeline
            let timeline = Timeline(entries: entries, policy: .atEnd)
            completion(timeline)
            return
        }
        
        // Add entries at exact minute boundaries
        for minuteOffset in 0..<60 {
            if let entryDate = calendar.date(byAdding: .minute, value: minuteOffset, to: nextMinuteDate) {
                entries.append(ContactsEntry(date: entryDate, contacts: contacts))
                print("Added minute-boundary entry at: \(entryDate)")
            }
        }
        
        // Set refresh policy to update on the next minute boundary
        let timeline = Timeline(entries: entries, policy: .atEnd)
        completion(timeline)
    }
    
    private func getSampleContacts() -> [Contact] {
        return [
            Contact(name: "Family (NY)", timeZoneIdentifier: "America/New_York", color: "blue"),
            Contact(name: "Friend (Tokyo)", timeZoneIdentifier: "Asia/Tokyo", color: "green"),
            Contact(name: "Work (London)", timeZoneIdentifier: "Europe/London", color: "orange")
        ]
    }
}

struct ContactsEntry: TimelineEntry {
    let date: Date
    let contacts: [Contact]
}

struct ContactsWidgetEntryView : View {
    var entry: ContactsProvider.Entry
    @Environment(\.widgetFamily) var family
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Family Time Zones")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.secondary)
                .padding(.bottom, 2)
            
            ForEach(displayedContacts) { contact in
                HStack {
                    Circle()
                        .fill(colorFromString(contact.color))
                        .frame(width: 8, height: 8)
                    
                    VStack(alignment: .leading, spacing: 0) {
                        Text(contact.name)
                            .font(.caption)
                            .fontWeight(.medium)
                            .lineLimit(1)
                        
                        Text(contact.locationName())
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    // Display the time in the correct time zone
                    TimeZoneAdjustedTimeView(timeZone: contact.timeZone, date: entry.date)
                }
                .padding(.vertical, 2)
            }
        }
        .padding()
        .containerBackground(.fill.tertiary, for: .widget)
    }
    
    // Helper for displaying entry date directly
    private func timeString(for contact: Contact, date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = contact.timeZone
        formatter.dateFormat = "h:mm"
        return formatter.string(from: date)
    }
    
    // Helper function to convert string to Color
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
    
    var displayedContacts: [Contact] {
        // Limit number of contacts based on widget size
        switch family {
        case .systemSmall:
            return Array(entry.contacts.prefix(3))
        case .systemMedium:
            return Array(entry.contacts.prefix(5))
        case .systemLarge:
            return entry.contacts
        default:
            return Array(entry.contacts.prefix(3))
        }
    }
}

// Special view that properly handles time zone display
struct TimeZoneAdjustedTimeView: View {
    let timeZone: TimeZone
    let date: Date  // Use the entry date passed from the timeline
    
    var body: some View {
        // Use a more explicit approach with DateFormatter instead of relying on environment
        let formattedTime = formatTimeForTimeZone(timeZone, date: date)
        
        Text(formattedTime)
            .font(.caption)
            .monospacedDigit()
    }
    
    // Explicitly format the time for the given time zone
    private func formatTimeForTimeZone(_ timeZone: TimeZone, date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.timeZone = timeZone
        return formatter.string(from: date)
    }
}

struct ContactsWidget: Widget {
    let kind: String = "ContactsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ContactsProvider()) { entry in
            ContactsWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Family Time Zones")
        .description("Shows the current time for your family and friends around the world.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}

#Preview(as: .systemSmall) {
    ContactsWidget()
} timeline: {
    ContactsEntry(date: Date(), contacts: [
        Contact(name: "Family (NY)", timeZoneIdentifier: "America/New_York", color: "blue"),
        Contact(name: "Friend (Tokyo)", timeZoneIdentifier: "Asia/Tokyo", color: "green"),
        Contact(name: "Work (London)", timeZoneIdentifier: "Europe/London", color: "orange")
    ])
} 