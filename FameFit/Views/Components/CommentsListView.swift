//
//  CommentsListView.swift
//  FameFit
//
//  Complete comments interface with threading, input, and state management
//

import SwiftUI

struct CommentsListView: View {
    let workoutId: String
    let workoutOwnerId: String
    let currentUser: UserProfile?

    @StateObject private var viewModel: CommentsViewModel
    @State private var showingInput = false
    @State private var replyToCommentId: String?
    @State private var editingComment: WorkoutComment?
    @State private var searchText = ""

    init(
        workoutId: String,
        workoutOwnerId: String,
        currentUser: UserProfile?,
        commentsService: WorkoutCommentsServicing
    ) {
        self.workoutId = workoutId
        self.workoutOwnerId = workoutOwnerId
        self.currentUser = currentUser
        _viewModel = StateObject(wrappedValue: CommentsViewModel(
            workoutId: workoutId,
            commentsService: commentsService
        ))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header with comment count
            commentsHeader

            // Content
            if viewModel.isLoading && viewModel.comments.isEmpty {
                loadingView
            } else if viewModel.comments.isEmpty && !viewModel.isLoading {
                emptyStateView
            } else {
                commentsList
            }

            // Input area (sticky bottom)
            if showingInput || replyToCommentId != nil || editingComment != nil {
                CommentInputView(
                    workoutId: workoutId,
                    workoutOwnerId: workoutOwnerId,
                    parentCommentId: replyToCommentId,
                    editingComment: editingComment,
                    currentUser: currentUser,
                    onSubmit: handleCommentSubmit,
                    onCancel: handleInputCancel
                )
                .background(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: -2)
            }
        }
        .background(Color(.systemGroupedBackground))
        .onAppear {
            viewModel.loadComments()
        }
        .refreshable {
            await viewModel.refreshComments()
        }
        .searchable(text: $searchText, prompt: "Search comments...")
        .onChange(of: searchText) { _, newValue in
            viewModel.filterComments(searchText: newValue)
        }
    }

    // MARK: - Header

    private var commentsHeader: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Comments")
                        .font(.title2)
                        .fontWeight(.bold)

                    if viewModel.totalComments > 0 {
                        Text("\(viewModel.totalComments) comment\(viewModel.totalComments == 1 ? "" : "s")")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                // Sort options
                Menu {
                    Button(action: { viewModel.setSortOrder(.newest) }) {
                        HStack {
                            Text("Newest First")
                            if viewModel.sortOrder == .newest {
                                Image(systemName: "checkmark")
                            }
                        }
                    }

                    Button(action: { viewModel.setSortOrder(.oldest) }) {
                        HStack {
                            Text("Oldest First")
                            if viewModel.sortOrder == .oldest {
                                Image(systemName: "checkmark")
                            }
                        }
                    }

                    Button(action: { viewModel.setSortOrder(.mostLiked) }) {
                        HStack {
                            Text("Most Liked")
                            if viewModel.sortOrder == .mostLiked {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.system(size: 16))
                        .foregroundColor(.blue)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            // Add comment button (for authenticated users)
            if currentUser != nil {
                HStack {
                    Button(action: { showingInput = true }) {
                        HStack(spacing: 12) {
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
                                                .font(.system(size: 14, weight: .medium))
                                                .foregroundColor(.blue)
                                        )
                                }
                                .frame(width: 32, height: 32)
                                .clipShape(Circle())
                            }

                            Text("Add a comment...")
                                .font(.system(size: 16))
                                .foregroundColor(.secondary)

                            Spacer()

                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.blue)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.systemBackground))
                                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }

            Divider()
        }
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Content Views

    private var commentsList: some View {
        ScrollViewReader { proxy in
            List {
                ForEach(filteredComments, id: \.comment.id) { commentWithUser in
                    CommentRowView(
                        commentWithUser: commentWithUser,
                        currentUserId: currentUser?.id,
                        onReply: { commentId in
                            replyToCommentId = commentId
                            withAnimation(.easeInOut(duration: 0.3)) {
                                proxy.scrollTo("input", anchor: .bottom)
                            }
                        },
                        onEdit: { comment in
                            editingComment = comment
                        },
                        onDelete: { commentId in
                            Task {
                                await viewModel.deleteComment(commentId: commentId)
                            }
                        },
                        onLike: { commentId in
                            Task {
                                await viewModel.toggleCommentLike(commentId: commentId)
                            }
                        },
                        onUserTap: { _ in
                            // Handle user profile navigation
                        }
                    )
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
                }

                // Load more comments
                if viewModel.hasMoreComments, !viewModel.isLoading {
                    Button("Load more comments") {
                        Task {
                            await viewModel.loadMoreComments()
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .font(.system(size: 16))
                    .foregroundColor(.blue)
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
                }

                // Loading indicator
                if viewModel.isLoading, !viewModel.comments.isEmpty {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                    .padding()
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
                }

                // Invisible anchor for scrolling
                Color.clear
                    .frame(height: 1)
                    .id("input")
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
            }
            .listStyle(.plain)
        }
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)

            Text("Loading comments...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 64))
                .foregroundColor(.gray.opacity(0.5))

            VStack(spacing: 8) {
                Text("No comments yet")
                    .font(.title3)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)

                Text("Be the first to share your thoughts about this workout!")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            if currentUser != nil {
                Button("Add Comment") {
                    showingInput = true
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color.blue)
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    // MARK: - Computed Properties

    private var filteredComments: [CommentWithUser] {
        if searchText.isEmpty {
            viewModel.comments
        } else {
            viewModel.comments.filter { commentWithUser in
                commentWithUser.comment.content.localizedCaseInsensitiveContains(searchText) ||
                    commentWithUser.user.displayName.localizedCaseInsensitiveContains(searchText) ||
                    commentWithUser.user.username.localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    // MARK: - Actions

    private func handleCommentSubmit(_ content: String) {
        Task {
            if let editingComment {
                await viewModel.updateComment(
                    commentId: editingComment.id,
                    newContent: content
                )
                self.editingComment = nil
            } else {
                await viewModel.postComment(
                    content: content,
                    parentCommentId: replyToCommentId
                )
                replyToCommentId = nil
                showingInput = false
            }
        }
    }

    private func handleInputCancel() {
        withAnimation(.easeInOut(duration: 0.2)) {
            showingInput = false
            replyToCommentId = nil
            editingComment = nil
        }
    }
}

// MARK: - Comments ViewModel

@MainActor
class CommentsViewModel: ObservableObject {
    @Published var comments: [CommentWithUser] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var totalComments = 0
    @Published var hasMoreComments = true
    @Published var sortOrder: CommentSortOrder = .newest

    private let workoutId: String
    private let commentsService: WorkoutCommentsServicing
    private let pageSize = 20

    enum CommentSortOrder: CaseIterable {
        case newest, oldest, mostLiked

        var displayName: String {
            switch self {
            case .newest: "Newest First"
            case .oldest: "Oldest First"
            case .mostLiked: "Most Liked"
            }
        }
    }

    init(workoutId: String, commentsService: WorkoutCommentsServicing) {
        self.workoutId = workoutId
        self.commentsService = commentsService
    }

    func loadComments() {
        Task {
            await fetchComments(reset: true)
        }
    }

    func refreshComments() async {
        await fetchComments(reset: true)
    }

    func loadMoreComments() async {
        guard hasMoreComments, !isLoading else { return }
        await fetchComments(reset: false)
    }

    func postComment(content: String, parentCommentId: String?) async {
        do {
            _ = try await commentsService.postComment(
                workoutId: workoutId,
                workoutOwnerId: "", // Will be handled by service
                content: content,
                parentCommentId: parentCommentId
            )

            // Reload to get the updated list with proper threading
            await fetchComments(reset: true)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func updateComment(commentId: String, newContent: String) async {
        do {
            let updatedComment = try await commentsService.updateComment(
                commentId: commentId,
                newContent: newContent
            )

            // Update the comment in the local list
            if let index = comments.firstIndex(where: { $0.comment.id == commentId }) {
                comments[index].comment = updatedComment
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteComment(commentId: String) async {
        do {
            try await commentsService.deleteComment(commentId: commentId)
            comments.removeAll { $0.comment.id == commentId }
            totalComments -= 1
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func toggleCommentLike(commentId: String) async {
        do {
            // This would typically check if user has already liked
            _ = try await commentsService.likeComment(commentId: commentId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func setSortOrder(_ newOrder: CommentSortOrder) {
        sortOrder = newOrder
        sortComments()
    }

    func filterComments(searchText _: String) {
        // Filtering is handled in the view
    }

    // MARK: - Private Methods

    private func fetchComments(reset: Bool) async {
        if reset {
            isLoading = true
        }

        do {
            let fetchedComments = try await commentsService.fetchComments(
                for: workoutId,
                limit: pageSize
            )

            if reset {
                comments = fetchedComments
            } else {
                comments.append(contentsOf: fetchedComments)
            }

            hasMoreComments = fetchedComments.count == pageSize

            // Get total count
            totalComments = try await commentsService.fetchCommentCount(for: workoutId)

            sortComments()
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func sortComments() {
        switch sortOrder {
        case .newest:
            comments.sort { $0.comment.createdTimestamp > $1.comment.createdTimestamp }
        case .oldest:
            comments.sort { $0.comment.createdTimestamp < $1.comment.createdTimestamp }
        case .mostLiked:
            comments.sort { $0.comment.likeCount > $1.comment.likeCount }
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationView {
        CommentsListView(
            workoutId: "sample-workout",
            workoutOwnerId: "owner123",
            currentUser: UserProfile(
                id: "current",
                userID: "current",
                username: "currentuser",
                displayName: "Current User",
                bio: "Test user",
                workoutCount: 25,
                totalXP: 500,
                joinedDate: Date().addingTimeInterval(-86_400 * 90),
                lastUpdated: Date(),
                isVerified: false,
                privacyLevel: .publicProfile,
                profileImageURL: nil
            ),
            commentsService: PreviewMockCommentsService()
        )
    }
}

// MARK: - Preview Mock

private class PreviewMockCommentsService: WorkoutCommentsServicing {
    func fetchComments(for _: String, limit _: Int) async throws -> [CommentWithUser] {
        []
    }

    func postComment(
        workoutId: String,
        workoutOwnerId: String,
        content: String,
        parentCommentId _: String?
    ) async throws -> WorkoutComment {
        WorkoutComment(
            id: UUID().uuidString,
            workoutId: workoutId,
            userId: "current",
            workoutOwnerId: workoutOwnerId,
            content: content,
            createdTimestamp: Date(),
            modifiedTimestamp: Date()
        )
    }

    func updateComment(commentId: String, newContent: String) async throws -> WorkoutComment {
        WorkoutComment(
            id: commentId,
            workoutId: "workout",
            userId: "current",
            workoutOwnerId: "owner",
            content: newContent,
            createdTimestamp: Date(),
            modifiedTimestamp: Date(),
            isEdited: true
        )
    }

    func deleteComment(commentId _: String) async throws {
        // Mock delete
    }

    func likeComment(commentId _: String) async throws -> Int {
        1
    }

    func unlikeComment(commentId _: String) async throws -> Int {
        0
    }

    func fetchCommentCount(for _: String) async throws -> Int {
        0
    }
}
