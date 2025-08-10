//
//  SignInView.swift
//  FameFit
//
//  Sign in with Apple step of onboarding
//

import SwiftUI

struct SignInView: View {
    @ObservedObject var viewModel: OnboardingViewModel

    var body: some View {
        VStack(spacing: 30) {
            Text("SIGN IN")
                .font(.system(size: 40, weight: .black, design: .rounded))
                .foregroundColor(.white)

            Text("First, let's get you set up with an account so we can track your journey to fitness fame!")
                .font(.body)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)

            Spacer()

            SignInWithAppleButton()
                .frame(height: 50)
                .cornerRadius(10)

            Spacer()
        }
    }
}