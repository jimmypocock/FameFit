import AuthenticationServices
import Combine
import Foundation
import SwiftUI

class AuthenticationService: NSObject, ObservableObject, AuthenticationProtocol {
    @Published var isAuthenticated = false
    @Published var authUserID: String?  // Sign in with Apple ID
    @Published var username: String?
    @Published var lastError: FameFitError?
    @Published var hasCompletedOnboarding = false

    private let authUserIDKey = "FameFitAuthUserID"
    private let usernameKey = "FameFitUserName"
    private weak var cloudKitManager: CloudKitService?

    // MARK: - Publisher Properties

    var isAuthenticatedPublisher: AnyPublisher<Bool, Never> {
        $isAuthenticated.eraseToAnyPublisher()
    }

    var authUserIDPublisher: AnyPublisher<String?, Never> {
        $authUserID.eraseToAnyPublisher()
    }

    var usernamePublisher: AnyPublisher<String?, Never> {
        $username.eraseToAnyPublisher()
    }

    var lastErrorPublisher: AnyPublisher<FameFitError?, Never> {
        $lastError.eraseToAnyPublisher()
    }

    var hasCompletedOnboardingPublisher: AnyPublisher<Bool, Never> {
        $hasCompletedOnboarding.eraseToAnyPublisher()
    }

    init(cloudKitManager: CloudKitService) {
        self.cloudKitManager = cloudKitManager
        super.init()
        checkAuthenticationStatus()
    }

    func checkAuthenticationStatus() {
        if let savedAuthUserID = UserDefaults.standard.string(forKey: authUserIDKey),
           let savedUserName = UserDefaults.standard.string(forKey: usernameKey) {
            authUserID = savedAuthUserID
            username = savedUserName
            isAuthenticated = true
            hasCompletedOnboarding = UserDefaults.standard.bool(
                forKey: UserDefaultsKeys.hasCompletedOnboarding
            )

            cloudKitManager?.checkAccountStatus()
            
            // Sync profile to Watch on app launch if authenticated
            Task {
                await syncProfileToWatch()
            }
        }
    }

    func handleSignInWithApple(credential: ASAuthorizationAppleIDCredential) {
        let authUserID = credential.user

        var displayName = "FameFit User"
        if let fullName = credential.fullName {
            let formatter = PersonNameComponentsFormatter()
            let name = formatter.string(from: fullName)
            if !name.isEmpty {
                displayName = name
            }
        }

        UserDefaults.standard.set(authUserID, forKey: authUserIDKey)
        UserDefaults.standard.set(displayName, forKey: usernameKey)

        self.authUserID = authUserID
        username = displayName
        isAuthenticated = true
        
        // Sync profile to Watch after successful sign-in
        Task {
            await syncProfileToWatch()
        }
    }

    func signOut() {
        UserDefaults.standard.removeObject(forKey: authUserIDKey)
        UserDefaults.standard.removeObject(forKey: usernameKey)
        UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.hasCompletedOnboarding)

        authUserID = nil
        username = nil
        isAuthenticated = false
        hasCompletedOnboarding = false
    }
    
    func deleteAccount() async throws {
        FameFitLogger.info("Starting account deletion process", category: FameFitLogger.auth)
        
        // Use anonymization approach for CloudKit data
        if let cloudKitManager = cloudKitManager {
            try await cloudKitManager.deleteAllUserDataWithAnonymization()
            
            // Clear CloudKit caches after deletion
            await cloudKitManager.clearAllCaches()
        }
        
        // Clear all local data
        signOut()
        
        // Clear any additional app data
        UserDefaults.standard.removePersistentDomain(forName: Bundle.main.bundleIdentifier!)
        UserDefaults.standard.synchronize()
        
        FameFitLogger.info("Account deletion completed", category: FameFitLogger.auth)
    }

    func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: UserDefaultsKeys.hasCompletedOnboarding)
        hasCompletedOnboarding = true
        
        // Sync profile to Watch after onboarding completion
        Task {
            await syncProfileToWatch()
        }
    }
    
    // MARK: - Watch Sync
    
    private func syncProfileToWatch() async {
        guard isAuthenticated else { return }
        
        // Try to fetch the user profile from CloudKit
        do {
            // Get UserProfileService from the CloudKitManager
            if let cloudKit = cloudKitManager {
                let profileService = UserProfileService(cloudKitManager: cloudKit)
                let profile = try await profileService.fetchCurrentUserProfile()
                
                // Send profile to Watch
                EnhancedWatchConnectivityManager.shared.syncUserProfile(profile)
                FameFitLogger.info("📱⌚ User profile synced to Watch", category: FameFitLogger.auth)
            }
        } catch {
            // If we can't get the full profile, at least send basic info
            if let authID = authUserID, let name = username {
                let basicProfile = UserProfile(
                    id: authID,
                    userID: authID,
                    username: name,
                    bio: "",
                    workoutCount: 0,
                    totalXP: 0,
                    creationDate: Date(),
                    modificationDate: Date(),
                    isVerified: false,
                    privacyLevel: .publicProfile,
                    profileImageURL: nil,
                    headerImageURL: nil,
                    countsLastVerified: nil,
                    countsVersion: nil,
                    countsSyncToken: nil
                )
                EnhancedWatchConnectivityManager.shared.syncUserProfile(basicProfile)
                FameFitLogger.warning("📱⌚ Synced basic profile to Watch (full profile unavailable)", category: FameFitLogger.auth)
            }
        }
    }
}

#if os(iOS)
    struct SignInWithAppleButton: UIViewRepresentable {
        @Environment(\.colorScheme) var colorScheme
        @EnvironmentObject var authManager: AuthenticationService

        func makeUIView(context: Context) -> ASAuthorizationAppleIDButton {
            let button = ASAuthorizationAppleIDButton(
                authorizationButtonType: .signIn,
                authorizationButtonStyle: colorScheme == .dark ? .white : .black
            )
            button.addTarget(
                context.coordinator, action: #selector(Coordinator.handleSignInWithApple),
                for: .touchUpInside
            )
            return button
        }

        func updateUIView(_: ASAuthorizationAppleIDButton, context _: Context) {}

        func makeCoordinator() -> Coordinator {
            Coordinator(authManager: authManager)
        }

        class Coordinator: NSObject, ASAuthorizationControllerDelegate,
            ASAuthorizationControllerPresentationContextProviding {
            let authManager: AuthenticationService

            init(authManager: AuthenticationService) {
                self.authManager = authManager
            }

            @objc func handleSignInWithApple() {
                let request = ASAuthorizationAppleIDProvider().createRequest()
                request.requestedScopes = [.fullName]

                let controller = ASAuthorizationController(authorizationRequests: [request])
                controller.delegate = self
                controller.presentationContextProvider = self
                controller.performRequests()
            }

            func authorizationController(
                controller _: ASAuthorizationController,
                didCompleteWithAuthorization authorization: ASAuthorization
            ) {
                if let credential = authorization.credential as? ASAuthorizationAppleIDCredential {
                    authManager.handleSignInWithApple(credential: credential)
                }
            }

            func authorizationController(
                controller _: ASAuthorizationController, didCompleteWithError error: Error
            ) {
                DispatchQueue.main.async {
                    let nsError = error as NSError
                    if nsError.code == ASAuthorizationError.canceled.rawValue {
                        self.authManager.lastError = .authenticationCancelled
                    } else {
                        self.authManager.lastError = .authenticationFailed(error)
                    }
                }
            }

            func presentationAnchor(for _: ASAuthorizationController) -> ASPresentationAnchor {
                guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                      let window = windowScene.windows.first
                else {
                    // Return a default window if none found
                    return UIWindow()
                }
                return window
            }
        }
    }
#endif

#if DEBUG
extension AuthenticationService {
    /// Set UI testing state - only available in DEBUG builds
    func setUITestingState(isAuthenticated: Bool, hasCompletedOnboarding: Bool, userID: String) {
        self.authUserID = userID
        self.isAuthenticated = isAuthenticated
        self.hasCompletedOnboarding = hasCompletedOnboarding
        
        UserDefaults.standard.set(isAuthenticated, forKey: "isAuthenticated")
        UserDefaults.standard.set(hasCompletedOnboarding, forKey: "hasCompletedOnboarding")
        UserDefaults.standard.set(userID, forKey: "userID")
        UserDefaults.standard.synchronize()
    }
}
#endif
