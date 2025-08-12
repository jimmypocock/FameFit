//
//  UnlockStorageProtocol.swift
//  FameFit
//
//  Protocol for unlock storage service operations
//

import Foundation

protocol UnlockStorageProtocol: AnyObject {
    func getUnlockedItems() -> [XPUnlock]
    func hasUnlocked(_ unlock: XPUnlock) -> Bool
    func recordUnlock(_ unlock: XPUnlock)
    func getUnlockTimestamp(for unlock: XPUnlock) -> Date?
    func resetAllUnlocks()
}