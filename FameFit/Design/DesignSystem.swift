//
//  DesignSystem.swift
//  FameFit
//
//  Centralized design system for consistent styling across the app
//

import SwiftUI

// MARK: - Spacing

enum Spacing {
    static let xxxSmall: CGFloat = 4
    static let xxSmall: CGFloat = 8
    static let xSmall: CGFloat = 12
    static let small: CGFloat = 16
    static let medium: CGFloat = 20
    static let large: CGFloat = 24
    static let xLarge: CGFloat = 32
    static let xxLarge: CGFloat = 40
    static let xxxLarge: CGFloat = 48
    static let huge: CGFloat = 60
}

// MARK: - Typography

struct Typography {
    // Hero/Display styles
    static let hero = Font.system(size: 32, weight: .light, design: .default)
    static let heroTracking: CGFloat = 3
    
    // Title styles
    static let largeTitle = Font.system(size: 28, weight: .semibold, design: .default)
    static let title = Font.system(size: 24, weight: .semibold, design: .default)
    static let title2 = Font.system(size: 20, weight: .semibold, design: .default)
    static let title3 = Font.system(size: 18, weight: .semibold, design: .default)
    
    // Body styles
    static let body = Font.system(size: 16, weight: .regular, design: .default)
    static let bodyLight = Font.system(size: 16, weight: .light, design: .default)
    static let bodySmall = Font.system(size: 14, weight: .regular, design: .default)
    
    // Caption styles
    static let caption = Font.system(size: 12, weight: .regular, design: .default)
    static let captionLight = Font.system(size: 12, weight: .light, design: .default)
    
    // CTA styles
    static let button = Font.system(size: 16, weight: .medium, design: .default)
    static let buttonSmall = Font.system(size: 14, weight: .medium, design: .default)
}

// MARK: - Colors

struct BrandColors {
    // Primary gradient colors
    static let gradientDark = Color(hex: "0F0F0F")
    static let gradientMid = Color(hex: "1C1C2E")
    static let gradientLight = Color(hex: "2A2A3E")
    
    // Text colors
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.85)
    static let textTertiary = Color.white.opacity(0.7)
    static let textQuaternary = Color.white.opacity(0.6)
    
    // UI colors
    static let glassFill = Color.white.opacity(0.1)
    static let glowColor = Color.white.opacity(0.2)
    
    // Semantic colors
    static let success = Color.green
    static let warning = Color.orange
    static let error = Color.red
    static let info = Color.blue
    
    // Legacy gradient (for other onboarding screens)
    static let legacyGradient = LinearGradient(
        colors: [Color.purple, Color.blue],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    // Premium gradient
    static var premiumGradient: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: gradientDark, location: 0.0),
                .init(color: gradientMid, location: 0.5),
                .init(color: gradientLight, location: 1.0)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - View Modifiers

struct HeroTextStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(Typography.hero)
            .tracking(Typography.heroTracking)
            .foregroundColor(BrandColors.textPrimary)
    }
}

struct TaglineTextStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(Typography.bodyLight)
            .foregroundColor(BrandColors.textTertiary)
            .tracking(0.5)
    }
}

struct FeatureTextStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(Typography.body)
            .foregroundColor(BrandColors.textSecondary)
    }
}

struct CTATextStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 15, weight: .regular))
            .foregroundColor(BrandColors.textQuaternary)
            .tracking(0.5)
    }
}

struct GlassCardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(BrandColors.glassFill)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - View Extensions

extension View {
    func heroTextStyle() -> some View {
        modifier(HeroTextStyle())
    }
    
    func taglineTextStyle() -> some View {
        modifier(TaglineTextStyle())
    }
    
    func featureTextStyle() -> some View {
        modifier(FeatureTextStyle())
    }
    
    func ctaTextStyle() -> some View {
        modifier(CTATextStyle())
    }
    
    func glassCardStyle() -> some View {
        modifier(GlassCardStyle())
    }
}

// MARK: - Layout Components

struct OnboardingContainer<Content: View>: View {
    let content: Content
    let showGradient: Bool
    
    init(showGradient: Bool = true, @ViewBuilder content: () -> Content) {
        self.showGradient = showGradient
        self.content = content()
    }
    
    var body: some View {
        ZStack {
            if showGradient {
                BrandColors.premiumGradient
                    .ignoresSafeArea()
            }
            content
        }
    }
}

// MARK: - Common Components

struct OnboardingFeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: Spacing.small) {
            // Icon with glass effect
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(BrandColors.glassFill)
                    .background(
                        .ultraThinMaterial,
                        in: RoundedRectangle(cornerRadius: 12)
                    )
                    .frame(width: 44, height: 44)
                
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(BrandColors.textPrimary.opacity(0.9))
            }
            
            Text(text)
                .featureTextStyle()
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.leading)
            
            Spacer()
        }
    }
}