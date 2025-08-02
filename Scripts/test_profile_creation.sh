#!/bin/bash

echo "🧪 Testing Profile Creation Flow"
echo "================================"

# Run specific UI test for profile creation
xcodebuild test \
    -workspace FameFit.xcworkspace \
    -scheme FameFit \
    -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
    -only-testing:FameFitUITests/ProfileCreationUITests \
    2>&1 | xcbeautify

echo "✅ Profile creation test completed"