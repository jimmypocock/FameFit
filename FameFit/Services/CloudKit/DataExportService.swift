//
//  DataExportService.swift
//  FameFit
//
//  Service for exporting user data for GDPR compliance
//

import CloudKit
import Foundation
import SwiftUI

struct ExportedUserData: Codable {
    let exportDate: Date
    let userInfo: UserInfo
    let profile: UserProfileData?
    let workouts: [WorkoutData]
    let xpTransactions: [XPTransactionData]
    let socialFollows: SocialData
    let activityFeed: [ActivityFeedData]
    let comments: [CommentData]
    let kudos: [KudosData]
    let groupWorkouts: [GroupWorkoutData]
    let userSettings: UserSettingsData?
    let activityFeedSettings: ActivityFeedSettingsData?
    let workoutMetrics: [WorkoutMetricsData]
    let workoutChallenges: [WorkoutChallengeData]
    let activityFeedComments: [ActivityFeedCommentData]
    let notifications: [NotificationData]
    
    struct UserInfo: Codable {
        let userID: String
        let username: String?
        let joinDate: Date?
    }
    
    struct UserProfileData: Codable {
        let username: String
        let bio: String?
        let workoutCount: Int
        let totalXP: Int
        let isVerified: Bool
        let privacyLevel: String
        let creationDate: Date
    }
    
    struct WorkoutData: Codable {
        let workoutID: String
        let workoutType: String
        let startDate: Date
        let endDate: Date
        let duration: TimeInterval
        let totalEnergyBurned: Double?
        let totalDistance: Double?
        let averageHeartRate: Double?
        let followersEarned: Int
    }
    
    struct XPTransactionData: Codable {
        let amount: Int
        let type: String
        let reason: String?
        let createdAt: Date
    }
    
    struct SocialData: Codable {
        let followers: [String]
        let following: [String]
    }
    
    struct ActivityFeedData: Codable {
        let feedType: String
        let title: String
        let subtitle: String?
        let createdAt: Date
    }
    
    struct CommentData: Codable {
        let workoutID: String
        let comment: String
        let createdAt: Date
    }
    
    struct KudosData: Codable {
        let workoutID: String
        let workoutOwnerID: String
        let createdAt: Date
    }
    
    struct GroupWorkoutData: Codable, Hashable {
        let groupWorkoutID: String
        let workoutType: String
        let scheduledStart: Date
        let scheduledEnd: Date
        let status: String
        let participantIDs: [String]
    }
    
    struct UserSettingsData: Codable {
        let emailNotifications: Bool
        let pushNotifications: Bool
        let workoutPrivacy: String
        let showWorkoutStats: Bool
    }
    
    struct ActivityFeedSettingsData: Codable {
        let shareActivitiesToFeed: Bool
        let shareWorkouts: Bool
        let shareGroupWorkouts: Bool
        let shareAchievements: Bool
    }
    
    // WorkoutHistoryData removed - doesn't exist as a record type
    
    struct WorkoutMetricsData: Codable {
        let workoutID: String
        let heartRate: Double?
        let distance: Double?
        let pace: Double?
        let timestamp: Date
    }
    
    struct WorkoutChallengeData: Codable {
        let challengeID: String
        let name: String
        let type: String
        let status: String
        let createdAt: Date
        let isCreator: Bool
    }
    
    struct ActivityFeedCommentData: Codable {
        let feedItemID: String
        let comment: String
        let createdAt: Date
    }
    
    struct NotificationData: Codable {
        let type: String
        let message: String
        let createdAt: Date
        let isRead: Bool
    }
}

class DataExportService: ObservableObject {
    private let cloudKitManager: CloudKitService
    @Published var isExporting = false
    @Published var exportProgress: Double = 0
    @Published var exportError: Error?
    
    init(cloudKitManager: CloudKitService) {
        self.cloudKitManager = cloudKitManager
    }
    
    func exportAllUserData() async throws -> Data {
        guard let userID = cloudKitManager.currentUserID else {
            throw FameFitError.userNotAuthenticated
        }
        
        await MainActor.run {
            isExporting = true
            exportProgress = 0
        }
        
        defer {
            Task { @MainActor in
                isExporting = false
            }
        }
        
        FameFitLogger.info("Starting data export for user: \(userID)", category: FameFitLogger.cloudKit)
        
        // Collect all user data
        async let userInfo = fetchUserInfo(userID: userID)
        async let profile = fetchUserProfile(userID: userID)
        async let workouts = fetchWorkouts(userID: userID)
        async let xpTransactions = fetchXPTransactions(userID: userID)
        async let socialData = fetchSocialData(userID: userID)
        async let activityFeed = fetchActivityFeed(userID: userID)
        async let comments = fetchComments(userID: userID)
        async let kudos = fetchKudos(userID: userID)
        async let groupWorkouts = fetchGroupWorkouts(userID: userID)
        async let userSettings = fetchUserSettings(userID: userID)
        async let activityFeedSettings = fetchActivityFeedSettings(userID: userID)
        async let workoutMetrics = fetchWorkoutMetrics(userID: userID)
        async let workoutChallenges = fetchWorkoutChallenges(userID: userID)
        async let activityFeedComments = fetchActivityFeedComments(userID: userID)
        async let notifications = fetchNotifications(userID: userID)
        
        await MainActor.run { exportProgress = 0.1 }
        
        let exportData = ExportedUserData(
            exportDate: Date(),
            userInfo: try await userInfo,
            profile: try? await profile,
            workouts: try await workouts,
            xpTransactions: try await xpTransactions,
            socialFollows: try await socialData,
            activityFeed: try await activityFeed,
            comments: try await comments,
            kudos: try await kudos,
            groupWorkouts: try await groupWorkouts,
            userSettings: try? await userSettings,
            activityFeedSettings: try? await activityFeedSettings,
            workoutMetrics: try await workoutMetrics,
            workoutChallenges: try await workoutChallenges,
            activityFeedComments: try await activityFeedComments,
            notifications: try await notifications
        )
        
        await MainActor.run { exportProgress = 0.9 }
        
        // Convert to JSON
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        let jsonData = try encoder.encode(exportData)
        
        await MainActor.run { exportProgress = 1.0 }
        
        FameFitLogger.info("Data export completed successfully", category: FameFitLogger.cloudKit)
        
        return jsonData
    }
    
    // MARK: - Private Data Fetching Methods
    
    private func fetchUserInfo(userID: String) async throws -> ExportedUserData.UserInfo {
        if let userRecord = cloudKitManager.userRecord {
            return ExportedUserData.UserInfo(
                userID: userID,
                username: userRecord["displayName"] as? String,
                joinDate: userRecord.creationDate
            )
        }
        
        return ExportedUserData.UserInfo(
            userID: userID,
            username: nil,
            joinDate: nil
        )
    }
    
    private func fetchUserProfile(userID: String) async throws -> ExportedUserData.UserProfileData? {
        let predicate = NSPredicate(format: "userID == %@", userID)
        let query = CKQuery(recordType: "UserProfiles", predicate: predicate)
        
        let results = try await cloudKitManager.publicDatabase.records(matching: query)
        
        if let result = results.matchResults.first,
           let record = try? result.1.get() {
            return ExportedUserData.UserProfileData(
                username: record["username"] as? String ?? "",
                bio: record["bio"] as? String,
                workoutCount: record["workoutCount"] as? Int ?? 0,
                totalXP: record["totalXP"] as? Int ?? 0,
                isVerified: record["isVerified"] as? Bool ?? false,
                privacyLevel: record["privacyLevel"] as? String ?? "public",
                creationDate: record.creationDate ?? Date()
            )
        }
        
        return nil
    }
    
    private func fetchWorkouts(userID: String) async throws -> [ExportedUserData.WorkoutData] {
        let predicate = NSPredicate(format: "userID == %@", userID)
        let query = CKQuery(recordType: "Workouts", predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "startDate", ascending: false)]
        
        let results = try await cloudKitManager.privateDatabase.records(matching: query)
        
        await MainActor.run { exportProgress = 0.3 }
        
        return results.matchResults.compactMap { result in
            guard let record = try? result.1.get() else { return nil }
            
            return ExportedUserData.WorkoutData(
                workoutID: record["workoutID"] as? String ?? "",
                workoutType: record["workoutType"] as? String ?? "",
                startDate: record["startDate"] as? Date ?? Date(),
                endDate: record["endDate"] as? Date ?? Date(),
                duration: record["duration"] as? TimeInterval ?? 0,
                totalEnergyBurned: record["totalEnergyBurned"] as? Double,
                totalDistance: record["totalDistance"] as? Double,
                averageHeartRate: record["averageHeartRate"] as? Double,
                followersEarned: record["followersEarned"] as? Int ?? 0
            )
        }
    }
    
    private func fetchXPTransactions(userID: String) async throws -> [ExportedUserData.XPTransactionData] {
        let predicate = NSPredicate(format: "userID == %@", userID)
        let query = CKQuery(recordType: "XPTransactions", predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        
        let results = try await cloudKitManager.privateDatabase.records(matching: query)
        
        await MainActor.run { exportProgress = 0.4 }
        
        return results.matchResults.compactMap { result in
            guard let record = try? result.1.get() else { return nil }
            
            return ExportedUserData.XPTransactionData(
                amount: record["amount"] as? Int ?? 0,
                type: record["type"] as? String ?? "",
                reason: record["reason"] as? String,
                createdAt: record.creationDate ?? Date()
            )
        }
    }
    
    private func fetchSocialData(userID: String) async throws -> ExportedUserData.SocialData {
        // Fetch followers (people who follow this user)
        let followersPredicate = NSPredicate(format: "followingID == %@", userID)
        let followersQuery = CKQuery(recordType: "UserRelationships", predicate: followersPredicate)
        let followersResults = try await cloudKitManager.publicDatabase.records(matching: followersQuery)
        
        let followers: [String] = followersResults.matchResults.compactMap { result in
            guard let record = try? result.1.get() else { return nil }
            return record["followerID"] as? String
        }
        
        // Fetch following (people this user follows)
        let followingPredicate = NSPredicate(format: "followerID == %@", userID)
        let followingQuery = CKQuery(recordType: "UserRelationships", predicate: followingPredicate)
        let followingResults = try await cloudKitManager.publicDatabase.records(matching: followingQuery)
        
        let following: [String] = followingResults.matchResults.compactMap { result in
            guard let record = try? result.1.get() else { return nil }
            return record["followingID"] as? String
        }
        
        await MainActor.run { exportProgress = 0.5 }
        
        return ExportedUserData.SocialData(
            followers: followers,
            following: following
        )
    }
    
    private func fetchActivityFeed(userID: String) async throws -> [ExportedUserData.ActivityFeedData] {
        let predicate = NSPredicate(format: "userID == %@", userID)
        let query = CKQuery(recordType: "ActivityFeed", predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        
        let results = try await cloudKitManager.publicDatabase.records(matching: query)
        
        await MainActor.run { exportProgress = 0.6 }
        
        return results.matchResults.compactMap { result in
            guard let record = try? result.1.get() else { return nil }
            
            return ExportedUserData.ActivityFeedData(
                feedType: record["feedType"] as? String ?? "",
                title: record["title"] as? String ?? "",
                subtitle: record["subtitle"] as? String,
                createdAt: record.creationDate ?? Date()
            )
        }
    }
    
    private func fetchComments(userID: String) async throws -> [ExportedUserData.CommentData] {
        let predicate = NSPredicate(format: "userID == %@", userID)
        let query = CKQuery(recordType: "ActivityFeedComments", predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        
        let results = try await cloudKitManager.publicDatabase.records(matching: query)
        
        await MainActor.run { exportProgress = 0.7 }
        
        return results.matchResults.compactMap { result in
            guard let record = try? result.1.get() else { return nil }
            
            return ExportedUserData.CommentData(
                workoutID: record["workoutID"] as? String ?? "",
                comment: record["comment"] as? String ?? "",
                createdAt: record.creationDate ?? Date()
            )
        }
    }
    
    private func fetchKudos(userID: String) async throws -> [ExportedUserData.KudosData] {
        let predicate = NSPredicate(format: "userID == %@", userID)
        let query = CKQuery(recordType: "WorkoutKudos", predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        
        let results = try await cloudKitManager.publicDatabase.records(matching: query)
        
        await MainActor.run { exportProgress = 0.8 }
        
        return results.matchResults.compactMap { result in
            guard let record = try? result.1.get() else { return nil }
            
            return ExportedUserData.KudosData(
                workoutID: record["workoutID"] as? String ?? "",
                workoutOwnerID: record["workoutOwnerID"] as? String ?? "",
                createdAt: record.creationDate ?? Date()
            )
        }
    }
    
    private func fetchGroupWorkouts(userID: String) async throws -> [ExportedUserData.GroupWorkoutData] {
        // CloudKit doesn't support CONTAINS with OR, so we need two separate queries
        
        // 1. Fetch workouts where user is the host
        let hostPredicate = NSPredicate(format: "hostID == %@", userID)
        let hostQuery = CKQuery(recordType: "GroupWorkouts", predicate: hostPredicate)
        hostQuery.sortDescriptors = [NSSortDescriptor(key: "scheduledStart", ascending: false)]
        
        let hostResults = try await cloudKitManager.publicDatabase.records(matching: hostQuery)
        
        // 2. Fetch workouts where user is a participant
        // Note: If participantIDs field doesn't support CONTAINS, we might need to handle this differently
        var participantWorkouts: [ExportedUserData.GroupWorkoutData] = []
        do {
            let participantPredicate = NSPredicate(format: "participantIDs CONTAINS %@", userID)
            let participantQuery = CKQuery(recordType: "GroupWorkouts", predicate: participantPredicate)
            participantQuery.sortDescriptors = [NSSortDescriptor(key: "scheduledStart", ascending: false)]
            
            let participantResults = try await cloudKitManager.publicDatabase.records(matching: participantQuery)
            
            participantWorkouts = participantResults.matchResults.compactMap { result in
                guard let record = try? result.1.get() else { return nil }
                
                return ExportedUserData.GroupWorkoutData(
                    groupWorkoutID: record["groupWorkoutID"] as? String ?? "",
                    workoutType: record["workoutType"] as? String ?? "",
                    scheduledStart: record["scheduledStart"] as? Date ?? Date(),
                    scheduledEnd: record["scheduledEnd"] as? Date ?? Date(),
                    status: record["status"] as? String ?? "",
                    participantIDs: record["participantIDs"] as? [String] ?? []
                )
            }
        } catch {
            // If CONTAINS query fails, just log it and continue with host workouts only
            FameFitLogger.warning("Could not fetch group workouts where user is participant: \(error)", category: FameFitLogger.cloudKit)
        }
        
        // Convert host results
        let hostWorkouts: [ExportedUserData.GroupWorkoutData] = hostResults.matchResults.compactMap { result in
            guard let record = try? result.1.get() else { return nil }
            
            return ExportedUserData.GroupWorkoutData(
                groupWorkoutID: record["groupWorkoutID"] as? String ?? "",
                workoutType: record["workoutType"] as? String ?? "",
                scheduledStart: record["scheduledStart"] as? Date ?? Date(),
                scheduledEnd: record["scheduledEnd"] as? Date ?? Date(),
                status: record["status"] as? String ?? "",
                participantIDs: record["participantIDs"] as? [String] ?? []
            )
        }
        
        // Combine and remove duplicates
        let allWorkouts = hostWorkouts + participantWorkouts
        let uniqueWorkouts = Array(Set(allWorkouts))
        
        // Sort by date
        return uniqueWorkouts.sorted { $0.scheduledStart > $1.scheduledStart }
    }
    
    private func fetchUserSettings(userID: String) async throws -> ExportedUserData.UserSettingsData? {
        let predicate = NSPredicate(format: "userID == %@", userID)
        let query = CKQuery(recordType: "UserSettings", predicate: predicate)
        
        let results = try await cloudKitManager.privateDatabase.records(matching: query)
        
        if let result = results.matchResults.first,
           let record = try? result.1.get() {
            return ExportedUserData.UserSettingsData(
                emailNotifications: record["emailNotifications"] as? Bool ?? false,
                pushNotifications: record["pushNotifications"] as? Bool ?? false,
                workoutPrivacy: record["workoutPrivacy"] as? String ?? "public",
                showWorkoutStats: record["showWorkoutStats"] as? Bool ?? true
            )
        }
        
        return nil
    }
    
    private func fetchActivityFeedSettings(userID: String) async throws -> ExportedUserData.ActivityFeedSettingsData? {
        let predicate = NSPredicate(format: "userID == %@", userID)
        let query = CKQuery(recordType: "ActivityFeedSettings", predicate: predicate)
        
        let results = try await cloudKitManager.privateDatabase.records(matching: query)
        
        if let result = results.matchResults.first,
           let record = try? result.1.get() {
            return ExportedUserData.ActivityFeedSettingsData(
                shareActivitiesToFeed: record["shareActivitiesToFeed"] as? Bool ?? true,
                shareWorkouts: record["shareWorkouts"] as? Bool ?? true,
                shareGroupWorkouts: record["shareGroupWorkouts"] as? Bool ?? true,
                shareAchievements: record["shareAchievements"] as? Bool ?? true
            )
        }
        
        return nil
    }
    
    // fetchWorkoutHistory removed - WorkoutHistory record type doesn't exist
    
    private func fetchWorkoutMetrics(userID: String) async throws -> [ExportedUserData.WorkoutMetricsData] {
        let predicate = NSPredicate(format: "userID == %@", userID)
        let query = CKQuery(recordType: "WorkoutMetrics", predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        
        let results = try await cloudKitManager.privateDatabase.records(matching: query)
        
        return results.matchResults.compactMap { result in
            guard let record = try? result.1.get() else { return nil }
            
            return ExportedUserData.WorkoutMetricsData(
                workoutID: record["workoutID"] as? String ?? "",
                heartRate: record["heartRate"] as? Double,
                distance: record["distance"] as? Double,
                pace: record["pace"] as? Double,
                timestamp: record.creationDate ?? Date()
            )
        }
    }
    
    private func fetchWorkoutChallenges(userID: String) async throws -> [ExportedUserData.WorkoutChallengeData] {
        // Fetch challenges where user is creator or participant
        let creatorPredicate = NSPredicate(format: "creatorID == %@", userID)
        let query = CKQuery(recordType: "WorkoutChallenges", predicate: creatorPredicate)
        
        let results = try await cloudKitManager.publicDatabase.records(matching: query)
        
        return results.matchResults.compactMap { result in
            guard let record = try? result.1.get() else { return nil }
            
            return ExportedUserData.WorkoutChallengeData(
                challengeID: record["challengeID"] as? String ?? "",
                name: record["name"] as? String ?? "",
                type: record["type"] as? String ?? "",
                status: record["status"] as? String ?? "",
                createdAt: record.creationDate ?? Date(),
                isCreator: true
            )
        }
    }
    
    private func fetchActivityFeedComments(userID: String) async throws -> [ExportedUserData.ActivityFeedCommentData] {
        let predicate = NSPredicate(format: "userID == %@", userID)
        let query = CKQuery(recordType: "ActivityFeedComments", predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        
        let results = try await cloudKitManager.publicDatabase.records(matching: query)
        
        return results.matchResults.compactMap { result in
            guard let record = try? result.1.get() else { return nil }
            
            return ExportedUserData.ActivityFeedCommentData(
                feedItemID: record["feedItemID"] as? String ?? "",
                comment: record["comment"] as? String ?? "",
                createdAt: record.creationDate ?? Date()
            )
        }
    }
    
    private func fetchNotifications(userID: String) async throws -> [ExportedUserData.NotificationData] {
        let predicate = NSPredicate(format: "userID == %@", userID)
        let query = CKQuery(recordType: "NotificationHistory", predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        
        let results = try await cloudKitManager.privateDatabase.records(matching: query)
        
        return results.matchResults.compactMap { result in
            guard let record = try? result.1.get() else { return nil }
            
            return ExportedUserData.NotificationData(
                type: record["type"] as? String ?? "",
                message: record["message"] as? String ?? "",
                createdAt: record.creationDate ?? Date(),
                isRead: record["isRead"] as? Bool ?? false
            )
        }
    }
}

// MARK: - SwiftUI Export View

struct DataExportView: View {
    @StateObject private var exportService: DataExportService
    @State private var showExportSheet = false
    @State private var exportedData: Data?
    @State private var showError = false
    
    init(cloudKitManager: CloudKitService) {
        _exportService = StateObject(wrappedValue: DataExportService(cloudKitManager: cloudKitManager))
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "square.and.arrow.down")
                .font(.system(size: 50))
                .foregroundColor(.blue)
            
            Text("Export Your Data")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Download all your FameFit data in JSON format. This includes your profile, workouts, achievements, and social connections.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            if exportService.isExporting {
                ProgressView(value: exportService.exportProgress)
                    .progressViewStyle(LinearProgressViewStyle())
                    .padding(.horizontal)
                
                Text("Exporting... \(Int(exportService.exportProgress * 100))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                Button(action: exportData) {
                    Label("Export My Data", systemImage: "square.and.arrow.down")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(10)
                }
                .padding(.horizontal)
            }
            
            Text("Your data will be exported as a JSON file that you can save and review.")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal)
        }
        .padding()
        .sheet(isPresented: $showExportSheet) {
            if let data = exportedData,
               let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                let fileName = "FameFit_Export_\(Date().timeIntervalSince1970).json"
                let fileURL = documentsPath.appendingPathComponent(fileName)
                if (try? data.write(to: fileURL)) != nil {
                    ExportDataSheet(items: [fileURL])
                } else {
                    Text("Failed to prepare export file")
                }
            } else {
                Text("No data to export")
            }
        }
        .alert("Export Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(exportService.exportError?.localizedDescription ?? "Failed to export data")
        }
    }
    
    private func exportData() {
        Task {
            do {
                exportedData = try await exportService.exportAllUserData()
                showExportSheet = true
            } catch {
                exportService.exportError = error
                showError = true
            }
        }
    }
}

// MARK: - Helper Types

// Using a simple URL-based export instead of NSItemProviderWriting
struct ExportDataSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}