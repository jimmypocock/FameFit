//
//  MockCKDatabaseWrapper.swift
//  FameFitTests
//
//  Wrapper to make MockCKDatabase compatible with CKDatabase protocols
//

import CloudKit
@testable import FameFit

// A wrapper that makes MockCKDatabase compatible with WorkoutChallengesService
class MockCKDatabaseWrapper {
    private let mockDatabase: MockCKDatabase
    private let mockCloudKitManager: MockCloudKitManager

    init(mockDatabase: MockCKDatabase, cloudKitManager: MockCloudKitManager) {
        self.mockDatabase = mockDatabase
        mockCloudKitManager = cloudKitManager
    }
}

// Extension to handle database operations for WorkoutChallengesService
extension MockCloudKitManager {
    func saveChallengeRecord(_ record: CKRecord) async throws -> CKRecord {
        saveCallCount += 1

        // Store the record
        mockRecords[record.recordID.recordName] = record

        // Also store in mock database if available
        mockPublicDatabase?.addRecord(record)

        return record
    }

    func fetchChallengeRecord(recordID: CKRecord.ID) async throws -> CKRecord {
        // Check mockRecords first
        if let record = mockRecords[recordID.recordName] {
            return record
        }

        // Try mock database
        if let record = try? await mockPublicDatabase?.record(for: recordID) {
            return record
        }

        throw ChallengeError.challengeNotFound
    }

    func queryChallengeRecords(matching _: NSPredicate, limit: Int = 50) async throws -> [CKRecord] {
        // Return mockQueryResults if available
        if !mockQueryResults.isEmpty {
            return Array(mockQueryResults.prefix(limit))
        }

        // Otherwise return empty array
        return []
    }
}
