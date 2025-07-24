# Push Notification Service (Backend)

## Overview

The FameFit Push Notification Service is a backend service responsible for sending Apple Push Notifications (APNS) to iOS devices. This service handles all server-side push notification logic including:

- Device token management
- Notification queuing and batching
- APNS communication
- Rate limiting and delivery tracking
- Notification preferences handling

## Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   iOS Apps      │    │  CloudKit       │    │  APNS Service   │
│                 │    │                 │    │                 │
│ - Register      │───▶│ - Device Tokens │◀───│ - Send Notifications │
│   Device Token  │    │ - Notifications │    │ - Handle Responses   │
│ - Receive       │◀───│ - User Prefs    │    │ - Retry Logic        │
│   Notifications │    │                 │    │                      │
└─────────────────┘    └─────────────────┘    └─────────────────────┘
                              │                           ▲
                              │                           │
                              ▼                           │
                       ┌─────────────────┐               │
                       │ Push Service    │──────────────┘
                       │                 │
                       │ - Token Mgmt    │
                       │ - Queue System  │
                       │ - Batch Process │
                       │ - Rate Limiting │
                       └─────────────────┘
```

## Implementation Options

### Option 1: CloudKit Functions (Recommended)
- **Pros**: Integrated with CloudKit, automatic scaling, Apple-managed infrastructure
- **Cons**: Limited control, Apple-specific
- **Best for**: Most apps using CloudKit ecosystem

### Option 2: Custom Server (Node.js/Python/Go)
- **Pros**: Full control, flexible deployment, custom logic
- **Cons**: Infrastructure management, scaling complexity
- **Best for**: Complex notification logic, multi-platform support

### Option 3: Third-Party Service (Firebase, OneSignal)
- **Pros**: Easy setup, managed infrastructure, analytics
- **Cons**: Vendor lock-in, additional costs, less customization
- **Best for**: Rapid development, simple notification needs

## Device Token Management

### Registration Flow
1. iOS app requests notification permission
2. System returns device token
3. App sends token to CloudKit (DeviceTokens record)
4. Backend service monitors for new/updated tokens
5. Tokens are validated and stored for targeting

### Token Lifecycle
- **Active**: Recently updated, valid for notifications
- **Stale**: Not updated recently, should be re-validated
- **Invalid**: APNS reported as invalid, should be removed
- **Expired**: Not seen for extended period, cleanup candidate

## Notification Types & Triggers

### Workout Notifications
```javascript
// Workout completion
{
  type: "workout_completed",
  trigger: "WorkoutHistory record created",
  target: "workout owner + followers",
  timing: "immediate",
  data: {
    workoutId: "uuid",
    workoutType: "Running", 
    xpEarned: 25,
    duration: 1800
  }
}
```

### Social Notifications
```javascript
// New follower
{
  type: "new_follower", 
  trigger: "UserRelationships record created",
  target: "followed user",
  timing: "immediate",
  data: {
    followerID: "uuid",
    followerName: "John Doe",
    followerUsername: "johndoe"
  }
}

// Workout comment
{
  type: "workout_comment",
  trigger: "WorkoutComments record created", 
  target: "workout owner",
  timing: "immediate",
  data: {
    commentId: "uuid",
    workoutId: "uuid",
    commenterName: "Jane Smith",
    commentPreview: "Great workout!"
  }
}
```

### Group Workout Notifications
```javascript
// Group workout starting
{
  type: "group_workout_starting",
  trigger: "scheduled time - 15 minutes",
  target: "all participants",
  timing: "scheduled",
  data: {
    workoutId: "uuid",
    workoutName: "Morning Run Club",
    startTime: "2024-01-15T08:00:00Z"
  }
}
```

## Batching & Rate Limiting

### Notification Batching
- **Immediate**: Critical notifications (mentions, challenges)
- **Batched**: Non-urgent notifications grouped by type
- **Scheduled**: Time-based notifications (workout reminders)

### Rate Limiting
- Per user: Maximum notifications per hour/day
- Per type: Different limits for different notification types
- Global: Overall system rate limits to prevent APNS throttling

## Sample Implementation (Node.js)

```javascript
// Push Notification Service
class PushNotificationService {
  constructor(apnsProvider, cloudKit, config) {
    this.apns = apnsProvider;
    this.cloudKit = cloudKit;
    this.config = config;
    this.notificationQueue = new Queue();
  }

  async initialize() {
    // Start CloudKit change monitoring
    await this.startCloudKitSubscriptions();
    
    // Start notification processing worker
    this.startNotificationWorker();
    
    // Start batch processor
    this.startBatchProcessor();
  }

  async startCloudKitSubscriptions() {
    // Subscribe to relevant record changes
    const subscriptions = [
      'WorkoutHistory',
      'UserRelationships', 
      'WorkoutComments',
      'GroupWorkouts'
    ];

    for (const recordType of subscriptions) {
      await this.cloudKit.subscribe(recordType, (change) => {
        this.handleRecordChange(recordType, change);
      });
    }
  }

  handleRecordChange(recordType, change) {
    switch (recordType) {
      case 'WorkoutHistory':
        if (change.type === 'CREATE') {
          this.queueWorkoutNotification(change.record);
        }
        break;
        
      case 'UserRelationships':
        if (change.type === 'CREATE') {
          this.queueFollowNotification(change.record);
        }
        break;
        
      case 'WorkoutComments':
        if (change.type === 'CREATE') {
          this.queueCommentNotification(change.record);
        }
        break;
    }
  }

  async queueWorkoutNotification(workoutRecord) {
    // Get workout owner's followers
    const followers = await this.getWorkoutFollowers(workoutRecord.userId);
    
    // Create notification for each follower
    for (const follower of followers) {
      const notification = {
        userId: follower.userId,
        type: 'workout_completed',
        priority: 'normal',
        data: {
          workoutId: workoutRecord.id,
          ownerName: workoutRecord.ownerName,
          workoutType: workoutRecord.workoutType,
          xpEarned: workoutRecord.xpEarned
        }
      };
      
      await this.notificationQueue.add(notification);
    }
  }

  async processNotification(notification) {
    try {
      // Get device tokens for user
      const deviceTokens = await this.getDeviceTokens(notification.userId);
      
      // Check user preferences
      const preferences = await this.getUserPreferences(notification.userId);
      if (!this.shouldSendNotification(notification.type, preferences)) {
        return;
      }

      // Build APNS payload
      const payload = this.buildAPNSPayload(notification);
      
      // Send to all user's devices
      const results = await Promise.allSettled(
        deviceTokens.map(token => this.sendAPNS(token, payload))
      );
      
      // Handle failed tokens
      await this.handleAPNSResults(results, deviceTokens);
      
    } catch (error) {
      console.error('Failed to process notification:', error);
      // Implement retry logic
    }
  }

  buildAPNSPayload(notification) {
    const base = {
      aps: {
        alert: {
          title: this.getNotificationTitle(notification),
          body: this.getNotificationBody(notification)
        },
        badge: 1,
        sound: 'default'
      },
      customData: {
        type: notification.type,
        ...notification.data
      }
    };

    return base;
  }

  async sendAPNS(deviceToken, payload) {
    const notification = new apn.Notification();
    notification.payload = payload;
    notification.topic = 'com.jimmypocock.FameFit';
    
    return await this.apns.send(notification, deviceToken);
  }
}

module.exports = PushNotificationService;
```

## Deployment

### CloudKit Functions (Recommended)
```bash
# Deploy to CloudKit
cloudkit deploy push-service-function.js

# Monitor logs
cloudkit logs --function push-service
```

### Custom Server Deployment
```bash
# Docker deployment
docker build -t famefit-push-service .
docker run -d --name push-service \
  -e APNS_KEY_ID=your_key_id \
  -e APNS_TEAM_ID=your_team_id \
  -e CLOUDKIT_API_TOKEN=your_token \
  famefit-push-service

# Kubernetes deployment
kubectl apply -f push-service-deployment.yaml
```

## Monitoring & Analytics

### Key Metrics
- Notification delivery rate
- User engagement rate (opens, actions)
- Device token health
- Processing latency
- Error rates by notification type

### Alerting
- APNS rate limit warnings
- High error rates
- Processing queue backup
- Device token validation failures

## Security Considerations

### Authentication
- APNS certificate/key management
- CloudKit API token rotation
- Service-to-service authentication

### Data Privacy
- User consent tracking
- Notification content minimization
- PII handling in payloads
- Retention policies for logs/data

### Rate Limiting Protection
- User-level rate limiting
- IP-based throttling
- APNS feedback handling
- Graceful degradation

## Testing

### Development Testing
```javascript
// Test notification sending
const testService = new PushNotificationService(mockAPNS, mockCloudKit);

// Test individual notification
await testService.sendTestNotification({
  userId: 'test-user',
  type: 'workout_completed',
  data: { workoutId: 'test-workout' }
});

// Test batch processing
await testService.processBatch([...notifications]);
```

### Load Testing
- Simulate high notification volumes
- Test APNS rate limiting handling  
- Verify queue processing performance
- Monitor memory/CPU usage under load

## Future Enhancements

### Advanced Features
- **Rich Notifications**: Images, videos, interactive buttons
- **Notification Channels**: Categorized notification management
- **A/B Testing**: Notification content/timing optimization
- **Analytics Integration**: Deep engagement tracking
- **Smart Scheduling**: AI-powered optimal send times

### Scalability
- **Multi-region Deployment**: Global latency optimization
- **Auto-scaling**: Dynamic capacity adjustment
- **Caching Layer**: Redis/Memcached for frequently accessed data
- **Message Queue**: RabbitMQ/Kafka for high-throughput processing

This backend push notification service provides the foundation for reliable, scalable push notifications in the FameFit ecosystem, handling all the complexity of APNS communication while providing rich notification experiences for users.