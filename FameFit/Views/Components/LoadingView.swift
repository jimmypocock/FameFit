//
//  LoadingView.swift
//  FameFit
//
//  Full-screen loading view shown during app initialization
//

import SwiftUI

struct LoadingView: View {
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            // Full black background
            Color.black
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                // App Icon or Logo (if you have one)
                Image(systemName: "figure.run.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.white)
                    .rotationEffect(.degrees(isAnimating ? 360 : 0))
                    .animation(
                        Animation.linear(duration: 2)
                            .repeatForever(autoreverses: false),
                        value: isAnimating
                    )
                
                // Loading indicator
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.5)
                
                // Loading text
                Text("Loading FameFit...")
                    .font(.headline)
                    .foregroundColor(.white.opacity(0.8))
            }
        }
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - Preview

#Preview {
    LoadingView()
}