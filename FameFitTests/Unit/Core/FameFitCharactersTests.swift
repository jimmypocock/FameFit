import XCTest
import HealthKit
@testable import FameFit

class FameFitCharactersTests: XCTestCase {
    
    func testCharacterSelection() {
        // Test character selection logic for different workout types
        let strengthCharacter = FameFitCharacter.characterForWorkoutType(.functionalStrengthTraining)
        let runningCharacter = FameFitCharacter.characterForWorkoutType(.running)
        let yogaCharacter = FameFitCharacter.characterForWorkoutType(.yoga)
        
        XCTAssertEqual(strengthCharacter, .chad)
        XCTAssertEqual(runningCharacter, .sierra)
        XCTAssertEqual(yogaCharacter, .zen)
    }
    
    func testCharacterProperties() {
        // Test character emoji properties
        XCTAssertEqual(FameFitCharacter.chad.emoji, "💪")
        XCTAssertEqual(FameFitCharacter.sierra.emoji, "🏃‍♀️")
        XCTAssertEqual(FameFitCharacter.zen.emoji, "🧘‍♀️")
        
        // Test character names
        XCTAssertEqual(FameFitCharacter.chad.fullName, "Chad Thunderbro")
        XCTAssertEqual(FameFitCharacter.sierra.fullName, "Sierra Swiftfoot")
        XCTAssertEqual(FameFitCharacter.zen.fullName, "Zen Master Flex")
        
        // Test character specialties
        XCTAssertEqual(FameFitCharacter.chad.specialty, "Strength & Power")
        XCTAssertEqual(FameFitCharacter.sierra.specialty, "Cardio & Endurance")
        XCTAssertEqual(FameFitCharacter.zen.specialty, "Flexibility & Mindfulness")
    }
    
    func testWorkoutCompletionMessages() {
        // Test that each character generates valid workout completion messages
        let testFollowers = 5
        
        for character in FameFitCharacter.allCases {
            let message = character.workoutCompletionMessage(followers: testFollowers)
            
            XCTAssertFalse(message.isEmpty, "\(character.fullName) should have a completion message")
            XCTAssertTrue(message.contains("\(testFollowers)"), "Message should contain follower count")
        }
    }
    
    func testCharacterForVariousWorkoutTypes() {
        // Test that all workout types return a valid character
        let workoutTypes: [HKWorkoutActivityType] = [
            .running, .cycling, .walking, .hiking, .swimming,
            .yoga, .functionalStrengthTraining, .socialDance, .boxing
        ]
        
        for workoutType in workoutTypes {
            let character = FameFitCharacter.characterForWorkoutType(workoutType)
            XCTAssertNotNil(character, "Should return a character for \(workoutType)")
        }
    }
}