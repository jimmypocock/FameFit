//
//  WorkoutPrivacySettingsTests.swift
//  FameFitTests
//
//  Unit tests for workout privacy settings
//

import XCTest
import HealthKit
@testable import FameFit

final class WorkoutPrivacySettingsTests: XCTestCase {
    
    // MARK: - Default Values Tests
    
    func testDefaultValues() {
        // Given/When
        let settings = WorkoutPrivacySettings()
        
        // Then
        XCTAssertEqual(settings.defaultPrivacy, .private)
        XCTAssertTrue(settings.workoutTypeSettings.isEmpty)
        XCTAssertFalse(settings.allowDataSharing)
        XCTAssertTrue(settings.shareAchievements)
        XCTAssertFalse(settings.sharePersonalRecords)
        XCTAssertTrue(settings.allowPublicSharing)
    }
    
    // MARK: - Privacy Level Tests
    
    func testPrivacyLevelForWorkoutType_UsesDefault() {
        // Given
        var settings = WorkoutPrivacySettings()
        settings.defaultPrivacy = .friendsOnly
        
        // When
        let privacy = settings.privacyLevel(for: .running)
        
        // Then
        XCTAssertEqual(privacy, .friendsOnly)
    }
    
    func testPrivacyLevelForWorkoutType_UsesOverride() {
        // Given
        var settings = WorkoutPrivacySettings()
        settings.defaultPrivacy = .friendsOnly
        settings.workoutTypeSettings[HKWorkoutActivityType.running.storageKey] = .public
        
        // When
        let privacy = settings.privacyLevel(for: .running)
        
        // Then
        XCTAssertEqual(privacy, .public)
    }
    
    func testSetPrivacyForWorkoutType() {
        // Given
        var settings = WorkoutPrivacySettings()
        
        // When
        settings.setPrivacyLevel(.public, for: .cycling)
        
        // Then
        XCTAssertEqual(settings.workoutTypeSettings[HKWorkoutActivityType.cycling.storageKey], .public)
        XCTAssertEqual(settings.privacyLevel(for: .cycling), .public)
    }
    
    // MARK: - Effective Privacy Tests
    
    func testEffectivePrivacy_RespectsPublicSharingRestriction() {
        // Given
        var settings = WorkoutPrivacySettings()
        settings.defaultPrivacy = .public
        settings.allowPublicSharing = false
        
        // When
        let effectivePrivacy = settings.effectivePrivacy(for: .running)
        
        // Then
        XCTAssertEqual(effectivePrivacy, .friendsOnly)
    }
    
    func testEffectivePrivacy_AllowsPublicWhenEnabled() {
        // Given
        var settings = WorkoutPrivacySettings()
        settings.defaultPrivacy = .public
        settings.allowPublicSharing = true
        
        // When
        let effectivePrivacy = settings.effectivePrivacy(for: .running)
        
        // Then
        XCTAssertEqual(effectivePrivacy, .public)
    }
    
    func testEffectivePrivacy_PrivateAlwaysPrivate() {
        // Given
        var settings = WorkoutPrivacySettings()
        settings.defaultPrivacy = .private
        settings.allowPublicSharing = true
        
        // When
        let effectivePrivacy = settings.effectivePrivacy(for: .running)
        
        // Then
        XCTAssertEqual(effectivePrivacy, .private)
    }
    
    func testEffectivePrivacy_FriendsOnlyUnaffectedByPublicRestriction() {
        // Given
        var settings = WorkoutPrivacySettings()
        settings.defaultPrivacy = .friendsOnly
        settings.allowPublicSharing = false
        
        // When
        let effectivePrivacy = settings.effectivePrivacy(for: .running)
        
        // Then
        XCTAssertEqual(effectivePrivacy, .friendsOnly)
    }
    
    // MARK: - COPPA Compliance Tests
    
    func testCOPPARestrictions_Under13() {
        // Given
        var settings = WorkoutPrivacySettings()
        
        // When - Simulate COPPA restrictions for user under 13
        settings.applyCOPPARestrictions()
        
        // Then
        XCTAssertFalse(settings.allowPublicSharing)
        XCTAssertEqual(settings.defaultPrivacy, .private)
    }
    
    // MARK: - Codable Tests
    
    func testCodable() throws {
        // Given
        var settings = WorkoutPrivacySettings()
        settings.defaultPrivacy = .friendsOnly
        settings.workoutTypeSettings = [
            HKWorkoutActivityType.running.storageKey: .public,
            HKWorkoutActivityType.yoga.storageKey: .private
        ]
        settings.allowDataSharing = true
        settings.shareAchievements = false
        settings.sharePersonalRecords = true
        settings.allowPublicSharing = false
        
        // When
        let encoded = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(WorkoutPrivacySettings.self, from: encoded)
        
        // Then
        XCTAssertEqual(decoded.defaultPrivacy, settings.defaultPrivacy)
        XCTAssertEqual(decoded.workoutTypeSettings, settings.workoutTypeSettings)
        XCTAssertEqual(decoded.allowDataSharing, settings.allowDataSharing)
        XCTAssertEqual(decoded.shareAchievements, settings.shareAchievements)
        XCTAssertEqual(decoded.sharePersonalRecords, settings.sharePersonalRecords)
        XCTAssertEqual(decoded.allowPublicSharing, settings.allowPublicSharing)
    }
    
    // MARK: - Equatable Tests
    
    func testEquatable_Equal() {
        // Given
        let settings1 = WorkoutPrivacySettings()
        let settings2 = WorkoutPrivacySettings()
        
        // Then
        XCTAssertEqual(settings1, settings2)
    }
    
    func testEquatable_NotEqual() {
        // Given
        let settings1 = WorkoutPrivacySettings()
        var settings2 = WorkoutPrivacySettings()
        settings2.defaultPrivacy = .public
        
        // Then
        XCTAssertNotEqual(settings1, settings2)
    }
    
    // MARK: - Edge Cases
    
    func testEmptyWorkoutTypeOverrides() {
        // Given
        var settings = WorkoutPrivacySettings()
        settings.defaultPrivacy = .public
        settings.workoutTypeSettings = [:] // Explicitly empty
        
        // When
        let privacy = settings.privacyLevel(for: .swimming)
        
        // Then
        XCTAssertEqual(privacy, .public) // Should use default
    }
    
    func testMultipleWorkoutTypeOverrides() {
        // Given
        var settings = WorkoutPrivacySettings()
        settings.defaultPrivacy = .friendsOnly
        
        // When - Set different privacy levels for different workouts
        settings.setPrivacyLevel(.public, for: .running)
        settings.setPrivacyLevel(.private, for: .yoga)
        settings.setPrivacyLevel(.friendsOnly, for: .cycling)
        
        // Then
        XCTAssertEqual(settings.privacyLevel(for: .running), .public)
        XCTAssertEqual(settings.privacyLevel(for: .yoga), .private)
        XCTAssertEqual(settings.privacyLevel(for: .cycling), .friendsOnly)
        XCTAssertEqual(settings.privacyLevel(for: .swimming), .friendsOnly) // Uses default
    }
}

// MARK: - Helper Extensions

extension WorkoutPrivacySettings {
    mutating func applyCOPPARestrictions() {
        allowPublicSharing = false
        if defaultPrivacy == .public {
            defaultPrivacy = .private
        }
    }
}