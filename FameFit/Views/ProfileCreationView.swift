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
    @Environment(\.dismiss) var dismiss
    @Environment(\.dependencyContainer) var container

    @State private var currentStep = 0
    @State private var username = ""
    @State private var displayName = ""
    @State private var bio = ""
    @State private var privacyLevel = ProfilePrivacyLevel.publicProfile
    @State private var selectedImage: PhotosPickerItem?
    @State private var profileImage: UIImage?

    @State private var isCheckingUsername = false
    @State private var usernameError: String?
    @State private var isCreatingProfile = false
    @State private var creationError: String?

    private var profileService: UserProfileServicing {
        container.userProfileService
    }

    private var isUsernameValid: Bool {
        UserProfile.isValidUsername(username) && usernameError == nil
    }

    private var isDisplayNameValid: Bool {
        UserProfile.isValidDisplayName(displayName)
    }

    private var isBioValid: Bool {
        UserProfile.isValidBio(bio)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color.purple, Color.blue],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack(spacing: 20) {
                    // Progress indicator
                    ProgressView(value: Double(currentStep + 1), total: 4)
                        .tint(.white)
                        .padding(.horizontal)

                    switch currentStep {
                    case 0:
                        usernameStep
                    case 1:
                        displayNameStep
                    case 2:
                        bioAndPhotoStep
                    case 3:
                        privacyStep
                    default:
                        EmptyView()
                    }

                    Spacer()

                    // Navigation buttons
                    HStack(spacing: 20) {
                        if currentStep > 0 {
                            Button("Back") {
                                withAnimation {
                                    currentStep -= 1
                                }
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.white.opacity(0.2))
                            .cornerRadius(15)
                        }

                        Button(currentStep == 3 ? "Create Profile" : "Next") {
                            if currentStep == 3 {
                                createProfile()
                            } else {
                                withAnimation {
                                    currentStep += 1
                                }
                            }
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(canProceed ? Color.white.opacity(0.3) : Color.white.opacity(0.1))
                        .cornerRadius(15)
                        .disabled(!canProceed || isCreatingProfile)
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle("Create Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
            .alert("Error", isPresented: .constant(creationError != nil)) {
                Button("OK") {
                    creationError = nil
                }
            } message: {
                Text(creationError ?? "")
            }
        }
    }

    // MARK: - Step Views

    private var usernameStep: some View {
        VStack(spacing: 30) {
            Text("CHOOSE YOUR USERNAME")
                .font(.system(size: 30, weight: .black, design: .rounded))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)

            Text("This is how other users will find you. Choose wisely!")
                .font(.body)
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)

            VStack(alignment: .leading, spacing: 10) {
                TextField("Username", text: $username)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
                    .onChange(of: username) { _, newValue in
                        // Remove spaces and special characters except underscore
                        let filtered = newValue.filter { $0.isLetter || $0.isNumber || $0 == "_" }
                        if filtered != newValue {
                            username = filtered
                        }
                        validateUsername()
                    }

                HStack {
                    if isCheckingUsername {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else if let error = usernameError {
                        Label(error, systemImage: "xmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.red)
                    } else if !username.isEmpty, isUsernameValid {
                        Label("Username available!", systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.green)
                    }

                    Spacer()

                    Text("\(username.count)/30")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            .padding(.horizontal)

            Text("3-30 characters, letters, numbers, and underscores only")
                .font(.caption)
                .foregroundColor(.white.opacity(0.6))
        }
        .padding()
    }

    private var displayNameStep: some View {
        VStack(spacing: 30) {
            Text("WHAT'S YOUR NAME?")
                .font(.system(size: 30, weight: .black, design: .rounded))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)

            Text("This is how you'll appear on leaderboards and to friends")
                .font(.body)
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)

            VStack(alignment: .trailing, spacing: 10) {
                TextField("Display Name", text: $displayName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())

                Text("\(displayName.count)/50")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
            }
            .padding(.horizontal)
        }
        .padding()
    }

    private var bioAndPhotoStep: some View {
        VStack(spacing: 30) {
            Text("TELL US ABOUT YOURSELF")
                .font(.system(size: 28, weight: .black, design: .rounded))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)

            // Profile photo picker
            PhotosPicker(selection: $selectedImage, matching: .images) {
                if let profileImage {
                    Image(uiImage: profileImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 120, height: 120)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.white, lineWidth: 3))
                } else {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.3))
                            .frame(width: 120, height: 120)

                        VStack(spacing: 8) {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 30))
                            Text("Add Photo")
                                .font(.caption)
                        }
                        .foregroundColor(.white)
                    }
                }
            }
            .onChange(of: selectedImage) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        profileImage = image
                    }
                }
            }

            // Bio text editor
            VStack(alignment: .trailing, spacing: 10) {
                ZStack(alignment: .topLeading) {
                    if bio.isEmpty {
                        Text("Share your fitness journey...")
                            .foregroundColor(.gray)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 8)
                    }

                    TextEditor(text: $bio)
                        .scrollContentBackground(.hidden)
                        .background(Color.white.opacity(0.9))
                        .cornerRadius(10)
                        .frame(height: 100)
                }

                Text("\(bio.count)/500")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
            }
            .padding(.horizontal)
        }
        .padding()
    }

    private var privacyStep: some View {
        VStack(spacing: 30) {
            Text("PRIVACY SETTINGS")
                .font(.system(size: 30, weight: .black, design: .rounded))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)

            Text("Choose who can see your profile and workouts")
                .font(.body)
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)

            VStack(spacing: 15) {
                ForEach(ProfilePrivacyLevel.allCases, id: \.self) { level in
                    Button(action: {
                        privacyLevel = level
                    }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(level.displayName)
                                    .font(.headline)
                                Text(level.description)
                                    .font(.caption)
                                    .opacity(0.8)
                            }

                            Spacer()

                            if privacyLevel == level {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            }
                        }
                        .padding()
                        .background(privacyLevel == level ? Color.white.opacity(0.3) : Color.white.opacity(0.1))
                        .cornerRadius(15)
                    }
                    .foregroundColor(.white)
                }
            }
            .padding(.horizontal)

            if isCreatingProfile {
                ProgressView("Creating your profile...")
                    .foregroundColor(.white)
                    .padding()
            }
        }
        .padding()
    }

    // MARK: - Helper Methods

    private var canProceed: Bool {
        switch currentStep {
        case 0:
            isUsernameValid && !username.isEmpty && !isCheckingUsername
        case 1:
            isDisplayNameValid && !displayName.isEmpty
        case 2:
            isBioValid // Bio can be empty
        case 3:
            true
        default:
            false
        }
    }

    private func validateUsername() {
        guard !username.isEmpty else {
            usernameError = nil
            return
        }

        guard UserProfile.isValidUsername(username) else {
            usernameError = "Invalid username format"
            return
        }

        // Debounce username availability check
        Task {
            isCheckingUsername = true
            usernameError = nil

            // Wait a bit to avoid too many requests
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

            // Check if username is still the same
            let currentUsername = username

            do {
                let isAvailable = try await profileService.isUsernameAvailable(username.lowercased())

                // Only update if username hasn't changed
                if currentUsername == username {
                    isCheckingUsername = false
                    if !isAvailable {
                        usernameError = "Username already taken"
                    }
                }
            } catch {
                if currentUsername == username {
                    isCheckingUsername = false
                    // Log the actual error for debugging
                    print("Username check error: \(error)")

                    // Provide more specific error message
                    if let ckError = error as? CKError {
                        switch ckError.code {
                        case .unknownItem:
                            usernameError = "Profile system not set up yet"
                        case .networkUnavailable, .networkFailure:
                            usernameError = "Network error - please try again"
                        case .notAuthenticated:
                            usernameError = "Please sign in to iCloud"
                        default:
                            usernameError = "Error: \(ckError.localizedDescription)"
                        }
                    } else {
                        usernameError = "Error checking username"
                    }
                }
            }
        }
    }

    private func createProfile() {
        isCreatingProfile = true
        creationError = nil

        Task {
            do {
                // Get current user ID from CloudKit
                guard let userId = container.cloudKitManager.currentUserID else {
                    throw ProfileServiceError.profileNotFound
                }

                // Create profile with lowercase username
                // Profile ID will be generated by CloudKit
                let profileId = UUID().uuidString
                let profile = UserProfile(
                    id: profileId,
                    userID: userId, // Reference to Users record
                    username: username.lowercased(),
                    displayName: displayName,
                    bio: bio,
                    workoutCount: container.cloudKitManager.totalWorkouts,
                    totalXP: container.cloudKitManager.totalXP,
                    joinedDate: container.cloudKitManager.joinTimestamp ?? Date(),
                    lastUpdated: Date(),
                    isVerified: false,
                    privacyLevel: privacyLevel,
                    profileImageURL: nil, // TODO: Upload image
                    headerImageURL: nil
                )

                _ = try await profileService.createProfile(profile)

                // Success - dismiss
                await MainActor.run {
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isCreatingProfile = false
                    creationError = error.localizedDescription
                }
            }
        }
    }
}

#Preview {
    ProfileCreationView()
        .environment(\.dependencyContainer, DependencyContainer())
}
