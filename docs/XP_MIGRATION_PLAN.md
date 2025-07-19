# Influencer XP Migration Plan

## Overview
This document outlines the migration strategy from "followers" to "Influencer XP" while maintaining backward compatibility and data integrity.

## Migration Strategy

### Phase 1: Schema Updates (Backward Compatible)

1. **Add New Fields** (don't remove old ones yet):
   - Add `influencerXP` (Int64) to User record
   - Add `xpEarned` (Int64) to WorkoutHistory record
   - Keep existing `followerCount` and `followersEarned` fields

2. **Dual-Write Period**:
   - Write to both old and new fields
   - Read from new fields if available, fallback to old
   - This ensures compatibility during rollout

3. **Data Migration**:
   - On first app launch after update, copy `followerCount` → `influencerXP`
   - Mark migration complete in UserDefaults

### Phase 2: Code Updates

1. **CloudKitManager**:
   - Add `influencerXP` property alongside `followerCount`
   - Update both during transition period
   - Add migration check on startup

2. **UI Updates**:
   - Change labels from "Followers" to "Influencer XP"
   - Update number formatting (XP can be larger numbers)
   - Add "XP" suffix to displays

3. **Calculations**:
   - Keep same calculation logic initially
   - Can enhance XP calculations later without breaking compatibility

### Phase 3: Cleanup (Future Release)

After all users have migrated (monitor analytics):
1. Stop writing to old fields
2. Remove old field references from code
3. Eventually remove old fields from schema

## Implementation Checklist

### CloudKit Dashboard Changes:
- [ ] Add `influencerXP` field to User record type
- [ ] Add `xpEarned` field to WorkoutHistory record type
- [ ] Deploy schema to production after testing

### Code Changes:
- [ ] Update CloudKitManager with dual-write logic
- [ ] Add migration check on app startup
- [ ] Update all UI labels
- [ ] Update tests to check both fields during transition
- [ ] Add migration tracking

### Testing:
- [ ] Test fresh install (no existing data)
- [ ] Test upgrade with existing follower data
- [ ] Test rollback scenario
- [ ] Verify CloudKit sync works correctly

## Migration Code Example

```swift
extension CloudKitManager {
    func migrateToInfluencerXP() {
        guard !UserDefaults.standard.bool(forKey: "HasMigratedToXP") else { return }
        
        // Copy existing followerCount to influencerXP
        if let record = userRecord {
            let currentFollowers = record["followerCount"] as? Int ?? 0
            record["influencerXP"] = currentFollowers
            
            // Save the migration
            privateDatabase.save(record) { _, error in
                if error == nil {
                    UserDefaults.standard.set(true, forKey: "HasMigratedToXP")
                }
            }
        }
    }
}
```

## Rollback Plan

If issues arise:
1. App continues reading from old fields as fallback
2. CloudKit schema keeps both fields
3. Can revert UI labels with simple string change
4. No data loss as we maintain both values

## Success Metrics

- 100% of active users migrated within 30 days
- No increase in CloudKit errors
- No user complaints about missing data
- Successful sync across devices

## Timeline

- Week 1: CloudKit schema updates, core migration logic
- Week 2: UI updates, testing
- Week 3: Release to TestFlight
- Week 4: Production release
- Week 8: Begin cleanup phase

---
Last Updated: 2025-07-18