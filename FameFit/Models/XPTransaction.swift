//
//  XPTransaction.swift
//  FameFit
//
//  Represents an XP transaction record for audit trail
//

import Foundation
import CloudKit

struct XPTransaction: Identifiable, Codable {
    let id: UUID
    let userID: String
    let workoutID: String
    let timestamp: Date
    let baseXP: Int
    let finalXP: Int
    let factors: XPCalculationFactors
    let creationDate: Date
    let modificationDate: Date
    
    init(id: UUID = UUID(),
         userID: String,
         workoutID: String,
         timestamp: Date = Date(),
         baseXP: Int,
         finalXP: Int,
         factors: XPCalculationFactors,
         creationDate: Date = Date(),
         modificationDate: Date = Date()) {
        self.id = id
        self.userID = userID
        self.workoutID = workoutID
        self.timestamp = timestamp
        self.baseXP = baseXP
        self.finalXP = finalXP
        self.factors = factors
        self.creationDate = creationDate
        self.modificationDate = modificationDate
    }
}

// MARK: - XP Calculation Factors
struct XPCalculationFactors: Codable {
    let workoutType: String
    let duration: TimeInterval
    let dayOfWeek: String
    let timeOfDay: String
    let consistencyStreak: Int
    let milestones: [String]
    let bonuses: [XPBonus]
    
    var totalMultiplier: Double {
        bonuses.reduce(1.0) { $0 * $1.multiplier }
    }
}

// MARK: - XP Bonus
struct XPBonus: Codable {
    let type: XPBonusType
    let multiplier: Double
    let description: String
}

enum XPBonusType: String, Codable, CaseIterable {
    case firstWorkoutOfDay = "first_workout_of_day"
    case weekendWarrior = "weekend_warrior"
    case earlyBird = "early_bird"
    case nightOwl = "night_owl"
    case consistencyStreak = "consistency_streak"
    case milestone = "milestone"
    case perfectWeek = "perfect_week"
    case varietyBonus = "variety_bonus"
}

// MARK: - CloudKit Support
extension XPTransaction {
    static let recordType = "XPTransactions"
    
    init?(from record: CKRecord) {
        guard record.recordType == Self.recordType,
              let userID = record["userID"] as? String,
              let workoutID = record["workoutID"] as? String,
              let timestamp = record["timestamp"] as? Date,
              let baseXP = record["baseXP"] as? Int64,
              let finalXP = record["finalXP"] as? Int64,
              let factorsData = record["factors"] as? Data else {
            return nil
        }
        
        let decoder = JSONDecoder()
        guard let factors = try? decoder.decode(XPCalculationFactors.self, from: factorsData) else {
            return nil
        }
        
        self.id = UUID(uuidString: record.recordID.recordName) ?? UUID()
        self.userID = userID
        self.workoutID = workoutID
        self.timestamp = timestamp
        self.baseXP = Int(baseXP)
        self.finalXP = Int(finalXP)
        self.factors = factors
        self.creationDate = record.creationDate ?? Date()
        self.modificationDate = record.modificationDate ?? Date()
    }
    
    func toCKRecord() -> CKRecord {
        let recordID = CKRecord.ID(recordName: id.uuidString)
        let record = CKRecord(recordType: Self.recordType, recordID: recordID)
        
        record["userID"] = userID
        record["workoutID"] = workoutID
        record["timestamp"] = timestamp
        record["baseXP"] = Int64(baseXP)
        record["finalXP"] = Int64(finalXP)
        
        let encoder = JSONEncoder()
        if let factorsData = try? encoder.encode(factors) {
            record["factors"] = factorsData
        }
        
        return record
    }
}

// MARK: - Display Helpers
extension XPTransaction {
    var xpGained: Int {
        finalXP - baseXP
    }
    
    var multiplierText: String {
        String(format: "%.1fx", factors.totalMultiplier)
    }
    
    var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }
}

extension XPBonus {
    var iconName: String {
        switch type {
        case .firstWorkoutOfDay: return "sunrise.fill"
        case .weekendWarrior: return "calendar.badge.plus"
        case .earlyBird: return "sun.max.fill"
        case .nightOwl: return "moon.stars.fill"
        case .consistencyStreak: return "flame.fill"
        case .milestone: return "star.fill"
        case .perfectWeek: return "checkmark.seal.fill"
        case .varietyBonus: return "shuffle"
        }
    }
    
    var color: String {
        switch type {
        case .firstWorkoutOfDay: return "orange"
        case .weekendWarrior: return "purple"
        case .earlyBird: return "yellow"
        case .nightOwl: return "indigo"
        case .consistencyStreak: return "red"
        case .milestone: return "gold"
        case .perfectWeek: return "green"
        case .varietyBonus: return "blue"
        }
    }
}
