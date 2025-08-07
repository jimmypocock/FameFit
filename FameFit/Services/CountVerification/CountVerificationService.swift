//
//  CountVerificationService.swift
//  FameFit
//
//  Service for verifying and recalculating cached counts to ensure data integrity
//

import Foundation
import CloudKit

// MARK: - Count Verification Service Protocol

protocol CountVerificationServicing {
    func verifyAllCounts() async throws -> CountVerificationResult
    func verifyXPCount() async throws -> Int
    func verifyWorkoutCount() async throws -> Int
    func shouldVerifyOnAppLaunch() -> Bool
    func markCountsAsVerified()
}

// MARK: - Count Verification Result

struct CountVerificationResult {
    let previousXP: Int
    let updatedXP: Int
    let xpCorrected: Bool
    
    let previousWorkoutCount: Int
    let updatedWorkoutCount: Int
    let workoutCountCorrected: Bool
    
    let verificationDate: Date
    
    var hadCorrections: Bool {
        xpCorrected || workoutCountCorrected
    }
    
    var summary: String {
        var parts: [String] = []
        
        if xpCorrected {
            let diff = updatedXP - previousXP
            let sign = diff > 0 ? "+" : ""
            parts.append("XP: \(previousXP) → \(updatedXP) (\(sign)\(diff))")
        }
        
        if workoutCountCorrected {
            let diff = updatedWorkoutCount - previousWorkoutCount
            let sign = diff > 0 ? "+" : ""
            parts.append("Workouts: \(previousWorkoutCount) → \(updatedWorkoutCount) (\(sign)\(diff))")
        }
        
        if parts.isEmpty {
            return "All counts verified correctly ✓"
        } else {
            return "Corrections made:\n" + parts.joined(separator: "\n")
        }
    }
}

// MARK: - Count Verification Service

final class CountVerificationService: CountVerificationServicing {
    private let cloudKitManager: CloudKitManager
    private let userProfileService: UserProfileServicing
    private let xpTransactionService: XPTransactionService
    
    // Verification settings
    private let staleThresholdHours: TimeInterval = 24 // Verify if older than 24 hours
    private let lastVerificationKey = "CountVerification.lastVerified"
    
    init(
        cloudKitManager: CloudKitManager,
        userProfileService: UserProfileServicing,
        xpTransactionService: XPTransactionService
    ) {
        self.cloudKitManager = cloudKitManager
        self.userProfileService = userProfileService
        self.xpTransactionService = xpTransactionService
    }
    
    // MARK: - Public Methods
    
    /// Verify and correct all counts
    func verifyAllCounts() async throws -> CountVerificationResult {
        FameFitLogger.info("🔢 Starting count verification", category: FameFitLogger.data)
        
        // Get current stats from CloudKit Users record (not profile)
        guard cloudKitManager.currentUserID != nil else {
            throw CountVerificationError.userNotAuthenticated
        }
        
        // Get current values from Users record
        let previousXP = cloudKitManager.totalXP
        let previousWorkoutCount = cloudKitManager.totalWorkouts
        
        // Recalculate from source of truth
        async let actualXP = verifyXPCount()
        async let actualWorkouts = verifyWorkoutCount()
        
        let (newXP, newWorkouts) = try await (actualXP, actualWorkouts)
        
        // Check if corrections needed
        let xpCorrected = newXP != previousXP
        let workoutCountCorrected = newWorkouts != previousWorkoutCount
        
        // Update Users record if needed
        if xpCorrected || workoutCountCorrected {
            FameFitLogger.warning("🔢 Count corrections needed - XP: \(previousXP)→\(newXP), Workouts: \(previousWorkoutCount)→\(newWorkouts)", category: FameFitLogger.data)
            
            // Update the Users record in CloudKit with corrected counts
            try await cloudKitManager.updateUserStats(
                totalWorkouts: newWorkouts,
                totalXP: newXP
            )
            
            // Update local cached values
            await MainActor.run {
                cloudKitManager.totalWorkouts = newWorkouts
                cloudKitManager.totalXP = newXP
            }
        } else {
            FameFitLogger.info("🔢 All counts verified correctly", category: FameFitLogger.data)
        }
        
        // Mark as verified
        markCountsAsVerified()
        
        return CountVerificationResult(
            previousXP: previousXP,
            updatedXP: newXP,
            xpCorrected: xpCorrected,
            previousWorkoutCount: previousWorkoutCount,
            updatedWorkoutCount: newWorkouts,
            workoutCountCorrected: workoutCountCorrected,
            verificationDate: Date()
        )
    }
    
    /// Verify XP count from XPTransaction records
    func verifyXPCount() async throws -> Int {
        FameFitLogger.debug("🔢 Verifying XP count from transactions", category: FameFitLogger.data)
        
        // Fetch all XP transactions for current user
        guard let userId = cloudKitManager.currentUserID else {
            throw CountVerificationError.userNotAuthenticated
        }
        
        let transactions = try await xpTransactionService.fetchAllTransactions(for: userId)
        let totalXP = transactions.reduce(0) { $0 + $1.finalXP }
        
        FameFitLogger.debug("🔢 Calculated XP: \(totalXP) from \(transactions.count) transactions", category: FameFitLogger.data)
        return totalXP
    }
    
    /// Verify workout count from Workout records
    func verifyWorkoutCount() async throws -> Int {
        FameFitLogger.debug("🔢 Verifying workout count from workout records", category: FameFitLogger.data)
        
        // Query all workouts for current user
        let predicate = NSPredicate(value: true) // Will be filtered by user in CloudKit
        let query = CKQuery(recordType: "Workouts", predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "startDate", ascending: false)]
        
        do {
            let records = try await cloudKitManager.privateDatabase.allRecords(
                matching: query,
                desiredKeys: ["workoutId"] // Only need IDs for counting
            )
            
            FameFitLogger.debug("🔢 Found \(records.count) workout records", category: FameFitLogger.data)
            return records.count
        } catch {
            FameFitLogger.error("🔢 Failed to fetch workout records for counting", error: error, category: FameFitLogger.data)
            throw CountVerificationError.queryFailed(error)
        }
    }
    
    /// Check if verification should run on app launch
    func shouldVerifyOnAppLaunch() -> Bool {
        guard let lastVerified = UserDefaults.standard.object(forKey: lastVerificationKey) as? Date else {
            // Never verified
            return true
        }
        
        let hoursSinceVerification = Date().timeIntervalSince(lastVerified) / 3600
        return hoursSinceVerification >= staleThresholdHours
    }
    
    /// Mark counts as recently verified
    func markCountsAsVerified() {
        UserDefaults.standard.set(Date(), forKey: lastVerificationKey)
    }
    
    // MARK: - Anomaly Detection
    
    /// Detect potential count anomalies that might indicate corruption
    func detectAnomalies(in profile: UserProfile) -> [CountAnomaly] {
        var anomalies: [CountAnomaly] = []
        
        // Check for negative counts
        if profile.totalXP < 0 {
            anomalies.append(.negativeXP(profile.totalXP))
        }
        
        if profile.totalWorkouts < 0 {
            anomalies.append(.negativeWorkoutCount(profile.totalWorkouts))
        }
        
        // Check for impossibly high single-day gains
        // (would need to track daily changes for this)
        
        // Check for XP without workouts
        if profile.totalXP > 0 && profile.totalWorkouts == 0 {
            anomalies.append(.xpWithoutWorkouts)
        }
        
        return anomalies
    }
}

// MARK: - Error Types

enum CountVerificationError: LocalizedError {
    case profileNotFound
    case userNotAuthenticated
    case queryFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .profileNotFound:
            return "User profile not found"
        case .userNotAuthenticated:
            return "User not authenticated"
        case .queryFailed(let error):
            return "Failed to query records: \(error.localizedDescription)"
        }
    }
}

// MARK: - Count Anomaly Types

enum CountAnomaly {
    case negativeXP(Int)
    case negativeWorkoutCount(Int)
    case xpWithoutWorkouts
    case impossibleDailyGain(Int)
    
    var description: String {
        switch self {
        case .negativeXP(let value):
            return "Negative XP detected: \(value)"
        case .negativeWorkoutCount(let value):
            return "Negative workout count: \(value)"
        case .xpWithoutWorkouts:
            return "XP exists without any workouts"
        case .impossibleDailyGain(let gain):
            return "Impossible daily gain: \(gain) XP"
        }
    }
}

// MARK: - CloudKit Extension for Fetching All Records

private extension CKDatabase {
    func allRecords(matching query: CKQuery, desiredKeys: [String]? = nil) async throws -> [CKRecord] {
        var allRecords: [CKRecord] = []
        var cursor: CKQueryOperation.Cursor?
        
        repeat {
            let (records, nextCursor) = try await withCheckedThrowingContinuation { continuation in
                let operation: CKQueryOperation
                
                if let cursor = cursor {
                    operation = CKQueryOperation(cursor: cursor)
                } else {
                    operation = CKQueryOperation(query: query)
                    operation.resultsLimit = 400 // CloudKit max
                }
                
                operation.desiredKeys = desiredKeys
                
                var fetchedRecords: [CKRecord] = []
                
                operation.recordMatchedBlock = { _, result in
                    switch result {
                    case .success(let record):
                        fetchedRecords.append(record)
                    case .failure(let error):
                        FameFitLogger.error("Failed to fetch record", error: error, category: FameFitLogger.data)
                    }
                }
                
                operation.queryResultBlock = { result in
                    switch result {
                    case .success(let cursor):
                        continuation.resume(returning: (fetchedRecords, cursor))
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                }
                
                self.add(operation)
            }
            
            allRecords.append(contentsOf: records)
            cursor = nextCursor
        } while cursor != nil
        
        return allRecords
    }
}