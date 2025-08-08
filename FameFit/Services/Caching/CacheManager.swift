//
//  CacheManager.swift
//  FameFit
//
//  Generic cache management with TTL and memory pressure handling
//

import Foundation
import Combine
#if os(iOS)
import UIKit
#endif

// MARK: - Cache Manager Protocol

protocol CacheManaging {
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

// MARK: - Cache Manager Implementation

final class CacheManager: NSObject, CacheManaging, @unchecked Sendable {
    // MARK: - Properties
    
    private let cache = NSCache<NSString, CacheEntryWrapper>()
    private let queue = DispatchQueue(label: "com.famefit.cache", attributes: .concurrent)
    private var keyTracker = Set<String>()
    
    // Statistics tracking
    private var hits: Int = 0
    private var misses: Int = 0
    private var evictions: Int = 0
    
    // Memory pressure handling
    private var memoryPressureObserver: NSObjectProtocol?
    
    // Background cleanup timer
    private var cleanupTimer: Timer?
    private let cleanupInterval: TimeInterval = 60 // 1 minute
    
    // MARK: - Initialization
    
    override init() {
        super.init()
        
        cache.countLimit = 1_000
        cache.totalCostLimit = 50 * 1_024 * 1_024 // 50MB default
        cache.delegate = self
        
        setupMemoryPressureHandling()
        setupBackgroundCleanup()
    }
    
    convenience init(countLimit: Int, totalCostLimit: Int) {
        self.init()
        cache.countLimit = countLimit
        cache.totalCostLimit = totalCostLimit
    }
    
    deinit {
        cleanupTimer?.invalidate()
        if let observer = memoryPressureObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    // MARK: - CacheManaging Implementation
    
    func get<T>(_ key: String, type: T.Type) -> T? {
        queue.sync {
            guard let wrapper = cache.object(forKey: key as NSString),
                  let entry = wrapper.entry as? CacheEntry<T> else {
                misses += 1
                return nil
            }
            
            // Check expiration
            if entry.isExpired {
                cache.removeObject(forKey: key as NSString)
                keyTracker.remove(key)
                misses += 1
                return nil
            }
            
            hits += 1
            return entry.value
        }
    }
    
    func set<T>(_ key: String, value: T, ttl: TimeInterval) {
        queue.async(flags: .barrier) {
            let entry = CacheEntry(value: value, ttl: ttl)
            let wrapper = CacheEntryWrapper(entry: entry)
            
            // Calculate cost (rough estimate)
            let cost = MemoryLayout<T>.size
            
            self.cache.setObject(wrapper, forKey: key as NSString, cost: cost)
            self.keyTracker.insert(key)
        }
    }
    
    func remove(_ key: String) {
        queue.async(flags: .barrier) {
            self.cache.removeObject(forKey: key as NSString)
            self.keyTracker.remove(key)
        }
    }
    
    func removeAll() {
        queue.async(flags: .barrier) {
            self.cache.removeAllObjects()
            self.keyTracker.removeAll()
            self.hits = 0
            self.misses = 0
            self.evictions = 0
        }
    }
    
    func removeExpired() {
        queue.async(flags: .barrier) {
            let keysToRemove = self.keyTracker.filter { key in
                guard let wrapper = self.cache.object(forKey: key as NSString),
                      let entry = wrapper.entry as? CacheEntry<Any> else {
                    return true // Remove if can't find
                }
                return entry.isExpired
            }
            
            for key in keysToRemove {
                self.cache.removeObject(forKey: key as NSString)
                self.keyTracker.remove(key)
            }
        }
    }
    
    func invalidate(matching pattern: String) {
        queue.async(flags: .barrier) {
            let keysToRemove = self.keyTracker.filter { key in
                key.contains(pattern)
            }
            
            for key in keysToRemove {
                self.cache.removeObject(forKey: key as NSString)
                self.keyTracker.remove(key)
            }
        }
    }
    
    var statistics: CacheStatistics {
        queue.sync {
            let total = hits + misses
            let hitRate = total > 0 ? Double(hits) / Double(total) : 0
            let missRate = total > 0 ? Double(misses) / Double(total) : 0
            
            return CacheStatistics(
                totalEntries: keyTracker.count,
                totalSize: 0, // Would need more sophisticated tracking
                hitRate: hitRate,
                missRate: missRate,
                evictionCount: evictions
            )
        }
    }
    
    // MARK: - Private Methods
    
    private func setupMemoryPressureHandling() {
        #if os(iOS)
        memoryPressureObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleMemoryPressure()
        }
        #endif
    }
    
    private func setupBackgroundCleanup() {
        cleanupTimer = Timer.scheduledTimer(withTimeInterval: cleanupInterval, repeats: true) { [weak self] _ in
            self?.removeExpired()
        }
    }
    
    private func handleMemoryPressure() {
        // Remove expired entries first
        removeExpired()
        
        // If still under pressure, remove oldest entries
        queue.async(flags: .barrier) {
            // NSCache will handle this automatically based on cost limits
            // But we can be more aggressive if needed
            let entriesToRemove = self.keyTracker.count / 2
            if entriesToRemove > 0 {
                let keysToRemove = Array(self.keyTracker.prefix(entriesToRemove))
                for key in keysToRemove {
                    self.cache.removeObject(forKey: key as NSString)
                    self.keyTracker.remove(key)
                }
            }
        }
    }
}

// MARK: - NSCacheDelegate

extension CacheManager: NSCacheDelegate {
    func cache(_ cache: NSCache<AnyObject, AnyObject>, willEvictObject obj: Any) {
        queue.async(flags: .barrier) {
            self.evictions += 1
        }
    }
}

// MARK: - Cache Entry Wrapper

private class CacheEntryWrapper: NSObject {
    let entry: Any
    
    init(entry: Any) {
        self.entry = entry
        super.init()
    }
}
