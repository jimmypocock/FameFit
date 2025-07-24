//
//  MockMessageProvider.swift
//  FameFit Watch AppTests
//
//  Mock implementation of MessageProviding for testing
//

import Foundation
import HealthKit
@testable import FameFit_Watch_App

/// Mock message provider for testing
public class MockMessageProvider: MessageProviding {
    
    // MARK: - Properties
    
    public var personality: MessagePersonality = .default
    
    // MARK: - Test Control Properties
    
    var getMessageCalled = false
    var getTimeAwareMessageCalled = false
    var getMotivationalMessageCalled = false
    var getRoastMessageCalled = false
    var getCatchphraseCalled = false
    var updatePersonalityCalled = false
    
    var lastMessageContext: MessageContext?
    var lastTimeAwareTime: Date?
    var lastRoastWorkoutType: HKWorkoutActivityType?
    var lastPersonalityUpdate: MessagePersonality?
    
    // Test response configuration
    var mockMessage = "Test message"
    var mockTimeAwareMessage = "Test time-aware message"
    var mockMotivationalMessage = "Test motivational message"
    var mockRoastMessage = "Test roast message"
    var mockCatchphrase = "Test catchphrase"
    
    // Track message requests by context
    var messageRequests: [MessageContext] = []
    var timeAwareRequests: [Date] = []
    var roastRequests: [HKWorkoutActivityType?] = []
    
    // MARK: - MessageProviding Implementation
    
    public func getMessage(for context: MessageContext) -> String {
        getMessageCalled = true
        lastMessageContext = context
        messageRequests.append(context)
        
        // Return contextually appropriate mock messages
        if context.isWorkoutStart {
            return "Mock workout start: \(mockMessage)"
        } else if context.isWorkoutEnd {
            return "Mock workout end: \(mockMessage)"
        } else if let milestone = context.milestoneReached {
            return "Mock milestone \(milestone): \(mockMessage)"
        } else {
            return "Mock random: \(mockMessage)"
        }
    }
    
    public func getTimeAwareMessage(at time: Date = Date()) -> String {
        getTimeAwareMessageCalled = true
        lastTimeAwareTime = time
        timeAwareRequests.append(time)
        
        let hour = Calendar.current.component(.hour, from: time)
        return "Mock time-aware (\(hour)h): \(mockTimeAwareMessage)"
    }
    
    public func getMotivationalMessage() -> String {
        getMotivationalMessageCalled = true
        return "Mock motivational: \(mockMotivationalMessage)"
    }
    
    public func getRoastMessage(for workoutType: HKWorkoutActivityType?) -> String {
        getRoastMessageCalled = true
        lastRoastWorkoutType = workoutType
        roastRequests.append(workoutType)
        
        if let workoutType = workoutType {
            let workoutName = getWorkoutName(for: workoutType)
            return "Mock roast (\(workoutName)): \(mockRoastMessage)"
        } else {
            return "Mock roast: \(mockRoastMessage)"
        }
    }
    
    public func getCatchphrase() -> String {
        getCatchphraseCalled = true
        return "Mock catchphrase: \(mockCatchphrase)"
    }
    
    public func updatePersonality(_ newPersonality: MessagePersonality) {
        updatePersonalityCalled = true
        lastPersonalityUpdate = newPersonality
        self.personality = newPersonality
    }
    
    // MARK: - Test Helper Methods
    
    public func reset() {
        getMessageCalled = false
        getTimeAwareMessageCalled = false
        getMotivationalMessageCalled = false
        getRoastMessageCalled = false
        getCatchphraseCalled = false
        updatePersonalityCalled = false
        
        lastMessageContext = nil
        lastTimeAwareTime = nil
        lastRoastWorkoutType = nil
        lastPersonalityUpdate = nil
        
        messageRequests.removeAll()
        timeAwareRequests.removeAll()
        roastRequests.removeAll()
        
        personality = .default
        mockMessage = "Test message"
        mockTimeAwareMessage = "Test time-aware message"
        mockMotivationalMessage = "Test motivational message"
        mockRoastMessage = "Test roast message"
        mockCatchphrase = "Test catchphrase"
    }
    
    public func simulatePersonalityChange(to newPersonality: MessagePersonality) {
        self.personality = newPersonality
    }
    
    public func setMockResponses(
        message: String? = nil,
        timeAware: String? = nil,
        motivational: String? = nil,
        roast: String? = nil,
        catchphrase: String? = nil
    ) {
        if let message = message { mockMessage = message }
        if let timeAware = timeAware { mockTimeAwareMessage = timeAware }
        if let motivational = motivational { mockMotivationalMessage = motivational }
        if let roast = roast { mockRoastMessage = roast }
        if let catchphrase = catchphrase { mockCatchphrase = catchphrase }
    }
    
    // MARK: - Test Assertions
    
    public func assertGetMessageCalled(
        times: Int = 1,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        guard getMessageCalled else {
            XCTFail("getMessage was not called", file: file, line: line)
            return
        }
        
        guard messageRequests.count == times else {
            XCTFail("getMessage was called \(messageRequests.count) times, expected \(times)", file: file, line: line)
            return
        }
    }
    
    public func assertLastContextWas(
        workoutStart: Bool? = nil,
        workoutEnd: Bool? = nil,
        milestone: Int? = nil,
        workoutType: HKWorkoutActivityType? = nil,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        guard let context = lastMessageContext else {
            XCTFail("No message context recorded", file: file, line: line)
            return
        }
        
        if let workoutStart = workoutStart {
            XCTAssertEqual(context.isWorkoutStart, workoutStart, "Workout start mismatch", file: file, line: line)
        }
        
        if let workoutEnd = workoutEnd {
            XCTAssertEqual(context.isWorkoutEnd, workoutEnd, "Workout end mismatch", file: file, line: line)
        }
        
        if let milestone = milestone {
            XCTAssertEqual(context.milestoneReached, milestone, "Milestone mismatch", file: file, line: line)
        }
        
        if let workoutType = workoutType {
            XCTAssertEqual(context.workoutType, workoutType, "Workout type mismatch", file: file, line: line)
        }
    }
    
    public func assertPersonalityUpdated(
        to expectedPersonality: MessagePersonality,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        guard updatePersonalityCalled else {
            XCTFail("updatePersonality was not called", file: file, line: line)
            return
        }
        
        guard let lastUpdate = lastPersonalityUpdate else {
            XCTFail("No personality update recorded", file: file, line: line)
            return
        }
        
        XCTAssertEqual(lastUpdate.roastLevel, expectedPersonality.roastLevel, "Roast level mismatch", file: file, line: line)
        XCTAssertEqual(lastUpdate.includeHumblebrags, expectedPersonality.includeHumblebrags, "Humblebrags setting mismatch", file: file, line: line)
        XCTAssertEqual(lastUpdate.includeSocialMediaRefs, expectedPersonality.includeSocialMediaRefs, "Social media refs setting mismatch", file: file, line: line)
    }
    
    // MARK: - Private Helpers
    
    private func getWorkoutName(for type: HKWorkoutActivityType) -> String {
        return type.displayName
    }
}

// MARK: - XCTest Import

#if canImport(XCTest)
import XCTest
#endif