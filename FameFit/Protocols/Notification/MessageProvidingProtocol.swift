//
//  MessageProvidingProtocol.swift
//  FameFit
//
//  Protocol for notification message provider operations
//

import Foundation

protocol MessageProvidingProtocol {
    func getWorkoutEndMessage(workoutType: String, duration: Int, calories: Int, xpEarned: Int) -> String
    func getStreakMessage(streak: Int, isAtRisk: Bool) -> String
    func getXPMilestoneMessage(level: Int, title: String) -> String
    func getFollowerMessage(username: String, displayName: String, action: String) -> String
}