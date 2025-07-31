//
//  CloudKitSeeder.swift
//  FameFit
//
//  Seeds CloudKit development environment with test data
//  IMPORTANT: This file is only included in DEBUG builds
//

#if DEBUG
import CloudKit
import Foundation

@MainActor
final class CloudKitSeeder {
    private let container = CKContainer(identifier: "iCloud.com.jimmypocock.FameFit")
    private let publicDatabase: CKDatabase
    private let privateDatabase: CKDatabase
    
    init() {
        self.publicDatabase = container.publicCloudDatabase
        self.privateDatabase = container.privateCloudDatabase
    }
    
    // MARK: - Current User Setup
    
    /// Get the current CloudKit user ID
    func getCurrentUserID() async throws -> String {
        let recordID = try await container.userRecordID()
        return recordID.recordName
    }
    
    /// Register current account as a test persona
    func registerCurrentAccount(as persona: TestAccountPersona) async throws {
        let userID = try await getCurrentUserID()
        
        // Save to UserDefaults
        var registry = UserDefaults.standard.dictionary(forKey: "TestAccountRegistry") ?? [:]
        registry[persona.rawValue] = userID
        UserDefaults.standard.set(registry, forKey: "TestAccountRegistry")
        
        print("✅ Registered \(userID) as \(persona.displayName)")
    }
    
    /// Update current user's profile with persona data
    func updateCurrentUserWithPersona(_ persona: TestAccountPersona) async throws {
        let userID = try await getCurrentUserID()
        
        // Create UserProfile in public database
        let profile = createProfile(for: persona, userID: userID)
        let record = profile.toCKRecord(recordID: CKRecord.ID(recordName: userID))
        
        _ = try await publicDatabase.save(record)
        print("✅ Updated profile for \(persona.displayName)")
    }
    
    /// Register a new account as a specific persona (for creating test profiles)
    func registerAccountAsPersona(_ persona: TestAccountPersona) async throws {
        // Generate a unique ID for this test profile
        let testUserID = "test_\(persona.rawValue)_\(UUID().uuidString.prefix(8))"
        
        // Save to UserDefaults
        var registry = UserDefaults.standard.dictionary(forKey: "TestAccountRegistry") ?? [:]
        registry[persona.rawValue] = testUserID
        UserDefaults.standard.set(registry, forKey: "TestAccountRegistry")
        
        print("✅ Registered test account \(testUserID) as \(persona.displayName)")
    }
    
    /// Setup profile for a specific persona
    func setupProfileForPersona(_ persona: TestAccountPersona) async throws {
        guard let userID = getStoredUserID(for: persona) else {
            throw SeederError.personaNotFound
        }
        
        // Create UserProfile in public database
        let profile = createProfile(for: persona, userID: userID)
        let record = profile.toCKRecord(recordID: CKRecord.ID(recordName: userID))
        
        _ = try await publicDatabase.save(record)
        print("✅ Created profile for \(persona.displayName)")
    }
    
    /// Seed workout history for a specific persona
    func seedWorkoutHistoryForPersona(_ persona: TestAccountPersona) async throws {
        guard let userID = getStoredUserID(for: persona) else {
            throw SeederError.personaNotFound
        }
        
        let workouts = createWorkoutHistory(for: persona)
        
        for workout in workouts {
            let record = CKRecord(recordType: "Workouts")
            record["workoutId"] = workout.id.uuidString
            record["workoutType"] = workout.workoutType
            record["startDate"] = workout.startDate
            record["endDate"] = workout.endDate
            record["duration"] = workout.duration
            record["totalEnergyBurned"] = workout.totalEnergyBurned
            record["totalDistance"] = workout.totalDistance ?? 0
            record["averageHeartRate"] = workout.averageHeartRate ?? 0
            record["followersEarned"] = Int64(workout.followersEarned)
            record["xpEarned"] = Int64(workout.xpEarned ?? workout.followersEarned)
            record["source"] = workout.source
            record["userID"] = userID
            
            do {
                _ = try await privateDatabase.save(record)
            } catch {
                print("⚠️ Error saving workout: \(error)")
            }
        }
        
        print("✅ Created \(workouts.count) workouts for \(persona.displayName)")
    }
    
    // MARK: - Profile Setup
    
    /// Setup profile for current user based on their persona
    func setupCurrentUserProfile() async throws {
        let userID = try await getCurrentUserID()
        guard let persona = getPersona(for: userID) else {
            throw SeederError.personaNotFound
        }
        
        // Create UserProfile in public database
        let profile = createProfile(for: persona, userID: userID)
        let record = profile.toCKRecord(recordID: CKRecord.ID(recordName: userID))
        
        do {
            _ = try await publicDatabase.save(record)
            print("✅ Created profile for \(persona.displayName)")
        } catch {
            print("⚠️ Profile may already exist: \(error)")
        }
    }
    
    // MARK: - Social Graph Setup
    
    /// Setup social relationships between test accounts
    func setupSocialGraph() async throws {
        let currentUserID = try await getCurrentUserID()
        guard let currentPersona = getPersona(for: currentUserID) else {
            throw SeederError.personaNotFound
        }
        
        // Define relationships based on persona
        let relationships = getSocialRelationships(for: currentPersona)
        
        for relationship in relationships {
            if let targetUserID = getStoredUserID(for: relationship.targetPersona) {
                try await createFollowRelationship(
                    from: currentUserID,
                    to: targetUserID,
                    type: relationship.type
                )
            }
        }
        
        print("✅ Set up \(relationships.count) social relationships")
    }
    
    // MARK: - Workout History
    
    /// Create workout history for current user
    func seedWorkoutHistory() async throws {
        let userID = try await getCurrentUserID()
        guard let persona = getPersona(for: userID) else {
            throw SeederError.personaNotFound
        }
        
        let workouts = createWorkoutHistory(for: persona)
        
        for workout in workouts {
            let record = CKRecord(recordType: "WorkoutHistory")
            record["workoutId"] = workout.id.uuidString
            record["workoutType"] = workout.workoutType
            record["startDate"] = workout.startDate
            record["endDate"] = workout.endDate
            record["duration"] = workout.duration
            record["totalEnergyBurned"] = workout.totalEnergyBurned
            record["totalDistance"] = workout.totalDistance ?? 0.0
            record["averageHeartRate"] = workout.averageHeartRate ?? 0.0
            record["xpEarned"] = workout.xpEarned
            record["source"] = workout.source
            
            do {
                _ = try await privateDatabase.save(record)
            } catch {
                print("⚠️ Workout may already exist: \(error)")
            }
        }
        
        print("✅ Created \(workouts.count) workout history records")
    }
    
    // MARK: - Activity Feed
    
    /// Seed activity feed with realistic data
    func seedActivityFeed() async throws {
        let userID = try await getCurrentUserID()
        guard let persona = getPersona(for: userID) else {
            throw SeederError.personaNotFound
        }
        
        let activities = createActivityFeed(for: persona, userID: userID)
        
        for activity in activities {
            let record = CKRecord(recordType: "ActivityFeed")
            record["id"] = activity.id
            record["userID"] = activity.userID
            record["activityType"] = activity.activityType
            record["workoutId"] = activity.workoutId
            record["content"] = activity.content
            record["visibility"] = activity.visibility
            record["createdTimestamp"] = activity.createdTimestamp
            record["expiresAt"] = activity.expiresAt
            record["xpEarned"] = activity.xpEarned
            record["achievementName"] = activity.achievementName
            
            do {
                _ = try await publicDatabase.save(record)
            } catch {
                print("⚠️ Activity may already exist: \(error)")
            }
        }
        
        print("✅ Created \(activities.count) activity feed items")
    }
    
    // MARK: - Clean Up
    
    /// Remove all test data for current user
    func cleanupCurrentUserData() async throws {
        let userID = try await getCurrentUserID()
        
        // Delete from public database
        let publicTypes = ["UserProfile", "ActivityFeed", "WorkoutKudos", "WorkoutComments"]
        for recordType in publicTypes {
            try await deleteRecords(ofType: recordType, in: publicDatabase, for: userID)
        }
        
        // Delete from private database
        let privateTypes = ["WorkoutHistory", "Users"]
        for recordType in privateTypes {
            try await deleteRecords(ofType: recordType, in: privateDatabase, for: userID)
        }
        
        print("✅ Cleaned up all data for current user")
    }
    
    // MARK: - Helper Methods
    
    private func getPersona(for userID: String) -> TestAccountPersona? {
        let registry = UserDefaults.standard.dictionary(forKey: "TestAccountRegistry") ?? [:]
        
        for (personaRaw, storedID) in registry {
            if storedID as? String == userID,
               let persona = TestAccountPersona(rawValue: personaRaw) {
                return persona
            }
        }
        
        return nil
    }
    
    private func getStoredUserID(for persona: TestAccountPersona) -> String? {
        let registry = UserDefaults.standard.dictionary(forKey: "TestAccountRegistry") ?? [:]
        return registry[persona.rawValue] as? String
    }
    
    private func createProfile(for persona: TestAccountPersona, userID: String) -> UserProfile {
        UserProfile(
            id: userID,
            userID: userID,
            username: persona.username,
            bio: persona.bio,
            workoutCount: persona.workoutCount,
            totalXP: persona.totalXP,
            createdTimestamp: Date().addingTimeInterval(-Double(persona.joinedDaysAgo * 24 * 3600)),
            modifiedTimestamp: Date(),
            isVerified: persona.isVerified,
            privacyLevel: .publicProfile,
            profileImageURL: nil,
            headerImageURL: nil
        )
    }
    
    private func getSocialRelationships(for persona: TestAccountPersona) -> [(targetPersona: TestAccountPersona, type: String)] {
        switch persona {
        case .athlete:
            return [
                (.influencer, "mutual"),
                (.coach, "following"),
                (.casual, "follower")
            ]
        case .beginner:
            return [
                (.coach, "following"),
                (.influencer, "following"),
                (.athlete, "following")
            ]
        case .influencer:
            return [
                (.athlete, "mutual"),
                (.coach, "mutual"),
                (.beginner, "follower"),
                (.casual, "follower")
            ]
        case .coach:
            return [
                (.influencer, "mutual"),
                (.athlete, "follower"),
                (.beginner, "follower")
            ]
        case .casual:
            return [
                (.athlete, "following"),
                (.influencer, "following")
            ]
        }
    }
    
    private func createFollowRelationship(from followerID: String, to followingID: String, type: String) async throws {
        // Create the follow relationship
        let relationshipID = "\(followerID)_follows_\(followingID)"
        let record = CKRecord(recordType: "UserRelationship", recordID: CKRecord.ID(recordName: relationshipID))
        record["followerID"] = followerID
        record["followingID"] = followingID
        record["status"] = "active"
        record["createdTimestamp"] = Date()
        record["notificationsEnabled"] = true
        
        do {
            _ = try await publicDatabase.save(record)
            
            // If mutual, create reverse relationship
            if type == "mutual" {
                let reverseID = "\(followingID)_follows_\(followerID)"
                let reverseRecord = CKRecord(recordType: "UserRelationship", recordID: CKRecord.ID(recordName: reverseID))
                reverseRecord["followerID"] = followingID
                reverseRecord["followingID"] = followerID
                reverseRecord["status"] = "active"
                reverseRecord["createdTimestamp"] = Date()
                reverseRecord["notificationsEnabled"] = true
                
                _ = try await publicDatabase.save(reverseRecord)
            }
        } catch {
            print("⚠️ Relationship may already exist: \(error)")
        }
    }
    
    private func createWorkoutHistory(for persona: TestAccountPersona) -> [Workout] {
        var workouts: [Workout] = []
        let workoutTypes = getWorkoutTypes(for: persona)
        let daysBack = min(persona.joinedDaysAgo, 90) // Last 90 days max
        
        for dayOffset in 0..<daysBack {
            // Random chance of workout on each day
            guard Int.random(in: 0..<100) < getWorkoutFrequency(for: persona) else { continue }
            
            let workoutType = workoutTypes.randomElement() ?? "Running"
            let date = Date().addingTimeInterval(-Double(dayOffset * 24 * 3600))
            
            let workout = createWorkout(
                type: workoutType,
                date: date,
                persona: persona
            )
            
            workouts.append(workout)
        }
        
        return workouts.reversed() // Oldest first
    }
    
    private func getWorkoutTypes(for persona: TestAccountPersona) -> [String] {
        switch persona {
        case .athlete:
            return ["Running", "Cycling", "Swimming", "Core Training"]
        case .beginner:
            return ["Walking", "Elliptical", "Strength Training"]
        case .influencer:
            return ["HIIT", "Strength Training", "Yoga", "Running", "CrossFit"]
        case .coach:
            return ["Running", "Strength Training", "Rowing", "Swimming"]
        case .casual:
            return ["Walking", "Cycling", "Golf", "Tennis"]
        }
    }
    
    private func getWorkoutFrequency(for persona: TestAccountPersona) -> Int {
        switch persona {
        case .athlete: return 85
        case .beginner: return 40
        case .influencer: return 90
        case .coach: return 70
        case .casual: return 30
        }
    }
    
    private func createWorkout(type: String, date: Date, persona: TestAccountPersona) -> Workout {
        let duration = getTypicalDuration(for: type, persona: persona)
        let calories = getTypicalCalories(for: type, duration: duration, persona: persona)
        let distance = getTypicalDistance(for: type, duration: duration, persona: persona)
        let heartRate = getTypicalHeartRate(for: type, persona: persona)
        
        // Create workout first to calculate XP
        let workout = Workout(
            id: UUID(),
            workoutType: type,
            startDate: date,
            endDate: date.addingTimeInterval(duration),
            duration: duration,
            totalEnergyBurned: calories,
            totalDistance: distance ?? 0,
            averageHeartRate: heartRate ?? 0,
            followersEarned: 0, // Deprecated
            xpEarned: 0, // Will calculate next
            source: "FameFit"
        )
        
        // Calculate XP based on persona's typical performance
        let xpEarned = XPCalculator.calculateXP(for: workout, currentStreak: Int.random(in: 0...30))
        
        // Return workout with calculated XP
        return Workout(
            id: workout.id,
            workoutType: workout.workoutType,
            startDate: workout.startDate,
            endDate: workout.endDate,
            duration: workout.duration,
            totalEnergyBurned: workout.totalEnergyBurned,
            totalDistance: workout.totalDistance ?? 0,
            averageHeartRate: workout.averageHeartRate ?? 0,
            followersEarned: 0,
            xpEarned: xpEarned,
            source: workout.source
        )
    }
    
    private func getTypicalDuration(for type: String, persona: TestAccountPersona) -> TimeInterval {
        let baseDuration: TimeInterval = {
            switch type {
            case "Running": return 30 * 60
            case "Walking": return 45 * 60
            case "Cycling": return 60 * 60
            case "Swimming": return 40 * 60
            case "HIIT": return 25 * 60
            case "Strength Training": return 45 * 60
            case "Yoga": return 60 * 60
            case "Golf": return 180 * 60
            case "Tennis": return 90 * 60
            default: return 30 * 60
            }
        }()
        
        let multiplier: Double = {
            switch persona {
            case .athlete: return 1.5
            case .beginner: return 0.7
            case .influencer: return 1.2
            case .coach: return 1.3
            case .casual: return 0.9
            }
        }()
        
        return baseDuration * multiplier * Double.random(in: 0.8...1.2)
    }
    
    private func getTypicalCalories(for type: String, duration: TimeInterval, persona: TestAccountPersona) -> Double {
        let caloriesPerMinute: Double = {
            switch type {
            case "Running": return 12
            case "Walking": return 5
            case "Cycling": return 10
            case "Swimming": return 11
            case "HIIT": return 15
            case "Strength Training": return 8
            case "Yoga": return 4
            case "Golf": return 3
            case "Tennis": return 8
            default: return 7
            }
        }()
        
        let fitnessMultiplier: Double = {
            switch persona {
            case .athlete: return 1.3
            case .beginner: return 0.8
            case .influencer: return 1.1
            case .coach: return 1.2
            case .casual: return 0.9
            }
        }()
        
        return (duration / 60) * caloriesPerMinute * fitnessMultiplier
    }
    
    private func getTypicalDistance(for type: String, duration: TimeInterval, persona: TestAccountPersona) -> Double? {
        guard ["Running", "Walking", "Cycling", "Swimming"].contains(type) else { return nil }
        
        let speedKmPerHour: Double = {
            switch (type, persona) {
            case ("Running", .athlete): return 15
            case ("Running", .influencer): return 12
            case ("Running", .coach): return 13
            case ("Running", _): return 9
            case ("Walking", _): return 5
            case ("Cycling", .athlete): return 35
            case ("Cycling", _): return 25
            case ("Swimming", .athlete): return 4
            case ("Swimming", _): return 2.5
            default: return 10
            }
        }()
        
        return (duration / 3600) * speedKmPerHour * 1000 // Convert to meters
    }
    
    private func getTypicalHeartRate(for type: String, persona: TestAccountPersona) -> Double? {
        let baseHeartRate: Double = {
            switch type {
            case "Running": return 150
            case "Walking": return 100
            case "Cycling": return 140
            case "Swimming": return 145
            case "HIIT": return 165
            case "Strength Training": return 120
            case "Yoga": return 85
            case "Golf": return 90
            case "Tennis": return 130
            default: return 110
            }
        }()
        
        let fitnessAdjustment: Double = {
            switch persona {
            case .athlete: return -10
            case .beginner: return 10
            case .influencer: return -5
            case .coach: return -8
            case .casual: return 5
            }
        }()
        
        return baseHeartRate + fitnessAdjustment + Double.random(in: -10...10)
    }
    
    private func createActivityFeed(for persona: TestAccountPersona, userID: String) -> [ActivityFeedItem] {
        var activities: [ActivityFeedItem] = []
        
        // Recent workout activities
        let recentWorkouts = createWorkoutHistory(for: persona).suffix(5)
        for workout in recentWorkouts {
            let content = ActivityFeedContent(
                title: "Completed a \(workout.workoutType) workout!",
                subtitle: "Duration: \(Int(workout.duration / 60)) min | \(Int(workout.totalEnergyBurned)) cal",
                details: [
                    "workoutType": workout.workoutType,
                    "duration": String(workout.duration),
                    "calories": String(workout.totalEnergyBurned),
                    "xpEarned": String(workout.xpEarned ?? 0)
                ]
            )
            
            let contentData = try! JSONEncoder().encode(content)
            let activity = ActivityFeedItem(
                id: UUID().uuidString,
                userID: userID,
                activityType: "workout",
                workoutId: workout.id.uuidString,
                content: String(data: contentData, encoding: .utf8) ?? "",
                visibility: "public",
                createdTimestamp: workout.endDate,
                expiresAt: workout.endDate.addingTimeInterval(90 * 24 * 3600),
                xpEarned: workout.xpEarned,
                achievementName: nil
            )
            
            activities.append(activity)
        }
        
        // Add some achievements
        if persona.totalXP > 10_000 {
            let achievementContent = ActivityFeedContent(
                title: "Earned the 'Rising Star' achievement!",
                subtitle: "Reached 10,000 XP",
                details: ["achievementName": "Rising Star", "xpRequired": "10000"]
            )
            
            let contentData = try! JSONEncoder().encode(achievementContent)
            let achievement = ActivityFeedItem(
                id: UUID().uuidString,
                userID: userID,
                activityType: "achievement",
                workoutId: nil,
                content: String(data: contentData, encoding: .utf8) ?? "",
                visibility: "public",
                createdTimestamp: Date().addingTimeInterval(-7 * 24 * 3600),
                expiresAt: Date().addingTimeInterval(83 * 24 * 3600),
                xpEarned: 0,
                achievementName: "Rising Star"
            )
            
            activities.append(achievement)
        }
        
        return activities
    }
    
    private func deleteRecords(ofType recordType: String, in database: CKDatabase, for userID: String) async throws {
        let predicate = NSPredicate(format: "userID == %@", userID)
        let query = CKQuery(recordType: recordType, predicate: predicate)
        
        do {
            let (results, _) = try await database.records(matching: query)
            
            for (recordID, _) in results {
                try await database.deleteRecord(withID: recordID)
            }
            
            print("✅ Deleted \(results.count) \(recordType) records")
        } catch {
            print("⚠️ Error deleting \(recordType): \(error)")
        }
    }
}

// MARK: - Error Types

enum SeederError: LocalizedError {
    case personaNotFound
    case noTestAccounts
    
    var errorDescription: String? {
        switch self {
        case .personaNotFound:
            return "No persona found for current user. Register this account first."
        case .noTestAccounts:
            return "No test accounts registered. Set up test accounts first."
        }
    }
}
#endif