//
//  AccountVerificationService.swift
//  FameFit
//
//  Service to verify FameFit account status for Watch app
//  Watch receives profile data from iPhone via WatchConnectivity
//

import Foundation

@MainActor
class AccountVerificationService: ObservableObject {
    @Published var accountStatus: AccountStatus = .checking
    @Published var shouldShowSetupPrompt = false
    
    private let userDefaults = UserDefaults.standard
    
    init() {
        // Watch gets profile from iPhone via WatchConnectivity
        // No direct CloudKit access needed
    }
    
    // MARK: - Public Methods
    
    /// Check account status from cached iPhone data
    func checkAccountStatus(forceRefresh: Bool = false) async {
        // Load cached profile from iPhone sync
        loadCachedStatus()
        
        // If no cached data, briefly wait for WatchConnectivity sync
        if case .notFound = accountStatus {
            // Give WatchConnectivity a moment to deliver pending data
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            loadCachedStatus()
        }
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
    
    /// Called when iPhone sends updated profile data via WatchConnectivity
    func updateFromiPhone(profile: UserProfile) {
        // Cache the profile
        cacheProfile(profile)
        // Update status
        accountStatus = .verified(profile)
        shouldShowSetupPrompt = false
    }
    
    // MARK: - Private Methods
    
    private func loadCachedStatus() {
        // Try to load cached profile from iPhone sync
        if let profileData = userDefaults.data(forKey: AccountCacheKeys.cachedProfileData),
           let profile = try? JSONDecoder().decode(UserProfile.self, from: profileData) {
            accountStatus = .verified(profile)
        } else if userDefaults.bool(forKey: AccountCacheKeys.allowWorkoutsWithoutAccount) {
            // User previously chose to continue without account
            accountStatus = .notFound
        } else {
            // No profile synced from iPhone yet
            accountStatus = .notFound
            // Don't prompt for setup if user already dismissed it
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