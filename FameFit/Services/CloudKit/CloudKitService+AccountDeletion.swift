//
//  CloudKitService+AccountDeletion.swift
//  FameFit
//
//  Improved account deletion with anonymization
//

import CloudKit
import Foundation

extension CloudKitService {
    
    /// Delete all user data with improved anonymization for public content
    func deleteAllUserDataWithAnonymization() async throws {
        guard let userID = currentUserID else {
            throw FameFitError.userNotAuthenticated
        }
        
        FameFitLogger.info("Starting account deletion with anonymization for user: \(userID)", category: FameFitLogger.cloudKit)
        
        var deletedRecords = 0
        var anonymizedRecords = 0
        var errors: [Error] = []
        
        // MARK: - Private Database - Full Deletion
        
        // Delete the Users record first (it uses recordID, not userID field)
        do {
            let userRecordID = CKRecord.ID(recordName: userID)
            _ = try await privateDatabase.deleteRecord(withID: userRecordID)
            deletedRecords += 1
            FameFitLogger.info("Deleted Users record for ID: \(userID)", category: FameFitLogger.cloudKit)
        } catch {
            // If the record doesn't exist, that's fine
            if !error.localizedDescription.contains("Record not found") {
                errors.append(error)
                FameFitLogger.error("Failed to delete Users record", error: error, category: FameFitLogger.cloudKit)
            }
        }
        
        // These are completely private to the user and should be fully deleted
        let privateRecordTypes = [
            // "Users" removed - handled separately above
            "Workouts", 
            "XPTransactions",
            "Notifications",
            "NotificationHistory",  // Push notification history
            "WorkoutChallengeLinks",
            "GroupWorkoutInvites",
            "UserSettings",  // User's app settings
            "ActivityFeedSettings",  // User's privacy settings
            // "WorkoutHistory" removed - doesn't exist as a record type
            "WorkoutMetrics",  // Detailed workout metrics
            "DeviceTokens"  // Push notification tokens
        ]
        
        for recordType in privateRecordTypes {
            do {
                let predicate = NSPredicate(format: "userID == %@", userID)
                let records = try await fetchAndDelete(
                    recordType: recordType,
                    predicate: predicate,
                    database: privateDatabase
                )
                deletedRecords += records
                FameFitLogger.info("Deleted \(records) \(recordType) records", category: FameFitLogger.cloudKit)
            } catch {
                errors.append(error)
                FameFitLogger.error("Failed to delete \(recordType)", error: error, category: FameFitLogger.cloudKit)
            }
        }
        
        // MARK: - Public Database - Anonymization
        // These affect other users and should be anonymized
        
        // 1. Anonymize Comments (keep them but remove user info)
        do {
            let commentRecords = try await anonymizeComments(userID: userID)
            anonymizedRecords += commentRecords
        } catch {
            errors.append(error)
        }
        
        // 2. Anonymize Kudos (keep the kudos but anonymize the giver)
        do {
            let kudosRecords = try await anonymizeKudos(userID: userID)
            anonymizedRecords += kudosRecords
        } catch {
            errors.append(error)
        }
        
        // 3. Handle Group Workouts (transfer ownership or mark as deleted host)
        do {
            let groupRecords = try await handleGroupWorkouts(userID: userID)
            anonymizedRecords += groupRecords
        } catch {
            errors.append(error)
        }
        
        // 4. Anonymize Activity Feed Comments
        do {
            let commentRecords = try await anonymizeActivityFeedComments(userID: userID)
            anonymizedRecords += commentRecords
        } catch {
            errors.append(error)
        }
        
        // 5. Handle Workout Challenges (cancel or transfer ownership)
        do {
            let challengeRecords = try await handleWorkoutChallenges(userID: userID)
            anonymizedRecords += challengeRecords
        } catch {
            errors.append(error)
        }
        
        // MARK: - Public Database - Full Deletion
        // These are the user's own content that should be fully removed
        
        // Delete user profile
        do {
            let predicate = NSPredicate(format: "userID == %@", userID)
            let deleted = try await fetchAndDelete(
                recordType: "UserProfiles",
                predicate: predicate,
                database: publicDatabase
            )
            deletedRecords += deleted
        } catch {
            errors.append(error)
        }
        
        // Delete social relationships
        do {
            let predicate = NSPredicate(format: "followerID == %@ OR followingID == %@", userID, userID)
            let deleted = try await fetchAndDelete(
                recordType: "UserRelationships",  // Fixed to plural
                predicate: predicate,
                database: publicDatabase
            )
            deletedRecords += deleted
            FameFitLogger.info("Deleted \(deleted) UserRelationships records", category: FameFitLogger.cloudKit)
        } catch {
            errors.append(error)
            FameFitLogger.error("Failed to delete UserRelationships records", error: error, category: FameFitLogger.cloudKit)
        }
        
        // Delete user's own activity feed posts
        do {
            let predicate = NSPredicate(format: "userID == %@", userID)
            let deleted = try await fetchAndDelete(
                recordType: "ActivityFeed",  // Fixed: was "ActivityFeedRecords"
                predicate: predicate,
                database: publicDatabase
            )
            deletedRecords += deleted
            FameFitLogger.info("Deleted \(deleted) ActivityFeed records", category: FameFitLogger.cloudKit)
        } catch {
            errors.append(error)
            FameFitLogger.error("Failed to delete ActivityFeed records", error: error, category: FameFitLogger.cloudKit)
        }
        
        // Local data will be cleared by AuthenticationService
        
        FameFitLogger.info("""
            Account deletion completed:
            - Deleted: \(deletedRecords) records
            - Anonymized: \(anonymizedRecords) records
            - Errors: \(errors.count)
            """, category: FameFitLogger.cloudKit)
        
        if !errors.isEmpty && deletedRecords == 0 && anonymizedRecords == 0 {
            throw FameFitError.cloudKitSyncFailed(errors.first!)
        }
    }
    
    // MARK: - Helper Methods
    
    private func fetchAndDelete(
        recordType: String,
        predicate: NSPredicate,
        database: CKDatabase
    ) async throws -> Int {
        let query = CKQuery(recordType: recordType, predicate: predicate)
        let records = try await database.records(matching: query)
        
        let recordIDs = records.matchResults.compactMap { result -> CKRecord.ID? in
            guard let record = try? result.1.get() else { return nil }
            return record.recordID
        }
        
        for recordID in recordIDs {
            _ = try await database.deleteRecord(withID: recordID)
        }
        
        return recordIDs.count
    }
    
    private func anonymizeComments(userID: String) async throws -> Int {
        let predicate = NSPredicate(format: "userID == %@", userID)
        let query = CKQuery(recordType: "ActivityFeedComments", predicate: predicate)
        let results = try await publicDatabase.records(matching: query)
        
        var count = 0
        for result in results.matchResults {
            if let record = try? result.1.get() {
                // Anonymize the comment - use timestamp to ensure uniqueness
                let deletedID = "deleted_\(Date().timeIntervalSince1970)_\(UUID().uuidString.prefix(8))"
                record["userID"] = deletedID
                record["username"] = "[Deleted User]"
                record["userProfileID"] = nil
                
                _ = try await publicDatabase.save(record)
                count += 1
            }
        }
        
        FameFitLogger.info("Anonymized \(count) comments", category: FameFitLogger.cloudKit)
        return count
    }
    
    private func anonymizeKudos(userID: String) async throws -> Int {
        let predicate = NSPredicate(format: "userID == %@", userID)
        let query = CKQuery(recordType: "WorkoutKudos", predicate: predicate)
        let results = try await publicDatabase.records(matching: query)
        
        var count = 0
        for result in results.matchResults {
            if let record = try? result.1.get() {
                // Anonymize the kudos - use timestamp to ensure uniqueness
                let deletedID = "deleted_\(Date().timeIntervalSince1970)_\(UUID().uuidString.prefix(8))"
                record["userID"] = deletedID
                record["username"] = "[Deleted User]"
                
                _ = try await publicDatabase.save(record)
                count += 1
            }
        }
        
        FameFitLogger.info("Anonymized \(count) kudos", category: FameFitLogger.cloudKit)
        return count
    }
    
    private func handleGroupWorkouts(userID: String) async throws -> Int {
        let predicate = NSPredicate(format: "hostID == %@", userID)
        let query = CKQuery(recordType: "GroupWorkouts", predicate: predicate)
        let results = try await publicDatabase.records(matching: query)
        
        var count = 0
        for result in results.matchResults {
            if let record = try? result.1.get() {
                // Mark the host as deleted - use timestamp to ensure uniqueness
                let deletedID = "deleted_\(Date().timeIntervalSince1970)_\(UUID().uuidString.prefix(8))"
                record["hostID"] = deletedID
                record["hostName"] = "[Deleted Host]"
                
                // If the workout is still scheduled/active, cancel it
                if let status = record["status"] as? String,
                   status == "scheduled" || status == "active" {
                    record["status"] = "cancelled"
                    record["cancellationReason"] = "Host account deleted"
                }
                
                _ = try await publicDatabase.save(record)
                count += 1
            }
        }
        
        FameFitLogger.info("Handled \(count) group workouts", category: FameFitLogger.cloudKit)
        return count
    }
    
    private func anonymizeActivityFeedComments(userID: String) async throws -> Int {
        let predicate = NSPredicate(format: "userID == %@", userID)
        let query = CKQuery(recordType: "ActivityFeedComments", predicate: predicate)
        let results = try await publicDatabase.records(matching: query)
        
        var count = 0
        for result in results.matchResults {
            if let record = try? result.1.get() {
                // Anonymize the comment - use timestamp to ensure uniqueness
                let deletedID = "deleted_\(Date().timeIntervalSince1970)_\(UUID().uuidString.prefix(8))"
                record["userID"] = deletedID
                record["username"] = "[Deleted User]"
                record["userProfileID"] = nil
                
                _ = try await publicDatabase.save(record)
                count += 1
            }
        }
        
        FameFitLogger.info("Anonymized \(count) activity feed comments", category: FameFitLogger.cloudKit)
        return count
    }
    
    private func handleWorkoutChallenges(userID: String) async throws -> Int {
        let predicate = NSPredicate(format: "creatorID == %@", userID)
        let query = CKQuery(recordType: "WorkoutChallenges", predicate: predicate)
        let results = try await publicDatabase.records(matching: query)
        
        var count = 0
        for result in results.matchResults {
            if let record = try? result.1.get() {
                // Mark the creator as deleted
                let deletedID = "deleted_\(Date().timeIntervalSince1970)_\(UUID().uuidString.prefix(8))"
                record["creatorID"] = deletedID
                record["creatorName"] = "[Deleted User]"
                
                // If the challenge is still active, cancel it
                if let status = record["status"] as? String,
                   status == "active" || status == "pending" {
                    record["status"] = "cancelled"
                    record["cancellationReason"] = "Creator account deleted"
                }
                
                _ = try await publicDatabase.save(record)
                count += 1
            }
        }
        
        FameFitLogger.info("Handled \(count) workout challenges", category: FameFitLogger.cloudKit)
        return count
    }
}