# CloudKit Schema Documentation

This document defines all CloudKit record types and their fields used in FameFit.

## Important Notes

1. **System Fields**: CloudKit automatically provides these fields on every record:
   - `recordName` (String) - Unique identifier
   - `creationDate` (Date) - When the record was created
   - `modificationDate` (Date) - When the record was last modified
   - `recordChangeTag` (String) - Used for conflict resolution
   
2. **Queryable Fields**: Only system fields (`creationDate`, `modificationDate`) are queryable by default. Custom fields must be manually marked as queryable in CloudKit Dashboard.

3. **Sortable Fields**: Only queryable fields can be used in sort descriptors.

4. **CRITICAL - recordID Index**: When creating any new record type that will be queried with `NSPredicate(value: true)` or similar queries, you MUST add `___recordID` as a QUERYABLE index in CloudKit Dashboard. This prevents the "Field 'recordName' is not marked queryable" error.

## Database Overview

FameFit uses multiple CloudKit databases:
- **Private Database**: Personal data, settings, workout history
- **Public Database**: User profiles, leaderboards, discoverable content
- **Shared Database**: (Future) Friend connections, group challenges

### Data Architecture Principles

1. **Single Source of Truth**: User statistics (XP, workout count, etc.) are stored ONLY in the private `Users` table
2. **Public Cache**: The `UserProfiles` table in the public database contains cached copies for social features
3. **One-way Sync**: Data flows from Users → UserProfiles, never the reverse
4. **Privacy First**: Only data explicitly marked as public is synced to the public database

## Record Types

### Private Database

#### Users
Stores user profile information.

| Field | Type | Required | Queryable | Indexed | Description |
|-------|------|----------|-----------|---------|-------------|
| displayName | String | Yes | Yes | No | Display name |
| influencerXP | Int64 | Yes* | Yes | Yes | DEPRECATED - Use totalXP |
| totalXP | Int64 | Yes | Yes | Yes | Total XP earned (source of truth) |
| totalWorkouts | Int64 | Yes | Yes | Yes | Total workouts completed (source of truth) |
| currentStreak | Int64 | Yes | Yes | No | Current workout streak |
| lastWorkoutTimestamp | Date | No | Yes | No | Last workout date |
| joinTimestamp | Date | Yes | Yes | No | When user joined |

*Note: This is the source of truth for all user statistics. The public UserProfiles table contains cached copies of these values.*

**Migration Note**: The `influencerXP` field is deprecated but kept for backward compatibility. The app writes to both `influencerXP` and `totalXP` fields but reads preferentially from `totalXP`.

#### WorkoutHistory
Stores individual workout records.

| Field | Type | Required | Queryable | Indexed | Description |
|-------|------|----------|-----------|---------|-------------|
| workoutId | String | Yes | Yes | Yes | UUID of the workout |
| workoutType | String | Yes | Yes | Yes | Type of workout (Running, Cycling, etc.) |
| startDate | Date | Yes | Yes | Yes | Workout start time |
| endDate | Date | Yes | Yes | Yes | Workout end time |
| duration | Double | Yes | Yes | No | Duration in seconds |
| totalEnergyBurned | Double | Yes | Yes | No | Calories burned |
| totalDistance | Double | No | Yes | No | Distance in meters |
| averageHeartRate | Double | No | Yes | No | Average heart rate |
| followersEarned | Int64 | Yes* | Yes | No | Followers earned from workout (DEPRECATED - use xpEarned) |
| xpEarned | Int64 | Yes | Yes | No | XP earned from workout |
| source | String | Yes | Yes | No | Source app (e.g., "Apple Watch") |

*Note: `followersEarned` is maintained for backward compatibility during migration to `xpEarned`

#### UserSettings (NEW)
Stores user privacy and notification preferences.

| Field | Type | Required | Queryable | Indexed | Description |
|-------|------|----------|-----------|---------|-------------|
| userID | String | Yes | Yes | Yes | Reference to UserProfile record ID |
| emailNotifications | Int64 | Yes | No | No | 1 = enabled, 0 = disabled |
| pushNotifications | Int64 | Yes | No | No | 1 = enabled, 0 = disabled |
| workoutPrivacy | String | Yes | Yes | No | Values: "public", "friends", "private" |
| allowMessages | String | Yes | Yes | No | Values: "all", "friends", "none" |
| blockedUsers | String List | No | No | No | Array of blocked user IDs |
| mutedUsers | String List | No | No | No | Array of muted user IDs |
| contentFilter | String | Yes | No | No | Values: "strict", "moderate", "off" |
| showWorkoutStats | Int64 | Yes | No | No | 1 = show, 0 = hide |
| allowFriendRequests | Int64 | Yes | No | No | 1 = allow, 0 = disallow |
| showOnLeaderboards | Int64 | Yes | No | No | 1 = show, 0 = hide |

#### FollowRequests (NEW)
Stores follow requests for private profiles.

| Field | Type | Required | Queryable | Indexed | Description |
|-------|------|----------|-----------|---------|-------------|
| requesterId | String | Yes | Yes | Yes | User ID of requester |
| targetId | String | Yes | Yes | Yes | User ID of target |
| status | String | Yes | Yes | Yes | Values: "pending", "accepted", "rejected", "expired" |
| createdAt | Date | Yes | Yes | Yes | Request creation timestamp |
| message | String | No | No | No | Optional message (max 280 chars) |
| expiresAt | Date | Yes | Yes | Yes | Request expiration date |

#### DeviceTokens (NEW)
Stores device tokens for Apple Push Notification Service (APNS).

| Field | Type | Required | Queryable | Indexed | Description |
|-------|------|----------|-----------|---------|-------------|
| userID | String | Yes | Yes | Yes | Reference to user's record ID |
| deviceToken | String | Yes | Yes | Yes | Unique device token from APNS |
| platform | String | Yes | Yes | No | Values: "iOS", "watchOS" |
| appVersion | String | Yes | No | No | App version when token was registered |
| osVersion | String | Yes | No | No | OS version when token was registered |
| environment | String | Yes | Yes | No | Values: "development", "production" |
| lastUpdated | Date | Yes | Yes | Yes | When token was last updated |
| isActive | Int64 | Yes | Yes | No | 1 = active, 0 = inactive |

### Public Database

#### UserProfiles (NEW)
Stores public user profile information.

| Field | Type | Required | Queryable | Indexed | Description |
|-------|------|----------|-----------|---------|-------------|
| userID | String | Yes | Yes | Yes | Reference to Users.recordID |
| username | String | Yes | Yes | Yes | Unique username (3-30 chars, lowercase) |
| displayName | String | Yes | Yes | No | Display name (1-50 characters) |
| bio | String | No | No | No | User bio (0-500 characters) |
| profileImageURL | String | No | No | No | URL to profile image asset |
| headerImageURL | String | No | No | No | URL to header/banner image asset |
| workoutCount | Int64 | Yes | Yes | Yes | Cached from Users table |
| totalXP | Int64 | Yes | Yes | Yes | Cached from Users table |
| joinedDate | Date | Yes | Yes | Yes | Cached from Users table |
| lastUpdated | Date | Yes | Yes | Yes | When profile was last synced |
| isVerified | Int64 | No | Yes | No | 1 = verified account, 0 = regular |
| privacyLevel | String | Yes | Yes | No | Values: "public", "friends", "private" |

#### UserRelationships (NEW)
Stores social following relationships between users.

| Field | Type | Required | Queryable | Indexed | Description |
|-------|------|----------|-----------|---------|-------------|
| followerID | String | Yes | Yes | Yes | User ID of follower |
| followingID | String | Yes | Yes | Yes | User ID being followed |
| status | String | Yes | Yes | No | Values: "active", "blocked", "muted" |
| notificationsEnabled | Int64 | Yes | No | No | 1 = notifications on, 0 = off |

**System Fields** (automatically provided):
- createdTimestamp (Date) - When the record was created
- modificationTimestamp (Date) - When the record was last modified
- recordName (String) - Unique identifier: "\(followerID)_follows_\(followingID)"

**Required Indexes**:
- followerID (QUERYABLE, SORTABLE)
- followingID (QUERYABLE, SORTABLE)
- status (QUERYABLE)
- ___recordID (QUERYABLE) - Critical for preventing query errors

#### ActivityFeedItems (NEW)
Stores user activities for social feeds.

| Field | Type | Required | Queryable | Indexed | Description |
|-------|------|----------|-----------|---------|-------------|
| userID | String | Yes | Yes | Yes | User ID who created the activity |
| activityType | String | Yes | Yes | Yes | Values: "workout", "achievement", "milestone", "level_up" |
| workoutId | String | No | Yes | No | Reference to workout (if applicable) |
| content | String | Yes | No | No | Activity content (encrypted) |
| visibility | String | Yes | Yes | No | Values: "public", "followers", "private" |
| createdAt | Date | Yes | Yes | Yes | Activity creation timestamp |
| expiresAt | Date | Yes | Yes | Yes | Auto-cleanup timestamp |
| xpEarned | Int64 | No | Yes | No | XP earned (for workout activities) |
| achievementName | String | No | Yes | No | Achievement name (for achievements) |

#### WorkoutKudos (NEW)
Stores kudos/cheers (likes) for workouts.

| Field | Type | Required | Queryable | Indexed | Description |
|-------|------|----------|-----------|---------|-------------|
| workoutId | String | Yes | Yes | Yes | ID of the workout |
| userID | String | Yes | Yes | Yes | User ID who gave kudos |
| workoutOwnerId | String | Yes | Yes | Yes | User ID who owns the workout |
| createdAt | Date | Yes | Yes | Yes | When kudos was given |

**Required Indexes**:
- Compound index: workoutId + userId (uniqueness constraint)
- workoutId (for fetching all kudos for a workout)
- userID (for fetching all kudos by a user)
- workoutOwnerId (for notifications)
- createdAt (for rate limiting)

#### WorkoutComments (NEW)
Stores comments on workout activities.

| Field | Type | Required | Queryable | Indexed | Description |
|-------|------|----------|-----------|---------|-------------|
| workoutId | String | Yes | Yes | Yes | ID of the workout |
| userId | String | Yes | Yes | Yes | User ID who posted comment |
| workoutOwnerId | String | Yes | Yes | Yes | User ID who owns the workout |
| content | String | Yes | No | No | Comment content (max 500 chars) |
| createdAt | Date | Yes | Yes | Yes | When comment was posted |
| updatedAt | Date | Yes | Yes | No | When comment was last edited |
| parentCommentId | String | No | Yes | No | For threaded replies |
| isEdited | Int64 | Yes | No | No | 1 = edited, 0 = not edited |
| likeCount | Int64 | Yes | No | No | Number of likes on comment |

**Required Indexes**:
- workoutId (for fetching all comments for a workout)
- userId (for fetching all comments by a user)
- createdAt (for sorting chronologically)
- parentCommentId (for threaded comment retrieval)

#### WorkoutChallenges (NEW)
Stores workout challenges between users.

| Field | Type | Required | Queryable | Indexed | Description |
|-------|------|----------|-----------|---------|-------------|
| creatorId | String | Yes | Yes | Yes | User ID who created challenge |
| participants | Data | Yes | No | No | JSON array of participants |
| type | String | Yes | Yes | Yes | Challenge type (distance, duration, etc.) |
| targetValue | Double | Yes | No | No | Target value to achieve |
| workoutType | String | No | Yes | No | Specific workout type (if applicable) |
| name | String | Yes | Yes | No | Challenge name |
| description | String | Yes | No | No | Challenge description |
| startDate | Date | Yes | Yes | Yes | When challenge starts |
| endDate | Date | Yes | Yes | Yes | When challenge ends |
| createdAt | Date | Yes | Yes | Yes | When challenge was created |
| status | String | Yes | Yes | Yes | Challenge status |
| winnerId | String | No | Yes | No | User ID of winner |
| xpStake | Int64 | Yes | No | No | XP bet amount |
| winnerTakesAll | Int64 | Yes | No | No | 1 = winner takes all, 0 = split |
| isPublic | Int64 | Yes | Yes | No | 1 = public, 0 = private |

**Required Indexes**:
- creatorId (for fetching challenges by creator)
- status (for filtering by challenge state)
- isPublic (for discovering public challenges)
- startDate, endDate (for active challenge queries)

#### GroupWorkouts (NEW)
Stores group workout sessions for real-time collaboration.

| Field | Type | Required | Queryable | Indexed | Description |
|-------|------|----------|-----------|---------|-------------|
| name | String | Yes | Yes | Yes | Workout session name |
| description | String | Yes | No | No | Workout description |
| workoutType | Int64 | Yes | Yes | Yes | HKWorkoutActivityType raw value |
| hostId | String | Yes | Yes | Yes | User ID of session host |
| participants | Data | Yes | No | No | JSON array of participants |
| maxParticipants | Int64 | Yes | No | No | Maximum allowed participants |
| scheduledStart | Date | Yes | Yes | Yes | When workout starts |
| scheduledEnd | Date | Yes | Yes | Yes | When workout ends |
| status | String | Yes | Yes | Yes | Values: "scheduled", "active", "completed", "cancelled" |
| createdAt | Date | Yes | Yes | Yes | When created |
| updatedAt | Date | Yes | Yes | No | Last update time |
| isPublic | Int64 | Yes | Yes | Yes | 1 = public, 0 = private |
| joinCode | String | No | Yes | Yes | Private session join code |
| tags | String List | No | Yes | No | Searchable tags |

**Required Indexes**:
- hostId (for fetching sessions by host)
- status (for filtering by session state)
- isPublic (for discovering public sessions)
- scheduledStart (for upcoming sessions)
- joinCode (for private session joins)
- workoutType (for filtering by activity)

## CloudKit Dashboard Setup

To avoid runtime errors, configure the following in CloudKit Dashboard:

1. **Create Record Types**:
   - Go to CloudKit Dashboard > Schema > Record Types
   - Create all record types as defined above:
     - Private Database: `Users`, `WorkoutHistory`, `UserSettings`, `FollowRequests`, `DeviceTokens`
     - Public Database: `UserProfiles`, `UserRelationships`, `ActivityFeedItems`, `WorkoutKudos`, `WorkoutComments`, `WorkoutChallenges`, `GroupWorkouts`
   - Add all custom fields as defined above

2. **Configure Indexes**:
   - For queries that need custom sorting, mark fields as queryable
   - **REQUIRED**: Add `___recordID` as QUERYABLE index for each record type
   - For WorkoutHistory: Also mark `endDate` and `startDate` as QUERYABLE + SORTABLE

3. **Deploy to Production**:
   - After testing in development, deploy schema to production
   - Schema changes are not automatic between environments

## Best Practices

1. **Use CKQueryOperation instead of convenience methods** when you need more control or encounter queryable field errors
2. **Avoid complex predicates** - Use `NSPredicate(value: true)` to fetch all records and filter in memory
3. **Never use sort descriptors in queries** - Sort in memory after fetching to avoid queryable field errors
4. **Always handle missing record types gracefully** - Check for specific CKError codes
5. **Test in development** environment first before deploying to production
6. **For simple fetches**, consider using record IDs or zones instead of queries

## Field Migration Strategy

Since CloudKit doesn't support renaming fields, here's how to handle field migrations:

1. **Add the new field** (e.g., `totalXP`) in CloudKit Dashboard
2. **Keep the old field** (e.g., `influencerXP`) for backward compatibility
3. **Update code to write to both fields** during transition
4. **Read preferentially from the new field** with fallback to old field
5. **After all users update**, you can stop writing to the old field

Example in code:
```swift
// Writing - update both fields
userRecord["totalXP"] = newValue
userRecord["influencerXP"] = newValue // Backward compatibility

// Reading - try new field first
let xp = record["totalXP"] as? Int ?? record["influencerXP"] as? Int ?? 0
```

## Common Errors and Solutions

| Error | Cause | Solution |
|-------|-------|----------|
| "Field 'recordName' is not marked queryable" | Missing recordID index | Add `___recordID` as QUERYABLE index in CloudKit Dashboard |
| "Field X is not marked queryable" | Using non-queryable field in predicate or sort | Use system fields or mark field queryable in dashboard |
| "Did not find record type X" | Record type doesn't exist | Save a record to auto-create type or create in dashboard |
| "Invalid predicate" | Using unsupported query operations | Simplify query or fetch all and filter locally |