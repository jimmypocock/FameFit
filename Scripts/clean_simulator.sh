#!/bin/bash

# Clean simulator caches to fix LaunchServices errors
echo "Cleaning simulator caches..."

# Kill any running simulator processes
killall Simulator 2>/dev/null || true

# Clean derived data
echo "Cleaning derived data..."
rm -rf ~/Library/Developer/Xcode/DerivedData/FameFit-*

# Reset LaunchServices database for simulators
echo "Resetting LaunchServices..."
xcrun simctl shutdown all
xcrun simctl erase all

# Clean build folder
echo "Cleaning build folder..."
xcodebuild -workspace FameFit.xcworkspace -scheme "FameFit Watch App" -configuration Debug clean

echo "Cleanup complete! Try running tests again."