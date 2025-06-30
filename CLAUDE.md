# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

ToughLove is an Apple Watch workout application built with SwiftUI and HealthKit. Based on Apple's WWDC sample code, it provides real-time workout tracking with metrics display and Always On display support.

## Development Commands

### Building and Running
- Open `WWDC_WatchApp.xcodeproj` in Xcode
- Select the "WWDC_WatchApp WatchKit App" scheme
- Build and run on Apple Watch simulator or physical device (⌘+R)

### Testing
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
```
WWDC_WatchAppApp (App entry point)
├── NavigationView
│   └── StartView (Workout selection)
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
- Main: `com.paigesoftware.worthreadingntimes.WWDC-WatchApp`
- WatchKit App: `com.paigesoftware.worthreadingntimes.WWDC-WatchApp.watchkitapp`
- Extension: `com.paigesoftware.worthreadingntimes.WWDC-WatchApp.watchkitapp.watchkitextension`

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