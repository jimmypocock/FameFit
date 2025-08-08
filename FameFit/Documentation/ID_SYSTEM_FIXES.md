# ID System Fixes Required

## The Problem

The app uses two different ID systems that are getting confused:

1. **Profile ID (UUID)**: The record ID for UserProfile records (e.g., `6F835AC7-8100-4B8B-95F5-94AB7F431AA0`)
2. **CloudKit User ID**: The actual user identifier from CloudKit (e.g., `_65016d98fd8579ab704d38d23d066b2f`)

## Current Issues

- ProfileView receives different ID types from different sources
- Social operations (follow/unfollow) need CloudKit user IDs but sometimes receive profile UUIDs
- Follower/following counts are queried with wrong IDs
- Navigation to profiles is inconsistent

## Required Fixes

### 1. Navigation Consistency

All navigation to ProfileView should use profile.id (UUID):

- ✅ UserSearchView: `selectedUserID = profile.id`
- ✅ LeaderboardView: Should pass entry.profile.id
- ✅ FollowersListView: `ProfileView(userID: profile.id)`
- ❌ TabMainView: Currently passes CloudKit ID directly

### 2. Social Operations

All social operations should use profile.userID (CloudKit ID):

- ✅ Follow/unfollow actions
- ✅ Relationship checks
- ✅ Follower/following counts

### 3. ProfileView Improvements

- ✅ Now handles both ID types intelligently
- ✅ Resolves to CloudKit user ID for social operations
- ✅ Uses appropriate ID for each operation

## Recommended Actions

1. **Standardize Navigation**: Always pass profile.id to ProfileView
2. **Update TabMainView**: Fetch current user's profile first, then navigate with profile.id
3. **Add Helper Methods**: Use UserProfile extensions for clarity
4. **Debug Logging**: Keep temporary logging to verify correct IDs are used

## Testing Checklist

- [ ] Can view own profile from tab bar
- [ ] Can view other profiles from search
- [ ] Can view profiles from leaderboard
- [ ] Cannot follow self
- [ ] Follower/following counts are accurate
- [ ] Follower/following lists show correct users
- [ ] Follow button state is correct (Following/Follow)
