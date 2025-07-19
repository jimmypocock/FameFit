# FameFit Architecture Improvements TODO

This document tracks planned architecture improvements to enhance testability, reduce coupling, and follow modern iOS/Swift best practices.

## 🚀 **NEXT UP - HIGH PRIORITY FEATURES**

### 🔧 Fix Remaining Test Failures (Immediate Priority)

**Status**: In Progress (2025-07-19)  
**Impact**: High - Test suite must pass for reliable development

**Remaining Issues to Fix:**

1. **WorkoutSyncQueueTests** - Async timing issues
   - `testProcessQueueWhenCloudKitAvailable()` - times out waiting for processing to complete
   - `testFullWorkflowFromEnqueueToSuccess()` - times out waiting for processing to complete
   - Root cause: The mock implementation simulates success but the async processing might not be completing properly
   - Potential fix: Review the background operation queue processing in WorkoutSyncQueue

2. **OnboardingUITests** - Navigation issues
   - Multiple tests failing to navigate through character introductions
   - Tests affected: `testCharacterIntroductions`, `testCompleteOnboardingFlow`, `testLetsGetStartedButtonBehavior`
   - Root cause: Navigation logic expects 7 dialogues but timing/animation issues may be causing failures
   - Already attempted fix: Updated navigation logic to handle exact dialogue count

3. **Simulator Launch Issues**
   - Some tests fail with "Simulator device failed to launch com.jimmypocock.FameFit"
   - May need to run `./Scripts/fix_test_devices.sh` before test runs
   - Consider adding retry logic for simulator launches

**Next Steps:**
- Debug the async processing in WorkoutSyncQueue to ensure it completes within test timeout
- Add more robust waiting/retry logic for UI test navigation
- Consider increasing test timeouts or adding explicit waits for async operations
- Run tests individually to isolate timing issues

### 10. 🎮 Influencer XP & Social Networking System

**Status**: Phase 1 Completed (2025-07-18) ✅ | Phase 2 Planning 📋  
**Impact**: High - Major feature addition transforming app dynamics

Transform the current "followers" system into a comprehensive gamification and social networking platform.

#### Core Concept Changes

**From**: Followers (simple counter)  
**To**: Influencer XP (experience points) + Real Social Following

This creates a dual-currency system:
- **Influencer XP**: Earned through workouts, used for in-app rewards/features
- **Real Followers**: Actual users who follow your fitness journey

#### Phase 1: Influencer XP System (Foundation) ✅

**Completed Tasks**:
- [x] Rename "followers" to "Influencer XP" throughout codebase
  - [x] Update CloudKit schema (maintain backward compatibility)
  - [x] Create migration for existing users (server-side tool)
  - [x] Update UI labels and terminology
  - [x] Update achievement messages and thresholds
- [x] Create XP calculation engine
  - [x] Base XP for workout completion
  - [x] Bonus XP for workout type/intensity
  - [x] Streak multipliers
  - [x] Time-of-day bonuses
  - [x] Achievement-based XP boosts
- [x] Implement XP unlock system (XP unlocks rewards, not spent)
  - [x] Design achievement-based unlocks (in XPCalculator)
  - [x] Create unlockable rewards catalog (in XPCalculator)
  - [x] Progress tracking UI component
  - [x] Unlock notification system
  - [x] Unlock persistence/storage

**Security Requirements**:
- Server-side XP validation (prevent client manipulation)
- Rate limiting for XP gains
- Audit trail for all XP transactions
- Encrypted storage of XP balances

#### Phase 2: User Profile System

**Tasks**:
- [ ] Create User model and CloudKit schema
  - [ ] Username (unique, validated)
  - [ ] Display name
  - [ ] Bio (character limited)
  - [ ] Profile picture (CloudKit asset)
  - [ ] Privacy settings
  - [ ] Workout stats visibility
- [ ] Build profile management
  - [ ] Profile creation flow
  - [ ] Edit profile view
  - [ ] Username validation service
  - [ ] Image upload/crop functionality
- [ ] Implement privacy controls
  - [ ] Public/Private profiles
  - [ ] Follower approval settings
  - [ ] Blocked users list
  - [ ] Data visibility granularity

**Security Requirements**:
- Content moderation for usernames/bios
- Image scanning for inappropriate content
- COPPA compliance for under-13 users
- GDPR-compliant data management

#### Phase 3: Social Following System

**Tasks**:
- [ ] Create Following/Follower relationships
  - [ ] CloudKit relationship schema
  - [ ] Follow/Unfollow actions
  - [ ] Follower notifications
  - [ ] Mutual follow detection
- [ ] Build user discovery
  - [ ] Search by username
  - [ ] Suggested users algorithm
  - [ ] Leaderboards (XP-based)
  - [ ] Workout buddy matching
- [ ] Social feed implementation
  - [ ] Activity feed protocol
  - [ ] Workout completion posts
  - [ ] Achievement announcements
  - [ ] Feed pagination/caching

**Security Requirements**:
- Rate limiting on follow actions
- Spam detection algorithms
- Report/block user functionality
- Age-appropriate content filtering

#### Phase 4: Social Interactions

**Tasks**:
- [ ] Implement engagement features
  - [ ] Kudos/Cheers for workouts
  - [ ] Comments on activities
  - [ ] Workout challenges between users
  - [ ] Group workout sessions
- [ ] Create notification system
  - [ ] Push notification infrastructure
  - [ ] In-app notification center
  - [ ] Notification preferences
  - [ ] Badge count management
- [ ] Build messaging system (optional)
  - [ ] Direct messages
  - [ ] Group chats for challenges
  - [ ] Message encryption
  - [ ] Media sharing controls

**Security Requirements**:
- End-to-end encryption for messages
- Content moderation AI/ML integration
- Reporting system for inappropriate behavior
- Parental controls for minors

#### Phase 1.5: XP System Polish & Enhancements

**Tasks**:
- [ ] Add XP gain animations
  - [ ] Floating +XP text animation
  - [ ] Progress bar fill animation
  - [ ] Level up celebration
  - [ ] Unlock celebration animations
- [ ] Create detailed workout history
  - [ ] XP breakdown per workout
  - [ ] Show multipliers applied
  - [ ] Personal records highlighted
  - [ ] Weekly/Monthly XP trends
- [ ] Build achievement notifications
  - [ ] Special bonus notifications
  - [ ] Milestone achievements
  - [ ] Streak notifications
  - [ ] Personal best alerts
- [ ] XP leaderboard preview
  - [ ] Friends leaderboard
  - [ ] Global top performers
  - [ ] Weekly/Monthly leaders
  - [ ] Near me in rankings

#### Phase 5: Gamification Enhancements

**Tasks**:
- [ ] Expand achievement system
  - [ ] Social achievements (first follow, 100 followers)
  - [ ] XP milestones
  - [ ] Workout variety achievements
  - [ ] Community participation badges
- [ ] Create leagues/seasons
  - [ ] Weekly/Monthly competitions
  - [ ] Division-based matchmaking
  - [ ] Season rewards
  - [ ] League promotion/relegation
- [ ] Implement virtual rewards
  - [ ] Custom workout messages
  - [ ] Profile badges/frames
  - [ ] Exclusive workout types
  - [ ] Character customization

#### Phase 6: FameCoin Currency System

**Tasks**:
- [ ] Create FameCoin currency system (separate from XP)
  - [ ] Design coin earning mechanics
  - [ ] Implement coin spending/store
  - [ ] Transaction management
  - [ ] Balance tracking and history
  - [ ] CloudKit schema for coins
  - [ ] Coin animation effects

**Coin Earning Ideas**:
- Base coins per workout (less than XP)
- Bonus coins for personal records
- Daily login coins
- Achievement completion coins
- Social interaction coins
- Streak maintenance coins
- Challenge completion coins

**Spending Options**:
- Premium character skins
- Custom workout messages
- Profile decorations
- Booster packs (2x XP for next workout)
- Skip rest day (maintain streak)
- Custom app themes

#### Testing Strategy

**Unit Tests Required**:
- XP calculation algorithms
- Privacy rule enforcement
- Follow/Unfollow state management
- Feed generation logic
- Notification delivery

**Integration Tests Required**:
- CloudKit sync for social data
- Real-time feed updates
- Push notification delivery
- Image upload/download
- Cross-device synchronization

**UI Tests Required**:
- Profile creation flow
- User search and discovery
- Follow/Unfollow interactions
- Feed scrolling performance
- Privacy setting changes

**Security Tests Required**:
- Penetration testing for XP manipulation
- SQL injection prevention
- Rate limiting effectiveness
- Privacy setting enforcement
- Content moderation accuracy

#### Performance Considerations

- CloudKit query optimization for social graphs
- Efficient feed pagination
- Image caching strategy
- Background sync for social updates
- Offline mode handling

#### Compliance Requirements

- **Privacy Policy Update**: Detail social features
- **Terms of Service**: Community guidelines
- **Age Verification**: COPPA compliance
- **Data Protection**: GDPR/CCPA compliance
- **Content Moderation**: CSAM detection
- **Accessibility**: VoiceOver support for social features

---

## 🚀 **COMPLETED HIGH PRIORITY TASKS**

### 9. ✅ Fix Test Suite Regressions (Technical Debt)

**Status**: Completed (2025-07-18) ✨  
**Impact**: Medium - Restore test suite functionality

Fixed test failures and compilation errors introduced during CloudKit changes.

**Completed Tasks:**

- [x] Fixed deprecated `.dance` workout type to `.cardioDance` in FameFitCharacters.swift
- [x] Fixed SwiftLint violations (snake_case enum cases, cyclomatic complexity)
- [x] Created comprehensive BaseUITestCase for consistent UI testing
- [x] Added HealthKit permission interruption handlers
- [x] Implemented safe element access methods to prevent scrolling failures
- [x] Fixed WorkoutSyncQueueTests async race conditions
- [x] Removed unused `completeOnboardingIfNeeded()` method from UI tests
- [x] Fixed all remaining SwiftLint warnings (redundant enum values, trailing newlines, number separators)
- [x] Verified all unit tests compile and pass (iOS: 146 tests ✅, Watch: 79 tests ✅)
- [x] Documented remaining test limitations and expected failures in TESTING_LIMITATIONS.md
- [x] Ensured UI tests work reliably with HealthKit permission dialogs

### 8. ✅ Fix Test Compilation Issues (Technical Debt)

**Status**: Completed (2025-07-16) ✨  
**Impact**: Medium - Clean up test suite

Fixed compilation errors in test suite and documented Apple API limitations.

**Completed Tasks:**

- [x] Fixed MainViewTests compilation errors (duplicate methods, property name mismatches)
- [x] Fixed WorkoutSyncQueueTests compilation errors (missing test helper methods)
- [x] Documented Apple API limitations for deprecated HKWorkout in docs/TESTING_LIMITATIONS.md
- [x] Verified all test files compile successfully
- [x] Added comprehensive documentation explaining why deprecated HKWorkout API is required for testing

---

## 🔄 **Medium Priority - After Abstractions**

---

## 📋 **Low Priority - Future Work**

### 8. Abstract HealthKit Session Management

**Impact**: Medium - Direct HealthKit usage in WorkoutManager  
**Status**: Not Started

### 9. Add Logging Protocol  

**Impact**: Low - Current implementation is adequate  
**Status**: Not Started

### 10. Abstract Complication Data Provider

**Impact**: Low - Watch-specific, limited testing needs  
**Status**: Not Started

### 11. Protocol for Dependency Container

**Impact**: Low - Current implementation works well  
**Status**: Not Started

---

## ✅ **COMPLETED - Major Wins!**

### 1. ✅ WorkoutManager Protocol (Watch App)

**Status**: Completed (2025-07-16) ✨  
**Impact**: Critical for Watch app testability

- [x] Created `WorkoutManaging` protocol with all public properties/methods
- [x] Made `WorkoutManager` conform to the protocol
- [x] Updated all views to use the protocol type instead of concrete type
- [x] Created `MockWorkoutManager` for testing
- [x] Added comprehensive unit tests for Watch app views

### 2. ✅ NotificationStore Protocol (iOS App)  

**Status**: Completed (2025-07-16) ✨  
**Impact**: High - Used throughout the app

- [x] Created `NotificationStoring` protocol
- [x] Made `NotificationStore` conform to the protocol
- [x] Updated all consumers to use the protocol
- [x] Created `MockNotificationStore` for testing
- [x] Fixed notification limiting bug (properly keeps 50 most recent)

### 3. ✅ AchievementManager Protocol (Watch App)

**Status**: Completed (2025-07-16) ✨  
**Impact**: High - Removed UserDefaults coupling

- [x] Created `AchievementManaging` protocol with associated type
- [x] Created `AchievementPersisting` protocol for storage abstraction
- [x] Refactored `AchievementManager` to use dependency injection
- [x] Created mock implementations for testing
- [x] Added comprehensive achievement tests

### 4. ✅ View Model Pattern (MainView)

**Status**: Completed (2025-07-16) ✨  
**Impact**: High - Better separation of concerns

- [x] Created `MainViewModeling` protocol
- [x] Implemented `MainViewModel` with protocol-based dependencies
- [x] Updated `MainView` to use view model pattern
- [x] Created `MockMainViewModel` for testing
- [x] Identified reactive binding limitation with protocols

### 5. ✅ Publisher Support for Manager Protocols

**Status**: Completed (2025-07-16) ✨  
**Impact**: Critical - Enables reactive UI updates through protocols

- [x] Added publisher properties to CloudKitManaging protocol
- [x] Added publisher properties to AuthenticationManaging protocol
- [x] Added publisher properties to NotificationStoring protocol
- [x] Updated CloudKitManager to expose publishers using AnyPublisher
- [x] Updated AuthenticationManager to expose publishers
- [x] Modified MainViewModel to use protocol-based reactive binding
- [x] Created comprehensive reactive view model tests
- [x] Fixed mock implementations to support publishers

### 6. ✅ Abstract WorkoutSyncQueue

**Status**: Completed (2025-07-16) ✨  
**Impact**: Medium - Removed CloudKit coupling  

- [x] Created `WorkoutSyncQueuing` protocol with publisher support
- [x] Refactored `WorkoutSyncQueue` to use protocol-based CloudKit abstraction
- [x] Added comprehensive mock implementation (`MockWorkoutSyncQueue`)
- [x] Created thorough sync queue tests with publisher testing
- [x] Improved PendingWorkout structure with proper Equatable conformance

### 7. ✅ Create Message Provider Abstraction

**Status**: Completed (2025-07-16) ✨  
**Impact**: Medium - Enables personality customization and testing

- [x] Created `MessageProviding` protocol with personality configuration
- [x] Built `FameFitMessageProvider` with instance-based implementation
- [x] Added personality/roast level system (5 levels from encouragement to ruthless)
- [x] Implemented context-aware message generation (workout start/end/milestones)
- [x] Created comprehensive mock implementation (`MockMessageProvider`)
- [x] Added 40+ unit tests covering all message scenarios
- [x] Maintained backwards compatibility with existing `FameFitMessages` API
- [x] Prepared for future user customization features

---

## 📊 **Progress Tracking**

- **Total Items**: 13
- **✅ Completed**: 9 (Protocol abstractions + View Models + Reactive Support + SyncQueue + Messages + Test Fixes + Test Regressions)
- **🎯 Next Up**: Influencer XP & Social Networking System
- **🔄 Technical Debt**: 0 (all major issues resolved)
- **📋 Low Priority**: 4

**Completion Rate**: 69% of major items ✨

**Current Status**: Phase 1 of Influencer XP system FULLY COMPLETE! ✅ 
- All "followers" migrated to "Influencer XP"
- XP calculation engine with multipliers implemented
- UI progress tracking and level display complete
- Unlock notification system operational
- Persistent storage for achievements
- Comprehensive test coverage and QA documentation
Ready for Phase 2: User Profile System!

---

## 🎯 **Next Steps**

1. **Immediate Priority - Phase 2: User Profile System**:
   - Create User model and CloudKit schema
   - Build profile creation and management UI
   - Implement username validation
   - Add profile picture support

2. **Architecture Preparation**:
   - Design social networking protocols
   - Plan caching strategies for social data
   - Security audit current CloudKit implementation
   - Research content moderation solutions

3. **Low Priority Items** (after all social features and FameCoin):
   - Abstract HealthKit Session Management
   - Add Logging Protocol
   - Abstract Complication Data Provider
   - Protocol for Dependency Container

4. **Future Enhancements**:
   - Connect personality settings to user preferences
   - Add UI for roast level customization
   - Extend view model pattern to remaining views
   - Apple Watch companion for social features

---

## 🏆 **What We've Achieved**

The app architecture has been **dramatically improved**:

✅ **Protocol-Oriented Design**: Major components now use protocols instead of concrete dependencies  
✅ **Better Testability**: Comprehensive mocking capabilities for all core services  
✅ **Reduced Coupling**: Clean separation between interfaces and implementations  
✅ **Modern Swift Practices**: Dependency injection throughout the codebase  
✅ **Maintainable Code**: Clear interfaces make future changes much easier

**The foundation is now solid for scalable, testable iOS development!** 🚀

---

Last Updated: 2025-07-18
