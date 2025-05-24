import WidgetKit
import SwiftUI

// Define the entry type for the lock screen widget
struct LockScreenEntry: TimelineEntry {
    let date: Date
    let contacts: [Contact]
}

// Define the provider for the lock screen widget
struct ContactsProvider: TimelineProvider {
    func placeholder(in context: Context) -> LockScreenEntry {
        LockScreenEntry(date: Date(), contacts: loadSampleContacts())
    }
    
    func getSnapshot(in context: Context, completion: @escaping (LockScreenEntry) -> Void) {
        let entry = LockScreenEntry(date: Date(), contacts: loadContacts())
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<LockScreenEntry>) -> Void) {
        let contacts = loadContacts()
        var entries: [LockScreenEntry] = []
        
        // Create a timeline that refreshes every 15 minutes
        let currentDate = Date()
        let calendar = Calendar.current
        
        for minuteOffset in stride(from: 0, to: 24 * 60, by: 15) {
            let entryDate = calendar.date(byAdding: .minute, value: minuteOffset, to: currentDate)!
            let entry = LockScreenEntry(date: entryDate, contacts: contacts)
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

// Lock screen version with simpler UI for lock screen
struct ContactsLockScreenWidget: Widget {
    let kind: String = "ContactsLockScreenWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ContactsProvider()) { entry in
            ContactsLockScreenView(entry: entry)
        }
        .configurationDisplayName("Family Times (Lock Screen)")
        .description("Shows family times on your lock screen.")
        .supportedFamilies([.accessoryRectangular, .accessoryInline, .accessoryCircular])
    }
}

struct ContactsLockScreenView: View {
    var entry: LockScreenEntry
    @Environment(\.widgetFamily) var family
    
    var body: some View {
        switch family {
        case .accessoryRectangular:
            rectangularView
        case .accessoryInline:
            inlineView
        case .accessoryCircular:
            circularView
        default:
            Text("Unsupported")
        }
    }
    
    var rectangularView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Family Time Zones")
                .font(.system(size: 12))
                .fontWeight(.bold)
            
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    let contactCount = min(entry.contacts.count, 3)
                    ForEach(0..<contactCount, id: \.self) { index in
                        let contact = entry.contacts[index]
                        HStack(spacing: 4) {
                            Circle()
                                .fill(colorFromString(contact.color))
                                .frame(width: 6, height: 6)
                            
                            Text(contact.name.split(separator: " ").first ?? "")
                                .font(.system(size: 10))
                        }
                    }
                }
                
                Spacer()
                
                Image(systemName: "clock")
                    .font(.system(size: 16))
            }
            
            if entry.contacts.count > 3 {
                Text("+ \(entry.contacts.count - 3) more")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }
        }
        .padding(8)
    }
    
    var inlineView: some View {
        Text("Family Times")
            .fontWeight(.medium)
    }
    
    var circularView: some View {
        ZStack {
            Circle()
                .stroke(Color.blue, lineWidth: 2)
            
            VStack(spacing: 0) {
                Text("Family")
                    .font(.system(size: 8))
                Text("Times")
                    .font(.system(size: 10, weight: .bold))
            }
        }
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
}

#Preview {
    ContactsLockScreenView(entry: LockScreenEntry(
        date: Date(),
        contacts: [
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
            )
        ]
    ))
    .previewContext(WidgetPreviewContext(family: .accessoryRectangular))
} 