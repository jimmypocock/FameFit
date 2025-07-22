# Push Notifications Setup Guide

This guide explains how to set up Apple Push Notification Service (APNS) for FameFit.

## 1. Enable Push Notifications Capability

### In Xcode:

1. Select the FameFit project in the navigator
2. Select the FameFit target
3. Go to the "Signing & Capabilities" tab
4. Click the "+" button to add a capability
5. Select "Push Notifications"
6. Xcode will automatically update your entitlements file

### Required Entitlements:

The following will be added to your entitlements file:
```xml
<key>aps-environment</key>
<string>development</string>
```

For production builds, this will automatically change to:
```xml
<key>aps-environment</key>
<string>production</string>
```

## 2. Configure App ID in Apple Developer Portal

1. Log in to [Apple Developer Portal](https://developer.apple.com)
2. Go to Certificates, Identifiers & Profiles
3. Select your App ID (com.jimmypocock.FameFit)
4. Enable "Push Notifications" capability
5. Click "Configure" next to Push Notifications
6. Create certificates for Development and Production

## 3. CloudKit Schema for Push Notifications

### DeviceTokens Record Type:
```
- userID: String (Reference)
- deviceToken: String
- platform: String ("iOS" or "watchOS")
- appVersion: String
- osVersion: String
- environment: String ("development" or "production")
- lastUpdated: Date/Time
- isActive: Int64
```

### PushNotificationQueue Record Type (for server-side processing):
```
- userID: String
- notificationType: String
- title: String
- body: String
- subtitle: String (optional)
- badge: Int64 (optional)
- sound: String (optional)
- category: String (optional)
- threadId: String (optional)
- deviceTokens: [String]
- metadata: String (JSON)
- createdAt: Date/Time
- status: String ("pending", "sent", "failed")
```

## 4. Testing Push Notifications

### Simulator Testing:
- Push notifications can be tested in the iOS Simulator (iOS 16+)
- Use the "Device" menu → "Trigger Push Notification..."
- Or drag an APNS file onto the simulator

### Sample APNS File (save as .apns):
```json
{
    "Simulator Target Bundle": "com.jimmypocock.FameFit",
    "aps": {
        "alert": {
            "title": "New Follower! 🎉",
            "body": "FitnessGuru is now following your fitness journey"
        },
        "badge": 1,
        "sound": "default"
    },
    "notificationType": "newFollower",
    "followerUserId": "test-user-123",
    "followerUsername": "FitnessGuru"
}
```

### Device Testing:
1. Ensure you have a valid provisioning profile with push notifications enabled
2. Install the app on a physical device
3. Grant notification permissions when prompted
4. Use CloudKit Dashboard or server-side code to trigger notifications

## 5. Implementation Status

### ✅ Completed:
- APNSManager service for handling device tokens and notifications
- AppDelegate integration for push notification callbacks
- NotificationPermissionView for requesting permissions
- CloudKitPushNotificationService for sending notifications
- Badge count management integrated with NotificationStore
- Push notification status in NotificationSettingsView

### ⏳ Pending:
- Server-side component for actually sending push notifications
- CloudKit function or external service integration
- Production push notification certificates

## 6. Server-Side Implementation Options

### Option 1: CloudKit Web Services
- Use CloudKit JS or REST API
- Requires server-side component to process PushNotificationQueue records
- Can be implemented as a scheduled job

### Option 2: Third-Party Service
- Integrate with services like Firebase Cloud Messaging
- OneSignal, Pusher, or similar
- Requires additional SDK integration

### Option 3: Custom Server
- Node.js/Swift Vapor server with APNS integration
- Direct control over notification delivery
- Can batch and optimize notification sending

## 7. Security Considerations

1. **Device Token Storage**: Tokens are stored in private CloudKit database
2. **Token Rotation**: Tokens can change; always use the latest
3. **Rate Limiting**: Implement rate limiting to prevent spam
4. **Privacy**: Never expose device tokens in logs or analytics
5. **Cleanup**: Remove inactive tokens periodically

## 8. Troubleshooting

### Common Issues:

1. **"Not Registered" Error**:
   - Check provisioning profile includes push notifications
   - Verify App ID configuration in Developer Portal

2. **Notifications Not Received**:
   - Check device notification settings
   - Verify correct environment (dev/prod)
   - Check CloudKit device token records

3. **Badge Not Updating**:
   - Ensure app has badge permission
   - Check NotificationStore integration

### Debug Tools:
- Console app on macOS to view device logs
- Xcode device console for debugging
- CloudKit Dashboard to inspect records

## 9. Best Practices

1. **Request Permission Thoughtfully**: Show value before asking
2. **Respect User Preferences**: Honor notification settings
3. **Batch Notifications**: Avoid overwhelming users
4. **Rich Notifications**: Use categories for quick actions
5. **Localization**: Localize notification content
6. **Testing**: Test on multiple devices and OS versions