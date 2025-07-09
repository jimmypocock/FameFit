#!/bin/bash

# Launch both iOS and Watch simulators with FameFit apps

echo "🚀 Launching FameFit on both simulators..."

# Build and run iOS app
echo "📱 Launching iOS app..."
xcodebuild -workspace FameFit.xcworkspace \
    -scheme FameFit-iOS \
    -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest' \
    -configuration Debug \
    -derivedDataPath build \
    build &

# Build and run Watch app
echo "⌚ Launching Watch app..."
xcodebuild -workspace FameFit.xcworkspace \
    -scheme FameFit-Watch \
    -destination 'platform=watchOS Simulator,name=Apple Watch Series 10 (46mm),OS=latest' \
    -configuration Debug \
    -derivedDataPath build \
    build &

# Wait for builds to complete
wait

# Install and launch iOS app
echo "📲 Installing iOS app..."
xcrun simctl install booted build/Build/Products/Debug-iphonesimulator/FameFit.app
xcrun simctl launch booted com.jimmypocock.FameFit

# Install and launch Watch app
echo "⌚ Installing Watch app..."
xcrun simctl install booted build/Build/Products/Debug-watchsimulator/FameFit\ Watch\ App.app
xcrun simctl launch booted com.jimmypocock.FameFit.watchkitapp

echo "✅ Both apps launched!"