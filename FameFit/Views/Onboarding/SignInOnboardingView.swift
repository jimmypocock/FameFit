//
//  SignInOnboardingView.swift
//  FameFit
//
//  Sign in with Apple step
//

import AuthenticationServices
import SwiftUI

struct SignInOnboardingView: View {
    @Binding var onboardingStep: Int
    @Binding var showSignIn: Bool
    @EnvironmentObject var authManager: AuthenticationService
    @EnvironmentObject var cloudKitManager: CloudKitService

    var body: some View {
        VStack(spacing: 30) {
            Text("SIGN IN TO CONTINUE")
                .font(.system(size: 30, weight: .black, design: .rounded))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)

            Text("Connect with Apple to save your progress and compete with others")
                .font(.body)
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Spacer()

            // Use the custom SignInWithAppleButton from AuthenticationService
            SignInWithAppleButton()
                .frame(height: 55)
                .padding(.horizontal, 40)

            Spacer()

            Text("Your privacy is important to us. We only use your Apple ID to create your account.")
                .font(.caption)
                .foregroundColor(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding(.vertical)
        .onChange(of: authManager.isAuthenticated) { _, isAuthenticated in
            if isAuthenticated {
                // Move to next step after successful authentication
                withAnimation {
                    onboardingStep = 2
                }
            }
        }
    }
}

#Preview {
    ZStack {
        LinearGradient(
            colors: [Color.purple, Color.blue],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
        
        SignInOnboardingView(onboardingStep: .constant(1), showSignIn: .constant(false))
            .environmentObject(AuthenticationService(cloudKitManager: CloudKitService()))
            .environmentObject(CloudKitService())
    }
}
