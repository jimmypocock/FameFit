//
//  MockCKDatabase.swift
//  FameFitTests
//
//  Mock CloudKit database for testing
//

import CloudKit
@testable import FameFit

// MockCKDatabase doesn't inherit from CKDatabase since CKDatabase has no public initializer
class MockCKDatabase {
    // Store records by ID
    private var records: [CKRecord.ID: CKRecord] = [:]
    private var shouldFailSave = false
    private var shouldFailFetch = false
    private var shouldFailQuery = false
    private var saveError: Error?
    private var fetchError: Error?
    private var queryError: Error?

    // Configuration methods
    func setShouldFailSave(_ shouldFail: Bool, error: Error? = nil) {
        shouldFailSave = shouldFail
        saveError = error ?? NSError(
            domain: "MockCKDatabase",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Save failed"]
        )
    }

    func setShouldFailFetch(_ shouldFail: Bool, error: Error? = nil) {
        shouldFailFetch = shouldFail
        fetchError = error ?? NSError(
            domain: "MockCKDatabase",
            code: 2,
            userInfo: [NSLocalizedDescriptionKey: "Fetch failed"]
        )
    }

    func setShouldFailQuery(_ shouldFail: Bool, error: Error? = nil) {
        shouldFailQuery = shouldFail
        queryError = error ?? NSError(
            domain: "MockCKDatabase",
            code: 3,
            userInfo: [NSLocalizedDescriptionKey: "Query failed"]
        )
    }

    // Save operation
    func save(_ record: CKRecord, completionHandler: @escaping (CKRecord?, Error?) -> Void) {
        if shouldFailSave {
            completionHandler(nil, saveError)
        } else {
            records[record.recordID] = record
            completionHandler(record, nil)
        }
    }

    // Fetch operation
    func fetch(withRecordID recordID: CKRecord.ID, completionHandler: @escaping (CKRecord?, Error?) -> Void) {
        if shouldFailFetch {
            completionHandler(nil, fetchError)
        } else if let record = records[recordID] {
            completionHandler(record, nil)
        } else {
            let error = NSError(
                domain: "MockCKDatabase",
                code: 4,
                userInfo: [NSLocalizedDescriptionKey: "Record not found"]
            )
            completionHandler(nil, error)
        }
    }

    // Query operation
    func perform(
        _ query: CKQuery,
        inZoneWith _: CKRecordZone.ID?,
        completionHandler: @escaping ([CKRecord]?, Error?) -> Void
    ) {
        if shouldFailQuery {
            completionHandler(nil, queryError)
        } else {
            // Filter records based on query
            let matchingRecords = records.values.filter { record in
                // Simple matching based on record type
                record.recordType == query.recordType
            }
            completionHandler(Array(matchingRecords), nil)
        }
    }

    // Delete operation
    func delete(withRecordID recordID: CKRecord.ID, completionHandler: @escaping (CKRecord.ID?, Error?) -> Void) {
        records.removeValue(forKey: recordID)
        completionHandler(recordID, nil)
    }

    // Async versions for modern API compatibility
    func save(_ record: CKRecord) async throws -> CKRecord {
        if shouldFailSave {
            throw saveError ?? NSError(
                domain: "MockCKDatabase",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Save failed"]
            )
        }

        records[record.recordID] = record
        return record
    }

    func record(for recordID: CKRecord.ID) async throws -> CKRecord {
        if shouldFailFetch {
            throw fetchError ?? NSError(
                domain: "MockCKDatabase",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Fetch failed"]
            )
        }

        guard let record = records[recordID] else {
            throw NSError(domain: "MockCKDatabase", code: 4, userInfo: [NSLocalizedDescriptionKey: "Record not found"])
        }

        return record
    }

    func records(matching query: CKQuery, resultsLimit: Int = CKQueryOperation.maximumResults) async throws -> [(
        CKRecord.ID,
        Result<CKRecord, Error>
    )] {
        if shouldFailQuery {
            throw queryError ?? NSError(
                domain: "MockCKDatabase",
                code: 3,
                userInfo: [NSLocalizedDescriptionKey: "Query failed"]
            )
        }

        // Filter records based on query
        let matchingRecords = records.values.filter { record in
            // Simple matching based on record type
            record.recordType == query.recordType
        }

        let results: [(CKRecord.ID, Result<CKRecord, Error>)] = Array(matchingRecords.prefix(resultsLimit))
            .map { record in
                (record.recordID, .success(record))
            }

        return results
    }

    // Helper methods for testing
    func addRecord(_ record: CKRecord) {
        records[record.recordID] = record
    }

    func getAllRecords() -> [CKRecord] {
        Array(records.values)
    }

    func clearAllRecords() {
        records.removeAll()
    }
}
