//
//  MessageDeduplicator.swift
//  FameFit
//
//  Handles deduplication of WatchConnectivity messages
//

import Foundation

/// Thread-safe message deduplicator for WatchConnectivity
actor MessageDeduplicator {
    private var processedMessageIDs = Set<String>()
    private var messageTimestamps: [String: Date] = [:]
    private let maxAge: TimeInterval = 300 // 5 minutes
    private let maxStoredIDs = 100
    
    /// Check if a message should be processed based on its ID
    func shouldProcess(_ message: [String: Any]) -> Bool {
        // Messages without IDs are always processed (legacy support)
        guard let messageID = message["id"] as? String else {
            return true
        }
        
        // Check if we've seen this ID before
        if processedMessageIDs.contains(messageID) {
            FameFitLogger.debug("Skipping duplicate message: \(messageID)", category: FameFitLogger.connectivity)
            return false
        }
        
        // Add to processed set
        processedMessageIDs.insert(messageID)
        messageTimestamps[messageID] = Date()
        
        // Clean old entries if we have too many
        if processedMessageIDs.count > maxStoredIDs {
            cleanOldEntries()
        }
        
        return true
    }
    
    private func cleanOldEntries() {
        let cutoffDate = Date().addingTimeInterval(-maxAge)
        
        // Remove entries older than maxAge
        let idsToRemove = messageTimestamps.compactMap { (id, timestamp) in
            timestamp < cutoffDate ? id : nil
        }
        
        for id in idsToRemove {
            processedMessageIDs.remove(id)
            messageTimestamps.removeValue(forKey: id)
        }
        
        // If still too many, remove oldest half
        if processedMessageIDs.count > maxStoredIDs {
            let sortedByAge = messageTimestamps.sorted { $0.value < $1.value }
            let toRemove = sortedByAge.prefix(maxStoredIDs / 2)
            
            for (id, _) in toRemove {
                processedMessageIDs.remove(id)
                messageTimestamps.removeValue(forKey: id)
            }
        }
    }
    
    /// Clear all stored message IDs
    func reset() {
        processedMessageIDs.removeAll()
        messageTimestamps.removeAll()
    }
}