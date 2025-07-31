//
//  CommentRowView.swift
//  FameFit
//
//  Individual comment row component with threading support
//

import SwiftUI

struct CommentRowView: View {
    let commentWithUser: CommentWithUser
    let currentUserId: String?
    let onReply: (String) -> Void
    let onEdit: (ActivityComment) -> Void
    let onDelete: (String) -> Void
    let onLike: (String) -> Void
    let onUserTap: (String) -> Void

    @State private var showingActions = false
    @State private var isLiked = false
    @State private var likeCount = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                // Thread indicator for replies
                if commentWithUser.comment.parentCommentId != nil {
                    VStack {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 2)
                            .padding(.top, 24)

                        Spacer()
                    }
                    .frame(width: 20)
                }

                // User profile image
                Button(action: { onUserTap(commentWithUser.user.id) }) {
                    AsyncImage(url: commentWithUser.user.profileImageURL.flatMap { URL(string: $0) }) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Circle()
                            .fill(Color.blue.opacity(0.2))
                            .overlay(
                                Text(commentWithUser.user.username.prefix(1).uppercased())
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.blue)
                            )
                    }
                    .frame(width: 40, height: 40)
                    .clipShape(Circle())
                }

                // Comment content
                VStack(alignment: .leading, spacing: 8) {
                    // User info and timestamp
                    HStack(alignment: .top, spacing: 8) {
                        Button(action: { onUserTap(commentWithUser.user.id) }) {
                            HStack(spacing: 4) {
                                Text(commentWithUser.user.username)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.primary)

                                if commentWithUser.user.isVerified {
                                    Image(systemName: "checkmark.seal.fill")
                                        .font(.system(size: 12))
                                        .foregroundColor(.blue)
                                }
                            }
                        }

                        Text("@\(commentWithUser.user.username)")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)

                        Spacer()

                        HStack(spacing: 4) {
                            Text(timeAgoString)
                                .font(.caption)
                                .foregroundColor(.secondary)

                            if commentWithUser.comment.isEdited {
                                Text("•")
                                    .font(.caption)
                                    .foregroundColor(.secondary)

                                Text("edited")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }

                    // Comment text
                    Text(commentWithUser.comment.content)
                        .font(.system(size: 15))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(nil)

                    // Action buttons
                    HStack(spacing: 16) {
                        // Like button
                        Button(action: {
                            onLike(commentWithUser.comment.id)
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isLiked.toggle()
                                likeCount += isLiked ? 1 : -1
                            }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: isLiked ? "heart.fill" : "heart")
                                    .font(.system(size: 14))
                                    .foregroundColor(isLiked ? .red : .gray)
                                    .scaleEffect(isLiked ? 1.1 : 1.0)
                                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isLiked)

                                if likeCount > 0 {
                                    Text("\(likeCount)")
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                }
                            }
                        }

                        // Reply button
                        Button(action: { onReply(commentWithUser.comment.id) }) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrowshape.turn.up.left")
                                    .font(.system(size: 14))
                                    .foregroundColor(.gray)

                                Text("Reply")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                        }

                        Spacer()

                        // More options for own comments
                        if commentWithUser.comment.userId == currentUserId {
                            Button(action: { showingActions.toggle() }) {
                                Image(systemName: "ellipsis")
                                    .font(.system(size: 14))
                                    .foregroundColor(.gray)
                            }
                            .confirmationDialog("Comment Options", isPresented: $showingActions) {
                                Button("Edit") {
                                    onEdit(commentWithUser.comment)
                                }

                                Button("Delete", role: .destructive) {
                                    onDelete(commentWithUser.comment.id)
                                }

                                Button("Cancel", role: .cancel) {}
                            }
                        }
                    }
                    .padding(.top, 4)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .onAppear {
            likeCount = commentWithUser.comment.likeCount
        }
    }

    private var timeAgoString: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: commentWithUser.comment.createdTimestamp, relativeTo: Date())
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        VStack(spacing: 0) {
            // Parent comment
            CommentRowView(
                commentWithUser: CommentWithUser(
                    comment: ActivityComment(
                        id: "1",
                        activityFeedId: "feed1",
                        sourceType: "workout",
                        sourceRecordId: "workout1",
                        userId: "user1",
                        activityOwnerId: "owner1",
                        content: "Great workout! Your form looked amazing throughout the entire session. Keep it up! 💪",
                        createdTimestamp: Date().addingTimeInterval(-3_600),
                        modifiedTimestamp: Date().addingTimeInterval(-3_600),
                        parentCommentId: nil,
                        isEdited: false,
                        likeCount: 3
                    ),
                    user: UserProfile(
                        id: "user1",
                        userID: "user1",
                        username: "fitnessCoach",
                        bio: "Certified trainer",
                        workoutCount: 127,
                        totalXP: 5_000,
                        createdTimestamp: Date().addingTimeInterval(-86_400 * 365),
                        modifiedTimestamp: Date(),
                        isVerified: true,
                        privacyLevel: .publicProfile,
                        profileImageURL: nil
                    )
                ),
                currentUserId: "currentUser",
                onReply: { _ in },
                onEdit: { _ in },
                onDelete: { _ in },
                onLike: { _ in },
                onUserTap: { _ in }
            )

            Divider()

            // Reply comment
            CommentRowView(
                commentWithUser: CommentWithUser(
                    comment: ActivityComment(
                        id: "2",
                        activityFeedId: "feed1",
                        sourceType: "workout",
                        sourceRecordId: "workout1",
                        userId: "user2",
                        activityOwnerId: "owner1",
                        content: "Thanks for the motivation! 🙏",
                        createdTimestamp: Date().addingTimeInterval(-1_800),
                        modifiedTimestamp: Date().addingTimeInterval(-1_800),
                        parentCommentId: "1",
                        isEdited: false,
                        likeCount: 1
                    ),
                    user: UserProfile(
                        id: "user2",
                        userID: "user2",
                        username: "runner_mike",
                        bio: "Weekend warrior",
                        workoutCount: 45,
                        totalXP: 1_200,
                        createdTimestamp: Date().addingTimeInterval(-86_400 * 180),
                        modifiedTimestamp: Date(),
                        isVerified: false,
                        privacyLevel: .publicProfile,
                        profileImageURL: nil
                    )
                ),
                currentUserId: "currentUser",
                onReply: { _ in },
                onEdit: { _ in },
                onDelete: { _ in },
                onLike: { _ in },
                onUserTap: { _ in }
            )
        }
    }
}
