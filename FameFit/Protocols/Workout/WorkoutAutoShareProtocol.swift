//
//  WorkoutAutoShareProtocol.swift
//  FameFit
//
//  Protocol for workout auto-share service operations
//

import Foundation

protocol WorkoutAutoShareProtocol: AnyObject {
    func setupAutoSharing()
    func stopAutoSharing()
}