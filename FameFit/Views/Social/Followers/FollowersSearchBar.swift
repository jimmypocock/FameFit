//
//  FollowersSearchBar.swift
//  FameFit
//
//  Search bar component for filtering followers and following lists
//

import SwiftUI

struct FollowersSearchBar: View {
    @Binding var searchText: String
    let selectedTab: FollowListTab

    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)

            TextField("Search \(selectedTab.rawValue.lowercased())...", text: $searchText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .autocapitalization(.none)
                .disableAutocorrection(true)

            if !searchText.isEmpty {
                Button(action: {
                    searchText = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}
