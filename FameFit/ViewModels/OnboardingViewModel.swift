//
//  OnboardingViewModel.swift
//  FameFit
//
//  Orchestrates the onboarding flow and ensures proper initialization order
//

import SwiftUI
import Combine
import HealthKit

@MainActor
final class OnboardingViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published var currentStep: OnboardingStep = .welcome {
        didSet {
            // Always save the current step
            UserDefaults.standard.set(currentStep.rawValue, forKey: "OnboardingCurrentStep")
        }
    }
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // Step completion tracking
    @Published private(set) var isAuthenticated = false
    @Published private(set) var hasHealthKitPermission = false
    @Published private(set) var hasProfile = false
    @Published private(set) var cloudKitUserID: String?
    @Published private(set) var createdProfile: UserProfile?
    
    // UI State
    @Published var showSignInSheet = false
    @Published var username = ""
    @Published var bio = ""
    @Published var privacyLevel = ProfilePrivacyLevel.publicProfile
    @Published var isCheckingUsername = false
    @Published var usernameError: String?
    
    // MARK: - Dependencies
    
    private let authManager: AuthenticationService
    private let cloudKitManager: CloudKitService
    private let workoutObserver: WorkoutObserver
    private let userProfileService: UserProfileProtocol
    private let container: DependencyContainer
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Onboarding Steps
    
    enum OnboardingStep: Int, CaseIterable {
        case welcome = 0
        case signIn = 1  // Deprecated - Sign in is now part of WelcomeView
        case healthKit = 2
        case profile = 3
        case gameMechanics = 4
        
        var title: String {
            switch self {
            case .welcome: return "Welcome"
            case .signIn: return "Sign In"
            case .healthKit: return "Health Access"
            case .profile: return "Create Profile"
            case .gameMechanics: return "How It Works"
            }
        }
        
        var canSkip: Bool {
            switch self {
            case .welcome, .gameMechanics: return false
            case .signIn: return false // Required for app to work
            case .healthKit: return true // Optional but recommended
            case .profile: return false // Required for app to work
            }
        }
    }
    
    // MARK: - Initialization
    
    init(container: DependencyContainer) {
        self.container = container
        self.authManager = container.authenticationManager
        self.cloudKitManager = container.cloudKitManager
        self.workoutObserver = container.workoutObserver
        self.userProfileService = container.userProfileService
        
        setupBindings()
        determineStartingStep()
    }
    
    // MARK: - Setup
    
    private var isInitializing = true
    
    private func setupBindings() {
        // Listen for authentication changes
        authManager.$isAuthenticated
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isAuthenticated in
                self?.isAuthenticated = isAuthenticated
                // Only handle auth changes after initial setup
                if isAuthenticated && !(self?.isInitializing ?? true) {
                    Task { [weak self] in
                        await self?.handleAuthenticationComplete()
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    /// Determine where to start based on existing state
    private func determineStartingStep() {
        Task {
            isLoading = true
            defer { 
                isLoading = false
                isInitializing = false
            }
            
            // Check authentication
            if authManager.isAuthenticated {
                isAuthenticated = true
                
                // Get CloudKit user ID
                if let userID = try? await cloudKitManager.getCurrentUserID() {
                    cloudKitUserID = userID
                    
                    // Check if profile exists by CloudKit user ID
                    if let existingProfile = try? await userProfileService.fetchProfileByUserID(userID) {
                        hasProfile = true
                        createdProfile = existingProfile // Store it for later use
                        
                        // User has completed everything, they shouldn't be in onboarding
                        authManager.completeOnboarding()
                        return
                    }
                }
                
                // For authenticated users without profile, we need to complete onboarding
                FameFitLogger.info("Authenticated user without profile, continuing onboarding flow", category: FameFitLogger.auth)
                
                // Check current HealthKit status
                hasHealthKitPermission = workoutObserver.checkHealthKitAuthorization()
                
                // Check if we have a saved step from a previous session
                let savedStep = UserDefaults.standard.integer(forKey: "OnboardingCurrentStep")
                FameFitLogger.info("Saved step value: \(savedStep), HealthKit authorized: \(hasHealthKitPermission)", category: FameFitLogger.auth)
                
                if savedStep > 0, let step = OnboardingStep(rawValue: savedStep) {
                    // Resume from saved step
                    FameFitLogger.info("Resuming onboarding from saved step: \(step.title)", category: FameFitLogger.auth)
                    currentStep = step
                    
                    // If resuming at HealthKit step, check if already granted
                    if step == .healthKit {
                        FameFitLogger.info("At HealthKit step, checking permissions...", category: FameFitLogger.auth)
                        checkHealthKitPermissions()
                    }
                } else {
                    // No saved step, start at HealthKit (already authenticated)
                    FameFitLogger.info("No saved step, starting at HealthKit", category: FameFitLogger.auth)
                    currentStep = .healthKit
                    checkHealthKitPermissions()
                }
            } else {
                // Not authenticated, start from beginning
                currentStep = .welcome
                isInitializing = false
            }
        }
    }
    
    // MARK: - Navigation
    
    func moveToNextStep() {
        guard let nextStep = OnboardingStep(rawValue: currentStep.rawValue + 1) else {
            // We're at the last step
            Task {
                await completeOnboarding()
            }
            return
        }
        
        withAnimation(.easeInOut(duration: 0.3)) {
            currentStep = nextStep
        }
        
        // When we arrive at HealthKit step, check if already authorized
        if nextStep == .healthKit {
            checkHealthKitPermissions()
        }
    }
    
    func moveToPreviousStep() {
        guard let previousStep = OnboardingStep(rawValue: currentStep.rawValue - 1) else { return }
        
        withAnimation(.easeInOut(duration: 0.3)) {
            currentStep = previousStep
        }
    }
    
    func skipCurrentStep() {
        guard currentStep.canSkip else { return }
        moveToNextStep()
    }
    
    // MARK: - Step Handlers
    
    /// Handle Sign In with Apple completion
    private func handleAuthenticationComplete() async {
        // Fetch CloudKit user ID after authentication
        do {
            let userID = try await cloudKitManager.getCurrentUserID()
            cloudKitUserID = userID
            
            // Check if user already has a profile (returning user)
            // userID is from cloudKitManager.getCurrentUserID(), so it's a CloudKit user ID
            if let _ = try? await userProfileService.fetchProfileByUserID(userID) {
                hasProfile = true
                
                // Returning user - complete onboarding
                authManager.completeOnboarding()
                return
            }
            
            // New user - only set step if we're not already in onboarding
            // This prevents overwriting the restored step
            if currentStep == .welcome {
                FameFitLogger.info("New user detected after sign-in, moving to HealthKit step", category: FameFitLogger.auth)
                currentStep = .healthKit
                // Check if HealthKit is already authorized
                checkHealthKitPermissions()
            }
        } catch {
            errorMessage = "Failed to connect to iCloud. Please check your connection."
            FameFitLogger.error("Failed to get CloudKit user ID", error: error, category: FameFitLogger.auth)
        }
    }
    
    /// Check if HealthKit permissions are already granted
    func checkHealthKitPermissions() {
        hasHealthKitPermission = workoutObserver.checkHealthKitAuthorization()
        FameFitLogger.info("checkHealthKitPermissions: hasPermission = \(hasHealthKitPermission), currentStep = \(currentStep.title)", category: FameFitLogger.auth)
        
        if hasHealthKitPermission {
            // Already authorized, immediately advance
            FameFitLogger.info("HealthKit already authorized, moving to next step", category: FameFitLogger.auth)
            moveToNextStep()
        } else {
            FameFitLogger.info("HealthKit not authorized, staying on current step", category: FameFitLogger.auth)
        }
    }
    
    /// Request HealthKit permissions
    func requestHealthKitPermissions() {
        // First check if already authorized
        if workoutObserver.checkHealthKitAuthorization() {
            hasHealthKitPermission = true
            FameFitLogger.info("HealthKit already authorized, moving to next step", category: FameFitLogger.auth)
            moveToNextStep()
            return
        }
        
        // Request authorization
        workoutObserver.requestHealthKitAuthorization { [weak self] success, error in
            DispatchQueue.main.async {
                if success {
                    self?.hasHealthKitPermission = true
                    FameFitLogger.info("HealthKit authorization granted, moving to next step", category: FameFitLogger.auth)
                    self?.moveToNextStep()
                } else {
                    // User denied or error occurred
                    self?.hasHealthKitPermission = false
                    
                    if let error = error, case .healthKitAuthorizationDenied = error {
                        FameFitLogger.info("User denied HealthKit permissions", category: FameFitLogger.auth)
                    } else if let error = error {
                        self?.errorMessage = "Failed to get health permissions: \(error.localizedDescription)"
                    }
                    // Don't auto-advance - let user decide to skip
                }
            }
        }
    }
    
    /// Check username availability
    func isUsernameAvailable() async {
        guard UserProfile.isValidUsername(username) else {
            usernameError = "Username must be 3-30 characters, alphanumeric with underscores only"
            return
        }
        
        isCheckingUsername = true
        usernameError = nil
        
        do {
            let isAvailable = try await userProfileService.isUsernameAvailable(username.lowercased())
            
            await MainActor.run {
                isCheckingUsername = false
                if !isAvailable {
                    usernameError = "Username is already taken"
                }
            }
        } catch {
            await MainActor.run {
                isCheckingUsername = false
                usernameError = "Failed to check username"
            }
        }
    }
    
    /// Create user profile
    func createProfile() async {
        guard let userID = cloudKitUserID else {
            errorMessage = "Unable to find user account. Please try signing out and back in."
            return
        }
        
        guard UserProfile.isValidUsername(username),
              UserProfile.isValidBio(bio),
              usernameError == nil else {
            errorMessage = "Please fix the errors before continuing."
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            // Check username one more time
            let isAvailable = try await userProfileService.isUsernameAvailable(username.lowercased())
            guard isAvailable else {
                throw ProfileServiceError.usernameAlreadyTaken
            }
            
            // Create the profile
            let profile = UserProfile(
                id: UUID().uuidString,
                userID: userID,
                username: username.lowercased(),
                bio: bio,
                workoutCount: 0,
                totalXP: 0,
                creationDate: Date(),
                modificationDate: Date(),
                isVerified: false,
                privacyLevel: privacyLevel,
                profileImageURL: nil,
                headerImageURL: nil
            )
            
            let createdProfile = try await userProfileService.createProfile(profile)
            
            // Store the created profile - we'll use this instead of fetching
            await MainActor.run {
                self.createdProfile = createdProfile
                hasProfile = true
                isLoading = false
                
                FameFitLogger.info("Profile created successfully for user: \(createdProfile.username), moving to next step", category: FameFitLogger.auth)
                moveToNextStep()
            }
            
        } catch {
            await MainActor.run {
                isLoading = false
                hasProfile = false // Ensure hasProfile is false on error
                
                if let serviceError = error as? ProfileServiceError {
                    switch serviceError {
                    case .usernameAlreadyTaken:
                        errorMessage = "Username is already taken. Please choose another."
                    case .invalidUsername:
                        errorMessage = "Invalid username format."
                    case .invalidBio:
                        errorMessage = "Bio is too long. Maximum 500 characters."
                    default:
                        errorMessage = "Failed to create profile: \(error.localizedDescription)"
                    }
                } else {
                    errorMessage = "Failed to create profile. Please try again."
                }
                FameFitLogger.error("Failed to create profile: \(error.localizedDescription)", category: FameFitLogger.auth)
            }
        }
    }
    
    /// Complete the onboarding process
    func completeOnboarding() async {
        isLoading = true
        errorMessage = nil
        
        do {
            // Verify everything is ready
            guard isAuthenticated else {
                throw OnboardingError.notAuthenticated
            }
            
            guard let userID = cloudKitUserID else {
                throw OnboardingError.noCloudKitUser
            }
            
            // Debug logging to understand state
            FameFitLogger.info("completeOnboarding - hasProfile: \(hasProfile), createdProfile: \(createdProfile != nil)", category: FameFitLogger.auth)
            
            // Ensure we have a profile (either just created or existing)
            guard hasProfile else {
                FameFitLogger.error("Cannot complete onboarding without a profile - hasProfile is false", category: FameFitLogger.auth)
                errorMessage = "Profile not created. Please go back and create your profile."
                throw OnboardingError.profileCreationFailed
            }
            
            // Use the created profile if we have it (from just creating it)
            // Otherwise try to fetch it (for edge cases)
            let profile: UserProfile
            if let createdProfile = self.createdProfile {
                profile = createdProfile
                FameFitLogger.info("Using recently created profile for user: \(profile.username)", category: FameFitLogger.auth)
            } else {
                // This shouldn't happen if hasProfile is true, but handle it gracefully
                FameFitLogger.warning("hasProfile is true but createdProfile is nil, attempting to fetch", category: FameFitLogger.auth)
                
                // Try to fetch with a small delay for propagation
                try? await Task.sleep(nanoseconds: 2_000_000_000) // Wait 2 seconds for propagation
                profile = try await userProfileService.fetchProfileByUserID(userID)
                FameFitLogger.info("Fetched existing profile for user: \(profile.username)", category: FameFitLogger.auth)
            }
            
            // CloudKit Users record will be created/fetched when services start
            // via AppInitializer -> CloudKitService.fetchUserRecordAsync()
            
            // If HealthKit permissions weren't granted during onboarding, request them now
            if !hasHealthKitPermission {
                FameFitLogger.info("Requesting HealthKit permissions during completion", category: FameFitLogger.auth)
                // Don't block completion on HealthKit - user can grant later
            }
            
            // Everything is ready - complete onboarding
            await MainActor.run {
                isLoading = false
                
                // Clear saved onboarding step since we're done (but keep HealthKit permission state)
                UserDefaults.standard.removeObject(forKey: "OnboardingCurrentStep")
                
                // Mark onboarding as complete ONLY after verifying everything
                authManager.completeOnboarding()
                FameFitLogger.info("✅ Onboarding completed successfully for user: \(profile.username)", category: FameFitLogger.auth)
                
                // Services will be initialized by AppInitializer
                // in response to the onboarding completion
            }
            
        } catch {
            await MainActor.run {
                isLoading = false
                errorMessage = "Failed to complete setup: \(error.localizedDescription)"
                FameFitLogger.error("Failed to complete onboarding", error: error, category: FameFitLogger.auth)
            }
        }
    }
    
    /// Sign out and reset onboarding
    func signOut() {
        // Clear saved onboarding progress
        UserDefaults.standard.removeObject(forKey: "OnboardingCurrentStep")
        authManager.signOut()
        // This will trigger navigation back to onboarding automatically
    }
}

// MARK: - Onboarding Errors

enum OnboardingError: LocalizedError {
    case notAuthenticated
    case noCloudKitUser
    case profileCreationFailed
    case healthKitNotAvailable
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Please sign in to continue"
        case .noCloudKitUser:
            return "Unable to connect to iCloud"
        case .profileCreationFailed:
            return "Failed to create profile"
        case .healthKitNotAvailable:
            return "Health data is not available"
        }
    }
}