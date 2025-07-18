# FameFit Build & Test Scripts

This directory contains automation scripts for building, testing, and maintaining the FameFit project.

## 🚀 Quick Start

```bash
# Run all tests (recommended)
./Scripts/test.sh

# Reset simulators before testing
./reset_sim.sh

# Run UI tests separately
./Scripts/run_ui_tests.sh
```

## 📋 Available Scripts

### Testing Scripts

#### `test.sh`
Comprehensive test runner that executes:
- SwiftLint validation
- iOS app unit tests
- Watch app unit tests
- Code coverage reporting

**Usage:** `./Scripts/test.sh`

#### `run_ui_tests.sh`
Runs UI tests in isolation to avoid simulator conflicts.
- Executes all UI test suites
- Better reliability than running with unit tests

**Usage:** `./Scripts/run_ui_tests.sh`

### Maintenance Scripts

#### `reset_sim.sh` 🆕
**Location:** Project root (not in Scripts/)
Lightweight simulator reset for fixing "device failed to launch" errors.
- Gracefully shuts down simulators
- Resets only test simulators (iPhone 16 Pro, Apple Watch Series 10)
- Cleans simulator caches
- Restarts simulator services

**Usage:** `./reset_sim.sh`
**When to use:** Before running tests in Xcode if you encounter simulator issues

#### `reset_testing_env.sh`
Full environment reset (more aggressive).
- Kills all Xcode/simulator processes
- Cleans derived data
- Resets ALL simulators
- Cleans build folders

**Usage:** `./Scripts/reset_testing_env.sh`
**When to use:** When you have persistent build/test issues

### Build Scripts

#### `build.sh`
Builds the project for different targets.
- `./Scripts/build.sh` - Build both iOS and Watch apps
- `./Scripts/build.sh ios` - Build iOS app only
- `./Scripts/build.sh watch` - Build Watch app only

## 🔧 Troubleshooting

### UI Test Failures
If you see "Simulator device failed to launch":
1. Run `./reset_sim.sh`
2. Try tests again in Xcode

### Persistent Test Issues
For stubborn problems:
1. Run `./Scripts/reset_testing_env.sh`
2. In Xcode: Product → Clean Build Folder (⇧⌘K)
3. Restart Xcode
4. Run tests again

### Test Timeouts
- UI tests may take longer on first run
- Simulator needs time to boot and install app
- Be patient with OnboardingUITests

## 📝 Best Practices

1. **Before Running Tests in Xcode**
   ```bash
   ./reset_sim.sh
   ```

2. **For CI/CD Pipeline**
   ```bash
   ./Scripts/reset_testing_env.sh
   ./Scripts/test.sh
   ./Scripts/run_ui_tests.sh
   ```

3. **Quick Test Run**
   ```bash
   ./Scripts/test.sh  # Unit tests only
   ```

4. **Full Test Suite**
   ```bash
   ./reset_sim.sh
   ./Scripts/test.sh
   ./Scripts/run_ui_tests.sh
   ```

## 🛠 Script Maintenance

All scripts include:
- Error handling with `set -euo pipefail`
- Clear status messages
- Non-destructive defaults
- Help documentation

To add a new script:
1. Create in `Scripts/` directory
2. Add shebang: `#!/bin/bash`
3. Make executable: `chmod +x Scripts/your_script.sh`
4. Document in this README