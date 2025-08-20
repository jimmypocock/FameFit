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
    struct WorkoutTemplate {
        let type: HKWorkoutActivityType
        let name: String
        let duration: TimeInterval
        let calories: Double
    }
    
    static func generateTestWorkouts(using cloudKitManager: CloudKitService) async {
        let workoutTypes: [WorkoutTemplate] = [
            WorkoutTemplate(type: .running, name: "Morning Run 🌅", duration: 1_560, calories: 320),
            WorkoutTemplate(type: .cycling, name: "Evening Ride 🚴", duration: 3_600, calories: 580),
            WorkoutTemplate(type: .swimming, name: "Pool Session 🏊", duration: 1_800, calories: 400),
            WorkoutTemplate(type: .traditionalStrengthTraining, name: "Gym Time 💪", duration: 2_700, calories: 350),
            WorkoutTemplate(type: .yoga, name: "Zen Flow 🧘", duration: 2_400, calories: 180),
            WorkoutTemplate(type: .running, name: "5K Personal Record! 🏆", duration: 1_380, calories: 295),
            WorkoutTemplate(type: .cycling, name: "Hill Climb Challenge 🏔️", duration: 5_400, calories: 820)
        ]

        for (index, workout) in workoutTypes.enumerated() {
            let workoutId = UUID().uuidString
            let xpEarned = Int.random(in: 50 ... 150)
            let followersEarned = Int.random(in: 5 ... 25)

            let workoutHistory = Workout(
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

            cloudKitManager.saveWorkout(workoutHistory)
            print("✅ Generated test workout: \(workout.name)")
        }
    }
}
