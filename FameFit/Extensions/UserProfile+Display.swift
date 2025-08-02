//
//  UserProfile+Display.swift
//  FameFit
//
//  UI display helpers for UserProfile
//

import Foundation

extension UserProfile {
    /// Formatted username for display (includes @ symbol)
    var displayUsername: String {
        "@\(username)"
    }
    
    /// Short display name for avatars (first 2 characters of username)
    var avatarText: String {
        String(username.prefix(2).uppercased())
    }
}

// MARK: - String Extension for Username Display

extension String {
    /// Formats a username string for display (adds @ if not present)
    var displayUsername: String {
        if self.hasPrefix("@") {
            return self
        } else {
            return "@\(self)"
        }
    }
}