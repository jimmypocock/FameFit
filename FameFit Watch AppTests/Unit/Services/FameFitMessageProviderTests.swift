//
//  FameFitMessageProviderTests.swift
//  FameFit Watch AppTests
//
//  Tests for FameFitMessageProvider with personality customization
//

@testable import FameFit_Watch_App
import HealthKit
import XCTest

class FameFitMessageProviderTests: XCTestCase {
    private var messageProvider: FameFitMessageProvider!

    override func setUp() {
        super.setUp()
        messageProvider = FameFitMessageProvider()
    }

    override func tearDown() {
        messageProvider = nil
        super.tearDown()
    }

    // MARK: - Initialization Tests

    func testInitializationWithDefaultPersonality() {
        // Given & When
        let provider = FameFitMessageProvider()

        // Then
        XCTAssertEqual(provider.personality.roastLevel, .moderateRoasting)
        XCTAssertTrue(provider.personality.includeHumblebrags)
        XCTAssertTrue(provider.personality.includeSocialMediaRefs)
        XCTAssertTrue(provider.personality.includeSupplementTalk)
        XCTAssertTrue(provider.personality.includePhilosophicalNonsense)
    }

    func testInitializationWithCustomPersonality() {
        // Given
        let customPersonality = MessagePersonality.encouraging

        // When
        let provider = FameFitMessageProvider(personality: customPersonality)

        // Then
        XCTAssertEqual(provider.personality.roastLevel, .pureEncouragement)
        XCTAssertFalse(provider.personality.includeHumblebrags)
        XCTAssertFalse(provider.personality.includeSocialMediaRefs)
    }

    // MARK: - Workout Context Tests

    func testWorkoutStartMessage() {
        // Given
        let context = MessageContext.workoutStart(workoutType: .running)

        // When
        let message = messageProvider.getMessage(for: context)

        // Then
        XCTAssertFalse(message.isEmpty)
        // Check that we get one of the workout start messages
        let workoutStartMessages = [
            "Alright bro",
            "Let's get this bread",
            "Time to be legendary",
            "Listen up champ",
            "RISE AND GRIND",
            "Yo! Your transformation",
            "Welcome to the ELITE",
            "Let's GO babe",
            "This workout is sponsored",
            "Bro, I woke up",
        ]
        let containsStartMessage = workoutStartMessages.contains { message.contains($0) }
        XCTAssertTrue(containsStartMessage, "Message should be a workout start message, but got: \(message)")
    }

    func testWorkoutEndMessage() {
        // Given
        let context = MessageContext.workoutEnd(workoutType: .running, duration: 1800) // 30 minutes

        // When
        let message = messageProvider.getMessage(for: context)

        // Then
        XCTAssertFalse(message.isEmpty)
        XCTAssertTrue(message.contains("COMMITMENT") || message.contains("INSANE") || message.contains("LEGENDARY"))
    }

    func testMilestoneMessage() {
        // Given
        let context = MessageContext.milestone(10, workoutType: .running)

        // When
        let message = messageProvider.getMessage(for: context)

        // Then
        XCTAssertFalse(message.isEmpty)
        XCTAssertTrue(message.contains("10 minute") || message.contains("milestone"))
    }

    func testShortWorkoutGetsRoasted() {
        // Given
        messageProvider.personality = .savage // Ensure roasting
        let context = MessageContext.workoutEnd(workoutType: .running, duration: 240) // 4 minutes

        // When
        // Run multiple times to account for randomness
        var foundRoast = false
        for _ in 0 ..< 10 {
            let message = messageProvider.getMessage(for: context)
            if message.contains("shorter") || message.contains("commercial") ||
                message.contains("blinked") || message.contains("attention span") ||
                message.contains("skincare routine")
            {
                foundRoast = true
                break
            }
        }

        // Then
        XCTAssertTrue(foundRoast, "Should eventually return a duration roast for short workouts")
    }

    // MARK: - Personality Level Tests

    func testPureEncouragementPersonality() {
        // Given
        messageProvider.personality = .encouraging

        // When
        let roastMessage = messageProvider.getRoastMessage(for: .running)

        // Then
        // Should return encouragement instead of roast
        let encouragementKeywords = [
            "amazing",
            "stronger",
            "believe",
            "proud",
            "crushing",
            "spirit",
            "doing",
            "got this",
            "Beautiful",
            "inspiring",
            "determination",
            "Love",
            "sweetie",
            "energy",
            "nailing",
            "progress",
            "moment",
            "Embrace",
        ]
        let containsEncouragement = encouragementKeywords.contains { keyword in
            roastMessage.contains(keyword)
        }
        XCTAssertTrue(containsEncouragement, "Pure encouragement should return positive messages, got: \(roastMessage)")
    }

    func testSavagePersonalityIncludesAllFeatures() {
        // Given
        messageProvider.personality = .savage

        // When & Then
        XCTAssertTrue(messageProvider.shouldIncludeCategory(.humbleBrags))
        XCTAssertTrue(messageProvider.shouldIncludeCategory(.socialMediaReferences))
        XCTAssertTrue(messageProvider.shouldIncludeCategory(.supplementTalk))
        XCTAssertTrue(messageProvider.shouldIncludeCategory(.philosophicalNonsense))
    }

    func testEncouragingPersonalityExcludesAnnoyingFeatures() {
        // Given
        messageProvider.personality = .encouraging

        // When & Then
        XCTAssertFalse(messageProvider.shouldIncludeCategory(.humbleBrags))
        XCTAssertFalse(messageProvider.shouldIncludeCategory(.socialMediaReferences))
        XCTAssertFalse(messageProvider.shouldIncludeCategory(.supplementTalk))
        XCTAssertFalse(messageProvider.shouldIncludeCategory(.philosophicalNonsense))
    }

    func testRoastLevelAffectsRoastProbability() {
        // Given
        let pureEncouragement = MessagePersonality(
            roastLevel: .pureEncouragement,
            includeHumblebrags: false,
            includeSocialMediaRefs: false,
            includeSupplementTalk: false,
            includePhilosophicalNonsense: false
        )

        let ruthless = MessagePersonality(
            roastLevel: .ruthless,
            includeHumblebrags: true,
            includeSocialMediaRefs: true,
            includeSupplementTalk: true,
            includePhilosophicalNonsense: true
        )

        // When & Then
        XCTAssertEqual(pureEncouragement.roastLevel.roastWeight, 0.0)
        XCTAssertEqual(ruthless.roastLevel.roastWeight, 0.95)
    }

    // MARK: - Time-Aware Message Tests

    func testEarlyMorningMessage() {
        // Given
        let earlyMorning = Calendar.current.date(bySettingHour: 5, minute: 30, second: 0, of: Date())!

        // When
        let message = messageProvider.getTimeAwareMessage(at: earlyMorning)

        // Then
        XCTAssertFalse(message.isEmpty)
        let morningKeywords = [
            "5AM",
            "early",
            "morning",
            "Rise",
            "grind",
            "dawn",
            "sunrise",
            "Morning",
            "wake",
            "sun",
        ]
        let containsMorningMessage = morningKeywords.contains { keyword in
            message.lowercased().contains(keyword.lowercased())
        }
        XCTAssertTrue(containsMorningMessage, "Early morning should return morning messages, got: \(message)")
    }

    func testAfternoonMessageCanBeRoast() {
        // Given
        messageProvider.personality = .savage
        let afternoon = Calendar.current.date(bySettingHour: 14, minute: 0, second: 0, of: Date())!

        // When
        let message = messageProvider.getTimeAwareMessage(at: afternoon)

        // Then
        XCTAssertFalse(message.isEmpty)
        // With savage personality, afternoon messages can be roasts
    }

    func testEveningMessageIsEncouraging() {
        // Given
        let evening = Calendar.current.date(bySettingHour: 19, minute: 0, second: 0, of: Date())!

        // When
        let message = messageProvider.getTimeAwareMessage(at: evening)

        // Then
        XCTAssertFalse(message.isEmpty)
        // Evening messages should be encouraging
        let encouragementKeywords = [
            "amazing",
            "stronger",
            "believe",
            "proud",
            "crushing",
            "spirit",
            "doing",
            "got this",
            "Beautiful",
            "inspiring",
            "nailing",
            "progress",
            "determination",
            "moment",
        ]
        let containsEncouragement = encouragementKeywords.contains { keyword in
            message.contains(keyword)
        }
        XCTAssertTrue(containsEncouragement, "Evening should return encouraging messages, got: \(message)")
    }

    // MARK: - Workout-Specific Roast Tests

    func testRunningSpecificRoasts() {
        // Given
        messageProvider.personality = .savage

        // When
        let roastMessage = messageProvider.getRoastMessage(for: .running)

        // Then
        XCTAssertFalse(roastMessage.isEmpty)
        // Check for running-specific roast keywords
        let runningKeywords = [
            "running",
            "walking",
            "pace",
            "turtles",
            "hustle",
            "bouncing",
            "battery",
            "stroll",
            "intensity",
            "senior citizens",
            "dead",
            "confused",
            "slow-motion",
            "impressive",
            "terrible",
            "sweat",
            "exercise",
            "meditating",
            "standing",
            "weak",
            "pretend",
        ]
        let containsRunningRoast = runningKeywords.contains { keyword in
            roastMessage.lowercased().contains(keyword.lowercased())
        }
        XCTAssertTrue(containsRunningRoast, "Should return running-related roast, got: \(roastMessage)")
    }

    func testStrengthTrainingSpecificRoasts() {
        // Given
        messageProvider.personality = .savage

        // When
        let roastMessage = messageProvider.getRoastMessage(for: .traditionalStrengthTraining)

        // Then
        XCTAssertFalse(roastMessage.isEmpty)
        // Check for strength-specific roast keywords
        let strengthKeywords = [
            "lifting",
            "weights",
            "strength",
            "paper towel",
            "warmth",
            "intensity",
            "senior citizens",
            "dead",
            "confused",
            "slow-motion",
            "impressive",
            "terrible",
            "sweat",
            "exercise",
            "meditating",
            "standing",
            "weak",
            "pretend",
            "happen",
            "dignity",
        ]
        let containsStrengthRoast = strengthKeywords.contains { keyword in
            roastMessage.lowercased().contains(keyword.lowercased())
        }
        XCTAssertTrue(containsStrengthRoast, "Should return strength-related roast, got: \(roastMessage)")
    }

    // MARK: - Personality Update Tests

    func testPersonalityUpdate() {
        // Given
        let originalPersonality = messageProvider.personality
        let newPersonality = MessagePersonality.savage

        // When
        messageProvider.updatePersonality(newPersonality)

        // Then
        XCTAssertNotEqual(messageProvider.personality.roastLevel, originalPersonality.roastLevel)
        XCTAssertEqual(messageProvider.personality.roastLevel, .ruthless)
        XCTAssertTrue(messageProvider.personality.includeHumblebrags)
    }

    // MARK: - Message Quality Tests

    func testAllMessageMethodsReturnNonEmptyStrings() {
        // Given
        let context = MessageContext.workoutStart(workoutType: .running)

        // When & Then
        XCTAssertFalse(messageProvider.getMessage(for: context).isEmpty)
        XCTAssertFalse(messageProvider.getTimeAwareMessage().isEmpty)
        XCTAssertFalse(messageProvider.getMotivationalMessage().isEmpty)
        XCTAssertFalse(messageProvider.getRoastMessage(for: .running).isEmpty)
        XCTAssertFalse(messageProvider.getCatchphrase().isEmpty)
    }

    func testMessageVariety() {
        // Given
        let context = MessageContext.workoutStart(workoutType: .running)
        var messages = Set<String>()

        // When - Generate multiple messages
        for _ in 0 ..< 20 {
            let message = messageProvider.getMessage(for: context)
            messages.insert(message)
        }

        // Then - Should have variety (more than 1 unique message)
        XCTAssertGreaterThan(messages.count, 1)
    }

    // MARK: - Backwards Compatibility Tests

    func testBackwardsCompatibilityStaticMethods() {
        // When & Then
        XCTAssertFalse(FameFitMessages.getMessage(for: .workoutStart).isEmpty)
        XCTAssertFalse(FameFitMessages.getTimeAwareMessage().isEmpty)
        XCTAssertFalse(FameFitMessages.getWorkoutSpecificMessage(workoutType: "running", duration: 1800).isEmpty)
    }

    // MARK: - Edge Cases Tests

    func testNilWorkoutTypeHandling() {
        // When
        let message = messageProvider.getRoastMessage(for: nil)

        // Then
        XCTAssertFalse(message.isEmpty)
    }

    func testZeroDurationWorkout() {
        // Given
        let context = MessageContext.workoutEnd(workoutType: .running, duration: 0)

        // When
        let message = messageProvider.getMessage(for: context)

        // Then
        XCTAssertFalse(message.isEmpty)
    }

    func testVeryLongWorkout() {
        // Given
        let context = MessageContext.workoutEnd(workoutType: .running, duration: 7200) // 2 hours

        // When
        let message = messageProvider.getMessage(for: context)

        // Then
        XCTAssertFalse(message.isEmpty)
        XCTAssertTrue(message.contains("COMMITMENT") || message.contains("LEGENDARY"))
    }
}

// MARK: - RoastLevel Tests

class RoastLevelTests: XCTestCase {
    func testRoastLevelDescriptions() {
        XCTAssertEqual(RoastLevel.pureEncouragement.description, "Pure Encouragement")
        XCTAssertEqual(RoastLevel.lightTeasing.description, "Light Teasing")
        XCTAssertEqual(RoastLevel.moderateRoasting.description, "Moderate Roasting")
        XCTAssertEqual(RoastLevel.heavyRoasting.description, "Heavy Roasting")
        XCTAssertEqual(RoastLevel.ruthless.description, "Ruthless")
    }

    func testRoastLevelWeights() {
        XCTAssertEqual(RoastLevel.pureEncouragement.roastWeight, 0.0)
        XCTAssertEqual(RoastLevel.lightTeasing.roastWeight, 0.2)
        XCTAssertEqual(RoastLevel.moderateRoasting.roastWeight, 0.5)
        XCTAssertEqual(RoastLevel.heavyRoasting.roastWeight, 0.8)
        XCTAssertEqual(RoastLevel.ruthless.roastWeight, 0.95)
    }

    func testRoastLevelCaseIterable() {
        let allCases = RoastLevel.allCases
        XCTAssertEqual(allCases.count, 5)
        XCTAssertTrue(allCases.contains(.pureEncouragement))
        XCTAssertTrue(allCases.contains(.ruthless))
    }
}

// MARK: - MessagePersonality Tests

class MessagePersonalityTests: XCTestCase {
    func testDefaultPersonality() {
        let personality = MessagePersonality.default
        XCTAssertEqual(personality.roastLevel, .moderateRoasting)
        XCTAssertTrue(personality.includeHumblebrags)
        XCTAssertTrue(personality.includeSocialMediaRefs)
        XCTAssertTrue(personality.includeSupplementTalk)
        XCTAssertTrue(personality.includePhilosophicalNonsense)
    }

    func testEncouragingPersonality() {
        let personality = MessagePersonality.encouraging
        XCTAssertEqual(personality.roastLevel, .pureEncouragement)
        XCTAssertFalse(personality.includeHumblebrags)
        XCTAssertFalse(personality.includeSocialMediaRefs)
        XCTAssertFalse(personality.includeSupplementTalk)
        XCTAssertFalse(personality.includePhilosophicalNonsense)
    }

    func testSavagePersonality() {
        let personality = MessagePersonality.savage
        XCTAssertEqual(personality.roastLevel, .ruthless)
        XCTAssertTrue(personality.includeHumblebrags)
        XCTAssertTrue(personality.includeSocialMediaRefs)
        XCTAssertTrue(personality.includeSupplementTalk)
        XCTAssertTrue(personality.includePhilosophicalNonsense)
    }
}
