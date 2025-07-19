#!/bin/bash

# =============================================================================
# reset_sim.sh
# 
# Resets iOS/watchOS simulators to fix launch issues without affecting Xcode
# Run this before running UI tests to ensure clean simulator state
# =============================================================================

set -euo pipefail

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${YELLOW}🔧 FameFit Simulator Reset Tool${NC}"
echo "================================"
echo ""

# Function to print status
print_status() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

# 1. Check if simulators are running
echo "Checking simulator status..."
if pgrep -x "Simulator" > /dev/null; then
    echo "Simulator app is running. Shutting down gracefully..."
    osascript -e 'quit app "Simulator"' 2>/dev/null || true
    sleep 2
fi

# 2. Shutdown all simulator devices
echo "Shutting down all simulator devices..."
xcrun simctl shutdown all 2>/dev/null || true
print_status "All simulators shut down"

# 3. Find and reset only our test simulators
echo ""
echo "Finding test simulators..."

# Get iPhone simulator for UI tests
IPHONE_SIM=$(xcrun simctl list devices -j | jq -r '.devices | to_entries | .[] | select(.key | contains("iOS")) | .value[] | select(.name == "iPhone 16 Pro") | .udid' | head -1)

# Get Watch simulator for Watch tests  
WATCH_SIM=$(xcrun simctl list devices -j | jq -r '.devices | to_entries | .[] | select(.key | contains("watchOS")) | .value[] | select(.name | contains("Series 10 (46mm)")) | .udid' | head -1)

# 4. Reset specific simulators
if [ -n "$IPHONE_SIM" ]; then
    echo "Resetting iPhone 16 Pro simulator..."
    xcrun simctl erase "$IPHONE_SIM"
    print_status "iPhone simulator reset"
else
    print_error "iPhone 16 Pro simulator not found"
fi

if [ -n "$WATCH_SIM" ]; then
    echo "Resetting Apple Watch simulator..."
    xcrun simctl erase "$WATCH_SIM"
    print_status "Watch simulator reset"
else
    print_error "Apple Watch Series 10 simulator not found"
fi

# 5. Clean simulator caches
echo ""
echo "Cleaning simulator caches..."
rm -rf ~/Library/Developer/CoreSimulator/Caches/dyld/ 2>/dev/null || true
print_status "Simulator caches cleaned"

# 6. Optional: Reset all simulators (commented out by default)
# echo ""
# echo "Reset ALL simulators? (y/N)"
# read -r response
# if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
#     xcrun simctl erase all
#     print_status "All simulators reset"
# fi

# 7. Restart CoreSimulatorService (without sudo)
echo ""
echo "Restarting simulator services..."
killall -9 com.apple.CoreSimulator.CoreSimulatorService 2>/dev/null || true
print_status "Simulator services restarted"

# Done!
echo ""
echo -e "${GREEN}✅ Simulator reset complete!${NC}"
echo ""
echo "Next steps:"
echo "1. Open Xcode"
echo "2. Run your tests (⌘U)"
echo ""
echo "Tips:"
echo "- Run this script if you see 'Simulator device failed to launch' errors"
echo "- For full reset, use: ./Scripts/reset_testing_env.sh"
echo "- To reset all simulators, uncomment section 6 in this script"