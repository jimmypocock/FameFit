# FameFit Testing Strategy

## Overview

This document outlines the comprehensive testing strategy for FameFit, including unit tests, integration tests, UI tests, and manual testing procedures.

## Test Coverage Goals

- **Unit Tests**: >80% code coverage
- **Integration Tests**: All critical user flows
- **UI Tests**: Key user journeys
- **Performance Tests**: Memory and speed benchmarks

## Test Categories

### 1. Unit Tests

#### Core Components
- **Models**: All data models should have comprehensive tests
  - `WorkoutHistoryItem`: Serialization, XP calculations
  - `UserProfile`: Privacy settings, data validation
  - `NotificationItem`: Type handling, metadata
  - `GroupWorkout`: State transitions, participant management

#### Services
- **CloudKitManager**: CRUD operations, error handling
- **HealthKitService**: Authorization, data fetching
- **NotificationManager**: Scheduling, permission handling
- **WorkoutSyncManager**: Sync logic, conflict resolution
- **Social Services**: Following, kudos, comments

#### ViewModels
- **MainViewModel**: State management, reactive updates
- **SocialFeedViewModel**: Real-time updates, pagination
- **NotificationCenterViewModel**: Notification handling

### 2. Integration Tests

#### Critical Flows
1. **Workout Detection Flow**
   - HealthKit → WorkoutObserver → WorkoutSyncManager → CloudKit
   - Notifications triggered correctly
   - XP calculations and updates

2. **Social Interaction Flow**
   - Following users → Activity feed updates
   - Kudos → Notifications → XP awards
   - Comments → Real-time updates

3. **Notification Pipeline**
   - Workout completion → Character selection → Message generation
   - Push notification delivery
   - In-app notification store updates

### 3. UI Tests

#### Key User Journeys
1. **Onboarding Flow**
   - Sign in with Apple
   - HealthKit permissions
   - Character introduction

2. **Workout Tracking**
   - Start workout on Watch
   - View live metrics
   - Complete and sync

3. **Social Features**
   - Search and follow users
   - View activity feed
   - Give kudos and comment

### 4. Performance Tests

#### Metrics to Monitor
- **Memory Usage**: During workout tracking
- **Sync Performance**: Large workout history
- **UI Responsiveness**: Feed scrolling, transitions
- **Battery Impact**: Background sync operations

## Mock Strategy

### Mock Services
All external dependencies should have comprehensive mocks:

1. **MockCloudKitManager**: Simulates CloudKit operations
2. **MockHealthKitService**: Provides test workout data
3. **MockNotificationManager**: Tracks notification calls
4. **MockUserProfileService**: Returns diverse test profiles
5. **MockGroupWorkoutService**: Simulates group workouts

### Mock Data Guidelines
- Use realistic data that covers edge cases
- Include diverse user profiles for social features
- Test with various workout types and durations
- Cover error scenarios and network failures

## Testing Best Practices

### 1. Test Naming
Use descriptive names that explain the scenario:
```swift
func testWorkoutCompletion_WithHighXP_TriggersMultipleMilestones()
func testFollowUser_WhenRateLimited_ShowsAppropriateError()
```

### 2. Test Structure
Follow Arrange-Act-Assert pattern:
```swift
func testExample() async throws {
    // Given (Arrange)
    let workout = createTestWorkout()
    
    // When (Act)
    let result = try await sut.processWorkout(workout)
    
    // Then (Assert)
    XCTAssertEqual(result.xpEarned, 50)
}
```

### 3. Async Testing
- Use async/await for cleaner asynchronous tests
- Avoid XCTestExpectation when possible
- Keep tests synchronous where feasible

### 4. Test Isolation
- Each test should be independent
- Reset state in setUp/tearDown
- Don't rely on test execution order

## Continuous Integration

### Pre-commit Checks
1. Run unit tests locally
2. Check code coverage
3. Verify no failing tests

### CI Pipeline
1. Run all unit tests
2. Run integration tests
3. Generate coverage reports
4. Run UI tests on multiple simulators

## Manual Testing Checklist

### Before Release
- [ ] Test on physical Apple Watch
- [ ] Verify HealthKit permissions flow
- [ ] Test notification delivery
- [ ] Check offline functionality
- [ ] Verify CloudKit sync
- [ ] Test with multiple Apple IDs
- [ ] Check accessibility features
- [ ] Test in different languages

### Device Matrix
- iPhone models: 12, 13, 14, 15, 16 series
- Apple Watch: Series 6+, SE, Ultra
- iOS versions: 17.0+
- watchOS versions: 10.0+

## Debugging Failed Tests

### Common Issues
1. **Timing Issues**: Use proper async/await
2. **Mock Data**: Ensure mocks return expected data
3. **State Pollution**: Check setUp/tearDown
4. **Simulator Issues**: Reset simulator if needed

### Debugging Tools
- Xcode test navigator
- Console logs with `FameFitLogger`
- Breakpoints in test code
- View hierarchy debugger for UI tests

## Test Maintenance

### Regular Tasks
- Review and update tests when features change
- Remove obsolete tests
- Refactor duplicate test code
- Update mock data to match production

### Quarterly Review
- Analyze test coverage reports
- Identify untested code paths
- Review test execution times
- Update testing documentation

## Environment Variables for Testing

```bash
# Enable mock social data
USE_MOCK_SOCIAL=1

# Skip onboarding for UI tests
--skip-onboarding

# Reset all state
--reset-state

# Use mock HealthKit data
--mock-healthkit
```

## Conclusion

A robust testing strategy ensures FameFit remains reliable and bug-free. Follow these guidelines to maintain high-quality code and catch issues before they reach users.