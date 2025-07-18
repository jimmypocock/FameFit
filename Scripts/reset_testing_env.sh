#!/bin/bash

echo "🧹 Resetting Xcode testing environment..."

# Kill simulator
echo "Stopping simulator..."
killall Simulator 2>/dev/null || true

# Kill Xcode processes that might be stuck
echo "Cleaning up Xcode processes..."
killall Xcode 2>/dev/null || true
killall xcodebuild 2>/dev/null || true

# Clean derived data
echo "Cleaning derived data..."
rm -rf ~/Library/Developer/Xcode/DerivedData/FameFit-*

# Reset simulators
echo "Resetting simulators..."
xcrun simctl shutdown all
xcrun simctl erase all

# Clean build
echo "Cleaning build..."
if [ -f "FameFit.xcworkspace" ]; then
    xcodebuild clean -workspace FameFit.xcworkspace -scheme FameFit -quiet || true
fi

# Restart CoreSimulator
echo "Restarting CoreSimulator service..."
sudo killall -9 com.apple.CoreSimulator.CoreSimulatorService 2>/dev/null || true

echo "✅ Environment reset complete!"
echo ""
echo "Next steps:"
echo "1. Open Xcode"
echo "2. Select Product → Clean Build Folder (⇧⌘K)"
echo "3. Run tests again"