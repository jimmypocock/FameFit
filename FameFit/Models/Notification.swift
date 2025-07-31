import Foundation

struct FameFitNotification: Identifiable, Codable {
    let id: String
    let type: NotificationType
    let title: String
    let body: String
    let timestamp: Date
    var isRead: Bool

    // Optional metadata based on notification type
    let metadata: NotificationMetadataContainer?

    // Actions available for this notification
    let actions: [NotificationAction]

    // Grouping support
    let groupId: String?

    // Legacy support - will be removed in future
    let character: FameFitCharacter?
    let workoutDuration: Int? // minutes
    let calories: Int?
    let followersEarned: Int?

    init(
        type: NotificationType,
        title: String,
        body: String,
        metadata: NotificationMetadataContainer? = nil,
        actions: [NotificationAction] = [],
        groupId: String? = nil
    ) {
        id = UUID().uuidString
        self.type = type
        self.title = title
        self.body = body
        timestamp = Date()
        isRead = false
        self.metadata = metadata
        self.actions = actions
        self.groupId = groupId

        // Legacy fields - set to nil for new notifications
        character = nil
        workoutDuration = nil
        calories = nil
        followersEarned = nil
    }

    // Legacy initializer for backward compatibility
    init(
        title: String,
        body: String,
        character: FameFitCharacter,
        workoutDuration: Int,
        calories: Int,
        followersEarned: Int = 5
    ) {
        id = UUID().uuidString
        type = .workoutCompleted // Default to workout completed for legacy
        self.title = title
        self.body = body
        self.character = character
        timestamp = Date()
        self.workoutDuration = workoutDuration
        self.calories = calories
        self.followersEarned = followersEarned
        isRead = false
        metadata = .workout(WorkoutNotificationMetadata(
            workoutId: nil,
            workoutType: nil,
            duration: workoutDuration,
            calories: calories,
            xpEarned: followersEarned,
            distance: nil,
            averageHeartRate: nil
        ))
        actions = []
        groupId = nil
    }

    // Explicit Codable implementation to handle the custom init
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        body = try container.decode(String.self, forKey: .body)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        isRead = try container.decode(Bool.self, forKey: .isRead)

        // Try to decode new fields first
        if let type = try? container.decode(NotificationType.self, forKey: .type) {
            self.type = type
        } else {
            // Default to workoutCompleted for legacy notifications
            type = .workoutCompleted
        }

        metadata = try? container.decode(NotificationMetadataContainer.self, forKey: .metadata)
        actions = (try? container.decode([NotificationAction].self, forKey: .actions)) ?? []
        groupId = try? container.decode(String.self, forKey: .groupId)

        // Legacy fields - decode if present
        character = try? container.decode(FameFitCharacter.self, forKey: .character)
        workoutDuration = try? container.decode(Int.self, forKey: .workoutDuration)
        calories = try? container.decode(Int.self, forKey: .calories)
        followersEarned = try? container.decode(Int.self, forKey: .followersEarned)
    }
}

// Extension for UserDefaults storage
extension FameFitNotification {
    static let storageKey = "com.jimmypocock.FameFit.notifications"

    static func loadAll() -> [FameFitNotification] {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let notifications = try? JSONDecoder().decode([FameFitNotification].self, from: data)
        else {
            return []
        }
        return notifications
    }

    static func saveAll(_ notifications: [FameFitNotification]) {
        if let data = try? JSONEncoder().encode(notifications) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
}