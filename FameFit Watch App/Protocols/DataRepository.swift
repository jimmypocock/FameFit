//
//  DataRepository.swift
//  FameFit Watch App
//
//  Protocol for type-safe data persistence with caching
//

import Foundation

// MARK: - Data Repository Protocol

protocol DataRepository {
    /// Save a codable object with a specific key
    func save<T: Codable>(_ object: T, for key: String) async throws
    
    /// Load a codable object for a specific key
    func load<T: Codable>(_ type: T.Type, for key: String) async throws -> T?
    
    /// Remove data for a specific key
    func remove(for key: String) async throws
    
    /// Check if data exists for a key
    func exists(for key: String) async -> Bool
    
    /// Clear all stored data (useful for logout)
    func clearAll() async throws
    
    /// Get data age (time since last update)
    func age(for key: String) async -> TimeInterval?
}

// MARK: - UserDefaults Implementation

final class UserDefaultsRepository: DataRepository {
    private let userDefaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }
    
    func save<T: Codable>(_ object: T, for key: String) async throws {
        let data = try encoder.encode(object)
        userDefaults.set(data, forKey: key)
        userDefaults.set(Date(), forKey: "\(key).timestamp")
    }
    
    func load<T: Codable>(_ type: T.Type, for key: String) async throws -> T? {
        guard let data = userDefaults.data(forKey: key) else { return nil }
        return try decoder.decode(type, from: data)
    }
    
    func remove(for key: String) async throws {
        userDefaults.removeObject(forKey: key)
        userDefaults.removeObject(forKey: "\(key).timestamp")
    }
    
    func exists(for key: String) async -> Bool {
        userDefaults.object(forKey: key) != nil
    }
    
    func clearAll() async throws {
        // Clear all Watch-specific keys
        for key in WatchConfiguration.StorageKeys.Profile.allCases {
            userDefaults.removeObject(forKey: key.rawValue)
        }
        for key in WatchConfiguration.StorageKeys.GroupWorkout.allCases {
            userDefaults.removeObject(forKey: key.rawValue)
        }
        for key in WatchConfiguration.StorageKeys.Challenge.allCases {
            userDefaults.removeObject(forKey: key.rawValue)
        }
        for key in WatchConfiguration.StorageKeys.Sync.allCases {
            userDefaults.removeObject(forKey: key.rawValue)
        }
        for key in WatchConfiguration.StorageKeys.Workout.allCases {
            userDefaults.removeObject(forKey: key.rawValue)
        }
        for key in WatchConfiguration.StorageKeys.Complication.allCases {
            userDefaults.removeObject(forKey: key.rawValue)
        }
    }
    
    func age(for key: String) async -> TimeInterval? {
        guard let timestamp = userDefaults.object(forKey: "\(key).timestamp") as? Date else {
            return nil
        }
        return Date().timeIntervalSince(timestamp)
    }
}

// MARK: - Cache Manager

final class CacheManager {
    let repository: DataRepository
    
    init(repository: DataRepository = UserDefaultsRepository()) {
        self.repository = repository
    }
    
    /// Save data with automatic timestamp
    func cache<T: Codable>(_ object: T, for key: String) async {
        try? await repository.save(object, for: key)
    }
    
    /// Load data if it's within the cache duration
    func loadCached<T: Codable>(_ type: T.Type, for key: String, maxAge: TimeInterval) async -> T? {
        // Check if data exists and is fresh
        if let age = await repository.age(for: key), age > maxAge {
            // Data is stale, remove it
            try? await repository.remove(for: key)
            return nil
        }
        
        return try? await repository.load(type, for: key)
    }
    
    /// Force refresh by removing cached data
    func invalidate(for key: String) async {
        try? await repository.remove(for: key)
    }
    
    /// Clear all caches
    func clearAll() async {
        try? await repository.clearAll()
    }
}