//
//  CacheProtocol.swift
//  FameFit
//
//  Protocol for cache management operations
//

import Foundation

protocol CacheProtocol {
    /// Get a cached value
    func get<T>(_ key: String, type: T.Type) -> T?
    
    /// Set a cached value with TTL
    func set<T>(_ key: String, value: T, ttl: TimeInterval)
    
    /// Remove a cached value
    func remove(_ key: String)
    
    /// Remove all cached values
    func removeAll()
    
    /// Remove all expired entries
    func removeExpired()
    
    /// Invalidate entries matching a pattern
    func invalidate(matching pattern: String)
    
    /// Get cache statistics
    var statistics: CacheStatistics { get }
}

// MARK: - Cache Statistics

struct CacheStatistics {
    let totalEntries: Int
    let totalSize: Int
    let hitRate: Double
    let missRate: Double
    let evictionCount: Int
}