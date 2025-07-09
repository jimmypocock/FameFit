# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

FameFit is a companion iOS and Apple Watch application built with SwiftUI, HealthKit, and CloudKit. The iOS app handles user onboarding, authentication, and displays progress, while the Watch app provides real-time workout tracking. The apps work together as companions, sharing data through CloudKit.

**Important**: This is a companion app setup - the iOS app and Watch app are meant to work together. The Watch app is a dependency of the iOS app and should NOT be removed from target dependencies.

## Development Philosophy

### Test-Driven Development (TDD)
This project follows Test-Driven Development principles:
1. **Write the test first** - Before implementing any feature, write a failing test that describes the expected behavior
2. **Make it pass** - Write the minimum code necessary to make the test pass
3. **Refactor** - Improve the code while keeping tests green
4. **Never commit code without tests** - All new features and bug fixes must include appropriate test coverage

### Dependency Injection
To ensure testability, this project uses dependency injection instead of singletons:
- Managers are injected via `@EnvironmentObject` or initializer parameters
- This allows for easy mocking in tests
- Avoid using `.shared` singleton instances directly in views or business logic

## Development Commands

### Building and Running

**From Xcode:**
- Open `FameFit.xcworkspace` (NOT the .xcodeproj)
- For iOS app: Select "FameFit-iOS" scheme, choose iPhone simulator
- For Watch app: Select "FameFit-Watch" scheme, choose Watch simulator
- Build and run (⌘+R)

**From Command Line:**
```bash
# Build iOS app only
./Scripts/build.sh ios

# Build Watch app only
./Scripts/build.sh watch

# Build both apps
./Scripts/build.sh
```

### Testing

**Unit Tests:**
```bash
# Run all tests
./test

# Run tests with coverage report
xcodebuild test -workspace FameFit.xcworkspace -scheme FameFit-iOS -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -enableCodeCoverage YES

# Run specific test file
xcodebuild test -workspace FameFit.xcworkspace -scheme FameFit-iOS -only-testing:FameFitTests/AuthenticationManagerTests
```

**Test Structure:**
- Unit tests go in `FameFitTests/` 
- Integration tests go in `FameFitIntegrationTests/`
- Watch app tests go in `FameFit Watch AppTests/`

**Best Practices:**
- Mock external dependencies (CloudKit, HealthKit)
- Test edge cases and error scenarios
- Aim for >80% code coverage
- Keep tests fast and isolated
- Use descriptive test names that explain the scenario

**Manual Testing:**
- Run on Apple Watch simulator or physical device through Xcode
- Physical device testing requires Apple Developer account
- HealthKit testing requires device with health data

### Debugging
- Use Xcode's debugging tools and console
- Check HealthKit authorization status if data isn't appearing
- Verify entitlements for device builds

## Architecture

### Core Components

**WorkoutManager** (`WorkoutManager.swift`)
- Central state management for workouts
- Implements `HKWorkoutSessionDelegate` and `HKLiveWorkoutBuilderDelegate`
- Manages HealthKit session lifecycle
- Publishes real-time metrics via `@Published` properties

**View Hierarchy**

iOS App (FameFit):
```
FameFitApp
├── OnboardingView (if not authenticated)
│   ├── Character introductions
│   ├── Sign in with Apple
│   └── HealthKit permissions
└── MainView (if authenticated)
    └── Displays follower count and stats
```

Watch App (FameFit Watch App):
```
FameFitApp
├── NavigationStack
│   └── WatchStartView (Workout selection)
│       └── SessionPagingView (Active workout tabs)
│           ├── ControlsView (Pause/End)
│           ├── MetricsView (Live metrics)
│           └── NowPlayingView (Media controls)
└── SummaryView (Post-workout summary - modal sheet)
```

### Key Implementation Details

**HealthKit Integration**
- Authorization required for: heart rate, active energy, distance, activity summary
- Uses `HKWorkoutSession` for session management
- `HKLiveWorkoutBuilder` for real-time data collection
- Metrics updated via delegate callbacks

**Always On Display Support**
- `TimelineView` with custom `MetricsTimelinesSchedule` for efficient updates
- Adjusts update frequency based on `TimelineScheduleMode`
- Subsecond precision shown only in active mode

**Data Flow**
1. User selects workout type → sets `WorkoutManager.selectedWorkout`
2. `didSet` triggers `startWorkout()` → creates session and builder
3. Delegate methods update `@Published` properties
4. SwiftUI views automatically update via property observation

## Important Configuration

### Bundle Identifiers
- Main: `com.jimmypocock.FameFit`
- Watch App: `com.jimmypocock.FameFitWatchApp`

### Required Capabilities
- HealthKit (read/write workout data)
- Background Modes: workout-processing

### Deployment Target
- watchOS 8.0+
- Swift 5.0

## Common Tasks

### Adding New Workout Types
1. Add to `workoutTypes` array in `StartView.swift:312`
2. Update name mapping in `HKWorkoutActivityType` extension (`StartView.swift:342`)
3. Consider if new `HKQuantityType` permissions needed in `WorkoutManager.requestAuthorization()`

### Modifying Metrics Display
- Update `MetricsView.swift` for layout changes
- Modify `WorkoutManager.updateForStatistics()` for new metric calculations
- Add new `@Published` properties in `WorkoutManager` for additional metrics

### Customizing Summary
- Edit `SummaryView.swift` to add/remove summary metrics
- Use `SummaryMetricView` component for consistent styling

### Timeline Schedule Adjustments
- Modify `MetricsTimelinesSchedule` in `MetricsView.swift:771`
- Adjust update frequencies for `.lowFrequency` (Always On) vs `.live` modes