# Manual Test: Profile Creation Flow

## Setup
1. Reset user data using Developer Menu > "Reset User Data for Testing"
2. Sign out if needed and restart the app

## Test Steps

### 1. Initial Onboarding
- [ ] App shows welcome screens with character introductions
- [ ] Can navigate through welcome screens

### 2. Sign In with Apple
- [ ] Sign in with Apple button appears
- [ ] Can successfully sign in with Apple ID
- [ ] App proceeds to next step after sign in

### 3. HealthKit Permissions
- [ ] HealthKit permission screen appears
- [ ] Can grant or deny permissions
- [ ] App proceeds to profile creation

### 4. Profile Creation - Username Step
- [ ] Username input field appears
- [ ] Can type username (letters, numbers, underscore only)
- [ ] Special characters are filtered out automatically
- [ ] "Next" button is enabled when username is valid
- [ ] **CRITICAL**: "Next" button works when clicked (no hanging)
- [ ] If network is available, username availability is checked
- [ ] Can proceed even if network check fails

### 5. Profile Creation - Display Name Step
- [ ] Display name input appears after username
- [ ] Can enter display name
- [ ] Character count shows correctly
- [ ] "Next" button works

### 6. Profile Creation - Bio & Photo Step
- [ ] Bio text area appears
- [ ] Can enter bio text (optional)
- [ ] Photo picker button works
- [ ] Can skip photo selection
- [ ] "Next" button works

### 7. Profile Creation - Privacy Settings
- [ ] Privacy options are displayed
- [ ] Can select privacy level
- [ ] "Create Profile" button appears
- [ ] Profile creation completes successfully

### 8. Main App Access
- [ ] After profile creation, main app appears
- [ ] User data is saved correctly
- [ ] Can't access main app without completing profile

## Expected Results
- No hanging or freezing at any step
- All "Next" buttons respond immediately
- Network errors don't block progression
- Profile is created successfully

## Known Issues Fixed
1. ✅ Username validation no longer hangs
2. ✅ Container identifier correctly set for CloudKit
3. ✅ Network errors handled gracefully
4. ✅ Can proceed even if UserProfiles table doesn't exist in CloudKit