//
//  NotificationPreferences.swift
//  FameFit
//
//  User preferences for notification delivery
//

import Foundation

struct NotificationPreferences: Codable, Equatable {
    // MARK: - Master Switches
    
    var pushNotificationsEnabled: Bool = true
    var inAppNotificationsEnabled: Bool = true
    var soundEnabled: Bool = true
    var badgeEnabled: Bool = true
    
    // MARK: - Per-Type Settings
    
    private var typeSettings: [NotificationType: NotificationSetting] = [:]
    
    // Legacy support for simple enabled/disabled states
    var enabledTypes: [NotificationType: Bool] = [:]
    
    // MARK: - Display Preferences
    
    var groupSimilarNotifications: Bool = true
    var showPreviewsWhenLocked: Bool = true
    
    // MARK: - Quiet Hours
    
    var quietHoursEnabled: Bool = false
    var quietHoursStart: Date?
    var quietHoursEnd: Date?
    var quietHoursIgnoreImmediate: Bool = true // Allow immediate priority during quiet hours
    
    // MARK: - Rate Limiting
    
    var maxNotificationsPerHour: Int = 10
    var maxNotificationsPerDay: Int = 50
    var batchingWindowMinutes: Int = 15
    
    // MARK: - History Management
    
    var historyRetentionDays: Int = 30
    
    // MARK: - Initialization
    
    init() {
        // Set default preferences for each notification type
        for type in NotificationType.allCases {
            typeSettings[type] = type.defaultSetting
        }
    }
    
    // MARK: - Accessors
    
    func setting(for type: NotificationType) -> NotificationSetting {
        return typeSettings[type] ?? type.defaultSetting
    }
    
    mutating func setSetting(_ setting: NotificationSetting, for type: NotificationType) {
        typeSettings[type] = setting
    }
    
    func isEnabled(for type: NotificationType) -> Bool {
        guard pushNotificationsEnabled else { return false }
        return setting(for: type).isEnabled
    }
    
    func shouldPlaySound(for type: NotificationType) -> Bool {
        return soundEnabled && type.soundEnabled && isEnabled(for: type)
    }
    
    func shouldBatch(for type: NotificationType) -> Bool {
        let setting = setting(for: type)
        return setting == .batched || setting == .daily || setting == .weekly
    }
    
    func isInQuietHours(at date: Date = Date()) -> Bool {
        guard quietHoursEnabled,
              let startTime = quietHoursStart,
              let endTime = quietHoursEnd else { return false }
        
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: date)
        let startComponents = calendar.dateComponents([.hour, .minute], from: startTime)
        let endComponents = calendar.dateComponents([.hour, .minute], from: endTime)
        
        guard let currentHour = components.hour,
              let currentMinute = components.minute,
              let startHour = startComponents.hour,
              let endHour = endComponents.hour else {
            return false
        }
        
        let startMinute = startComponents.minute ?? 0
        let endMinute = endComponents.minute ?? 0
        
        let currentMinutes = currentHour * 60 + currentMinute
        let startMinutes = startHour * 60 + startMinute
        let endMinutes = endHour * 60 + endMinute
        
        // Handle overnight quiet hours (e.g., 22:00 to 08:00)
        if startMinutes > endMinutes {
            return currentMinutes >= startMinutes || currentMinutes < endMinutes
        } else {
            return currentMinutes >= startMinutes && currentMinutes < endMinutes
        }
    }
    
    func isNotificationTypeEnabled(_ type: NotificationType) -> Bool {
        guard pushNotificationsEnabled else { return false }
        
        // Check new enabled types first (for backward compatibility)
        if let enabled = enabledTypes[type] {
            return enabled
        }
        
        // Fall back to type settings
        return isEnabled(for: type)
    }
    
    // MARK: - Persistence
    
    static let storageKey = "com.jimmypocock.FameFit.notificationPreferences"
    
    static func load() -> NotificationPreferences {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let preferences = try? JSONDecoder().decode(NotificationPreferences.self, from: data) else {
            return NotificationPreferences()
        }
        return preferences
    }
    
    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }
    
    // MARK: - Default Presets
    
    static var allEnabled: NotificationPreferences {
        var prefs = NotificationPreferences()
        for type in NotificationType.allCases {
            prefs.setSetting(.enabled, for: type)
        }
        return prefs
    }
    
    static var minimal: NotificationPreferences {
        var prefs = NotificationPreferences()
        prefs.soundEnabled = false
        
        // Only enable critical notifications
        for type in NotificationType.allCases {
            switch type {
            case .workoutCompleted, .levelUp, .followRequest, .securityAlert:
                prefs.setSetting(.enabled, for: type)
            case .workoutKudos, .newFollower:
                prefs.setSetting(.daily, for: type)
            default:
                prefs.setSetting(.disabled, for: type)
            }
        }
        return prefs
    }
    
    static var balanced: NotificationPreferences {
        var prefs = NotificationPreferences()
        
        // Batch social interactions
        prefs.setSetting(.batched, for: .workoutKudos)
        prefs.setSetting(.batched, for: .newFollower)
        prefs.setSetting(.weekly, for: .leaderboardChange)
        
        // Enable quiet hours by default
        prefs.quietHoursEnabled = true
        let calendar = Calendar.current
        prefs.quietHoursStart = calendar.date(bySettingHour: 22, minute: 0, second: 0, of: Date())
        prefs.quietHoursEnd = calendar.date(bySettingHour: 8, minute: 0, second: 0, of: Date())
        
        return prefs
    }
}

// MARK: - User Defaults Extension

extension NotificationPreferences {
    /// Migrate from old notification settings if they exist
    static func migrateFromLegacySettings() -> NotificationPreferences {
        var prefs = NotificationPreferences()
        
        // Check for any legacy settings
        if UserDefaults.standard.object(forKey: "pushNotificationsEnabled") != nil {
            prefs.pushNotificationsEnabled = UserDefaults.standard.bool(forKey: "pushNotificationsEnabled")
            // Remove legacy key
            UserDefaults.standard.removeObject(forKey: "pushNotificationsEnabled")
        }
        
        prefs.save()
        return prefs
    }
}