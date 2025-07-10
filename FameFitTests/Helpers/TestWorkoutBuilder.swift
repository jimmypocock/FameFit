import Foundation
import HealthKit
@testable import FameFit

/// Builder for creating test workout data
struct TestWorkoutBuilder {
    
    // MARK: - Mock Workout Creation
    
    /// Creates a mock walking workout
    static func createWalkWorkout(
        duration: TimeInterval = 1800, // 30 minutes default
        distance: Double? = nil,
        calories: Double? = nil,
        startDate: Date = Date().addingTimeInterval(-3600)
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
        duration: TimeInterval = 1800, // 30 minutes default
        distance: Double? = nil,
        calories: Double? = nil,
        startDate: Date = Date().addingTimeInterval(-3600)
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
        duration: TimeInterval = 2700, // 45 minutes default
        distance: Double? = nil,
        calories: Double? = nil,
        startDate: Date = Date().addingTimeInterval(-3600)
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
        calories: Double? = nil
    ) -> HKWorkout {
        // Create energy and distance quantities
        var totalEnergyBurned: HKQuantity?
        var totalDistance: HKQuantity?
        
        if let calories = calories {
            totalEnergyBurned = HKQuantity(
                unit: .kilocalorie(),
                doubleValue: calories
            )
        }
        
        if let distance = distance {
            totalDistance = HKQuantity(
                unit: .meter(),
                doubleValue: distance
            )
        }
        
        // Note: In real tests, we might need to use HKWorkoutBuilder
        // For now, this creates a basic workout for testing logic
        let workout = HKWorkout(
            activityType: type,
            start: startDate,
            end: endDate,
            duration: endDate.timeIntervalSince(startDate),
            totalEnergyBurned: totalEnergyBurned,
            totalDistance: totalDistance,
            metadata: nil
        )
        
        return workout
    }
    
    // MARK: - Test Scenarios
    
    /// Creates a series of workouts for testing multiple workout detection
    static func createWorkoutSeries(count: Int = 3) -> [HKWorkout] {
        var workouts: [HKWorkout] = []
        let now = Date()
        
        for i in 0..<count {
            let hoursAgo = TimeInterval((i + 1) * 2) * 3600 // 2, 4, 6 hours ago
            let startDate = now.addingTimeInterval(-hoursAgo)
            
            // Alternate between workout types
            let workout: HKWorkout
            switch i % 3 {
            case 0:
                workout = createRunWorkout(startDate: startDate)
            case 1:
                workout = createWalkWorkout(startDate: startDate)
            default:
                workout = createCycleWorkout(startDate: startDate)
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
                duration: 1800,
                startDate: today.addingTimeInterval(7 * 3600) // 7 AM
            ),
            createWalkWorkout(
                duration: 1200,
                startDate: today.addingTimeInterval(12 * 3600) // Noon
            ),
            createCycleWorkout(
                duration: 2400,
                startDate: today.addingTimeInterval(17 * 3600) // 5 PM
            )
        ]
    }
    
    /// Creates a workout from the Apple Watch (FameFit source)
    static func createFameFitWorkout(
        type: HKWorkoutActivityType = .running,
        duration: TimeInterval = 1800
    ) -> HKWorkout {
        // Simulate a workout from our Watch app
        return createWorkout(
            type: type,
            startDate: Date().addingTimeInterval(-duration),
            endDate: Date(),
            distance: duration * 2.5,
            calories: duration * 0.15
        )
    }
}