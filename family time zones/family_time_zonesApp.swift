//
//  family_time_zonesApp.swift
//  family time zones
//
//  Created by TJ Nielsen on 4/12/25.
//

import SwiftUI

extension Notification.Name {
    /// Posted after `familytimezones://` invitation URL is handled (same name as legacy SceneDelegate flow).
    static let locationSharingInvitationHandled = Notification.Name("LocationSharingInvitationAccepted")
}

@main
struct family_time_zonesApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL { url in
                    if LocationManager.shared.handleInvitationDeepLink(url: url) {
                        NotificationCenter.default.post(name: .locationSharingInvitationHandled, object: nil)
                    }
                }
        }
    }
}
