# CloudKit Schema Documentation

## Overview

This document defines the CloudKit schema for FameFit. It serves as the source of truth for all CloudKit record types and fields.

**Container Identifier:** `iCloud.com.jimmypocock.FameFit`  
**Database:** Private Database

## Record Types

### UserProfiles

Stores user profile and gamification data. This is a custom record type that follows database naming conventions (plural) and iOS best practices, separate from the system Users type.

**Note on Date/Time fields**: CloudKit's "Date" type always stores full timestamps with millisecond precision and timezone information. We use "timestamp" in field names to make this clear.

| Field | Type | Description | Default | Required |
|-------|------|-------------|---------|----------|
| `recordName` | Reference | CloudKit user record ID (primary key) | Auto-generated | Yes |
| `displayName` | String | User's display name from Sign in with Apple | - | Yes |
| `followerCount` | Int64 | Number of followers gained through workouts | 0 | Yes |
| `totalWorkouts` | Int64 | Total number of completed workouts | 0 | Yes |
| `currentStreak` | Int64 | Current consecutive days with workouts | 0 | Yes |
| `joinTimestamp` | Date/Time | Full timestamp when user first joined (includes time & timezone) | Current timestamp | Yes |
| `lastWorkoutTimestamp` | Date/Time | Full timestamp of the most recent workout (includes time & timezone) | - | No |

#### Indexes

- **Record Name** (System Index) - Primary key using CloudKit user record ID
- **modifiedAt** (System Index) - For change tracking

#### Security

- Owner: Read/Write
- Public: No Access

## Data Flow

```bash
Apple Watch (HealthKit) 
    ↓
WorkoutSyncManager (iOS App)
    ↓
CloudKitManager → UserProfiles Record
```

## Business Rules

1. **Follower Calculation**: Each completed workout adds 5 followers
2. **Streak Logic**: Streak increments if workout occurs within 24-48 hours of last workout
3. **Record Creation**: UserProfiles record created on first sign-in using CloudKit user's record ID

## Migration History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2024-01 | Initial schema with User record type |
| 1.1 | 2024-12 | Renamed User to UserProfiles following database naming conventions |

## Testing

### Development Environment

- Use CloudKit Dashboard to verify schema matches this document
- Test with sandbox environment before production

### Schema Validation

Run the following checks:

1. All required fields have values on record creation
2. Field types match CloudKit Dashboard configuration
3. Security roles are properly configured

## Future Considerations

Potential additions for v2:

- Achievement records for unlocking new characters
- Workout detail records (if moving beyond HealthKit storage)
- Social features (following other users)
