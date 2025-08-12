//
//  SheetType.swift
//  FameFit
//
//  Centralized sheet management for MainView
//

import SwiftUI

enum SheetType: Identifiable {
    case profile
    case notifications
    case workoutHistory
    case editProfile
    case workoutSharing(Workout)
    #if DEBUG
    case notificationDebug
    case developerMenu
    #endif
    
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
        #if DEBUG
        case .notificationDebug:
            return "notificationDebug"
        case .developerMenu:
            return "developerMenu"
        #endif
        }
    }
}
