import XCTest
import HealthKit
@testable import FameFit

class FameFitCharactersTests: XCTestCase {
    
    func testCharacterSelection() {
        // Test character selection logic for different workout types
        let runningCharacter = FameFitCharacter.characterForWorkoutType(.running)
        let cyclingCharacter = FameFitCharacter.characterForWorkoutType(.cycling)
        let walkingCharacter = FameFitCharacter.characterForWorkoutType(.walking)
        
        XCTAssertEqual(runningCharacter, .rex)
        XCTAssertEqual(cyclingCharacter, .bella)
        XCTAssertEqual(walkingCharacter, .max)
    }
    
    func testCharacterProperties() {
        // Test character emoji properties
        XCTAssertEqual(FameFitCharacter.rex.emoji, "🦖")
        XCTAssertEqual(FameFitCharacter.bella.emoji, "💁‍♀️")
        XCTAssertEqual(FameFitCharacter.max.emoji, "🐕")
        XCTAssertEqual(FameFitCharacter.luna.emoji, "🦄")
        XCTAssertEqual(FameFitCharacter.rocky.emoji, "🥊")
        XCTAssertEqual(FameFitCharacter.chad.emoji, "💪")
        
        // Test character names
        XCTAssertEqual(FameFitCharacter.rex.fullName, "Rex the Runner")
        XCTAssertEqual(FameFitCharacter.bella.fullName, "Bella on a Bike")
        XCTAssertEqual(FameFitCharacter.max.fullName, "Max the Mutt")
    }
    
    func testWorkoutCompletionMessages() {
        // Test that each character generates valid workout completion messages
        let testFollowers = 5
        
        for character in [FameFitCharacter.rex, .bella, .max, .luna, .rocky, .chad] {
            let message = character.workoutCompletionMessage(followers: testFollowers)
            
            XCTAssertFalse(message.isEmpty, "\(character.fullName) should have a completion message")
            XCTAssertTrue(message.contains("\(testFollowers)"), "Message should contain follower count")
        }
    }
    
    func testCharacterForVariousWorkoutTypes() {
        // Test that all workout types return a valid character
        let workoutTypes: [HKWorkoutActivityType] = [
            .running, .cycling, .walking, .hiking, .swimming,
            .yoga, .functionalStrengthTraining, .dance, .boxing
        ]
        
        for workoutType in workoutTypes {
            let character = FameFitCharacter.characterForWorkoutType(workoutType)
            XCTAssertNotNil(character, "Should return a character for \(workoutType)")
        }
    }
}