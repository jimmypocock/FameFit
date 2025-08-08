//
//  WorkoutTypes.swift
//  FameFit
//
//  Centralized workout type definitions for the app
//

import Foundation
import HealthKit
import SwiftUI

// MARK: - Workout Type Configuration

struct WorkoutTypeConfig {
    let type: HKWorkoutActivityType
    let name: String
    let icon: String
    let color: Color
    let caloriesPerMinute: Double // Rough estimate for group workouts without HealthKit data
    
    var id: Int {
        Int(type.rawValue)
    }
}

// MARK: - Centralized Workout Types

enum WorkoutTypes {
    
    // MARK: - Primary Workout Types (for regular workouts)
    static let primary: [WorkoutTypeConfig] = [
        WorkoutTypeConfig(
            type: .running,
            name: "Run",
            icon: "figure.run",
            color: .orange,
            caloriesPerMinute: 10
        ),
        WorkoutTypeConfig(
            type: .cycling,
            name: "Bike",
            icon: "bicycle",
            color: .blue,
            caloriesPerMinute: 8
        ),
        WorkoutTypeConfig(
            type: .walking,
            name: "Walk",
            icon: "figure.walk",
            color: .green,
            caloriesPerMinute: 4
        )
    ]
    
    // MARK: - All Available Types (for group workouts and settings)
    static let all: [WorkoutTypeConfig] = [
        WorkoutTypeConfig(
            type: .running,
            name: "Running",
            icon: "figure.run",
            color: .orange,
            caloriesPerMinute: 10
        ),
        WorkoutTypeConfig(
            type: .cycling,
            name: "Cycling",
            icon: "bicycle",
            color: .blue,
            caloriesPerMinute: 8
        ),
        WorkoutTypeConfig(
            type: .walking,
            name: "Walking",
            icon: "figure.walk",
            color: .green,
            caloriesPerMinute: 4
        ),
        WorkoutTypeConfig(
            type: .swimming,
            name: "Swimming",
            icon: "figure.pool.swim",
            color: .cyan,
            caloriesPerMinute: 11
        ),
        WorkoutTypeConfig(
            type: .functionalStrengthTraining,
            name: "Functional Training",
            icon: "figure.strengthtraining.functional",
            color: .purple,
            caloriesPerMinute: 8
        ),
        WorkoutTypeConfig(
            type: .yoga,
            name: "Yoga",
            icon: "figure.yoga",
            color: .indigo,
            caloriesPerMinute: 3
        ),
        WorkoutTypeConfig(
            type: .socialDance,
            name: "Dance",
            icon: "figure.socialdance",
            color: .pink,
            caloriesPerMinute: 6
        ),
        WorkoutTypeConfig(
            type: .tennis,
            name: "Tennis",
            icon: "figure.tennis",
            color: .yellow,
            caloriesPerMinute: 7
        ),
        WorkoutTypeConfig(
            type: .hiking,
            name: "Hiking",
            icon: "figure.hiking",
            color: .brown,
            caloriesPerMinute: 6
        ),
        WorkoutTypeConfig(
            type: .highIntensityIntervalTraining,
            name: "HIIT",
            icon: "figure.highintensity.intervaltraining",
            color: .red,
            caloriesPerMinute: 12
        ),
        WorkoutTypeConfig(
            type: .traditionalStrengthTraining,
            name: "Strength Training",
            icon: "figure.strengthtraining.traditional",
            color: .gray,
            caloriesPerMinute: 6
        ),
        WorkoutTypeConfig(
            type: .elliptical,
            name: "Elliptical",
            icon: "figure.elliptical",
            color: .mint,
            caloriesPerMinute: 8
        ),
        WorkoutTypeConfig(
            type: .rowing,
            name: "Rowing",
            icon: "figure.rowing",
            color: .teal,
            caloriesPerMinute: 10
        ),
        WorkoutTypeConfig(
            type: .stairClimbing,
            name: "Stair Climbing",
            icon: "figure.stair.stepper",
            color: .orange,
            caloriesPerMinute: 9
        ),
        WorkoutTypeConfig(
            type: .boxing,
            name: "Boxing",
            icon: "figure.boxing",
            color: .red,
            caloriesPerMinute: 12
        )
    ]
    
    // MARK: - Helper Methods
    
    static func config(for type: HKWorkoutActivityType) -> WorkoutTypeConfig? {
        all.first { $0.type == type }
    }
    
    static func caloriesPerMinute(for type: HKWorkoutActivityType) -> Double {
        config(for: type)?.caloriesPerMinute ?? 5 // Default to 5 if not found
    }
    
    static func icon(for type: HKWorkoutActivityType) -> String {
        config(for: type)?.icon ?? "figure.run"
    }
    
    static func name(for type: HKWorkoutActivityType) -> String {
        config(for: type)?.name ?? type.displayName
    }
    
    static func color(for type: HKWorkoutActivityType) -> Color {
        config(for: type)?.color ?? .blue
    }
    
    // MARK: - Validation
    
    static func isSupported(_ type: HKWorkoutActivityType) -> Bool {
        all.contains { $0.type == type }
    }
    
    // MARK: - Default Values
    
    static let defaultType: HKWorkoutActivityType = .walking
    static let defaultConfig: WorkoutTypeConfig = WorkoutTypeConfig(
        type: .walking,
        name: "Walking",
        icon: "figure.walk",
        color: .green,
        caloriesPerMinute: 4
    )
}

// MARK: - Legacy Support

extension WorkoutTypes {
    /// For backward compatibility with existing code
    static var legacyGroupWorkoutTypes: [(id: Int, name: String, icon: String)] {
        all.map { config in
            (config.id, config.name, config.icon)
        }
    }
}