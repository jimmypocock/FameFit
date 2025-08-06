//
//  CloudKitStateManager.swift
//  FameFit
//
//  Actor-based state management for CloudKit operations
//

import CloudKit
import Foundation

/// Thread-safe state manager for CloudKit operations using Swift actors
actor CloudKitStateManager {
    // MARK: - Properties
    
    private var initializationState: InitializationState = .notStarted
    private var accountStatus: CKAccountStatus = .couldNotDetermine
    private var lastAccountCheck: Date?
    private var activeOperations: Set<String> = []
    private var retryAttempts: [String: Int] = [:]
    
    // Configuration
    private let maxRetryAttempts = 3
    private let baseRetryDelay: TimeInterval = 2.0
    private let accountCheckInterval: TimeInterval = 30.0
    
    // MARK: - Types
    
    enum InitializationState {
        case notStarted
        case inProgress
        case completed
        case failed(Error)
        case waitingForAccount
    }
    
    enum OperationType: String {
        case schemaInitialization
        case userRecordFetch
        case userRecordCreate
        case workoutSync
        case profileSync
    }
    
    // MARK: - Account Status
    
    func updateAccountStatus(_ status: CKAccountStatus) {
        self.accountStatus = status
        self.lastAccountCheck = Date()
        
        // Update initialization state based on account status
        switch status {
        case .available:
            if case .waitingForAccount = initializationState {
                initializationState = .notStarted
            }
        case .noAccount, .restricted:
            initializationState = .waitingForAccount
        default:
            break
        }
    }
    
    func shouldCheckAccountStatus() -> Bool {
        guard let lastCheck = lastAccountCheck else { return true }
        return Date().timeIntervalSince(lastCheck) > accountCheckInterval
    }
    
    func getAccountStatus() -> CKAccountStatus {
        return accountStatus
    }
    
    // MARK: - Initialization State
    
    func getInitializationState() -> InitializationState {
        return initializationState
    }
    
    func setInitializationState(_ state: InitializationState) {
        self.initializationState = state
    }
    
    func canStartInitialization() -> Bool {
        switch initializationState {
        case .notStarted, .failed:
            return accountStatus == .available
        default:
            return false
        }
    }
    
    // MARK: - Operation Management
    
    func startOperation(_ type: OperationType) -> Bool {
        let operationKey = type.rawValue
        
        // Check if operation is already running
        guard !activeOperations.contains(operationKey) else {
            FameFitLogger.debug("Operation \(operationKey) already in progress", category: FameFitLogger.cloudKit)
            return false
        }
        
        activeOperations.insert(operationKey)
        return true
    }
    
    func completeOperation(_ type: OperationType) {
        let operationKey = type.rawValue
        activeOperations.remove(operationKey)
        retryAttempts.removeValue(forKey: operationKey)
    }
    
    func isOperationActive(_ type: OperationType) -> Bool {
        return activeOperations.contains(type.rawValue)
    }
    
    // MARK: - Retry Management
    
    func shouldRetryOperation(_ type: OperationType, error: Error) -> Bool {
        let operationKey = type.rawValue
        let currentAttempts = retryAttempts[operationKey] ?? 0
        
        // Check max attempts
        guard currentAttempts < maxRetryAttempts else {
            FameFitLogger.warning("Max retry attempts reached for \(operationKey)", category: FameFitLogger.cloudKit)
            return false
        }
        
        // Check if error is retryable
        guard isRetryableError(error) else {
            return false
        }
        
        retryAttempts[operationKey] = currentAttempts + 1
        return true
    }
    
    func getRetryDelay(for type: OperationType) -> TimeInterval {
        let operationKey = type.rawValue
        let attempts = retryAttempts[operationKey] ?? 0
        
        // Exponential backoff with jitter
        let exponentialDelay = baseRetryDelay * pow(2.0, Double(attempts))
        let jitter = Double.random(in: 0...1.0)
        return exponentialDelay + jitter
    }
    
    func resetRetryCount(for type: OperationType) {
        retryAttempts.removeValue(forKey: type.rawValue)
    }
    
    // MARK: - Private Helpers
    
    private func isRetryableError(_ error: Error) -> Bool {
        // CloudKit specific errors
        if let ckError = error as? CKError {
            switch ckError.code {
            case .networkUnavailable, .networkFailure, .serviceUnavailable, 
                 .requestRateLimited, .zoneBusy, .operationCancelled:
                return true
            case .notAuthenticated, .permissionFailure, .incompatibleVersion,
                 .constraintViolation, .invalidArguments:
                return false
            default:
                // For unknown errors, check the error message
                break
            }
        }
        
        // Check error messages
        let errorString = error.localizedDescription.lowercased()
        let nonRetryableMessages = [
            "can't query system types",
            "not authenticated",
            "permission failure",
            "invalid arguments"
        ]
        
        return !nonRetryableMessages.contains { errorString.contains($0) }
    }
    
    // MARK: - Diagnostics
    
    func getDiagnosticInfo() -> [String: Any] {
        return [
            "initializationState": String(describing: initializationState),
            "accountStatus": String(describing: accountStatus),
            "activeOperations": Array(activeOperations),
            "retryAttempts": retryAttempts,
            "lastAccountCheck": lastAccountCheck?.description ?? "never"
        ]
    }
}