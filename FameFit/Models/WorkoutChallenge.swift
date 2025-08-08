//
//  WorkoutChallenge.swift
//  FameFit
//
//  Model for workout challenges between users
//

import CloudKit
import Foundation
import HealthKit

// MARK: - Challenge Type

enum ChallengeType: String, CaseIterable, Codable {
    case distance
    case duration
    case calories
    case workoutCount = "workout_count"
    case totalXP = "total_xp"
    case specificWorkout = "specific_workout"

    var displayName: String {
        switch self {
        case .distance: "Distance Challenge"
        case .duration: "Duration Challenge"
        case .calories: "Calorie Burn Challenge"
        case .workoutCount: "Workout Count Challenge"
        case .totalXP: "XP Challenge"
        case .specificWorkout: "Workout Type Challenge"
        }
    }

    var icon: String {
        switch self {
        case .distance: "📏"
        case .duration: "⏱️"
        case .calories: "🔥"
        case .workoutCount: "🏃"
        case .totalXP: "⭐"
        case .specificWorkout: "💪"
        }
    }

    var unit: String {
        switch self {
        case .distance: "km"
        case .duration: "minutes"
        case .calories: "cal"
        case .workoutCount: "workouts"
        case .totalXP: "XP"
        case .specificWorkout: "workouts"
        }
    }
}

// MARK: - Challenge Status

enum ChallengeStatus: String, Codable {
    case pending
    case accepted
    case declined
    case active
    case completed
    case cancelled
    case expired

    var canBeAccepted: Bool {
        self == .pending
    }

    var isActive: Bool {
        self == .active
    }

    var isFinished: Bool {
        [.completed, .cancelled, .expired].contains(self)
    }
}

// MARK: - Challenge Participant

struct ChallengeParticipant: Codable, Identifiable {
    let id: String // User ID
    let username: String
    let profileImageURL: String?
    var progress: Double = 0
    var lastUpdated: Date = .init()

    var isWinning: Bool = false
}

// MARK: - Workout Challenge

struct WorkoutChallenge: Identifiable, Codable {
    let id: String // CKRecord.ID as String
    let creatorID: String
    var participants: [ChallengeParticipant]
    let type: ChallengeType
    let targetValue: Double
    let workoutType: String? // For specific workout challenges (e.g., "Running")
    let name: String
    let description: String
    let startDate: Date
    let endDate: Date
    let createdTimestamp: Date
    var status: ChallengeStatus
    var winnerID: String?

    // Betting/Stakes (optional)
    var xpStake: Int = 0 // XP each participant puts up
    var winnerTakesAll: Bool = false

    // Privacy and Access Control
    var isPublic: Bool = true // Whether challenge shows in public feeds
    let maxParticipants: Int // Maximum number of participants allowed
    let joinCode: String? // For private challenges (invite-only)

    // Computed properties
    var isExpired: Bool {
        status == .active && Date() > endDate
    }
    
    var hasSpace: Bool {
        participants.count < maxParticipants
    }

    var daysRemaining: Int {
        let calendar = Calendar.current
        let now = Date()

        // If challenge has already ended, return 0
        if endDate < now {
            return 0
        }

        // Get start of today and start of end date
        let startOfToday = calendar.startOfDay(for: now)
        let startOfEndDate = calendar.startOfDay(for: endDate)

        // Calculate days between start of days
        let components = calendar.dateComponents([.day], from: startOfToday, to: startOfEndDate)
        let days = components.day ?? 0

        // If end date is today but hasn't passed yet, return 1
        if days == 0, endDate > now {
            return 1
        }

        return max(0, days + 1) // Add 1 to include the end date
    }

    var progressPercentage: Double {
        guard targetValue > 0 else { return 0 }
        let totalProgress = participants.reduce(0) { $0 + $1.progress }
        let avgProgress = totalProgress / Double(participants.count)
        return min(100, (avgProgress / targetValue) * 100)
    }

    var leadingParticipant: ChallengeParticipant? {
        participants.max(by: { $0.progress < $1.progress })
    }

    // Validation
    static func isValidChallenge(type: ChallengeType, targetValue: Double, duration: TimeInterval) -> Bool {
        guard targetValue > 0, duration > 0 else { return false }

        // Reasonable limits per type
        switch type {
        case .distance:
            return targetValue <= 1_000 // Max 1000 km
        case .duration:
            return targetValue <= 10_000 // Max 10000 minutes
        case .calories:
            return targetValue <= 50_000 // Max 50000 calories
        case .workoutCount:
            return targetValue <= 100 // Max 100 workouts
        case .totalXP:
            return targetValue <= 10_000 // Max 10000 XP
        case .specificWorkout:
            return targetValue <= 50 // Max 50 specific workouts
        }
    }
    
    // Generate a unique join code for private challenges
    static func generateJoinCode() -> String {
        let letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0 ..< 6).map { _ in letters.randomElement()! })
    }
}

// MARK: - CloudKit Extensions

extension WorkoutChallenge {
    init?(from record: CKRecord) {
        guard let creatorID = record["creatorID"] as? String,
              let participantsData = record["participants"] as? Data,
              let participants = try? JSONDecoder().decode([ChallengeParticipant].self, from: participantsData),
              let typeString = record["type"] as? String,
              let type = ChallengeType(rawValue: typeString),
              let targetValue = record["targetValue"] as? Double,
              let name = record["name"] as? String,
              let description = record["description"] as? String,
              let startDate = record["startTimestamp"] as? Date,
              let endDate = record["endTimestamp"] as? Date,
              let createdTimestamp = record["createdTimestamp"] as? Date,
              let statusString = record["status"] as? String,
              let status = ChallengeStatus(rawValue: statusString)
        else {
            return nil
        }

        id = record.recordID.recordName
        self.creatorID = creatorID
        self.participants = participants
        self.type = type
        self.targetValue = targetValue
        workoutType = record["workoutType"] as? String
        self.name = name
        self.description = description
        self.startDate = startDate
        self.endDate = endDate
        self.createdTimestamp = createdTimestamp
        self.status = status
        winnerID = record["winnerID"] as? String
        xpStake = Int(record["xpStake"] as? Int64 ?? 0)
        winnerTakesAll = (record["winnerTakesAll"] as? Int64) == 1
        isPublic = (record["isPublic"] as? Int64) == 1
        maxParticipants = Int(record["maxParticipants"] as? Int64 ?? 10)
        joinCode = record["joinCode"] as? String
    }

    func toCKRecord(recordID: CKRecord.ID? = nil) -> CKRecord {
        let record: CKRecord
        if let recordID {
            record = CKRecord(recordType: "WorkoutChallenges", recordID: recordID)
        } else {
            // Use the challenge's ID as the record name
            let challengeRecordID = CKRecord.ID(recordName: id)
            record = CKRecord(recordType: "WorkoutChallenges", recordID: challengeRecordID)
        }

        record["creatorID"] = creatorID
        record["participants"] = try? JSONEncoder().encode(participants)
        record["type"] = type.rawValue
        record["targetValue"] = targetValue

        if let workoutType {
            record["workoutType"] = workoutType
        }

        record["name"] = name
        record["description"] = description
        record["startTimestamp"] = startDate
        record["endTimestamp"] = endDate
        record["createdTimestamp"] = createdTimestamp
        record["status"] = status.rawValue

        if let winnerID {
            record["winnerID"] = winnerID
        }

        record["xpStake"] = Int64(xpStake)
        record["winnerTakesAll"] = winnerTakesAll ? Int64(1) : Int64(0)
        record["isPublic"] = isPublic ? Int64(1) : Int64(0)
        record["maxParticipants"] = Int64(maxParticipants)
        
        if let joinCode {
            record["joinCode"] = joinCode
        }

        return record
    }
}

// MARK: - Challenge Update

struct ChallengeUpdate: Codable {
    let challengeID: String
    let userID: String
    let progressValue: Double
    let timestamp: Date
    let workoutID: String? // Reference to specific workout
}
