//
//  MockCKDatabaseWithValidation.swift
//  FameFitTests
//
//  Mock CKDatabase that validates records match production CloudKit schema
//

import CloudKit
@testable import FameFit

/// Mock CKDatabase that validates CloudKit record schema
class MockCKDatabaseWithValidation {
    
    // MARK: - CloudKit Schema Definition
    
    /// Expected schema for Workouts record type based on production CloudKit
    private let workoutsSchema: [String: FieldDefinition] = [
        "id": FieldDefinition(type: .string, required: true, queryable: true, sortable: true),
        "userID": FieldDefinition(type: .string, required: true, queryable: true, sortable: false),
        "workoutType": FieldDefinition(type: .string, required: true, queryable: true, sortable: true),
        "startDate": FieldDefinition(type: .dateTime, required: true, queryable: true, sortable: true),
        "endDate": FieldDefinition(type: .dateTime, required: true, queryable: true, sortable: true),
        "duration": FieldDefinition(type: .double, required: true, queryable: true, sortable: false),
        "totalEnergyBurned": FieldDefinition(type: .double, required: true, queryable: true, sortable: false),
        "totalDistance": FieldDefinition(type: .double, required: false, queryable: true, sortable: false),
        "averageHeartRate": FieldDefinition(type: .double, required: false, queryable: true, sortable: false),
        "followersEarned": FieldDefinition(type: .int64, required: true, queryable: true, sortable: false),
        "xpEarned": FieldDefinition(type: .int64, required: false, queryable: true, sortable: false),
        "source": FieldDefinition(type: .string, required: false, queryable: true, sortable: false),
        "groupWorkoutID": FieldDefinition(type: .string, required: false, queryable: false, sortable: false)
    ]
    
    // MARK: - Properties
    
    var savedRecords: [CKRecord] = []
    var shouldFailSave = false
    var validationErrors: [String] = []
    
    // MARK: - Field Definition
    
    struct FieldDefinition {
        enum FieldType {
            case string
            case int64
            case double
            case dateTime
            case reference
        }
        
        let type: FieldType
        let required: Bool
        let queryable: Bool
        let sortable: Bool
    }
    
    // MARK: - Save Method (mimics CKDatabase.save)
    
    func save(_ record: CKRecord) async throws -> CKRecord {
        // Clear previous validation errors
        validationErrors.removeAll()
        
        // Validate based on record type
        switch record.recordType {
        case "Workouts":
            try validateWorkoutRecord(record)
        case "UserProfiles":
            // Add UserProfiles schema validation if needed
            break
        default:
            validationErrors.append("Unknown record type: \(record.recordType)")
        }
        
        // If validation failed, throw error
        if !validationErrors.isEmpty {
            throw MockCloudKitError.validationFailed(errors: validationErrors)
        }
        
        // If configured to fail, simulate CloudKit error
        if shouldFailSave {
            throw CKError(CKError.Code.networkFailure)
        }
        
        // Save the record
        savedRecords.append(record)
        return record
    }
    
    // MARK: - Validation
    
    private func validateWorkoutRecord(_ record: CKRecord) throws {
        // Check all required fields
        for (fieldName, definition) in workoutsSchema {
            let value = record[fieldName]
            
            // Check required fields
            if definition.required && value == nil {
                validationErrors.append("Missing required field: \(fieldName)")
                continue
            }
            
            // Check field types
            if let value = value {
                switch definition.type {
                case .string:
                    if !(value is String) && !(value is NSString) {
                        validationErrors.append("Field '\(fieldName)' should be String, got \(type(of: value))")
                    }
                case .int64:
                    if !(value is Int64) && !(value is Int) && !(value is NSNumber) {
                        validationErrors.append("Field '\(fieldName)' should be Int64, got \(type(of: value))")
                    }
                case .double:
                    if !(value is Double) && !(value is Float) && !(value is NSNumber) {
                        validationErrors.append("Field '\(fieldName)' should be Double, got \(type(of: value))")
                    }
                case .dateTime:
                    if !(value is Date) && !(value is NSDate) {
                        validationErrors.append("Field '\(fieldName)' should be Date, got \(type(of: value))")
                    }
                case .reference:
                    if !(value is CKRecord.Reference) {
                        validationErrors.append("Field '\(fieldName)' should be CKRecord.Reference, got \(type(of: value))")
                    }
                }
            }
        }
        
        // Check for unexpected fields (warn but don't fail)
        for key in record.allKeys() {
            if !workoutsSchema.keys.contains(key) && !key.starts(with: "___") { // System fields start with ___
                print("⚠️ Warning: Unexpected field '\(key)' not in CloudKit schema")
            }
        }
        
        // Validate specific business rules
        
        // 0. UserID should not be empty
        if let userID = record["userID"] as? String, userID.isEmpty {
            validationErrors.append("Field 'userID' cannot be empty")
        }
        
        // 1. ID field should match a UUID pattern
        if let id = record["id"] as? String {
            let uuidRegex = /^[A-F0-9]{8}-[A-F0-9]{4}-[A-F0-9]{4}-[A-F0-9]{4}-[A-F0-9]{12}$/
            if !id.uppercased().contains(uuidRegex) {
                validationErrors.append("Field 'id' should be a valid UUID string, got: \(id)")
            }
        }
        
        // 2. Duration should be positive
        if let duration = record["duration"] as? Double {
            if duration <= 0 {
                validationErrors.append("Duration must be positive, got: \(duration)")
            }
        }
        
        // 3. Start date should be before end date
        if let startDate = record["startDate"] as? Date,
           let endDate = record["endDate"] as? Date {
            if startDate >= endDate {
                validationErrors.append("Start date must be before end date")
            }
        }
        
        // 4. XP and followers should be non-negative
        if let followersEarned = record["followersEarned"] as? Int64 {
            if followersEarned < 0 {
                validationErrors.append("Followers earned cannot be negative")
            }
        }
        
        if let xpEarned = record["xpEarned"] as? Int64 {
            if xpEarned < 0 {
                validationErrors.append("XP earned cannot be negative")
            }
        }
        
        // 5. Workout type should be a known type
        if let workoutType = record["workoutType"] as? String {
            let knownTypes = ["Running", "Walking", "Cycling", "Swimming", "Yoga", 
                            "Strength Training", "HIIT", "Tennis", "Basketball", 
                            "Soccer", "Dance", "Rowing", "Elliptical", "Other"]
            if !knownTypes.contains(where: { workoutType.contains($0) }) {
                print("⚠️ Warning: Unusual workout type: \(workoutType)")
            }
        }
    }
    
    // MARK: - Query Methods
    
    func records(matching query: CKQuery) async throws -> [CKRecord] {
        // Filter saved records based on query
        return savedRecords.filter { record in
            record.recordType == query.recordType
            // Add predicate matching if needed
        }
    }
    
    // MARK: - Helper Methods
    
    func reset() {
        savedRecords.removeAll()
        validationErrors.removeAll()
        shouldFailSave = false
    }
    
    func lastSavedRecord() -> CKRecord? {
        savedRecords.last
    }
    
    func recordCount() -> Int {
        savedRecords.count
    }
}

// MARK: - Custom Error

enum MockCloudKitError: LocalizedError {
    case validationFailed(errors: [String])
    
    var errorDescription: String? {
        switch self {
        case .validationFailed(let errors):
            return "CloudKit validation failed:\n" + errors.joined(separator: "\n")
        }
    }
}