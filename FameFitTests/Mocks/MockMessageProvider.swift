//
//  MockMessageProvider.swift
//  FameFitTests
//
//  Mock implementation of MessagingProtocol for testing
//

@testable import FameFit
import Foundation
import HealthKit

class MockMessageProvider: MessagingProtocol {
    // Required properties
    var personality: MessagePersonality = .default
    
    // Track method calls
    var getMessageCalled = false
    var getTimeAwareMessageCalled = false
    var getMotivationalMessageCalled = false
    var getRoastMessageCalled = false
    var getCatchphraseCalled = false
    var updatePersonalityCalled = false
    var shouldIncludeCategoryCalled = false
    var getWorkoutEndMessageCalled = false
    var getStreakMessageCalled = false
    var getXPMilestoneMessageCalled = false
    var getFollowerMessageCalled = false
    
    // Control return values
    var mockMessage = "Test message"
    var mockTimeAwareMessage = "Good morning!"
    var mockMotivationalMessage = "Keep going!"
    var mockRoastMessage = "Nice try!"
    var mockCatchphrase = "Boom!"
    var mockWorkoutEndMessage = "Workout complete!"
    var mockStreakMessage = "Great streak!"
    var mockXPMilestoneMessage = "Level up!"
    var mockFollowerMessage = "New follower!"
    var mockShouldIncludeCategory = true
    
    func getMessage(for context: MessageContext) -> String {
        getMessageCalled = true
        return mockMessage
    }
    
    func getTimeAwareMessage(at time: Date) -> String {
        getTimeAwareMessageCalled = true
        return mockTimeAwareMessage
    }
    
    func getMotivationalMessage() -> String {
        getMotivationalMessageCalled = true
        return mockMotivationalMessage
    }
    
    func getRoastMessage(for workoutType: HKWorkoutActivityType?) -> String {
        getRoastMessageCalled = true
        return mockRoastMessage
    }
    
    func getCatchphrase() -> String {
        getCatchphraseCalled = true
        return mockCatchphrase
    }
    
    func updatePersonality(_ newPersonality: MessagePersonality) {
        updatePersonalityCalled = true
        personality = newPersonality
    }
    
    func shouldIncludeCategory(_ category: MessageCategory) -> Bool {
        shouldIncludeCategoryCalled = true
        return mockShouldIncludeCategory
    }
    
    func getWorkoutEndMessage(workoutType: String, duration: Int, calories: Int, xpEarned: Int) -> String {
        getWorkoutEndMessageCalled = true
        return mockWorkoutEndMessage
    }
    
    func getStreakMessage(streak: Int, isAtRisk: Bool) -> String {
        getStreakMessageCalled = true
        return mockStreakMessage
    }
    
    func getXPMilestoneMessage(level: Int, title: String) -> String {
        getXPMilestoneMessageCalled = true
        return mockXPMilestoneMessage
    }
    
    func getFollowerMessage(username: String, displayName: String, action: String) -> String {
        getFollowerMessageCalled = true
        return mockFollowerMessage
    }
    
    // Test helper
    func reset() {
        getMessageCalled = false
        getTimeAwareMessageCalled = false
        getMotivationalMessageCalled = false
        getRoastMessageCalled = false
        getCatchphraseCalled = false
        updatePersonalityCalled = false
        shouldIncludeCategoryCalled = false
        getWorkoutEndMessageCalled = false
        getStreakMessageCalled = false
        getXPMilestoneMessageCalled = false
        getFollowerMessageCalled = false
        personality = .default
    }
}