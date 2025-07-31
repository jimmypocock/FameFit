import CloudKit
import Foundation
import HealthKit
import os.log

/// Manages CloudKit schema initialization and validation
/// This helps prevent runtime errors by ensuring record types exist
class CloudKitSchemaManager {
    private let container: CKContainer
    private let privateDatabase: CKDatabase
    private let publicDatabase: CKDatabase

    init(container: CKContainer) {
        self.container = container
        privateDatabase = container.privateCloudDatabase
        publicDatabase = container.publicCloudDatabase
    }

    /// Initialize all required record types by creating dummy records
    /// This ensures the schema exists in CloudKit
    func initializeSchemaIfNeeded() {
        FameFitLogger.info("Checking CloudKit schema...", category: FameFitLogger.cloudKit)

        // Check if we've already initialized the schema
        let schemaInitializedKey = "FameFitCloudKitSchemaInitialized"
        guard !UserDefaults.standard.bool(forKey: schemaInitializedKey) else {
            FameFitLogger.info("CloudKit schema already initialized", category: FameFitLogger.cloudKit)
            return
        }

        // Initialize all record types
        Task {
            do {
                // Private database types
                try await initializeUserRecordType()
                FameFitLogger.info("User record type initialized", category: FameFitLogger.cloudKit)

                try await initializeWorkoutsRecordType()
                FameFitLogger.info(
                    "Workouts record type initialized", category: FameFitLogger.cloudKit
                )

                try await initializeUserSettingsRecordType()
                FameFitLogger.info("UserSettings record type initialized", category: FameFitLogger.cloudKit)

                try await initializeDeviceTokensRecordType()
                FameFitLogger.info("DeviceTokens record type initialized", category: FameFitLogger.cloudKit)

                // Public database types
                try await initializeUserProfilesRecordType()
                FameFitLogger.info("UserProfiles record type initialized", category: FameFitLogger.cloudKit)

                try await initializeUserRelationshipsRecordType()
                FameFitLogger.info(
                    "UserRelationships record type initialized", category: FameFitLogger.cloudKit
                )

                try await initializeActivityFeedItemsRecordType()
                FameFitLogger.info(
                    "ActivityFeedItems record type initialized", category: FameFitLogger.cloudKit
                )

                try await initializeWorkoutKudosRecordType()
                FameFitLogger.info("WorkoutKudos record type initialized", category: FameFitLogger.cloudKit)

                try await initializeWorkoutCommentsRecordType()
                FameFitLogger.info(
                    "WorkoutComments record type initialized", category: FameFitLogger.cloudKit
                )

                try await initializeGroupWorkoutsRecordType()
                FameFitLogger.info(
                    "GroupWorkouts record type initialized", category: FameFitLogger.cloudKit
                )

                // Mark schema as initialized
                UserDefaults.standard.set(true, forKey: schemaInitializedKey)
                FameFitLogger.info(
                    "CloudKit schema initialization complete", category: FameFitLogger.cloudKit
                )
            } catch {
                FameFitLogger.error(
                    "Failed to initialize CloudKit schema", error: error, category: FameFitLogger.cloudKit
                )
            }
        }
    }

    private func initializeUserRecordType() async throws {
        // Check if User record type exists by querying
        let query = CKQuery(recordType: "Users", predicate: NSPredicate(value: true))

        do {
            _ = try await privateDatabase.records(matching: query, resultsLimit: 1)
            // Record type exists
            return
        } catch {
            // Record type doesn't exist, create a dummy record
            if error.localizedDescription.contains("Record type")
                || error.localizedDescription.contains("Did not find record type") {
                let dummyRecord = CKRecord(recordType: "Users")
                dummyRecord["displayName"] = "Schema Init"
                dummyRecord["totalXP"] = Int64(0)
                dummyRecord["influencerXP"] = Int64(0) // Backward compatibility
                dummyRecord["totalWorkouts"] = Int64(0)
                dummyRecord["currentStreak"] = Int64(0)
                dummyRecord["joinTimestamp"] = Date()

                do {
                    let savedRecord = try await privateDatabase.save(dummyRecord)
                    // Delete the dummy record
                    try await privateDatabase.deleteRecord(withID: savedRecord.recordID)
                } catch {
                    throw error
                }
            } else {
                throw error
            }
        }
    }

    private func initializeWorkoutsRecordType() async throws {
        // Check if Workouts record type exists by querying
        let query = CKQuery(recordType: "Workouts", predicate: NSPredicate(value: true))

        do {
            _ = try await privateDatabase.records(matching: query, resultsLimit: 1)
            // Record type exists
            return
        } catch {
            // Record type doesn't exist, create a dummy record
            if error.localizedDescription.contains("Record type")
                || error.localizedDescription.contains("Did not find record type") {
                let dummyRecord = CKRecord(recordType: "Workouts")
                dummyRecord["workoutId"] = UUID().uuidString
                dummyRecord["workoutType"] = "Running"
                dummyRecord["startDate"] = Date()
                dummyRecord["endDate"] = Date()
                dummyRecord["duration"] = 0.0
                dummyRecord["totalEnergyBurned"] = 0.0
                dummyRecord["totalDistance"] = 0.0
                dummyRecord["averageHeartRate"] = 0.0
                dummyRecord["followersEarned"] = Int64(0)
                dummyRecord["xpEarned"] = Int64(0)
                dummyRecord["source"] = "Schema Init"

                do {
                    let savedRecord = try await privateDatabase.save(dummyRecord)
                    // Delete the dummy record
                    try await privateDatabase.deleteRecord(withID: savedRecord.recordID)
                } catch {
                    throw error
                }
            } else {
                throw error
            }
        }
    }

    private func initializeUserSettingsRecordType() async throws {
        let query = CKQuery(recordType: "UserSettings", predicate: NSPredicate(value: true))

        do {
            _ = try await privateDatabase.records(matching: query, resultsLimit: 1)
            return
        } catch {
            if error.localizedDescription.contains("Record type")
                || error.localizedDescription.contains("Did not find record type") {
                let dummyRecord = CKRecord(recordType: "UserSettings")
                dummyRecord["userID"] = "dummy"
                dummyRecord["emailNotifications"] = Int64(1)
                dummyRecord["pushNotifications"] = Int64(1)
                dummyRecord["workoutPrivacy"] = "private"
                dummyRecord["allowMessages"] = "friends"
                dummyRecord["blockedUsers"] = [String]()
                dummyRecord["mutedUsers"] = [String]()
                dummyRecord["contentFilter"] = "moderate"
                dummyRecord["showWorkoutStats"] = Int64(1)
                dummyRecord["allowFriendRequests"] = Int64(1)
                dummyRecord["showOnLeaderboards"] = Int64(1)

                do {
                    let savedRecord = try await privateDatabase.save(dummyRecord)
                    try await privateDatabase.deleteRecord(withID: savedRecord.recordID)
                } catch {
                    throw error
                }
            } else {
                throw error
            }
        }
    }

    private func initializeDeviceTokensRecordType() async throws {
        let query = CKQuery(recordType: "DeviceTokens", predicate: NSPredicate(value: true))

        do {
            _ = try await privateDatabase.records(matching: query, resultsLimit: 1)
            return
        } catch {
            if error.localizedDescription.contains("Record type")
                || error.localizedDescription.contains("Did not find record type") {
                let dummyRecord = CKRecord(recordType: "DeviceTokens")
                dummyRecord["userID"] = "dummy"
                dummyRecord["deviceToken"] = "dummy-token"
                dummyRecord["platform"] = "iOS"
                dummyRecord["appVersion"] = "1.0.0"
                dummyRecord["osVersion"] = "17.0"
                dummyRecord["environment"] = "development"
                // modifiedTimestamp is managed by CloudKit automatically
                dummyRecord["isActive"] = Int64(1)

                do {
                    let savedRecord = try await privateDatabase.save(dummyRecord)
                    try await privateDatabase.deleteRecord(withID: savedRecord.recordID)
                } catch {
                    throw error
                }
            } else {
                throw error
            }
        }
    }

    private func initializeUserProfilesRecordType() async throws {
        let query = CKQuery(recordType: "UserProfiles", predicate: NSPredicate(value: true))

        do {
            _ = try await publicDatabase.records(matching: query, resultsLimit: 1)
            return
        } catch {
            if error.localizedDescription.contains("Record type")
                || error.localizedDescription.contains("Did not find record type") {
                let dummyRecord = CKRecord(recordType: "UserProfiles")
                dummyRecord["userID"] = "dummy"
                dummyRecord["username"] = "schemaInit"
                dummyRecord["displayName"] = "Schema Init"
                dummyRecord["bio"] = ""
                dummyRecord["workoutCount"] = Int64(0)
                dummyRecord["totalXP"] = Int64(0)
                // createdTimestamp and modifiedTimestamp are managed by CloudKit automatically
                dummyRecord["privacyLevel"] = "private"

                do {
                    let savedRecord = try await publicDatabase.save(dummyRecord)
                    try await publicDatabase.deleteRecord(withID: savedRecord.recordID)
                } catch {
                    throw error
                }
            } else {
                throw error
            }
        }
    }

    private func initializeUserRelationshipsRecordType() async throws {
        let query = CKQuery(recordType: "UserRelationships", predicate: NSPredicate(value: true))

        do {
            _ = try await publicDatabase.records(matching: query, resultsLimit: 1)
            return
        } catch {
            if error.localizedDescription.contains("Record type")
                || error.localizedDescription.contains("Did not find record type") {
                let dummyRecord = CKRecord(recordType: "UserRelationships")
                dummyRecord["followerID"] = "dummy1"
                dummyRecord["followingID"] = "dummy2"
                dummyRecord["status"] = "active"
                dummyRecord["notificationsEnabled"] = Int64(1)

                do {
                    let savedRecord = try await publicDatabase.save(dummyRecord)
                    try await publicDatabase.deleteRecord(withID: savedRecord.recordID)
                } catch {
                    throw error
                }
            } else {
                throw error
            }
        }
    }

    private func initializeActivityFeedItemsRecordType() async throws {
        let query = CKQuery(recordType: "ActivityFeedItems", predicate: NSPredicate(value: true))

        do {
            _ = try await publicDatabase.records(matching: query, resultsLimit: 1)
            return
        } catch {
            if error.localizedDescription.contains("Record type")
                || error.localizedDescription.contains("Did not find record type") {
                let dummyRecord = CKRecord(recordType: "ActivityFeedItems")
                dummyRecord["userID"] = "dummy"
                dummyRecord["activityType"] = "workout"
                dummyRecord["content"] = "Schema Init"
                dummyRecord["visibility"] = "private"
                dummyRecord["createdTimestamp"] = Date()
                dummyRecord["expiresAt"] = Date().addingTimeInterval(86_400 * 30) // 30 days

                do {
                    let savedRecord = try await publicDatabase.save(dummyRecord)
                    try await publicDatabase.deleteRecord(withID: savedRecord.recordID)
                } catch {
                    throw error
                }
            } else {
                throw error
            }
        }
    }

    private func initializeWorkoutKudosRecordType() async throws {
        let query = CKQuery(recordType: "WorkoutKudos", predicate: NSPredicate(value: true))

        do {
            _ = try await publicDatabase.records(matching: query, resultsLimit: 1)
            return
        } catch {
            if error.localizedDescription.contains("Record type")
                || error.localizedDescription.contains("Did not find record type") {
                let dummyRecord = CKRecord(recordType: "WorkoutKudos")
                dummyRecord["workoutId"] = "dummy-workout"
                dummyRecord["userID"] = "dummy-user"
                dummyRecord["workoutOwnerId"] = "dummy-owner"
                dummyRecord["createdTimestamp"] = Date()

                do {
                    let savedRecord = try await publicDatabase.save(dummyRecord)
                    try await publicDatabase.deleteRecord(withID: savedRecord.recordID)
                } catch {
                    throw error
                }
            } else {
                throw error
            }
        }
    }

    private func initializeWorkoutCommentsRecordType() async throws {
        let query = CKQuery(recordType: "WorkoutComments", predicate: NSPredicate(value: true))

        do {
            _ = try await publicDatabase.records(matching: query, resultsLimit: 1)
            return
        } catch {
            if error.localizedDescription.contains("Record type")
                || error.localizedDescription.contains("Did not find record type") {
                let dummyRecord = CKRecord(recordType: "WorkoutComments")
                dummyRecord["workoutId"] = "dummy-workout"
                dummyRecord["userId"] = "dummy-user"
                dummyRecord["workoutOwnerId"] = "dummy-owner"
                dummyRecord["content"] = "Great workout!"
                dummyRecord["createdTimestamp"] = Date()
                dummyRecord["modifiedTimestamp"] = Date()
                dummyRecord["isEdited"] = Int64(0)
                dummyRecord["likeCount"] = Int64(0)

                do {
                    let savedRecord = try await publicDatabase.save(dummyRecord)
                    try await publicDatabase.deleteRecord(withID: savedRecord.recordID)
                } catch {
                    throw error
                }
            } else {
                throw error
            }
        }
    }

    private func initializeGroupWorkoutsRecordType() async throws {
        let query = CKQuery(recordType: "GroupWorkouts", predicate: NSPredicate(value: true))

        do {
            _ = try await publicDatabase.records(matching: query, resultsLimit: 1)
            return
        } catch {
            if error.localizedDescription.contains("Record type")
                || error.localizedDescription.contains("Did not find record type") {
                let dummyRecord = CKRecord(recordType: "GroupWorkouts")

                // Create minimal group workout
                let dummyParticipants = [
                    GroupWorkoutParticipant(
                        userId: "dummy1",
                        username: "DummyUser",
                        profileImageURL: nil
                    )
                ]

                dummyRecord["name"] = "Schema Init Workout"
                dummyRecord["description"] = "Schema initialization"
                dummyRecord["workoutType"] = Int64(HKWorkoutActivityType.running.rawValue)
                dummyRecord["hostId"] = "dummy-host"
                dummyRecord["participants"] = try? JSONEncoder().encode(dummyParticipants)
                dummyRecord["maxParticipants"] = Int64(10)
                dummyRecord["scheduledStart"] = Date().addingTimeInterval(3_600) // 1 hour from now
                dummyRecord["scheduledEnd"] = Date().addingTimeInterval(7_200) // 2 hours from now
                dummyRecord["status"] = "scheduled"
                dummyRecord["createdTimestamp"] = Date()
                dummyRecord["modifiedTimestamp"] = Date()
                dummyRecord["isPublic"] = Int64(1)
                dummyRecord["tags"] = [String]()

                do {
                    let savedRecord = try await publicDatabase.save(dummyRecord)
                    try await publicDatabase.deleteRecord(withID: savedRecord.recordID)
                } catch {
                    throw error
                }
            } else {
                throw error
            }
        }
    }
}

// MARK: - CloudKit Best Practices

extension CloudKitSchemaManager {
    /// Guidelines for preventing CloudKit schema errors:
    /// 1. Always use system fields for queries when possible (creationDate, modificationDate)
    /// 2. Document all record types in CLOUDKIT_SCHEMA.md
    /// 3. Initialize schema programmatically in development
    /// 4. Handle missing record types gracefully
    /// 5. Test thoroughly before deploying to production

    static var schemaGuidelines: String {
        """
        CloudKit Schema Best Practices:

        1. System fields are always queryable:
           - creationDate
           - modificationDate
           - recordName (but avoid using in predicates)

        2. Custom fields must be marked queryable in CloudKit Dashboard

        3. To prevent "record type not found" errors:
           - Use CloudKitSchemaManager.initializeSchemaIfNeeded()
           - Handle errors gracefully in queries

        4. For sorting:
           - Prefer system fields (creationDate, modificationDate)
           - Only queryable fields can be used in sort descriptors

        5. See docs/CLOUDKIT_SCHEMA.md for full schema documentation
        """
    }
}
