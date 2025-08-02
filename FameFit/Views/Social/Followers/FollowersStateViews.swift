//
//  FollowersStateViews.swift
//  FameFit
//
//  Loading, error, and empty state views for followers list
//

import SwiftUI

// MARK: - Loading View

struct FollowersLoadingView: View {
    let selectedTab: FollowListTab

    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
            Text("Loading \(selectedTab.rawValue.lowercased())...")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Error View

struct FollowersErrorView: View {
    let error: String
    let selectedTab: FollowListTab
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundColor(.red)

            Text("Error Loading \(selectedTab.rawValue)")
                .font(.headline)

            Text(error)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button("Try Again") {
                onRetry()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

// MARK: - Empty View

struct FollowersEmptyView: View {
    let selectedTab: FollowListTab
    let searchText: String
    let isOwnProfile: Bool

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: selectedTab == .followers ? "person.2.slash" : "person.crop.circle.badge.xmark")
                .font(.system(size: 60))
                .foregroundColor(.secondary)

            Text(emptyTitle)
                .font(.headline)

            Text(emptyMessage)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var emptyTitle: String {
        if !searchText.isEmpty {
            return "No Results"
        }

        if selectedTab == .followers {
            return isOwnProfile ? "No Followers Yet" : "No Followers"
        } else {
            return isOwnProfile ? "Not Following Anyone" : "Not Following Anyone"
        }
    }

    private var emptyMessage: String {
        if !searchText.isEmpty {
            return "Try searching with a different term"
        }

        if selectedTab == .followers {
            return isOwnProfile ? "When people follow you, they'll appear here" : "This user has no followers yet"
        } else {
            return isOwnProfile ? "Discover users to follow" : "This user isn't following anyone yet"
        }
    }
}