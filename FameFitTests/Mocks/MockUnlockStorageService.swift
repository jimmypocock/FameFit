//
//  MockUnlockStorageService.swift
//  FameFitTests
//
//  Mock implementation of UnlockStorageService for testing
//

@testable import FameFit
import Foundation

final class MockUnlockStorageService: UnlockStorageProtocol {
    var mockUnlocks: [XPUnlock] = []
    var mockTimestamps: [String: Date] = [:] // key is unlock.name

    func getUnlockedItems() -> [XPUnlock] {
        mockUnlocks
    }

    func hasUnlocked(_ unlock: XPUnlock) -> Bool {
        mockUnlocks.contains { $0.xpRequired == unlock.xpRequired && $0.name == unlock.name }
    }

    func recordUnlock(_ unlock: XPUnlock) {
        if !hasUnlocked(unlock) {
            mockUnlocks.append(unlock)
            mockTimestamps[unlock.name] = Date()
        }
    }

    func getUnlockTimestamp(for unlock: XPUnlock) -> Date? {
        mockTimestamps[unlock.name]
    }

    func resetAllUnlocks() {
        mockUnlocks.removeAll()
        mockTimestamps.removeAll()
    }

    // Helper methods for testing
    func reset() {
        resetAllUnlocks()
    }
}
