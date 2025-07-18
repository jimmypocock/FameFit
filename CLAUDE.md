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
- For iOS app: Select "FameFit" scheme, choose iPhone simulator
- For Watch app: Select "FameFit Watch App" scheme, choose Watch simulator
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
# Run comprehensive test suite (includes SwiftLint)
./Scripts/test.sh

# Run UI tests separately to avoid simulator conflicts
./Scripts/run_ui_tests.sh

# Reset environment if tests have issues
./Scripts/reset_testing_env.sh

# Or use Xcode directly (⌘+U)

# Run tests with coverage report
xcodebuild test -workspace FameFit.xcworkspace -scheme FameFit -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -enableCodeCoverage YES

# Run specific test file
xcodebuild test -workspace FameFit.xcworkspace -scheme FameFit -only-testing:FameFitTests/WorkoutManagerTests
```

**Test Structure:**
- iOS app unit tests: `FameFitTests/`
- iOS app UI tests: `FameFitUITests/`
- Watch app unit tests: `FameFit Watch AppTests/`
- Watch app UI tests: `FameFit Watch AppUITests/`

**Best Practices:**
- Mock external dependencies (CloudKit, HealthKit)
- Test edge cases and error scenarios
- Aim for >80% code coverage
- Keep tests fast and isolated
- Use descriptive test names that explain the scenario
- Write synchronous tests where possible
- Each test should test ONE specific behavior
- UI tests should focus on user flows, not exact text
- Use launch arguments for UI test setup (e.g., `--skip-onboarding`)

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
- iOS App: `com.jimmypocock.FameFit`
- Watch App: `com.jimmypocock.FameFit.watchkitapp`

### Required Capabilities
- HealthKit (read/write workout data)
- CloudKit (private database)
- Sign in with Apple (iOS app)
- Background Modes: remote notifications, workout-processing

### Deployment Target
- iOS 17.0+
- watchOS 10.0+
- Xcode 16.0+ (16.4 recommended)

## Common Tasks

### Adding New Workout Types
1. Add to `workoutTypes` array in `WatchStartView.swift`
2. Update name mapping in `HKWorkoutActivityType` extension
3. Consider if new `HKQuantityType` permissions needed in `WorkoutManager.requestAuthorization()`

### Modifying Metrics Display
- Update `MetricsView.swift` for layout changes
- Modify `WorkoutManager.updateForStatistics()` for new metric calculations
- Add new `@Published` properties in `WorkoutManager` for additional metrics

### Customizing Summary
- Edit `SummaryView.swift` to add/remove summary metrics
- Use `SummaryMetricView` component for consistent styling

### Timeline Schedule Adjustments
- Modify `MetricsTimelineSchedule` in `MetricsView.swift`
- Adjust update frequencies for `.lowFrequency` (Always On) vs `.live` modes

## Project Structure

The project uses Xcode 16's synchronized file groups. Always use the `.xcworkspace` file, not `.xcodeproj`.

### Key Files:
- `Shared/` - Code shared between iOS and Watch apps
- `FameFit/` - iOS companion app
- `FameFit Watch App/` - Apple Watch workout app
- `Scripts/` - Build and test automation scripts

## Testing Improvements

### Mock Services
- `MockCloudKitManager` - Simulates CloudKit operations synchronously
- `MockHealthKitService` - Provides test workout data with date filtering
- All mocks update state immediately for predictable testing

### UI Testing Setup
The app supports launch arguments for UI testing:
- `--skip-onboarding` - Sets up authenticated state with mock data
- `--reset-state` - Clears all user data for fresh onboarding tests
- `--mock-healthkit` - Uses mock HealthKit data

### Common Issues and Solutions
1. **Test runner crashes**: Run `./Scripts/reset_testing_env.sh`
2. **Asset catalog errors**: Empty AppIcon.appiconset/Contents.json is intentional
3. **Async test failures**: Tests are now synchronous where possible
4. **UI test brittleness**: Tests now check for UI flows, not exact text

## CloudKit Configuration

### Setting Up Record Types
When creating new CloudKit record types, follow these steps:

1. **Access CloudKit Dashboard**: https://icloud.developer.apple.com/dashboard
2. **Create Record Type**: Schema → Record Types → Add new type
3. **Configure Fields**: Add all fields with appropriate types and mark as Queryable/Sortable as needed
4. **CRITICAL - Add System Index**: 
   - Go to Schema → Indexes
   - Add an index for `___recordID` (three underscores) as QUERYABLE
   - This prevents "Field 'recordName' is not marked queryable" errors
   - Despite the error mentioning 'recordName', you must make 'recordID' queryable
5. **Deploy Changes**: Always deploy schema changes to Production

### Example: WorkoutHistory Record Type
Fields configuration:
- `workoutId` (String) - Queryable, Sortable
- `workoutType` (String) - Queryable, Sortable  
- `startDate` (Date/Time) - Queryable, Sortable
- `endDate` (Date/Time) - Queryable, Sortable
- `duration` (Double) - Queryable
- `totalEnergyBurned` (Double) - Queryable
- `totalDistance` (Double) - Queryable
- `averageHeartRate` (Double) - Queryable
- `followersEarned` (Int64) - Queryable
- `source` (String) - Queryable

Required Index:
- `___recordID` - QUERYABLE (prevents query errors)