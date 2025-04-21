# Find My Location Integration for Family Time Zones

This branch implements a feature that allows the app to automatically determine a contact's time zone based on their shared location through Apple's Find My service.

## How It Works

1. Users can opt-in to use location tracking for any contact
2. They select a person who already shares their location via Find My
3. The app periodically checks the contact's location and updates their time zone
4. Times in the widget always reflect the contact's current time zone

## Implementation Details

### New Files

- `LocationManager.swift`: Handles CoreLocation and Find My integration
- `FindMyContactPicker.swift`: UI component for selecting Find My contacts

### Modified Files

- `ContactModel.swift`: Added location tracking properties
- `ContactViewModel.swift`: Added methods to update time zones based on location
- `ContentView.swift`: Added UI for enabling location tracking
- `InfoPlist_Changes.md`: Instructions for necessary Info.plist changes

## Testing Notes

The implementation uses mock data for FindMy contacts since the real FindMy API requires special entitlements from Apple. To test:

1. Run the app and create or edit a contact
2. Enable "Use Location for Time Zone"
3. Select one of the mock Find My contacts (John, Jane, or Akira)
4. The contact's time zone will be set based on their location

## Production Requirements

To deploy this feature to production:

1. Request FindMy entitlement from Apple Developer Program
2. Update Info.plist with required privacy descriptions
3. Implement the real FindMy API integration (current implementation is a mock)
4. Update privacy policy on your support site

## Privacy Considerations

This feature was designed with privacy in mind:

- Only uses location of contacts who already share location via Find My
- Location data is only used to determine time zone, never stored or shared
- Clear opt-in flow with explicit user consent
- Status indicator shows when automatic updates are active 