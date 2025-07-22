# User Profile System QA Guide

This document provides comprehensive testing procedures for the User Profile System (Phase 2) of FameFit.

## Overview

The User Profile System introduces social features to FameFit, allowing users to create profiles, set privacy preferences, and prepare for future social interactions. This guide covers manual testing procedures to ensure all features work correctly.

## Prerequisites

1. **Test Environment Setup**
   - Fresh install of FameFit app
   - Physical iPhone device (preferred) or Simulator
   - Test Apple ID for Sign in with Apple
   - Access to CloudKit Dashboard for verification
   - Multiple test devices for multi-user scenarios (optional)

2. **CloudKit Schema**
   - Ensure UserProfile and UserSettings record types are deployed
   - Verify indexes are properly configured (especially ___recordID)

## Test Scenarios

### 1. Profile Creation Flow

#### 1.1 New User Profile Creation

**Test Steps:**
1. Launch app with fresh install
2. Complete onboarding (Sign in with Apple + HealthKit permissions)
3. Arrive at "Create Your Profile" screen
4. Tap "Create Profile" button

**Expected Results:**
- Profile creation modal appears
- Progress bar shows 1/4 complete
- Username step is displayed first

#### 1.2 Username Selection

**Valid Username Tests:**
- ✅ Enter "john_doe" → Should show green checkmark
- ✅ Enter "user123" → Should show green checkmark
- ✅ Enter "ABC" (3 chars) → Should show green checkmark
- ✅ Enter 30 character username → Should show green checkmark

**Invalid Username Tests:**
- ❌ Enter "ab" → Error: "Invalid username format"
- ❌ Enter 31+ characters → Text field should limit input
- ❌ Enter "john doe" (space) → Space should be filtered out
- ❌ Enter "john@doe" → @ should be filtered out
- ❌ Enter existing username → Error: "Username already taken"

**Real-time Validation:**
- Type slowly → See loading indicator while checking availability
- Type quickly → Debouncing should prevent excessive requests

#### 1.3 Display Name Entry

**Test Steps:**
1. Complete username step
2. Progress to display name (2/4)

**Valid Display Names:**
- ✅ "John Doe" (normal name)
- ✅ "J" (single character)
- ✅ 50 character name

**Invalid Display Names:**
- ❌ Empty field → Next button disabled
- ❌ Only spaces → Next button disabled
- ❌ 51+ characters → Text field should limit

#### 1.4 Bio and Profile Photo

**Bio Tests:**
- ✅ Empty bio → Should be allowed
- ✅ 500 character bio → Should show 500/500
- ❌ 501+ characters → Should prevent input

**Photo Tests:**
1. Tap photo circle → Photos picker appears
2. Select photo → Photo displays in circle
3. No photo selected → Should be optional

#### 1.5 Privacy Settings

**Test Each Option:**
- Select "Public" → Verify description shown
- Select "Friends Only" → Verify selected with checkmark
- Select "Private" → Verify selection updates

**Complete Profile Creation:**
1. Tap "Create Profile"
2. See loading indicator
3. Success → Modal dismisses
4. Main screen shows with profile data

### 2. Profile Validation & Error Handling

#### 2.1 Network Error Simulation

**Test Steps:**
1. Enable Airplane Mode
2. Try to create profile
3. Should see error: "Network error: The Internet connection appears to be offline"

#### 2.2 CloudKit Errors

**Quota Exceeded:**
- Create many profiles rapidly
- Should see: "Too many requests. Please try again later"

#### 2.3 Content Moderation

**If implemented with word filter:**
- Try inappropriate usernames/bios
- Should see: "Your content was flagged for inappropriate language"

### 3. Existing User Profile Check

**Test Steps:**
1. Complete profile creation
2. Sign out (Settings → Sign Out)
3. Sign in again
4. Should skip profile creation step
5. Go directly to game mechanics

### 4. Profile Data Persistence

#### 4.1 CloudKit Verification

**Public Database Check:**
1. Open CloudKit Dashboard
2. Navigate to Public Database → UserProfile
3. Find record with your username
4. Verify all fields saved correctly:
   - username matches
   - displayName matches
   - bio matches
   - privacyLevel matches selection
   - totalXP shows current value
   - joinedDate is set
   - lastActive is recent

**Private Database Check:**
1. Navigate to Private Database → UserSettings
2. Find record with ID "settings-{userId}"
3. Verify default settings created:
   - emailNotifications = 1
   - pushNotifications = 1
   - workoutPrivacy matches profile privacy
   - Other defaults per spec

### 5. Integration Tests

#### 5.1 Profile Display in Main View

**After Profile Creation:**
- Main view should show username/display name
- Profile data should be accessible
- XP should match profile totalXP

#### 5.2 Workout Integration

**Complete a Workout:**
1. Start workout on Apple Watch
2. Complete workout
3. Verify profile's workoutCount increments
4. Verify totalXP updates
5. Check lastActive timestamp updates

### 6. Edge Cases

#### 6.1 Interruption Handling

**During Profile Creation:**
- Force quit app at each step
- Relaunch and verify:
  - Returns to profile creation
  - Previous data not saved
  - Can start fresh

#### 6.2 Multiple Devices

**Same Apple ID:**
1. Create profile on Device A
2. Sign in on Device B
3. Profile should sync automatically
4. Changes on one device reflect on other

### 7. Performance Tests

#### 7.1 Username Availability Check
- Should respond within 1 second
- Network indicator shows during check
- Typing quickly doesn't cause lag

#### 7.2 Profile Creation
- Should complete within 2-3 seconds
- Loading indicator throughout
- No UI freezing

#### 7.3 Profile Fetching
- Existing profile loads immediately
- Cache should work (offline viewing)

### 8. Accessibility Tests

#### 8.1 VoiceOver
- All buttons properly labeled
- Form fields announce purpose
- Errors read aloud
- Progress announced

#### 8.2 Dynamic Type
- Text scales appropriately
- Layout remains functional
- No text truncation issues

### 9. Privacy & Security Tests

#### 9.1 Data Validation
- SQL injection attempts in username/bio → Should be sanitized
- Script tags in bio → Should be escaped
- Extremely long inputs → Should be limited

#### 9.2 Privacy Settings
- Private profile → Should not appear in future leaderboards
- Public profile → Should be discoverable
- Friends only → Ready for future friend system

## Regression Tests

After implementing User Profiles, verify these existing features still work:

1. **Onboarding Flow**
   - Sign in with Apple works
   - HealthKit permissions work
   - Character dialogues display correctly

2. **Workout Syncing**
   - Workouts still sync to CloudKit
   - XP calculations unchanged
   - Notifications still appear

3. **Main View**
   - Stats display correctly
   - Navigation works
   - No layout issues

## Test Data

### Sample Valid Usernames
- fitking2024
- muscle_mike
- yogagirl_sf
- runner123
- gym_rat_99

### Sample Invalid Usernames
- me (too short)
- user@email.com (special chars)
- my username (spaces)
- émoji_user (non-ASCII)
- this_is_a_very_long_username_over_thirty (too long)

### Sample Bios
- "Just starting my fitness journey! 💪"
- "Marathon runner | Yoga instructor | Plant-based"
- "Transforming one workout at a time"
- (Empty bio to test optional field)

## Bug Report Template

When reporting issues, include:

1. **Device Info**
   - iOS version
   - Device model
   - App version

2. **Steps to Reproduce**
   - Detailed step-by-step
   - Any specific data entered

3. **Expected vs Actual**
   - What should happen
   - What actually happened

4. **Screenshots/Videos**
   - Especially for UI issues

5. **CloudKit Records**
   - Record IDs if relevant
   - Error messages from console

## Success Criteria

Profile creation is successful when:
- ✅ User can complete all steps without errors
- ✅ Profile saves to CloudKit Public Database
- ✅ Settings save to CloudKit Private Database  
- ✅ Username uniqueness is enforced
- ✅ Validation provides clear feedback
- ✅ Profile data persists across sessions
- ✅ Integration with existing features works
- ✅ Performance is acceptable (<2s for operations)
- ✅ Accessibility features work correctly
- ✅ Privacy settings are respected

## Notes for QA Team

1. **Test Multiple Scenarios**: Don't just test the happy path
2. **Check CloudKit**: Verify data actually saves correctly
3. **Test Interruptions**: Kill app, toggle airplane mode, etc.
4. **Verify Integration**: Ensure workouts still update profile
5. **Document Issues**: Use bug template for consistency

---

Last Updated: 2025-07-19
Phase 2: User Profile System v1.0