@testable import FameFit
import Foundation
import HealthKit

/// Builder for creating test workout data
enum TestWorkoutBuilder {
    // MARK: - Mock Workout Creation

    /// Creates a mock walking workout
    static func createWalkWorkout(
        duration: TimeInterval = 1_800, // 30 minutes default
        distance: Double? = nil,
        calories: Double? = nil,
        startDate: Date = Date().addingTimeInterval(-3_600)
    ) -> HKWorkout {
        let endDate = startDate.addingTimeInterval(duration)
        let distanceValue = distance ?? (duration * 1.2) // ~1.2 meters per second walking
        let caloriesValue = calories ?? (duration * 0.05) // ~0.05 calories per second

        return createWorkout(
            type: .walking,
            startDate: startDate,
            endDate: endDate,
            distance: distanceValue,
            calories: caloriesValue
        )
    }

    /// Creates a mock running workout
    static func createRunWorkout(
        duration: TimeInterval = 1_800, // 30 minutes default
        distance: Double? = nil,
        calories: Double? = nil,
        startDate: Date = Date().addingTimeInterval(-3_600)
    ) -> HKWorkout {
        let endDate = startDate.addingTimeInterval(duration)
        let distanceValue = distance ?? (duration * 2.5) // ~2.5 meters per second running
        let caloriesValue = calories ?? (duration * 0.15) // ~0.15 calories per second

        return createWorkout(
            type: .running,
            startDate: startDate,
            endDate: endDate,
            distance: distanceValue,
            calories: caloriesValue
        )
    }

    /// Creates a mock cycling workout
    static func createCycleWorkout(
        duration: TimeInterval = 2_700, // 45 minutes default
        distance: Double? = nil,
        calories: Double? = nil,
        startDate: Date = Date().addingTimeInterval(-3_600)
    ) -> HKWorkout {
        let endDate = startDate.addingTimeInterval(duration)
        let distanceValue = distance ?? (duration * 5.0) // ~5 meters per second cycling
        let caloriesValue = calories ?? (duration * 0.12) // ~0.12 calories per second

        return createWorkout(
            type: .cycling,
            startDate: startDate,
            endDate: endDate,
            distance: distanceValue,
            calories: caloriesValue
        )
    }

    /// Creates a custom workout with specified parameters
    static func createWorkout(
        type: HKWorkoutActivityType,
        startDate: Date,
        endDate: Date,
        distance: Double? = nil,
        calories: Double? = nil,
        metadata: [String: Any]? = nil
    ) -> HKWorkout {
        // Create energy and distance quantities
        var totalEnergyBurned: HKQuantity?
        var totalDistance: HKQuantity?

        if let calories {
            totalEnergyBurned = HKQuantity(
                unit: .kilocalorie(),
                doubleValue: calories
            )
        }

        if let distance {
            totalDistance = HKQuantity(
                unit: .meter(),
                doubleValue: distance
            )
        }

        // CRITICAL: Using deprecated HKWorkout initializer for unit testing
        //
        // This is currently the ONLY way to create HKWorkout objects in unit tests.
        // HKWorkoutBuilder (the recommended replacement) requires:
        // 1. A real HKHealthStore instance
        // 2. HealthKit authorization (impossible in unit tests)
        // 3. An active HealthKit session
        //
        // Apple has acknowledged this gap but hasn't provided a testing solution as of iOS 17+
        // See: https://developer.apple.com/forums/thread/721221
        //
        // We intentionally use the deprecated API here because:
        // - It's essential for testing our workout processing logic
        // - There is literally no alternative for unit testing
        // - Moving to integration tests would make our test suite slow and device-dependent
        //
        // When Apple provides a proper testing API, we'll migrate immediately.
        // Using deprecated API for testing - no viable alternative exists for unit testing
        
        // Intentionally using deprecated API - no alternative exists for unit testing
        #if compiler(>=5.9)
        @available(iOS, deprecated: 17.0)
        #endif
        let workout = HKWorkout(
            activityType: type,
            start: startDate,
            end: endDate,
            duration: endDate.timeIntervalSince(startDate),
            totalEnergyBurned: totalEnergyBurned,
            totalDistance: totalDistance,
            metadata: metadata
        )

        return workout
    }

    /// Convenience method for creating workouts with HKQuantity parameters
    static func createWorkout(
        type: HKWorkoutActivityType = .running,
        duration: TimeInterval = 3600,
        totalEnergyBurned: HKQuantity? = nil,
        totalDistance: HKQuantity? = nil,
        metadata: [String: Any]? = nil
    ) -> HKWorkout {
        let startDate = Date().addingTimeInterval(-duration - 60)
        let endDate = startDate.addingTimeInterval(duration)
        
        let calories = totalEnergyBurned?.doubleValue(for: .kilocalorie())
        let distance = totalDistance?.doubleValue(for: .meter())
        
        return createWorkout(
            type: type,
            startDate: startDate,
            endDate: endDate,
            distance: distance,
            calories: calories,
            metadata: metadata
        )
    }
    
    // MARK: - Test Scenarios

    /// Creates multiple workouts for testing
    static func createMultipleWorkouts(count: Int) -> [HKWorkout] {
        createWorkoutSeries(count: count)
    }

    /// Creates a series of workouts for testing multiple workout detection
    static func createWorkoutSeries(count: Int = 3) -> [HKWorkout] {
        var workouts: [HKWorkout] = []
        let now = Date()

        for index in 0 ..< count {
            let hoursAgo = TimeInterval((index + 1) * 2) * 3_600 // 2, 4, 6 hours ago
            let startDate = now.addingTimeInterval(-hoursAgo)

            // Alternate between workout types
            let workout: HKWorkout = switch index % 3 {
            case 0:
                createRunWorkout(startDate: startDate)
            case 1:
                createWalkWorkout(startDate: startDate)
            default:
                createCycleWorkout(startDate: startDate)
            }

            workouts.append(workout)
        }

        return workouts
    }

    /// Creates today's workouts for testing daily summary
    static func createTodaysWorkouts() -> [HKWorkout] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        return [
            createRunWorkout(
                duration: 1_800,
                startDate: today.addingTimeInterval(7 * 3_600) // 7 AM
            ),
            createWalkWorkout(
                duration: 1_200,
                startDate: today.addingTimeInterval(12 * 3_600) // Noon
            ),
            createCycleWorkout(
                duration: 2_400,
                startDate: today.addingTimeInterval(17 * 3_600) // 5 PM
            )
        ]
    }

    /// Creates a workout from the Apple Watch (FameFit source)
    static func createFameFitWorkout(
        type: HKWorkoutActivityType = .running,
        duration: TimeInterval = 1_800
    ) -> HKWorkout {
        // Simulate a workout from our Watch app
        createWorkout(
            type: type,
            startDate: Date().addingTimeInterval(-duration),
            endDate: Date(),
            distance: duration * 2.5,
            calories: duration * 0.15
        )
    }
}
