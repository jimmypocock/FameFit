//
//  UserProfile+Navigation.swift
//  FameFit
//
//  Extensions to help with profile navigation and ID handling
//

import Foundation

extension UserProfile {
    /// The ID to use when navigating to ProfileView
    /// This should be the profile record ID (UUID)
    var navigationID: String {
        id
    }
    
    /// The ID to use for social operations (follow, unfollow, etc)
    /// This should be the CloudKit user ID
    var socialID: String {
        userID
    }
    
    /// Check if this profile belongs to the current user
    func isCurrentUser(cloudKitUserID: String?) -> Bool {
        guard let cloudKitUserID else { return false }
        return userID == cloudKitUserID
    }
}
