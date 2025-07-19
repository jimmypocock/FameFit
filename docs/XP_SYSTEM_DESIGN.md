# FameFit XP System Design

## Overview

The FameFit XP (Influencer Experience Points) system rewards users for workout consistency, intensity, and variety. XP is a permanent achievement metric that unlocks rewards and showcases fitness dedication.

## Core Principles

1. **XP is Permanent**: Once earned, XP is never lost or spent
2. **Clear Progression**: Users always know how to earn more XP
3. **Reward Variety**: Different workout types and behaviors earn different XP
4. **Surprise & Delight**: Occasional bonuses keep things exciting
5. **Fair & Transparent**: No pay-to-win, only earn through fitness

## XP Calculation Formula

```
Total XP = Base XP × Workout Multiplier × Intensity Multiplier × Streak Multiplier × Time Bonus
```

### 1. Base XP Calculation

**Base Rate**: 1 XP per minute of workout

```swift
let baseXP = workoutDuration(inMinutes) * 1.0
```

### 2. Workout Type Multipliers

Different workout types have different difficulty levels:

| Workout Type | Multiplier | Reasoning |
|-------------|------------|-----------|
| HIIT | 1.5x | High intensity, maximum effort |
| Swimming | 1.4x | Full body, technical skill |
| Strength Training | 1.3x | Muscle building, progressive overload |
| Running | 1.2x | Cardiovascular endurance |
| Cycling | 1.0x | Standard baseline |
| Yoga | 0.8x | Recovery focused, lower intensity |
| Walking | 0.7x | Entry-level activity |

### 3. Intensity Multipliers (Heart Rate Based)

Based on percentage of maximum heart rate:

| Zone | HR Range | Multiplier | Description |
|------|----------|------------|-------------|
| Rest | < 50% | 0.5x | Recovery zone |
| Easy | 50-60% | 0.8x | Light activity |
| Moderate | 60-70% | 1.0x | Standard effort |
| Hard | 70-85% | 1.3x | High effort |
| Maximum | 85%+ | 1.5x | Peak performance |

### 4. Streak Multipliers

Reward consistency with increasing multipliers:

```swift
// 5% bonus per day, capped at 100% (20 days)
let streakMultiplier = min(1.0 + (currentStreak * 0.05), 2.0)
```

| Streak Days | Multiplier |
|------------|------------|
| 1 | 1.05x |
| 5 | 1.25x |
| 10 | 1.50x |
| 15 | 1.75x |
| 20+ | 2.00x |

### 5. Time-of-Day Bonuses

Encourage healthy workout habits:

| Time | Bonus | Reasoning |
|------|-------|-----------|
| 5am-9am | 1.2x | Early bird bonus |
| 9am-10pm | 1.0x | Standard hours |
| 10pm-12am | 1.1x | Night owl bonus |
| 12am-5am | 0.8x | Discourage unhealthy hours |

### 6. Special Bonuses

One-time or special event bonuses:

| Event | XP Bonus | Frequency |
|-------|----------|-----------|
| First Workout | +50 | Once |
| Personal Record | +25 | Per record |
| Weekly Goal Met | +100 | Weekly |
| 10th Workout | +100 | Once |
| 50th Workout | +250 | Once |
| 100th Workout | +500 | Once |
| 365 Day Streak | +1000 | Once |
| Weekend Workout | 1.1x | Sat/Sun |
| Holiday Workout | 1.5x | Special days |

## XP Levels & Titles

Users progress through titles as they earn XP:

| XP Range | Title | Unlocks |
|----------|-------|---------|
| 0-99 | Couch Potato | Basic features |
| 100-499 | Fitness Newbie | Custom message |
| 500-999 | Gym Regular | Bronze badge |
| 1,000-2,499 | Fitness Enthusiast | Workout stats |
| 2,500-4,999 | Workout Warrior | Silver badge |
| 5,000-9,999 | Micro-Influencer | New character personality |
| 10,000-24,999 | Rising Star | Gold badge |
| 25,000-49,999 | Fitness Influencer | Custom app icon |
| 50,000-99,999 | Verified Athlete | Platinum badge |
| 100,000-249,999 | FameFit Elite | Exclusive workouts |
| 250,000-499,999 | Legendary | Diamond badge |
| 500,000-999,999 | Mythical | Special effects |
| 1,000,000+ | FameFit God | Ultimate prestige |

## FameCoin Currency (Future Addition)

Separate from XP, FameCoins will be a spendable currency:

### Earning FameCoins
- 1 coin per 10 XP earned
- Daily login bonus: 5 coins
- Weekly streak bonus: 50 coins
- Challenge completion: Variable

### Spending FameCoins
- Temporary XP boosters
- Character customization
- Challenge entries
- Profile themes
- Workout music packs

## Implementation Example

```swift
struct XPCalculator {
    static func calculateXP(for workout: WorkoutHistoryItem) -> Int {
        // Base XP
        let minutes = workout.duration / 60.0
        var xp = minutes * 1.0
        
        // Workout type multiplier
        let workoutMultiplier = getWorkoutMultiplier(workout.workoutType)
        xp *= workoutMultiplier
        
        // Intensity multiplier (if heart rate data available)
        if let avgHR = workout.averageHeartRate {
            let intensityMultiplier = getIntensityMultiplier(avgHR)
            xp *= intensityMultiplier
        }
        
        // Streak multiplier
        let streakMultiplier = getStreakMultiplier()
        xp *= streakMultiplier
        
        // Time of day bonus
        let timeBonus = getTimeOfDayBonus(workout.startDate)
        xp *= timeBonus
        
        // Round to nearest integer
        return Int(round(xp))
    }
}
```

## Security Considerations

1. **Server Validation**: All XP calculations must be verified server-side
2. **Rate Limiting**: Maximum XP per day to prevent abuse
3. **Audit Trail**: Log all XP transactions for review
4. **Anomaly Detection**: Flag unusual XP gains for review

## Future Enhancements

1. **Team Challenges**: Bonus XP for group workouts
2. **Seasonal Events**: Special multipliers during events
3. **Location Bonuses**: Extra XP for outdoor workouts
4. **Social Bonuses**: XP for helping others reach goals
5. **Milestone Challenges**: Special XP quests

## Testing Strategy

1. **Unit Tests**: All calculation functions
2. **Integration Tests**: CloudKit XP storage
3. **Edge Cases**: Timezone changes, DST, leap years
4. **Performance**: Large workout history calculations
5. **Security**: Attempt to manipulate XP values

## Success Metrics

- User engagement: Daily active users
- Workout frequency: Sessions per week
- Streak length: Average consecutive days
- Feature adoption: Unlock redemption rate
- User satisfaction: XP system feedback