//
//  FameFitCharacters.swift
//  FameFit
//
//  Character definitions and workout type extensions
//

import Foundation
import HealthKit

// MARK: - HKWorkoutActivityType Extensions

extension HKWorkoutActivityType {
    /// Human-readable name for the workout type
    var name: String {
        switch self {
        case .running:
            return "Running"
        case .cycling:
            return "Cycling"
        case .walking:
            return "Walking"
        case .swimming:
            return "Swimming"
        case .yoga:
            return "Yoga"
        case .functionalStrengthTraining:
            return "Strength Training"
        case .traditionalStrengthTraining:
            return "Weight Training"
        case .crossTraining:
            return "Cross Training"
        case .coreTraining:
            return "Core Training"
        case .elliptical:
            return "Elliptical"
        case .rowing:
            return "Rowing"
        case .stairClimbing:
            return "Stair Climbing"
        case .highIntensityIntervalTraining:
            return "HIIT"
        case .dance:
            return "Dance"
        case .pilates:
            return "Pilates"
        case .martialArts:
            return "Martial Arts"
        case .hiking:
            return "Hiking"
        case .tennis:
            return "Tennis"
        case .tableTennis:
            return "Table Tennis"
        case .basketball:
            return "Basketball"
        case .soccer:
            return "Soccer"
        case .americanFootball:
            return "Football"
        case .golf:
            return "Golf"
        case .badminton:
            return "Badminton"
        case .baseball:
            return "Baseball"
        case .bowling:
            return "Bowling"
        case .boxing:
            return "Boxing"
        case .climbing:
            return "Climbing"
        case .cricket:
            return "Cricket"
        case .crossCountrySkiing:
            return "Cross Country Skiing"
        case .downhillSkiing:
            return "Downhill Skiing"
        case .flexibility:
            return "Flexibility"
        case .handball:
            return "Handball"
        case .hockey:
            return "Hockey"
        case .hunting:
            return "Hunting"
        case .lacrosse:
            return "Lacrosse"
        case .mindAndBody:
            return "Mind & Body"
        case .paddleSports:
            return "Paddle Sports"
        case .play:
            return "Play"
        case .preparationAndRecovery:
            return "Recovery"
        case .racquetball:
            return "Racquetball"
        case .rugby:
            return "Rugby"
        case .sailing:
            return "Sailing"
        case .skatingSports:
            return "Skating"
        case .snowSports:
            return "Snow Sports"
        case .softball:
            return "Softball"
        case .squash:
            return "Squash"
        case .surfingSports:
            return "Surfing"
        case .swimBikeRun:
            return "Triathlon"
        case .volleyball:
            return "Volleyball"
        case .waterFitness:
            return "Water Fitness"
        case .waterPolo:
            return "Water Polo"
        case .waterSports:
            return "Water Sports"
        case .wrestling:
            return "Wrestling"
        case .other:
            return "Other"
        default:
            return "Workout"
        }
    }
    
    private static let nameToWorkoutType: [String: HKWorkoutActivityType] = [
        "Running": .running,
        "Cycling": .cycling,
        "Walking": .walking,
        "Swimming": .swimming,
        "Yoga": .yoga,
        "Strength Training": .functionalStrengthTraining,
        "Weight Training": .traditionalStrengthTraining,
        "Cross Training": .crossTraining,
        "Core Training": .coreTraining,
        "Elliptical": .elliptical,
        "Rowing": .rowing,
        "Stair Climbing": .stairClimbing,
        "HIIT": .highIntensityIntervalTraining,
        "Dance": .cardioDance,
        "Pilates": .pilates,
        "Martial Arts": .martialArts,
        "Hiking": .hiking,
        "Tennis": .tennis,
        "Table Tennis": .tableTennis,
        "Basketball": .basketball,
        "Soccer": .soccer,
        "Football": .americanFootball,
        "Golf": .golf,
        "Badminton": .badminton,
        "Baseball": .baseball,
        "Bowling": .bowling,
        "Boxing": .boxing,
        "Climbing": .climbing,
        "Cricket": .cricket,
        "Cross Country Skiing": .crossCountrySkiing,
        "Downhill Skiing": .downhillSkiing,
        "Flexibility": .flexibility,
        "Handball": .handball,
        "Hockey": .hockey,
        "Hunting": .hunting,
        "Lacrosse": .lacrosse,
        "Mind & Body": .mindAndBody,
        "Paddle Sports": .paddleSports,
        "Play": .play,
        "Recovery": .preparationAndRecovery,
        "Racquetball": .racquetball,
        "Rugby": .rugby,
        "Sailing": .sailing,
        "Skating": .skatingSports,
        "Snow Sports": .snowSports,
        "Softball": .softball,
        "Squash": .squash,
        "Surfing": .surfingSports,
        "Triathlon": .swimBikeRun,
        "Volleyball": .volleyball,
        "Water Fitness": .waterFitness,
        "Water Polo": .waterPolo,
        "Water Sports": .waterSports,
        "Wrestling": .wrestling,
        "Other": .other
    ]
    
    /// Create HKWorkoutActivityType from string name
    static func from(name: String) -> HKWorkoutActivityType {
        return nameToWorkoutType[name] ?? .other
    }
}

// MARK: - FameFit Characters

enum FameFitCharacter: String, CaseIterable, Codable {
    case chad = "Chad"
    case sierra = "Sierra"
    case zen = "Zen"
    
    var emoji: String {
        switch self {
        case .chad: return "💪"
        case .sierra: return "🏃‍♀️"
        case .zen: return "🧘‍♀️"
        }
    }
    
    var fullName: String {
        switch self {
        case .chad: return "Chad Thunderbro"
        case .sierra: return "Sierra Swiftfoot"
        case .zen: return "Zen Master Flex"
        }
    }
    
    var catchphrase: String {
        switch self {
        case .chad: return "GET HUGE OR GO HOME!"
        case .sierra: return "Every mile is a milestone!"
        case .zen: return "Find your flow, grow your glow"
        }
    }
    
    var specialty: String {
        switch self {
        case .chad: return "Strength & Power"
        case .sierra: return "Cardio & Endurance"
        case .zen: return "Flexibility & Mindfulness"
        }
    }
    
    func workoutCompletionMessage(followers: Int) -> String {
        switch self {
        case .chad:
            return "BRO! You just CRUSHED that workout! \(followers) new followers are mirin' your gains! 💪"
        case .sierra:
            return "Amazing pace out there! You just earned \(followers) new followers who can't keep up! 🏃‍♀️"
        case .zen:
            return "Beautiful flow, warrior. The universe has gifted you \(followers) new followers. Namaste 🙏"
        }
    }
    
    func motivationalMessage() -> String {
        let messages: [String]
        switch self {
        case .chad:
            messages = [
                "Time to get HUGE! Your followers are waiting!",
                "No pain, no gain, no followers!",
                "Let's show these followers what BEAST MODE looks like!",
                "Your muscles called - they want more followers!",
                "Time to lift heavy and post heavily!"
            ]
        case .sierra:
            messages = [
                "Every step is a follower earned!",
                "Your cardio game needs to match your follower game!",
                "Run like your follower count depends on it!",
                "Miles = Smiles = Followers!",
                "Let's get that heart rate AND follower count up!"
            ]
        case .zen:
            messages = [
                "Breathe in strength, exhale followers",
                "Your chakras are aligned with the algorithm",
                "Flexibility in body, growth in followers",
                "The universe is ready to expand your reach",
                "Inner peace leads to outer influence"
            ]
        }
        return messages.randomElement() ?? catchphrase
    }
    
    static func characterForWorkoutType(_ type: HKWorkoutActivityType) -> FameFitCharacter {
        switch type {
        case .functionalStrengthTraining, .traditionalStrengthTraining, .coreTraining, .crossTraining:
            return .chad
        case .running, .walking, .cycling, .elliptical, .stairClimbing, .rowing:
            return .sierra
        case .yoga, .pilates, .flexibility, .mindAndBody:
            return .zen
        default:
            // For other workout types, return a random character
            return FameFitCharacter.allCases.randomElement()!
        }
    }
}