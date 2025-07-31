//
//  ActivitySharingSettingsService.swift
//  FameFit
//
//  Service for managing user's activity sharing preferences
//

import Foundation
import CloudKit
import Combine

// MARK: - Protocol

protocol ActivitySharingSettingsServicing: AnyObject {
    func loadSettings() async throws -> ActivitySharingSettings
    func saveSettings(_ settings: ActivitySharingSettings) async throws
    func resetToDefaults() async throws
    
    // Publisher for settings changes
    var settingsPublisher: AnyPublisher<ActivitySharingSettings, Never> { get }
}

// MARK: - Implementation

final class ActivitySharingSettingsService: ActivitySharingSettingsServicing {
    private let cloudKitManager: any CloudKitManaging
    private let privateDatabase: CKDatabase
    private let userDefaults = UserDefaults.standard
    private let settingsKey = "ActivitySharingSettings"
    private let recordType = "ActivitySharingSettings"
    
    private let settingsSubject = CurrentValueSubject<ActivitySharingSettings, Never>(ActivitySharingSettings())
    
    var settingsPublisher: AnyPublisher<ActivitySharingSettings, Never> {
        settingsSubject.eraseToAnyPublisher()
    }
    
    init(cloudKitManager: any CloudKitManaging) {
        self.cloudKitManager = cloudKitManager
        let container = CKContainer(identifier: "iCloud.com.jimmypocock.FameFit")
        self.privateDatabase = container.privateCloudDatabase
        
        // Load cached settings on init
        if let cachedSettings = loadCachedSettings() {
            settingsSubject.send(cachedSettings)
        }
    }
    
    // MARK: - Public Methods
    
    func loadSettings() async throws -> ActivitySharingSettings {
        // First check if we have settings in CloudKit
        do {
            if let settings = try await fetchFromCloudKit() {
                cacheSettings(settings)
                settingsSubject.send(settings)
                return settings
            }
        } catch {
            print("Failed to fetch settings from CloudKit: \(error)")
        }
        
        // Fall back to cached settings
        if let cachedSettings = loadCachedSettings() {
            return cachedSettings
        }
        
        // Return defaults for new users
        let defaultSettings = ActivitySharingSettings()
        cacheSettings(defaultSettings)
        settingsSubject.send(defaultSettings)
        return defaultSettings
    }
    
    func saveSettings(_ settings: ActivitySharingSettings) async throws {
        // Save to CloudKit
        try await saveToCloudKit(settings)
        
        // Cache locally
        cacheSettings(settings)
        
        // Notify subscribers
        settingsSubject.send(settings)
    }
    
    func resetToDefaults() async throws {
        let defaultSettings = ActivitySharingSettings()
        try await saveSettings(defaultSettings)
    }
    
    // MARK: - Private Methods
    
    private func fetchFromCloudKit() async throws -> ActivitySharingSettings? {
        guard let userId = cloudKitManager.currentUserID else {
            throw NSError(domain: "ActivitySharingSettings", code: 1, userInfo: [NSLocalizedDescriptionKey: "No user ID available"])
        }
        
        // Create predicate to find settings for current user
        let predicate = NSPredicate(format: "userID == %@", userId)
        let query = CKQuery(recordType: recordType, predicate: predicate)
        
        do {
            // Perform query
            let (matchResults, _) = try await privateDatabase.records(matching: query, inZoneWith: nil)
            let records = matchResults.compactMap { _, result in
                try? result.get()
            }
            
            // Return first record if found
            if let record = records.first {
                return ActivitySharingSettings.fromCKRecord(record)
            }
            
            return nil
        } catch {
            print("Failed to fetch settings from CloudKit: \(error)")
            throw error
        }
    }
    
    private func saveToCloudKit(_ settings: ActivitySharingSettings) async throws {
        guard let userId = cloudKitManager.currentUserID else {
            throw NSError(domain: "ActivitySharingSettings", code: 1, userInfo: [NSLocalizedDescriptionKey: "No user ID available"])
        }
        
        // First, try to fetch existing record to update it
        let existingRecord: CKRecord?
        do {
            existingRecord = try await fetchExistingRecord(for: userId)
        } catch {
            // If fetch fails, we'll create a new record
            existingRecord = nil
        }
        
        // Use existing record or create new one
        let record: CKRecord
        if let existing = existingRecord {
            record = existing
            updateRecord(record, with: settings)
        } else {
            record = settings.toCKRecord()
            record["userID"] = userId
        }
        
        // Save to CloudKit
        do {
            _ = try await privateDatabase.save(record)
            print("Successfully saved activity sharing settings to CloudKit")
        } catch {
            print("Failed to save settings to CloudKit: \(error)")
            // Don't throw - settings are still cached locally
        }
    }
    
    private func fetchExistingRecord(for userId: String) async throws -> CKRecord? {
        let predicate = NSPredicate(format: "userID == %@", userId)
        let query = CKQuery(recordType: recordType, predicate: predicate)
        
        let (matchResults, _) = try await privateDatabase.records(matching: query, inZoneWith: nil)
        let records = matchResults.compactMap { _, result in
            try? result.get()
        }
        return records.first
    }
    
    private func updateRecord(_ record: CKRecord, with settings: ActivitySharingSettings) {
        // Update all fields from settings
        record["shareActivitiesToFeed"] = settings.shareActivitiesToFeed ? 1 : 0
        record["shareWorkouts"] = settings.shareWorkouts ? 1 : 0
        record["shareAchievements"] = settings.shareAchievements ? 1 : 0
        record["shareLevelUps"] = settings.shareLevelUps ? 1 : 0
        record["shareMilestones"] = settings.shareMilestones ? 1 : 0
        record["shareStreaks"] = settings.shareStreaks ? 1 : 0
        
        record["workoutTypesToShare"] = Array(settings.workoutTypesToShareRaw)
        record["minimumWorkoutDuration"] = settings.minimumWorkoutDuration
        record["shareWorkoutDetails"] = settings.shareWorkoutDetails ? 1 : 0
        
        record["workoutPrivacy"] = settings.workoutPrivacy.rawValue
        record["achievementPrivacy"] = settings.achievementPrivacy.rawValue
        record["levelUpPrivacy"] = settings.levelUpPrivacy.rawValue
        record["milestonePrivacy"] = settings.milestonePrivacy.rawValue
        record["streakPrivacy"] = settings.streakPrivacy.rawValue
        
        record["shareFromAllSources"] = settings.shareFromAllSources ? 1 : 0
        record["allowedSources"] = Array(settings.allowedSources)
        record["blockedSources"] = Array(settings.blockedSources)
        
        record["sharingDelay"] = settings.sharingDelay
        record["shareHistoricalWorkouts"] = settings.shareHistoricalWorkouts ? 1 : 0
        record["historicalWorkoutMaxAge"] = Int64(settings.historicalWorkoutMaxAge)
    }
    
    private func loadCachedSettings() -> ActivitySharingSettings? {
        guard let data = userDefaults.data(forKey: settingsKey),
              let settings = try? JSONDecoder().decode(ActivitySharingSettings.self, from: data) else {
            return nil
        }
        return settings
    }
    
    private func cacheSettings(_ settings: ActivitySharingSettings) {
        if let data = try? JSONEncoder().encode(settings) {
            userDefaults.set(data, forKey: settingsKey)
        }
    }
}

// MARK: - Mock Implementation

final class MockActivitySharingSettingsService: ActivitySharingSettingsServicing {
    private let settingsSubject = CurrentValueSubject<ActivitySharingSettings, Never>(ActivitySharingSettings())
    private var currentSettings = ActivitySharingSettings()
    
    var settingsPublisher: AnyPublisher<ActivitySharingSettings, Never> {
        settingsSubject.eraseToAnyPublisher()
    }
    
    var shouldFail = false
    var error: Error = NSError(domain: "MockError", code: 0)
    
    func loadSettings() async throws -> ActivitySharingSettings {
        if shouldFail {
            throw error
        }
        return currentSettings
    }
    
    func saveSettings(_ settings: ActivitySharingSettings) async throws {
        if shouldFail {
            throw error
        }
        currentSettings = settings
        settingsSubject.send(settings)
    }
    
    func resetToDefaults() async throws {
        if shouldFail {
            throw error
        }
        currentSettings = ActivitySharingSettings()
        settingsSubject.send(currentSettings)
    }
}