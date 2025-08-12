//
//  CountVerificationProtocol.swift
//  FameFit
//
//  Protocol for count verification service operations
//

import Foundation

protocol CountVerificationProtocol {
    func verifyAllCounts() async throws -> CountVerificationResult
    func verifyXPCount() async throws -> Int
    func verifyWorkoutCount() async throws -> Int
    func shouldVerifyOnAppLaunch() -> Bool
    func markCountsAsVerified()
}

// MARK: - Supporting Types

struct CountVerificationResult {
    let previousXP: Int
    let updatedXP: Int
    let xpCorrected: Bool
    
    let previousWorkoutCount: Int
    let updatedWorkoutCount: Int
    let workoutCountCorrected: Bool
    
    let verificationDate: Date
    
    var summary: String {
        var corrections: [String] = []
        if xpCorrected {
            corrections.append("XP: \(previousXP) → \(updatedXP)")
        }
        if workoutCountCorrected {
            corrections.append("Workouts: \(previousWorkoutCount) → \(updatedWorkoutCount)")
        }
        
        if corrections.isEmpty {
            return "All counts verified correctly"
        } else {
            return "Corrections made: " + corrections.joined(separator: ", ")
        }
    }
}