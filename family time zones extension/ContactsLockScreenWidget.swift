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