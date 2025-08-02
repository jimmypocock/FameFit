//
//  ProfileSetupOnboardingView.swift
//  FameFit
//
//  Profile creation prompt step
//

import SwiftUI

struct ProfileSetupOnboardingView: View {
    @Binding var onboardingStep: Int
    @Binding var showProfileCreation: Bool

    var body: some View {
        VStack(spacing: 30) {
            Text("CREATE YOUR PROFILE")
                .font(.system(size: 30, weight: .black, design: .rounded))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)

            Text("Time to make your mark! Set up your profile to start building your fitness empire.")
                .font(.body)
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Spacer()

            // Profile benefits
            VStack(alignment: .leading, spacing: 20) {
                ProfileBenefitRow(
                    icon: "person.circle.fill",
                    title: "Unique Username",
                    description: "Choose how others will find you"
                )
                
                ProfileBenefitRow(
                    icon: "camera.fill",
                    title: "Profile Photo",
                    description: "Show off your best side"
                )
                
                ProfileBenefitRow(
                    icon: "text.quote",
                    title: "Personal Bio",
                    description: "Share your fitness journey"
                )
                
                ProfileBenefitRow(
                    icon: "lock.shield.fill",
                    title: "Privacy Controls",
                    description: "Choose who can see your workouts"
                )
            }
            .padding(.horizontal)

            Spacer()

            Button(action: {
                showProfileCreation = true
            }) {
                HStack {
                    Image(systemName: "sparkles")
                    Text("Create Profile")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.white.opacity(0.3))
                .cornerRadius(15)
            }
            .padding(.horizontal, 40)
        }
        .padding(.vertical)
    }
}

struct ProfileBenefitRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.white)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.white)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            }
            
            Spacer()
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
        
        ProfileSetupOnboardingView(onboardingStep: .constant(3), showProfileCreation: .constant(false))
    }
}