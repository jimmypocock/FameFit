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

## Record Types

### User
Stores user profile information.

| Field | Type | Required | Queryable | Indexed | Description |
|-------|------|----------|-----------|---------|-------------|
| userName | String | Yes | No | No | Display name |
| followerCount | Int64 | Yes* | No | No | Total followers (DEPRECATED - use influencerXP) |
| influencerXP | Int64 | Yes | No | No | Total Influencer XP earned |
| totalWorkouts | Int64 | Yes | No | No | Total workouts completed |
| currentStreak | Int64 | Yes | No | No | Current workout streak |
| lastWorkoutTimestamp | Date | No | No | No | Last workout date |
| joinTimestamp | Date | Yes | No | No | When user joined |

*Note: `followerCount` is maintained for backward compatibility during migration to `influencerXP`

### WorkoutHistory
Stores individual workout records.

| Field | Type | Required | Queryable | Indexed | Description |
|-------|------|----------|-----------|---------|-------------|
| workoutId | String | Yes | No | No | UUID of the workout |
| workoutType | String | Yes | No | No | Type of workout (Running, Cycling, etc.) |
| startDate | Date | Yes | No | No | Workout start time |
| endDate | Date | Yes | No | No | Workout end time |
| duration | Double | Yes | No | No | Duration in seconds |
| totalEnergyBurned | Double | Yes | No | No | Calories burned |
| totalDistance | Double | No | No | No | Distance in meters |
| averageHeartRate | Double | No | No | No | Average heart rate |
| followersEarned | Int64 | Yes* | No | No | Followers earned from workout (DEPRECATED - use xpEarned) |
| xpEarned | Int64 | Yes | No | No | XP earned from workout |
| source | String | Yes | No | No | Source app (e.g., "Apple Watch") |

*Note: `followersEarned` is maintained for backward compatibility during migration to `xpEarned`

## CloudKit Dashboard Setup

To avoid runtime errors, configure the following in CloudKit Dashboard:

1. **Create Record Types**:
   - Go to CloudKit Dashboard > Schema > Record Types
   - Create `User` and `WorkoutHistory` record types
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

## Common Errors and Solutions

| Error | Cause | Solution |
|-------|-------|----------|
| "Field 'recordName' is not marked queryable" | Missing recordID index | Add `___recordID` as QUERYABLE index in CloudKit Dashboard |
| "Field X is not marked queryable" | Using non-queryable field in predicate or sort | Use system fields or mark field queryable in dashboard |
| "Did not find record type X" | Record type doesn't exist | Save a record to auto-create type or create in dashboard |
| "Invalid predicate" | Using unsupported query operations | Simplify query or fetch all and filter locally |