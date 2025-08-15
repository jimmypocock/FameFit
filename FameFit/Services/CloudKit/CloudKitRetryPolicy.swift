//
//  CloudKitRetryPolicy.swift
//  FameFit
//
//  Modern retry infrastructure for CloudKit operations
//

import Foundation
import CloudKit
import os.log

// MARK: - Retry Configuration

struct RetryConfiguration: Sendable {
    let maxAttempts: Int
    let baseDelay: TimeInterval
    let maxDelay: TimeInterval
    let backoffMultiplier: Double
    
    static let `default` = RetryConfiguration(
        maxAttempts: 3,
        baseDelay: 1.0,
        maxDelay: 30.0,
        backoffMultiplier: 2.0
    )
    
    static let aggressive = RetryConfiguration(
        maxAttempts: 5,
        baseDelay: 0.5,
        maxDelay: 60.0,
        backoffMultiplier: 1.5
    )
    
    static let conservative = RetryConfiguration(
        maxAttempts: 2,
        baseDelay: 2.0,
        maxDelay: 10.0,
        backoffMultiplier: 2.0
    )
}

// MARK: - CloudKit Error Extensions

extension CKError {
    /// Determines if this error is worth retrying
    var isRetryable: Bool {
        switch self.code {
        case .networkUnavailable,
             .networkFailure,
             .serviceUnavailable,
             .requestRateLimited,
             .zoneBusy,
             .internalError,
             .serverResponseLost:
            return true
            
        default:
            return false
        }
    }
    
    /// CloudKit's suggested retry delay if available
    var suggestedRetryDelay: TimeInterval? {
        userInfo[CKErrorRetryAfterKey] as? TimeInterval
    }
    
    /// Categorizes the error for logging and metrics
    var category: ErrorCategory {
        switch self.code {
        case .networkUnavailable, .networkFailure:
            return .network
        case .serviceUnavailable, .zoneBusy, .requestRateLimited:
            return .serverLoad
        case .unknownItem, .zoneNotFound, .userDeletedZone:
            return .notFound
        case .invalidArguments, .incompatibleVersion:
            return .clientBug
        case .permissionFailure, .managedAccountRestricted:
            return .permissions
        case .quotaExceeded, .limitExceeded:
            return .quota
        default:
            return .other
        }
    }
    
    enum ErrorCategory {
        case network
        case serverLoad
        case notFound
        case clientBug
        case permissions
        case quota
        case other
    }
}

// MARK: - Retry Executor

actor CloudKitRetryExecutor {
    private let logger = Logger(subsystem: "com.famefit", category: "CloudKitRetry")
    private var metrics = RetryMetrics()
    
    struct RetryMetrics {
        var totalAttempts = 0
        var successfulRetries = 0
        var failedOperations = 0
        var errorCounts: [CKError.Code: Int] = [:]
    }
    
    /// Execute an operation with retry logic
    func execute<T: Sendable>(
        operation: @escaping @Sendable () async throws -> T,
        configuration: RetryConfiguration = .default,
        operationName: String
    ) async throws -> T {
        var lastError: Error?
        var currentDelay = configuration.baseDelay
        
        for attempt in 1...configuration.maxAttempts {
            metrics.totalAttempts += 1
            
            do {
                let result = try await operation()
                
                if attempt > 1 {
                    metrics.successfulRetries += 1
                    logger.info("✅ \(operationName) succeeded after \(attempt) attempts")
                }
                
                return result
                
            } catch let error as CKError {
                lastError = error
                
                // Update metrics
                metrics.errorCounts[error.code, default: 0] += 1
                
                // Check if retryable
                guard error.isRetryable else {
                    metrics.failedOperations += 1
                    logger.error("❌ \(operationName) failed with non-retryable error: \(error.code.rawValue)")
                    
                    if error.category == .clientBug {
                        logger.critical("🐛 Potential bug detected in \(operationName): \(error.localizedDescription)")
                    }
                    
                    throw error
                }
                
                // Check if we have attempts left
                guard attempt < configuration.maxAttempts else {
                    metrics.failedOperations += 1
                    logger.error("❌ \(operationName) exhausted \(configuration.maxAttempts) retry attempts")
                    throw error
                }
                
                // Calculate delay
                let delay: TimeInterval
                if let suggestedDelay = error.suggestedRetryDelay {
                    delay = min(suggestedDelay, configuration.maxDelay)
                    logger.info("⏰ Using CloudKit suggested delay: \(delay)s")
                } else {
                    delay = min(currentDelay, configuration.maxDelay)
                    currentDelay *= configuration.backoffMultiplier
                }
                
                logger.warning("⚠️ \(operationName) failed (attempt \(attempt)/\(configuration.maxAttempts)), retrying in \(String(format: "%.1f", delay))s: \(error.code.rawValue)")
                
                // Wait before retry
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                
            } catch {
                // Non-CloudKit error
                metrics.failedOperations += 1
                logger.error("🐛 \(operationName) failed with non-CloudKit error: \(error.localizedDescription)")
                throw error
            }
        }
        
        throw lastError ?? NSError(domain: "CloudKitRetry", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unknown error occurred during retry"])
    }
    
    /// Get current metrics
    func getMetrics() -> RetryMetrics {
        metrics
    }
    
    /// Reset metrics
    func resetMetrics() {
        metrics = RetryMetrics()
    }
}

// MARK: - Retry Queue removed - now using Queue.swift
// MARK: - Background Task Handler removed - now using WorkoutQueue.swift