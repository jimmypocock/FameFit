//
//  BulkPrivacyUpdateService.swift
//  FameFit
//
//  Service for managing bulk privacy updates on shared activities
//

import Foundation
import CloudKit
import Combine

// MARK: - Bulk Privacy Update Service Protocol

protocol BulkPrivacyUpdateServicing: AnyObject {
    func updatePrivacyForAllActivities(to privacy: WorkoutPrivacy) async throws -> Int
    func updatePrivacyForActivities(activityIDs: [String], to privacy: WorkoutPrivacy) async throws -> Int
    func updatePrivacyForActivitiesByType(_ type: String, to privacy: WorkoutPrivacy) async throws -> Int
    func updatePrivacyForActivitiesInDateRange(from startDate: Date, to endDate: Date, privacy: WorkoutPrivacy) async throws -> Int
    var progressPublisher: AnyPublisher<BulkUpdateProgress, Never> { get }
}

// MARK: - Bulk Update Progress

struct BulkUpdateProgress {
    let total: Int
    let completed: Int
    let failed: Int
    let currentActivity: String?
    
    var percentComplete: Double {
        guard total > 0 else { return 0 }
        return Double(completed) / Double(total) * 100
    }
    
    var isComplete: Bool {
        completed + failed >= total
    }
}

// MARK: - Implementation

final class BulkPrivacyUpdateService: BulkPrivacyUpdateServicing {
    private let cloudKitManager: any CloudKitManaging
    private let activityFeedService: ActivityFeedServicing
    private let publicDatabase: CKDatabase
    private let progressSubject = CurrentValueSubject<BulkUpdateProgress, Never>(
        BulkUpdateProgress(total: 0, completed: 0, failed: 0, currentActivity: nil)
    )
    
    var progressPublisher: AnyPublisher<BulkUpdateProgress, Never> {
        progressSubject.eraseToAnyPublisher()
    }
    
    init(cloudKitManager: any CloudKitManaging, activityFeedService: ActivityFeedServicing) {
        self.cloudKitManager = cloudKitManager
        self.activityFeedService = activityFeedService
        self.publicDatabase = CKContainer(identifier: "iCloud.com.jimmypocock.FameFit").publicCloudDatabase
    }
    
    // MARK: - Update All Activities
    
    func updatePrivacyForAllActivities(to privacy: WorkoutPrivacy) async throws -> Int {
        guard let userID = cloudKitManager.currentUserID else {
            throw NSError(domain: "BulkPrivacyUpdate", code: 1, userInfo: [NSLocalizedDescriptionKey: "No user ID available"])
        }
        
        // Fetch all user's activities
        let predicate = NSPredicate(format: "userID == %@", userID)
        let query = CKQuery(recordType: "FeedActivities", predicate: predicate)
        
        return try await performBulkUpdate(query: query, privacy: privacy)
    }
    
    // MARK: - Update Specific Activities
    
    func updatePrivacyForActivities(activityIDs: [String], to privacy: WorkoutPrivacy) async throws -> Int {
        guard !activityIDs.isEmpty else { return 0 }
        
        let recordIDs = activityIDs.map { CKRecord.ID(recordName: $0) }
        let records = try await fetchRecords(with: recordIDs)
        
        return try await updateRecords(records, privacy: privacy)
    }
    
    // MARK: - Update Activities by Type
    
    func updatePrivacyForActivitiesByType(_ type: String, to privacy: WorkoutPrivacy) async throws -> Int {
        guard let userID = cloudKitManager.currentUserID else {
            throw NSError(domain: "BulkPrivacyUpdate", code: 1, userInfo: [NSLocalizedDescriptionKey: "No user ID available"])
        }
        
        let predicate = NSPredicate(format: "userID == %@ AND activityType == %@", userID, type)
        let query = CKQuery(recordType: "FeedActivities", predicate: predicate)
        
        return try await performBulkUpdate(query: query, privacy: privacy)
    }
    
    // MARK: - Update Activities by Date Range
    
    func updatePrivacyForActivitiesInDateRange(from startDate: Date, to endDate: Date, privacy: WorkoutPrivacy) async throws -> Int {
        guard let userID = cloudKitManager.currentUserID else {
            throw NSError(domain: "BulkPrivacyUpdate", code: 1, userInfo: [NSLocalizedDescriptionKey: "No user ID available"])
        }
        
        let predicate = NSPredicate(
            format: "userID == %@ AND timestamp >= %@ AND timestamp <= %@",
            userID,
            startDate as NSDate,
            endDate as NSDate
        )
        let query = CKQuery(recordType: "FeedActivities", predicate: predicate)
        
        return try await performBulkUpdate(query: query, privacy: privacy)
    }
    
    // MARK: - Private Methods
    
    private func performBulkUpdate(query: CKQuery, privacy: WorkoutPrivacy) async throws -> Int {
        // Fetch all matching records
        var allRecords: [CKRecord] = []
        var cursor: CKQueryOperation.Cursor?
        
        repeat {
            let results: (matchResults: [(CKRecord.ID, Result<CKRecord, Error>)], queryCursor: CKQueryOperation.Cursor?)
            
            if let cursor = cursor {
                results = try await publicDatabase.records(continuingMatchFrom: cursor)
            } else {
                results = try await publicDatabase.records(matching: query, resultsLimit: 100)
            }
            
            let records = results.matchResults.compactMap { _, result in
                try? result.get()
            }
            
            allRecords.append(contentsOf: records)
            cursor = results.queryCursor
        } while cursor != nil
        
        // Update progress
        progressSubject.send(BulkUpdateProgress(
            total: allRecords.count,
            completed: 0,
            failed: 0,
            currentActivity: nil
        ))
        
        // Perform batch updates
        return try await updateRecords(allRecords, privacy: privacy)
    }
    
    private func fetchRecords(with recordIDs: [CKRecord.ID]) async throws -> [CKRecord] {
        var records: [CKRecord] = []
        
        // CloudKit has a limit on batch fetch size
        let batchSize = 400
        for batch in recordIDs.chunked(into: batchSize) {
            let fetchResults = try await publicDatabase.records(for: batch)
            
            for (_, result) in fetchResults {
                if case .success(let record) = result {
                    records.append(record)
                }
            }
        }
        
        return records
    }
    
    private func updateRecords(_ records: [CKRecord], privacy: WorkoutPrivacy) async throws -> Int {
        guard !records.isEmpty else { return 0 }
        
        var successCount = 0
        var failedCount = 0
        
        // Update records in batches
        let batchSize = 200 // CloudKit modification limit
        for (index, batch) in records.chunked(into: batchSize).enumerated() {
            // Update privacy field on each record
            let updatedRecords = batch.map { record in
                record["privacy"] = privacy.rawValue
                return record
            }
            
            // Update progress with current batch info
            let currentProgress = progressSubject.value
            progressSubject.send(BulkUpdateProgress(
                total: records.count,
                completed: currentProgress.completed,
                failed: currentProgress.failed,
                currentActivity: "Updating batch \(index + 1)..."
            ))
            
            // Save batch to CloudKit
            do {
                let modifyResults = try await publicDatabase.modifyRecords(
                    saving: updatedRecords,
                    deleting: [],
                    savePolicy: .changedKeys
                )
                
                // Count successes and failures
                for (_, result) in modifyResults.saveResults {
                    switch result {
                    case .success:
                        successCount += 1
                    case .failure:
                        failedCount += 1
                    }
                }
                
                // Update progress
                progressSubject.send(BulkUpdateProgress(
                    total: records.count,
                    completed: successCount,
                    failed: failedCount,
                    currentActivity: "Completed batch \(index + 1)"
                ))
            } catch {
                // If entire batch fails, count them all as failed
                failedCount += batch.count
                
                progressSubject.send(BulkUpdateProgress(
                    total: records.count,
                    completed: successCount,
                    failed: failedCount,
                    currentActivity: "Batch \(index + 1) failed"
                ))
                
                print("Failed to update batch: \(error)")
            }
            
            // Add small delay between batches to avoid rate limiting
            if index < records.chunked(into: batchSize).count - 1 {
                try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            }
        }
        
        // Final progress update
        progressSubject.send(BulkUpdateProgress(
            total: records.count,
            completed: successCount,
            failed: failedCount,
            currentActivity: nil
        ))
        
        return successCount
    }
}

// MARK: - Array Extension for Chunking

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
