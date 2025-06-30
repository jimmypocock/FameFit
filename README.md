# FameFit - Your Personal Celebrity Fitness Influencer 💪🌟

**The fitness app where your coach thinks they're famous (and makes you famous too)**

A snarky Apple Watch workout app that combines real fitness tracking with an autonomous fitness influencer personality. Imagine having a stereotypical gym bro trapped in your watch, taking credit for your gains while somehow actually motivating you. It tracks your runs, bike rides, walks, HIIT, and weight lifting while delivering brutally honest (and hilarious) motivational messages.

## Current State

This is currently a fully functional Apple Watch workout app that tracks your runs, bike rides, walks, HIIT, and weight lifting while delivering brutally honest (and hilarious) motivational messages.

**🎯 Coming Soon**: iOS companion app for detailed progress tracking, widgets, and sharing your journey to fame!

### Key Features

- **Real Workout Tracking**: Full HealthKit integration for legitimate fitness tracking
- **Savage Motivational Messages**: Over 170+ snarky messages to keep you entertained and motivated
- **Achievement System**: Unlock roast-worthy achievements like "Speed Demon" (for going fast) or "Slow & Steady" (for... not)
- **Live Metrics**: Real-time heart rate, calories, distance, and elapsed time
- **Personality**: Messages appear during workouts, at milestones, and when you complete (or quit) your session

### Sample Messages You'll Get

- Starting a workout: _"Oh look who finally decided to move!"_
- During workout: _"Your effort level is giving participation trophy."_
- Slow pace: _"I've seen faster movement in a DMV line."_
- Finishing: _"You survived! Your couch missed you."_
- Achievement unlocked: _"100 calories burned! That's almost a cookie!"_

## Technical Details

### Built With

- **SwiftUI** - Modern declarative UI framework
- **HealthKit** - Apple's health data framework
- **WatchKit** - watchOS-specific APIs
- **TimelineView** - For Always On display support

### Based On

This app was built using Apple's WWDC workout app template as a foundation:
https://github.com/paigeshin/WWDC_Watch_WorkoutApp

### Architecture

```
FameFit/
├── Core Systems/
│   ├── WorkoutManager.swift        # Main workout logic + tough love integration
│   ├── ToughLoveMessages.swift     # Message system with 170+ roasts
│   └── AchievementManager.swift    # Tracks and unlocks achievements
├── Views/
│   ├── StartView.swift             # Workout selection
│   ├── MetricsView.swift           # Live metrics + messages display
│   ├── ControlsView.swift          # Pause/End controls
│   └── SummaryView.swift           # Post-workout summary + achievements
└── Supporting/
    ├── ElapsedTimeView.swift       # Custom timer display
    └── ActivityRingsView.swift     # Apple activity rings integration
```

## Development Setup

### Requirements

- Xcode 14.0+
- macOS 12.0+
- watchOS 8.0+ target
- Apple Developer account (for device testing)

### Getting Started

1. **Clone the repository**

   ```bash
   git clone [your-repo-url]
   cd FameFit
   ```

2. **Open in Xcode**

   ```bash
   open WWDC_WatchApp.xcodeproj
   ```

3. **Select the Watch App scheme**

   - In Xcode's toolbar, select "WWDC_WatchApp WatchKit App"
   - Choose your target device (simulator or physical Apple Watch)

4. **Run the app**
   - Press ⌘+R or click the Play button
   - The Watch simulator will launch automatically

### First-Time Setup

- The app will request HealthKit permissions on first launch
- Grant access to workout data, heart rate, calories, and distance

## How to Use

1. **Start a Workout**

   - Launch the app and select Run, Bike, or Walk
   - Get ready for your first roast message!

2. **During Your Workout**

   - Swipe between tabs: Controls, Metrics, Now Playing
   - Watch for motivational messages every 5 minutes
   - Messages also appear at milestones (5, 10, 20, 30 minutes)

3. **End Your Workout**
   - Tap "Quit" to end (and get roasted one more time)
   - View your summary with achievements
   - Your progress is saved to HealthKit

## Message System

The app includes different message categories:

- **Workout Start**: Wake-up call messages
- **Milestones**: Progress acknowledgments (backhanded compliments)
- **Encouragement**: "Motivational" support
- **Roasts**: Pure savage mode
- **Achievements**: Sarcastic congratulations
- **Workout End**: Final thoughts on your performance

## Achievements

Unlock achievements like:

- **First Timer**: Complete your first workout
- **5 Minute Hero**: Last 5 whole minutes
- **Speed Demon**: Actually go fast (under 6 min/km)
- **Slow & Steady**: Embrace the turtle life (over 12 min/km)
- **Early Bird**: Work out before 7 AM
- **Night Owl**: Work out after 9 PM
- **Calorie Crusher**: Burn 100+ calories
- **Inferno Mode**: Burn 500+ calories

## Customization

### Adding New Messages

Edit `FameFitMessages.swift` to add new roasts to any category:

```swift
.workoutStart: [
    "Your new motivational message here!",
    // ... more messages
]
```

### Adjusting Message Frequency

In `WorkoutManager.swift`, change the timer interval (currently 5 minutes):

```swift
Timer.scheduledTimer(withTimeInterval: 300, repeats: true) // 300 seconds = 5 minutes
```

## Future Enhancements

The app is MVP-ready but could be expanded with:

- User preferences for message intensity (Mild, Medium, Savage)
- Social sharing of achievements
- Custom workout types
- Message personalization based on performance
- Workout history with roast recaps
- Apple Watch complications

## Contributing

Feel free to contribute more savage messages, new achievements, or feature improvements. The only rule: keep it funny, keep it motivational (in a twisted way).

## License

[Add your license here]

## Acknowledgments

- Built on Apple's WWDC workout app template
- Inspired by apps like Carrot Fit and Zombies Run
- Special thanks to everyone who's ready to get famous while getting fit

---

_Remember: This app roasts because it cares. Now stop reading and go work out!_ 💪
