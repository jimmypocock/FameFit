import Foundation

struct NotificationItem: Identifiable, Codable {
    let id: String
    let title: String
    let body: String
    let character: FameFitCharacter
    let timestamp: Date
    let workoutDuration: Int // minutes
    let calories: Int
    let followersEarned: Int
    var isRead: Bool
    
    init(title: String, body: String, character: FameFitCharacter, 
         workoutDuration: Int, calories: Int, followersEarned: Int = 5) {
        self.id = UUID().uuidString
        self.title = title
        self.body = body
        self.character = character
        self.timestamp = Date()
        self.workoutDuration = workoutDuration
        self.calories = calories
        self.followersEarned = followersEarned
        self.isRead = false
    }
}

// Extension for UserDefaults storage
extension NotificationItem {
    static let storageKey = "com.jimmypocock.FameFit.notifications"
    
    static func loadAll() -> [NotificationItem] {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let notifications = try? JSONDecoder().decode([NotificationItem].self, from: data) else {
            return []
        }
        return notifications
    }
    
    static func saveAll(_ notifications: [NotificationItem]) {
        if let data = try? JSONEncoder().encode(notifications) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
}