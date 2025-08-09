//
//  WatchCommand.swift
//  FameFit
//
//  CloudKit-based fallback for Watch communication
//

import Foundation
import CloudKit

struct WatchCommand: Codable {
    let id: String
    let userID: String
    let command: String
    let workoutID: String?
    let workoutName: String?
    let workoutType: Int?
    let isHost: Bool?
    let processed: Bool
    
    init(command: String, workoutID: String? = nil, workoutName: String? = nil, 
         workoutType: Int? = nil, isHost: Bool? = nil, userID: String) {
        self.id = UUID().uuidString
        self.userID = userID
        self.command = command
        self.workoutID = workoutID
        self.workoutName = workoutName
        self.workoutType = workoutType
        self.isHost = isHost
        self.processed = false
    }
    
    // Convert to CKRecord
    func toCKRecord() -> CKRecord {
        let record = CKRecord(recordType: "WatchCommands")
        record["id"] = id
        record["userID"] = userID
        record["command"] = command
        record["workoutID"] = workoutID
        record["workoutName"] = workoutName
        if let workoutType = workoutType {
            record["workoutType"] = workoutType as CKRecordValue
        }
        if let isHost = isHost {
            record["isHost"] = isHost ? 1 : 0 as CKRecordValue
        }
        record["processed"] = processed ? 1 : 0 as CKRecordValue
        // creationDate is automatically set by CloudKit
        return record
    }
    
    // Create from CKRecord
    static func fromCKRecord(_ record: CKRecord) -> WatchCommand? {
        guard let id = record["id"] as? String,
              let userID = record["userID"] as? String,
              let command = record["command"] as? String else {
            return nil
        }
        
        var cmd = WatchCommand(
            command: command,
            workoutID: record["workoutID"] as? String,
            workoutName: record["workoutName"] as? String,
            workoutType: record["workoutType"] as? Int,
            isHost: (record["isHost"] as? Int) == 1,
            userID: userID
        )
        cmd.id = id
        cmd.processed = (record["processed"] as? Int) == 1
        // Use system creationDate instead of custom timestamp
        return cmd
    }
}