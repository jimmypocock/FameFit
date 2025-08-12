//
//  WelcomeView.swift
//  FameFit
//
//  Welcome step of onboarding - introduces the app concept
//

import SwiftUI

struct WelcomeView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @State private var showContent = false
    @State private var showTagline = false
    @State private var showFeatures = false
    @State private var showCTA = false
    @State private var glowAnimation = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Premium gradient background - full screen
                backgroundGradient
                    .ignoresSafeArea()
                
                // Subtle animated particles
                ParticleEffectView()
                    .opacity(0.3)
                    .ignoresSafeArea()
                
                // Check if content would overflow
                if geometry.size.height < 600 {
                    // Small screen: Scrollable content with sticky CTA
                    ZStack(alignment: .bottom) {
                        ScrollView {
                            VStack(spacing: Spacing.large) {
                                // Logo and brand
                                brandSection
                                    .opacity(showContent ? 1 : 0)
                                    .scaleEffect(showContent ? 1 : 0.8)
                                    .padding(.top, Spacing.xxLarge)
                                
                                // Tagline
                                taglineSection
                                    .opacity(showTagline ? 1 : 0)
                                    .offset(y: showTagline ? 0 : 20)
                                
                                // Feature highlights
                                featureSection
                                    .opacity(showFeatures ? 1 : 0)
                                    .offset(y: showFeatures ? 0 : 30)
                                
                                // Add padding at bottom to prevent content hiding behind CTA
                                Color.clear
                                    .frame(height: 120)
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
                                .opacity(showCTA ? 1 : 0)
                                .offset(y: showCTA ? 0 : 40)
                                .background(BrandColors.gradientDark)
                        }
                    }
                } else {
                    // Regular screen: Fixed layout
                    VStack {
                        // Top section with logo, tagline, and features
                        VStack(spacing: Spacing.large) {
                            // Logo and brand
                            brandSection
                                .opacity(showContent ? 1 : 0)
                                .scaleEffect(showContent ? 1 : 0.8)
                                .padding(.top, Spacing.xxLarge)
                            
                            // Tagline
                            taglineSection
                                .opacity(showTagline ? 1 : 0)
                                .offset(y: showTagline ? 0 : 20)
                            
                            // Feature highlights
                            featureSection
                                .opacity(showFeatures ? 1 : 0)
                                .offset(y: showFeatures ? 0 : 30)
                        }
                        
                        // This pushes everything apart - the key to flexbox-like behavior
                        Spacer(minLength: Spacing.xxLarge)
                        
                        // CTA section at bottom
                        ctaSection
                            .opacity(showCTA ? 1 : 0)
                            .offset(y: showCTA ? 0 : 40)
                    }
                    .frame(maxHeight: .infinity)
                }
            }
        }
        .onAppear {
            animateContent()
        }
    }
    
    // MARK: - Components
    
    private var backgroundGradient: some View {
        BrandColors.premiumGradient
    }
    
    private var brandSection: some View {
        VStack(spacing: Spacing.small) {
            ZStack {
                // Subtle glow effect
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
                    .frame(width: 80, height: 80)
                    .blur(radius: 15)
                    .scaleEffect(glowAnimation ? 1.1 : 0.9)
                    .animation(
                        .easeInOut(duration: 3).repeatForever(autoreverses: true),
                        value: glowAnimation
                    )
                
                // App icon/logo
                Image("AppIconTitle")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 70)
                    .foregroundColor(BrandColors.textPrimary)
            }
            
            // Brand name - properly capitalized
            Text("Welcome to FameFit")
                .heroTextStyle()
        }
    }
    
    private var taglineSection: some View {
        Text("Where fitness meets influence")
            .taglineTextStyle()
            .multilineTextAlignment(.center)
            .padding(.horizontal, Spacing.medium)
            .padding(.bottom, Spacing.xLarge)
    }
    
    private var featureSection: some View {
        VStack(spacing: Spacing.large) {
            WelcomeFeatureRow(
                icon: "chart.line.uptrend.xyaxis",
                text: "Turn sweat into social currency",
                delay: 0.1
            )
            
            WelcomeFeatureRow(
                icon: "star.fill",
                text: "Every workout earns you XP",
                delay: 0.2
            )
            
            WelcomeFeatureRow(
                icon: "person.3.fill",
                text: "Host group workouts",
                delay: 0.3
            )
            
            WelcomeFeatureRow(
                icon: "trophy.fill",
                text: "Challenge your followers",
                delay: 0.4
            )
        }
        .padding(.horizontal, Spacing.xxLarge)
    }
    
    private var ctaSection: some View {
        VStack(spacing: Spacing.medium) {
            // Subtle descriptive text
            Text("Working out without XP? That's just exercise.")
                .ctaTextStyle()
            
            // Sign in with Apple button
            SignInWithAppleButton()
                .frame(height: 54)
                .padding(.horizontal, Spacing.xxLarge)
        }
        .padding(.bottom, Spacing.xLarge)
    }
    
    // MARK: - Animation
    
    private func animateContent() {
        withAnimation(.easeOut(duration: 0.8)) {
            showContent = true
        }
        
        withAnimation(.easeOut(duration: 0.8).delay(0.3)) {
            showTagline = true
        }
        
        withAnimation(.easeOut(duration: 0.8).delay(0.6)) {
            showFeatures = true
        }
        
        withAnimation(.easeOut(duration: 0.8).delay(1.0)) {
            showCTA = true
        }
        
        glowAnimation = true
    }
}

// MARK: - Supporting Views

struct WelcomeFeatureRow: View {
    let icon: String
    let text: String
    let delay: Double
    @State private var isVisible = false
    
    var body: some View {
        OnboardingFeatureRow(icon: icon, text: text)
            .opacity(isVisible ? 1 : 0)
            .offset(x: isVisible ? 0 : -20)
            .onAppear {
                withAnimation(.easeOut(duration: 0.6).delay(delay)) {
                    isVisible = true
                }
            }
    }
}

struct ParticleEffectView: View {
    @State private var particles: [Particle] = []
    
    var body: some View {
        GeometryReader { geometry in
            ForEach(particles) { particle in
                Circle()
                    .fill(Color.white.opacity(particle.opacity))
                    .frame(width: particle.size, height: particle.size)
                    .position(particle.position)
                    .blur(radius: particle.blur)
            }
        }
        .onAppear {
            createParticles()
        }
    }
    
    private func createParticles() {
        for _ in 0..<15 {
            let particle = Particle()
            particles.append(particle)
            animateParticle(particle)
        }
    }
    
    private func animateParticle(_ particle: Particle) {
        withAnimation(.linear(duration: Double.random(in: 15...25)).repeatForever(autoreverses: false)) {
            if let index = particles.firstIndex(where: { $0.id == particle.id }) {
                particles[index].position.y = -100
            }
        }
    }
}

struct Particle: Identifiable {
    let id = UUID()
    var position: CGPoint
    let size: CGFloat
    let opacity: Double
    let blur: CGFloat
    
    init() {
        position = CGPoint(
            x: CGFloat.random(in: 0...UIScreen.main.bounds.width),
            y: CGFloat.random(in: 0...UIScreen.main.bounds.height)
        )
        size = CGFloat.random(in: 2...4)
        opacity = Double.random(in: 0.1...0.3)
        blur = CGFloat.random(in: 0...2)
    }
}

// MARK: - Preview

#Preview("Welcome View") {
    let container = DependencyContainer()
    return WelcomeView(viewModel: OnboardingViewModel(container: container))
        .environmentObject(container.authenticationManager)
        .environmentObject(container.cloudKitManager)
        .environmentObject(container.workoutObserver)
        .environment(\.dependencyContainer, container)
}

#Preview("Welcome View - iPhone SE", traits: .fixedLayout(width: 375, height: 667)) {
    let container = DependencyContainer()
    return WelcomeView(viewModel: OnboardingViewModel(container: container))
        .environmentObject(container.authenticationManager)
        .environmentObject(container.cloudKitManager)
        .environmentObject(container.workoutObserver)
        .environment(\.dependencyContainer, container)
}

