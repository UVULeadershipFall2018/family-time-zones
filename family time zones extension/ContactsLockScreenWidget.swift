import WidgetKit
import SwiftUI

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
    var entry: ContactsProvider.Entry
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
        VStack(alignment: .leading, spacing: 2) {
            ForEach(Array(entry.contacts.prefix(3))) { contact in
                HStack {
                    Circle()
                        .fill(colorFromString(contact.color))
                        .frame(width: 6, height: 6)
                    
                    VStack(alignment: .leading, spacing: 0) {
                        Text(contact.name.split(separator: " ").first ?? "")
                            .font(.system(size: 10))
                            .fontWeight(.medium)
                        
                        Text(contact.locationName())
                            .font(.system(size: 7))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Text(formattedTime(for: contact, at: entry.date))
                        .font(.system(size: 11))
                        .monospacedDigit()
                }
            }
        }
        .padding(.horizontal, 4)
    }
    
    var inlineView: some View {
        if let contact = entry.contacts.first {
            Text("\(contact.name): \(formattedTime(for: contact, at: entry.date)) (\(contact.locationName()))")
        } else {
            Text("No contacts")
        }
    }
    
    var circularView: some View {
        ZStack {
            Circle()
                .stroke(entry.contacts.first.map { colorFromString($0.color) } ?? Color.gray, lineWidth: 2)
            
            VStack(spacing: 0) {
                if let contact = entry.contacts.first {
                    Text(String(contact.name.prefix(3)))
                        .font(.system(size: 8))
                    
                    Text(formattedTime(for: contact, at: entry.date))
                        .font(.system(size: 10, weight: .bold))
                        .monospacedDigit()
                        
                    Text(contact.locationName().prefix(5))
                        .font(.system(size: 6))
                        .foregroundColor(.secondary)
                } else {
                    Text("No")
                        .font(.system(size: 8))
                    
                    Text("data")
                        .font(.system(size: 12, weight: .bold))
                }
            }
        }
    }
    
    // Format time for a specific entry date
    private func formattedTime(for contact: Contact, at date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = contact.timeZone
        formatter.timeStyle = .short
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