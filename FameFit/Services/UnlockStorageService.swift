//
//  UnlockStorageService.swift
//  FameFit
//
//  Manages persistent storage of user unlocks and achievements
//

import Foundation

protocol UnlockStorageServiceProtocol: AnyObject {
    func getUnlockedItems() -> [XPUnlock]
    func hasUnlocked(_ unlock: XPUnlock) -> Bool
    func recordUnlock(_ unlock: XPUnlock)
    func getUnlockTimestamp(for unlock: XPUnlock) -> Date?
    func resetAllUnlocks()
}

final class UnlockStorageService: UnlockStorageServiceProtocol {
    private let userDefaults: UserDefaults
    private let unlocksKey = "FameFitUnlocks"
    private let timestampsKey = "FameFitUnlockTimestamps"

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func getUnlockedItems() -> [XPUnlock] {
        guard let unlockedXPValues = userDefaults.array(forKey: unlocksKey) as? [Int] else {
            return []
        }

        return XPCalculator.unlockables.filter { unlock in
            unlockedXPValues.contains(unlock.xpRequired)
        }
    }

    func hasUnlocked(_ unlock: XPUnlock) -> Bool {
        guard let unlockedXPValues = userDefaults.array(forKey: unlocksKey) as? [Int] else {
            return false
        }

        return unlockedXPValues.contains(unlock.xpRequired)
    }

    func recordUnlock(_ unlock: XPUnlock) {
        var unlockedXPValues = userDefaults.array(forKey: unlocksKey) as? [Int] ?? []

        // Don't add duplicates
        if !unlockedXPValues.contains(unlock.xpRequired) {
            unlockedXPValues.append(unlock.xpRequired)
            userDefaults.set(unlockedXPValues, forKey: unlocksKey)

            // Also record timestamp
            var timestamps = userDefaults.dictionary(forKey: timestampsKey) as? [String: Date] ?? [:]
            timestamps[String(unlock.xpRequired)] = Date()
            userDefaults.set(timestamps, forKey: timestampsKey)

            // Synchronize for test suites
            userDefaults.synchronize()
        }
    }

    func getUnlockTimestamp(for unlock: XPUnlock) -> Date? {
        guard let timestamps = userDefaults.dictionary(forKey: timestampsKey) as? [String: Date] else {
            return nil
        }

        return timestamps[String(unlock.xpRequired)]
    }

    func resetAllUnlocks() {
        userDefaults.removeObject(forKey: unlocksKey)
        userDefaults.removeObject(forKey: timestampsKey)
        userDefaults.synchronize()
    }
}

// MARK: - Convenience Methods

extension UnlockStorageService {
    func getUnlockedBadges() -> [XPUnlock] {
        getUnlockedItems().filter { $0.category == .badge }
    }

    func getUnlockedFeatures() -> [XPUnlock] {
        getUnlockedItems().filter { $0.category == .feature }
    }

    func getUnlockedCustomizations() -> [XPUnlock] {
        getUnlockedItems().filter { $0.category == .customization }
    }

    func getUnlockedAchievements() -> [XPUnlock] {
        getUnlockedItems().filter { $0.category == .achievement }
    }
}

// MARK: - Mock Implementation

final class MockUnlockStorageService: UnlockStorageServiceProtocol {
    private var unlockedItems: Set<Int> = []
    private var timestamps: [Int: Date] = [:]

    func getUnlockedItems() -> [XPUnlock] {
        XPCalculator.unlockables.filter { unlock in
            unlockedItems.contains(unlock.xpRequired)
        }
    }

    func hasUnlocked(_ unlock: XPUnlock) -> Bool {
        unlockedItems.contains(unlock.xpRequired)
    }

    func recordUnlock(_ unlock: XPUnlock) {
        unlockedItems.insert(unlock.xpRequired)
        timestamps[unlock.xpRequired] = Date()
    }

    func getUnlockTimestamp(for unlock: XPUnlock) -> Date? {
        timestamps[unlock.xpRequired]
    }

    func resetAllUnlocks() {
        unlockedItems.removeAll()
        timestamps.removeAll()
    }
}
