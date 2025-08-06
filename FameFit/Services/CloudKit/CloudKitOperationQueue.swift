//
//  CloudKitOperationQueue.swift
//  FameFit
//
//  Rate-limited operation queue for CloudKit operations
//

import CloudKit
import Foundation

/// Manages CloudKit operations with rate limiting and prioritization
actor CloudKitOperationQueue {
    // MARK: - Types
    
    enum Priority: Int, Comparable {
        case low = 0
        case medium = 1
        case high = 2
        case critical = 3
        
        static func < (lhs: Priority, rhs: Priority) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }
    
    struct QueuedOperation {
        let id = UUID()
        let priority: Priority
        let operation: () async throws -> Void
        let description: String
        let timestamp = Date()
    }
    
    // MARK: - Properties
    
    private var queue: [QueuedOperation] = []
    private var isProcessing = false
    private var lastOperationTime: Date?
    private let rateLimitDelay: TimeInterval = 0.5 // 500ms between operations
    private let maxConcurrentOperations = 3
    private var activeOperationCount = 0
    
    // Statistics
    private var operationStats = OperationStatistics()
    
    // MARK: - Public Methods
    
    /// Add an operation to the queue
    func enqueue(
        priority: Priority = .medium,
        description: String,
        operation: @escaping () async throws -> Void
    ) {
        let queuedOp = QueuedOperation(
            priority: priority,
            operation: operation,
            description: description
        )
        
        // Insert based on priority
        if let insertIndex = queue.firstIndex(where: { $0.priority < priority }) {
            queue.insert(queuedOp, at: insertIndex)
        } else {
            queue.append(queuedOp)
        }
        
        FameFitLogger.debug("Enqueued operation: \(description) (priority: \(priority))", category: FameFitLogger.cloudKit)
        
        // Start processing if not already running
        Task {
            await processQueue()
        }
    }
    
    /// Process the queue
    private func processQueue() async {
        guard !isProcessing else { return }
        guard activeOperationCount < maxConcurrentOperations else { return }
        
        isProcessing = true
        defer { isProcessing = false }
        
        while !queue.isEmpty && activeOperationCount < maxConcurrentOperations {
            // Rate limiting
            if let lastTime = lastOperationTime {
                let timeSinceLastOp = Date().timeIntervalSince(lastTime)
                if timeSinceLastOp < rateLimitDelay {
                    let waitTime = rateLimitDelay - timeSinceLastOp
                    try? await Task.sleep(nanoseconds: UInt64(waitTime * 1_000_000_000))
                }
            }
            
            // Get next operation
            let operation = queue.removeFirst()
            activeOperationCount += 1
            lastOperationTime = Date()
            
            // Execute operation
            Task {
                await executeOperation(operation)
                decrementActiveCount()
                
                // Continue processing
                Task {
                    await processQueue()
                }
            }
        }
    }
    
    private func executeOperation(_ queuedOp: QueuedOperation) async {
        let startTime = Date()
        
        do {
            FameFitLogger.debug("Executing operation: \(queuedOp.description)", category: FameFitLogger.cloudKit)
            try await queuedOp.operation()
            
            let duration = Date().timeIntervalSince(startTime)
            recordSuccess(duration: duration)
            
            FameFitLogger.debug("Operation completed: \(queuedOp.description) (took \(String(format: "%.2f", duration))s)", category: FameFitLogger.cloudKit)
            
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            recordFailure(error: error, duration: duration)
            
            FameFitLogger.error("Operation failed: \(queuedOp.description)", error: error, category: FameFitLogger.cloudKit)
            
            // Handle rate limit errors
            if let ckError = error as? CKError, ckError.code == .requestRateLimited {
                if let retryAfter = ckError.userInfo[CKErrorRetryAfterKey] as? TimeInterval {
                    FameFitLogger.warning("Rate limited, waiting \(retryAfter) seconds", category: FameFitLogger.cloudKit)
                    try? await Task.sleep(nanoseconds: UInt64(retryAfter * 1_000_000_000))
                }
            }
        }
    }
    
    private func decrementActiveCount() {
        activeOperationCount -= 1
    }
    
    // MARK: - Statistics
    
    private func recordSuccess(duration: TimeInterval) {
        operationStats.successCount += 1
        operationStats.totalDuration += duration
        operationStats.lastOperationTime = Date()
    }
    
    private func recordFailure(error: Error, duration: TimeInterval) {
        operationStats.failureCount += 1
        operationStats.totalDuration += duration
        operationStats.lastOperationTime = Date()
        operationStats.lastError = error
    }
    
    func getStatistics() -> OperationStatistics {
        return operationStats
    }
    
    func getQueueSize() -> Int {
        return queue.count
    }
    
    func clearQueue() {
        queue.removeAll()
        FameFitLogger.info("CloudKit operation queue cleared", category: FameFitLogger.cloudKit)
    }
}

// MARK: - Supporting Types

struct OperationStatistics {
    var successCount: Int = 0
    var failureCount: Int = 0
    var totalDuration: TimeInterval = 0
    var lastOperationTime: Date?
    var lastError: Error?
    
    var averageDuration: TimeInterval {
        let total = successCount + failureCount
        return total > 0 ? totalDuration / Double(total) : 0
    }
    
    var successRate: Double {
        let total = successCount + failureCount
        return total > 0 ? Double(successCount) / Double(total) : 0
    }
}

// MARK: - Convenience Extensions

extension CloudKitOperationQueue {
    /// Enqueue a save operation
    func enqueueSave(
        record: CKRecord,
        database: CKDatabase,
        priority: Priority = .medium
    ) async throws -> CKRecord {
        try await withCheckedThrowingContinuation { continuation in
            Task {
                enqueue(
                    priority: priority,
                    description: "Save \(record.recordType) record"
                ) {
                    do {
                        let saved = try await database.save(record)
                        continuation.resume(returning: saved)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
    }
    
    /// Enqueue a fetch operation
    func enqueueFetch(
        recordID: CKRecord.ID,
        database: CKDatabase,
        priority: Priority = .medium
    ) async throws -> CKRecord {
        try await withCheckedThrowingContinuation { continuation in
            Task {
                enqueue(
                    priority: priority,
                    description: "Fetch record \(recordID.recordName)"
                ) {
                    do {
                        let record = try await database.record(for: recordID)
                        continuation.resume(returning: record)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
    }
    
    /// Enqueue a query operation
    func enqueueQuery(
        query: CKQuery,
        database: CKDatabase,
        limit: Int = 100,
        priority: Priority = .medium
    ) async throws -> [CKRecord] {
        try await withCheckedThrowingContinuation { continuation in
            Task {
                enqueue(
                    priority: priority,
                    description: "Query \(query.recordType) records"
                ) {
                    do {
                        let results = try await database.records(matching: query, resultsLimit: limit)
                        let records = results.matchResults.compactMap { try? $0.1.get() }
                        continuation.resume(returning: records)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
    }
}