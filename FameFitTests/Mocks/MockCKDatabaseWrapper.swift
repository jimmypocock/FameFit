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
    private let mockCloudKitService: MockCloudKitService

    init(mockDatabase: MockCKDatabase, cloudKitManager: MockCloudKitService) {
        self.mockDatabase = mockDatabase
        mockCloudKitService = cloudKitManager
    }
}

// Extension to handle database operations for WorkoutChallengesService
extension MockCloudKitService {
    func saveChallengeRecord(_ record: CKRecord) async throws -> CKRecord {
        saveCallCount += 1

        // Store the record
        mockRecordsByID[record.recordID.recordName] = record

        // Also store in mock database if available
        // mockDatabase.addRecord(record) // Can't access from extension

        return record
    }

    func fetchChallengeRecord(recordID: CKRecord.ID) async throws -> CKRecord {
        // Check mockRecords first
        if let record = mockRecordsByID[recordID.recordName] {
            return record
        }

        // Try mock database
        // Check in saved records instead
        if let record = mockRecords.first(where: { $0.recordID == recordID }) {
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
