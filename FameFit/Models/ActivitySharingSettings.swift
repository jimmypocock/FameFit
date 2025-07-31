//
//  ActivitySharingSettings.swift
//  FameFit
//
//  User preferences for automatic activity sharing to social feed
//

import Foundation
import HealthKit
import CloudKit

struct ActivitySharingSettings: Codable, Equatable {
    // MARK: - Preset Options
    
    enum SharingPreset: String, CaseIterable {
        case minimal
        case balanced
        case social
        case custom
    }
    
    // MARK: - Global Settings
    
    /// Master toggle for all activity sharing
    var shareActivitiesToFeed: Bool = true
    
    // MARK: - Activity Type Settings
    
    /// Share workout completions
    var shareWorkouts: Bool = true
    
    /// Share achievement unlocks
    var shareAchievements: Bool = true
    
    /// Share level ups
    var shareLevelUps: Bool = true
    
    /// Share milestone achievements (100th workout, etc.)
    var shareMilestones: Bool = true
    
    /// Share streak updates
    var shareStreaks: Bool = true
    
    // MARK: - Workout-Specific Settings
    
    /// Workout types to share (stored as raw values for Codable)
    var workoutTypesToShareRaw: Set<Int> = []
    
    /// Minimum workout duration in seconds (default 5 minutes)
    var minimumWorkoutDuration: TimeInterval = 300
    
    /// Include workout details (calories, distance, etc.)
    var shareWorkoutDetails: Bool = true
    
    // MARK: - Privacy Levels
    
    /// Default privacy for workouts
    var workoutPrivacy: WorkoutPrivacy = .friendsOnly
    
    /// Default privacy for achievements
    var achievementPrivacy: WorkoutPrivacy = .public
    
    /// Default privacy for level ups
    var levelUpPrivacy: WorkoutPrivacy = .public
    
    /// Default privacy for milestones
    var milestonePrivacy: WorkoutPrivacy = .public
    
    /// Default privacy for streaks
    var streakPrivacy: WorkoutPrivacy = .friendsOnly
    
    // MARK: - Source Filtering
    
    /// Share from all sources or specific apps only
    var shareFromAllSources: Bool = true
    
    /// Specific source bundle IDs to share from (if not sharing from all)
    var allowedSources: Set<String> = []
    
    /// Sources to never share from (blacklist)
    var blockedSources: Set<String> = []
    
    // MARK: - Advanced Settings
    
    /// Delay before auto-sharing (allows for deletion/editing)
    var sharingDelay: TimeInterval = 300 // 5 minutes
    
    /// Share workouts retroactively when first enabling
    var shareHistoricalWorkouts: Bool = false
    
    /// Maximum age of workouts to share retroactively (in days)
    var historicalWorkoutMaxAge: Int = 7
    
    // MARK: - Initializers
    
    init() {
        // Initialize with common workout types by default
        let defaultWorkoutTypes: Set<HKWorkoutActivityType> = [
            .running,
            .walking,
            .cycling,
            .swimming,
            .functionalStrengthTraining,
            .traditionalStrengthTraining,
            .yoga,
            .coreTraining,
            .hiking,
            .rowing,
            .elliptical,
            .stairClimbing
        ]
        self.workoutTypesToShareRaw = Set(defaultWorkoutTypes.map { Int($0.rawValue) })
    }
    
    // MARK: - Computed Properties
    
    var workoutTypesToShare: Set<HKWorkoutActivityType> {
        get {
            Set(workoutTypesToShareRaw.compactMap { HKWorkoutActivityType(rawValue: UInt($0)) })
        }
        set {
            workoutTypesToShareRaw = Set(newValue.map { Int($0.rawValue) })
        }
    }
    
    // MARK: - Methods
    
    /// Check if a specific workout should be shared
    func shouldShareWorkout(_ workout: HKWorkout) -> Bool {
        guard shareActivitiesToFeed && shareWorkouts else { return false }
        
        // Check duration
        guard workout.duration >= minimumWorkoutDuration else { return false }
        
        // Check workout type
        guard workoutTypesToShare.contains(workout.workoutActivityType) else { return false }
        
        // Check source
        let sourceBundleId = workout.sourceRevision.source.bundleIdentifier
        if !shareFromAllSources && !allowedSources.contains(sourceBundleId) {
            return false
        }
        if blockedSources.contains(sourceBundleId) {
            return false
        }
        
        return true
    }
    
    /// Get privacy level for a specific activity type
    func privacyLevel(for activityType: String) -> WorkoutPrivacy {
        switch activityType {
        case "workout":
            return workoutPrivacy
        case "achievement":
            return achievementPrivacy
        case "level_up":
            return levelUpPrivacy
        case "milestone":
            return milestonePrivacy
        case "streak":
            return streakPrivacy
        default:
            return .friendsOnly
        }
    }
}

// MARK: - CloudKit Support

extension ActivitySharingSettings {
    init(from record: CKRecord) {
        self.shareActivitiesToFeed = record["shareActivitiesToFeed"] as? Bool ?? true
        self.shareWorkouts = record["shareWorkouts"] as? Bool ?? true
        self.shareAchievements = record["shareAchievements"] as? Bool ?? true
        self.shareLevelUps = record["shareLevelUps"] as? Bool ?? true
        self.shareMilestones = record["shareMilestones"] as? Bool ?? true
        self.shareStreaks = record["shareStreaks"] as? Bool ?? true
        
        if let workoutTypes = record["workoutTypesToShare"] as? [Int] {
            self.workoutTypesToShareRaw = Set(workoutTypes)
        }
        
        self.minimumWorkoutDuration = record["minimumWorkoutDuration"] as? Double ?? 300
        self.shareWorkoutDetails = record["shareWorkoutDetails"] as? Bool ?? true
        
        self.workoutPrivacy = WorkoutPrivacy(rawValue: record["workoutPrivacy"] as? String ?? "") ?? .friendsOnly
        self.achievementPrivacy = WorkoutPrivacy(rawValue: record["achievementPrivacy"] as? String ?? "") ?? .public
        self.levelUpPrivacy = WorkoutPrivacy(rawValue: record["levelUpPrivacy"] as? String ?? "") ?? .public
        self.milestonePrivacy = WorkoutPrivacy(rawValue: record["milestonePrivacy"] as? String ?? "") ?? .public
        self.streakPrivacy = WorkoutPrivacy(rawValue: record["streakPrivacy"] as? String ?? "") ?? .friendsOnly
        
        self.shareFromAllSources = record["shareFromAllSources"] as? Bool ?? true
        self.allowedSources = Set(record["allowedSources"] as? [String] ?? [])
        self.blockedSources = Set(record["blockedSources"] as? [String] ?? [])
        
        self.sharingDelay = record["sharingDelay"] as? Double ?? 300
        self.shareHistoricalWorkouts = record["shareHistoricalWorkouts"] as? Bool ?? false
        self.historicalWorkoutMaxAge = record["historicalWorkoutMaxAge"] as? Int ?? 7
    }
    
    func toCKRecord() -> CKRecord {
        let record = CKRecord(recordType: "ActivitySharingSettings")
        
        // Convert Bool to Int64 for CloudKit
        record["shareActivitiesToFeed"] = shareActivitiesToFeed ? 1 : 0
        record["shareWorkouts"] = shareWorkouts ? 1 : 0
        record["shareAchievements"] = shareAchievements ? 1 : 0
        record["shareLevelUps"] = shareLevelUps ? 1 : 0
        record["shareMilestones"] = shareMilestones ? 1 : 0
        record["shareStreaks"] = shareStreaks ? 1 : 0
        
        record["workoutTypesToShare"] = Array(workoutTypesToShareRaw)
        record["minimumWorkoutDuration"] = minimumWorkoutDuration
        record["shareWorkoutDetails"] = shareWorkoutDetails ? 1 : 0
        
        record["workoutPrivacy"] = workoutPrivacy.rawValue
        record["achievementPrivacy"] = achievementPrivacy.rawValue
        record["levelUpPrivacy"] = levelUpPrivacy.rawValue
        record["milestonePrivacy"] = milestonePrivacy.rawValue
        record["streakPrivacy"] = streakPrivacy.rawValue
        
        record["shareFromAllSources"] = shareFromAllSources ? 1 : 0
        record["allowedSources"] = Array(allowedSources)
        record["blockedSources"] = Array(blockedSources)
        
        record["sharingDelay"] = sharingDelay
        record["shareHistoricalWorkouts"] = shareHistoricalWorkouts ? 1 : 0
        record["historicalWorkoutMaxAge"] = Int64(historicalWorkoutMaxAge)
        
        return record
    }
}

// MARK: - Default Presets

extension ActivitySharingSettings {
    /// Conservative preset - share less, more private
    static var conservative: ActivitySharingSettings {
        var settings = ActivitySharingSettings()
        settings.shareWorkouts = true
        settings.shareAchievements = false
        settings.shareLevelUps = false
        settings.workoutPrivacy = .private
        settings.minimumWorkoutDuration = 600 // 10 minutes
        settings.shareWorkoutDetails = false
        return settings
    }
    
    /// Balanced preset - reasonable defaults
    static var balanced: ActivitySharingSettings {
        ActivitySharingSettings() // Use defaults
    }
    
    /// Social preset - share more, more public
    static var social: ActivitySharingSettings {
        var settings = ActivitySharingSettings()
        settings.shareWorkouts = true
        settings.shareAchievements = true
        settings.shareLevelUps = true
        settings.shareMilestones = true
        settings.shareStreaks = true
        settings.workoutPrivacy = .public
        settings.achievementPrivacy = .public
        settings.minimumWorkoutDuration = 180 // 3 minutes
        settings.shareWorkoutDetails = true
        return settings
    }
    
    // MARK: - CloudKit Conversion
    
    /// Create ActivitySharingSettings from CloudKit record
    static func fromCKRecord(_ record: CKRecord) -> ActivitySharingSettings {
        var settings = ActivitySharingSettings()
        
        // Core sharing settings - CloudKit stores as Int64 (1/0)
        settings.shareActivitiesToFeed = (record["shareActivitiesToFeed"] as? Int64 ?? 1) == 1
        settings.shareWorkouts = (record["shareWorkouts"] as? Int64 ?? 1) == 1
        settings.shareAchievements = (record["shareAchievements"] as? Int64 ?? 1) == 1
        settings.shareLevelUps = (record["shareLevelUps"] as? Int64 ?? 1) == 1
        settings.shareMilestones = (record["shareMilestones"] as? Int64 ?? 1) == 1
        settings.shareStreaks = (record["shareStreaks"] as? Int64 ?? 1) == 1
        
        // Workout type filtering
        if let workoutTypeInts = record["workoutTypesToShare"] as? [Int] {
            settings.workoutTypesToShareRaw = Set(workoutTypeInts)
        }
        
        // Sharing options
        settings.minimumWorkoutDuration = record["minimumWorkoutDuration"] as? TimeInterval ?? 300
        settings.shareWorkoutDetails = (record["shareWorkoutDetails"] as? Int64 ?? 1) == 1
        
        // Privacy settings
        if let privacyString = record["workoutPrivacy"] as? String,
           let privacy = WorkoutPrivacy(rawValue: privacyString) {
            settings.workoutPrivacy = privacy
        }
        if let privacyString = record["achievementPrivacy"] as? String,
           let privacy = WorkoutPrivacy(rawValue: privacyString) {
            settings.achievementPrivacy = privacy
        }
        if let privacyString = record["levelUpPrivacy"] as? String,
           let privacy = WorkoutPrivacy(rawValue: privacyString) {
            settings.levelUpPrivacy = privacy
        }
        if let privacyString = record["milestonePrivacy"] as? String,
           let privacy = WorkoutPrivacy(rawValue: privacyString) {
            settings.milestonePrivacy = privacy
        }
        if let privacyString = record["streakPrivacy"] as? String,
           let privacy = WorkoutPrivacy(rawValue: privacyString) {
            settings.streakPrivacy = privacy
        }
        
        // Source filtering
        settings.shareFromAllSources = (record["shareFromAllSources"] as? Int64 ?? 1) == 1
        if let allowedSources = record["allowedSources"] as? [String] {
            settings.allowedSources = Set(allowedSources)
        }
        if let blockedSources = record["blockedSources"] as? [String] {
            settings.blockedSources = Set(blockedSources)
        }
        
        // Timing and historical
        settings.sharingDelay = record["sharingDelay"] as? TimeInterval ?? 0
        settings.shareHistoricalWorkouts = (record["shareHistoricalWorkouts"] as? Int64 ?? 0) == 1
        if let maxAge = record["historicalWorkoutMaxAge"] as? Int64 {
            settings.historicalWorkoutMaxAge = Int(maxAge)
        }
        
        return settings
    }
}