import Foundation
import CloudKit
import os.log

/// Manages CloudKit schema initialization and validation
/// This helps prevent runtime errors by ensuring record types exist
class CloudKitSchemaManager {
    private let container: CKContainer
    private let privateDatabase: CKDatabase
    
    init(container: CKContainer) {
        self.container = container
        self.privateDatabase = container.privateCloudDatabase
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
        
        // Initialize User record type
        initializeUserRecordType { [weak self] success in
            if success {
                FameFitLogger.info("User record type initialized", category: FameFitLogger.cloudKit)
            }
            
            // Initialize WorkoutHistory record type
            self?.initializeWorkoutHistoryRecordType { success in
                if success {
                    FameFitLogger.info("WorkoutHistory record type initialized", category: FameFitLogger.cloudKit)
                    
                    // Mark schema as initialized
                    UserDefaults.standard.set(true, forKey: schemaInitializedKey)
                }
            }
        }
    }
    
    private func initializeUserRecordType(completion: @escaping (Bool) -> Void) {
        // Check if User record type exists by querying
        let query = CKQuery(recordType: "Users", predicate: NSPredicate(value: true))
        
        privateDatabase.fetch(withQuery: query, inZoneWith: nil, desiredKeys: nil, resultsLimit: 1) { result in
            switch result {
            case .success:
                // Record type exists
                completion(true)
                return
            case .failure(let error):
                // Record type doesn't exist, create a dummy record
                if error.localizedDescription.contains("Record type") == true {
                    let dummyRecord = CKRecord(recordType: "Users")
                    dummyRecord["userName"] = "Schema Init"
                    dummyRecord["followerCount"] = 0
                    dummyRecord["totalWorkouts"] = 0
                    dummyRecord["currentStreak"] = 0
                    dummyRecord["joinTimestamp"] = Date()
                    
                    self.privateDatabase.save(dummyRecord) { savedRecord, saveError in
                        if let saveError = saveError {
                            FameFitLogger.error("Failed to initialize User record type", error: saveError, category: FameFitLogger.cloudKit)
                            completion(false)
                        } else {
                            // Delete the dummy record
                            if let recordID = savedRecord?.recordID {
                                self.privateDatabase.delete(withRecordID: recordID) { _, _ in
                                    completion(true)
                                }
                            } else {
                                completion(true)
                            }
                        }
                    }
                } else {
                    completion(false)
                }
            }
        }
    }
    
    private func initializeWorkoutHistoryRecordType(completion: @escaping (Bool) -> Void) {
        // Check if WorkoutHistory record type exists by querying
        let query = CKQuery(recordType: "WorkoutHistory", predicate: NSPredicate(value: true))
        
        privateDatabase.fetch(withQuery: query, inZoneWith: nil, desiredKeys: nil, resultsLimit: 1) { result in
            switch result {
            case .success:
                // Record type exists
                completion(true)
                return
            case .failure(let error):
                // Record type doesn't exist, create a dummy record
                if error.localizedDescription.contains("Record type") == true ||
                   error.localizedDescription.contains("Did not find record type") == true {
                    let dummyRecord = CKRecord(recordType: "WorkoutHistory")
                    dummyRecord["workoutId"] = UUID().uuidString
                    dummyRecord["workoutType"] = "Schema Init"
                    dummyRecord["startDate"] = Date()
                    dummyRecord["endDate"] = Date()
                    dummyRecord["duration"] = 0.0
                    dummyRecord["totalEnergyBurned"] = 0.0
                    dummyRecord["followersEarned"] = 0
                    dummyRecord["source"] = "Schema Init"
                    
                    self.privateDatabase.save(dummyRecord) { savedRecord, saveError in
                        if let saveError = saveError {
                            FameFitLogger.error("Failed to initialize WorkoutHistory record type", error: saveError, category: FameFitLogger.cloudKit)
                            completion(false)
                        } else {
                            // Delete the dummy record
                            if let recordID = savedRecord?.recordID {
                                self.privateDatabase.delete(withRecordID: recordID) { _, _ in
                                    completion(true)
                                }
                            } else {
                                completion(true)
                            }
                        }
                    }
                } else {
                    completion(false)
                }
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