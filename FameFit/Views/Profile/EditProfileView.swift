//
//  EditProfileView.swift
//  FameFit
//
//  View for editing user profiles
//

import PhotosUI
import SwiftUI

struct EditProfileView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.dependencyContainer) var container

    @State private var bio: String
    @State private var privacyLevel: ProfilePrivacyLevel
    @State private var selectedImage: PhotosPickerItem?
    @State private var profileImage: UIImage?

    @State private var isSaving = false
    @State private var saveError: String?
    @State private var hasChanges = false
    @State private var showDiscardAlert = false
    @State private var showDeleteAccountAlert = false
    @State private var isDeletingAccount = false
    @State private var deleteAccountError: String?
    @State private var showActivitySettings = false
    @State private var showDataExport = false
    @State private var showHealthKitSettings = false

    let profile: UserProfile
    let onSave: (UserProfile) -> Void

    private var profileService: UserProfileProtocol {
        container.userProfileService
    }

    init(profile: UserProfile, onSave: @escaping (UserProfile) -> Void) {
        self.profile = profile
        self.onSave = onSave

        // Initialize state with current values
        _bio = State(initialValue: profile.bio)
        _privacyLevel = State(initialValue: profile.privacyLevel)
    }

    // MARK: - View Sections
    
    private var profilePhotoSection: some View {
        Section {
            HStack {
                Spacer()

                PhotosPicker(selection: $selectedImage, matching: .images) {
                    if let profileImage {
                        Image(uiImage: profileImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 100, height: 100)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.gray, lineWidth: 2))
                    } else if profile.profileImageURL != nil {
                        // TODO: Load existing image
                        profileImagePlaceholder
                    } else {
                        profileImagePlaceholder
                    }
                }
                .onChange(of: selectedImage) { _, newItem in
                    Task {
                        if let data = try? await newItem?.loadTransferable(type: Data.self),
                           let image = UIImage(data: data) {
                            profileImage = image
                            hasChanges = true
                        }
                    }
                }

                Spacer()
            }
            .padding(.vertical, 8)
        }
    }
    
    private var accountInfoSection: some View {
        Section(header: Text("Account Info")) {
            HStack {
                Text("Username")
                Spacer()
                Text("@\(profile.username)")
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var profileInfoSection: some View {
        Section(header: Text("Profile Info")) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Bio")
                    Spacer()
                    Text("\(bio.count)/500")
                        .font(.caption)
                        .foregroundColor(bio.count > 500 ? .red : .secondary)
                }

                TextEditor(text: $bio)
                    .frame(minHeight: 100)
                    .onChange(of: bio) { _, _ in
                        hasChanges = true
                    }
            }
        }
    }
    
    private var privacySection: some View {
        Section(header: Text("Privacy")) {
            Picker("Profile Visibility", selection: $privacyLevel) {
                ForEach(ProfilePrivacyLevel.allCases, id: \.self) { level in
                    VStack(alignment: .leading) {
                        Text(level.displayName)
                        Text(level.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .tag(level)
                }
            }
            .pickerStyle(.navigationLink)
            .onChange(of: privacyLevel) { _, _ in
                hasChanges = true
            }
            
            // Activity Sharing Settings
            Button(action: {
                showActivitySettings = true
            }) {
                HStack {
                    Text("Activity Sharing")
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            }
        }
    }
    
    private var validationSection: some View {
        Section {
            if !isDisplayNameValid {
                Label("Display name must be 1-50 characters", systemImage: "exclamationmark.circle")
                    .foregroundColor(.red)
                    .font(.caption)
            }

            if !isBioValid {
                Label("Bio must be 500 characters or less", systemImage: "exclamationmark.circle")
                    .foregroundColor(.red)
                    .font(.caption)
            }
        }
        .listRowBackground(Color.clear)
    }
    
    private var accountSettingsSection: some View {
        Section(header: Text("Account")) {
            // HealthKit Permissions
            Button(action: {
                showHealthKitSettings = true
            }) {
                Label("Manage Health Access", systemImage: "heart.fill")
            }
            
            // Privacy Policy Link
            Link(destination: URL(string: "https://github.com/jimmypocock/FameFit/blob/main/PRIVACY.md")!) {
                HStack {
                    Label("Privacy Policy", systemImage: "lock.shield")
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: "arrow.up.right.square")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            }
            
            // Export Data
            Button(action: {
                showDataExport = true
            }) {
                Label("Export My Data", systemImage: "square.and.arrow.down")
            }
            
            // Delete Account
            Button(action: {
                showDeleteAccountAlert = true
            }) {
                Label("Delete Account", systemImage: "trash")
                    .foregroundColor(.red)
            }
            .disabled(isDeletingAccount)
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                profilePhotoSection
                accountInfoSection
                profileInfoSection
                privacySection
                validationSection
                accountSettingsSection
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        if hasChanges {
                            showDiscardAlert = true
                        } else {
                            dismiss()
                        }
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveProfile()
                    }
                    .disabled(!canSave || isSaving)
                }
            }
            .alert("Save Error", isPresented: .constant(saveError != nil)) {
                Button("OK") {
                    saveError = nil
                }
            } message: {
                Text(saveError ?? "")
            }
            .alert("Discard Changes?", isPresented: $showDiscardAlert) {
                Button("Discard", role: .destructive) {
                    dismiss()
                }
                Button("Keep Editing", role: .cancel) {}
            } message: {
                Text("You have unsaved changes. Are you sure you want to discard them?")
            }
            .alert("Delete Account?", isPresented: $showDeleteAccountAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Delete Account", role: .destructive) {
                    Task {
                        await deleteAccount()
                    }
                }
            } message: {
                Text("This will permanently delete your account and all associated data. This action cannot be undone.\n\nAre you sure you want to delete your FameFit account?")
            }
            .alert("Account Deletion Error", isPresented: .constant(deleteAccountError != nil)) {
                Button("OK") {
                    deleteAccountError = nil
                }
            } message: {
                Text(deleteAccountError ?? "")
            }
            .overlay {
                if isSaving || isDeletingAccount {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .overlay {
                            ProgressView(isDeletingAccount ? "Deleting Account..." : "Saving...")
                                .padding()
                                .background(Color(.systemBackground))
                                .cornerRadius(10)
                                .shadow(radius: 5)
                        }
                }
            }
            .sheet(isPresented: $showActivitySettings) {
                ActivityFeedSettingsView()
                    .environment(\.dependencyContainer, container)
            }
            .sheet(isPresented: $showDataExport) {
                NavigationStack {
                    DataExportView(cloudKitManager: container.cloudKitManager)
                        .navigationTitle("Export Data")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button("Done") {
                                    showDataExport = false
                                }
                            }
                        }
                }
            }
            .sheet(isPresented: $showHealthKitSettings) {
                HealthKitSettingsView()
                    .environment(\.dependencyContainer, container)
            }
        }
    }

    // MARK: - Helper Views

    private var profileImagePlaceholder: some View {
        ZStack {
            Circle()
                .fill(LinearGradient(
                    colors: [Color.purple, Color.blue],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .frame(width: 100, height: 100)

            VStack {
                Image(systemName: "camera.fill")
                    .font(.system(size: 30))
                Text("Edit")
                    .font(.caption)
            }
            .foregroundColor(.white)
        }
    }

    // MARK: - Validation

    private var isDisplayNameValid: Bool {
        true
    }

    private var isBioValid: Bool {
        UserProfile.isValidBio(bio)
    }

    private var canSave: Bool {
        hasChanges && isBioValid
    }

    // MARK: - Save Profile

    private func saveProfile() {
        isSaving = true
        saveError = nil

        Task {
            do {
                // Create updated profile
                let updatedProfile = UserProfile(
                    id: profile.id,
                    userID: profile.userID,
                    username: profile.username,
                    bio: bio,
                    workoutCount: profile.workoutCount,
                    totalXP: profile.totalXP,
                    creationDate: profile.creationDate,
                    modificationDate: Date(),
                    isVerified: profile.isVerified,
                    privacyLevel: privacyLevel,
                    profileImageURL: profile.profileImageURL, // TODO: Handle image upload
                    headerImageURL: profile.headerImageURL
                )

                let savedProfile = try await profileService.updateProfile(updatedProfile)

                await MainActor.run {
                    onSave(savedProfile)
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    saveError = error.localizedDescription
                }
            }
        }
    }
    
    // MARK: - Delete Account
    
    private func deleteAccount() async {
        await MainActor.run {
            isDeletingAccount = true
            deleteAccountError = nil
        }
        
        do {
            // Delete account through authentication manager
            try await container.authenticationManager.deleteAccount()
            
            // Clear profile caches to prevent stale data
            await MainActor.run {
                container.userProfileService.clearAllCaches()
            }
            
            // Account deleted successfully - the sign out in deleteAccount 
            // will trigger the app to return to onboarding
            await MainActor.run {
                isDeletingAccount = false
            }
        } catch {
            await MainActor.run {
                isDeletingAccount = false
                deleteAccountError = "Failed to delete account: \(error.localizedDescription)\n\nPlease try again or contact support."
            }
            FameFitLogger.error("Account deletion failed", error: error, category: FameFitLogger.auth)
        }
    }
}

// MARK: - Preview

#Preview {
    EditProfileView(profile: UserProfile.mockProfile) { _ in }
        .environment(\.dependencyContainer, DependencyContainer())
}
