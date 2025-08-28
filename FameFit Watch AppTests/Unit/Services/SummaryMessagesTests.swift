//
//  SummaryMessagesTests.swift
//  FameFit Watch AppTests
//
//  Tests for SummaryMessages motivational message system
//

@testable import FameFit_Watch_App
import XCTest

class SummaryMessagesTests: XCTestCase {
    
    // MARK: - Message Content Tests
    
    func testShortWorkoutMessages() {
        // Given: Duration less than 5 minutes
        let duration: TimeInterval = 240 // 4 minutes
        
        // When: Getting a message
        let message = SummaryMessages.getMessage(duration: duration)
        
        // Then: Should return a non-empty message
        XCTAssertFalse(message.isEmpty, "Should return a message for short workouts")
        
        // Verify it's from one of the expected message arrays
        let possibleMessages = SummaryMessages.shortWorkout + 
                               SummaryMessages.genericAwesome + 
                               SummaryMessages.morningWorkout + 
                               SummaryMessages.eveningWorkout
        XCTAssertTrue(possibleMessages.contains(message), 
                     "Message should be from the defined message sets")
    }
    
    func testMediumWorkoutMessages() {
        // Given: Duration between 5-20 minutes
        let duration: TimeInterval = 600 // 10 minutes
        
        // When: Getting a message
        let message = SummaryMessages.getMessage(duration: duration)
        
        // Then: Should return a non-empty message
        XCTAssertFalse(message.isEmpty, "Should return a message for medium workouts")
        
        // Verify it's from one of the expected message arrays
        let possibleMessages = SummaryMessages.mediumWorkout + 
                               SummaryMessages.genericAwesome + 
                               SummaryMessages.morningWorkout + 
                               SummaryMessages.eveningWorkout
        XCTAssertTrue(possibleMessages.contains(message), 
                     "Message should be from the defined message sets")
    }
    
    func testLongWorkoutMessages() {
        // Given: Duration more than 20 minutes
        let duration: TimeInterval = 1800 // 30 minutes
        
        // When: Getting a message
        let message = SummaryMessages.getMessage(duration: duration)
        
        // Then: Should return a non-empty message
        XCTAssertFalse(message.isEmpty, "Should return a message for long workouts")
        
        // Verify it's from one of the expected message arrays
        let possibleMessages = SummaryMessages.longWorkout + 
                               SummaryMessages.genericAwesome + 
                               SummaryMessages.morningWorkout + 
                               SummaryMessages.eveningWorkout
        XCTAssertTrue(possibleMessages.contains(message), 
                     "Message should be from the defined message sets")
    }
    
    func testZeroDurationWorkout() {
        // Given: Zero duration
        let duration: TimeInterval = 0
        
        // When: Getting a message
        let message = SummaryMessages.getMessage(duration: duration)
        
        // Then: Should still return a message
        XCTAssertFalse(message.isEmpty, "Should handle zero duration gracefully")
    }
    
    func testVeryLongWorkout() {
        // Given: Very long workout (2+ hours)
        let duration: TimeInterval = 7200 // 2 hours
        
        // When: Getting a message
        let message = SummaryMessages.getMessage(duration: duration)
        
        // Then: Should return a long workout message
        XCTAssertFalse(message.isEmpty, "Should return a message for very long workouts")
        
        // Verify it's from one of the expected message arrays
        let possibleMessages = SummaryMessages.longWorkout + 
                               SummaryMessages.genericAwesome + 
                               SummaryMessages.morningWorkout + 
                               SummaryMessages.eveningWorkout
        XCTAssertTrue(possibleMessages.contains(message), 
                     "Message should be from the defined message sets")
    }
    
    // MARK: - Message Variety Tests
    
    func testMessageVariety() {
        // Given: Same duration
        let duration: TimeInterval = 900 // 15 minutes
        var messages = Set<String>()
        
        // When: Getting multiple messages
        for _ in 0..<50 {
            let message = SummaryMessages.getMessage(duration: duration)
            messages.insert(message)
        }
        
        // Then: Should have some variety
        XCTAssertGreaterThan(messages.count, 1, 
                            "Should return different messages for variety")
    }
    
    // MARK: - Message Arrays Tests
    
    func testAllMessageArraysHaveContent() {
        // Verify all message arrays have at least one message
        XCTAssertFalse(SummaryMessages.shortWorkout.isEmpty, 
                      "Short workout messages should not be empty")
        XCTAssertFalse(SummaryMessages.mediumWorkout.isEmpty, 
                      "Medium workout messages should not be empty")
        XCTAssertFalse(SummaryMessages.longWorkout.isEmpty, 
                      "Long workout messages should not be empty")
        XCTAssertFalse(SummaryMessages.genericAwesome.isEmpty, 
                      "Generic messages should not be empty")
        XCTAssertFalse(SummaryMessages.morningWorkout.isEmpty, 
                      "Morning workout messages should not be empty")
        XCTAssertFalse(SummaryMessages.eveningWorkout.isEmpty, 
                      "Evening workout messages should not be empty")
    }
    
    func testMessageDurationBoundaries() {
        // Test boundary conditions
        
        // Exactly 5 minutes (300 seconds) - boundary between short and medium
        let fiveMinutes: TimeInterval = 300
        let fiveMinMessage = SummaryMessages.getMessage(duration: fiveMinutes)
        XCTAssertFalse(fiveMinMessage.isEmpty, "Should handle 5-minute boundary")
        
        // Exactly 20 minutes (1200 seconds) - boundary between medium and long
        let twentyMinutes: TimeInterval = 1200
        let twentyMinMessage = SummaryMessages.getMessage(duration: twentyMinutes)
        XCTAssertFalse(twentyMinMessage.isEmpty, "Should handle 20-minute boundary")
        
        // Just under 5 minutes
        let underFive: TimeInterval = 299
        let underFiveMessage = SummaryMessages.getMessage(duration: underFive)
        XCTAssertFalse(underFiveMessage.isEmpty, "Should handle just under 5 minutes")
        
        // Just under 20 minutes
        let underTwenty: TimeInterval = 1199
        let underTwentyMessage = SummaryMessages.getMessage(duration: underTwenty)
        XCTAssertFalse(underTwentyMessage.isEmpty, "Should handle just under 20 minutes")
    }
    
    func testNegativeDuration() {
        // Given: Negative duration (edge case)
        let duration: TimeInterval = -100
        
        // When: Getting a message
        let message = SummaryMessages.getMessage(duration: duration)
        
        // Then: Should still return a message without crashing
        XCTAssertFalse(message.isEmpty, "Should handle negative duration gracefully")
    }
}