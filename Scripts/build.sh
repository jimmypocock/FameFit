#!/bin/bash

# FameFit Build Script
# This script properly builds the companion iOS and Watch apps

set -e  # Exit on error

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORKSPACE="$PROJECT_DIR/FameFit.xcworkspace"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "🏗️  FameFit Build Script"
echo "======================="

# Function to build iOS app
build_ios() {
    echo -e "\n${YELLOW}Building iOS app...${NC}"
    
    xcodebuild \
        -workspace "$WORKSPACE" \
        -scheme "FameFit-iOS" \
        -sdk iphonesimulator \
        -configuration Debug \
        -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest' \
        clean build \
        ONLY_ACTIVE_ARCH=NO \
        -skipPackagePluginValidation \
        -skipMacroValidation \
        2>&1 | tee /tmp/famefit_ios_build.log | grep -E "(error:|warning:|SUCCEEDED|FAILED|Building)" || true
    
    if grep -q "BUILD SUCCEEDED" /tmp/famefit_ios_build.log; then
        echo -e "${GREEN}✅ iOS app built successfully${NC}"
    else
        echo -e "${RED}❌ iOS app build failed${NC}"
        exit 1
    fi
}

# Function to build Watch app
build_watch() {
    echo -e "\n${YELLOW}Building Watch app...${NC}"
    
    xcodebuild \
        -workspace "$WORKSPACE" \
        -scheme "FameFit-Watch" \
        -sdk watchsimulator \
        -configuration Debug \
        -destination 'platform=watchOS Simulator,name=Apple Watch Series 10 (46mm),OS=latest' \
        clean build \
        ONLY_ACTIVE_ARCH=NO \
        -skipPackagePluginValidation \
        -skipMacroValidation \
        2>&1 | tee /tmp/famefit_watch_build.log | grep -E "(error:|warning:|SUCCEEDED|FAILED|Building)" || true
    
    if grep -q "BUILD SUCCEEDED" /tmp/famefit_watch_build.log; then
        echo -e "${GREEN}✅ Watch app built successfully${NC}"
    else
        echo -e "${RED}❌ Watch app build failed${NC}"
        exit 1
    fi
}

# Function to build both apps
build_all() {
    build_ios
    build_watch
}

# Parse command line arguments
case "${1:-all}" in
    ios)
        build_ios
        ;;
    watch)
        build_watch
        ;;
    all)
        build_all
        ;;
    *)
        echo "Usage: $0 [ios|watch|all]"
        echo "  ios   - Build only the iOS app"
        echo "  watch - Build only the Watch app"
        echo "  all   - Build both apps (default)"
        exit 1
        ;;
esac

echo -e "\n${GREEN}🎉 Build complete!${NC}"