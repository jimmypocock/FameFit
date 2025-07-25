//
//  NotificationMessageProvider.swift
//  FameFit
//
//  Simplified message provider for notification content
//

import Foundation

// MARK: - Message Provider Protocol

protocol MessageProviding {
    func getWorkoutEndMessage(workoutType: String, duration: Int, calories: Int, xpEarned: Int) -> String
    func getStreakMessage(streak: Int, isAtRisk: Bool) -> String
    func getXPMilestoneMessage(level: Int, title: String) -> String
    func getFollowerMessage(username: String, displayName: String, action: String) -> String
}

// MARK: - Default Implementation

final class FameFitMessageProvider: MessageProviding {
    func getWorkoutEndMessage(workoutType: String, duration: Int, calories: Int, xpEarned: Int) -> String {
        let messages = [
            "Great \(workoutType.lowercased()) session! \(duration) minutes, \(calories) calories burned, and \(xpEarned) XP earned! 💪",
            "Crushed it! \(xpEarned) XP added to your total. Keep pushing! 🔥",
            "\(workoutType) complete! You're \(xpEarned) XP closer to your next level!",
            "Another one in the books! \(duration) minutes of pure dedication earned you \(xpEarned) XP!",
            "Workout warrior! \(calories) calories torched and \(xpEarned) XP collected! 🏆",
        ]
        return messages.randomElement()!
    }

    func getStreakMessage(streak: Int, isAtRisk: Bool) -> String {
        if isAtRisk {
            let messages = [
                "Your \(streak)-day streak needs you! Don't let it slip away!",
                "\(streak) days of consistency on the line. You've got this!",
                "Quick workout to save your \(streak)-day streak? Future you will thank you!",
                "Streak alert! Keep your \(streak)-day run alive with a workout today!",
            ]
            return messages.randomElement()!
        } else {
            let messages = [
                "\(streak) days strong! You're unstoppable! 🔥",
                "Streak game on point! \(streak) days and counting!",
                "\(streak)-day streak achieved! Consistency is your superpower!",
                "Day \(streak) complete! You're building something special here!",
            ]
            return messages.randomElement()!
        }
    }

    func getXPMilestoneMessage(level: Int, title: String) -> String {
        let messages = [
            "Level \(level) unlocked! You're now a \(title)! 🎉",
            "Congrats, \(title)! Level \(level) looks good on you!",
            "Achievement unlocked: \(title) (Level \(level))! Keep climbing!",
            "Welcome to Level \(level), \(title)! The journey continues!",
        ]
        return messages.randomElement()!
    }

    func getFollowerMessage(username: String, displayName: String, action: String) -> String {
        switch action {
        case "follow":
            "\(displayName) (@\(username)) is now following your fitness journey!"
        case "kudos":
            "\(displayName) gave your workout a kudos!"
        case "comment":
            "\(displayName) commented on your workout"
        case "mention":
            "\(displayName) mentioned you"
        default:
            "\(displayName) interacted with your content"
        }
    }
}

// MARK: - Mock Implementation

final class MockMessageProvider: MessageProviding {
    var workoutEndMessageCalled = false
    var streakMessageCalled = false
    var xpMilestoneMessageCalled = false
    var followerMessageCalled = false

    func getWorkoutEndMessage(workoutType _: String, duration _: Int, calories _: Int, xpEarned _: Int) -> String {
        workoutEndMessageCalled = true
        return "Test workout message"
    }

    func getStreakMessage(streak _: Int, isAtRisk _: Bool) -> String {
        streakMessageCalled = true
        return "Test streak message"
    }

    func getXPMilestoneMessage(level _: Int, title _: String) -> String {
        xpMilestoneMessageCalled = true
        return "Test XP message"
    }

    func getFollowerMessage(username _: String, displayName _: String, action _: String) -> String {
        followerMessageCalled = true
        return "Test follower message"
    }
}
