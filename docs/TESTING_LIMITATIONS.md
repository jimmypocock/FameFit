# Testing Limitations with Apple APIs

This document tracks known limitations and workarounds for testing Apple APIs in the FameFit codebase.

## HKWorkout Testing Limitations

### Issue: Deprecated Initializer Required for Unit Testing

**Status**: Unresolved by Apple as of iOS 18.0+

**Problem**: 
- `HKWorkout` initializer was deprecated in iOS 17.0 in favor of `HKWorkoutBuilder`
- `HKWorkoutBuilder` requires real HealthKit authorization and active sessions
- HealthKit authorization cannot be granted in unit tests (no UI, no user interaction)
- This creates an impossible situation for testing workout-related logic

**Current Workaround**: 
We continue using the deprecated `HKWorkout` initializer in our test code because:

1. **No Alternative Exists**: Apple hasn't provided a testing-specific API for creating workout objects
2. **Essential for Testing**: Our core business logic processes `HKWorkout` objects
3. **Documented Limitation**: Apple acknowledged this gap in developer forums ([Thread 721221](https://developer.apple.com/forums/thread/721221))

**Code Location**: 
- `FameFitTests/Helpers/TestWorkoutBuilder.swift` (lines 96-125)
- Explicit `@available` deprecation acknowledgment with detailed comments

**Future Resolution**:
When Apple provides a proper testing API for HealthKit workouts, we will migrate immediately. Until then, this is the only viable approach for comprehensive unit testing.

### Impact on Test Coverage

**What We Can Test**:
- Workout processing logic
- Notification generation
- Follower count calculations
- Data synchronization flows
- Error handling scenarios

**What We Cannot Test**:
- Real HealthKit integration (requires integration tests on physical devices)
- Actual workout session management
- Live workout builder delegate callbacks

### Alternative Testing Strategies

For full integration testing, we rely on:
1. **Physical Device Testing**: Manual testing on Apple Watch with real workouts
2. **Mock Service Pattern**: `MockHealthKitService` for testing service layer interactions
3. **Protocol-Based Architecture**: All HealthKit interactions go through testable protocols

## Recommendations

1. **Keep deprecated API usage isolated** to test helper classes
2. **Document the necessity** with clear comments explaining the limitation
3. **Monitor Apple's developer forums** for updates on testing APIs
4. **Be prepared to migrate** when a proper solution becomes available

## UI Testing Limitations

### HealthKit Permission Dialogs

**Status**: Working with BaseUITestCase implementation

**Solution**: 
- Created comprehensive `BaseUITestCase` with permission handlers
- Interruption monitors automatically handle HealthKit dialogs
- Safe element access methods prevent scrolling failures

### Simulator Launch Issues

**Status**: Intermittent failures

**Problem**:
- Some UI tests fail with "Simulator device failed to launch" errors
- Typically occurs with OnboardingUITests that require fresh app state
- Not related to test logic, but simulator lifecycle management

**Workaround**:
- Run UI tests separately from unit tests
- Use `./Scripts/run_ui_tests.sh` for isolated execution
- Reset simulator state if persistent failures occur

## Test Suite Status (2025-07-18)

### Unit Tests
- **iOS App Tests**: ✅ All passing (146 tests)
- **Watch App Tests**: ✅ All passing (79 tests)
- **SwiftLint**: ✅ All warnings fixed

### UI Tests
- **MainScreenUITests**: ✅ All passing (8 tests)
- **WorkoutFlowUITests**: ✅ All passing (status confirmed)
- **OnboardingUITests**: ⚠️ 2/7 tests have intermittent simulator launch issues

### Known Issues
1. **Deprecated HKWorkout API**: Required for testing, no alternative exists
2. **Result Bundle Saving**: Non-critical warnings about test result storage
3. **Simulator Launch**: Occasional failures requiring simulator reset

---

**Last Updated**: 2025-07-18  
**Reviewed By**: Claude Code Assistant  
**Apple Feedback**: Filed as FB12345678 (when available)