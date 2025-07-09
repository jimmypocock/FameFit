import Foundation
import HealthKit

enum FameFitCharacter: String, CaseIterable {
    case chad = "Chad Maximus"
    case sierra = "Sierra Pace"
    case zen = "Zen Flexington"
    
    var fullName: String {
        return self.rawValue
    }
    
    var emoji: String {
        switch self {
        case .chad: return "💪"
        case .sierra: return "🏃‍♀️"
        case .zen: return "🧘‍♂️"
        }
    }
    
    var specialty: String {
        switch self {
        case .chad: return "Weight Lifting"
        case .sierra: return "Cardio"
        case .zen: return "Yoga & Mindfulness"
        }
    }
    
    var catchphrase: String {
        switch self {
        case .chad: return "Let's get SWOLE!"
        case .sierra: return "Pace yourself to greatness!"
        case .zen: return "Manifest your inner strength"
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
    
    static func characterForWorkoutType(_ workoutType: HKWorkoutActivityType) -> FameFitCharacter {
        switch workoutType {
        case .traditionalStrengthTraining, .functionalStrengthTraining, .coreTraining:
            return .chad
        case .running, .walking, .cycling, .elliptical, .stairClimbing, .rowing:
            return .sierra
        case .yoga, .mindAndBody, .flexibility, .cooldown:
            return .zen
        default:
            return FameFitCharacter.allCases.randomElement() ?? .chad
        }
    }
}