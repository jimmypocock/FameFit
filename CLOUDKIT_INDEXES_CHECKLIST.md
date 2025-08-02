# CloudKit Indexes Configuration Checklist

This checklist helps you configure all required CloudKit indexes based on the queries found in the FameFit codebase.

**How to add indexes:**

1. Go to <https://icloud.developer.apple.com/dashboard>
2. Select your FameFit container
3. Go to Schema → Indexes
4. Add each index listed below

## Critical System Requirement

Every record type MUST have this index to prevent "Can't query system types" errors:

- [ ] `___recordID` - QUERYABLE (three underscores)

---

## ActivityFeed

- [x] `___recordID` - QUERYABLE ⚠️ **MISSING - Add this first!**
- [x] `userID` - QUERYABLE (for "userID IN %@" queries)
- [x] `createdTimestamp` - QUERYABLE & SORTABLE (for date filtering and sorting)
- [x] `expiresAt` - QUERYABLE (for expiration checks)
- [x] **UPDATE**: Change existing `createdAt` index to `createdTimestamp`

## UserProfiles

- [x] `___recordID` - QUERYABLE
- [x] `userID` - QUERYABLE
- [x] `username` - QUERYABLE  
- [x] `privacyLevel` - QUERYABLE
- [x] `lastUpdated` - QUERYABLE & SORTABLE
- [x] `totalXP` - SORTABLE

## UserRelationships

- [x] `___recordID` - QUERYABLE
- [x] `followerID` - QUERYABLE
- [x] `followingID` - QUERYABLE
- [x] `creationDate` - SORTABLE

## ActivitySharingSettings

- [ ] `___recordID` - QUERYABLE
- [ ] `userID` - QUERYABLE

## DeviceTokens

- [x] `___recordID` - QUERYABLE
- [x] `userID` - QUERYABLE
- [x] `deviceToken` - QUERYABLE
- [x] `isActive` - QUERYABLE
- [x] `lastUpdated` - QUERYABLE & SORTABLE (rename to ModifiedTimestamp)

## Workouts (renamed from WorkoutHistory)

- [x] `___recordID` - QUERYABLE
- [x] `endDate` - SORTABLE

## ActivityComments (new, replaces WorkoutComments)

- [ ] `___recordID` - QUERYABLE
- [ ] `activityFeedId` - QUERYABLE
- [ ] `sourceType` - QUERYABLE
- [ ] `sourceRecordId` - QUERYABLE
- [ ] `createdTimestamp` - SORTABLE

## WorkoutComments (DEPRECATED - DO NOT USE)

**This table is deprecated. Use ActivityComments instead.**
**Since there's no existing data, this table can be removed from CloudKit.**

- [ ] ~~`___recordID` - QUERYABLE~~
- [ ] ~~`workoutId` - QUERYABLE~~
- [ ] ~~`createdTimestamp` - SORTABLE~~

## WorkoutKudos

- [ ] `___recordID` - QUERYABLE
- [ ] `userID` - QUERYABLE
- [ ] `workoutId` - QUERYABLE
- [ ] `createdTimestamp` - SORTABLE

## GroupWorkouts

- [ ] `___recordID` - QUERYABLE
- [ ] `hostID` - QUERYABLE
- [ ] `joinCode` - QUERYABLE
- [ ] `scheduledStart` - SORTABLE
- [ ] `status` - QUERYABLE
- [ ] `isPublic` - QUERYABLE
- [ ] `participants` - QUERYABLE
- [ ] `workoutType` - QUERYABLE

## WorkoutChallenges

- [ ] `___recordID` - QUERYABLE
- [ ] `id` - QUERYABLE
- [ ] `status` - QUERYABLE
- [ ] `isPublic` - QUERYABLE
- [ ] `participants` - QUERYABLE
- [ ] `createdTimestamp` - SORTABLE

## Users

- [x] `___recordID` - QUERYABLE

## UserSettings

- [x] `___recordID` - QUERYABLE

---

## Deployment Notes

After adding all indexes:

1. [ ] Deploy schema changes to Development environment
2. [ ] Test the app to ensure queries work
3. [ ] Deploy schema changes to Production environment

## Common Issues

**"Field 'recordName' is not marked queryable" error:**

- This actually means `___recordID` needs to be queryable
- Make sure it has exactly three underscores: `___recordID`

**Queries still failing after adding indexes:**

- Ensure you've deployed the schema changes
- Check that field names match exactly (case-sensitive)
- Verify you're querying the correct database (public vs private)

## Verification

To verify indexes are working:

1. Clear app data and restart
2. Sign in and create a profile
3. Check console for CloudKit errors
4. Test social features (following, feed, etc.)
