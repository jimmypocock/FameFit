//
//  HealthKitPermissionView.swift
//  FameFit
//
//  HealthKit permissions step of onboarding
//

import SwiftUI

struct HealthKitPermissionView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @State private var showContent = false
    @State private var showFeatures = false
    @State private var showCTA = false
    @State private var pulseAnimation = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Premium gradient background
                BrandColors.premiumGradient
                    .ignoresSafeArea()
                
                // Subtle animated particles
                ParticleEffectView()
                    .opacity(0.3)
                    .ignoresSafeArea()
                
                if geometry.size.height < 600 {
                    // Small screen: Scrollable content with sticky CTA
                    ZStack(alignment: .bottom) {
                        ScrollView {
                            VStack(spacing: Spacing.large) {
                                contentSection
                                
                                // Add padding at bottom to prevent content hiding behind CTA
                                Color.clear
                                    .frame(height: 160)
                            }
                        }
                        .scrollIndicators(.hidden)
                        
                        // Sticky CTA with gradient fade
                        VStack(spacing: 0) {
                            // Gradient fade from transparent to background
                            LinearGradient(
                                colors: [
                                    BrandColors.gradientDark.opacity(0),
                                    BrandColors.gradientDark
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            .frame(height: 20)
                            
                            // CTA on solid background
                            ctaSection
                                .background(BrandColors.gradientDark)
                        }
                    }
                } else {
                    // Regular screen: Fixed layout
                    VStack {
                        contentSection
                        
                        Spacer(minLength: Spacing.xxLarge)
                        
                        ctaSection
                    }
                    .frame(maxHeight: .infinity)
                }
            }
        }
        .onAppear {
            animateContent()
            // Check permission status when view appears
            viewModel.checkHealthKitPermissions()
        }
        .onChange(of: viewModel.hasHealthKitPermission) { _, hasPermission in
            // If permission granted, immediately move to next step
            if hasPermission {
                viewModel.moveToNextStep()
            }
        }
    }
    
    // MARK: - Components
    
    private var contentSection: some View {
        VStack(spacing: Spacing.large) {
            // Header icon and title - EXACT same as WelcomeView's brandSection
            headerSection
                .opacity(showContent ? 1 : 0)
                .scaleEffect(showContent ? 1 : 0.8)
                .padding(.top, Spacing.xxLarge)
            
            // Tagline - EXACT same animation as WelcomeView
            taglineSection
                .opacity(showFeatures ? 1 : 0)  // Note: using showFeatures for timing match
                .offset(y: showFeatures ? 0 : 20)
            
            // Feature list
            featuresSection
                .opacity(showFeatures ? 1 : 0)
                .offset(y: showFeatures ? 0 : 30)
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: Spacing.small) {  // EXACT same spacing as WelcomeView brandSection
            ZStack {
                // Subtle glow effect - EXACT same as WelcomeView (80x80, radius 50)
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                BrandColors.glowColor,
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 50
                        )
                    )
                    .frame(width: 80, height: 80)  // EXACT same as WelcomeView
                    .blur(radius: 15)
                    .scaleEffect(pulseAnimation ? 1.1 : 0.9)
                    .animation(
                        .easeInOut(duration: 3).repeatForever(autoreverses: true),
                        value: pulseAnimation
                    )
                
                // Heart icon with red accent - same size as logo (70pt)
                Image(systemName: "heart.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 70)  // EXACT same height as AppIconTitle in WelcomeView
                    .foregroundColor(.red)  // Using accent color as requested
            }
            
            Text("Health Access")
                .heroTextStyle()  // Using same hero style as WelcomeView
        }
    }
    
    private var taglineSection: some View {
        Text("Connect your workouts to earn XP")
            .taglineTextStyle()
            .multilineTextAlignment(.center)
            .padding(.horizontal, Spacing.medium)  // EXACT same as WelcomeView
            .padding(.bottom, Spacing.xLarge)  // EXACT same as WelcomeView
    }
    
    private var featuresSection: some View {
        VStack(spacing: Spacing.large) {  // EXACT same spacing as WelcomeView featureSection
            HealthKitFeatureRow(
                icon: "figure.run",
                text: "Automatically track your workouts",
                delay: 0.1
            )
            
            HealthKitFeatureRow(
                icon: "chart.line.uptrend.xyaxis",
                text: "Monitor your fitness progress",
                delay: 0.2
            )
            
            HealthKitFeatureRow(
                icon: "star.fill",
                text: "Earn XP for every workout",
                delay: 0.3
            )
            
            HealthKitFeatureRow(
                icon: "trophy.fill",
                text: "Unlock achievements & badges",
                delay: 0.4
            )
        }
        .padding(.horizontal, Spacing.xxLarge)
    }
    
    private var ctaSection: some View {
        VStack(spacing: Spacing.medium) {
            // Only show button if we don't have permission
            if !viewModel.hasHealthKitPermission {
                // Primary CTA - keeping red for Grant Access
                Button(action: {
                    viewModel.requestHealthKitPermissions()
                }) {
                    HStack {
                        Image(systemName: "heart.circle.fill")
                            .font(.title3)
                        Text("Grant Access")
                            .font(Typography.button)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(
                        LinearGradient(
                            colors: [Color.red, Color.red.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .cornerRadius(12)
                    .shadow(color: Color.red.opacity(0.3), radius: 10, x: 0, y: 5)
                }
                .disabled(viewModel.isLoading)
                .opacity(showCTA ? 1 : 0)
                .offset(y: showCTA ? 0 : 20)
                
                // Helper text and skip option with more spacing
                VStack(spacing: Spacing.small) {
                    Text("You can enable this later in Settings")
                        .font(Typography.caption)
                        .foregroundColor(BrandColors.textQuaternary.opacity(0.7))
                        .multilineTextAlignment(.center)
                    
                    // Skip button with more distance from Grant Access
                    Button(action: {
                        viewModel.skipCurrentStep()
                    }) {
                        Text("Continue Without Health Access")
                            .font(Typography.bodySmall)
                            .foregroundColor(BrandColors.textQuaternary)
                            .underline()
                    }
                    .padding(.top, Spacing.xSmall)  // Extra padding to separate from helper text
                }
                .opacity(showCTA ? 1 : 0)
            }
        }
        .padding(.horizontal, Spacing.xxLarge)  // EXACT same as WelcomeView
        .padding(.bottom, Spacing.xLarge)  // EXACT same as WelcomeView
    }
    
    // MARK: - Animation
    
    private func animateContent() {
        withAnimation(.easeOut(duration: 0.8)) {
            showContent = true
        }
        
        withAnimation(.easeOut(duration: 0.8).delay(0.3)) {
            showFeatures = true
        }
        
        withAnimation(.easeOut(duration: 0.8).delay(0.6)) {
            showCTA = true
        }
        
        pulseAnimation = true
    }
}

// MARK: - Supporting Views

struct HealthKitFeatureRow: View {
    let icon: String
    let text: String
    let delay: Double
    @State private var isVisible = false
    
    var body: some View {
        HStack(spacing: 16) {  // EXACT same spacing as WelcomeFeatureRow in WelcomeView
            // Icon with glass effect - EXACT copy from WelcomeView
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.1))
                    .background(
                        .ultraThinMaterial,
                        in: RoundedRectangle(cornerRadius: 12)
                    )
                    .frame(width: 44, height: 44)
                
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white.opacity(0.9))  // EXACT same as WelcomeView
            }
            
            Text(text)
                .font(.system(size: 16, weight: .regular))  // EXACT same as WelcomeView
                .foregroundColor(.white.opacity(0.85))  // EXACT same as WelcomeView
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.leading)
            
            Spacer()
        }
        .opacity(isVisible ? 1 : 0)
        .offset(x: isVisible ? 0 : -20)
        .onAppear {
            withAnimation(.easeOut(duration: 0.6).delay(delay)) {
                isVisible = true
            }
        }
    }
}

// MARK: - Preview

#Preview("HealthKit Permission") {
    let container = DependencyContainer()
    return HealthKitPermissionView(viewModel: OnboardingViewModel(container: container))
        .environmentObject(container.authenticationManager)
        .environmentObject(container.cloudKitManager)
        .environmentObject(container.workoutObserver)
        .environment(\.dependencyContainer, container)
}

#Preview("HealthKit - Small Screen", traits: .fixedLayout(width: 375, height: 667)) {
    let container = DependencyContainer()
    return HealthKitPermissionView(viewModel: OnboardingViewModel(container: container))
        .environmentObject(container.authenticationManager)
        .environmentObject(container.cloudKitManager)
        .environmentObject(container.workoutObserver)
        .environment(\.dependencyContainer, container)
}