//
//  BulkPrivacyUpdateProtocol.swift
//  FameFit
//
//  Protocol for bulk privacy update operations
//

import Combine
import Foundation

protocol BulkPrivacyUpdateProtocol: AnyObject {
    func updatePrivacyForAllActivities(to privacy: WorkoutPrivacy) async throws -> Int
    func updatePrivacyForActivities(activityIDs: [String], to privacy: WorkoutPrivacy) async throws -> Int
    func updatePrivacyForActivitiesByType(_ type: String, to privacy: WorkoutPrivacy) async throws -> Int
    func updatePrivacyForActivitiesInDateRange(from startDate: Date, to endDate: Date, privacy: WorkoutPrivacy) async throws -> Int
    var progressPublisher: AnyPublisher<BulkUpdateProgress, Never> { get }
}

// MARK: - Supporting Types

struct BulkUpdateProgress {
    let total: Int
    let completed: Int
    let failed: Int
    let currentActivity: String?
    
    var percentComplete: Double {
        guard total > 0 else { return 0 }
        return Double(completed) / Double(total) * 100
    }
}