import Foundation
import AuthenticationServices
import SwiftUI

class AuthenticationManager: NSObject, ObservableObject, AuthenticationManaging {
    @Published var isAuthenticated = false
    @Published var userID: String?
    @Published var userName: String?
    @Published var lastError: FameFitError?
    @Published var hasCompletedOnboarding = false
    
    private let userIDKey = "FameFitUserID"
    private let userNameKey = "FameFitUserName"
    private weak var cloudKitManager: CloudKitManager?
    
    init(cloudKitManager: CloudKitManager) {
        self.cloudKitManager = cloudKitManager
        super.init()
        checkAuthenticationStatus()
    }
    
    func checkAuthenticationStatus() {
        if let savedUserID = UserDefaults.standard.string(forKey: userIDKey),
           let savedUserName = UserDefaults.standard.string(forKey: userNameKey) {
            self.userID = savedUserID
            self.userName = savedUserName
            self.isAuthenticated = true
            self.hasCompletedOnboarding = UserDefaults.standard.bool(forKey: UserDefaultsKeys.hasCompletedOnboarding)
            
            cloudKitManager?.checkAccountStatus()
        }
    }
    
    func handleSignInWithApple(credential: ASAuthorizationAppleIDCredential) {
        let userID = credential.user
        
        var displayName = "FameFit User"
        if let fullName = credential.fullName {
            let formatter = PersonNameComponentsFormatter()
            let name = formatter.string(from: fullName)
            if !name.isEmpty {
                displayName = name
            }
        }
        
        UserDefaults.standard.set(userID, forKey: userIDKey)
        UserDefaults.standard.set(displayName, forKey: userNameKey)
        
        self.userID = userID
        self.userName = displayName
        self.isAuthenticated = true
        
        cloudKitManager?.setupUserRecord(userID: userID, displayName: displayName)
    }
    
    func signOut() {
        UserDefaults.standard.removeObject(forKey: userIDKey)
        UserDefaults.standard.removeObject(forKey: userNameKey)
        UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.hasCompletedOnboarding)
        
        self.userID = nil
        self.userName = nil
        self.isAuthenticated = false
        self.hasCompletedOnboarding = false
    }
    
    func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: UserDefaultsKeys.hasCompletedOnboarding)
        self.hasCompletedOnboarding = true
    }
}

#if os(iOS)
struct SignInWithAppleButton: UIViewRepresentable {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var authManager: AuthenticationManager
    
    func makeUIView(context: Context) -> ASAuthorizationAppleIDButton {
        let button = ASAuthorizationAppleIDButton(
            authorizationButtonType: .signIn,
            authorizationButtonStyle: colorScheme == .dark ? .white : .black
        )
        button.addTarget(context.coordinator, action: #selector(Coordinator.handleSignInWithApple), for: .touchUpInside)
        return button
    }
    
    func updateUIView(_ uiView: ASAuthorizationAppleIDButton, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(authManager: authManager)
    }
    
    class Coordinator: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
        let authManager: AuthenticationManager
        
        init(authManager: AuthenticationManager) {
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
        
        func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
            if let credential = authorization.credential as? ASAuthorizationAppleIDCredential {
                authManager.handleSignInWithApple(credential: credential)
            }
        }
        
        func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
            DispatchQueue.main.async {
                let nsError = error as NSError
                if nsError.code == ASAuthorizationError.canceled.rawValue {
                    self.authManager.lastError = .authenticationCancelled
                } else {
                    self.authManager.lastError = .authenticationFailed(error)
                }
            }
        }
        
        func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let window = windowScene.windows.first else {
                // Return a default window if none found
                return UIWindow()
            }
            return window
        }
    }
}
#endif
