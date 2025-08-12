//
//  SummaryMessages.swift
//  FameFit Watch App
//
//  Lightweight motivational messages for workout summary
//

import Foundation

struct SummaryMessages {
    
    // MARK: - Message Categories
    
    static let shortWorkout = [
        "Every journey starts with a single step!",
        "Quick and effective. Love it!",
        "Short but sweet!",
        "You showed up. That's what matters.",
        "Consistency > Duration",
        "Even 5 minutes counts!",
        "Better than scrolling social media!",
        "Quick hit of endorphins!"
    ]
    
    static let mediumWorkout = [
        "Now we're talking!",
        "Solid effort out there!",
        "You're getting stronger!",
        "Look at you go!",
        "That's how it's done!",
        "Crushing those goals!",
        "You're on fire today!",
        "Keep this momentum going!"
    ]
    
    static let longWorkout = [
        "ABSOLUTE LEGEND!",
        "You're unstoppable!",
        "That was EPIC!",
        "Marathon mode: ACTIVATED",
        "You're built different!",
        "Endurance champion!",
        "Now THAT'S dedication!",
        "You just set the bar HIGH!"
    ]
    
    static let genericAwesome = [
        "Well, well, well...",
        "Another one in the books!",
        "You did that!",
        "Mission accomplished!",
        "Workout complete!",
        "That's a wrap!",
        "And... DONE!",
        "Victory achieved!"
    ]
    
    static let morningWorkout = [
        "Early bird gets the gains!",
        "Starting the day RIGHT!",
        "Morning warrior!",
        "Rise and grind complete!",
        "Sun's up, guns up!",
        "Dawn patrol crushed!"
    ]
    
    static let eveningWorkout = [
        "Ending the day strong!",
        "Night shift complete!",
        "Evening excellence!",
        "Sunset sweat session!",
        "Closing out the day right!",
        "Night moves!"
    ]
    
    // MARK: - Public Methods
    
    /// Get a message based on workout duration and time of day
    static func getMessage(duration: TimeInterval) -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        
        // Check time of day first (20% chance)
        if Int.random(in: 0..<5) == 0 {
            if hour < 9 {
                return morningWorkout.randomElement() ?? genericAwesome.randomElement()!
            } else if hour > 18 {
                return eveningWorkout.randomElement() ?? genericAwesome.randomElement()!
            }
        }
        
        // Otherwise base on duration
        switch duration {
        case 0..<300: // Less than 5 minutes
            return shortWorkout.randomElement() ?? genericAwesome.randomElement()!
        case 300..<1200: // 5-20 minutes
            return mediumWorkout.randomElement() ?? genericAwesome.randomElement()!
        case 1200...: // 20+ minutes
            return longWorkout.randomElement() ?? genericAwesome.randomElement()!
        default:
            return genericAwesome.randomElement()!
        }
    }
    
    /// Get a random generic message (fallback)
    static func getRandomMessage() -> String {
        genericAwesome.randomElement() ?? "Great workout!"
    }
}