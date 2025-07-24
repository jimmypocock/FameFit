//
//  CloudKitPushNotificationService.swift
//  FameFit
//
//  Service for sending push notifications through CloudKit
//

import Foundation
import CloudKit

// MARK: - Push Notification Service

final class CloudKitPushNotificationService {
    private let container = CKContainer.default()
    private let privateDatabase: CKDatabase
    
    init() {
        self.privateDatabase = container.privateCloudDatabase
    }
    
    // MARK: - Send Push Notification
    
    /// Sends a push notification to a specific user
    /// - Parameters:
    ///   - userID: The CloudKit user ID to send the notification to
    ///   - request: The push notification request containing all notification data
    func sendPushNotification(to userID: String, request: PushNotificationRequest) async throws {
        // First, check if the user has any active device tokens
        let deviceTokens = try await fetchActiveDeviceTokens(for: userID)
        
        guard !deviceTokens.isEmpty else {
            print("No active device tokens found for user: \(userID)")
            return
        }
        
        // Create the notification info
        let notificationInfo = CKSubscription.NotificationInfo()
        notificationInfo.alertBody = request.body
        notificationInfo.title = request.title
        notificationInfo.subtitle = request.subtitle
        notificationInfo.shouldBadge = request.badge != nil
        notificationInfo.soundName = request.sound
        notificationInfo.category = request.category
        
        // Add custom data
        var customData: [String: String] = [
            "notificationType": request.type.rawValue
        ]
        
        if let metadata = request.metadata {
            for (key, value) in metadata {
                customData[key] = value
            }
        }
        
        // For each device token, we need to use CloudKit Web Services API
        // Since CloudKit framework doesn't directly support sending push notifications,
        // we'll create a server-side component or use CloudKit JS for this
        
        // For now, we'll create a notification record that a server component can process
        try await createPushNotificationRecord(
            userID: userID,
            request: request,
            deviceTokens: deviceTokens
        )
    }
    
    // MARK: - Batch Send
    
    /// Sends push notifications to multiple users
    func sendPushNotifications(to userIDs: [String], request: PushNotificationRequest) async throws {
        // Process in batches to avoid overwhelming the system
        let batchSize = 50
        
        for i in stride(from: 0, to: userIDs.count, by: batchSize) {
            let endIndex = min(i + batchSize, userIDs.count)
            let batch = Array(userIDs[i..<endIndex])
            
            await withTaskGroup(of: Void.self) { group in
                for userID in batch {
                    group.addTask {
                        do {
                            try await self.sendPushNotification(to: userID, request: request)
                        } catch {
                            print("Failed to send notification to \(userID): \(error)")
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Device Token Management
    
    private func fetchActiveDeviceTokens(for userID: String) async throws -> [DeviceTokenRecord] {
        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            NSPredicate(format: "userID == %@", userID),
            NSPredicate(format: "isActive == 1")
        ])
        
        let query = CKQuery(recordType: "DeviceTokens", predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "lastUpdated", ascending: false)]
        
        let results = try await privateDatabase.records(matching: query)
        
        var tokens: [DeviceTokenRecord] = []
        
        for (_, result) in results.matchResults {
            switch result {
            case .success(let record):
                if let token = parseDeviceTokenRecord(from: record) {
                    tokens.append(token)
                }
            case .failure(let error):
                print("Failed to fetch device token: \(error)")
            }
        }
        
        return tokens
    }
    
    private func parseDeviceTokenRecord(from record: CKRecord) -> DeviceTokenRecord? {
        guard let userID = record["userID"] as? String,
              let deviceToken = record["deviceToken"] as? String,
              let platform = record["platform"] as? String,
              let appVersion = record["appVersion"] as? String,
              let osVersion = record["osVersion"] as? String,
              let environment = record["environment"] as? String,
              let lastUpdated = record["lastUpdated"] as? Date,
              let isActive = record["isActive"] as? Int64 else {
            return nil
        }
        
        return DeviceTokenRecord(
            id: record.recordID.recordName,
            userID: userID,
            deviceToken: deviceToken,
            platform: platform,
            appVersion: appVersion,
            osVersion: osVersion,
            environment: environment,
            createdAt: record.creationDate ?? Date(),
            lastUpdated: lastUpdated,
            isActive: isActive == 1
        )
    }
    
    // MARK: - Push Notification Record
    
    /// Creates a push notification record for server-side processing
    private func createPushNotificationRecord(
        userID: String,
        request: PushNotificationRequest,
        deviceTokens: [DeviceTokenRecord]
    ) async throws {
        let record = CKRecord(recordType: "PushNotificationQueue")
        
        record["userID"] = userID
        record["notificationType"] = request.type.rawValue
        record["title"] = request.title
        record["body"] = request.body
        record["subtitle"] = request.subtitle
        record["badge"] = request.badge as? CKRecordValue
        record["sound"] = request.sound
        record["category"] = request.category
        record["threadId"] = request.threadId
        record["deviceTokens"] = deviceTokens.map { $0.deviceToken }
        record["createdAt"] = Date()
        record["status"] = "pending"
        
        // Add metadata as JSON string
        if let metadata = request.metadata,
           let jsonData = try? JSONSerialization.data(withJSONObject: metadata),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            record["metadata"] = jsonString
        }
        
        _ = try await privateDatabase.save(record)
    }
    
    // MARK: - Cleanup
    
    /// Removes inactive device tokens older than the specified days
    func cleanupInactiveDeviceTokens(olderThanDays days: Int = 90) async throws {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
        
        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            NSPredicate(format: "isActive == 0"),
            NSPredicate(format: "lastUpdated < %@", cutoffDate as NSDate)
        ])
        
        let query = CKQuery(recordType: "DeviceTokens", predicate: predicate)
        
        let results = try await privateDatabase.records(matching: query)
        
        var recordIDsToDelete: [CKRecord.ID] = []
        
        for (recordID, result) in results.matchResults {
            if case .success = result {
                recordIDsToDelete.append(recordID)
            }
        }
        
        if !recordIDsToDelete.isEmpty {
            let operation = CKModifyRecordsOperation(
                recordsToSave: nil,
                recordIDsToDelete: recordIDsToDelete
            )
            
            operation.savePolicy = .changedKeys
            operation.database = privateDatabase
            
            try await withCheckedThrowingContinuation { continuation in
                operation.modifyRecordsResultBlock = { result in
                    switch result {
                    case .success:
                        continuation.resume()
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                }
                
                privateDatabase.add(operation)
            }
        }
    }
}

// MARK: - Notification Templates

extension CloudKitPushNotificationService {
    
    /// Creates a push notification request for a new follower
    static func newFollowerNotification(from user: UserProfile, to userID: String) -> PushNotificationRequest {
        return PushNotificationRequest(
            userID: userID,
            type: .newFollower,
            title: "New Follower! 🎉",
            body: "\(user.displayName) is now following your fitness journey",
            metadata: [
                "followerUserId": user.userID,
                "followerUsername": user.username
            ]
        )
    }
    
    /// Creates a push notification request for workout kudos
    static func workoutKudosNotification(
        from user: UserProfile,
        for workoutId: String,
        to userID: String
    ) -> PushNotificationRequest {
        return PushNotificationRequest(
            userID: userID,
            type: .workoutKudos,
            title: "Kudos! 💪",
            body: "\(user.displayName) gave kudos to your workout",
            metadata: [
                "kudosUserId": user.userID,
                "kudosUsername": user.username,
                "workoutId": workoutId
            ],
            category: "WORKOUT_KUDOS"
        )
    }
    
    /// Creates a push notification request for a follow request
    static func followRequestNotification(from user: UserProfile, to userID: String) -> PushNotificationRequest {
        return PushNotificationRequest(
            userID: userID,
            type: .followRequest,
            title: "Follow Request",
            body: "\(user.displayName) wants to follow you",
            metadata: [
                "requesterUserId": user.userID,
                "requesterUsername": user.username
            ],
            category: "FOLLOW_REQUEST"
        )
    }
}