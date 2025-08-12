//
//  UnlockNotificationService.swift
//  FameFit
//
//  Manages notifications for XP unlocks and level progression
//

import Foundation
import UserNotifications


final class UnlockNotificationService: UnlockNotificationProtocol {
    private let notificationStore: any NotificationStoringProtocol
    private let unlockStorage: UnlockStorageProtocol
    private let userDefaults: UserDefaults
    private var preferences: NotificationPreferences = .load()

    private let unlockKeyPrefix = "unlock_notified_"
    private let levelKeyPrefix = "level_notified_"

    init(
        notificationStore: any NotificationStoringProtocol,
        unlockStorage: UnlockStorageProtocol,
        userDefaults: UserDefaults = .standard
    ) {
        self.notificationStore = notificationStore
        self.unlockStorage = unlockStorage
        self.userDefaults = userDefaults
    }

    func updatePreferences(_ newPreferences: NotificationPreferences) {
        preferences = newPreferences
    }

    func checkForNewUnlocks(previousXP: Int, currentXP: Int) async {
        guard currentXP > previousXP else { return }

        // Get all unlocks between previous and current XP
        let newUnlocks = XPCalculator.unlockables.filter { unlock in
            unlock.xpRequired > previousXP && unlock.xpRequired <= currentXP
        }

        for unlock in newUnlocks {
            // Use unlock name in key to handle multiple unlocks at same XP
            let notificationKey = "\(unlockKeyPrefix)\(unlock.xpRequired)_\(unlock.name)"

            // Check if we've already notified about this unlock
            if !userDefaults.bool(forKey: notificationKey) {
                await notifyUnlock(unlock)
                userDefaults.set(true, forKey: notificationKey)

                // Also record the unlock in storage
                unlockStorage.recordUnlock(unlock)
            }
        }

        // Check for level changes
        let previousLevel = XPCalculator.getLevel(for: previousXP)
        let currentLevel = XPCalculator.getLevel(for: currentXP)

        // Notify for each level passed
        if currentLevel.level > previousLevel.level {
            for level in (previousLevel.level + 1) ... currentLevel.level {
                let levelInfo = XPCalculator.getLevel(for: getLevelThreshold(for: level))
                await notifyLevelUp(newLevel: levelInfo.level, title: levelInfo.title)
            }
        }
    }

    func notifyLevelUp(newLevel: Int, title: String) async {
        let notificationKey = "\(levelKeyPrefix)\(newLevel)"

        // Check if we've already notified about this level
        guard !userDefaults.bool(forKey: notificationKey) else { return }

        let notification = FameFitNotification(
            type: .levelUp,
            title: "🎉 Level Up!",
            body: "Congratulations! You've reached Level \(newLevel): \(title)",
            metadata: .achievement(AchievementNotificationMetadata(
                achievementID: "level_\(newLevel)",
                achievementName: title,
                achievementDescription: "Reached Level \(newLevel)",
                xpRequired: getLevelThreshold(for: newLevel),
                category: "level",
                iconEmoji: "🎉"
            ))
        )

        Task { @MainActor in
            notificationStore.addFameFitNotification(notification)
        }
        userDefaults.set(true, forKey: notificationKey)

        // Also send a local push notification if permissions granted
        await sendLocalFameFitNotification(
            title: "Level \(newLevel) Achieved! 🎉",
            body: "You're now a \(title)! Keep up the amazing work!",
            identifier: "level_\(newLevel)"
        )
    }

    private func notifyUnlock(_ unlock: XPUnlock) async {
        let notification = FameFitNotification(
            type: .unlockAchieved,
            title: "New Unlock! \(iconForUnlock(unlock))",
            body: "\(unlock.name): \(unlock.description)"
        )

        Task { @MainActor in
            notificationStore.addFameFitNotification(notification)
        }

        // Also send a local push notification if permissions granted
        await sendLocalFameFitNotification(
            title: "Unlock Achieved! \(iconForUnlock(unlock))",
            body: "\(unlock.name) is now available!",
            identifier: "unlock_\(unlock.xpRequired)"
        )
    }

    func requestNotificationPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()

        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            return granted
        } catch {
            print("Failed to request notification permission: \(error)")
            return false
        }
    }

    private func sendLocalFameFitNotification(title: String, body: String, identifier: String) async {
        let center = UNUserNotificationCenter.current()

        // Check if we have permission and notifications are enabled
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized,
              preferences.pushNotificationsEnabled else { return }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = preferences.soundEnabled ? .default : nil
        content.badge = preferences.badgeEnabled ? NSNumber(value: notificationStore.unreadCount) : nil

        // Deliver immediately
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: nil
        )

        do {
            try await center.add(request)
        } catch {
            print("Failed to send local notification: \(error)")
        }
    }


    private func iconForUnlock(_ unlock: XPUnlock) -> String {
        switch unlock.category {
        case .badge:
            "🏅"
        case .feature:
            "✨"
        case .customization:
            "🎨"
        case .achievement:
            "🏆"
        }
    }

    private func getLevelThreshold(for level: Int) -> Int {
        // Level thresholds from XPCalculator
        let thresholds = [0, 100, 500, 1_000, 2_500, 5_000, 10_000, 25_000, 50_000, 100_000, 250_000, 500_000, 1_000_000]
        guard level > 0, level <= thresholds.count else { return 0 }
        return thresholds[level - 1]
    }
}
