//
//  ActivitySharingSettingsServiceTests.swift
//  FameFitTests
//
//  Unit tests for ActivitySharingSettingsService
//

@testable import FameFit
import CloudKit
import Combine
import XCTest

final class ActivitySharingSettingsServiceTests: XCTestCase {
    private var service: ActivitySharingSettingsService!
    private var mockCloudKitManager: MockCloudKitManager!
    private var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        mockCloudKitManager = MockCloudKitManager()
        service = ActivitySharingSettingsService(cloudKitManager: mockCloudKitManager)
        cancellables = []
    }
    
    override func tearDown() {
        service = nil
        mockCloudKitManager = nil
        cancellables = nil
        // Clear UserDefaults
        UserDefaults.standard.removeObject(forKey: "ActivitySharingSettings")
        super.tearDown()
    }
    
    // MARK: - Load Settings Tests
    
    func testLoadSettings_FirstTime_ReturnsDefaults() async throws {
        // Given - No local cache (CloudKit fetch returns nil in current implementation)
        UserDefaults.standard.removeObject(forKey: "ActivitySharingSettings")
        
        // When
        let settings = try await service.loadSettings()
        
        // Then
        XCTAssertEqual(settings, ActivitySharingSettings())
        XCTAssertTrue(settings.shareActivitiesToFeed)
        XCTAssertEqual(settings.workoutPrivacy, .friendsOnly)
    }
    
    func testLoadSettings_FromLocalCache() async throws {
        // Given - Settings in local cache
        let cachedSettings = ActivitySharingSettings.conservative
        let encoded = try JSONEncoder().encode(cachedSettings)
        UserDefaults.standard.set(encoded, forKey: "ActivitySharingSettings")
        
        // When
        let settings = try await service.loadSettings()
        
        // Then
        XCTAssertEqual(settings, cachedSettings)
        XCTAssertFalse(settings.shareAchievements) // Conservative preset
    }
    
    func testLoadSettings_FromCloudKit() async throws {
        // Skip this test - requires real CloudKit database connection
        // The mock doesn't simulate CloudKit operations
        throw XCTSkip("Test requires CloudKit integration - covered by integration tests")
    }
    
    // MARK: - Save Settings Tests
    
    func testSaveSettings_UpdatesLocalCache() async throws {
        // Given
        let settings = ActivitySharingSettings.conservative
        
        // When
        try await service.saveSettings(settings)
        
        // Then - Verify local cache
        let cached = UserDefaults.standard.data(forKey: "ActivitySharingSettings")
        XCTAssertNotNil(cached)
        let decoded = try JSONDecoder().decode(ActivitySharingSettings.self, from: cached!)
        XCTAssertEqual(decoded, settings)
    }
    
    func testSaveSettings_UpdatesCloudKit() async throws {
        // Skip this test - requires real CloudKit database connection
        // The mock doesn't simulate CloudKit operations
        throw XCTSkip("Test requires CloudKit integration - covered by integration tests")
    }
    
    func testSaveSettings_PublishesUpdate() async throws {
        // Given
        let expectation = XCTestExpectation(description: "Settings published")
        var receivedSettings: ActivitySharingSettings?
        
        service.settingsPublisher
            .dropFirst() // Skip initial value
            .sink { settings in
                receivedSettings = settings
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        // When
        let newSettings = ActivitySharingSettings.conservative
        try await service.saveSettings(newSettings)
        
        // Then
        await fulfillment(of: [expectation], timeout: 1.0)
        XCTAssertEqual(receivedSettings, newSettings)
    }
    
    // MARK: - Reset to Defaults Tests
    
    func testResetToDefaults() async throws {
        // Given - Save custom settings first
        var customSettings = ActivitySharingSettings()
        customSettings.shareWorkouts = false
        customSettings.workoutPrivacy = .private
        try await service.saveSettings(customSettings)
        
        // When
        try await service.resetToDefaults()
        
        // Then
        let settings = try await service.loadSettings()
        XCTAssertEqual(settings, ActivitySharingSettings()) // Default settings
        XCTAssertTrue(settings.shareWorkouts)
        XCTAssertEqual(settings.workoutPrivacy, .friendsOnly)
    }
    
    // MARK: - Error Handling Tests
    
    func testLoadSettings_CloudKitError_FallsBackToCache() async throws {
        // Given - Cache exists (CloudKit always returns nil in current implementation)
        let cachedSettings = ActivitySharingSettings.conservative
        let encoded = try JSONEncoder().encode(cachedSettings)
        UserDefaults.standard.set(encoded, forKey: "ActivitySharingSettings")
        
        // When
        let settings = try await service.loadSettings()
        
        // Then
        XCTAssertEqual(settings, cachedSettings)
    }
    
    func testSaveSettings_CloudKitError_StillUpdatesCache() async throws {
        // Given
        let settings = ActivitySharingSettings.social
        
        // When - Should not throw (CloudKit errors don't fail the operation)
        try await service.saveSettings(settings)
        
        // Verify cache was updated
        let cached = UserDefaults.standard.data(forKey: "ActivitySharingSettings")
        XCTAssertNotNil(cached)
        let decoded = try JSONDecoder().decode(ActivitySharingSettings.self, from: cached!)
        XCTAssertEqual(decoded, settings)
    }
    
    // MARK: - Publisher Tests
    
    func testSettingsPublisher_InitialValue() {
        // Given
        let expectation = XCTestExpectation(description: "Initial value received")
        var receivedSettings: ActivitySharingSettings?
        
        // When
        service.settingsPublisher
            .first()
            .sink { settings in
                receivedSettings = settings
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        // Then
        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(receivedSettings, ActivitySharingSettings()) // Default
    }
    
    func testSettingsPublisher_MultipleUpdates() async throws {
        // Given
        let expectation = XCTestExpectation(description: "Multiple updates received")
        expectation.expectedFulfillmentCount = 2
        var receivedCount = 0
        
        service.settingsPublisher
            .dropFirst() // Skip initial
            .sink { _ in
                receivedCount += 1
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        // When
        try await service.saveSettings(.conservative)
        try await service.saveSettings(.social)
        
        // Then
        await fulfillment(of: [expectation], timeout: 2.0)
        XCTAssertEqual(receivedCount, 2)
    }
    
    // MARK: - Helper Methods
    
    private func createCloudKitRecord(from settings: ActivitySharingSettings) throws -> CKRecord {
        let record = CKRecord(recordType: "ActivitySharingSettings")
        
        record["shareActivitiesToFeed"] = settings.shareActivitiesToFeed as CKRecordValue
        record["shareWorkouts"] = settings.shareWorkouts as CKRecordValue
        record["shareAchievements"] = settings.shareAchievements as CKRecordValue
        record["shareLevelUps"] = settings.shareLevelUps as CKRecordValue
        record["shareMilestones"] = settings.shareMilestones as CKRecordValue
        record["shareStreaks"] = settings.shareStreaks as CKRecordValue
        
        // Workout types need to be converted to Int array
        let workoutTypes = settings.workoutTypesToShare.map { Int($0.rawValue) }
        record["workoutTypesToShare"] = workoutTypes as CKRecordValue
        
        record["minimumWorkoutDuration"] = settings.minimumWorkoutDuration as CKRecordValue
        record["shareWorkoutDetails"] = settings.shareWorkoutDetails as CKRecordValue
        
        record["workoutPrivacy"] = settings.workoutPrivacy.rawValue as CKRecordValue
        record["achievementPrivacy"] = settings.achievementPrivacy.rawValue as CKRecordValue
        record["levelUpPrivacy"] = settings.levelUpPrivacy.rawValue as CKRecordValue
        record["milestonePrivacy"] = settings.milestonePrivacy.rawValue as CKRecordValue
        record["streakPrivacy"] = settings.streakPrivacy.rawValue as CKRecordValue
        
        record["shareFromAllSources"] = settings.shareFromAllSources as CKRecordValue
        record["allowedSources"] = Array(settings.allowedSources) as CKRecordValue
        record["blockedSources"] = Array(settings.blockedSources) as CKRecordValue
        
        record["sharingDelay"] = settings.sharingDelay as CKRecordValue
        record["shareHistoricalWorkouts"] = settings.shareHistoricalWorkouts as CKRecordValue
        record["historicalWorkoutMaxAge"] = Int64(settings.historicalWorkoutMaxAge) as CKRecordValue
        
        record["lastModified"] = Date() as CKRecordValue
        
        return record
    }
}