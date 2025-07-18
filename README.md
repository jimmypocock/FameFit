# FameFit - Your Personal Fitness Influencer Squad 💪🌟

**The fitness app where three wannabe influencers turn your workouts into social media fame**

FameFit is a gamified fitness ecosystem combining an Apple Watch workout tracker with an iOS companion app. Three overly-confident fitness influencers - Chad, Sierra, and Zen - coach you through workouts while helping you gain "followers" for every exercise you complete. It's like having a reality TV fitness show in your pocket, where you're both the star and the audience.

## 🎯 Current Features

### iOS Companion App
- **Sign in with Apple** authentication
- **Real-time follower count** that increases with each workout
- **CloudKit sync** to track progress across devices
- **Influencer onboarding** with character introductions
- **HealthKit integration** for automatic workout detection

### Apple Watch App
- **Full workout tracking** for running, cycling, walking, and more
- **Live metrics** including heart rate, calories, distance, and time
- **Character-based coaching** with 250+ motivational messages
- **Achievement system** with sarcastic rewards
- **Always On Display** support with efficient updates

### The Influencer Squad

**Chad Maximus** 💪
- The stereotypical gym bro who takes selfies between sets
- Specializes in strength and HIIT workouts
- Sample quote: "Yo! Let's get SWOLE and VIRAL at the same time!"

**Sierra Pace** 🏃‍♀️
- The cardio queen who documents every mile
- Running and cycling specialist
- Sample quote: "Every step is content, bestie!"

**Zen Flexington** 🧘‍♂️
- The spiritual fitness guru who monetizes mindfulness
- Yoga and walking specialist
- Sample quote: "Manifest those gains through cosmic alignment!"

## 📱 How It Works

1. **Sign up** on the iOS app and meet your coaches
2. **Complete workouts** on Apple Watch (or any app that saves to Apple Fitness)
3. **Gain 5 followers** for every workout completed
4. **Unlock titles** as you grow your following:
   - 0-99: Fitness Newbie
   - 100-999: Micro-Influencer
   - 1,000-9,999: Rising Star
   - 10,000-99,999: Verified Influencer
   - 100,000+: FameFit Elite

## 🛠 Technical Stack

### Architecture

The project uses a companion app architecture where the iOS and Watch apps work together:

- **iOS App**: Handles authentication, displays progress, manages CloudKit sync
- **Watch App**: Provides real-time workout tracking with character coaching
- **Shared Code**: Common managers and models used by both apps

### Technologies
- **SwiftUI** for all UI (iOS 17+ and watchOS 10+)
- **CloudKit** for data persistence and sync
- **HealthKit** for workout tracking and detection
- **Sign in with Apple** for authentication
- **Background processing** for workout notifications
- **Test-Driven Development** with XCTest and mocks
- **Dependency Injection** for testability
- **Protocol-Oriented Programming** for flexibility

## 🚀 Getting Started

### Requirements
- Xcode 16.0+ (16.4 recommended)
- macOS 14.0+ (Sonoma or later)
- iOS 17.0+ device/simulator
- watchOS 10.0+ device/simulator
- Apple Developer account (for device testing)

### Setup

1. **Clone the repository**
   ```bash
   git clone https://github.com/yourusername/FameFit.git
   cd FameFit
   ```

2. **Install dependencies (optional)**
   ```bash
   # Install SwiftLint for code quality
   brew install swiftlint
   ```

3. **Open the workspace**
   ```bash
   open FameFit.xcworkspace
   ```
   **Important**: Always use the `.xcworkspace` file, not `.xcodeproj`

4. **Configure signing**
   - Select the project in Xcode
   - Update Team and Bundle Identifier for both targets:
     - iOS App: `com.yourdomain.FameFit`
     - Watch App: `com.yourdomain.FameFit.watchkitapp`
   - Ensure these capabilities are enabled:
     - HealthKit (both targets)
     - CloudKit (iOS target)
     - Sign in with Apple (iOS target)
     - Background Modes > Remote notifications (iOS target)

5. **Run the apps**
   - For iOS: Select "FameFit" scheme → iPhone simulator → ⌘+R
   - For Watch: Select "FameFit Watch App" scheme → Watch simulator → ⌘+R
   - For both: Use the launch script:
     ```bash
     ./Scripts/launch-both-simulators.sh
     ```

### First Launch
1. iOS app will show onboarding with character introductions
2. Sign in with Apple ID
3. Grant HealthKit permissions
4. Watch app will request workout permissions
5. Start earning followers!

## 🏃‍♂️ Usage Guide

### Starting a Workout (Watch)
1. Open FameFit on Apple Watch
2. Select workout type (Run, Bike, Walk, etc.)
3. Watch for coaching messages during workout
4. End workout to see summary and achievements

### Tracking Progress (iOS)
1. Open FameFit on iPhone
2. View current follower count and title
3. Check workout stats and streaks
4. Watch follower count update after workouts

### Background Sync
- Complete workouts in ANY app (Apple Fitness, Strava, Nike Run Club)
- FameFit detects new workouts automatically
- Receive notifications with character messages
- Followers added without opening the app

## 🎮 Game Mechanics

### Follower System
- **+5 followers** per workout completed
- **Streak bonuses** for consecutive days
- **Achievement multipliers** for special accomplishments
- **Milestone rewards** at follower thresholds

### Achievements
- **First Timer**: Complete your first workout
- **Early Bird**: Workout before 7 AM  
- **Night Owl**: Workout after 9 PM
- **Speed Demon**: Run under 6 min/km pace
- **Calorie Crusher**: Burn 100+ calories
- **Marathon Mindset**: Workout for 60+ minutes

## 🔧 Configuration

### Message Customization
Edit character messages in `FameFitMessages.swift`:
```swift
static let messages: [MessageCategory: [String]] = [
    .workoutStart: [
        "Your motivational message here!",
        // Add more...
    ]
]
```

### CloudKit Setup
1. Enable CloudKit capability in Xcode
2. Use container: `iCloud.com.yourteam.FameFit`
3. Create "User" record type with fields:
   - displayName (String)
   - followerCount (Int64)
   - totalWorkouts (Int64)
   - currentStreak (Int64)

### HealthKit Permissions
Required permissions in Info.plist:
```xml
<key>NSHealthShareUsageDescription</key>
<string>FameFit needs access to read your workout data to track your fitness journey and award followers.</string>
<key>NSHealthUpdateUsageDescription</key>
<string>FameFit saves workout data to Apple Health to track your progress.</string>
```

## 📊 Development

### Project Structure
```
FameFit/
├── FameFit/                        # iOS companion app
│   ├── FameFitApp.swift           # App entry point
│   ├── MainView.swift             # Main dashboard
│   ├── OnboardingView.swift       # Character introductions
│   └── Info.plist                 # iOS app configuration
├── FameFit Watch App/              # Apple Watch workout app
│   ├── FameFitApp.swift           # Watch app entry
│   ├── Models/                    # Watch-specific models
│   │   ├── WorkoutManager.swift   # Core workout logic
│   │   ├── AchievementManager.swift # Achievement tracking
│   │   └── FameFitMessages.swift  # Character messages
│   ├── Views/                     # Watch UI components
│   │   ├── Start/                 # Workout selection
│   │   ├── Session/               # Active workout views
│   │   ├── Controls/              # Workout controls
│   │   ├── Metrics/               # Live metrics display
│   │   └── Summary/               # Post-workout summary
│   └── ComplicationController.swift # Watch complications
├── Shared/                         # Code shared between apps
│   ├── CloudKitManager.swift      # iCloud sync
│   ├── AuthenticationManager.swift # Sign in with Apple
│   ├── WorkoutObserver.swift      # Background workout detection
│   ├── FameFitCharacters.swift    # Character definitions
│   ├── FameFitError.swift         # Error types
│   ├── DependencyContainer.swift  # Dependency injection
│   └── ManagerProtocols.swift     # Protocol definitions
├── FameFitTests/                   # iOS app unit tests
├── FameFit Watch AppTests/         # Watch app unit tests
├── FameFit Watch AppUITests/       # Watch app UI tests
├── Scripts/                        # Build and test scripts
└── docs/                          # Additional documentation
```

### Testing

#### Using Test Script (Recommended)
```bash
# Run comprehensive test suite (SwiftLint + Unit Tests + Build verification)
./Scripts/test.sh

# Build both iOS and Watch apps
./Scripts/build.sh         # Build both
./Scripts/build.sh ios     # iOS only
./Scripts/build.sh watch   # Watch only

# Run UI tests separately (avoids simulator conflicts)
./Scripts/run_ui_tests.sh

# Reset testing environment if tests fail
./Scripts/reset_testing_env.sh

# Reset app data (useful for testing onboarding)
./Scripts/reset_app_data.swift
```

#### Using Xcode directly
```bash
# Run all tests
xcodebuild test -workspace FameFit.xcworkspace -scheme FameFit -destination 'platform=iOS Simulator,name=iPhone 16 Pro'

# Run specific test class
xcodebuild test -workspace FameFit.xcworkspace -scheme FameFit -only-testing:FameFitTests/WorkoutManagerTests
```

### Code Quality
- **SwiftLint**: Enforces Swift style and conventions
  - Configuration in `.swiftlint.yml`
  - Run with `swiftlint` or automatically via `./Scripts/test.sh`
- **Test Coverage**: Comprehensive test suite with mocks
  - `FameFitTests/` - iOS app unit tests with mocked services
  - `FameFitUITests/` - iOS app UI tests with launch arguments
  - `FameFit Watch AppTests/` - Watch app unit tests
  - `FameFit Watch AppUITests/` - Watch app UI tests
- **Test-Driven Development**: Write tests first, then implementation
- **Testing Best Practices**:
  - Synchronous tests where possible (avoid complex async)
  - Each test tests ONE specific behavior
  - UI tests focus on user flows, not exact text matching
  - Mocks are simple and focused
- **Dependency Injection**: Managers use protocols for easy mocking
- **Error Handling**: Comprehensive `FameFitError` types
- **Memory Management**: Weak references prevent retain cycles

### Security & Privacy
- **Sign in with Apple**: No passwords stored
- **Minimal Data Collection**: Only user ID and display name
- **HealthKit**: Read-only access, no health data transmitted
- **CloudKit**: Private database with encrypted transport
- **No Third-Party Dependencies**: Reduces attack surface

## 🚀 Deployment

### Pre-Flight Checklist
- ✅ All tests passing
- ✅ Zero SwiftLint violations
- ✅ No hardcoded values or secrets
- ✅ Error handling implemented
- ✅ Memory leaks checked
- ✅ Background modes configured
- ✅ Entitlements verified

### App Store Requirements
- **Bundle IDs**: 
  - iOS: `com.yourteam.FameFit`
  - Watch: `com.yourteam.FameFit.watchkitapp`
- **Capabilities**: 
  - HealthKit (read/write workouts)
  - CloudKit (private database)
  - Sign in with Apple
  - Background Modes (remote notifications, workout processing)
- **Minimum OS Versions**:
  - iOS 17.0
  - watchOS 10.0
- **Age Rating**: 12+ (Mild suggestive humor)
- **Category**: Health & Fitness

## 🤝 Contributing

We welcome contributions!

### Areas for Contribution
- New character messages and personalities
- Additional workout types
- Social sharing features
- Leaderboards and challenges
- Widget support
- Apple Watch complications
- Localization support
- Advanced analytics

### Code Style Guidelines
- Follow SwiftLint rules (automatically checked)
- Use dependency injection, not singletons
- Write tests for all new features
- Keep views lightweight - logic in managers
- Use `@MainActor` for UI updates
- Handle all error cases explicitly

### Development Process
1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. **Write tests first** (TDD approach):
   - Add failing test in appropriate test file
   - Run tests to confirm they fail
   - Implement minimum code to pass
   - Refactor while keeping tests green
4. Implement your feature
5. Run the test suite:
   ```bash
   ./Scripts/test.sh  # Runs SwiftLint + Tests + Build verification
   ```
6. Commit your changes:
   ```bash
   git add .
   git commit -m "Add amazing feature"
   ```
7. Push to your fork and submit a pull request

## 📄 License

This project is licensed under the MIT License - see [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Inspired by fitness apps like Zombies Run and Carrot Fit
- Built with Apple's HealthKit and CloudKit frameworks
- Character personalities inspired by fitness influencer culture

---

**Remember**: Every workout makes you more famous! Now stop reading and start sweating! 💦

*"Success isn't just measured in gains, it's measured in followers!" - Chad Maximus*