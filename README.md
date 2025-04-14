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