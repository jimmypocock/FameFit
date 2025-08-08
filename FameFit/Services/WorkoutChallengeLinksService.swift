//
//  WorkoutChallengeLinksService.swift
//  FameFit
//
//  Service for managing the many-to-many relationship between workouts and challenges
//

import Foundation
import CloudKit
import HealthKit

// MARK: - Protocol

protocol WorkoutChallengeLinksServicing {
    // Create and manage links
    func createLink(workoutID: String, workoutChallengeID: String, userID: String, contributionValue: Double, contributionType: String, workoutDate: Date) async throws -> WorkoutChallengeLink
    func verifyLink(linkID: String) async throws -> WorkoutChallengeLink
    func deleteLink(linkID: String) async throws
    
    // Verification methods
    func requestManualVerification(linkID: String, note: String?) async throws -> WorkoutChallengeLink
    func approveManualVerification(linkID: String) async throws -> WorkoutChallengeLink
    func verifyWithGracePeriod(linkID: String, challengeEndDate: Date) async throws -> WorkoutChallengeLink
    func retryVerificationWithBackoff(linkID: String) async throws -> WorkoutChallengeLink
    
    // Query links
    func fetchLinks(for workoutChallengeID: String) async throws -> [WorkoutChallengeLink]
    func fetchLinks(for workoutID: String, in workoutChallengeIDs: [String]) async throws -> [WorkoutChallengeLink]
    func fetchUserLinks(userID: String, workoutChallengeID: String) async throws -> [WorkoutChallengeLink]
    func fetchVerifiedLinks(for workoutChallengeID: String) async throws -> [WorkoutChallengeLink]
    
    // Progress calculations
    func calculateTotalProgress(for workoutChallengeID: String) async throws -> Double
    func calculateUserProgress(userID: String, workoutChallengeID: String) async throws -> Double
    func getLeaderboard(for workoutChallengeID: String) async throws -> [(userID: String, progress: Double)]
    
    // Bulk operations for workout completion
    func processWorkoutForChallenges(workout: Workout, userID: String, activeChallengeIDs: [String]) async throws -> [WorkoutChallengeLink]
}

// MARK: - Service Implementation

final class WorkoutChallengeLinksService: WorkoutChallengeLinksServicing {
    
    // MARK: - Properties
    
    private let publicDatabase: CKDatabase
    private let cloudKitManager: any CloudKitManaging
    
    // MARK: - Initialization
    
    init(
        cloudKitManager: any CloudKitManaging,
        publicDatabase: CKDatabase? = nil
    ) {
        self.cloudKitManager = cloudKitManager
        self.publicDatabase = publicDatabase ?? CKContainer.default().publicCloudDatabase
    }
    
    // MARK: - Link Management
    
    func createLink(
        workoutID: String,
        workoutChallengeID: String,
        userID: String,
        contributionValue: Double,
        contributionType: String,
        workoutDate: Date
    ) async throws -> WorkoutChallengeLink {
        FameFitLogger.info("Creating challenge link: workout=\(workoutID), challenge=\(workoutChallengeID)", category: FameFitLogger.data)
        
        // Check if link already exists
        let predicate = NSPredicate(
            format: "workoutID == %@ AND workoutChallengeID == %@ AND userID == %@",
            workoutID, workoutChallengeID, userID
        )
        
        let query = CKQuery(recordType: "WorkoutChallengeLinks", predicate: predicate)
        let existingRecords = try await publicDatabase.records(matching: query, resultsLimit: 1)
        
        if !existingRecords.matchResults.isEmpty {
            FameFitLogger.warning("Link already exists for workout \(workoutID) and challenge \(workoutChallengeID)", category: FameFitLogger.data)
            if let (_, result) = existingRecords.matchResults.first,
               case .success(let record) = result,
               let existingLink = WorkoutChallengeLink(from: record) {
                return existingLink
            }
        }
        
        // Create new link with pending verification status
        let link = WorkoutChallengeLink(
            workoutID: workoutID,
            workoutChallengeID: workoutChallengeID,
            userID: userID,
            contributionValue: contributionValue,
            contributionType: contributionType,
            workoutDate: workoutDate,
            verificationStatus: .pending // Will be verified after HealthKit sync confirms
        )
        
        let record = link.toCKRecord()
        let savedRecord = try await publicDatabase.save(record)
        
        guard let savedLink = WorkoutChallengeLink(from: savedRecord) else {
            throw ChallengeError.saveFailed
        }
        
        FameFitLogger.info("✅ Created challenge link: \(savedLink.id)", category: FameFitLogger.data)
        return savedLink
    }
    
    func verifyLink(linkID: String) async throws -> WorkoutChallengeLink {
        FameFitLogger.info("🔍 Starting verification for challenge link: \(linkID)", category: FameFitLogger.data)
        
        // Fetch the current link
        let recordID = CKRecord.ID(recordName: linkID)
        let record = try await publicDatabase.record(for: recordID)
        
        guard let link = WorkoutChallengeLink(from: record) else {
            throw LinkError.linkNotFound
        }
        
        // Check current verification status
        let currentStatus = WorkoutVerificationStatus(rawValue: link.verificationStatus) ?? .pending
        
        // If already verified, return immediately
        if currentStatus.countsTowardProgress {
            FameFitLogger.info("✅ Link already verified: \(linkID)", category: FameFitLogger.data)
            return link
        }
        
        // If failed too many times, don't retry automatically
        if currentStatus == .failed && link.verificationAttempts >= VerificationConfig.maxAutoVerificationRetries {
            FameFitLogger.warning("⚠️ Link has exceeded max verification attempts: \(linkID)", category: FameFitLogger.data)
            throw VerificationFailureReason.timeout
        }
        
        // Attempt automatic verification
        do {
            let verificationResult = try await performAutomaticVerification(link: link)
            
            // Update the record with verification result
            record["verificationStatus"] = verificationResult.status.rawValue
            record["verificationTimestamp"] = verificationResult.timestamp
            record["verificationAttempts"] = Int64(link.verificationAttempts + 1)
            
            // Update legacy field for backward compatibility
            record["isVerified"] = verificationResult.status.countsTowardProgress ? Int64(1) : Int64(0)
            
            if let failureReason = verificationResult.failureReason {
                record["failureReason"] = failureReason.rawValue
            }
            
            let savedRecord = try await publicDatabase.save(record)
            
            guard let verifiedLink = WorkoutChallengeLink(from: savedRecord) else {
                throw ChallengeError.updateFailed
            }
            
            FameFitLogger.info("✅ Verification complete for link \(linkID): \(verificationResult.status.rawValue)", category: FameFitLogger.data)
            return verifiedLink
            
        } catch {
            // Update attempt count even on failure
            record["verificationAttempts"] = Int64(link.verificationAttempts + 1)
            _ = try? await publicDatabase.save(record)
            
            throw error
        }
    }
    
    // MARK: - Manual Verification
    
    func requestManualVerification(linkID: String, note: String?) async throws -> WorkoutChallengeLink {
        FameFitLogger.info("📝 Manual verification requested for link: \(linkID)", category: FameFitLogger.data)
        
        let recordID = CKRecord.ID(recordName: linkID)
        let record = try await publicDatabase.record(for: recordID)
        
        guard let link = WorkoutChallengeLink(from: record) else {
            throw LinkError.linkNotFound
        }
        
        let currentStatus = WorkoutVerificationStatus(rawValue: link.verificationStatus) ?? .pending
        
        // Check if manual verification can be requested
        guard currentStatus.canRequestManualVerification else {
            FameFitLogger.warning("Cannot request manual verification for status: \(currentStatus.rawValue)", category: FameFitLogger.data)
            throw LinkError.invalidVerificationRequest
        }
        
        // Update record with manual verification request
        record["manualVerificationRequested"] = Int64(1)
        record["manualVerificationNote"] = note
        
        let savedRecord = try await publicDatabase.save(record)
        
        guard let updatedLink = WorkoutChallengeLink(from: savedRecord) else {
            throw ChallengeError.updateFailed
        }
        
        FameFitLogger.info("✅ Manual verification requested for link: \(linkID)", category: FameFitLogger.data)
        
        // TODO: Trigger notification to admin/moderator for review
        
        return updatedLink
    }
    
    func approveManualVerification(linkID: String) async throws -> WorkoutChallengeLink {
        FameFitLogger.info("✅ Approving manual verification for link: \(linkID)", category: FameFitLogger.data)
        
        let recordID = CKRecord.ID(recordName: linkID)
        let record = try await publicDatabase.record(for: recordID)
        
        // Update to manually verified status
        record["verificationStatus"] = WorkoutVerificationStatus.manuallyVerified.rawValue
        record["verificationTimestamp"] = Date()
        record["isVerified"] = Int64(1) // Legacy field
        record["manualVerificationRequested"] = Int64(0) // Clear the request flag
        
        let savedRecord = try await publicDatabase.save(record)
        
        guard let verifiedLink = WorkoutChallengeLink(from: savedRecord) else {
            throw ChallengeError.updateFailed
        }
        
        FameFitLogger.info("✅ Manual verification approved for link: \(linkID)", category: FameFitLogger.data)
        return verifiedLink
    }
    
    // MARK: - Grace Period Verification
    
    func verifyWithGracePeriod(linkID: String, challengeEndDate: Date) async throws -> WorkoutChallengeLink {
        FameFitLogger.info("⏰ Attempting grace period verification for link: \(linkID)", category: FameFitLogger.data)
        
        let recordID = CKRecord.ID(recordName: linkID)
        let record = try await publicDatabase.record(for: recordID)
        
        guard WorkoutChallengeLink(from: record) != nil else {
            throw LinkError.linkNotFound
        }
        
        // Check if within grace period
        let timeSinceChallengeEnd = Date().timeIntervalSince(challengeEndDate)
        guard timeSinceChallengeEnd <= VerificationConfig.challengeEndGracePeriod else {
            FameFitLogger.warning("❌ Grace period expired for link: \(linkID)", category: FameFitLogger.data)
            throw VerificationFailureReason.challengeEnded
        }
        
        // Verify with grace status
        record["verificationStatus"] = WorkoutVerificationStatus.graceVerified.rawValue
        record["verificationTimestamp"] = Date()
        record["isVerified"] = Int64(1) // Legacy field
        
        let savedRecord = try await publicDatabase.save(record)
        
        guard let verifiedLink = WorkoutChallengeLink(from: savedRecord) else {
            throw ChallengeError.updateFailed
        }
        
        FameFitLogger.info("✅ Grace period verification successful for link: \(linkID)", category: FameFitLogger.data)
        return verifiedLink
    }
    
    // MARK: - Verification Retry with Exponential Backoff
    
    func retryVerificationWithBackoff(linkID: String) async throws -> WorkoutChallengeLink {
        FameFitLogger.info("🔄 Retrying verification with backoff for link: \(linkID)", category: FameFitLogger.data)
        
        let recordID = CKRecord.ID(recordName: linkID)
        let record = try await publicDatabase.record(for: recordID)
        
        guard let link = WorkoutChallengeLink(from: record) else {
            throw LinkError.linkNotFound
        }
        
        let attempts = link.verificationAttempts
        
        // Check if we've exceeded max retries
        guard attempts < VerificationConfig.maxAutoVerificationRetries else {
            FameFitLogger.error("❌ Max retry attempts exceeded for link: \(linkID)", category: FameFitLogger.data)
            
            // Mark as failed
            record["verificationStatus"] = WorkoutVerificationStatus.failed.rawValue
            record["failureReason"] = VerificationFailureReason.timeout.rawValue
            _ = try await publicDatabase.save(record)
            
            throw VerificationFailureReason.timeout
        }
        
        // Calculate backoff delay (exponential: 10s, 20s, 40s)
        let backoffDelay = VerificationConfig.retryDelay * pow(2.0, Double(attempts))
        
        FameFitLogger.info("⏳ Waiting \(backoffDelay) seconds before retry attempt \(attempts + 1)", category: FameFitLogger.data)
        
        // Wait with backoff
        try await Task.sleep(nanoseconds: UInt64(backoffDelay * 1_000_000_000))
        
        // Retry verification
        return try await verifyLink(linkID: linkID)
    }
    
    // MARK: - Private Verification Methods
    
    private func performAutomaticVerification(link: WorkoutChallengeLink) async throws -> VerificationResult {
        FameFitLogger.debug("🔬 Performing automatic verification for workout: \(link.workoutID)", category: FameFitLogger.data)
        
        // Fetch the workout record to verify it exists
        let workoutRecordID = CKRecord.ID(recordName: link.workoutID)
        
        do {
            let workoutRecord = try await publicDatabase.record(for: workoutRecordID)
            
            // Verify workout data integrity
            guard let workoutDate = workoutRecord["startDate"] as? Date,
                  let duration = workoutRecord["duration"] as? Double,
                  duration > 0 else {
                FameFitLogger.warning("❌ Invalid workout data for verification", category: FameFitLogger.data)
                return VerificationResult(
                    status: .failed,
                    timestamp: Date(),
                    failureReason: .dataMismatch
                )
            }
            
            // Check if workout date matches link workout date (within reasonable tolerance)
            let dateDifference = abs(workoutDate.timeIntervalSince(link.workoutDate))
            guard dateDifference < 3600 else { // 1 hour tolerance
                FameFitLogger.warning("❌ Workout date mismatch", category: FameFitLogger.data)
                return VerificationResult(
                    status: .failed,
                    timestamp: Date(),
                    failureReason: .dataMismatch
                )
            }
            
            // Verify contribution values are reasonable
            if link.contributionType == "distance" {
                // Check for impossible distance values (e.g., 1000km in one workout)
                guard link.contributionValue < 200_000 else { // 200km max
                    FameFitLogger.warning("❌ Impossible distance value: \(link.contributionValue)", category: FameFitLogger.data)
                    return VerificationResult(
                        status: .failed,
                        timestamp: Date(),
                        failureReason: .impossibleValues
                    )
                }
            } else if link.contributionType == "calories" {
                // Check for impossible calorie values
                guard link.contributionValue < 5000 else { // 5000 calories max
                    FameFitLogger.warning("❌ Impossible calorie value: \(link.contributionValue)", category: FameFitLogger.data)
                    return VerificationResult(
                        status: .failed,
                        timestamp: Date(),
                        failureReason: .impossibleValues
                    )
                }
            }
            
            // If all checks pass, mark as auto-verified
            FameFitLogger.info("✅ Automatic verification successful", category: FameFitLogger.data)
            return VerificationResult(
                status: .autoVerified,
                timestamp: Date(),
                failureReason: nil
            )
            
        } catch {
            FameFitLogger.error("❌ Failed to fetch workout for verification", error: error, category: FameFitLogger.data)
            return VerificationResult(
                status: .failed,
                timestamp: Date(),
                failureReason: .healthKitDataMissing
            )
        }
    }
    
    private struct VerificationResult {
        let status: WorkoutVerificationStatus
        let timestamp: Date
        let failureReason: VerificationFailureReason?
    }
    
    func deleteLink(linkID: String) async throws {
        FameFitLogger.info("Deleting challenge link: \(linkID)", category: FameFitLogger.data)
        
        let recordID = CKRecord.ID(recordName: linkID)
        try await publicDatabase.deleteRecord(withID: recordID)
        
        FameFitLogger.info("✅ Deleted challenge link: \(linkID)", category: FameFitLogger.data)
    }
    
    // MARK: - Query Methods
    
    func fetchLinks(for workoutChallengeID: String) async throws -> [WorkoutChallengeLink] {
        let predicate = NSPredicate(format: "workoutChallengeID == %@", workoutChallengeID)
        let query = CKQuery(recordType: "WorkoutChallengeLinks", predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "workoutDate", ascending: false)]
        
        let records = try await publicDatabase.records(matching: query)
        
        var links: [WorkoutChallengeLink] = []
        for (_, result) in records.matchResults {
            if case .success(let record) = result,
               let link = WorkoutChallengeLink(from: record) {
                links.append(link)
            }
        }
        
        return links
    }
    
    func fetchLinks(for workoutID: String, in workoutChallengeIDs: [String]) async throws -> [WorkoutChallengeLink] {
        guard !workoutChallengeIDs.isEmpty else { return [] }
        
        let predicate = NSPredicate(
            format: "workoutID == %@ AND workoutChallengeID IN %@",
            workoutID, workoutChallengeIDs
        )
        let query = CKQuery(recordType: "WorkoutChallengeLinks", predicate: predicate)
        
        let records = try await publicDatabase.records(matching: query)
        
        var links: [WorkoutChallengeLink] = []
        for (_, result) in records.matchResults {
            if case .success(let record) = result,
               let link = WorkoutChallengeLink(from: record) {
                links.append(link)
            }
        }
        
        return links
    }
    
    func fetchUserLinks(userID: String, workoutChallengeID: String) async throws -> [WorkoutChallengeLink] {
        let predicate = NSPredicate(
            format: "userID == %@ AND workoutChallengeID == %@",
            userID, workoutChallengeID
        )
        let query = CKQuery(recordType: "WorkoutChallengeLinks", predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "workoutDate", ascending: false)]
        
        let records = try await publicDatabase.records(matching: query)
        
        var links: [WorkoutChallengeLink] = []
        for (_, result) in records.matchResults {
            if case .success(let record) = result,
               let link = WorkoutChallengeLink(from: record) {
                links.append(link)
            }
        }
        
        return links
    }
    
    func fetchVerifiedLinks(for workoutChallengeID: String) async throws -> [WorkoutChallengeLink] {
        // Fetch all links for the challenge
        let predicate = NSPredicate(format: "workoutChallengeID == %@", workoutChallengeID)
        let query = CKQuery(recordType: "WorkoutChallengeLinks", predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "workoutDate", ascending: false)]
        
        let records = try await publicDatabase.records(matching: query)
        
        var links: [WorkoutChallengeLink] = []
        for (_, result) in records.matchResults {
            if case .success(let record) = result,
               let link = WorkoutChallengeLink(from: record) {
                // Only include links that count toward progress
                let status = WorkoutVerificationStatus(rawValue: link.verificationStatus) ?? .pending
                if status.countsTowardProgress {
                    links.append(link)
                }
            }
        }
        
        return links
    }
    
    // MARK: - Progress Calculations
    
    func calculateTotalProgress(for workoutChallengeID: String) async throws -> Double {
        let links = try await fetchVerifiedLinks(for: workoutChallengeID)
        return links.reduce(0) { $0 + $1.contributionValue }
    }
    
    func calculateUserProgress(userID: String, workoutChallengeID: String) async throws -> Double {
        let links = try await fetchUserLinks(userID: userID, workoutChallengeID: workoutChallengeID)
        return links
            .filter { link in
                let status = WorkoutVerificationStatus(rawValue: link.verificationStatus) ?? .pending
                return status.countsTowardProgress
            }
            .reduce(0) { $0 + $1.contributionValue }
    }
    
    func getLeaderboard(for workoutChallengeID: String) async throws -> [(userID: String, progress: Double)] {
        let links = try await fetchVerifiedLinks(for: workoutChallengeID)
        
        // Group by user and sum progress
        var userProgress: [String: Double] = [:]
        for link in links {
            userProgress[link.userID, default: 0] += link.contributionValue
        }
        
        // Sort by progress (highest first)
        return userProgress
            .map { ($0.key, $0.value) }
            .sorted { $0.progress > $1.progress }
    }
    
    // MARK: - Bulk Operations
    
    func processWorkoutForChallenges(
        workout: Workout,
        userID: String,
        activeChallengeIDs: [String]
    ) async throws -> [WorkoutChallengeLink] {
        guard !activeChallengeIDs.isEmpty else { return [] }
        
        FameFitLogger.info("Processing workout \(workout.id) for \(activeChallengeIDs.count) challenges", category: FameFitLogger.data)
        
        var createdLinks: [WorkoutChallengeLink] = []
        
        // Check each active challenge to see if this workout contributes
        for workoutChallengeID in activeChallengeIDs {
            // Fetch challenge details to determine contribution type
            let challenge = try await fetchChallenge(workoutChallengeID: workoutChallengeID)
            
            // Calculate contribution based on challenge type
            let contribution = calculateContribution(
                workout: workout,
                challengeType: challenge.type
            )
            
            if contribution.value > 0 {
                let link = try await createLink(
                    workoutID: workout.id.uuidString,
                    workoutChallengeID: workoutChallengeID,
                    userID: userID,
                    contributionValue: contribution.value,
                    contributionType: contribution.type,
                    workoutDate: workout.startDate
                )
                createdLinks.append(link)
            }
        }
        
        FameFitLogger.info("✅ Created \(createdLinks.count) challenge links for workout", category: FameFitLogger.data)
        return createdLinks
    }
    
    // MARK: - Helper Methods
    
    private func fetchChallenge(workoutChallengeID: String) async throws -> WorkoutChallenge {
        let recordID = CKRecord.ID(recordName: workoutChallengeID)
        let record = try await publicDatabase.record(for: recordID)
        
        guard let challenge = WorkoutChallenge(from: record) else {
            throw ChallengeError.challengeNotFound
        }
        
        return challenge
    }
    
    private func calculateContribution(
        workout: Workout,
        challengeType: ChallengeType
    ) -> (value: Double, type: String) {
        switch challengeType {
        case .distance:
            return (workout.totalDistance ?? 0, "distance")
            
        case .duration:
            return (workout.duration, "duration")
            
        case .calories:
            return (workout.totalEnergyBurned, "calories")
            
        case .workoutCount:
            return (1, "count")
            
        case .totalXP:
            // XP is calculated elsewhere, return 0 for now
            return (0, "xp")
            
        case .specificWorkout:
            // For specific workout type challenges, count as 1 if it matches
            return (1, "specificWorkout")
        }
    }
}

// MARK: - Error Types

extension WorkoutChallengeLinksService {
    enum LinkError: LocalizedError {
        case linkNotFound
        case duplicateLink
        case invalidContribution
        case invalidVerificationRequest
        
        var errorDescription: String? {
            switch self {
            case .linkNotFound:
                return "Challenge link not found"
            case .duplicateLink:
                return "A link already exists for this workout and challenge"
            case .invalidContribution:
                return "Invalid contribution value for challenge"
            case .invalidVerificationRequest:
                return "Cannot request manual verification in this state"
            }
        }
    }
}