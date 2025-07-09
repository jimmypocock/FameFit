# FameFit Testing Guide

## Running Watch App Tests in Xcode

### Method 1: Using Xcode UI (Easiest for Beginners)

1. **Open Xcode**
   - Open `FameFit.xcworkspace` (not the .xcodeproj)

2. **Select the Watch Scheme**
   - In the scheme selector (top left), choose "FameFit Watch App"
   - Select destination: "iPhone 16 Pro + Watch" (or any paired simulator)

3. **Run Unit Tests**
   - Press `Cmd + U` or Product → Test
   - Tests will run on the watch simulator

4. **Run Specific Tests**
   - Open Test Navigator (Cmd + 6)
   - Click the play button next to individual tests or test classes

5. **Run UI Tests**
   - UI tests require the app to be installed first
   - Press `Cmd + R` to run the app
   - Then `Cmd + U` to run tests

### Method 2: Command Line

```bash
# Run all watch app tests
xcodebuild test \
  -workspace FameFit.xcworkspace \
  -scheme "FameFit Watch App" \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 10 (46mm)'

# Run specific test class
xcodebuild test \
  -workspace FameFit.xcworkspace \
  -scheme "FameFit Watch App" \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 10 (46mm)' \
  -only-testing:FameFit_Watch_AppTests/WorkoutManagerTests

# Run UI tests only
xcodebuild test \
  -workspace FameFit.xcworkspace \
  -scheme "FameFit Watch App" \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 10 (46mm)' \
  -only-testing:FameFit_Watch_AppUITests
```

## Testing Companion App Communication

### 1. **Paired Simulator Testing**

When you select "iPhone 16 Pro + Watch" as destination:

- Both simulators launch together
- They're automatically paired
- Can test WatchConnectivity features

### 2. **Manual Testing Process**

```
1. Launch iOS app on iPhone simulator
2. Launch Watch app on paired watch simulator
3. Test features that require both:
   - Data sync
   - Shared CloudKit data
   - HealthKit permissions
```

### 3. **Testing Watch-Specific Features**

```swift
// In your UI tests, handle watch-specific UI
func testWatchWorkoutFlow() {
    let app = XCUIApplication()
    
    // Watch apps use different navigation
    app.buttons["Run"].tap()
    
    // Swipe between pages (watch-specific)
    app.swipeLeft() // Go to metrics
    app.swipeRight() // Go back to controls
    
    // Handle crown scrolling
    app.scrollViews.firstMatch.scroll(byDeltaX: 0, deltaY: -100)
}
```

## Common Testing Scenarios

### 1. **Fresh Install Test**

```bash
# Reset simulators
xcrun simctl erase all

# Install and test
xcodebuild test -workspace FameFit.xcworkspace -scheme "FameFit Watch App" -destination 'platform=watchOS Simulator,name=Apple Watch Series 10 (46mm)'
```

### 2. **Permission Testing**

- Reset privacy settings: Settings → General → Reset → Reset Location & Privacy
- Run app to test permission flows

### 3. **Background Testing**

- Start workout
- Press Digital Crown to go to watch face
- Verify workout continues in background

### 4. **Always-On Display Testing**

- In Simulator: Device → Always On Display → Enable
- Verify UI updates appropriately

## Debugging Test Failures

### 1. **View Test Logs**

```bash
# After test run, logs are in:
~/Library/Developer/Xcode/DerivedData/FameFit-*/Logs/Test/

# Or in Xcode:
# Report Navigator (Cmd + 9) → Select test run → View logs
```

### 2. **Screenshot on Failure**

```swift
// Add to UI tests
override func tearDown() {
    if testRun?.failureCount ?? 0 > 0 {
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
```

### 3. **Common Issues**

**"Unable to find device"**

- Solution: Use specific device ID or update destination

**"App not installed"**

- Solution: Run app first with Cmd+R, then tests

**"HealthKit permission dialog blocking test"**

- Solution: Add UI interruption monitor (already in our tests)

## Best Practices

1. **Test on Multiple Watch Sizes**
   - 41mm/45mm (Series 7-9)
   - 40mm/44mm (Series 4-6)
   - Different screen sizes can reveal UI issues

2. **Test State Restoration**
   - Kill app during workout
   - Relaunch and verify state

3. **Test Real Device Features** (Manual)
   - Heart rate sensor
   - GPS tracking
   - Haptic feedback
   - Digital Crown rotation

4. **Performance Testing**

   ```swift
   func testWorkoutStartPerformance() {
       measure {
           // Test workout start time
           app.buttons["Run"].tap()
           _ = app.buttons["pause"].waitForExistence(timeout: 10)
       }
   }
   ```

## Continuous Integration

### GitHub Actions Setup

```yaml
name: Test Watch App

on: [push, pull_request]

jobs:
  test:
    runs-on: macos-latest
    steps:
    - uses: actions/checkout@v3
    
    - name: Select Xcode
      run: sudo xcode-select -s /Applications/Xcode.app
    
    - name: Run Tests
      run: |
        xcodebuild test \
          -workspace FameFit.xcworkspace \
          -scheme "FameFit Watch App" \
          -destination 'platform=watchOS Simulator,OS=latest,name=Apple Watch Series 10 (46mm)' \
          -resultBundlePath TestResults.xcresult
    
    - name: Upload Test Results
      if: always()
      uses: actions/upload-artifact@v3
      with:
        name: test-results
        path: TestResults.xcresult
```

## Quick Test Commands

```bash
# Just build tests (fast check)
./Scripts/test.sh build-tests

# Run unit tests only
./Scripts/test.sh unit

# Run UI tests only  
./Scripts/test.sh ui

# Run all tests
./Scripts/test.sh all

# Run tests with coverage
./Scripts/test.sh coverage
```
