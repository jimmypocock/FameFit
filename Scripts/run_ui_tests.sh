#!/bin/bash

echo "🧪 Running UI tests..."

# Set environment to reduce resource usage
export XCODE_BUILD_SETTINGS_TIMEOUT=180
export SIMULATOR_DEVICE_TIMEOUT=300

# Run tests one at a time to avoid conflicts
echo "Running MainScreenUITests..."
xcodebuild test \
    -workspace FameFit.xcworkspace \
    -scheme FameFit \
    -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
    -only-testing:FameFitUITests/MainScreenUITests \
    -parallel-testing-enabled NO \
    -maximum-concurrent-test-simulator-destinations 1 \
    -quiet \
    2>&1 | grep -E "(Test Suite|passed|failed)" || true

echo ""
echo "Running WorkoutFlowUITests..."
xcodebuild test \
    -workspace FameFit.xcworkspace \
    -scheme FameFit \
    -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
    -only-testing:FameFitUITests/WorkoutFlowUITests \
    -parallel-testing-enabled NO \
    -maximum-concurrent-test-simulator-destinations 1 \
    -quiet \
    2>&1 | grep -E "(Test Suite|passed|failed)" || true

echo "✅ UI tests complete!"