#!/bin/bash

echo "🧪 Testing USE_MOCK_SOCIAL environment variable..."

# Export the environment variable
export USE_MOCK_SOCIAL=1

# Run a simple test that should show mock data
xcodebuild test \
    -workspace FameFit.xcworkspace \
    -scheme FameFit \
    -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
    -skipPackagePluginValidation \
    -only-testing:FameFitTests/Unit/ViewModels/LeaderboardViewModelTests \
    USE_MOCK_SOCIAL=1 \
    2>&1 | grep -E "(🧪|Mock|test-user|mockProfiles|TEST PASSED|TEST FAILED)"

echo "✅ Test complete"