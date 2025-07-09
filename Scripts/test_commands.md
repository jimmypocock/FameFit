# Xcode Test Commands Reference

## Standard xcodebuild Commands (Most Common)

### 1. Run All Tests
```bash
# Basic test command
xcodebuild test -workspace FameFit.xcworkspace -scheme FameFit-iOS -destination 'platform=iOS Simulator,name=iPhone 15 Pro'

# With prettier output using xcpretty (recommended)
xcodebuild test -workspace FameFit.xcworkspace -scheme FameFit-iOS -destination 'platform=iOS Simulator,name=iPhone 15 Pro' | xcpretty

# Install xcpretty if needed
gem install xcpretty
```

### 2. Run Specific Test Classes
```bash
# Run only WorkoutObserverTests
xcodebuild test -workspace FameFit.xcworkspace -scheme FameFit-iOS -destination 'platform=iOS Simulator,name=iPhone 15 Pro' -only-testing:FameFitTests/WorkoutObserverTests

# Run multiple specific test classes
xcodebuild test -workspace FameFit.xcworkspace -scheme FameFit-iOS -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  -only-testing:FameFitTests/WorkoutObserverTests \
  -only-testing:FameFitTests/CloudKitManagerTests
```

### 3. Run Specific Test Methods
```bash
# Run a single test method
xcodebuild test -workspace FameFit.xcworkspace -scheme FameFit-iOS -destination 'platform=iOS Simulator,name=iPhone 15 Pro' -only-testing:FameFitTests/WorkoutObserverTests/testStartObservingWorkouts_EnablesBackgroundDelivery
```

### 4. Skip Specific Tests
```bash
# Run all tests except UI tests
xcodebuild test -workspace FameFit.xcworkspace -scheme FameFit-iOS -destination 'platform=iOS Simulator,name=iPhone 15 Pro' -skip-testing:FameFitUITests
```

## Using Swift Package Manager (if applicable)
```bash
# If using SPM
swift test

# Run specific tests
swift test --filter WorkoutObserverTests
```



## Using xcode-select and xcrun
```bash
# Ensure correct Xcode version
sudo xcode-select -s /Applications/Xcode.app

# Run tests using xcrun
xcrun xcodebuild test -workspace FameFit.xcworkspace -scheme FameFit-iOS -destination 'platform=iOS Simulator,name=iPhone 15 Pro'
```

## Test Results and Reports

### 1. Generate JUnit XML (for CI systems)
```bash
xcodebuild test -workspace FameFit.xcworkspace -scheme FameFit-iOS -destination 'platform=iOS Simulator,name=iPhone 15 Pro' -resultBundlePath TestResults.xcresult

# Convert to JUnit format
xcrun xcresulttool format --output-path test-results.xml TestResults.xcresult
```

### 2. Generate HTML Report
```bash
# Using xcov
xcov --workspace FameFit.xcworkspace --scheme FameFit-iOS --output_directory coverage_report

# Using slather
slather coverage --html --scheme FameFit-iOS FameFit.xcworkspace
```

## Environment Variables for Testing
```bash
# Run tests with specific environment variables
env TEST_ENV=CI xcodebuild test -workspace FameFit.xcworkspace -scheme FameFit-iOS -destination 'platform=iOS Simulator,name=iPhone 15 Pro'
```

## Parallel Testing
```bash
# Run tests in parallel (faster)
xcodebuild test -workspace FameFit.xcworkspace -scheme FameFit-iOS -destination 'platform=iOS Simulator,name=iPhone 15 Pro' -parallel-testing-enabled YES -parallel-testing-worker-count 4
```

## Which Approach is "Normal"?

1. **Most iOS Teams Use**:
   - Xcode GUI for day-to-day development (⌘+U)
   - Direct `xcodebuild` commands for CI/CD
   - Custom scripts for specific workflows

2. **Benefits of Each**:
   - **xcodebuild**: Direct, no dependencies, full control
   - **Custom scripts**: Good for project-specific workflows
   - **Xcode GUI**: Visual feedback, integrated debugging

3. **Recommended Setup**:
   ```bash
   # For development
   ⌘+U in Xcode
   
   # For CI/CD
   xcodebuild test ... | xcpretty --report junit
   
   # For comprehensive testing
   ./Scripts/test.sh
   ```