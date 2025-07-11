# FameFit Watch App Test Plan

## Test Strategy

### 1. Unit Tests (Fast, Run on Every Commit)

- **Purpose**: Test individual components in isolation
- **What to test**:
  - Data models
  - Business logic
  - State management
- **What NOT to test**:
  - HealthKit integration (can't mock properly)
  - UI behavior
  - Navigation

### 2. Integration Tests (Run on PR)

- **Purpose**: Test component interactions
- **What to test**:
  - State flow through the app
  - Data persistence
  - Error handling paths

### 3. UI Tests (Run on Main Branch)

- **Purpose**: Test actual user workflows
- **Critical Paths**:
  1. Start workout → See metrics → End workout → View summary
  2. Start workout → Pause → Resume → End
  3. Start workout → Switch tabs → End workout
  4. Navigate between workout types

### 4. Manual Testing Protocol

Before each release, manually verify:

#### Basic Flow

- [ ] Launch app
- [ ] All 3 workout types visible
- [ ] Tap each workout type - navigates correctly
- [ ] Metrics display and update
- [ ] Pause button shows correct state
- [ ] Resume button works
- [ ] End workout doesn't freeze
- [ ] Summary shows correct data
- [ ] Summary dismissal returns to start

#### Edge Cases

- [ ] Start workout and immediately end
- [ ] Rapidly tap pause/resume
- [ ] Navigate away during workout
- [ ] Low battery mode behavior
- [ ] Always-on display mode

#### HealthKit Integration

- [ ] First launch - permission request appears
- [ ] Denying permissions - app handles gracefully
- [ ] Workout saves to Health app
- [ ] Metrics match Health app data

## Continuous Integration Setup

### GitHub Actions Workflow

```yaml
name: Watch App Tests

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  unit-tests:
    runs-on: macos-latest
    steps:
    - uses: actions/checkout@v3
    - name: Run Unit Tests
      run: |
        xcodebuild test \
          -workspace FameFit.xcworkspace \
          -scheme "FameFit Watch App" \
          -destination 'platform=watchOS Simulator,name=Apple Watch Series 10 (46mm)' \
          -only-testing:FameFit_Watch_AppTests

  ui-tests:
    runs-on: macos-latest
    steps:
    - uses: actions/checkout@v3
    - name: Run UI Tests
      run: |
        xcodebuild test \
          -workspace FameFit.xcworkspace \
          -scheme "FameFit Watch App" \
          -destination 'platform=watchOS Simulator,name=Apple Watch Series 10 (46mm)' \
          -only-testing:FameFit_Watch_AppUITests
```

## Test Coverage Goals

- Unit Tests: 80% code coverage
- UI Tests: All critical user paths
- Integration Tests: All state transitions

## Known Limitations

1. Can't mock HKWorkoutSession (Apple's framework)
2. Can't test actual HealthKit data saving in unit tests
3. Can't test hardware features (heart rate sensor)
4. UI tests on watchOS are limited compared to iOS

## Best Practices

1. **Test behavior, not implementation**
2. **Focus on user journeys**
3. **Keep UI tests simple and reliable**
4. **Use manual testing for HealthKit integration**
5. **Document flaky tests**
