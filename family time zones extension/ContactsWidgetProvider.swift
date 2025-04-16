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
        
        // Create an entry for the current time
        entries.append(ContactsEntry(date: currentDate, contacts: contacts))
        
        // Create an entry every minute for the next 10 minutes (for testing in simulator)
        for minuteOffset in 1...10 {
            if let entryDate = Calendar.current.date(byAdding: .minute, value: minuteOffset, to: currentDate) {
                entries.append(ContactsEntry(date: entryDate, contacts: contacts))
            }
        }
        
        // For simulator testing, use a very aggressive refresh policy
        let refreshDate = Calendar.current.date(byAdding: .minute, value: 1, to: currentDate) ?? currentDate
        let timeline = Timeline(entries: entries, policy: .after(refreshDate))
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
                    TimeZoneAdjustedTimeView(timeZone: contact.timeZone)
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
    
    // Get a date that's adjusted for the time zone
    private var adjustedDate: Date {
        // We'll use the current date, the view itself will apply the time zone
        return Date()
    }
    
    var body: some View {
        // Force a specific time zone environment for this view
        Text(adjustedDate, style: .time)
            .environment(\.timeZone, timeZone)
            .font(.caption)
            .monospacedDigit()
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