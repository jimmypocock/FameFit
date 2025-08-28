//
//  ProfileCreationViewSimple.swift
//  FameFit
//
//  Simplified profile creation without keyboard complexity
//

import CloudKit
import PhotosUI
import SwiftUI

struct ProfileCreationView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @State private var currentStep = 0
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
        ZStack {
            // Background
            BrandColors.premiumGradient
                .ignoresSafeArea()
            
            ParticleEffectView()
                .opacity(0.3)
                .ignoresSafeArea()
            
            // Content
            VStack {
                // Header
                headerSection
                    .padding(.top, Spacing.xxLarge)
                
                // Progress
                progressSection
                    .padding(.horizontal, Spacing.xxLarge)
                    .padding(.bottom, Spacing.medium)
                
                // Current step content - scrollable if needed
                ScrollView {
                    stepContent
                        .padding(.bottom, Spacing.large)
                }
                
                // CTA buttons - always at bottom
                ctaSection
            }
        }
    }
    
    // MARK: - Components
    
    private var headerSection: some View {
        VStack(spacing: Spacing.small) {
            // Title
            Text(stepTitle)
                .heroTextStyle()
            
            // Subtitle
            Text(stepSubtitle)
                .taglineTextStyle()
                .padding(.horizontal, Spacing.medium)
        }
    }
    
    private var progressSection: some View {
        VStack(spacing: Spacing.small) {
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 4)
                    
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.white.opacity(0.8))
                        .frame(width: geometry.size.width * (Double(currentStep + 1) / 3.0), height: 4)
                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: currentStep)
                }
            }
            .frame(height: 4)
            
            // Step labels
            HStack {
                ForEach(0..<3) { index in
                    Text(stepName(for: index))
                        .font(Typography.caption)
                        .foregroundColor(index <= currentStep ? 
                                       BrandColors.textSecondary : BrandColors.textQuaternary)
                    
                    if index < 2 {
                        Spacer()
                    }
                }
            }
        }
    }
    
    private var stepContent: some View {
        VStack(spacing: Spacing.large) {
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
        }
        .animation(.easeInOut(duration: 0.3), value: currentStep)
    }
    
    // MARK: - Step Views
    
    private var usernameStep: some View {
        VStack(spacing: Spacing.large) {
            // Simple white input field
            ZStack(alignment: .leading) {
                TextField("", text: $viewModel.username)
                    .textFieldStyle(.plain)
                    .font(.system(size: 18, weight: .regular))
                    .foregroundColor(.black)
                    .tint(.black)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .padding(Spacing.medium)
                    .background(Color.white)
                    .cornerRadius(12)
                    .onChange(of: viewModel.username) { _, _ in
                        Task {
                            try? await Task.sleep(nanoseconds: 500_000_000)
                            await viewModel.isUsernameAvailable()
                        }
                    }
                
                if viewModel.username.isEmpty {
                    Text("username")
                        .font(.system(size: 18, weight: .regular))
                        .foregroundColor(Color.gray.opacity(0.5))
                        .padding(.horizontal, Spacing.medium)
                        .allowsHitTesting(false)
                }
            }
            
            // Validation feedback
            VStack(spacing: Spacing.xSmall) {
                if viewModel.isCheckingUsername {
                    HStack(spacing: Spacing.xSmall) {
                        ProgressView()
                            .scaleEffect(0.7)
                            .tint(BrandColors.textTertiary)
                        Text("Checking availability...")
                            .font(Typography.caption)
                            .foregroundColor(BrandColors.textTertiary)
                    }
                } else if let error = viewModel.usernameError {
                    Label(error, systemImage: "xmark.circle.fill")
                        .font(Typography.caption)
                        .foregroundColor(.red)
                } else if !viewModel.username.isEmpty && UserProfile.isValidUsername(viewModel.username) {
                    Label("Username available", systemImage: "checkmark.circle.fill")
                        .font(Typography.caption)
                        .foregroundColor(.green)
                }
                
                Text("3-30 characters, letters, numbers, and underscores only")
                    .font(Typography.caption)
                    .foregroundColor(BrandColors.textQuaternary)
            }
        }
        .padding(.horizontal, Spacing.xxLarge)
    }
    
    private var bioStep: some View {
        VStack(spacing: Spacing.large) {
            // Simple white text editor
            ZStack(alignment: .topLeading) {
                TextEditor(text: $viewModel.bio)
                    .scrollContentBackground(.hidden)
                    .font(.system(size: 18, weight: .regular))
                    .foregroundColor(.black)
                    .tint(.black)
                    .padding(Spacing.medium)
                    .frame(height: 120)
                    .background(Color.white)
                    .cornerRadius(12)
                
                if viewModel.bio.isEmpty {
                    Text("Share your fitness goals, favorite workouts, or what motivates you...")
                        .font(.system(size: 18, weight: .regular))
                        .foregroundColor(Color.gray.opacity(0.5))
                        .padding(Spacing.medium + 4)
                        .allowsHitTesting(false)
                }
            }
            .frame(height: 120)
            
            // Character count
            HStack {
                Text("\(viewModel.bio.count)/500")
                    .font(Typography.caption)
                    .foregroundColor(viewModel.bio.count > 500 ? .red : BrandColors.textQuaternary)
                Spacer()
            }
            
            // Optional photo picker
            PhotosPicker(selection: $selectedImage, matching: .images) {
                HStack(spacing: Spacing.medium) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(0.1))
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                            .frame(width: 44, height: 44)
                        
                        if let profileImage {
                            Image(uiImage: profileImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 44, height: 44)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        } else {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.white.opacity(0.9))
                        }
                    }
                    
                    Text(profileImage != nil ? "Change Photo" : "Add Profile Photo")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(.white.opacity(0.85))
                    
                    Spacer()
                    
                    Text("Optional")
                        .font(Typography.caption)
                        .foregroundColor(BrandColors.textQuaternary)
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
        }
        .padding(.horizontal, Spacing.xxLarge)
    }
    
    private var privacyStep: some View {
        VStack(spacing: Spacing.large) {
            ForEach([
                ProfilePrivacyLevel.publicProfile,
                ProfilePrivacyLevel.friendsOnly,
                ProfilePrivacyLevel.privateProfile
            ], id: \.self) { level in
                Button(action: {
                    viewModel.privacyLevel = level
                }) {
                    HStack(spacing: 16) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.white.opacity(0.1))
                                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                                .frame(width: 44, height: 44)
                            
                            Image(systemName: level.iconName)
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(viewModel.privacyLevel == level ? 
                                                .white : .white.opacity(0.6))
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(level.displayName)
                                .font(.system(size: 16, weight: .regular))
                                .foregroundColor(.white.opacity(0.85))
                            
                            Text(level.description)
                                .font(Typography.caption)
                                .foregroundColor(BrandColors.textTertiary)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        
                        Spacer()
                        
                        if viewModel.privacyLevel == level {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 22))
                                .foregroundColor(.green)
                        }
                    }
                    .padding(Spacing.medium)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(viewModel.privacyLevel == level ?
                                  Color.white.opacity(0.15) : Color.white.opacity(0.05))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(viewModel.privacyLevel == level ?
                                           Color.white.opacity(0.2) : Color.clear,
                                           lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, Spacing.xxLarge)
    }
    
    private var ctaSection: some View {
        HStack(spacing: Spacing.medium) {
            // Back button - compact icon only
            if currentStep > 0 {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        currentStep -= 1
                    }
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white)
                        .frame(width: 54, height: 54)
                        .background(
                            LinearGradient(
                                colors: [Color.white.opacity(0.3), Color.white.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                        )
                }
            }
            
            // Next/Create button - takes remaining width
            OnboardingCTAButton(
                title: currentStep == 2 ? "Create Profile" : "Next",
                icon: "chevron.right",
                isLoading: viewModel.isLoading,
                isEnabled: canProceed,
                action: {
                    if currentStep == 2 {
                        Task {
                            await viewModel.createProfile()
                        }
                    } else {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            currentStep += 1
                        }
                    }
                }
            )
        }
        .padding(.horizontal, Spacing.xxLarge)
        .padding(.bottom, Spacing.xLarge)
    }
    
    // MARK: - Helpers
    
    private var stepTitle: String {
        switch currentStep {
        case 0: return "Create Username"
        case 1: return "About You"
        case 2: return "Privacy Settings"
        default: return ""
        }
    }
    
    private var stepSubtitle: String {
        switch currentStep {
        case 0: return "Choose how others will find you"
        case 1: return "Tell your fitness story"
        case 2: return "Control who sees your activity"
        default: return ""
        }
    }
    
    private func stepName(for index: Int) -> String {
        switch index {
        case 0: return "Username"
        case 1: return "Bio"
        case 2: return "Privacy"
        default: return ""
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

// MARK: - Preview

// Preview wrapper to show specific steps
private struct ProfileCreationPreviewWrapper: View {
    @ObservedObject var viewModel: OnboardingViewModel
    let initialStep: Int
    
    var body: some View {
        ProfileCreationViewWithStep(viewModel: viewModel, initialStep: initialStep)
    }
}

// Modified view for preview that can start at specific step
private struct ProfileCreationViewWithStep: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @State private var currentStep: Int
    @State private var selectedImage: PhotosPickerItem?
    @State private var profileImage: UIImage?
    
    init(viewModel: OnboardingViewModel, initialStep: Int) {
        self.viewModel = viewModel
        self._currentStep = State(initialValue: initialStep)
    }
    
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
        // Copy of the main ProfileCreationView body but with local currentStep
        ZStack {
            // Background
            BrandColors.premiumGradient
                .ignoresSafeArea()
            
            ParticleEffectView()
                .opacity(0.3)
                .ignoresSafeArea()
            
            // Content
            VStack {
                // Header
                VStack(spacing: Spacing.small) {
                    // Title
                    Text(stepTitle)
                        .heroTextStyle()
                    
                    // Subtitle
                    Text(stepSubtitle)
                        .taglineTextStyle()
                        .padding(.horizontal, Spacing.medium)
                }
                .padding(.top, Spacing.xxLarge)
                
                // Progress
                VStack(spacing: Spacing.small) {
                    // Progress bar
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.white.opacity(0.1))
                                .frame(height: 4)
                            
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.white.opacity(0.8))
                                .frame(width: geometry.size.width * (Double(currentStep + 1) / 3.0), height: 4)
                                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: currentStep)
                        }
                    }
                    .frame(height: 4)
                    
                    // Step labels
                    HStack {
                        ForEach(0..<3) { index in
                            Text(stepName(for: index))
                                .font(Typography.caption)
                                .foregroundColor(index <= currentStep ? 
                                               BrandColors.textSecondary : BrandColors.textQuaternary)
                            
                            if index < 2 {
                                Spacer()
                            }
                        }
                    }
                }
                .padding(.horizontal, Spacing.xxLarge)
                .padding(.bottom, Spacing.large)
                
                // Current step content - scrollable if needed
                ScrollView {
                    VStack(spacing: Spacing.large) {
                        switch currentStep {
                        case 0:
                            // Username step (simplified for preview)
                            VStack(spacing: Spacing.large) {
                                ZStack(alignment: .leading) {
                                    TextField("", text: $viewModel.username)
                                        .textFieldStyle(.plain)
                                        .font(.system(size: 18, weight: .regular))
                                        .foregroundColor(.black)
                                        .tint(.black)
                                        .autocapitalization(.none)
                                        .disableAutocorrection(true)
                                        .padding(Spacing.medium)
                                        .background(Color.white)
                                        .cornerRadius(12)
                                    
                                    if viewModel.username.isEmpty {
                                        Text("username")
                                            .font(.system(size: 18, weight: .regular))
                                            .foregroundColor(Color.gray.opacity(0.5))
                                            .padding(.horizontal, Spacing.medium)
                                            .allowsHitTesting(false)
                                    }
                                }
                                
                                Text("3-30 characters, letters, numbers, and underscores only")
                                    .font(Typography.caption)
                                    .foregroundColor(BrandColors.textQuaternary)
                            }
                            .padding(.horizontal, Spacing.xxLarge)
                            
                        case 1:
                            // Bio step (simplified for preview)
                            VStack(spacing: Spacing.large) {
                                ZStack(alignment: .topLeading) {
                                    TextEditor(text: $viewModel.bio)
                                        .scrollContentBackground(.hidden)
                                        .font(.system(size: 18, weight: .regular))
                                        .foregroundColor(.black)
                                        .tint(.black)
                                        .padding(Spacing.medium)
                                        .frame(height: 120)
                                        .background(Color.white)
                                        .cornerRadius(12)
                                    
                                    if viewModel.bio.isEmpty {
                                        Text("Share your fitness goals, favorite workouts, or what motivates you...")
                                            .font(.system(size: 18, weight: .regular))
                                            .foregroundColor(Color.gray.opacity(0.5))
                                            .padding(Spacing.medium + 4)
                                            .allowsHitTesting(false)
                                    }
                                }
                                .frame(height: 120)
                                
                                HStack {
                                    Text("\(viewModel.bio.count)/500")
                                        .font(Typography.caption)
                                        .foregroundColor(viewModel.bio.count > 500 ? .red : BrandColors.textQuaternary)
                                    Spacer()
                                }
                            }
                            .padding(.horizontal, Spacing.xxLarge)
                            
                        case 2:
                            // Privacy step (simplified for preview)
                            VStack(spacing: Spacing.large) {
                                ForEach([
                                    ProfilePrivacyLevel.publicProfile,
                                    ProfilePrivacyLevel.friendsOnly,
                                    ProfilePrivacyLevel.privateProfile
                                ], id: \.self) { level in
                                    Button(action: {
                                        viewModel.privacyLevel = level
                                    }) {
                                        HStack(spacing: 16) {
                                            ZStack {
                                                RoundedRectangle(cornerRadius: 12)
                                                    .fill(Color.white.opacity(0.1))
                                                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                                                    .frame(width: 44, height: 44)
                                                
                                                Image(systemName: level.iconName)
                                                    .font(.system(size: 18, weight: .medium))
                                                    .foregroundColor(viewModel.privacyLevel == level ? 
                                                                    .white : .white.opacity(0.6))
                                            }
                                            
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(level.displayName)
                                                    .font(.system(size: 16, weight: .regular))
                                                    .foregroundColor(.white.opacity(0.85))
                                                
                                                Text(level.description)
                                                    .font(Typography.caption)
                                                    .foregroundColor(BrandColors.textTertiary)
                                                    .multilineTextAlignment(.leading)
                                                    .fixedSize(horizontal: false, vertical: true)
                                            }
                                            
                                            Spacer()
                                            
                                            if viewModel.privacyLevel == level {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .font(.system(size: 22))
                                                    .foregroundColor(.green)
                                            }
                                        }
                                        .padding(Spacing.medium)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(viewModel.privacyLevel == level ?
                                                      Color.white.opacity(0.15) : Color.white.opacity(0.05))
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 12)
                                                        .stroke(viewModel.privacyLevel == level ?
                                                               Color.white.opacity(0.2) : Color.clear,
                                                               lineWidth: 1)
                                                )
                                        )
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                            .padding(.horizontal, Spacing.xxLarge)
                            
                        default:
                            EmptyView()
                        }
                    }
                    .padding(.bottom, Spacing.large)
                }
                .animation(.easeInOut(duration: 0.3), value: currentStep)
                
                // CTA buttons - always at bottom
                HStack(spacing: Spacing.medium) {
                    // Back button - compact icon only
                    if currentStep > 0 {
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                currentStep -= 1
                            }
                        }) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.white)
                                .frame(width: 54, height: 54)
                                .background(
                                    LinearGradient(
                                        colors: [Color.white.opacity(0.3), Color.white.opacity(0.2)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                )
                        }
                    }
                    
                    // Next/Create button - takes remaining width
                    OnboardingCTAButton(
                        title: currentStep == 2 ? "Create Profile" : "Next",
                        icon: "chevron.right",
                        isLoading: viewModel.isLoading,
                        isEnabled: canProceed,
                        action: {
                            if currentStep == 2 {
                                // Preview doesn't actually create profile
                            } else {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    currentStep += 1
                                }
                            }
                        }
                    )
                }
                .padding(.horizontal, Spacing.xxLarge)
                .padding(.bottom, Spacing.xLarge)
            }
        }
    }
    
    private var stepTitle: String {
        switch currentStep {
        case 0: return "Create Username"
        case 1: return "About You"
        case 2: return "Privacy Settings"
        default: return ""
        }
    }
    
    private var stepSubtitle: String {
        switch currentStep {
        case 0: return "Choose how others will find you"
        case 1: return "Tell your fitness story"
        case 2: return "Control who sees your activity"
        default: return ""
        }
    }
    
    private func stepName(for index: Int) -> String {
        switch index {
        case 0: return "Username"
        case 1: return "Bio"
        case 2: return "Privacy"
        default: return ""
        }
    }
}

#Preview("Profile Creation - Username") {
    let container = DependencyContainer()
    let viewModel = OnboardingViewModel(container: container)
    ProfileCreationView(viewModel: viewModel)
        .environmentObject(container.authenticationManager)
        .environmentObject(container.cloudKitManager)
        .environmentObject(container.workoutSyncManager)
        .environment(\.dependencyContainer, container)
}

#Preview("Profile Creation - Bio") {
    let container = DependencyContainer()
    let viewModel = OnboardingViewModel(container: container)
    viewModel.username = "fitnessfanatic"
    return ProfileCreationViewWithStep(viewModel: viewModel, initialStep: 1)
        .environmentObject(container.authenticationManager)
        .environmentObject(container.cloudKitManager)
        .environmentObject(container.workoutSyncManager)
        .environment(\.dependencyContainer, container)
}

#Preview("Profile Creation - Privacy") {
    let container = DependencyContainer()
    let viewModel = OnboardingViewModel(container: container)
    viewModel.username = "fitnessfanatic"
    viewModel.bio = "Passionate about fitness and helping others reach their goals! 💪"
    return ProfileCreationViewWithStep(viewModel: viewModel, initialStep: 2)
        .environmentObject(container.authenticationManager)
        .environmentObject(container.cloudKitManager)
        .environmentObject(container.workoutSyncManager)
        .environment(\.dependencyContainer, container)
}

#Preview("Profile Creation - Small Screen", traits: .fixedLayout(width: 375, height: 667)) {
    let container = DependencyContainer()
    ProfileCreationView(viewModel: OnboardingViewModel(container: container))
        .environmentObject(container.authenticationManager)
        .environmentObject(container.cloudKitManager)
        .environmentObject(container.workoutSyncManager)
        .environment(\.dependencyContainer, container)
}
