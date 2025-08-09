//
//  ActivityFeedService.swift
//  FameFit
//
//  Service for managing activity feed items from workout completions
//

import CloudKit
import Combine
import Foundation
import HealthKit

// MARK: - Activity Feed Service Protocol

protocol ActivityFeedServicing {
    func postWorkoutActivity(
        workout: Workout,
        privacy: WorkoutPrivacy,
        includeDetails: Bool
    ) async throws

    func postAchievementActivity(
        achievementName: String,
        xpEarned: Int,
        privacy: WorkoutPrivacy
    ) async throws

    func postLevelUpActivity(
        newLevel: Int,
        newTitle: String,
        privacy: WorkoutPrivacy
    ) async throws

    func fetchFeed(for userIDs: Set<String>, since: Date?, limit: Int) async throws -> [ActivityFeedRecord]
    func deleteActivity(_ activityID: String) async throws
    func updateActivityPrivacy(_ activityID: String, newPrivacy: WorkoutPrivacy) async throws

    // Publishers for real-time updates
    var newActivityPublisher: AnyPublisher<ActivityFeedRecord, Never> { get }
    var privacyUpdatePublisher: AnyPublisher<(String, WorkoutPrivacy), Never> { get }
}

// MARK: - Activity Feed Service Implementation

final class ActivityFeedService: ActivityFeedServicing {
    private let cloudKitManager: any CloudKitManaging
    private var privacySettings: WorkoutPrivacySettings
    private let userProfileService: UserProfileServicing?
    private var currentUsername: String = "Unknown"

    // Publishers
    private let newActivitySubject = PassthroughSubject<ActivityFeedRecord, Never>()
    private let privacyUpdateSubject = PassthroughSubject<(String, WorkoutPrivacy), Never>()

    var newActivityPublisher: AnyPublisher<ActivityFeedRecord, Never> {
        newActivitySubject.eraseToAnyPublisher()
    }

    var privacyUpdatePublisher: AnyPublisher<(String, WorkoutPrivacy), Never> {
        privacyUpdateSubject.eraseToAnyPublisher()
    }

    init(cloudKitManager: any CloudKitManaging, privacySettings: WorkoutPrivacySettings, userProfileService: UserProfileServicing? = nil) {
        self.cloudKitManager = cloudKitManager
        self.privacySettings = privacySettings
        self.userProfileService = userProfileService
        
        // Load current username on init
        Task {
            await loadCurrentUsername()
        }
    }
    
    private func loadCurrentUsername() async {
        guard let userID = cloudKitManager.currentUserID,
              let profileService = userProfileService else { return }
        
        do {
            let profile = try await profileService.fetchProfile(userID: userID)
            currentUsername = profile.username
            FameFitLogger.info("📝 Loaded current username: \(currentUsername)", category: FameFitLogger.social)
        } catch {
            FameFitLogger.warning("⚠️ Could not load username for activity feed: \(error)", category: FameFitLogger.social)
        }
    }
    
    /// Update privacy settings from saved user preferences
    func updatePrivacySettings(_ settings: WorkoutPrivacySettings) {
        self.privacySettings = settings
        FameFitLogger.info("📱 Updated privacy settings: defaultPrivacy=\(settings.defaultPrivacy.rawValue)", category: FameFitLogger.social)
    }

    // MARK: - Post Activity Methods

    func postWorkoutActivity(
        workout: Workout,
        privacy: WorkoutPrivacy,
        includeDetails: Bool
    ) async throws {
        FameFitLogger.info("📝 Attempting to post workout activity: type=\(workout.workoutType)", category: FameFitLogger.social)
        
        // Validate privacy settings
        guard let workoutType = HKWorkoutActivityType.from(storageKey: workout.workoutType) else {
            FameFitLogger.error("❌ Invalid workout type: \(workout.workoutType)", category: FameFitLogger.social)
            throw ActivityFeedError.invalidWorkoutType
        }

        let effectivePrivacy = privacySettings.effectivePrivacy(for: workoutType)
        let finalPrivacy = min(privacy, effectivePrivacy) // Use most restrictive
        FameFitLogger.info("📊 Privacy check: requested=\(privacy.rawValue), effective=\(effectivePrivacy.rawValue), final=\(finalPrivacy.rawValue)", category: FameFitLogger.social)

        // Private workouts should still be saved - they're just not visible to others
        // The visibility field controls who can see them

        // Create content
        let content = createWorkoutContent(
            from: workout,
            includeDetails: includeDetails && privacySettings.allowDataSharing
        )

        let contentData = try JSONEncoder().encode(content)
        guard let contentString = String(data: contentData, encoding: .utf8) else {
            throw ActivityFeedError.encodingFailed
        }

        // Create activity feed item
        let activityItem = ActivityFeedRecord(
            id: UUID().uuidString,
            userID: cloudKitManager.currentUserID ?? "",
            username: currentUsername,
            activityType: "workout",
            workoutID: workout.id,
            content: contentString,
            visibility: finalPrivacy.rawValue,
            creationDate: Date(),
            expiresAt: Date().addingTimeInterval(30 * 24 * 3_600), // 30 days
            xpEarned: workout.followersEarned,
            achievementName: nil
        )

        FameFitLogger.info("📤 Saving activity feed item to CloudKit...", category: FameFitLogger.social)
        try await saveToCloudKit(activityItem)
        FameFitLogger.info("✅ Successfully posted workout to activity feed", category: FameFitLogger.social)

        // Notify subscribers
        newActivitySubject.send(activityItem)
    }

    func postAchievementActivity(
        achievementName: String,
        xpEarned: Int,
        privacy: WorkoutPrivacy
    ) async throws {
        // Check if achievement sharing is enabled
        guard privacySettings.shareAchievements else { return }

        let effectivePrivacy = min(privacy, privacySettings.allowPublicSharing ? .public : .friendsOnly)
        guard effectivePrivacy != .private else { return }

        let content = ActivityFeedContent(
            title: "Earned the '\(achievementName)' achievement!",
            subtitle: "Unlocked with \(xpEarned) XP",
            details: [
                "achievementName": achievementName,
                "xpEarned": String(xpEarned),
                "achievementIcon": "trophy.fill"
            ]
        )

        let contentData = try JSONEncoder().encode(content)
        guard let contentString = String(data: contentData, encoding: .utf8) else {
            throw ActivityFeedError.encodingFailed
        }

        let activityItem = ActivityFeedRecord(
            id: UUID().uuidString,
            userID: cloudKitManager.currentUserID ?? "",
            username: currentUsername,
            activityType: "achievement",
            workoutID: nil,
            content: contentString,
            visibility: effectivePrivacy.rawValue,
            creationDate: Date(),
            expiresAt: Date().addingTimeInterval(90 * 24 * 3_600), // 90 days for achievements
            xpEarned: xpEarned,
            achievementName: achievementName
        )

        try await saveToCloudKit(activityItem)
        newActivitySubject.send(activityItem)
    }

    func postLevelUpActivity(
        newLevel: Int,
        newTitle: String,
        privacy: WorkoutPrivacy
    ) async throws {
        let effectivePrivacy = min(privacy, privacySettings.allowPublicSharing ? .public : .friendsOnly)
        guard effectivePrivacy != .private else { return }

        let content = ActivityFeedContent(
            title: "Reached Level \(newLevel)!",
            subtitle: newTitle,
            details: [
                "newLevel": String(newLevel),
                "newTitle": newTitle,
                "levelIcon": "star.circle.fill"
            ]
        )

        let contentData = try JSONEncoder().encode(content)
        guard let contentString = String(data: contentData, encoding: .utf8) else {
            throw ActivityFeedError.encodingFailed
        }

        let activityItem = ActivityFeedRecord(
            id: UUID().uuidString,
            userID: cloudKitManager.currentUserID ?? "",
            username: currentUsername,
            activityType: "level_up",
            workoutID: nil,
            content: contentString,
            visibility: effectivePrivacy.rawValue,
            creationDate: Date(),
            expiresAt: Date().addingTimeInterval(365 * 24 * 3_600), // 1 year for level ups
            xpEarned: nil,
            achievementName: nil
        )

        try await saveToCloudKit(activityItem)
        newActivitySubject.send(activityItem)
    }

    // MARK: - Fetch Methods

    func fetchFeed(for userIDs: Set<String>, since: Date?, limit _: Int) async throws -> [ActivityFeedRecord] {
        FameFitLogger.info("🔍 Starting fetchFeed for \(userIDs.count) users: \(Array(userIDs).prefix(3))...", category: FameFitLogger.social)
        
        let predicate = if let since {
            NSPredicate(
                format: "userID IN %@ AND creationDate > %@ AND expiresAt > %@",
                Array(userIDs),
                since as NSDate,
                Date() as NSDate
            )
        } else {
            NSPredicate(
                format: "userID IN %@ AND expiresAt > %@",
                Array(userIDs),
                Date() as NSDate
            )
        }
        
        FameFitLogger.info("🔍 Query predicate: \(predicate)", category: FameFitLogger.social)

        let query = CKQuery(recordType: "ActivityFeed", predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]

        // Perform the actual CloudKit query
        do {
            FameFitLogger.info("🌐 Executing CloudKit query on public database...", category: FameFitLogger.social)
            let results = try await cloudKitManager.publicDatabase.records(matching: query)
            FameFitLogger.info("📦 Query returned \(results.matchResults.count) results", category: FameFitLogger.social)
            
            let records = results.matchResults.compactMap { result -> CKRecord? in
                do {
                    return try result.1.get()
                } catch {
                    FameFitLogger.error("⚠️ Failed to get record: \(error)", category: FameFitLogger.social)
                    return nil
                }
            }
            
            FameFitLogger.info("📦 Successfully extracted \(records.count) CKRecords", category: FameFitLogger.social)
            
            // Convert CKRecords to ActivityFeedRecords
            let feedRecords = records.compactMap { record -> ActivityFeedRecord? in
                let result = convertRecordToActivityItem(record)
                if result == nil {
                    FameFitLogger.warning("⚠️ Failed to convert record: \(record.recordID.recordName)", category: FameFitLogger.social)
                }
                return result
            }
            
            FameFitLogger.info("📥 Successfully converted \(feedRecords.count) activity feed items from CloudKit", category: FameFitLogger.social)
            if !feedRecords.isEmpty {
                FameFitLogger.info("📋 First item: type=\(feedRecords[0].activityType), user=\(feedRecords[0].userID)", category: FameFitLogger.social)
            }
            return feedRecords
        } catch {
            FameFitLogger.error("❌ Failed to fetch activity feed: \(error)", category: FameFitLogger.social)
            throw error
        }
    }

    func deleteActivity(_: String) async throws {
        // CloudKit delete would go here
        // For now, this is a placeholder
    }

    func updateActivityPrivacy(_ activityID: String, newPrivacy: WorkoutPrivacy) async throws {
        // CloudKit update would go here
        // For now, this is a placeholder

        // Notify subscribers
        privacyUpdateSubject.send((activityID, newPrivacy))
    }

    // MARK: - Private Helper Methods

    private func createWorkoutContent(from workout: Workout, includeDetails: Bool) -> ActivityFeedContent {
        var details: [String: String] = [
            "workoutType": workout.workoutType,
            "workoutIcon": "figure.run"
        ]

        if includeDetails {
            details["duration"] = String(workout.duration)
            if workout.totalEnergyBurned > 0 {
                details["calories"] = String(workout.totalEnergyBurned)
            }
            if let distance = workout.totalDistance, distance > 0 {
                details["distance"] = String(distance)
            }
            if workout.followersEarned > 0 {
                details["xpEarned"] = String(workout.followersEarned)
            }
        }

        let workoutDisplayName = workout.workoutType.replacingOccurrences(of: "_", with: " ").capitalized
        let title = "Completed a \(workoutDisplayName) workout"

        var subtitle: String?
        if includeDetails, workout.duration > 0 {
            let minutes = Int(workout.duration / 60)
            subtitle = "Great job on that \(minutes)-minute session! 💪"
        }

        return ActivityFeedContent(
            title: title,
            subtitle: subtitle,
            details: details
        )
    }

    private func saveToCloudKit(_ item: ActivityFeedRecord) async throws {
        let record = CKRecord(recordType: "ActivityFeed")
        record["userID"] = item.userID
        record["username"] = item.username
        record["activityType"] = item.activityType
        record["workoutID"] = item.workoutID
        record["content"] = item.content
        record["visibility"] = item.visibility
        // creationDate is automatically set by CloudKit - no need to set it
        record["expiresAt"] = item.expiresAt
        record["xpEarned"] = item.xpEarned
        record["achievementName"] = item.achievementName
        
        FameFitLogger.info("📋 Activity feed record details:", category: FameFitLogger.social)
        FameFitLogger.info("  - Record ID: \(record.recordID.recordName)", category: FameFitLogger.social)
        FameFitLogger.info("  - User ID: \(item.userID)", category: FameFitLogger.social)
        FameFitLogger.info("  - Type: \(item.activityType)", category: FameFitLogger.social)
        FameFitLogger.info("  - Workout ID: \(item.workoutID ?? "nil")", category: FameFitLogger.social)
        FameFitLogger.info("  - Visibility: \(item.visibility)", category: FameFitLogger.social)
        
        do {
            let savedRecord = try await cloudKitManager.publicDatabase.save(record)
            FameFitLogger.info("✅ Saved activity feed item to CloudKit: \(item.activityType)", category: FameFitLogger.social)
            FameFitLogger.info("  - Saved Record ID: \(savedRecord.recordID.recordName)", category: FameFitLogger.social)
            FameFitLogger.info("  - Database: Public", category: FameFitLogger.social)
        } catch {
            FameFitLogger.error("❌ Failed to save activity feed to CloudKit: \(error)", category: FameFitLogger.social)
            throw error
        }
    }

    private func convertRecordToActivityItem(_ record: CKRecord) -> ActivityFeedRecord? {
        guard
            let userID = record["userID"] as? String,
            let username = record["username"] as? String,
            let activityType = record["activityType"] as? String,
            let content = record["content"] as? String,
            let visibility = record["visibility"] as? String,
            let creationDate = record.creationDate,
            let expiresAt = record["expiresAt"] as? Date
        else {
            return nil
        }

        return ActivityFeedRecord(
            id: record.recordID.recordName,
            userID: userID,
            username: username,
            activityType: activityType,
            workoutID: record["workoutID"] as? String,
            content: content,
            visibility: visibility,
            creationDate: creationDate,
            expiresAt: expiresAt,
            xpEarned: record["xpEarned"] as? Int,
            achievementName: record["achievementName"] as? String
        )
    }

    // Helper to use most restrictive privacy level
    private func min(_ privacy1: WorkoutPrivacy, _ privacy2: WorkoutPrivacy) -> WorkoutPrivacy {
        let order: [WorkoutPrivacy] = [.private, .friendsOnly, .public]
        let index1 = order.firstIndex(of: privacy1) ?? 0
        let index2 = order.firstIndex(of: privacy2) ?? 0
        return order[Swift.min(index1, index2)]
    }
}

// MARK: - Activity Feed Errors

enum ActivityFeedError: LocalizedError {
    case invalidWorkoutType
    case encodingFailed
    case updateFailed(Error)
    case unauthorized
    case networkError(String)

    var errorDescription: String? {
        switch self {
        case .invalidWorkoutType:
            "Invalid workout type"
        case .encodingFailed:
            "Failed to encode activity content"
        case let .updateFailed(error):
            "Failed to update activity: \(error.localizedDescription)"
        case .unauthorized:
            "Not authorized to post activities"
        case let .networkError(message):
            "Network error: \(message)"
        }
    }
}
