//
//  WorkoutKudosProtocol.swift
//  FameFit
//
//  Protocol for workout kudos service operations
//

import Combine
import Foundation

protocol WorkoutKudosProtocol {
    // Kudos actions
    func toggleKudos(for workoutID: String, ownerID: String) async throws -> KudosActionResult
    func removeKudos(for workoutID: String) async throws
    
    // Fetching kudos
    func getKudosSummary(for workoutID: String) async throws -> WorkoutKudosSummary
    func getUserKudos(for userID: String, limit: Int) async throws -> [WorkoutKudos]
    func hasUserGivenKudos(workoutID: String, userID: String) async throws -> Bool
    
    // Batch operations
    func getKudosSummaries(for workoutIDs: [String]) async throws -> [String: WorkoutKudosSummary]
    
    // Real-time updates
    var kudosUpdates: AnyPublisher<KudosUpdate, Never> { get }
}

// MARK: - Supporting Types

struct KudosUpdate {
    let workoutID: String
    let action: KudosAction
    let userID: String
    let newCount: Int
    
    enum KudosAction {
        case added
        case removed
    }
}