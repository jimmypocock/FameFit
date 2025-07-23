//
//  UnlockNotificationService.swift
//  FameFit
//
//  Manages notifications for XP unlocks and level progression
//

import Foundation
import UserNotifications

protocol UnlockNotificationServiceProtocol: AnyObject {
    func checkForNewUnlocks(previousXP: Int, currentXP: Int) async
    func notifyLevelUp(newLevel: Int, title: String) async
    func requestNotificationPermission() async -> Bool
}

final class UnlockNotificationService: UnlockNotificationServiceProtocol {
    private let notificationStore: any NotificationStoring
    private let unlockStorage: UnlockStorageServiceProtocol
    private let userDefaults: UserDefaults
    private var preferences: NotificationPreferences = NotificationPreferences.load()
    
    private let unlockKeyPrefix = "unlock_notified_"
    private let levelKeyPrefix = "level_notified_"
    
    init(
        notificationStore: any NotificationStoring,
        unlockStorage: UnlockStorageServiceProtocol,
        userDefaults: UserDefaults = .standard
    ) {
        self.notificationStore = notificationStore
        self.unlockStorage = unlockStorage
        self.userDefaults = userDefaults
    }
    
    func updatePreferences(_ newPreferences: NotificationPreferences) {
        self.preferences = newPreferences
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
            for level in (previousLevel.level + 1)...currentLevel.level {
                let levelInfo = XPCalculator.getLevel(for: getLevelThreshold(for: level))
                await notifyLevelUp(newLevel: levelInfo.level, title: levelInfo.title)
            }
        }
    }
    
    func notifyLevelUp(newLevel: Int, title: String) async {
        let notificationKey = "\(levelKeyPrefix)\(newLevel)"
        
        // Check if we've already notified about this level
        guard !userDefaults.bool(forKey: notificationKey) else { return }
        
        let character = getCharacterForLevel(newLevel)
        let notification = NotificationItem(
            type: .levelUp,
            title: "\(character.emoji) Level Up!",
            body: "Congratulations! You've reached Level \(newLevel): \(title)",
            metadata: .achievement(AchievementNotificationMetadata(
                achievementId: "level_\(newLevel)",
                achievementName: title,
                achievementDescription: "Reached Level \(newLevel)",
                xpRequired: getLevelThreshold(for: newLevel),
                category: "level",
                iconEmoji: character.emoji
            ))
        )
        
        notificationStore.addNotification(notification)
        userDefaults.set(true, forKey: notificationKey)
        
        // Also send a local push notification if permissions granted
        await sendLocalNotification(
            title: "Level \(newLevel) Achieved! 🎉",
            body: "You're now a \(title)! Keep up the amazing work!",
            identifier: "level_\(newLevel)"
        )
    }
    
    private func notifyUnlock(_ unlock: XPUnlock) async {
        let notification = NotificationItem(
            type: .unlockAchieved,
            title: "New Unlock! \(iconForUnlock(unlock))",
            body: "\(unlock.name): \(unlock.description)"
        )
        
        notificationStore.addNotification(notification)
        
        // Also send a local push notification if permissions granted
        await sendLocalNotification(
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
    
    private func sendLocalNotification(title: String, body: String, identifier: String) async {
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
    
    private func getCharacterForLevel(_ level: Int) -> FameFitCharacter {
        switch level {
        case 1...4:
            return .zen
        case 5...9:
            return .sierra
        case 10...14:
            return .chad
        default:
            return .chad
        }
    }
    
    private func iconForUnlock(_ unlock: XPUnlock) -> String {
        switch unlock.category {
        case .badge:
            return "🏅"
        case .feature:
            return "✨"
        case .customization:
            return "🎨"
        case .achievement:
            return "🏆"
        }
    }
    
    private func getLevelThreshold(for level: Int) -> Int {
        // Level thresholds from XPCalculator
        let thresholds = [0, 100, 500, 1_000, 2_500, 5_000, 10_000, 25_000, 50_000, 100_000, 250_000, 500_000, 1_000_000]
        guard level > 0 && level <= thresholds.count else { return 0 }
        return thresholds[level - 1]
    }
}

// MARK: - Mock Implementation

final class MockUnlockNotificationService: UnlockNotificationServiceProtocol {
    var checkForNewUnlocksCalled = false
    var lastPreviousXP: Int?
    var lastCurrentXP: Int?
    
    var notifyLevelUpCalled = false
    var lastNotifiedLevel: Int?
    var lastNotifiedTitle: String?
    
    var requestPermissionResult = true
    
    func checkForNewUnlocks(previousXP: Int, currentXP: Int) async {
        checkForNewUnlocksCalled = true
        lastPreviousXP = previousXP
        lastCurrentXP = currentXP
    }
    
    func notifyLevelUp(newLevel: Int, title: String) async {
        notifyLevelUpCalled = true
        lastNotifiedLevel = newLevel
        lastNotifiedTitle = title
    }
    
    func requestNotificationPermission() async -> Bool {
        return requestPermissionResult
    }
}