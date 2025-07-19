# FameFit Social Architecture Design

## Overview

This document outlines the technical architecture for transforming FameFit from a single-player fitness tracker into a social fitness platform with gamification through the Influencer XP system.

## Core Concepts

### Dual Currency System

1. **Influencer XP (IXP)**
   - Virtual currency earned through workouts
   - Non-transferable between users
   - Used for in-app rewards and features
   - Server-validated to prevent cheating

2. **Followers**
   - Real user-to-user relationships
   - Builds actual social network
   - Provides social proof and motivation
   - Enables community features

## Technical Architecture

### Data Models

#### User Profile
```swift
struct UserProfile: Codable {
    let id: String // CloudKit recordID
    let username: String // Unique, validated
    let displayName: String
    let bio: String? // 160 char limit
    let profileImageURL: URL?
    let joinDate: Date
    let privacySettings: PrivacySettings
    let stats: UserStats
    let isVerified: Bool // For notable users
}

struct UserStats: Codable {
    let totalXP: Int64
    let currentStreak: Int
    let totalWorkouts: Int
    let favoriteWorkoutType: WorkoutType?
    let weeklyAverage: Double
}

struct PrivacySettings: Codable {
    let profileVisibility: ProfileVisibility
    let requireFollowApproval: Bool
    let showWorkoutDetails: Bool
    let allowMessages: MessagePermission
}
```

#### Social Relationships
```swift
struct FollowRelationship: Codable {
    let id: String
    let followerID: String
    let followingID: String
    let createdAt: Date
    let status: FollowStatus // pending, active, blocked
}

struct SocialActivity: Codable {
    let id: String
    let userID: String
    let type: ActivityType
    let timestamp: Date
    let data: ActivityData
    let visibility: ActivityVisibility
}
```

### CloudKit Schema Updates

#### New Record Types

1. **UserProfile**
   - Indexes: username (unique), displayName
   - References: User record
   - Security: Owner read/write, others read based on privacy

2. **FollowRelationship**
   - Indexes: followerID, followingID, compound(followerID+followingID)
   - Security: Creator read/write, referenced users read

3. **SocialActivity**
   - Indexes: userID, timestamp, type
   - Security: Owner write, followers read

4. **XPTransaction**
   - Indexes: userID, timestamp, type
   - Security: System write only, owner read

### Service Architecture

```swift
// Social networking services
protocol UserProfileServiceProtocol {
    func createProfile(_ profile: UserProfile) async throws
    func updateProfile(_ profile: UserProfile) async throws
    func fetchProfile(username: String) async throws -> UserProfile?
    func searchUsers(query: String) async throws -> [UserProfile]
}

protocol FollowServiceProtocol {
    func follow(userID: String) async throws
    func unfollow(userID: String) async throws
    func getFollowers(for userID: String) async throws -> [UserProfile]
    func getFollowing(for userID: String) async throws -> [UserProfile]
}

protocol FeedServiceProtocol {
    func getFeed(limit: Int, offset: Int) async throws -> [SocialActivity]
    func postActivity(_ activity: SocialActivity) async throws
    func deleteActivity(_ activityID: String) async throws
}

// XP system services
protocol XPServiceProtocol {
    func calculateXP(for workout: HKWorkout) -> Int64
    func addXP(_ amount: Int64, reason: XPReason) async throws
    func getXPBalance() async throws -> Int64
    func getXPHistory(limit: Int) async throws -> [XPTransaction]
}
```

## Security Architecture

### XP Integrity

1. **Server-Side Validation**
   - All XP calculations happen server-side
   - Client sends workout data, server calculates XP
   - Prevents client-side manipulation

2. **Rate Limiting**
   - Maximum XP per day: 10,000
   - Maximum workouts per day: 10
   - Cooldown between workouts: 30 minutes

3. **Audit Trail**
   - Every XP transaction logged
   - Includes source, amount, timestamp, validation hash
   - Anomaly detection for suspicious patterns

### Privacy & Safety

1. **Content Moderation**
   - Username validation against inappropriate terms
   - Bio content filtering
   - Image moderation using Vision framework
   - User reporting system

2. **Age Verification**
   - Birth date required at signup
   - Under 13: Restricted features (COPPA)
   - Under 18: Enhanced privacy defaults

3. **Data Protection**
   - End-to-end encryption for messages
   - Minimal data collection principle
   - Right to deletion (GDPR)
   - Data portability support

## Implementation Phases

### Phase 1: Foundation (4-6 weeks)
- Rename followers to Influencer XP
- Create XP calculation engine
- Update CloudKit schema
- Migration for existing users

### Phase 2: Profiles (3-4 weeks)
- User profile creation/editing
- Username validation system
- Profile image handling
- Privacy settings

### Phase 3: Social Graph (4-5 weeks)
- Follow/Unfollow functionality
- User discovery/search
- Follower/Following lists
- Mutual follow detection

### Phase 4: Activity Feed (3-4 weeks)
- Activity posting system
- Feed generation algorithm
- Real-time updates
- Engagement features

### Phase 5: Gamification (4-5 weeks)
- XP rewards catalog
- Achievement expansion
- Leaderboards
- Seasonal competitions

## Testing Strategy

### Unit Testing
- XP calculation accuracy
- Privacy rule enforcement
- Feed algorithm correctness
- Username validation

### Integration Testing
- CloudKit synchronization
- Cross-device data consistency
- Push notification delivery
- Image upload/download

### Load Testing
- Feed performance with 10k+ activities
- Search performance with 100k+ users
- Concurrent user limits
- CloudKit rate limit handling

### Security Testing
- XP manipulation attempts
- SQL injection in search
- Privacy setting bypass attempts
- Rate limit circumvention

## Performance Optimizations

1. **Caching Strategy**
   - User profiles: 24-hour cache
   - Follow relationships: 1-hour cache
   - Feed content: Incremental updates
   - Images: Progressive loading

2. **Query Optimization**
   - Compound indexes for complex queries
   - Pagination for all list endpoints
   - Batch fetching for related data
   - Background prefetching

3. **Offline Support**
   - Queue XP transactions when offline
   - Cache recent feed content
   - Optimistic UI updates
   - Conflict resolution strategy

## Monitoring & Analytics

1. **Key Metrics**
   - Daily Active Users (DAU)
   - Average XP earned per user
   - Follow/Unfollow ratio
   - Feed engagement rate
   - Content moderation accuracy

2. **Performance Monitoring**
   - API response times
   - CloudKit query performance
   - Cache hit rates
   - Error rates by endpoint

3. **Security Monitoring**
   - Failed XP validation attempts
   - Unusual activity patterns
   - Report/Block statistics
   - Privacy setting changes

## Compliance Checklist

- [ ] Update Privacy Policy
- [ ] Create Terms of Service
- [ ] Implement COPPA compliance
- [ ] Add GDPR data controls
- [ ] Setup CCPA compliance
- [ ] Create Community Guidelines
- [ ] Implement CSAM detection
- [ ] Add Accessibility features
- [ ] Create Data Retention Policy
- [ ] Setup Security Incident Response

## Risk Mitigation

1. **Technical Risks**
   - CloudKit rate limits → Implement caching and queuing
   - Data consistency → Use CKOperation transactions
   - Performance degradation → Progressive feature rollout

2. **Security Risks**
   - XP manipulation → Server validation + anomaly detection
   - Inappropriate content → AI moderation + user reporting
   - Data breaches → Encryption + minimal data collection

3. **Business Risks**
   - User adoption → Gradual rollout with feedback loops
   - Moderation costs → Automated systems + community moderation
   - Compliance violations → Regular audits + legal review

## Success Criteria

1. **Technical Success**
   - 99.9% uptime for social features
   - <500ms average API response time
   - <1% error rate on transactions
   - Zero critical security incidents

2. **User Success**
   - 50% of users create profiles
   - 30% follow at least one user
   - 20% daily engagement with feed
   - 4.5+ star rating maintained

3. **Business Success**
   - 25% increase in user retention
   - 40% increase in daily workouts
   - Positive ROI within 6 months
   - Compliance audit passed

---

Last Updated: 2025-07-18  
Version: 1.0