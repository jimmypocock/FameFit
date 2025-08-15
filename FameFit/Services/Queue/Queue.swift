//
//  Queue.swift
//  FameFit
//
//  Generic persistent queue for operations
//

import Foundation
import os.log

/// Generic persistent queue for operations that need retry capability
actor Queue {
    private let logger = Logger(subsystem: "com.famefit", category: "Queue")
    private var pendingItems: [QueueItem] = []
    private var failedItems: [QueueItem] = []  // Dead letter queue
    private let maxQueueSize = 100
    private let maxRetries = 5
    
    // File-based persistence paths
    private let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    private var pendingQueueURL: URL {
        documentsDirectory.appendingPathComponent("PendingOperations")
    }
    private var deadLetterQueueURL: URL {
        documentsDirectory.appendingPathComponent("FailedOperations")
    }
    
    init() {
        Task {
            await setupDirectories()
            await loadFromDisk()
        }
    }
    
    // MARK: - Public Methods
    
    /// Add item to queue
    func enqueue(_ item: QueueItem) async {
        // Check if already exists
        if let index = pendingItems.firstIndex(where: { $0.id == item.id }) {
            // Update existing item
            pendingItems[index].attempts += 1
            pendingItems[index].lastAttemptDate = Date()
        } else {
            // Add new item
            pendingItems.append(item)
        }
        
        // Sort by priority and age
        pendingItems.sort { lhs, rhs in
            if lhs.priority != rhs.priority {
                return lhs.priority > rhs.priority
            }
            return lhs.createdDate < rhs.createdDate
        }
        
        // Trim if too large
        if pendingItems.count > maxQueueSize {
            let removed = pendingItems.suffix(pendingItems.count - maxQueueSize)
            pendingItems = Array(pendingItems.prefix(maxQueueSize))
            
            for item in removed {
                logger.warning("Dropping item \(item.id) due to queue size limit")
                await moveToDeadLetter(item)
            }
        }
        
        await saveToDisk()
        logger.info("Enqueued item \(item.id) with priority \(item.priority.rawValue)")
    }
    
    /// Get next item to process
    func dequeue() async -> QueueItem? {
        // Find item that's ready to retry (at least 60 seconds since last attempt)
        let now = Date()
        let readyItem = pendingItems.first { item in
            now.timeIntervalSince(item.lastAttemptDate) >= 60
        }
        
        if let item = readyItem {
            pendingItems.removeAll { $0.id == item.id }
            await saveToDisk()
            return item
        }
        
        return nil
    }
    
    /// Remove item from queue (successful completion)
    func remove(id: String) async {
        pendingItems.removeAll { $0.id == id }
        await saveToDisk()
        logger.info("Removed completed item \(id)")
    }
    
    /// Move item to dead letter queue after max retries
    func moveToDeadLetter(_ item: QueueItem) async {
        pendingItems.removeAll { $0.id == item.id }
        failedItems.append(item)
        
        // Keep dead letter queue size reasonable
        if failedItems.count > 50 {
            failedItems = Array(failedItems.suffix(50))
        }
        
        await saveToDisk()
        logger.warning("Moved item \(item.id) to dead letter queue after \(item.attempts) attempts")
    }
    
    /// Handle item failure - re-queue or move to dead letter
    func handleFailure(for item: QueueItem) async {
        var updatedItem = item
        updatedItem.attempts += 1
        updatedItem.lastAttemptDate = Date()
        
        if updatedItem.attempts >= maxRetries {
            await moveToDeadLetter(updatedItem)
        } else {
            await enqueue(updatedItem)
        }
    }
    
    /// Get all pending items
    func getPendingItems() -> [QueueItem] {
        pendingItems
    }
    
    /// Get all failed items (dead letter queue)
    func getFailedItems() -> [QueueItem] {
        failedItems
    }
    
    /// Clear old items (over 7 days)
    func cleanupOldItems() async {
        let cutoffDate = Date().addingTimeInterval(-7 * 24 * 60 * 60)
        let oldPendingCount = pendingItems.count
        let oldFailedCount = failedItems.count
        
        pendingItems.removeAll { item in
            item.createdDate < cutoffDate
        }
        
        failedItems.removeAll { item in
            item.createdDate < cutoffDate
        }
        
        let removedPending = oldPendingCount - pendingItems.count
        let removedFailed = oldFailedCount - failedItems.count
        
        if removedPending > 0 || removedFailed > 0 {
            logger.info("Cleaned up \(removedPending) old pending items and \(removedFailed) old failed items")
            await saveToDisk()
        }
    }
    
    // MARK: - File-based Persistence
    
    private func setupDirectories() async {
        do {
            try FileManager.default.createDirectory(at: pendingQueueURL, withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: deadLetterQueueURL, withIntermediateDirectories: true)
        } catch {
            logger.error("Failed to create queue directories: \(error.localizedDescription)")
        }
    }
    
    private func saveToDisk() async {
        // Save each item as a separate file for atomicity
        do {
            // Clear existing files
            let pendingFiles = try FileManager.default.contentsOfDirectory(at: pendingQueueURL, includingPropertiesForKeys: nil)
            for file in pendingFiles {
                try FileManager.default.removeItem(at: file)
            }
            
            // Save pending items
            for item in pendingItems {
                let fileURL = pendingQueueURL.appendingPathComponent("\(item.id).json")
                let data = try JSONEncoder().encode(item)
                try data.write(to: fileURL)
            }
            
            // Clear existing dead letter files
            let deadLetterFiles = try FileManager.default.contentsOfDirectory(at: deadLetterQueueURL, includingPropertiesForKeys: nil)
            for file in deadLetterFiles {
                try FileManager.default.removeItem(at: file)
            }
            
            // Save dead letter items
            for item in failedItems {
                let fileURL = deadLetterQueueURL.appendingPathComponent("\(item.id).json")
                let data = try JSONEncoder().encode(item)
                try data.write(to: fileURL)
            }
            
        } catch {
            logger.error("Failed to save queue to disk: \(error.localizedDescription)")
        }
    }
    
    private func loadFromDisk() async {
        do {
            // Load pending items
            let pendingFiles = try FileManager.default.contentsOfDirectory(at: pendingQueueURL, includingPropertiesForKeys: nil)
            var loadedPending: [QueueItem] = []
            
            for fileURL in pendingFiles where fileURL.pathExtension == "json" {
                let data = try Data(contentsOf: fileURL)
                if let item = try? JSONDecoder().decode(QueueItem.self, from: data) {
                    loadedPending.append(item)
                }
            }
            
            pendingItems = loadedPending.sorted { lhs, rhs in
                if lhs.priority != rhs.priority {
                    return lhs.priority > rhs.priority
                }
                return lhs.createdDate < rhs.createdDate
            }
            
            // Load dead letter items
            let deadLetterFiles = try FileManager.default.contentsOfDirectory(at: deadLetterQueueURL, includingPropertiesForKeys: nil)
            var loadedFailed: [QueueItem] = []
            
            for fileURL in deadLetterFiles where fileURL.pathExtension == "json" {
                let data = try Data(contentsOf: fileURL)
                if let item = try? JSONDecoder().decode(QueueItem.self, from: data) {
                    loadedFailed.append(item)
                }
            }
            
            failedItems = loadedFailed
            
            logger.info("Loaded \(self.pendingItems.count) pending items and \(self.failedItems.count) failed items from disk")
            
            // Clean up old items on load
            await cleanupOldItems()
            
        } catch {
            logger.error("Failed to load queue from disk: \(error.localizedDescription)")
        }
    }
}