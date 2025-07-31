//
//  SheetType.swift
//  FameFit
//
//  Centralized sheet management for TabMainView
//

import SwiftUI

enum SheetType: Identifiable {
    case profile
    case notifications
    case workoutHistory
    case editProfile
    case workoutSharing(Workout)
    case notificationDebug
    case developerMenu
    
    var id: String {
        switch self {
        case .profile:
            return "profile"
        case .notifications:
            return "notifications"
        case .workoutHistory:
            return "workoutHistory"
        case .editProfile:
            return "editProfile"
        case .workoutSharing:
            return "workoutSharing"
        case .notificationDebug:
            return "notificationDebug"
        case .developerMenu:
            return "developerMenu"
        }
    }
}