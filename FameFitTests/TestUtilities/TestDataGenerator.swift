//
//  TestDataGenerator.swift
//  FameFitTests
//
//  Generates test workout data for testing
//

@testable import FameFit
import Foundation
import HealthKit

enum TestDataGenerator {
    static func generateTestWorkouts(using cloudKitManager: CloudKitManager) async {
        let workoutTypes: [(type: HKWorkoutActivityType, name: String, duration: TimeInterval, calories: Double)] = [
            (.running, "Morning Run 🌅", 1_560, 320),
            (.cycling, "Evening Ride 🚴", 3_600, 580),
            (.swimming, "Pool Session 🏊", 1_800, 400),
            (.traditionalStrengthTraining, "Gym Time 💪", 2_700, 350),
            (.yoga, "Zen Flow 🧘", 2_400, 180),
            (.running, "5K Personal Record! 🏆", 1_380, 295),
            (.cycling, "Hill Climb Challenge 🏔️", 5_400, 820)
        ]

        for (index, workout) in workoutTypes.enumerated() {
            let workoutId = UUID()
            let xpEarned = Int.random(in: 50 ... 150)
            let followersEarned = Int.random(in: 5 ... 25)

            let workoutHistory = WorkoutHistoryItem(
                id: workoutId,
                workoutType: workout.name,
                startDate: Date().addingTimeInterval(TimeInterval(-index * 3_600)),
                endDate: Date().addingTimeInterval(TimeInterval(-index * 3_600) + workout.duration),
                duration: workout.duration,
                totalEnergyBurned: workout.calories,
                totalDistance: workout.type == .running || workout.type == .cycling ? Double.random(in: 3 ... 10) : 0,
                averageHeartRate: Double.random(in: 120 ... 160),
                followersEarned: followersEarned,
                xpEarned: xpEarned,
                source: "com.apple.watch"
            )

            cloudKitManager.saveWorkoutHistory(workoutHistory)
            print("✅ Generated test workout: \(workout.name)")
        }
    }
}
