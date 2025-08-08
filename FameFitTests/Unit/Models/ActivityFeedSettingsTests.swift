//
//  ActivityFeedSettingsTests.swift
//  FameFitTests
//
//  Unit tests for ActivityFeedSettings model
//

@testable import FameFit
import HealthKit
import XCTest

final class ActivityFeedSettingsTests: XCTestCase {
    // MARK: - Default Settings Tests
    
    func testDefaultSettings() {
        // When
        let settings = ActivityFeedSettings()
        
        // Then
        XCTAssertTrue(settings.shareActivitiesToFeed)
        XCTAssertTrue(settings.shareWorkouts)
        XCTAssertTrue(settings.shareAchievements)
        XCTAssertTrue(settings.shareLevelUps)
        XCTAssertTrue(settings.shareMilestones)
        XCTAssertTrue(settings.shareStreaks)
        XCTAssertEqual(settings.minimumWorkoutDuration, 300) // 5 minutes
        XCTAssertTrue(settings.shareWorkoutDetails)
        XCTAssertEqual(settings.workoutPrivacy, .friendsOnly)
        XCTAssertEqual(settings.achievementPrivacy, .public)
        XCTAssertEqual(settings.levelUpPrivacy, .public)
        XCTAssertEqual(settings.milestonePrivacy, .public)
        XCTAssertEqual(settings.streakPrivacy, .friendsOnly)
        XCTAssertTrue(settings.shareFromAllSources)
        XCTAssertTrue(settings.allowedSources.isEmpty)
        XCTAssertTrue(settings.blockedSources.isEmpty)
        XCTAssertEqual(settings.sharingDelay, 300) // 5 minutes
        XCTAssertFalse(settings.shareHistoricalWorkouts)
        XCTAssertEqual(settings.historicalWorkoutMaxAge, 7)
    }
    
    func testDefaultWorkoutTypes() {
        // When
        let settings = ActivityFeedSettings()
        
        // Then
        let workoutTypes = settings.workoutTypesToShare
        XCTAssertTrue(workoutTypes.contains(.running))
        XCTAssertTrue(workoutTypes.contains(.walking))
        XCTAssertTrue(workoutTypes.contains(.cycling))
        XCTAssertTrue(workoutTypes.contains(.swimming))
        XCTAssertTrue(workoutTypes.contains(.functionalStrengthTraining))
        XCTAssertTrue(workoutTypes.contains(.traditionalStrengthTraining))
        XCTAssertTrue(workoutTypes.contains(.yoga))
        XCTAssertTrue(workoutTypes.contains(.coreTraining))
        XCTAssertTrue(workoutTypes.contains(.hiking))
        XCTAssertTrue(workoutTypes.contains(.rowing))
        XCTAssertTrue(workoutTypes.contains(.elliptical))
        XCTAssertTrue(workoutTypes.contains(.stairClimbing))
    }
    
    // MARK: - Preset Tests
    
    func testConservativePreset() {
        // When
        let settings = ActivityFeedSettings.conservative
        
        // Then
        XCTAssertTrue(settings.shareWorkouts)
        XCTAssertFalse(settings.shareAchievements)
        XCTAssertFalse(settings.shareLevelUps)
        XCTAssertEqual(settings.workoutPrivacy, .private)
        XCTAssertEqual(settings.minimumWorkoutDuration, 600) // 10 minutes
        XCTAssertFalse(settings.shareWorkoutDetails)
    }
    
    func testBalancedPreset() {
        // When
        let settings = ActivityFeedSettings.balanced
        
        // Then - Should use defaults
        XCTAssertTrue(settings.shareWorkouts)
        XCTAssertTrue(settings.shareAchievements)
        XCTAssertTrue(settings.shareLevelUps)
        XCTAssertEqual(settings.workoutPrivacy, .friendsOnly)
        XCTAssertEqual(settings.minimumWorkoutDuration, 300)
        XCTAssertTrue(settings.shareWorkoutDetails)
    }
    
    func testSocialPreset() {
        // When
        let settings = ActivityFeedSettings.social
        
        // Then
        XCTAssertTrue(settings.shareWorkouts)
        XCTAssertTrue(settings.shareAchievements)
        XCTAssertTrue(settings.shareLevelUps)
        XCTAssertTrue(settings.shareMilestones)
        XCTAssertTrue(settings.shareStreaks)
        XCTAssertEqual(settings.workoutPrivacy, .public)
        XCTAssertEqual(settings.achievementPrivacy, .public)
        XCTAssertEqual(settings.minimumWorkoutDuration, 180) // 3 minutes
        XCTAssertTrue(settings.shareWorkoutDetails)
    }
    
    // MARK: - Workout Sharing Logic Tests
    
    func testWorkoutSharingLogic_MasterToggleOff() {
        // Given
        var settings = ActivityFeedSettings()
        settings.shareActivitiesToFeed = false
        
        // Then
        XCTAssertFalse(settings.shareActivitiesToFeed)
        // With master toggle off, no workouts should be shared
    }
    
    func testWorkoutSharingLogic_WorkoutsDisabled() {
        // Given
        var settings = ActivityFeedSettings()
        settings.shareActivitiesToFeed = true
        settings.shareWorkouts = false
        
        // Then
        XCTAssertTrue(settings.shareActivitiesToFeed)
        XCTAssertFalse(settings.shareWorkouts)
    }
    
    func testWorkoutSharingLogic_DurationFilter() {
        // Given
        var settings = ActivityFeedSettings()
        
        // When
        settings.minimumWorkoutDuration = 600 // 10 minutes
        
        // Then
        XCTAssertEqual(settings.minimumWorkoutDuration, 600)
    }
    
    func testWorkoutSharingLogic_WorkoutTypeFilter() {
        // Given
        var settings = ActivityFeedSettings()
        
        // When
        settings.workoutTypesToShare = [.running, .cycling]
        
        // Then
        XCTAssertEqual(settings.workoutTypesToShare.count, 2)
        XCTAssertTrue(settings.workoutTypesToShare.contains(.running))
        XCTAssertTrue(settings.workoutTypesToShare.contains(.cycling))
    }
    
    func testWorkoutSharingLogic_SourceFilter() {
        // Given
        var settings = ActivityFeedSettings()
        
        // When
        settings.shareFromAllSources = false
        settings.allowedSources = ["com.apple.health", "com.strava.app"]
        
        // Then
        XCTAssertFalse(settings.shareFromAllSources)
        XCTAssertEqual(settings.allowedSources.count, 2)
        XCTAssertTrue(settings.allowedSources.contains("com.apple.health"))
    }
    
    func testWorkoutSharingLogic_BlockedSources() {
        // Given
        var settings = ActivityFeedSettings()
        
        // When
        settings.blockedSources = ["com.blocked.app"]
        
        // Then
        XCTAssertEqual(settings.blockedSources.count, 1)
        XCTAssertTrue(settings.blockedSources.contains("com.blocked.app"))
    }
    
    // MARK: - Privacy Level Tests
    
    func testPrivacyLevelForActivity() {
        // Given
        var settings = ActivityFeedSettings()
        settings.workoutPrivacy = .private
        settings.achievementPrivacy = .public
        settings.levelUpPrivacy = .friendsOnly
        settings.milestonePrivacy = .public
        settings.streakPrivacy = .private
        
        // Then
        XCTAssertEqual(settings.privacyLevel(for: "workout"), .private)
        XCTAssertEqual(settings.privacyLevel(for: "achievement"), .public)
        XCTAssertEqual(settings.privacyLevel(for: "level_up"), .friendsOnly)
        XCTAssertEqual(settings.privacyLevel(for: "milestone"), .public)
        XCTAssertEqual(settings.privacyLevel(for: "streak"), .private)
        XCTAssertEqual(settings.privacyLevel(for: "unknown"), .friendsOnly) // Default
    }
    
    // MARK: - Codable Tests
    
    func testCodable() throws {
        // Given
        var settings = ActivityFeedSettings()
        settings.shareWorkouts = false
        settings.minimumWorkoutDuration = 900
        settings.workoutPrivacy = .public
        settings.workoutTypesToShare = [.running, .cycling]
        settings.blockedSources = ["com.test.app"]
        
        // When
        let encoded = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(ActivityFeedSettings.self, from: encoded)
        
        // Then
        XCTAssertEqual(decoded.shareWorkouts, false)
        XCTAssertEqual(decoded.minimumWorkoutDuration, 900)
        XCTAssertEqual(decoded.workoutPrivacy, .public)
        XCTAssertEqual(decoded.workoutTypesToShare.count, 2)
        XCTAssertTrue(decoded.workoutTypesToShare.contains(.running))
        XCTAssertTrue(decoded.workoutTypesToShare.contains(.cycling))
        XCTAssertEqual(decoded.blockedSources, ["com.test.app"])
    }
    
    // MARK: - Equatable Tests
    
    func testEquatable() {
        // Given
        let settings1 = ActivityFeedSettings()
        var settings2 = ActivityFeedSettings()
        
        // Then
        XCTAssertEqual(settings1, settings2)
        
        // When
        settings2.shareWorkouts = false
        
        // Then
        XCTAssertNotEqual(settings1, settings2)
    }
}
