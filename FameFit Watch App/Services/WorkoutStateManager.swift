//
//  WorkoutStateManager.swift
//  FameFit Watch App
//
//  Manages workout UI state with clean separation from business logic
//

import Foundation
import HealthKit
import Combine

@MainActor
final class WorkoutStateManager: ObservableObject, WorkoutStateManaging {
    // MARK: - Published Properties
    
    @Published private(set) var isWorkoutActive = false
    @Published private(set) var isPaused = false
    @Published private(set) var selectedWorkoutType: HKWorkoutActivityType?
    
    // MARK: - Publishers
    
    private let stateChangeSubject = PassthroughSubject<WorkoutStateChange, Never>()
    var stateChanges: AnyPublisher<WorkoutStateChange, Never> {
        stateChangeSubject.eraseToAnyPublisher()
    }
    
    // MARK: - WorkoutStateManaging Protocol
    
    func setWorkoutActive(_ active: Bool) {
        isWorkoutActive = active
        
        if active, let type = selectedWorkoutType {
            stateChangeSubject.send(.started(type))
            FameFitLogger.info("🏃 Workout started: \(type)", category: FameFitLogger.workout)
        } else if !active {
            stateChangeSubject.send(.ended)
            FameFitLogger.info("🏁 Workout ended", category: FameFitLogger.workout)
        }
    }
    
    func setPaused(_ paused: Bool) {
        isPaused = paused
        
        if paused {
            stateChangeSubject.send(.paused)
            FameFitLogger.info("⏸️ Workout paused", category: FameFitLogger.workout)
        } else if isWorkoutActive {
            stateChangeSubject.send(.resumed)
            FameFitLogger.info("▶️ Workout resumed", category: FameFitLogger.workout)
        }
    }
    
    func selectWorkoutType(_ type: HKWorkoutActivityType) {
        selectedWorkoutType = type
        FameFitLogger.debug("Selected workout type: \(type)", category: FameFitLogger.workout)
    }
    
    func reset() {
        isWorkoutActive = false
        isPaused = false
        selectedWorkoutType = nil
        FameFitLogger.debug("State reset", category: FameFitLogger.workout)
    }
}

// MARK: - Mock Implementation for Previews

final class MockWorkoutStateManager: WorkoutStateManaging {
    var isWorkoutActive = false
    var isPaused = false
    var selectedWorkoutType: HKWorkoutActivityType? = .running
    
    let stateChanges = PassthroughSubject<WorkoutStateChange, Never>()
        .eraseToAnyPublisher()
    
    func setWorkoutActive(_ active: Bool) {
        isWorkoutActive = active
    }
    
    func setPaused(_ paused: Bool) {
        isPaused = paused
    }
    
    func selectWorkoutType(_ type: HKWorkoutActivityType) {
        selectedWorkoutType = type
    }
    
    func reset() {
        isWorkoutActive = false
        isPaused = false
        selectedWorkoutType = nil
    }
}