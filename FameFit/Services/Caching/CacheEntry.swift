//
//  CacheEntry.swift
//  FameFit
//
//  Cache entry wrapper with TTL support
//

import Foundation

/// A wrapper for cached values with expiration support
struct CacheEntry<T> {
    let value: T
    let timestamp: Date
    let ttl: TimeInterval
    
    /// Check if this cache entry has expired
    var isExpired: Bool {
        Date().timeIntervalSince(timestamp) > ttl
    }
    
    /// Check if this cache entry is still valid
    var isValid: Bool {
        !isExpired
    }
    
    /// Time remaining until expiration (nil if already expired)
    var timeRemaining: TimeInterval? {
        let elapsed = Date().timeIntervalSince(timestamp)
        let remaining = ttl - elapsed
        return remaining > 0 ? remaining : nil
    }
    
    /// Create a new cache entry with the current timestamp
    init(value: T, ttl: TimeInterval) {
        self.value = value
        self.timestamp = Date()
        self.ttl = ttl
    }
}

// MARK: - Codable Support

extension CacheEntry: Codable where T: Codable {
    enum CodingKeys: String, CodingKey {
        case value
        case timestamp
        case ttl
    }
}

