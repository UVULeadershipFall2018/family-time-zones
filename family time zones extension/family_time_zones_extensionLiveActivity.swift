//
//  family_time_zones_extensionLiveActivity.swift
//  family time zones extension
//
//  Created by TJ Nielsen on 4/12/25.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct family_time_zones_extensionAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct family_time_zones_extensionLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: family_time_zones_extensionAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Text("Hello \(context.state.emoji)")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom \(context.state.emoji)")
                    // more content
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T \(context.state.emoji)")
            } minimal: {
                Text(context.state.emoji)
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
        }
    }
}

extension family_time_zones_extensionAttributes {
    fileprivate static var preview: family_time_zones_extensionAttributes {
        family_time_zones_extensionAttributes(name: "World")
    }
}

extension family_time_zones_extensionAttributes.ContentState {
    fileprivate static var smiley: family_time_zones_extensionAttributes.ContentState {
        family_time_zones_extensionAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: family_time_zones_extensionAttributes.ContentState {
         family_time_zones_extensionAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: family_time_zones_extensionAttributes.preview) {
   family_time_zones_extensionLiveActivity()
} contentStates: {
    family_time_zones_extensionAttributes.ContentState.smiley
    family_time_zones_extensionAttributes.ContentState.starEyes
}
