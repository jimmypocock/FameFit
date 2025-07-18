//
//  MessageProviding.swift
//  FameFit Watch App
//
//  Protocol for providing motivational/roasting messages with personality customization
//

import Foundation
import HealthKit

// MARK: - Personality Configuration

/// Represents the level of roasting vs encouragement in messages
public enum RoastLevel: Int, CaseIterable {
    case pureEncouragement = 0  // Only positive, supportive messages
    case lightTeasing = 1       // Gentle teasing mixed with encouragement
    case moderateRoasting = 2   // Balanced roasting and motivation (default)
    case heavyRoasting = 3      // Mostly roasts with some motivation
    case ruthless = 4           // Maximum roasting, minimal encouragement
    
    /// User-friendly description for settings UI
    var description: String {
        switch self {
        case .pureEncouragement: return "Pure Encouragement"
        case .lightTeasing: return "Light Teasing"
        case .moderateRoasting: return "Moderate Roasting"
        case .heavyRoasting: return "Heavy Roasting"
        case .ruthless: return "Ruthless"
        }
    }
    
    /// Weight for roast vs encouragement messages (0.0 = all encouragement, 1.0 = all roasts)
    var roastWeight: Double {
        switch self {
        case .pureEncouragement: return 0.0
        case .lightTeasing: return 0.2
        case .moderateRoasting: return 0.5
        case .heavyRoasting: return 0.8
        case .ruthless: return 0.95
        }
    }
}

/// Configuration for message personality
public struct MessagePersonality {
    let roastLevel: RoastLevel
    let includeHumblebrags: Bool
    let includeSocialMediaRefs: Bool
    let includeSupplementTalk: Bool
    let includePhilosophicalNonsense: Bool
    
    /// Default personality configuration
    public static let `default` = MessagePersonality(
        roastLevel: .moderateRoasting,
        includeHumblebrags: true,
        includeSocialMediaRefs: true,
        includeSupplementTalk: true,
        includePhilosophicalNonsense: true
    )
    
    /// Pure encouragement configuration
    public static let encouraging = MessagePersonality(
        roastLevel: .pureEncouragement,
        includeHumblebrags: false,
        includeSocialMediaRefs: false,
        includeSupplementTalk: false,
        includePhilosophicalNonsense: false
    )
    
    /// Maximum roasting configuration
    public static let savage = MessagePersonality(
        roastLevel: .ruthless,
        includeHumblebrags: true,
        includeSocialMediaRefs: true,
        includeSupplementTalk: true,
        includePhilosophicalNonsense: true
    )
}

// MARK: - Message Context

/// Context information for generating appropriate messages
public struct MessageContext {
    let workoutType: HKWorkoutActivityType?
    let duration: TimeInterval?
    let currentTime: Date
    let milestoneReached: Int? // minutes
    let isWorkoutStart: Bool
    let isWorkoutEnd: Bool
    
    /// Creates context for workout start
    static func workoutStart(workoutType: HKWorkoutActivityType, time: Date = Date()) -> MessageContext {
        return MessageContext(
            workoutType: workoutType,
            duration: nil,
            currentTime: time,
            milestoneReached: nil,
            isWorkoutStart: true,
            isWorkoutEnd: false
        )
    }
    
    /// Creates context for workout end
    static func workoutEnd(workoutType: HKWorkoutActivityType, duration: TimeInterval, time: Date = Date()) -> MessageContext {
        return MessageContext(
            workoutType: workoutType,
            duration: duration,
            currentTime: time,
            milestoneReached: nil,
            isWorkoutStart: false,
            isWorkoutEnd: true
        )
    }
    
    /// Creates context for workout milestone
    static func milestone(_ minutes: Int, workoutType: HKWorkoutActivityType, time: Date = Date()) -> MessageContext {
        return MessageContext(
            workoutType: workoutType,
            duration: TimeInterval(minutes * 60),
            currentTime: time,
            milestoneReached: minutes,
            isWorkoutStart: false,
            isWorkoutEnd: false
        )
    }
    
    /// Creates context for random workout message
    static func randomWorkout(workoutType: HKWorkoutActivityType, duration: TimeInterval, time: Date = Date()) -> MessageContext {
        return MessageContext(
            workoutType: workoutType,
            duration: duration,
            currentTime: time,
            milestoneReached: nil,
            isWorkoutStart: false,
            isWorkoutEnd: false
        )
    }
}

// MARK: - Message Provider Protocol

/// Protocol for providing contextual workout messages with personality customization
public protocol MessageProviding {
    /// Current personality configuration
    var personality: MessagePersonality { get set }
    
    /// Gets a message for the given context
    /// - Parameter context: The context for message generation
    /// - Returns: An appropriate message string
    func getMessage(for context: MessageContext) -> String
    
    /// Gets a time-aware message (morning motivation, etc.)
    /// - Parameter time: The current time (defaults to now)
    /// - Returns: A time-appropriate message
    func getTimeAwareMessage(at time: Date) -> String
    
    /// Gets a random motivational message
    /// - Returns: A general motivational message
    func getMotivationalMessage() -> String
    
    /// Gets a random roast message
    /// - Parameter workoutType: Optional workout type for specific roasts
    /// - Returns: A roast message
    func getRoastMessage(for workoutType: HKWorkoutActivityType?) -> String
    
    /// Gets a catchphrase
    /// - Returns: A signature catchphrase
    func getCatchphrase() -> String
    
    /// Updates personality configuration
    /// - Parameter newPersonality: The new personality settings
    func updatePersonality(_ newPersonality: MessagePersonality)
    
    /// Checks if a message category should be included based on personality
    /// - Parameter category: The category to check
    /// - Returns: True if the category should be included
    func shouldIncludeCategory(_ category: MessageCategory) -> Bool
}

// MARK: - Message Category (from existing FameFitMessages)

/// Categories of messages available
public enum MessageCategory: String, CaseIterable {
    case workoutStart
    case workoutMilestone
    case workoutEnd
    case missedWorkout
    case achievement
    case encouragement
    case roast
    case morningMotivation
    case socialMediaReferences
    case supplementTalk
    case philosophicalNonsense
    case humbleBrags
    case catchphrases
    
    /// Whether this category is affected by personality settings
    var isPersonalityDependent: Bool {
        switch self {
        case .workoutStart, .workoutMilestone, .workoutEnd, .missedWorkout, .achievement:
            return false // Always included
        case .encouragement, .roast:
            return true // Affected by roast level
        case .morningMotivation, .catchphrases:
            return false // Always included
        case .socialMediaReferences, .supplementTalk, .philosophicalNonsense, .humbleBrags:
            return true // Can be disabled by personality
        }
    }
}

// MARK: - Default Implementation Extensions

public extension MessageProviding {
    /// Default implementation for checking if a category should be included
    func shouldIncludeCategory(_ category: MessageCategory) -> Bool {
        guard category.isPersonalityDependent else { return true }
        
        switch category {
        case .socialMediaReferences:
            return personality.includeSocialMediaRefs
        case .supplementTalk:
            return personality.includeSupplementTalk
        case .philosophicalNonsense:
            return personality.includePhilosophicalNonsense
        case .humbleBrags:
            return personality.includeHumblebrags
        case .encouragement, .roast:
            // These are handled by roast level logic in implementations
            return true
        default:
            return true
        }
    }
    
    /// Helper to determine if a roast should be shown based on personality
    func shouldShowRoast() -> Bool {
        return Double.random(in: 0...1) < personality.roastLevel.roastWeight
    }
}
