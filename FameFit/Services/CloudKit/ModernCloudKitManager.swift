//
//  ModernCloudKitManager.swift
//  FameFit
//
//  Example of modern Swift best practices for CloudKit
//

import CloudKit
import Foundation
import os.log

// MARK: - Actor for thread safety
actor CloudKitAccountManager {
    private var isInitializing = false
    private var lastInitializationAttempt: Date?
    private let retryDelay: TimeInterval = 5.0
    
    func shouldAttemptInitialization() -> Bool {
        guard !isInitializing else { return false }
        
        if let lastAttempt = lastInitializationAttempt {
            return Date().timeIntervalSince(lastAttempt) > retryDelay
        }
        
        return true
    }
    
    func markInitializationStarted() {
        isInitializing = true
        lastInitializationAttempt = Date()
    }
    
    func markInitializationCompleted() {
        isInitializing = false
    }
}

// MARK: - Modern CloudKit Manager Example
@MainActor
final class ModernCloudKitManager: ObservableObject {
    private let container: CKContainer
    private let accountManager = CloudKitAccountManager()
    
    @Published private(set) var accountStatus: CKAccountStatus = .couldNotDetermine
    @Published private(set) var isAuthenticated = false
    @Published private(set) var initializationState: InitializationState = .notStarted
    
    enum InitializationState {
        case notStarted
        case inProgress
        case completed
        case failed(Error)
        case waitingForCloudKit
    }
    
    init(container: CKContainer = .default()) {
        self.container = container
        
        // Start monitoring account status
        Task {
            await startAccountMonitoring()
        }
    }
    
    // MARK: - Modern async/await approach
    private func startAccountMonitoring() async {
        // Initial check
        await checkAndUpdateAccountStatus()
        
        // Set up continuous monitoring with NotificationCenter
        NotificationCenter.default.addObserver(
            forName: .CKAccountChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { [weak self] in
                await self?.checkAndUpdateAccountStatus()
            }
        }
    }
    
    private func checkAndUpdateAccountStatus() async {
        do {
            let status = try await container.accountStatus()
            self.accountStatus = status
            self.isAuthenticated = (status == .available)
            
            if status == .available {
                await initializeCloudKitIfNeeded()
            } else {
                self.initializationState = .waitingForCloudKit
            }
        } catch {
            FameFitLogger.error("Failed to check account status", error: error, category: FameFitLogger.cloudKit)
        }
    }
    
    private func initializeCloudKitIfNeeded() async {
        guard await accountManager.shouldAttemptInitialization() else {
            FameFitLogger.debug("CloudKit initialization already in progress or too soon to retry", category: FameFitLogger.cloudKit)
            return
        }
        
        await accountManager.markInitializationStarted()
        self.initializationState = .inProgress
        
        defer {
            Task {
                await accountManager.markInitializationCompleted()
            }
        }
        
        do {
            // Initialize schema with retry logic
            try await initializeSchemaWithRetry()
            self.initializationState = .completed
            
            // Fetch user record
            try await fetchUserRecord()
        } catch {
            FameFitLogger.error("CloudKit initialization failed", error: error, category: FameFitLogger.cloudKit)
            self.initializationState = .failed(error)
            
            // Schedule retry if appropriate
            if shouldRetryError(error) {
                Task {
                    try await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
                    await initializeCloudKitIfNeeded()
                }
            }
        }
    }
    
    private func initializeSchemaWithRetry(maxAttempts: Int = 3) async throws {
        var lastError: Error?
        
        for attempt in 1...maxAttempts {
            do {
                FameFitLogger.info("Attempting CloudKit schema initialization (attempt \(attempt)/\(maxAttempts))", category: FameFitLogger.cloudKit)
                
                // Check if CloudKit is truly ready
                _ = try await container.privateCloudDatabase.recordZone(withID: .default)
                
                // If we get here, CloudKit is ready - initialize schema
                // This would call your schema manager with async/await
                return
            } catch {
                lastError = error
                
                // Don't retry certain errors
                if !shouldRetryError(error) {
                    throw error
                }
                
                // Exponential backoff
                if attempt < maxAttempts {
                    let delay = Double(attempt) * 2.0
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }
        
        throw lastError ?? CloudKitError.unknown
    }
    
    private func shouldRetryError(_ error: Error) -> Bool {
        let errorString = error.localizedDescription
        
        // Don't retry these errors
        if errorString.contains("Can't query system types") ||
           errorString.contains("Not Authenticated") {
            return false
        }
        
        // Retry network and temporary errors
        if let ckError = error as? CKError {
            switch ckError.code {
            case .networkUnavailable, .networkFailure, .serviceUnavailable, .requestRateLimited:
                return true
            default:
                return false
            }
        }
        
        return true
    }
    
    private func fetchUserRecord() async throws {
        let userID = try await container.userRecordID()
        let record = try await container.privateCloudDatabase.record(for: userID)
        
        // Process record on main actor
        await MainActor.run {
            processUserRecord(record)
        }
    }
    
    private func processUserRecord(_ record: CKRecord) {
        // Update published properties
    }
}

// MARK: - Errors
enum CloudKitError: LocalizedError {
    case notAuthenticated
    case unknown
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "User is not authenticated with iCloud"
        case .unknown:
            return "An unknown error occurred"
        }
    }
}