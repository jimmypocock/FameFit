# FameFit Notification Architecture

This document outlines the comprehensive notification system for FameFit, ensuring users receive timely, relevant, and non-spammy notifications for social interactions and achievements.

## Design Principles

1. **User-Centric**: Notifications should add value, not annoyance
2. **Contextual**: Right notification at the right time
3. **Configurable**: Granular user control over notification types
4. **Rate-Limited**: Prevent notification spam through intelligent batching
5. **Privacy-First**: Respect user settings and relationships
6. **Testable**: Mock-friendly architecture for comprehensive testing

## Notification Categories

### 1. Workout Notifications (Existing)
- **Workout Completed**: Character-based encouragement after workouts
- **XP Milestones**: Level ups and unlock achievements
- **Streak Reminders**: Maintaining workout consistency

### 2. Social Notifications (New)
- **New Follower**: When someone follows you
- **Friend Request**: For private profiles
- **Workout Kudos**: When someone cheers your workout
- **Workout Comment**: When someone comments on your activity
- **Mention**: When tagged in a comment or challenge
- **Challenge Invite**: Workout challenge invitations
- **Leaderboard Changes**: Moving up/down in rankings

### 3. System Notifications (New)
- **Security Alerts**: Suspicious login attempts
- **Privacy Updates**: Changes to privacy policies
- **Feature Announcements**: New features available
- **Maintenance Notices**: Scheduled downtime

## Notification Channels

### 1. Push Notifications
- **Local**: Immediate notifications (XP unlocks, reminders)
- **Remote**: Server-triggered (social interactions, challenges)
- **Silent**: Background updates (feed refresh, sync)

### 2. In-App Notifications
- **Notification Center**: Persistent list of all notifications
- **Badge Count**: Unread notification indicator
- **Banner Alerts**: Temporary in-app alerts

### 3. Apple Watch
- **Haptic Feedback**: Gentle taps for important events
- **Complications**: Quick glance notification count
- **Rich Notifications**: Actionable workout summaries

## User Preferences Schema

```swift
struct NotificationPreferences: Codable {
    // Master switches
    var pushNotificationsEnabled: Bool = true
    var inAppNotificationsEnabled: Bool = true
    var soundEnabled: Bool = true
    var badgeEnabled: Bool = true
    
    // Workout notifications
    var workoutCompleted: NotificationSetting = .enabled
    var xpMilestones: NotificationSetting = .enabled
    var streakReminders: NotificationSetting = .enabled
    var dailyGoalReminders: NotificationSetting = .disabled
    
    // Social notifications
    var newFollowers: NotificationSetting = .enabled
    var followRequests: NotificationSetting = .immediate
    var workoutKudos: NotificationSetting = .batched
    var workoutComments: NotificationSetting = .immediate
    var mentions: NotificationSetting = .immediate
    var challengeInvites: NotificationSetting = .enabled
    var leaderboardChanges: NotificationSetting = .weekly
    
    // Quiet hours
    var quietHoursEnabled: Bool = false
    var quietHoursStart: Date = DateComponents(hour: 22).date!
    var quietHoursEnd: Date = DateComponents(hour: 8).date!
    
    // Rate limiting
    var maxNotificationsPerHour: Int = 10
    var batchingWindowMinutes: Int = 15
}

enum NotificationSetting: String, Codable {
    case disabled       // Never notify
    case enabled        // Notify immediately
    case batched        // Group notifications
    case immediate      // Always immediate, ignore batching
    case daily          // Once per day summary
    case weekly         // Once per week summary
}
```

## Rate Limiting & Batching

### Intelligent Batching Algorithm
```swift
class NotificationBatcher {
    private var pendingNotifications: [NotificationType: [PendingNotification]] = [:]
    private var batchingTimers: [NotificationType: Timer] = [:]
    
    func shouldBatch(_ notification: Notification) -> Bool {
        // Always send immediately for:
        // - Direct messages/mentions
        // - Security alerts
        // - User-initiated actions (follow requests)
        guard notification.priority != .immediate else { return false }
        
        // Check rate limits
        let recentCount = getRecentNotificationCount(in: .hour)
        if recentCount >= preferences.maxNotificationsPerHour {
            return true // Force batching when at limit
        }
        
        // Check user preference for this type
        return notification.type.preferredSetting == .batched
    }
    
    func addToBatch(_ notification: Notification) {
        pendingNotifications[notification.type, default: []].append(notification)
        scheduleBatchDelivery(for: notification.type)
    }
}
```

### Smart Grouping
- **Similar notifications**: "3 people kudos'd your morning run"
- **Time-based**: Group notifications within 15-minute windows
- **Context-aware**: Don't batch during active app usage

## Privacy & Security

### Notification Content
```swift
extension Notification {
    func sanitizedContent(for privacyLevel: PrivacyLevel) -> (title: String, body: String) {
        switch privacyLevel {
        case .public:
            return (title, body) // Full content
            
        case .friendsOnly:
            // Show sender name only if they're a friend
            if relationship == .mutual {
                return (title, body)
            } else {
                return ("FameFit", "You have a new notification")
            }
            
        case .private:
            // Never show details in notifications
            return ("FameFit", "You have a new notification")
        }
    }
}
```

### Data Protection
- Notification content encrypted at rest
- No PII in push notification payloads
- Tokens rotated regularly
- Failed delivery tracking for security monitoring

## Implementation Plan

### Phase 1: Foundation (Week 1)
1. **Enhanced NotificationItem Model**
   - Add notification type enum
   - Add priority levels
   - Add action metadata
   - Add grouping support

2. **NotificationPreferences Service**
   - User preference storage
   - Default preference sets
   - Migration from existing settings

3. **NotificationScheduler**
   - Rate limiting logic
   - Batching algorithm
   - Quiet hours enforcement

### Phase 2: Push Infrastructure (Week 1-2)
1. **Remote Notification Setup**
   - APNS certificate configuration
   - Server-side integration
   - Token management
   - Delivery tracking

2. **Rich Notifications**
   - Notification Service Extension
   - Custom UI for workout summaries
   - Action buttons (Kudos, View, Dismiss)

3. **Background Refresh**
   - Silent notification handling
   - Feed updates
   - Badge count sync

### Phase 3: Social Notifications (Week 2)
1. **Event Triggers**
   - Follow/unfollow events
   - Kudos and comments
   - Challenge system
   - Leaderboard changes

2. **Notification Center UI**
   - Grouped notification display
   - Mark as read functionality
   - Swipe actions
   - Pull to refresh

3. **In-App Banners**
   - Non-intrusive alerts
   - Auto-dismiss timing
   - Action buttons

### Phase 4: Testing & Polish (Week 3)
1. **Comprehensive Testing**
   - Unit tests for all components
   - Integration tests for delivery
   - UI tests for notification center
   - Performance testing at scale

2. **Analytics**
   - Delivery success rates
   - User engagement metrics
   - Opt-out tracking
   - A/B testing framework

## Testing Strategy

### Mock Notification Service
```swift
class MockNotificationService: NotificationServicing {
    var scheduledNotifications: [ScheduledNotification] = []
    var deliveredNotifications: [DeliveredNotification] = []
    var preferences = NotificationPreferences()
    
    func scheduleNotification(_ notification: Notification) {
        // Track for testing
        scheduledNotifications.append(
            ScheduledNotification(
                notification: notification,
                scheduledAt: Date(),
                willBatch: shouldBatch(notification)
            )
        )
    }
}
```

### Test Scenarios
1. **Rate Limiting**: Verify spam prevention
2. **Batching**: Ensure proper grouping
3. **Quiet Hours**: No notifications during sleep
4. **Privacy**: Content filtering based on settings
5. **Delivery**: Reliable notification arrival

## Success Metrics

1. **User Satisfaction**
   - < 5% opt-out rate
   - > 80% keep defaults
   - Positive app store reviews

2. **Technical Performance**
   - 99.9% delivery success
   - < 100ms scheduling time
   - < 1% duplicate delivery

3. **Engagement**
   - 60% notification open rate
   - 40% action taken rate
   - Increased daily active users

## Anti-Patterns to Avoid

1. **Notification Spam**
   - Too many kudos notifications
   - Redundant information
   - Marketing disguised as notifications

2. **Privacy Violations**
   - Showing usernames to non-friends
   - Leaking workout details
   - Location information

3. **Poor Timing**
   - Late night notifications
   - During Do Not Disturb
   - While user is active in app

4. **Technical Issues**
   - Duplicate notifications
   - Stale badge counts
   - Lost notifications

## Future Enhancements

1. **Machine Learning**
   - Optimal delivery timing
   - Personalized batching
   - Engagement prediction

2. **Rich Media**
   - Workout route previews
   - Achievement animations
   - Profile photos in notifications

3. **Cross-Platform**
   - Web notifications
   - Email digests
   - SMS fallback for critical alerts