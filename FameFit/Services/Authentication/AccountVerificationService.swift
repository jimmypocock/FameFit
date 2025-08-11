//
//  AccountVerificationService.swift
//  FameFit
//
//  Service to verify FameFit account status for Watch app
//

import CloudKit
import Foundation

@MainActor
class AccountVerificationService: ObservableObject {
    @Published var accountStatus: AccountStatus = .checking
    @Published var shouldShowSetupPrompt = false
    
    private let container: CKContainer
    private let userDefaults = UserDefaults.standard
    
    init(container: CKContainer = CKContainer(identifier: "iCloud.com.jimmypocock.FameFit")) {
        self.container = container
    }
    
    // MARK: - Public Methods
    
    /// Check account status with smart caching
    func checkAccountStatus(forceRefresh: Bool = false) async {
        // If not forcing refresh, check cache first
        if !forceRefresh && shouldUseCachedStatus() {
            loadCachedStatus()
            return
        }
        
        // Update UI to show checking
        accountStatus = .checking
        
        // Check CloudKit for account
        await performCloudKitCheck()
    }
    
    /// User chose to continue without account
    func continueWithoutAccount() {
        userDefaults.set(true, forKey: AccountCacheKeys.allowWorkoutsWithoutAccount)
        shouldShowSetupPrompt = false
        accountStatus = .notFound
    }
    
    /// Check if we should prompt for setup
    func shouldPromptForSetup() -> Bool {
        // Don't prompt if user already chose to continue without
        if userDefaults.bool(forKey: AccountCacheKeys.allowWorkoutsWithoutAccount) {
            return false
        }
        
        // Prompt if no account found
        if case .notFound = accountStatus {
            return true
        }
        
        return false
    }
    
    // MARK: - Private Methods
    
    private func shouldUseCachedStatus() -> Bool {
        guard let lastCheck = userDefaults.object(forKey: AccountCacheKeys.lastCheckDate) as? Date else {
            // No cache, need to check
            return false
        }
        
        // Check if cache is still valid (within 3 days)
        let timeSinceLastCheck = Date().timeIntervalSince(lastCheck)
        return timeSinceLastCheck < AccountCacheKeys.accountCheckInterval
    }
    
    private func loadCachedStatus() {
        // Try to load cached profile
        if let profileData = userDefaults.data(forKey: AccountCacheKeys.cachedProfileData),
           let profile = try? JSONDecoder().decode(UserProfile.self, from: profileData) {
            accountStatus = .verified(profile)
        } else if userDefaults.bool(forKey: AccountCacheKeys.allowWorkoutsWithoutAccount) {
            // User previously chose to continue without account
            accountStatus = .notFound
        } else {
            // No cache, need to check
            Task {
                await performCloudKitCheck()
            }
        }
    }
    
    private func performCloudKitCheck() async {
        do {
            // First check if user is signed into iCloud
            let accountStatus = try await container.accountStatus()
            guard accountStatus == .available else {
                self.accountStatus = .error("iCloud account not available. Please sign in to iCloud.")
                return
            }
            
            // Get CloudKit user ID
            let userID = try await container.userRecordID()
            
            // Create query for UserProfile with this CloudKit ID
            let predicate = NSPredicate(format: "cloudKitID == %@", userID.recordName)
            let query = CKQuery(recordType: "UserProfile", predicate: predicate)
            
            // Perform query with timeout
            let database = container.privateCloudDatabase
            
            // Use a task with timeout
            let timeoutTask = Task {
                try? await Task.sleep(nanoseconds: 3_000_000_000) // 3 second timeout
                return nil as Any?
            }
            
            let queryTask = Task {
                try await database.records(matching: query, resultsLimit: 1)
            }
            
            // Race between timeout and query
            let result = await withTaskGroup(of: Any?.self) { group in
                group.addTask { await timeoutTask.value }
                group.addTask { try? await queryTask.value }
                
                // Return first non-nil result
                for await value in group {
                    if value != nil {
                        group.cancelAll()
                        return value
                    }
                }
                return nil as Any?
            }
            
            // Process result
            if let queryResult = result as? (matchResults: [(CKRecord.ID, Result<CKRecord, Error>)], queryCursor: CKQueryOperation.Cursor?) {
                if let firstResult = queryResult.matchResults.first {
                    switch firstResult.1 {
                    case .success(let record):
                        // Found user profile
                        if let profile = UserProfile(from: record) {
                            self.accountStatus = .verified(profile)
                            cacheProfile(profile)
                            shouldShowSetupPrompt = false
                        } else {
                            // Could not parse profile
                            handleNoAccount()
                        }
                    case .failure:
                        // Error fetching profile
                        handleNoAccount()
                    }
                } else {
                    // No profile found
                    handleNoAccount()
                }
            } else {
                // Timeout or network issue
                handleOffline()
            }
            
        } catch {
            // Handle errors
            if error.localizedDescription.contains("Network") {
                handleOffline()
            } else {
                self.accountStatus = .error(error.localizedDescription)
            }
        }
    }
    
    private func handleNoAccount() {
        accountStatus = .notFound
        shouldShowSetupPrompt = !userDefaults.bool(forKey: AccountCacheKeys.allowWorkoutsWithoutAccount)
        userDefaults.set(Date(), forKey: AccountCacheKeys.lastCheckDate)
    }
    
    private func handleOffline() {
        // Check if we have a cached profile
        if let profileData = userDefaults.data(forKey: AccountCacheKeys.cachedProfileData),
           let profile = try? JSONDecoder().decode(UserProfile.self, from: profileData) {
            accountStatus = .offline(cachedProfile: profile)
        } else {
            accountStatus = .offline(cachedProfile: nil)
            shouldShowSetupPrompt = !userDefaults.bool(forKey: AccountCacheKeys.allowWorkoutsWithoutAccount)
        }
    }
    
    private func cacheProfile(_ profile: UserProfile) {
        // Cache the profile data
        if let encoded = try? JSONEncoder().encode(profile) {
            userDefaults.set(encoded, forKey: AccountCacheKeys.cachedProfileData)
        }
        
        // Update last check date
        userDefaults.set(Date(), forKey: AccountCacheKeys.lastCheckDate)
    }
    
    /// Clear all cached data (useful for testing or sign out)
    func clearCache() {
        userDefaults.removeObject(forKey: AccountCacheKeys.lastCheckDate)
        userDefaults.removeObject(forKey: AccountCacheKeys.cachedProfileData)
        userDefaults.removeObject(forKey: AccountCacheKeys.allowWorkoutsWithoutAccount)
        accountStatus = .checking
    }
}