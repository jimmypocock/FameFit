//
//  DeveloperResetTool.swift
//  FameFit
//
//  Developer tool to reset user data for testing onboarding
//

import CloudKit
import Foundation

class DeveloperResetTool {
    private let container = CKContainer(identifier: "iCloud.com.jimmypocock.FameFit")
    
    /// Completely resets the user's data to test onboarding flow
    func resetUserDataForTesting() async throws {
        print("🔧 Starting developer reset...")
        
        // 1. Delete all related CloudKit records (skip user record - can't be deleted)
        try await deleteUserRelatedRecords()
        
        // 2. Clear local authentication state
        clearLocalAuthenticationState()
        
        // 3. Clear all UserDefaults
        clearAllUserDefaults()
        
        // 4. Clear ALL caches to prevent stale data
        await clearAllCaches()
        
        print("✅ Developer reset complete - app will show onboarding on next launch")
    }
    
    /// Delete a specific profile by username (for development cleanup)
    func deleteProfileByUsername(_ username: String) async throws {
        print("🗑️ Attempting to delete profile with username: '\(username)'")
        
        // Try both the exact username and lowercase version
        let usernamesToTry = [username, username.lowercased()]
        var deletedCount = 0
        
        for usernameToTry in usernamesToTry {
            print("  🔍 Trying username: '\(usernameToTry)'")
            let predicate = NSPredicate(format: "username == %@", usernameToTry)
            let query = CKQuery(recordType: "UserProfiles", predicate: predicate)
            
            // Check both databases
            for (dbName, database) in [("public", container.publicCloudDatabase), ("private", container.privateCloudDatabase)] {
                do {
                    print("    📂 Checking \(dbName) database...")
                    let results = try await database.records(matching: query)
                    print("    📊 Found \(results.matchResults.count) matching records")
                    
                    for result in results.matchResults {
                        if let record = try? result.1.get() {
                            let recordUsername = record["username"] as? String ?? "unknown"
                            print("    🎯 Found record with username: '\(recordUsername)', deleting...")
                            try await database.deleteRecord(withID: record.recordID)
                            deletedCount += 1
                            print("    ✅ Deleted profile from \(dbName) database")
                        }
                    }
                } catch {
                    print("    ⚠️ Error checking \(dbName) database: \(error)")
                    if let ckError = error as? CKError {
                        print("      Error code: \(ckError.code.rawValue)")
                        print("      Error description: \(ckError.localizedDescription)")
                        
                        if ckError.code == .permissionFailure {
                            print("    ❌ Permission denied: You can only delete profiles you created")
                        }
                    }
                }
            }
            
            if deletedCount > 0 {
                break // Found and deleted, no need to try other variations
            }
        }
        
        if deletedCount > 0 {
            print("✅ Successfully deleted \(deletedCount) profile(s) with username: \(username)")
        } else {
            print("❌ No profiles found with username: \(username)")
        }
    }
    
    /// List all profiles in the database (for debugging)
    func listAllProfiles() async throws -> [(username: String, userID: String, database: String)] {
        print("📋 Listing all profiles in CloudKit...")
        
        let query = CKQuery(recordType: "UserProfiles", predicate: NSPredicate(value: true))
        var allProfiles: [(username: String, userID: String, database: String)] = []
        
        for (dbName, database) in [("public", container.publicCloudDatabase), ("private", container.privateCloudDatabase)] {
            do {
                let results = try await database.records(matching: query)
                let count = results.matchResults.count
                
                if !results.matchResults.isEmpty {
                    print("\n📁 \(dbName.capitalized) Database (\(count) profiles):")
                    
                    for result in results.matchResults {
                        if let record = try? result.1.get() {
                            let username = record["username"] as? String ?? "unknown"
                            let userID = record["userID"] as? String ?? "unknown"
                            print("  - Username: \(username), UserID: \(userID)")
                            
                            allProfiles.append((
                                username: username,
                                userID: userID,
                                database: dbName
                            ))
                        }
                    }
                }
            } catch {
                print("  ⚠️ Error listing \(dbName) database: \(error)")
            }
        }
        
        print("\n📊 Total profiles found: \(allProfiles.count)")
        return allProfiles
    }
    
    /// List only profiles created by the current user (deletable), excluding the active profile
    func listCurrentUserProfiles() async throws -> [(username: String, userID: String, database: String, isActive: Bool)] {
        print("📋 Listing current user's profiles...")
        
        // Get current user's ID
        let currentUserID = try await container.userRecordID().recordName
        print("🔍 Current user ID: \(currentUserID)")
        
        // First, try to get the current active profile from CloudKit
        var activeUsername: String?
        
        // Try to fetch the current user's active profile
        let activeProfileQuery = CKQuery(
            recordType: "UserProfiles",
            predicate: NSPredicate(format: "userID == %@", currentUserID)
        )
        
        // Check both databases for the active profile
        for database in [container.publicCloudDatabase, container.privateCloudDatabase] {
            do {
                let results = try await database.records(matching: activeProfileQuery, resultsLimit: 100)
                // Find the most recently modified profile (likely the active one)
                let profiles = results.matchResults.compactMap { try? $0.1.get() }
                if let mostRecent = profiles.max(by: { 
                    ($0.modificationDate ?? Date.distantPast) < ($1.modificationDate ?? Date.distantPast) 
                }) {
                    activeUsername = mostRecent["username"] as? String
                    print("🔍 Found active profile: @\(activeUsername ?? "unknown") (most recent)")
                    break
                }
            } catch {
                // Continue to next database
            }
        }
        
        print("🔍 Active username: \(activeUsername ?? "none")")
        
        // Query for profiles created by this user
        let predicate = NSPredicate(format: "userID == %@", currentUserID)
        let query = CKQuery(recordType: "UserProfiles", predicate: predicate)
        var userProfiles: [(username: String, userID: String, database: String, isActive: Bool)] = []
        
        for (dbName, database) in [("public", container.publicCloudDatabase), ("private", container.privateCloudDatabase)] {
            do {
                let results = try await database.records(matching: query)
                let count = results.matchResults.count
                
                if !results.matchResults.isEmpty {
                    print("\n📁 \(dbName.capitalized) Database (\(count) profiles):")
                    
                    for result in results.matchResults {
                        if let record = try? result.1.get() {
                            let username = record["username"] as? String ?? "unknown"
                            let userID = record["userID"] as? String ?? "unknown"
                            let isActive = username == activeUsername
                            
                            print("  - Username: \(username)\(isActive ? " [ACTIVE]" : "")")
                            
                            // Only add non-active profiles
                            // If we couldn't determine the active profile, include all profiles but mark uncertainty
                            if !isActive || activeUsername == nil {
                                userProfiles.append((
                                    username: username,
                                    userID: userID,
                                    database: dbName,
                                    isActive: isActive
                                ))
                            }
                        }
                    }
                }
            } catch {
                print("  ⚠️ Error listing \(dbName) database: \(error)")
            }
        }
        
        print("\n📊 Total deletable profiles found: \(userProfiles.count) (excluding active profile)")
        return userProfiles
    }
    
    private func deleteCloudKitUserRecord() async throws {
        let recordID = try await container.userRecordID()
        
        do {
            try await container.privateCloudDatabase.deleteRecord(withID: recordID)
            print("🗑️ Deleted CloudKit user record")
        } catch {
            // Record might not exist, that's OK
            print("⚠️ User record not found or already deleted: \(error.localizedDescription)")
        }
    }
    
    private func deleteUserRelatedRecords() async throws {
        let userID = try await container.userRecordID().recordName
        
        print("🔍 Searching for records to delete for user: \(userID)")
        
        // Delete ALL records we can find - be aggressive about cleanup
        
        // UserProfiles - try to delete ALL profiles (we'll filter in code)
        await deleteAllUserRecords(ofType: "UserProfiles", forUser: userID)
        
        // Workouts - delete only user's workouts
        await deleteRecords(ofType: "Workouts", matching: NSPredicate(format: "userID == %@", userID))
        
        // UserRelationships - use separate predicates to avoid OR syntax issues
        await deleteRecords(ofType: "UserRelationships", matching: NSPredicate(format: "followerID == %@", userID))
        await deleteRecords(ofType: "UserRelationships", matching: NSPredicate(format: "followingID == %@", userID))
        
        // ActivityFeed - if it exists
        await deleteRecords(ofType: "ActivityFeed", matching: NSPredicate(format: "userID == %@", userID))
        
        // WorkoutKudos - if it exists
        await deleteRecords(ofType: "WorkoutKudos", matching: NSPredicate(format: "userID == %@", userID))
        
        // WorkoutComments - field is "userID" (lowercase)
        await deleteRecords(ofType: "WorkoutComments", matching: NSPredicate(format: "userID == %@", userID))
        
        // GroupWorkouts - DON'T DELETE! Just remove user as participant
        // Deleting would break the workout for other participants
        await removeUserFromGroupWorkouts(userID: userID)
        
        // WorkoutChallenges - DON'T DELETE! Just remove user as participant
        // Deleting would break the challenge for other participants
        await removeUserFromChallenges(userID: userID)
        
        // UserSettings - if it exists
        await deleteRecords(ofType: "UserSettings", matching: NSPredicate(format: "userID == %@", userID))
        
        // DeviceTokens
        await deleteRecords(ofType: "DeviceTokens", matching: NSPredicate(format: "userID == %@", userID))
        
        print("🗑️ Deleted all user-related CloudKit records")
    }
    
    private func deleteRecords(ofType recordType: String, matching predicate: NSPredicate) async {
        let query = CKQuery(recordType: recordType, predicate: predicate)
        
        // Try both databases since we might have records in either
        let databases = [container.privateCloudDatabase, container.publicCloudDatabase]
        var totalDeleted = 0
        
        for database in databases {
            do {
                let results = try await database.records(matching: query)
                let recordIDs = results.matchResults.compactMap { try? $0.1.get().recordID }
                
                if !recordIDs.isEmpty {
                    for recordID in recordIDs {
                        do {
                            try await database.deleteRecord(withID: recordID)
                            totalDeleted += 1
                        } catch {
                            print("    ⚠️ Failed to delete individual record: \(error.localizedDescription)")
                        }
                    }
                }
            } catch {
                // Silently continue - the record type might not exist in this database
            }
        }
        
        if totalDeleted > 0 {
            print("  ✅ Deleted \(totalDeleted) \(recordType) records")
        } else {
            print("  ℹ️ No \(recordType) records found to delete")
        }
    }
    
    private func deleteAllUserRecords(ofType recordType: String, forUser userID: String) async {
        print("  🔍 Looking for \(recordType) records...")
        
        // Special handling for UserProfiles which might have different field names
        // Try multiple predicates to catch all variations
        
        let predicates = [
            ("userID == userID", NSPredicate(format: "userID == %@", userID)),
            ("userID == userID", NSPredicate(format: "userID == %@", userID)),
            ("ALL records", NSPredicate(value: true)) // Nuclear option - get ALL profiles and filter in code
        ]
        
        var totalDeleted = 0
        var foundAny = false
        
        for (predicateDesc, predicate) in predicates {
            print("    → Trying predicate: \(predicateDesc)")
            let query = CKQuery(recordType: recordType, predicate: predicate)
            
            // Check both databases
            let databases = [
                ("private", container.privateCloudDatabase),
                ("public", container.publicCloudDatabase)
            ]
            
            for (dbName, database) in databases {
                do {
                    let results = try await database.records(matching: query)
                    let recordCount = results.matchResults.count
                    
                    if recordCount > 0 {
                        print("      📁 Found \(recordCount) records in \(dbName) database")
                        foundAny = true
                    }
                    
                    for result in results.matchResults {
                        if let record = try? result.1.get() {
                            // If we're using the "true" predicate, check if this record belongs to our user
                            if predicate.predicateFormat == "TRUEPREDICATE" {
                                let recordUserID = record["userID"] as? String ?? record["userID"] as? String
                                if recordUserID != userID {
                                    continue // Skip records for other users
                                }
                                print("      🎯 Found matching profile for user: \(userID)")
                            }
                            
                            // Delete the record
                            do {
                                try await database.deleteRecord(withID: record.recordID)
                                totalDeleted += 1
                                print("      ✅ Deleted \(recordType) record: \(record.recordID.recordName)")
                            } catch {
                                print("      ⚠️ Failed to delete record: \(error.localizedDescription)")
                            }
                        }
                    }
                } catch {
                    // This is expected for non-existent record types or databases
                    if error.localizedDescription.contains("did not find record type") {
                        print("      ❌ Record type doesn't exist in \(dbName) database")
                    }
                }
            }
            
            // If we found and deleted records, we can stop trying other predicates
            if totalDeleted > 0 {
                break
            }
        }
        
        if totalDeleted > 0 {
            print("  ✅ Successfully deleted \(totalDeleted) \(recordType) records")
        } else if !foundAny {
            print("  ℹ️ No \(recordType) records found")
        } else {
            print("  ⚠️ Found \(recordType) records but couldn't delete them")
        }
    }
    
    private func clearLocalAuthenticationState() {
        // Clear keychain items if any
        // For now, we'll rely on UserDefaults clearing
    }
    
    private func removeUserFromGroupWorkouts(userID: String) async {
        print("  🔍 Looking for GroupWorkouts where user is participant...")
        
        // Find workouts where user is a participant
        let participantPredicate = NSPredicate(format: "ANY participants.userID == %@", userID)
        let query = CKQuery(recordType: "GroupWorkouts", predicate: participantPredicate)
        
        var updatedCount = 0
        
        for database in [container.publicCloudDatabase, container.privateCloudDatabase] {
            do {
                let results = try await database.records(matching: query)
                
                for result in results.matchResults {
                    if let record = try? result.1.get() {
                        // Check if this is a workout the user hosts
                        if let hostID = record["hostID"] as? String, hostID == userID {
                            // If user is host, we should cancel the workout instead of deleting
                            record["status"] = "cancelled"
                            
                            print("    ⚠️ Cancelling group workout hosted by user")
                        } else {
                            // Remove user from participants array
                            if var participants = record["participants"] as? [[String: Any]] {
                                participants.removeAll { participant in
                                    if let participantUserID = participant["userID"] as? String {
                                        return participantUserID == userID
                                    }
                                    return false
                                }
                                record["participants"] = participants as CKRecordValue
                                
                                print("    ✅ Removed user from participant list")
                            }
                        }
                        
                        // Save the updated record
                        do {
                            _ = try await database.save(record)
                            updatedCount += 1
                        } catch {
                            print("    ⚠️ Failed to update group workout: \(error)")
                        }
                    }
                }
            } catch {
                // Continue with other database
            }
        }
        
        if updatedCount > 0 {
            print("  ✅ Updated \(updatedCount) group workouts")
        } else {
            print("  ℹ️ No group workouts found for user")
        }
    }
    
    private func removeUserFromChallenges(userID: String) async {
        print("  🔍 Looking for WorkoutChallenges where user is participant...")
        
        // Find challenges where user is a participant
        let participantPredicate = NSPredicate(format: "ANY participants CONTAINS %@", userID)
        let query = CKQuery(recordType: "WorkoutChallenges", predicate: participantPredicate)
        
        var updatedCount = 0
        
        for database in [container.publicCloudDatabase, container.privateCloudDatabase] {
            do {
                let results = try await database.records(matching: query)
                
                for result in results.matchResults {
                    if let record = try? result.1.get() {
                        // Check if this is a challenge the user created
                        if let creatorID = record["creatorID"] as? String, creatorID == userID {
                            // If user is creator, mark challenge as cancelled
                            record["status"] = "cancelled"
                            
                            print("    ⚠️ Cancelling challenge created by user")
                        } else {
                            // Remove user from participants array
                            if var participants = record["participants"] as? [String] {
                                participants.removeAll { $0 == userID }
                                record["participants"] = participants as CKRecordValue
                                
                                print("    ✅ Removed user from participant list")
                            }
                        }
                        
                        // Save the updated record
                        do {
                            _ = try await database.save(record)
                            updatedCount += 1
                        } catch {
                            print("    ⚠️ Failed to update challenge: \(error)")
                        }
                    }
                }
            } catch {
                // Continue with other database
            }
        }
        
        if updatedCount > 0 {
            print("  ✅ Updated \(updatedCount) workout challenges")
        } else {
            print("  ℹ️ No workout challenges found for user")
        }
    }
    
    private func clearAllUserDefaults() {
        let defaults = UserDefaults.standard
        
        // List of all keys used by the app
        let keysToRemove = [
            // Authentication & Onboarding
            "hasCompletedOnboarding",
            "isAuthenticated",
            "userID",
            "username",
            "currentUsername",
            "hasSeenWelcome",
            
            // HealthKit & Sync
            "hasRequestedHealthKitAccess",
            "lastSyncAnchor",
            "workoutSyncAnchor",
            "lastWorkoutSync",
            
            // App State
            "selectedTab",
            "lastActiveTab",
            
            // Developer/Test Account Related
            "TestAccountRegistry",
            "currentTestPersona",
            
            // Notification Preferences
            "notificationPreferences",
            "hasRequestedNotificationPermission",
            "deviceToken",
            
            // Cache Keys
            "userProfileCache",
            "socialRelationshipCache",
            "lastCacheUpdate",
            
            // Privacy Settings
            "workoutPrivacySettings",
            "activitySharingSettings",
            
            // Feature Flags
            "hasSeenActivitySharingMigration",
            "hasCompletedProfileSetup"
        ]
        
        // Remove all known keys
        for key in keysToRemove {
            defaults.removeObject(forKey: key)
        }
        
        // Nuclear option: Remove ALL keys with our app's prefix (if we use one)
        // This catches any keys we might have missed
        let allKeys = defaults.dictionaryRepresentation().keys
        for key in allKeys {
            // Remove any keys that look like they belong to our app
            if key.contains("FameFit") || key.contains("workout") || key.contains("profile") {
                defaults.removeObject(forKey: key)
            }
        }
        
        defaults.synchronize()
        print("🗑️ Cleared all UserDefaults (\(keysToRemove.count) known keys + any app-specific keys)")
    }
    
    private func clearAllCaches() async {
        print("🧹 Clearing all in-memory caches...")
        
        // NOTE: We can't clear caches here without access to the app's dependency container
        // The reset tool forces the app to restart, which will create fresh services anyway
        print("  ℹ️ Caches will be cleared when app restarts")
        print("🧹 Cache clear deferred to app restart")
    }
}
