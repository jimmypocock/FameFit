# FameFit XP System QA Guide

This document provides comprehensive testing procedures for the Influencer XP system in FameFit.

## Overview

The XP system replaces the simple "followers" counter with a dynamic experience point system that rewards users based on workout duration, intensity, consistency, and timing.

## Pre-Testing Setup

### Required Test Data
1. **Fresh Install Testing**: Start with app uninstalled
2. **Migration Testing**: Install old version first (with followers), then update
3. **Test Apple ID**: Use a test Apple ID for CloudKit testing

### Testing Without Multiple Devices

Since social features require multiple users, here are strategies for single-device testing:

1. **CloudKit Dashboard Testing**
   - Access: https://icloud.developer.apple.com/dashboard
   - Navigate to FameFit container
   - Manually modify user records to simulate different XP values
   - Create test records to verify XP calculations

2. **UI Testing with Mock Data**
   - Use the `--mock-healthkit` launch argument
   - This provides simulated workout data for testing

3. **Time-Based Testing**
   - Change device time to test time-of-day bonuses
   - Test weekend vs weekday bonuses

## Test Cases

### 1. XP Calculation Tests

#### 1.1 Basic XP Earning
- [ ] Complete a 30-minute running workout
  - Expected: ~36 XP (30 mins × 1.0 base × 1.2 running multiplier)
- [ ] Complete a 60-minute cycling workout
  - Expected: ~60 XP (60 mins × 1.0 base × 1.0 cycling multiplier)
- [ ] Complete a 45-minute HIIT workout
  - Expected: ~67 XP (45 mins × 1.0 base × 1.5 HIIT multiplier)

#### 1.2 Time-of-Day Bonuses
- [ ] Morning workout (5-9 AM): Should show 1.2x multiplier
- [ ] Normal hours (9 AM-10 PM): Should show 1.0x multiplier
- [ ] Night owl (10 PM-midnight): Should show 1.1x multiplier
- [ ] Late night (midnight-5 AM): Should show 0.8x multiplier

#### 1.3 Weekend Bonus
- [ ] Complete identical workouts on weekday vs weekend
  - Weekend should give 1.1x the weekday XP

#### 1.4 Streak Multipliers
- [ ] First workout: No streak bonus
- [ ] After 5 consecutive days: 1.25x multiplier
- [ ] After 10 consecutive days: 1.5x multiplier
- [ ] After 20 consecutive days: 2.0x multiplier (max)

### 2. UI/UX Tests

#### 2.1 XP Progress Display
- [ ] Main screen shows current XP total
- [ ] Progress bar shows percentage to next level
- [ ] Current level title is displayed correctly
- [ ] Next unlock preview shows correct XP requirement

#### 2.2 Level Progression
| Current XP | Expected Level | Expected Title |
|------------|----------------|----------------|
| 0-99       | Level 1        | Couch Potato   |
| 100-499    | Level 2        | Fitness Newbie |
| 500-999    | Level 3        | Gym Regular    |
| 1000-2499  | Level 4        | Fitness Enthusiast |
| 2500-4999  | Level 5        | Workout Warrior |

#### 2.3 Animation Tests
- [ ] Progress bar animates smoothly when XP increases
- [ ] No visual glitches during level transitions

### 3. Unlock System Tests

#### 3.1 Unlock Notifications
- [ ] Reach 100 XP: Should unlock "Bronze Badge" and "Custom Messages"
- [ ] Notification appears in app notification center
- [ ] Push notification received (if permissions granted)
- [ ] Character selection matches level (Zen for 1-4, Sierra for 5-8, Chad for 9+)

#### 3.2 Unlock Persistence
- [ ] Force quit app after unlock
- [ ] Reopen app - unlocks should still be visible
- [ ] Check unlock timestamp is preserved

#### 3.3 Multiple Unlocks
- [ ] Jump from <100 XP to >500 XP in one workout
- [ ] Should receive all intermediate unlock notifications
- [ ] All unlocks should be recorded

### 4. Migration Tests

#### 4.1 Existing User Migration
1. Install previous version with follower system
2. Accumulate some followers (e.g., 90)
3. Update to XP version
4. Verify followers converted to XP (90 followers = 90 XP)
5. Verify workout history preserved

#### 4.2 Fresh Install
- [ ] New users start with 0 XP
- [ ] No migration errors in console
- [ ] Onboarding shows XP terminology

### 5. Edge Cases

#### 5.1 Data Validation
- [ ] Very short workout (<1 minute): Should still earn minimum 1 XP
- [ ] Very long workout (>3 hours): XP calculates correctly
- [ ] No heart rate data: Intensity multiplier not applied
- [ ] Workout with 0 duration: Should earn 1 XP minimum

#### 5.2 Notification Handling
- [ ] Disable notifications in iOS Settings
- [ ] Unlocks should still appear in in-app notification center
- [ ] Re-enable notifications - future unlocks should push notify

#### 5.3 CloudKit Sync
- [ ] Put device in Airplane Mode
- [ ] Complete workout
- [ ] Turn off Airplane Mode
- [ ] XP should sync when connection restored

### 6. Performance Tests

#### 6.1 Large XP Values
- [ ] Simulate user with 1,000,000+ XP
- [ ] UI should format numbers correctly (with commas)
- [ ] No performance degradation

#### 6.2 Many Unlocks
- [ ] User with all unlocks achieved
- [ ] Unlock list should scroll smoothly
- [ ] No memory issues

## Regression Tests

After testing new XP system, verify these existing features still work:

- [ ] Apple Watch workout tracking
- [ ] Workout completion notifications
- [ ] Workout history display
- [ ] HealthKit data sync
- [ ] Sign in/Sign out flow
- [ ] Character messages appear correctly

## Testing Tips for Single Device

1. **Simulating Multiple XP Levels**
   - Use CloudKit Dashboard to manually edit your XP value
   - Test UI at different XP thresholds (99, 100, 499, 500, etc.)

2. **Testing Streaks**
   - Manually edit `lastWorkoutTimestamp` in CloudKit to simulate streak breaks
   - Change device date to test consecutive day detection

3. **Testing All Unlock Types**
   - Edit CloudKit record to set XP just below unlock thresholds
   - Complete small workout to trigger specific unlocks

4. **Screenshot Locations**
   - Main screen with XP progress bar
   - Level up notification
   - Unlock notification
   - Workout history showing XP earned

## Bug Reporting Template

When reporting XP-related bugs, include:

```
Device: [iPhone model]
iOS Version: [version]
App Version: [version]
Current XP: [amount]
Current Level: [level]

Steps to Reproduce:
1. 
2. 
3. 

Expected Result:

Actual Result:

Screenshots/Video: [attach if applicable]
```

## Social Features Testing

### 7. Workout Sharing Tests

#### 7.1 Privacy Settings
- [ ] Default privacy should be "Private" for new users
- [ ] Verify privacy settings persist across app restarts
- [ ] Test per-workout type privacy overrides
- [ ] Verify COPPA compliance (users under 13 can't share publicly)

#### 7.2 Post-Workout Sharing Flow
- [ ] Complete workout on Apple Watch
- [ ] iOS app should show sharing prompt within 5 seconds
- [ ] Verify workout preview displays correct data:
  - Workout type with appropriate icon
  - Duration formatted correctly
  - XP earned displayed
- [ ] Privacy selector shows appropriate options
- [ ] "Include workout details" toggle respects privacy settings

#### 7.3 Privacy Level Testing
| Privacy Level | Who Can See | Expected Behavior |
|--------------|-------------|-------------------|
| Private | Nobody | Activity not posted to feed |
| Friends Only | Following users | Activity visible only to followers |
| Public | Everyone | Activity visible in global feed |

#### 7.4 Content Filtering
- [ ] Activities with inappropriate content are filtered
- [ ] Test with various workout names and custom text
- [ ] Verify content moderation works correctly

#### 7.5 Activity Feed Display
- [ ] Feed loads activities from followed users
- [ ] Activities display in chronological order
- [ ] Each activity shows:
  - User profile image/initials
  - Username and verification badge (if applicable)
  - Time ago (e.g., "2 hours ago")
  - Activity type icon
  - Workout details (if shared)
  - XP earned
- [ ] Pull-to-refresh updates the feed
- [ ] Infinite scroll loads older activities

#### 7.6 Privacy Controls UI
- [ ] Settings > Privacy shows all privacy options
- [ ] Toggle "Allow Public Sharing" on/off
- [ ] Toggle "Share Achievements" on/off
- [ ] Toggle "Share Personal Records" on/off
- [ ] Per-workout type privacy overrides work correctly

#### 7.7 Edge Cases
- [ ] Share workout with no internet connection
  - Should queue and sync when connected
- [ ] Share very short workout (<1 minute)
- [ ] Share workout with missing data (no heart rate, no distance)
- [ ] Rapidly share multiple workouts
- [ ] Change privacy after sharing (should update in feed)

### 8. Achievement Sharing Tests

#### 8.1 Achievement Types
- [ ] Level up achievements post to feed (if enabled)
- [ ] Badge unlocks post to feed (if enabled)
- [ ] Personal records post to feed (if enabled)

#### 8.2 Achievement Privacy
- [ ] Respect "Share Achievements" toggle
- [ ] Achievement privacy follows default privacy setting
- [ ] COPPA users can't share achievements publicly

### 9. Social Interaction Tests

#### 9.1 User Profiles
- [ ] Tap on user in feed navigates to profile
- [ ] Profile shows user's level and XP
- [ ] Follow/Unfollow buttons work correctly
- [ ] Following count updates immediately

#### 9.2 Feed Filtering
- [ ] Filter by activity type (workouts, achievements, etc.)
- [ ] Filter by time range (today, week, month, all)
- [ ] Filters persist across sessions
- [ ] "Apply" button updates feed immediately

### 10. Performance Tests for Social Features

#### 10.1 Large Feed Tests
- [ ] Feed with 100+ activities scrolls smoothly
- [ ] Images load without blocking UI
- [ ] Memory usage remains stable

#### 10.2 Sync Performance
- [ ] Activities post within 5 seconds
- [ ] Feed updates reflect new activities quickly
- [ ] No duplicate activities in feed

## Integration Testing

### Workout Completion to Feed Flow
1. [ ] Start workout on Apple Watch
2. [ ] Complete workout
3. [ ] iOS app receives completion notification
4. [ ] Sharing prompt appears
5. [ ] Select privacy level and share
6. [ ] Activity appears in feed
7. [ ] Other users see activity (based on privacy)

### Privacy Settings Impact
1. [ ] Set default privacy to "Private"
2. [ ] Complete workout
3. [ ] Sharing prompt should show "Private" selected
4. [ ] Change to "Friends Only" and share
5. [ ] Verify only followers see the activity

## Security Testing

### Privacy Enforcement
- [ ] Users can't see private activities via API
- [ ] Friends-only activities require following relationship
- [ ] No data leakage in CloudKit queries
- [ ] User IDs are properly anonymized

### Content Security
- [ ] HTML/script injection attempts are sanitized
- [ ] Large text inputs are truncated appropriately
- [ ] Emoji and special characters display correctly

## Post-Release Monitoring

Monitor these metrics after release:
- Average XP per user
- Most common unlock achievements  
- XP calculation accuracy
- Notification delivery rate
- Migration success rate
- Workout sharing adoption rate
- Privacy setting distribution
- Average activities per user per week
- Content filtering effectiveness

---

Last Updated: 2025-07-20