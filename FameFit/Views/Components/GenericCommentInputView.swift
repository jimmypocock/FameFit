//
//  GenericCommentInputView.swift
//  FameFit
//
//  Generic comment input that works with any comment type
//

import SwiftUI

struct GenericCommentInputView: View {
    let resourceId: String
    let resourceOwnerId: String
    let resourceType: String
    let sourceRecordId: String?
    let parentCommentId: String?
    let editingComment: AnyComment?
    let currentUser: UserProfile?
    let onSubmit: (String) -> Void
    let onCancel: () -> Void
    
    @State private var commentText = ""
    @FocusState private var isTextFieldFocused: Bool
    @State private var characterCount = 0
    
    private let maxCharacters = 500
    
    var body: some View {
        VStack(spacing: 0) {
            // Context header
            if parentCommentId != nil || editingComment != nil {
                HStack {
                    Text(editingComment != nil ? "Editing comment" : "Replying to comment")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Button("Cancel") {
                        onCancel()
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color(.secondarySystemBackground))
            }
            
            // Input area
            HStack(alignment: .bottom, spacing: 12) {
                // User avatar
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
                    .padding(.bottom, 8)
                }
                
                // Text input
                VStack(alignment: .trailing, spacing: 4) {
                    TextField("Add a comment...", text: $commentText, axis: .vertical)
                        .textFieldStyle(.plain)
                        .lineLimit(1...6)
                        .focused($isTextFieldFocused)
                        .onChange(of: commentText) { _, newValue in
                            characterCount = newValue.count
                            if newValue.count > maxCharacters {
                                commentText = String(newValue.prefix(maxCharacters))
                                characterCount = maxCharacters
                            }
                        }
                    
                    // Character count
                    Text("\(characterCount)/\(maxCharacters)")
                        .font(.caption2)
                        .foregroundColor(characterCount > Int(Double(maxCharacters) * 0.8) ? .orange : .secondary)
                }
                
                // Submit button
                Button(action: submitComment) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(canSubmit ? .blue : .gray.opacity(0.5))
                }
                .disabled(!canSubmit)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .onAppear {
            if let editingComment {
                commentText = editingComment.content
                characterCount = editingComment.content.count
            }
            
            // Auto-focus the text field
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                isTextFieldFocused = true
            }
        }
    }
    
    private var canSubmit: Bool {
        let trimmed = commentText.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && trimmed.count <= maxCharacters
    }
    
    private func submitComment() {
        let trimmed = commentText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard canSubmit else { return }
        
        onSubmit(trimmed)
        commentText = ""
        characterCount = 0
        isTextFieldFocused = false
    }
}