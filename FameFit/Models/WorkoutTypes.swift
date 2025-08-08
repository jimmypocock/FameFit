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
        // Cardio
        WorkoutTypeConfig(
            type: .running,
            name: "Running",
            icon: "figure.run",
            color: .orange,
            caloriesPerMinute: 10
        ),
        WorkoutTypeConfig(
            type: .walking,
            name: "Walking",
            icon: "figure.walk",
            color: .green,
            caloriesPerMinute: 4
        ),
        WorkoutTypeConfig(
            type: .cycling,
            name: "Cycling",
            icon: "bicycle",
            color: .blue,
            caloriesPerMinute: 8
        ),
        WorkoutTypeConfig(
            type: .swimming,
            name: "Swimming",
            icon: "figure.pool.swim",
            color: .cyan,
            caloriesPerMinute: 11
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
            icon: "figure.rower",
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
            type: .jumpRope,
            name: "Jump Rope",
            icon: "figure.jumprope",
            color: .purple,
            caloriesPerMinute: 11
        ),
        
        // Strength
        WorkoutTypeConfig(
            type: .traditionalStrengthTraining,
            name: "Strength Training",
            icon: "figure.strengthtraining.traditional",
            color: .gray,
            caloriesPerMinute: 6
        ),
        WorkoutTypeConfig(
            type: .functionalStrengthTraining,
            name: "Functional Training",
            icon: "figure.strengthtraining.functional",
            color: .purple,
            caloriesPerMinute: 8
        ),
        WorkoutTypeConfig(
            type: .coreTraining,
            name: "Core Training",
            icon: "figure.strengthtraining.traditional",
            color: .orange,
            caloriesPerMinute: 5
        ),
        
        // HIIT & Cross Training
        WorkoutTypeConfig(
            type: .highIntensityIntervalTraining,
            name: "HIIT",
            icon: "figure.highintensity.intervaltraining",
            color: .red,
            caloriesPerMinute: 12
        ),
        WorkoutTypeConfig(
            type: .crossTraining,
            name: "Cross Training",
            icon: "figure.highintensity.intervaltraining",
            color: .purple,
            caloriesPerMinute: 9
        ),
        WorkoutTypeConfig(
            type: .mixedCardio,
            name: "Mixed Cardio",
            icon: "figure.run.circle",
            color: .pink,
            caloriesPerMinute: 8
        ),
        
        // Mind & Body
        WorkoutTypeConfig(
            type: .yoga,
            name: "Yoga",
            icon: "figure.yoga",
            color: .indigo,
            caloriesPerMinute: 3
        ),
        WorkoutTypeConfig(
            type: .pilates,
            name: "Pilates",
            icon: "figure.pilates",
            color: .mint,
            caloriesPerMinute: 4
        ),
        WorkoutTypeConfig(
            type: .taiChi,
            name: "Tai Chi",
            icon: "figure.taichi",
            color: .cyan,
            caloriesPerMinute: 3
        ),
        WorkoutTypeConfig(
            type: .mindAndBody,
            name: "Mind & Body",
            icon: "figure.mind.and.body",
            color: .indigo,
            caloriesPerMinute: 3
        ),
        WorkoutTypeConfig(
            type: .flexibility,
            name: "Flexibility",
            icon: "figure.flexibility",
            color: .blue,
            caloriesPerMinute: 2
        ),
        
        // Sports
        WorkoutTypeConfig(
            type: .basketball,
            name: "Basketball",
            icon: "figure.basketball",
            color: .orange,
            caloriesPerMinute: 8
        ),
        WorkoutTypeConfig(
            type: .soccer,
            name: "Soccer",
            icon: "figure.soccer",
            color: .green,
            caloriesPerMinute: 9
        ),
        WorkoutTypeConfig(
            type: .tennis,
            name: "Tennis",
            icon: "figure.tennis",
            color: .yellow,
            caloriesPerMinute: 7
        ),
        WorkoutTypeConfig(
            type: .golf,
            name: "Golf",
            icon: "figure.golf",
            color: .green,
            caloriesPerMinute: 4
        ),
        WorkoutTypeConfig(
            type: .baseball,
            name: "Baseball",
            icon: "figure.baseball",
            color: .brown,
            caloriesPerMinute: 5
        ),
        WorkoutTypeConfig(
            type: .volleyball,
            name: "Volleyball",
            icon: "figure.volleyball",
            color: .blue,
            caloriesPerMinute: 6
        ),
        WorkoutTypeConfig(
            type: .badminton,
            name: "Badminton",
            icon: "figure.tennis",
            color: .mint,
            caloriesPerMinute: 6
        ),
        WorkoutTypeConfig(
            type: .pickleball,
            name: "Pickleball",
            icon: "figure.tennis",
            color: .green,
            caloriesPerMinute: 5
        ),
        
        // Martial Arts
        WorkoutTypeConfig(
            type: .boxing,
            name: "Boxing",
            icon: "figure.martial.arts",
            color: .red,
            caloriesPerMinute: 12
        ),
        WorkoutTypeConfig(
            type: .kickboxing,
            name: "Kickboxing",
            icon: "figure.martial.arts",
            color: .orange,
            caloriesPerMinute: 10
        ),
        WorkoutTypeConfig(
            type: .martialArts,
            name: "Martial Arts",
            icon: "figure.martial.arts",
            color: .red,
            caloriesPerMinute: 9
        ),
        
        // Dance (using non-deprecated types)
        WorkoutTypeConfig(
            type: .cardioDance,
            name: "Cardio Dance",
            icon: "figure.dance",
            color: .pink,
            caloriesPerMinute: 7
        ),
        WorkoutTypeConfig(
            type: .socialDance,
            name: "Social Dance",
            icon: "figure.dance",
            color: .pink,
            caloriesPerMinute: 6
        ),
        WorkoutTypeConfig(
            type: .barre,
            name: "Barre",
            icon: "figure.barre",
            color: .purple,
            caloriesPerMinute: 5
        ),
        
        // Winter Sports
        WorkoutTypeConfig(
            type: .snowboarding,
            name: "Snowboarding",
            icon: "figure.snowboarding",
            color: .cyan,
            caloriesPerMinute: 8
        ),
        WorkoutTypeConfig(
            type: .downhillSkiing,
            name: "Downhill Skiing",
            icon: "figure.snowboarding",
            color: .blue,
            caloriesPerMinute: 7
        ),
        WorkoutTypeConfig(
            type: .crossCountrySkiing,
            name: "Cross Country Skiing",
            icon: "figure.snowboarding",
            color: .cyan,
            caloriesPerMinute: 9
        ),
        
        // Water Sports
        WorkoutTypeConfig(
            type: .surfingSports,
            name: "Surfing",
            icon: "figure.surfing",
            color: .blue,
            caloriesPerMinute: 6
        ),
        WorkoutTypeConfig(
            type: .paddleSports,
            name: "Paddle Sports",
            icon: "figure.outdoor.cycle",
            color: .cyan,
            caloriesPerMinute: 5
        ),
        
        // Other Activities
        WorkoutTypeConfig(
            type: .hiking,
            name: "Hiking",
            icon: "figure.hiking",
            color: .brown,
            caloriesPerMinute: 6
        ),
        WorkoutTypeConfig(
            type: .climbing,
            name: "Climbing",
            icon: "figure.climbing",
            color: .orange,
            caloriesPerMinute: 11
        ),
        WorkoutTypeConfig(
            type: .cooldown,
            name: "Cooldown",
            icon: "figure.cooldown",
            color: .blue,
            caloriesPerMinute: 2
        ),
        WorkoutTypeConfig(
            type: .other,
            name: "Other",
            icon: "figure.wave",
            color: .gray,
            caloriesPerMinute: 5
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