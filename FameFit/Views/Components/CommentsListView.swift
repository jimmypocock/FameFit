//
//  CommentsListView.swift
//  FameFit
//
//  Complete comments interface with threading, input, and state management
//

import SwiftUI

struct CommentsListView: View {
    let workoutID: String
    let workoutOwnerID: String
    let currentUser: UserProfile?

    @StateObject private var viewModel: CommentsViewModel
    @State private var showingInput = false
    @State private var replyToCommentID: String?
    @State private var editingComment: ActivityFeedComment?
    @State private var searchText = ""

    init(
        workoutID: String,
        workoutOwnerID: String,
        currentUser: UserProfile?,
        commentsService: ActivityFeedCommentsServicing
    ) {
        self.workoutID = workoutID
        self.workoutOwnerID = workoutOwnerID
        self.currentUser = currentUser
        _viewModel = StateObject(wrappedValue: CommentsViewModel(
            workoutID: workoutID,
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
            if showingInput || replyToCommentID != nil || editingComment != nil {
                CommentInputView(
                    workoutID: workoutID,
                    workoutOwnerID: workoutOwnerID,
                    parentCommentID: replyToCommentID,
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
                                            Text(user.username.prefix(1))
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
                    GenericCommentRowView(
                        commentWithUser: AnyActivityFeedCommentWithUser(commentWithUser),
                        currentUserID: currentUser?.id,
                        onReply: { commentID in
                            replyToCommentID = commentID
                            withAnimation(.easeInOut(duration: 0.3)) {
                                proxy.scrollTo("input", anchor: .bottom)
                            }
                        },
                        onEdit: { comment in
                            editingComment = ActivityFeedComment(
                                id: comment.id,
                                activityFeedID: workoutID, // Using workoutID as activityFeedID
                                sourceType: "workout",
                                sourceID: workoutID,
                                userID: comment.userID,
                                activityOwnerID: workoutOwnerID,
                                content: comment.content,
                                createdTimestamp: comment.createdTimestamp,
                                modifiedTimestamp: comment.modifiedTimestamp,
                                parentCommentID: comment.parentCommentID,
                                isEdited: comment.isEdited,
                                likeCount: comment.likeCount
                            )
                        },
                        onDelete: { commentID in
                            Task {
                                await viewModel.deleteComment(commentID: commentID)
                            }
                        },
                        onLike: { commentID in
                            Task {
                                await viewModel.toggleCommentLike(commentID: commentID)
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

    private var filteredComments: [ActivityFeedCommentWithUser] {
        if searchText.isEmpty {
            viewModel.comments
        } else {
            viewModel.comments.filter { commentWithUser in
                commentWithUser.comment.content.localizedCaseInsensitiveContains(searchText) ||
                    commentWithUser.user.username.localizedCaseInsensitiveContains(searchText) ||
                    commentWithUser.user.username.localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    // MARK: - Actions

    private func handleCommentSubmit(_ content: String) {
        Task {
            if let editingComment {
                await viewModel.updateComment(
                    commentID: editingComment.id,
                    newContent: content
                )
                self.editingComment = nil
            } else {
                await viewModel.postComment(
                    content: content,
                    parentCommentID: replyToCommentID
                )
                replyToCommentID = nil
                showingInput = false
            }
        }
    }

    private func handleInputCancel() {
        withAnimation(.easeInOut(duration: 0.2)) {
            showingInput = false
            replyToCommentID = nil
            editingComment = nil
        }
    }
}

// MARK: - Comments ViewModel

@MainActor
class CommentsViewModel: ObservableObject {
    @Published var comments: [ActivityFeedCommentWithUser] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var totalComments = 0
    @Published var hasMoreComments = true
    @Published var sortOrder: CommentSortOrder = .newest

    private let workoutID: String
    private let commentsService: ActivityFeedCommentsServicing
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

    init(workoutID: String, commentsService: ActivityFeedCommentsServicing) {
        self.workoutID = workoutID
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

    func postComment(content: String, parentCommentID: String?) async {
        do {
            _ = try await commentsService.postComment(
                activityFeedID: workoutID, // Using workoutID as activityFeedID
                sourceType: "workout",
                sourceID: workoutID,
                activityOwnerID: "", // Will be handled by service
                content: content,
                parentCommentID: parentCommentID
            )

            // Reload to get the updated list with proper threading
            await fetchComments(reset: true)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func updateComment(commentID: String, newContent: String) async {
        do {
            let updatedComment = try await commentsService.updateComment(
                commentID: commentID,
                newContent: newContent
            )

            // Update the comment in the local list
            if let index = comments.firstIndex(where: { $0.comment.id == commentID}) {
                comments[index].comment = updatedComment
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteComment(commentID: String) async {
        do {
            try await commentsService.deleteComment(commentID: commentID)
            comments.removeAll { $0.comment.id == commentID}
            totalComments -= 1
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func toggleCommentLike(commentID: String) async {
        do {
            // This would typically check if user has already liked
            _ = try await commentsService.likeComment(commentID: commentID)
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
            let fetchedComments = try await commentsService.fetchCommentsBySource(
                sourceType: "workout",
                sourceID: workoutID,
                limit: pageSize
            )

            if reset {
                comments = fetchedComments
            } else {
                comments.append(contentsOf: fetchedComments)
            }

            hasMoreComments = fetchedComments.count == pageSize

            // Get total count
            totalComments = try await commentsService.fetchCommentCountBySource(sourceType: "workout", sourceID: workoutID)

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
            workoutID: "sample-workout",
            workoutOwnerID: "owner123",
            currentUser: UserProfile(
                id: "current",
                userID: "current",
                username: "currentuser",
                bio: "Test user",
                workoutCount: 25,
                totalXP: 500,
                createdTimestamp: Date().addingTimeInterval(-86_400 * 90),
                modifiedTimestamp: Date(),
                isVerified: false,
                privacyLevel: .publicProfile,
                profileImageURL: nil
            ),
            commentsService: PreviewMockCommentsService()
        )
    }
}

// MARK: - Preview Mock

private class PreviewMockCommentsService: ActivityFeedCommentsServicing {
    func fetchComments(for activityFeedID: String, limit: Int) async throws -> [ActivityFeedCommentWithUser] {
        []
    }
    
    func fetchCommentsBySource(sourceType: String, sourceID: String, limit: Int) async throws -> [ActivityFeedCommentWithUser] {
        []
    }

    func postComment(
        activityFeedID: String,
        sourceType: String,
        sourceID: String,
        activityOwnerID: String,
        content: String,
        parentCommentID: String?
    ) async throws -> ActivityFeedComment {
        ActivityFeedComment(
            id: UUID().uuidString,
            activityFeedID: activityFeedID,
            sourceType: sourceType,
            sourceID: sourceID,
            userID: "current",
            activityOwnerID: activityOwnerID,
            content: content,
            createdTimestamp: Date(),
            modifiedTimestamp: Date(),
            parentCommentID: parentCommentID,
            isEdited: false,
            likeCount: 0
        )
    }

    func updateComment(commentID: String, newContent: String) async throws -> ActivityFeedComment {
        ActivityFeedComment(
            id: commentID,
            activityFeedID: "feed1",
            sourceType: "workout",
            sourceID: "workout1",
            userID: "current",
            activityOwnerID: "owner",
            content: newContent,
            createdTimestamp: Date(),
            modifiedTimestamp: Date(),
            parentCommentID: nil,
            isEdited: true,
            likeCount: 0
        )
    }

    func deleteComment(commentID: String) async throws {
        // Mock delete
    }

    func likeComment(commentID: String) async throws -> Int {
        1
    }

    func unlikeComment(commentID: String) async throws -> Int {
        0
    }

    func fetchCommentCount(for _: String) async throws -> Int {
        0
    }
    
    func fetchCommentCountBySource(sourceType: String, sourceID: String) async throws -> Int {
        0
    }
}
