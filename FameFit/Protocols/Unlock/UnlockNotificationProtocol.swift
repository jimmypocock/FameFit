//
//  UnlockNotificationProtocol.swift
//  FameFit
//
//  Protocol for unlock notification service operations
//

import Foundation

protocol UnlockNotificationProtocol: AnyObject {
    func checkForNewUnlocks(previousXP: Int, currentXP: Int) async
    func notifyLevelUp(newLevel: Int, title: String) async
    func requestNotificationPermission() async -> Bool
}