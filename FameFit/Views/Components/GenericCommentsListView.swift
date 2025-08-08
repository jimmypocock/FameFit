//
//  GenericCommentsListView.swift
//  FameFit
//
//  Generic comments list view that works with any CommentServicing implementation
//

import SwiftUI

struct GenericCommentsListView: View {
    let resourceID: String
    let resourceOwnerID: String
    let resourceType: String
    let sourceRecordID: String?
    let currentUser: UserProfile?
    let commentService: AnyCommentService
    
    @StateObject private var viewModel: GenericCommentsViewModel
    @State private var showingInput = false
    @State private var replyToCommentID: String?
    @State private var editingComment: AnyComment?
    @State private var searchText = ""
    
    init(
        resourceID: String,
        resourceOwnerID: String,
        resourceType: String,
        sourceRecordID: String? = nil,
        currentUser: UserProfile?,
        commentService: AnyCommentService
    ) {
        self.resourceID = resourceID
        self.resourceOwnerID = resourceOwnerID
        self.resourceType = resourceType
        self.sourceRecordID = sourceRecordID
        self.currentUser = currentUser
        self.commentService = commentService
        _viewModel = StateObject(wrappedValue: GenericCommentsViewModel(
            resourceID: resourceID,
            commentService: commentService
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
                GenericCommentInputView(
                    resourceID: resourceID,
                    resourceOwnerID: resourceOwnerID,
                    resourceType: resourceType,
                    sourceRecordID: sourceRecordID,
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
                                            Text(user.initials)
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
                ForEach(filteredComments) { commentWithUser in
                    GenericCommentRowView(
                        commentWithUser: commentWithUser,
                        currentUserID: currentUser?.id,
                        onReply: { commentID in
                            replyToCommentID = commentID
                            withAnimation(.easeInOut(duration: 0.3)) {
                                proxy.scrollTo("input", anchor: .bottom)
                            }
                        },
                        onEdit: { comment in
                            editingComment = comment
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
                
                Text("Be the first to share your thoughts!")
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
    
    private var filteredComments: [AnyActivityFeedCommentWithUser] {
        if searchText.isEmpty {
            viewModel.comments
        } else {
            viewModel.comments.filter { commentWithUser in
                commentWithUser.comment.content.localizedCaseInsensitiveContains(searchText) ||
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
                let metadata = CommentMetadata(
                    resourceType: resourceType,
                    sourceRecordID: sourceRecordID
                )
                await viewModel.postComment(
                    content: content,
                    parentCommentID: replyToCommentID,
                    metadata: metadata
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

// MARK: - Generic Comments ViewModel

@MainActor
class GenericCommentsViewModel: ObservableObject {
    @Published var comments: [AnyActivityFeedCommentWithUser] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var totalComments = 0
    @Published var hasMoreComments = true
    @Published var sortOrder: CommentSortOrder = .newest
    
    private let resourceID: String
    private let commentService: AnyCommentService
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
    
    init(resourceID: String, commentService: AnyCommentService) {
        self.resourceID = resourceID
        self.commentService = commentService
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
    
    func postComment(content: String, parentCommentID: String?, metadata: CommentMetadata) async {
        do {
            _ = try await commentService.postComment(
                resourceID: resourceID,
                resourceOwnerID: "", // Will be handled by service
                content: content,
                parentCommentID: parentCommentID,
                metadata: metadata
            )
            
            // Reload to get the updated list with proper threading
            await fetchComments(reset: true)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func updateComment(commentID: String, newContent: String) async {
        do {
            let updatedComment = try await commentService.updateComment(
                commentID: commentID,
                newContent: newContent
            )
            
            // Update the comment in the local list
            if let index = comments.firstIndex(where: { $0.comment.id == commentID}) {
                // Simply update the content and metadata of the existing comment
                let existingUser = comments[index].user
                comments[index] = AnyActivityFeedCommentWithUser(
                    ActivityFeedCommentWithUser(comment: ActivityFeedComment(
                        id: updatedComment.id,
                        activityFeedID: "",
                        sourceType: "",
                        sourceID: "",
                        userID: updatedComment.userID,
                        activityOwnerID: "",
                        content: updatedComment.content,
                        createdTimestamp: updatedComment.createdTimestamp,
                        modifiedTimestamp: updatedComment.modifiedTimestamp,
                        parentCommentID: updatedComment.parentCommentID,
                        isEdited: updatedComment.isEdited,
                        likeCount: updatedComment.likeCount
                    ), user: existingUser)
                )
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func deleteComment(commentID: String) async {
        do {
            try await commentService.deleteComment(commentID: commentID)
            comments.removeAll { $0.comment.id == commentID}
            totalComments -= 1
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func toggleCommentLike(commentID: String) async {
        do {
            // This would typically check if user has already liked
            _ = try await commentService.likeComment(commentID: commentID)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func setSortOrder(_ newOrder: CommentSortOrder) {
        sortOrder = newOrder
        sortComments()
    }
    
    func filterComments(searchText: String) {
        // Filtering is handled in the view
    }
    
    // MARK: - Private Methods
    
    private func fetchComments(reset: Bool) async {
        if reset {
            isLoading = true
        }
        
        do {
            let fetchedComments = try await commentService.fetchComments(
                for: resourceID,
                limit: pageSize
            )
            
            if reset {
                comments = fetchedComments
            } else {
                comments.append(contentsOf: fetchedComments)
            }
            
            hasMoreComments = fetchedComments.count == pageSize
            
            // Get total count
            totalComments = try await commentService.fetchCommentCount(for: resourceID)
            
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
