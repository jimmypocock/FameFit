//
//  XPTransactionService.swift
//  FameFit
//
//  Service for managing XP transaction audit trail
//

import Foundation
import CloudKit
import Combine

class XPTransactionService: ObservableObject {
    @Published var recentTransactions: [XPTransaction] = []
    @Published var isLoading = false
    @Published var lastError: Error?
    
    private let container: CKContainer
    private let publicDatabase: CKDatabase
    private var cancellables = Set<AnyCancellable>()
    
    init(container: CKContainer = CKContainer.default()) {
        self.container = container
        self.publicDatabase = container.publicCloudDatabase
    }
    
    // MARK: - Fetch All Transactions (for verification)
    func fetchAllTransactions(for userID: String) async throws -> [XPTransaction] {
        let predicate = NSPredicate(format: "userRecordID == %@", userID)
        let query = CKQuery(recordType: "XPTransactions", predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        
        var allTransactions: [XPTransaction] = []
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
                
                var fetchedRecords: [CKRecord] = []
                
                operation.recordMatchedBlock = { _, result in
                    switch result {
                    case .success(let record):
                        fetchedRecords.append(record)
                    case .failure(let error):
                        print("Failed to fetch XP transaction record: \(error)")
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
                
                publicDatabase.add(operation)
            }
            
            // Convert records to XPTransaction objects
            let transactions = records.compactMap { XPTransaction(from: $0) }
            allTransactions.append(contentsOf: transactions)
            cursor = nextCursor
        } while cursor != nil
        
        return allTransactions
    }
    
    // MARK: - Create Transaction
    func createTransaction(
        userRecordID: String,
        workoutRecordID: String,
        baseXP: Int,
        finalXP: Int,
        factors: XPCalculationFactors
    ) async throws -> XPTransaction {
        let transaction = XPTransaction(
            userRecordID: userRecordID,
            workoutRecordID: workoutRecordID,
            baseXP: baseXP,
            finalXP: finalXP,
            factors: factors
        )
        
        let record = transaction.toCKRecord()
        
        do {
            let savedRecord = try await publicDatabase.save(record)
            print("✅ XP Transaction saved: \(savedRecord.recordID.recordName)")
            
            // Update recent transactions
            await MainActor.run {
                self.recentTransactions.insert(transaction, at: 0)
                if self.recentTransactions.count > 10 {
                    self.recentTransactions = Array(self.recentTransactions.prefix(10))
                }
            }
            
            return transaction
        } catch {
            print("❌ Failed to save XP transaction: \(error)")
            throw error
        }
    }
    
    // MARK: - Fetch Transactions
    func fetchTransactions(for userRecordID: String, limit: Int = 10) async throws -> [XPTransaction] {
        let predicate = NSPredicate(format: "userRecordID == %@", userRecordID)
        let query = CKQuery(recordType: XPTransaction.recordType, predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
        
        do {
            let records = try await publicDatabase.records(matching: query, resultsLimit: limit)
            let transactions = records.matchResults
                .compactMap { _, result in
                    try? result.get()
                }
                .compactMap { XPTransaction(from: $0) }
            
            await MainActor.run {
                self.recentTransactions = transactions
                self.isLoading = false
            }
            
            return transactions
        } catch {
            await MainActor.run {
                self.lastError = error
                self.isLoading = false
            }
            throw error
        }
    }
    
    // MARK: - Fetch Transaction for Workout
    func fetchTransaction(for workoutRecordID: String) async throws -> XPTransaction? {
        let predicate = NSPredicate(format: "workoutRecordID == %@", workoutRecordID)
        let query = CKQuery(recordType: XPTransaction.recordType, predicate: predicate)
        
        do {
            let records = try await publicDatabase.records(matching: query, resultsLimit: 1)
            return records.matchResults
                .compactMap { _, result in try? result.get() }
                .compactMap { XPTransaction(from: $0) }
                .first
        } catch {
            print("❌ Failed to fetch transaction for workout: \(error)")
            throw error
        }
    }
    
    // MARK: - Analytics
    func fetchUserStats(for userRecordID: String) async throws -> XPStats {
        let predicate = NSPredicate(format: "userRecordID == %@", userRecordID)
        let query = CKQuery(recordType: XPTransaction.recordType, predicate: predicate)
        
        do {
            let records = try await publicDatabase.records(matching: query)
            let transactions = records.matchResults
                .compactMap { _, result in try? result.get() }
                .compactMap { XPTransaction(from: $0) }
            
            return XPStats(from: transactions)
        } catch {
            print("❌ Failed to fetch user stats: \(error)")
            throw error
        }
    }
}

// MARK: - XP Stats
struct XPStats {
    let totalTransactions: Int
    let totalXPEarned: Int
    let averageMultiplier: Double
    let mostCommonBonuses: [XPBonusType]
    let bestWorkoutType: String?
    let bestTimeOfDay: String?
    
    init(from transactions: [XPTransaction]) {
        self.totalTransactions = transactions.count
        self.totalXPEarned = transactions.reduce(0) { $0 + $1.xpGained }
        
        if !transactions.isEmpty {
            self.averageMultiplier = transactions.reduce(0.0) { $0 + $1.factors.totalMultiplier } / Double(transactions.count)
        } else {
            self.averageMultiplier = 1.0
        }
        
        // Calculate most common bonuses
        var bonusCount: [XPBonusType: Int] = [:]
        for transaction in transactions {
            for bonus in transaction.factors.bonuses {
                bonusCount[bonus.type, default: 0] += 1
            }
        }
        self.mostCommonBonuses = bonusCount
            .sorted { $0.value > $1.value }
            .prefix(3)
            .map { $0.key }
        
        // Find best workout type
        var workoutTypeXP: [String: Int] = [:]
        for transaction in transactions {
            workoutTypeXP[transaction.factors.workoutType, default: 0] += transaction.xpGained
        }
        self.bestWorkoutType = workoutTypeXP
            .max { $0.value < $1.value }?
            .key
        
        // Find best time of day
        var timeOfDayXP: [String: Int] = [:]
        for transaction in transactions {
            timeOfDayXP[transaction.factors.timeOfDay, default: 0] += transaction.xpGained
        }
        self.bestTimeOfDay = timeOfDayXP
            .max { $0.value < $1.value }?
            .key
    }
}