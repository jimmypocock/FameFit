//
//  GameMechanicsView.swift
//  FameFit
//
//  Game mechanics explanation - final step of onboarding
//

import SwiftUI

struct GameMechanicsView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @State private var glowAnimation = false
    
    // Simplified feature list matching WelcomeView style
    let features = [
        ("figure.run", "Complete workouts to earn XP"),
        ("chart.line.uptrend.xyaxis", "Level up your fitness influence"),
        ("trophy.fill", "Unlock exclusive rewards"),
        ("person.3.fill", "Join group challenges")
    ]
    
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
                                    .frame(height: 140)
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
                            
                            // CTA section - no background needed, button has its own
                            ctaSection
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
            glowAnimation = true
        }
        .disabled(viewModel.isLoading)
    }
    
    // MARK: - Components
    
    private var contentSection: some View {
        VStack(spacing: Spacing.large) {
            // Header icon and title - EXACT same as WelcomeView
            headerSection
                .padding(.top, Spacing.xxLarge)
            
            // Tagline
            taglineSection
            
            // Feature list
            featuresSection
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
                    .scaleEffect(glowAnimation ? 1.1 : 0.9)
                    .animation(
                        .easeInOut(duration: 3).repeatForever(autoreverses: true),
                        value: glowAnimation
                    )
                
                // App icon/logo - using FameFit icon like WelcomeView
                Image("AppIconTitle")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 70)  // EXACT same height as WelcomeView
                    .foregroundColor(BrandColors.textPrimary)
            }
            
            // Title matching WelcomeView's hero style
            Text("Ready to Level Up?")
                .heroTextStyle()
        }
    }
    
    private var taglineSection: some View {
        Text("Turn every workout into influence")
            .taglineTextStyle()
            .multilineTextAlignment(.center)
            .padding(.horizontal, Spacing.medium)  // EXACT same as WelcomeView
            .padding(.bottom, Spacing.xLarge)  // EXACT same as WelcomeView
    }
    
    private var featuresSection: some View {
        VStack(spacing: Spacing.large) {  // EXACT same spacing as WelcomeView featureSection
            GameMechanicsFeatureRow(
                icon: features[0].0,
                text: features[0].1,
                delay: 0.1
            )
            
            GameMechanicsFeatureRow(
                icon: features[1].0,
                text: features[1].1,
                delay: 0.2
            )
            
            GameMechanicsFeatureRow(
                icon: features[2].0,
                text: features[2].1,
                delay: 0.3
            )
            
            GameMechanicsFeatureRow(
                icon: features[3].0,
                text: features[3].1,
                delay: 0.4
            )
        }
        .padding(.horizontal, Spacing.xxLarge)  // EXACT same as WelcomeView
    }
    
    private var ctaSection: some View {
        VStack(spacing: Spacing.medium) {
            // CTA text matching WelcomeView style
            Text("Ready to start earning XP?")
                .ctaTextStyle()
            
            // Primary action button using reusable component
            OnboardingCTAButton(
                title: "Start Your Journey",
                icon: "chevron.right",
                isLoading: viewModel.isLoading,
                action: {
                    Task {
                        await viewModel.completeOnboarding()
                    }
                }
            )
        }
        .padding(.horizontal, Spacing.xxLarge)
        .padding(.bottom, Spacing.xLarge)
    }
    
}

// MARK: - Supporting Views

struct GameMechanicsFeatureRow: View {
    let icon: String
    let text: String
    let delay: Double
    
    var body: some View {
        HStack(spacing: 16) {  // EXACT same spacing as WelcomeFeatureRow
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
    }
}

// MARK: - Preview

// Helper view to show all content immediately in preview - simplified
private struct GameMechanicsPreviewWrapper: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @State private var showAll = true
    
    var body: some View {
        GameMechanicsView(viewModel: viewModel)
            .onAppear {
                // Force all animations to complete immediately for preview
                viewModel.isLoading = false
            }
    }
}

#Preview("Game Mechanics") {
    let container = DependencyContainer()
    GameMechanicsView(viewModel: OnboardingViewModel(container: container))
        .environmentObject(container.authenticationManager)
        .environmentObject(container.cloudKitManager)
        .environmentObject(container.workoutSyncManager)
        .environment(\.dependencyContainer, container)
}

#Preview("Game Mechanics - Static") {
    let container = DependencyContainer()
    let viewModel = OnboardingViewModel(container: container)
    
    GameMechanicsView(viewModel: viewModel)
        .environmentObject(container.authenticationManager)
        .environmentObject(container.cloudKitManager)
        .environmentObject(container.workoutSyncManager)
        .environment(\.dependencyContainer, container)
}

#Preview("Game Mechanics - Small Screen", traits: .fixedLayout(width: 375, height: 667)) {
    let container = DependencyContainer()
    GameMechanicsView(viewModel: OnboardingViewModel(container: container))
        .environmentObject(container.authenticationManager)
        .environmentObject(container.cloudKitManager)
        .environmentObject(container.workoutSyncManager)
        .environment(\.dependencyContainer, container)
}
