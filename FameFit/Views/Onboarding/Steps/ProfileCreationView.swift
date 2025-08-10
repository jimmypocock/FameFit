//
//  ProfileCreationView.swift
//  FameFit
//
//  Profile creation flow for new users
//

import CloudKit
import PhotosUI
import SwiftUI

struct ProfileCreationView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @State private var currentStep = 0
    @State private var showingSignOutAlert = false
    @State private var selectedImage: PhotosPickerItem?
    @State private var profileImage: UIImage?
    
    private var canProceed: Bool {
        switch currentStep {
        case 0:
            return UserProfile.isValidUsername(viewModel.username) && viewModel.usernameError == nil
        case 1:
            return UserProfile.isValidBio(viewModel.bio)
        case 2:
            return true // Privacy level always has a default
        default:
            return false
        }
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // Header with sign out button
            HStack {
                Text("Create Profile")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Spacer()
                
                Button(action: {
                    showingSignOutAlert = true
                }) {
                    Image(systemName: "ellipsis.circle")
                        .font(.title2)
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            .padding(.horizontal)
            
            // Progress indicator
            ProgressView(value: Double(currentStep + 1), total: 3)
                .tint(.white)
                .padding(.horizontal)

            switch currentStep {
            case 0:
                usernameStep
            case 1:
                bioStep
            case 2:
                privacyStep
            default:
                EmptyView()
            }

            Spacer()

            // Navigation buttons
            HStack(spacing: 20) {
                if currentStep > 0 {
                    Button(action: {
                        withAnimation {
                            currentStep -= 1
                        }
                    }) {
                        Text("Back")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.white.opacity(0.2))
                            .cornerRadius(15)
                    }
                }

                Button(action: {
                    if currentStep == 2 {
                        Task {
                            await viewModel.createProfile()
                        }
                    } else {
                        withAnimation {
                            currentStep += 1
                        }
                    }
                }) {
                    Text(currentStep == 2 ? "Create Profile" : "Next")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(canProceed ? Color.white.opacity(0.3) : Color.white.opacity(0.1))
                        .cornerRadius(15)
                }
                .disabled(!canProceed || viewModel.isLoading)
            }
            .padding(.horizontal)
        }
        .padding(.vertical)
        .alert("Sign Out?", isPresented: $showingSignOutAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Sign Out", role: .destructive) {
                viewModel.signOut()
            }
        } message: {
            Text("Are you sure you want to sign out? You'll need to sign in again to continue.")
        }
    }

    // MARK: - Step Views

    private var usernameStep: some View {
        VStack(spacing: 30) {
            Text("CHOOSE YOUR USERNAME")
                .font(.system(size: 24, weight: .black, design: .rounded))
                .foregroundColor(.white)

            VStack(alignment: .leading, spacing: 10) {
                TextField("Username", text: $viewModel.username)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .onChange(of: viewModel.username) { _, _ in
                        // Debounce username checking
                        Task {
                            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                            await viewModel.isUsernameAvailable()
                        }
                    }

                if viewModel.isCheckingUsername {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Checking availability...")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                    }
                } else if let error = viewModel.usernameError {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                } else if !viewModel.username.isEmpty && UserProfile.isValidUsername(viewModel.username) {
                    Text("✓ Username available")
                        .font(.caption)
                        .foregroundColor(.green)
                }

                Text("3-30 characters, letters, numbers, and underscores only")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
            }
            .padding(.horizontal)
        }
    }

    private var bioStep: some View {
        VStack(spacing: 30) {
            Text("TELL US ABOUT YOURSELF")
                .font(.system(size: 24, weight: .black, design: .rounded))
                .foregroundColor(.white)

            VStack(alignment: .leading, spacing: 10) {
                ZStack(alignment: .topLeading) {
                    TextEditor(text: $viewModel.bio)
                        .frame(height: 120)
                        .cornerRadius(10)
                        .opacity(viewModel.bio.isEmpty ? 0.7 : 1.0)

                    if viewModel.bio.isEmpty {
                        Text("Share your fitness goals, favorite workouts, or what motivates you...")
                            .foregroundColor(.gray)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 12)
                            .allowsHitTesting(false)
                    }
                }

                HStack {
                    Text("\(viewModel.bio.count)/500 characters")
                        .font(.caption)
                        .foregroundColor(viewModel.bio.count > 500 ? .red : .white.opacity(0.6))
                    Spacer()
                }
            }
            .padding(.horizontal)

            // Optional: Profile picture picker
            PhotosPicker(selection: $selectedImage, matching: .images) {
                HStack {
                    Image(systemName: "camera.fill")
                    Text("Add Profile Photo (Optional)")
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding()
                .background(Color.white.opacity(0.2))
                .cornerRadius(15)
            }
            .onChange(of: selectedImage) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        profileImage = image
                    }
                }
            }

            if let profileImage {
                Image(uiImage: profileImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 100, height: 100)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.white, lineWidth: 2))
            }
        }
    }

    private var privacyStep: some View {
        VStack(spacing: 30) {
            Text("PRIVACY SETTINGS")
                .font(.system(size: 24, weight: .black, design: .rounded))
                .foregroundColor(.white)

            VStack(spacing: 20) {
                ForEach([
                    ProfilePrivacyLevel.publicProfile,
                    ProfilePrivacyLevel.friendsOnly,
                    ProfilePrivacyLevel.privateProfile
                ], id: \.self) { level in
                    Button(action: {
                        viewModel.privacyLevel = level
                    }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 5) {
                                HStack {
                                    Image(systemName: level.iconName)
                                    Text(level.displayName)
                                        .font(.headline)
                                }

                                Text(level.description)
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.8))
                                    .multilineTextAlignment(.leading)
                            }

                            Spacer()

                            if viewModel.privacyLevel == level {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            }
                        }
                        .padding()
                        .background(
                            viewModel.privacyLevel == level
                                ? Color.white.opacity(0.3)
                                : Color.white.opacity(0.1)
                        )
                        .cornerRadius(15)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal)
        }
    }
}

// MARK: - Privacy Level Icon Extension

extension ProfilePrivacyLevel {
    var iconName: String {
        switch self {
        case .publicProfile:
            return "globe"
        case .friendsOnly:
            return "person.2.fill"
        case .privateProfile:
            return "lock.fill"
        }
    }
}

#Preview {
    ProfileCreationView(viewModel: OnboardingViewModel(container: DependencyContainer()))
        .background(
            LinearGradient(
                colors: [Color.purple, Color.blue],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
}