# Info.plist Changes for FindMy Location Feature

## Required Privacy Descriptions

Add the following privacy descriptions to your Info.plist file:

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>Your location is used to determine your current time zone and update contacts that share their location with you.</string>

<key>NSContactsUsageDescription</key>
<string>Contacts access is needed to find people who share their location with you for automatic time zone updates.</string>

<key>NSFindMyUsageDescription</key>
<string>FindMy access is used to determine time zones for contacts who share their location with you.</string>
```

## Required Framework Entitlements

When implementing the real FindMy API, you'll need to add the appropriate entitlements to your app:

1. In Xcode, select your app target
2. Go to "Signing & Capabilities"
3. Click "+" to add a capability
4. Add "FindMy" capability (this requires special permission from Apple)

## Testing Notes

Since the FindMy framework requires special entitlements from Apple, this implementation uses mock data for testing. When submitting a request to Apple:

1. Clearly explain that you're using FindMy only for time zone determination, not for tracking
2. Emphasize the privacy-focused approach (only accessing contacts who already share location)
3. Detail the user consent flow for enabling this feature 