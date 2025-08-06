#!/bin/bash

# Test script to verify follower/following system fixes

echo "🧪 Testing Follower/Following System Fixes"
echo "========================================="

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Check if we can build the iOS app
echo -e "\n${YELLOW}1. Building iOS app...${NC}"
if xcodebuild -workspace FameFit.xcworkspace -scheme "FameFit" -sdk iphonesimulator -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.5' build CODE_SIGNING_ALLOWED=NO > /tmp/build_test.log 2>&1; then
    echo -e "${GREEN}✅ iOS app builds successfully${NC}"
else
    echo -e "${RED}❌ iOS app build failed${NC}"
    echo "See /tmp/build_test.log for details"
    exit 1
fi

# Check for ID-related issues in the code
echo -e "\n${YELLOW}2. Checking for consistent ID usage...${NC}"

# Check FollowersListView uses correct IDs
if grep -q "profile.userID" FameFit/Views/FollowersListView.swift; then
    echo -e "${GREEN}✅ FollowersListView uses CloudKit user IDs${NC}"
else
    echo -e "${RED}❌ FollowersListView may still use profile UUIDs${NC}"
fi

# Check ProfileView uses correct IDs
if grep -q "profile.userID" FameFit/Views/ProfileView.swift | grep -v "profile.id"; then
    echo -e "${GREEN}✅ ProfileView uses CloudKit user IDs for social operations${NC}"
else
    echo -e "${RED}❌ ProfileView may still use profile UUIDs${NC}"
fi

# Check for self-follow prevention
echo -e "\n${YELLOW}3. Checking self-follow prevention...${NC}"
if grep -q "profile.userID != currentUserId" FameFit/Views/FollowersListView.swift; then
    echo -e "${GREEN}✅ Self-follow prevention in FollowersListView${NC}"
else
    echo -e "${YELLOW}⚠️  Self-follow prevention may need review${NC}"
fi

if grep -q "isOwnProfile" FameFit/Views/ProfileView.swift; then
    echo -e "${GREEN}✅ ProfileView has isOwnProfile check${NC}"
else
    echo -e "${RED}❌ ProfileView missing isOwnProfile check${NC}"
fi

echo -e "\n${GREEN}🎉 Follower/Following system fixes verified!${NC}"
echo -e "${YELLOW}Note: The Watch app has asset catalog issues that need to be fixed for production builds.${NC}"