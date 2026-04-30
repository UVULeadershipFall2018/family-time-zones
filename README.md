# Family Time Zones Widget

An iOS app with widgets for showing multiple family members' and friends' times in different time zones on your home screen and lock screen.

## Features

- Add and manage contacts with different time zones
- Color-code each contact for easy recognition
- Home screen widgets in small, medium, and large sizes
- Lock screen widgets compatible with iOS 16+ lock screen customization
- Automatic time updates

## Setup Instructions

1. **App Groups Configuration**:
   - Before running the app, you need to set up App Groups in your Xcode project
   - Go to your project settings > Signing & Capabilities
   - Add the App Groups capability to both the main app and the widget extension
   - Create a new app group with the identifier: `group.com.tjandtroy.FamilyTimezoneApp`
   - Ensure both targets are checked for this app group

2. **Widget Extension Setup**:
   - In Xcode, select File > New > Target
   - Choose Widget Extension and follow the prompts
   - Name it "FamilyTimeZoneWidget"
   - Link it to your main app

3. **Running the App**:
   - Build and run the app
   - Add your family members and friends with their respective time zones
   - Long-press your home screen to add widgets
   - Choose the "Family Time Zones" widget in the available widgets

## Lock Screen Widgets

To add widgets to your lock screen (iOS 16+):
1. Long-press your lock screen
2. Tap "Customize"
3. Select the area where you want to add a widget
4. Find and add the "Family Times" widget

## Customization

- Each contact can be given a unique color
- Reorder contacts by using the edit mode in the main app
- The widget will show contacts in the order they appear in the app

## Requirements

- iOS 16.0+
- Xcode 14.0+
- SwiftUI 4.0+
- WidgetKit

## Location sharing and CloudKit

The app does **not** use Apple’s Find My APIs. For **paired sharing**, it uses **CloudKit** (public database):

- The **inviter** creates an [`Invitation`](family%20time%20zones/CloudKitInvitationSync.swift) record and shares the `familytimezones://accept?invitation=<uuid>` link. On a real iPhone, **Messages opens with the link already in the body** (and the contact’s **iPhone / mobile** number prefilled when available); otherwise the system **share sheet** is used (e.g. Simulator or no SMS).
- The **invitee** opens the link, verifies the invitation exists in iCloud, then writes an **`InvitationReply`** record (they own that record) with coarse latitude/longitude. The inviter’s app **polls** for replies every ~45s and merges the latest location into the local invitation so time zones can update.

**Requirements:** Both people should be signed into **iCloud** on their iPhones. The app opens **Messages** with text ready (or the share sheet as a fallback); the sender still taps **Send** — nothing is transmitted until they confirm.

**Xcode setup:**

1. Select the **family time zones** app target → **Signing & Capabilities** → **+ Capability** → **iCloud**.
2. Check **CloudKit** and ensure a container is selected. The entitlements file lists `iCloud.TnT.family-time-zones`; if Xcode creates a different default container, either pick that container in the UI or change [`family time zones.entitlements`](family%20time%20zones/family%20time%20zones.entitlements) to match exactly.
3. In **CloudKit Console** (Xcode → Open Developer Tool → CloudKit Console), after first run in **Development**, confirm record types **`Invitation`** and **`InvitationReply`** exist. Add a **Queryable** index on field **`invitationID`** for type `InvitationReply` if queries fail (CloudKit will often hint in the error log).
4. For **production** / TestFlight, deploy the schema from Development to Production in the console.

**Privacy note:** Invitation IDs are unguessable UUIDs, but the **public** database is still readable by any signed-in user of your app who knows a record name. Do not store highly sensitive data in these records.

Custom URL scheme: `familytimezones://accept?invitation=<id>` is handled in [`family_time_zonesApp.swift`](family%20time%20zones/family_time_zonesApp.swift) and [`LocationManager`](family%20time%20zones/LocationManager.swift).

Merged Info.plist keys for the main app live in **[`family-time-zones-Info.plist`](family-time-zones-Info.plist)** at the repository root (the target’s `INFOPLIST_FILE`), combined with generated keys from Xcode build settings.

## Running on a physical iPhone

1. Install **Xcode** from the Mac App Store and open this project.
2. In Xcode, add your Apple ID under **Settings → Accounts** (or **Xcode → Settings → Accounts**).
3. Select the **family time zones** target → **Signing & Capabilities** → choose your **Team** (Personal Team is fine for your own device).
4. Connect your iPhone, select it as the run destination, press **Run** (⌘R).
5. On the phone, if prompted: **Settings → General → VPN & Device Management** → trust your developer app.

For testers who are not on your Mac, use a paid **Apple Developer Program** membership, then **Archive**, upload to **App Store Connect**, and distribute with **TestFlight**.
 