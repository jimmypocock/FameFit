#!/bin/bash

# Fix XCTest device issues after simulator reset
# This script helps resolve "No matching device" and simulator launch errors

echo "🔧 Fixing XCTest device and simulator issues..."

# Kill all simulator-related processes
echo "📱 Stopping simulators and related processes..."
killall "Simulator" 2>/dev/null || true
killall "SimulatorTrampoline" 2>/dev/null || true
killall "CoreSimulatorService" 2>/dev/null || true
xcrun simctl shutdown all 2>/dev/null || true

# Wait for processes to terminate
sleep 2

# Clean specific test device if provided as argument
if [ -n "$1" ]; then
    echo "🗑️  Removing specific device: $1"
    rm -rf ~/Library/Developer/XCTestDevices/"$1" 2>/dev/null || true
else
    # Clean all XCTest devices if none specified
    echo "🗑️  Cleaning all XCTest devices..."
    rm -rf ~/Library/Developer/XCTestDevices/* 2>/dev/null || true
fi

# Reset simulator preferences that might be corrupted
echo "♻️  Resetting simulator preferences..."
rm -rf ~/Library/Preferences/com.apple.iphonesimulator.plist 2>/dev/null || true
rm -rf ~/Library/Preferences/com.apple.CoreSimulator.plist 2>/dev/null || true

# Clean build
echo "🧹 Cleaning build..."
if [ -f "FameFit.xcworkspace" ]; then
    xcodebuild -workspace FameFit.xcworkspace -scheme FameFit clean -quiet
else
    echo "⚠️  FameFit.xcworkspace not found. Run from project root."
fi

# Clear DerivedData for FameFit
echo "🗂️  Clearing DerivedData..."
rm -rf ~/Library/Developer/Xcode/DerivedData/FameFit-* 2>/dev/null || true

# Clear module cache to prevent stale data
echo "🧹 Clearing module cache..."
rm -rf ~/Library/Developer/Xcode/DerivedData/ModuleCache.noindex 2>/dev/null || true

# Boot preferred test device
echo "🚀 Attempting to boot test simulators..."
# Try to boot iPhone 16 Pro for iOS tests
IPHONE_ID=$(xcrun simctl list devices available | grep "iPhone 16 Pro" | grep -v "Max" | head -1 | grep -o -E "[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}" || true)
if [ -n "$IPHONE_ID" ]; then
    echo "📱 Booting iPhone 16 Pro: $IPHONE_ID"
    xcrun simctl boot "$IPHONE_ID" 2>/dev/null || true
fi

# Try to boot Apple Watch for Watch tests
WATCH_ID=$(xcrun simctl list devices available | grep "Apple Watch Series 10" | head -1 | grep -o -E "[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}" || true)
if [ -n "$WATCH_ID" ]; then
    echo "⌚ Booting Apple Watch Series 10: $WATCH_ID"
    xcrun simctl boot "$WATCH_ID" 2>/dev/null || true
fi

# List remaining test devices
echo ""
echo "📋 XCTest devices status:"
if [ -d ~/Library/Developer/XCTestDevices ]; then
    device_count=$(ls -1 ~/Library/Developer/XCTestDevices 2>/dev/null | wc -l | xargs)
    echo "Found $device_count test device(s)"
else
    echo "No XCTestDevices directory found (this is normal)"
fi

echo ""
echo "✅ Cleanup complete! Simulators are ready for testing."
echo ""
echo "💡 Next steps:"
echo "   - Run './Scripts/test.sh' to run all tests"
echo "   - Run './Scripts/run_ui_tests.sh' for UI tests only"
echo "   - If issues persist, restart Xcode and try again"