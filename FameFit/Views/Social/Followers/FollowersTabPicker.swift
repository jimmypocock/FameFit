//
//  FollowersTabPicker.swift
//  FameFit
//
//  Tab picker component for followers and following lists
//

import SwiftUI

struct FollowersTabPicker: View {
    @Binding var selectedTab: FollowListTab
    let followerCount: Int
    let followingCount: Int
    @Binding var searchText: String
    let onTabChanged: (FollowListTab) -> Void

    var body: some View {
        Picker("List Type", selection: $selectedTab) {
            ForEach(FollowListTab.allCases, id: \.self) { tab in
                if tab == .followers {
                    Text("Followers (\(followerCount))").tag(tab)
                } else {
                    Text("Following (\(followingCount))").tag(tab)
                }
            }
        }
        .pickerStyle(.segmented)
        .padding()
        .onChange(of: selectedTab) { _, newTab in
            searchText = ""
            onTabChanged(newTab)
        }
    }
}
