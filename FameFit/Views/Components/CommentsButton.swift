//
//  CommentsButton.swift
//  FameFit
//
//  Button component for showing comments on workout cards
//

import SwiftUI

struct CommentsButton: View {
    let workoutId: String
    let commentCount: Int
    let onTap: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = true
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeInOut(duration: 0.1)) {
                    isPressed = false
                }
                onTap()
            }
        }) {
            HStack(spacing: 6) {
                Image(systemName: "bubble.left")
                    .font(.system(size: 18))
                    .foregroundColor(.primary)
                
                if commentCount > 0 {
                    Text("\(commentCount)")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.primary)
                } else {
                    Text("Comment")
                        .font(.system(size: 14))
                        .foregroundColor(.primary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.gray.opacity(0.1))
                    .scaleEffect(isPressed ? 0.95 : 1.0)
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        // No comments
        CommentsButton(
            workoutId: "workout1",
            commentCount: 0,
            onTap: { }
        )
        
        // With comments
        CommentsButton(
            workoutId: "workout2", 
            commentCount: 5,
            onTap: { }
        )
        
        // Many comments
        CommentsButton(
            workoutId: "workout3",
            commentCount: 23,
            onTap: { }
        )
    }
    .padding()
}