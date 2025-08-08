//
//  WorkoutChallengeLink.swift
//  FameFit
//
//  Links workouts to challenges (many-to-many relationship)
//

import Foundation
import CloudKit

/// Links a workout to one or more challenges it contributes to
struct WorkoutChallengeLink: Codable, Identifiable {
    let id: String
    
    // Core relationships
    let workoutID: String             // The workout that contributes to the challenge
    let workoutChallengeID: String    // The challenge this workout counts toward
    let userID: String                // User who completed the workout
    
    // Contribution details
    let contributionValue: Double    // How much this workout contributed (distance, calories, etc.)
    let contributionType: String     // "distance", "calories", "duration", etc.
    let workoutDate: Date            // When the workout was completed
    let creationDate: Date      // When this link was created
    
    // Validation
    let verificationStatus: String          // WorkoutVerificationStatus.rawValue
    let verificationTimestamp: Date?        // When it was verified
    let failureReason: String?              // VerificationFailureReason.rawValue if failed
    let verificationAttempts: Int           // Number of auto-verification attempts
    let manualVerificationRequested: Bool   // User requested manual verification
    let manualVerificationNote: String?     // User's note for manual verification
    
    init(
        id: String = UUID().uuidString,
        workoutID: String,
        workoutChallengeID: String,
        userID: String,
        contributionValue: Double,
        contributionType: String,
        workoutDate: Date,
        creationDate: Date = Date(),
        verificationStatus: WorkoutVerificationStatus = .pending,
        verificationTimestamp: Date? = nil,
        failureReason: VerificationFailureReason? = nil,
        verificationAttempts: Int = 0,
        manualVerificationRequested: Bool = false,
        manualVerificationNote: String? = nil
    ) {
        self.id = id
        self.workoutID = workoutID
        self.workoutChallengeID = workoutChallengeID
        self.userID = userID
        self.contributionValue = contributionValue
        self.contributionType = contributionType
        self.workoutDate = workoutDate
        self.creationDate = creationDate
        self.verificationStatus = verificationStatus.rawValue
        self.verificationTimestamp = verificationTimestamp
        self.failureReason = failureReason?.rawValue
        self.verificationAttempts = verificationAttempts
        self.manualVerificationRequested = manualVerificationRequested
        self.manualVerificationNote = manualVerificationNote
    }
}

// MARK: - CloudKit Conversion

extension WorkoutChallengeLink {
    init?(from record: CKRecord) {
        guard record.recordType == "WorkoutChallengeLinks",
              let workoutID = record["workoutID"] as? String,
              let workoutChallengeID = record["workoutChallengeID"] as? String,
              let userID = record["userID"] as? String,
              let contributionValue = record["contributionValue"] as? Double,
              let contributionType = record["contributionType"] as? String,
              let workoutDate = record["workoutDate"] as? Date,
              let creationDate = record.creationDate else {
            return nil
        }
        
        self.id = record.recordID.recordName
        self.workoutID = workoutID
        self.workoutChallengeID = workoutChallengeID
        self.userID = userID
        self.contributionValue = contributionValue
        self.contributionType = contributionType
        self.workoutDate = workoutDate
        self.creationDate = creationDate
        
        // Handle legacy isVerified field for backward compatibility
        if let legacyVerified = record["isVerified"] as? Int64 {
            self.verificationStatus = legacyVerified != 0 ? 
                WorkoutVerificationStatus.autoVerified.rawValue : 
                WorkoutVerificationStatus.pending.rawValue
        } else {
            self.verificationStatus = record["verificationStatus"] as? String ?? 
                WorkoutVerificationStatus.pending.rawValue
        }
        
        self.verificationTimestamp = record["verificationTimestamp"] as? Date
        self.failureReason = record["failureReason"] as? String
        self.verificationAttempts = Int(record["verificationAttempts"] as? Int64 ?? 0)
        self.manualVerificationRequested = (record["manualVerificationRequested"] as? Int64 ?? 0) != 0
        self.manualVerificationNote = record["manualVerificationNote"] as? String
    }
    
    func toCKRecord() -> CKRecord {
        let record = CKRecord(recordType: "WorkoutChallengeLinks", recordID: CKRecord.ID(recordName: id))
        
        record["workoutID"] = workoutID
        record["workoutChallengeID"] = workoutChallengeID
        record["userID"] = userID
        record["contributionValue"] = contributionValue
        record["contributionType"] = contributionType
        record["workoutDate"] = workoutDate
        
        record["verificationStatus"] = verificationStatus
        record["verificationTimestamp"] = verificationTimestamp
        record["failureReason"] = failureReason
        record["verificationAttempts"] = Int64(verificationAttempts)
        record["manualVerificationRequested"] = manualVerificationRequested ? Int64(1) : Int64(0)
        record["manualVerificationNote"] = manualVerificationNote
        
        // Keep legacy field for backward compatibility
        let status = WorkoutVerificationStatus(rawValue: verificationStatus) ?? .pending
        record["isVerified"] = status.countsTowardProgress ? Int64(1) : Int64(0)
        
        return record
    }
}

// MARK: - Challenge Progress Calculation

extension WorkoutChallengeLink {
    /// Groups links by challenge to calculate total progress (only counts verified contributions)
    static func calculateProgress(for links: [WorkoutChallengeLink], workoutChallengeID: String) -> Double {
        return links
            .filter { link in
                let status = WorkoutVerificationStatus(rawValue: link.verificationStatus) ?? .pending
                return link.workoutChallengeID == workoutChallengeID && status.countsTowardProgress
            }
            .reduce(0) { $0 + $1.contributionValue }
    }
    
    /// Groups links by user to calculate individual progress in a challenge
    static func calculateUserProgress(for links: [WorkoutChallengeLink], userID: String, workoutChallengeID: String) -> Double {
        return links
            .filter { link in
                let status = WorkoutVerificationStatus(rawValue: link.verificationStatus) ?? .pending
                return link.userID == userID && link.workoutChallengeID == workoutChallengeID && status.countsTowardProgress
            }
            .reduce(0) { $0 + $1.contributionValue }
    }
    
    /// Gets pending contributions that need verification
    static func pendingContributions(for links: [WorkoutChallengeLink], userID: String) -> [WorkoutChallengeLink] {
        return links.filter { link in
            let status = WorkoutVerificationStatus(rawValue: link.verificationStatus) ?? .pending
            return link.userID == userID && status == .pending
        }
    }
    
    /// Gets all unique workout IDs for a challenge
    static func workoutIDs(for links: [WorkoutChallengeLink], workoutChallengeID: String) -> Set<String> {
        return Set(links
            .filter { $0.workoutChallengeID == workoutChallengeID }
            .map { $0.workoutID })
    }
    
    /// Gets all unique challenge IDs for a workout
    static func workoutChallengeIDs(for links: [WorkoutChallengeLink], workoutID: String) -> Set<String> {
        return Set(links
            .filter { $0.workoutID == workoutID }
            .map { $0.workoutChallengeID })
    }
}

// MARK: - CloudKit Schema Documentation

/*
 CloudKit Record Type: WorkoutChallengeLinks
 
 Core Fields:
 - workoutID (String) - Links to Workout record - QUERYABLE, SORTABLE
 - workoutChallengeID (String) - Links to WorkoutChallenges record - QUERYABLE, SORTABLE
 - userID (String) - User who completed the workout - QUERYABLE
 
 Contribution Fields:
 - contributionValue (Double) - Amount contributed - QUERYABLE
 - contributionType (String) - Type of contribution - QUERYABLE
 - workoutDate (Date/Time) - When workout was done - QUERYABLE, SORTABLE
 - creationDate (Date/Time) - When link was created - QUERYABLE, SORTABLE
 
 Validation Fields:
 - isVerified (Int64) - 1 if verified, 0 if pending
 - verificationTimestamp (Date/Time) - When verified
 
 Indexes Required:
 - workoutID_workoutChallengeID (QUERYABLE) - For finding specific links
 - workoutChallengeID_userID (QUERYABLE) - For user progress in challenge
 - userID_workoutDate (QUERYABLE) - For user's challenge history
 - workoutChallengeID_isVerified (QUERYABLE) - For verified contributions
 - ___recordID (QUERYABLE) - System index
 
 Subscriptions:
 - Challenge participants: Subscribe where workoutChallengeID matches
 - User's challenges: Subscribe where userID matches
 
 Usage:
 - When a workout completes, check active challenges and create links
 - Verify links after workout data is confirmed from HealthKit
 - Use for leaderboards and progress tracking
 */