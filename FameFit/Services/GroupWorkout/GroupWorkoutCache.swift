//
//  GroupWorkoutCache.swift
//  FameFit
//
//  Thread-safe cache for group workout data using Swift actors
//

import Foundation

/// Thread-safe cache for group workout data
actor GroupWorkoutCache {
    // MARK: - Properties
    
    private var workoutCache: [String: (workout: GroupWorkout, timestamp: Date)] = [:]
    private var throttleCache: [String: Date] = [:]
    
    // MARK: - Workout Cache
    
    func store(workout: GroupWorkout) {
        workoutCache[workout.id] = (workout, Date())
    }
    
    func get(workoutID: String, expiration: TimeInterval) -> GroupWorkout? {
        guard let cached = workoutCache[workoutID] else { return nil }
        
        // Check if cache expired
        if Date().timeIntervalSince(cached.timestamp) > expiration {
            workoutCache.removeValue(forKey: workoutID)
            return nil
        }
        
        return cached.workout
    }
    
    func remove(workoutID: String) {
        workoutCache.removeValue(forKey: workoutID)
    }
    
    func clear() {
        workoutCache.removeAll()
        throttleCache.removeAll()
    }
    
    // MARK: - Throttle Cache
    
    func shouldThrottle(workoutID: String, interval: TimeInterval) -> Bool {
        let now = Date()
        
        if let lastUpdate = throttleCache[workoutID] {
            if now.timeIntervalSince(lastUpdate) < interval {
                return false
            }
        }
        
        throttleCache[workoutID] = now
        return true
    }
}
