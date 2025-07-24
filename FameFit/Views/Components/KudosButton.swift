//
//  KudosButton.swift
//  FameFit
//
//  Animated kudos/cheer button component
//

import SwiftUI

struct KudosButton: View {
    let workoutId: String
    let ownerId: String
    let kudosSummary: WorkoutKudosSummary?
    let onTap: () async -> Void
    
    @State private var isAnimating = false
    @State private var showHeart = false
    @State private var particleOffsets: [(x: CGFloat, y: CGFloat)] = []
    
    private var kudosCount: Int {
        kudosSummary?.totalCount ?? 0
    }
    
    private var hasKudos: Bool {
        kudosSummary?.hasUserKudos ?? false
    }
    
    var body: some View {
        HStack(spacing: 8) {
            ZStack {
                // Background heart
                Image(systemName: hasKudos ? "heart.fill" : "heart")
                    .font(.system(size: 22))
                    .foregroundColor(hasKudos ? .red : .gray)
                    .scaleEffect(isAnimating ? 1.3 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isAnimating)
                
                // Animated heart overlay
                if showHeart {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.red)
                        .scaleEffect(showHeart ? 1.5 : 0)
                        .opacity(showHeart ? 0 : 1)
                        .animation(.easeOut(duration: 0.5), value: showHeart)
                }
                
                // Particle effects
                ForEach(0..<6, id: \.self) { index in
                    if showHeart && index < particleOffsets.count {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 4, height: 4)
                            .offset(
                                x: particleOffsets[index].x,
                                y: particleOffsets[index].y
                            )
                            .opacity(showHeart ? 0 : 1)
                            .animation(
                                .easeOut(duration: 0.8).delay(Double(index) * 0.05),
                                value: showHeart
                            )
                    }
                }
            }
            
            if kudosCount > 0 {
                Text("\(kudosCount)")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.gray.opacity(0.1))
        )
        .onTapGesture {
            triggerAnimation()
            Task {
                await onTap()
            }
        }
    }
    
    private func triggerAnimation() {
        // Generate random particle positions
        particleOffsets = (0..<6).map { _ in
            let angle = Double.random(in: 0...(2 * .pi))
            let distance = CGFloat.random(in: 20...40)
            return (
                x: cos(angle) * distance,
                y: sin(angle) * distance
            )
        }
        
        // Trigger animations
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            isAnimating = true
        }
        
        showHeart = true
        
        // Reset animations
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            isAnimating = false
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            showHeart = false
        }
    }
}

// MARK: - Kudos List View

struct KudosListView: View {
    let kudosSummary: WorkoutKudosSummary
    let onUserTap: (String) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("\(kudosSummary.totalCount) Kudos")
                .font(.headline)
            
            if !kudosSummary.recentUsers.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(kudosSummary.recentUsers, id: \.userID) { user in
                        HStack(spacing: 12) {
                            // Profile image
                            profileImage(for: user)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(user.displayName)
                                    .font(.system(size: 14, weight: .medium))
                                
                                Text("@\(user.username)")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            onUserTap(user.userID)
                        }
                    }
                    
                    if kudosSummary.totalCount > kudosSummary.recentUsers.count {
                        Text("and \(kudosSummary.totalCount - kudosSummary.recentUsers.count) others")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .padding(.top, 4)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
    
    private func profileImage(for user: WorkoutKudosSummary.KudosUser) -> some View {
        AsyncImage(url: profileImageURL(for: user)) { image in
            image
                .resizable()
                .aspectRatio(contentMode: .fill)
        } placeholder: {
            Circle()
                .fill(Color.gray.opacity(0.3))
                .overlay(
                    Text(String(user.displayName.prefix(1)))
                        .font(.system(size: 16, weight: .medium))
                )
        }
        .frame(width: 36, height: 36)
        .clipShape(Circle())
    }
    
    private func profileImageURL(for user: WorkoutKudosSummary.KudosUser) -> URL? {
        guard let urlString = user.profileImageURL else { return nil }
        return URL(string: urlString)
    }
}

// MARK: - Preview

struct KudosButton_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            // No kudos
            KudosButton(
                workoutId: "123",
                ownerId: "456",
                kudosSummary: WorkoutKudosSummary(
                    workoutId: "123",
                    totalCount: 0,
                    hasUserKudos: false,
                    recentUsers: []
                ),
                onTap: {}
            )
            
            // With kudos (not liked)
            KudosButton(
                workoutId: "123",
                ownerId: "456",
                kudosSummary: WorkoutKudosSummary(
                    workoutId: "123",
                    totalCount: 42,
                    hasUserKudos: false,
                    recentUsers: []
                ),
                onTap: {}
            )
            
            // With kudos (liked)
            KudosButton(
                workoutId: "123",
                ownerId: "456",
                kudosSummary: WorkoutKudosSummary(
                    workoutId: "123",
                    totalCount: 43,
                    hasUserKudos: true,
                    recentUsers: []
                ),
                onTap: {}
            )
        }
        .padding()
    }
}