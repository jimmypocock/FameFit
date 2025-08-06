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
    
    func get(workoutId: String, expiration: TimeInterval) -> GroupWorkout? {
        guard let cached = workoutCache[workoutId] else { return nil }
        
        // Check if cache expired
        if Date().timeIntervalSince(cached.timestamp) > expiration {
            workoutCache.removeValue(forKey: workoutId)
            return nil
        }
        
        return cached.workout
    }
    
    func remove(workoutId: String) {
        workoutCache.removeValue(forKey: workoutId)
    }
    
    func clear() {
        workoutCache.removeAll()
        throttleCache.removeAll()
    }
    
    // MARK: - Throttle Cache
    
    func shouldThrottle(workoutId: String, interval: TimeInterval) -> Bool {
        let now = Date()
        
        if let lastUpdate = throttleCache[workoutId] {
            if now.timeIntervalSince(lastUpdate) < interval {
                return false
            }
        }
        
        throttleCache[workoutId] = now
        return true
    }
}