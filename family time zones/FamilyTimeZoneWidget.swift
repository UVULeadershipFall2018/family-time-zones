import WidgetKit
import SwiftUI

// IMPORTANT: This file is now obsolete and has been moved to the widget extension target.
// It should be removed from the main app target.
// The widget implementation is now in the "family time zones extension" folder.

// Remove @main since this should be in a separate target from the main app
// When you create the proper widget extension, add @main back
struct FamilyTimeZoneWidgets: WidgetBundle {
    var body: some Widget {
        ContactsWidget()
        ContactsLockScreenWidget()
    }
}

// Lock screen version with simpler UI for lock screen
struct ContactsLockScreenWidget: Widget {
    let kind: String = "ContactsLockScreenWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            ContactsLockScreenView(entry: entry)
        }
        .configurationDisplayName("Family Times (Lock Screen)")
        .description("Shows family times on your lock screen.")
        .supportedFamilies([.accessoryRectangular, .accessoryInline, .accessoryCircular])
    }
}

struct ContactsLockScreenView: View {
    var entry: Provider.Entry
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
                        .fill(Color(contact.color))
                        .frame(width: 6, height: 6)
                    
                    Text(contact.name.split(separator: " ").first ?? "")
                        .font(.system(size: 11))
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Text(contact.formattedTime())
                        .font(.system(size: 11))
                        .monospacedDigit()
                }
            }
        }
        .padding(.horizontal, 4)
    }
    
    var inlineView: some View {
        if let contact = entry.contacts.first {
            Text("\(contact.name): \(contact.formattedTime())")
        } else {
            Text("No contacts")
        }
    }
    
    var circularView: some View {
        ZStack {
            Circle()
                .stroke(Color(entry.contacts.first?.color ?? "gray"), lineWidth: 2)
            
            VStack(spacing: 0) {
                if let contact = entry.contacts.first {
                    Text(String(contact.name.prefix(3)))
                        .font(.system(size: 8))
                    
                    Text(contact.formattedTime())
                        .font(.system(size: 12, weight: .bold))
                        .monospacedDigit()
                } else {
                    Text("No")
                        .font(.system(size: 8))
                    
                    Text("data")
                        .font(.system(size: 12, weight: .bold))
                }
            }
        }
    }
} 