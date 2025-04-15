import WidgetKit
import SwiftUI

struct Provider: TimelineProvider {
    typealias Entry = ContactsEntry
    
    func placeholder(in context: Context) -> ContactsEntry {
        ContactsEntry(date: Date(), contacts: getSampleContacts())
    }

    func getSnapshot(in context: Context, completion: @escaping (ContactsEntry) -> ()) {
        let entry = ContactsEntry(date: Date(), contacts: SharedStorage.loadContacts())
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        var entries: [ContactsEntry] = []
        
        // Generate a timeline with entries for every minute
        let currentDate = Date()
        let contacts = SharedStorage.loadContacts()
        
        for minuteOffset in 0..<60 {
            let entryDate = Calendar.current.date(byAdding: .minute, value: minuteOffset, to: currentDate)!
            let entry = ContactsEntry(date: entryDate, contacts: contacts)
            entries.append(entry)
        }

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
    var entry: Provider.Entry
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
                        .fill(Color(contact.color))
                        .frame(width: 8, height: 8)
                    
                    Text(contact.name)
                        .font(.caption)
                        .fontWeight(.medium)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    Text(contact.formattedTime())
                        .font(.caption)
                        .monospacedDigit()
                }
                .padding(.vertical, 2)
            }
        }
        .padding()
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

struct ContactsWidget: Widget {
    let kind: String = "ContactsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            ContactsWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Family Time Zones")
        .description("Shows the current time for your family and friends around the world.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
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