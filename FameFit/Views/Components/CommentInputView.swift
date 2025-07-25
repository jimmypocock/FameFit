//
//  CommentInputView.swift
//  FameFit
//
//  Comment composition and editing component
//

import SwiftUI

struct CommentInputView: View {
    let workoutId: String
    let workoutOwnerId: String
    let parentCommentId: String?
    let editingComment: WorkoutComment?
    let currentUser: UserProfile?
    let onSubmit: (String) -> Void
    let onCancel: () -> Void

    @State private var commentText = ""
    @State private var isSubmitting = false
    @FocusState private var isTextFieldFocused: Bool

    private let maxCharacters = 500

    var body: some View {
        VStack(spacing: 0) {
            // Reply context indicator
            if parentCommentId != nil {
                replyContextView
            }

            // Input area
            VStack(spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    // User profile image
                    if let user = currentUser {
                        AsyncImage(url: user.profileImageURL.flatMap { URL(string: $0) }) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Circle()
                                .fill(Color.blue.opacity(0.2))
                                .overlay(
                                    Text(user.displayName.prefix(1))
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.blue)
                                )
                        }
                        .frame(width: 36, height: 36)
                        .clipShape(Circle())
                    } else {
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 36, height: 36)
                            .overlay(
                                Image(systemName: "person.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(.gray)
                            )
                    }

                    // Text input
                    VStack(alignment: .leading, spacing: 8) {
                        ZStack(alignment: .topLeading) {
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color(.systemGray6))
                                .frame(minHeight: 44)

                            TextField(placeholderText, text: $commentText, axis: .vertical)
                                .textFieldStyle(.plain)
                                .lineLimit(1 ... 6)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .focused($isTextFieldFocused)
                                .onChange(of: commentText) { _, newValue in
                                    if newValue.count > maxCharacters {
                                        commentText = String(newValue.prefix(maxCharacters))
                                    }
                                }
                        }

                        // Character count and actions
                        HStack {
                            // Character count
                            Text("\(commentText.count)/\(maxCharacters)")
                                .font(.caption)
                                .foregroundColor(commentText.count > maxCharacters * 90 / 100 ? .orange : .secondary)

                            Spacer()

                            // Action buttons
                            HStack(spacing: 12) {
                                // Cancel button
                                Button("Cancel") {
                                    commentText = ""
                                    isTextFieldFocused = false
                                    onCancel()
                                }
                                .font(.system(size: 16))
                                .foregroundColor(.secondary)

                                // Submit button
                                Button(submitButtonTitle) {
                                    submitComment()
                                }
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 20)
                                        .fill(canSubmit ? Color.blue : Color.gray.opacity(0.5))
                                )
                                .disabled(!canSubmit || isSubmitting)
                            }
                        }
                    }
                }

                // Submission guidelines (only for new comments)
                if editingComment == nil, commentText.isEmpty, isTextFieldFocused {
                    submissionGuidelines
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding(16)
            .background(Color(.systemBackground))
        }
        .onAppear {
            if let editingComment {
                commentText = editingComment.content
            }
            // Auto-focus when replying
            if parentCommentId != nil {
                isTextFieldFocused = true
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isTextFieldFocused)
    }

    // MARK: - Computed Properties

    private var placeholderText: String {
        if editingComment != nil {
            "Edit your comment..."
        } else if parentCommentId != nil {
            "Write a reply..."
        } else {
            "Add a comment..."
        }
    }

    private var submitButtonTitle: String {
        if isSubmitting {
            "..."
        } else if editingComment != nil {
            "Update"
        } else {
            "Post"
        }
    }

    private var canSubmit: Bool {
        !commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            commentText.count <= maxCharacters &&
            !isSubmitting
    }

    // MARK: - Subviews

    private var replyContextView: some View {
        HStack(spacing: 8) {
            Image(systemName: "arrowshape.turn.up.left")
                .font(.system(size: 14))
                .foregroundColor(.blue)

            Text("Replying to comment")
                .font(.system(size: 14))
                .foregroundColor(.secondary)

            Spacer()

            Button(action: onCancel) {
                Image(systemName: "xmark")
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.blue.opacity(0.05))
    }

    private var submissionGuidelines: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "info.circle")
                    .font(.system(size: 14))
                    .foregroundColor(.blue)

                Text("Comment Guidelines")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.blue)
            }

            VStack(alignment: .leading, spacing: 4) {
                guidelineItem("Be respectful and encouraging")
                guidelineItem("Keep feedback constructive")
                guidelineItem("No spam or inappropriate content")
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.blue.opacity(0.05))
        )
    }

    private func guidelineItem(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 12))
                .foregroundColor(.green)
                .padding(.top, 2)

            Text(text)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Actions

    private func submitComment() {
        let trimmedText = commentText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }

        isSubmitting = true

        // Simulate API call delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            onSubmit(trimmedText)
            commentText = ""
            isSubmitting = false
            isTextFieldFocused = false
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        // New comment
        CommentInputView(
            workoutId: "workout1",
            workoutOwnerId: "owner1",
            parentCommentId: nil,
            editingComment: nil,
            currentUser: UserProfile(
                id: "current",
                userID: "current",
                username: "currentuser",
                displayName: "Current User",
                bio: "Test user",
                workoutCount: 25,
                totalXP: 500,
                joinedDate: Date().addingTimeInterval(-86400 * 90),
                lastUpdated: Date(),
                isVerified: false,
                privacyLevel: .publicProfile,
                profileImageURL: nil
            ),
            onSubmit: { _ in },
            onCancel: {}
        )

        Divider()

        // Reply to comment
        CommentInputView(
            workoutId: "workout1",
            workoutOwnerId: "owner1",
            parentCommentId: "parent1",
            editingComment: nil,
            currentUser: UserProfile(
                id: "current",
                userID: "current",
                username: "currentuser",
                displayName: "Current User",
                bio: "Test user",
                workoutCount: 25,
                totalXP: 500,
                joinedDate: Date().addingTimeInterval(-86400 * 90),
                lastUpdated: Date(),
                isVerified: false,
                privacyLevel: .publicProfile,
                profileImageURL: nil
            ),
            onSubmit: { _ in },
            onCancel: {}
        )
    }
    .background(Color(.systemGroupedBackground))
}
