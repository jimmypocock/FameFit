//
//  WorkoutMetrics.swift
//  FameFit
//
//  Real-time metrics for workouts with privacy controls
//

import Foundation
import CloudKit
import CoreLocation

/// Privacy levels for sharing workout metrics
enum WorkoutSharingLevel: String, CaseIterable, Codable {
    case privateOnly = "private"     // Not shared
    case friendsOnly = "friends"     // Only followers can see
    case groupOnly = "group"         // Only group participants
    case coachOnly = "coach"         // Only designated coaches
    case publicFeed = "public"       // Anyone can see
    
    var displayName: String {
        switch self {
        case .privateOnly: return "Private"
        case .friendsOnly: return "Friends Only"
        case .groupOnly: return "Group Only"
        case .coachOnly: return "Coach Only"
        case .publicFeed: return "Public"
        }
    }
    
    var icon: String {
        switch self {
        case .privateOnly: return "lock.fill"
        case .friendsOnly: return "person.2.fill"
        case .groupOnly: return "person.3.fill"
        case .coachOnly: return "figure.run"
        case .publicFeed: return "globe"
        }
    }
}

/// Real-time metrics for any workout with privacy controls
struct WorkoutMetrics: Codable, Identifiable {
    let id: String
    
    // Core identification
    let workoutID: String        // Links to private Workout record
    let userID: String           // User sharing these metrics
    let creationDate: Date
    
    // Context
    let workoutType: String      // "running", "cycling", etc.
    let groupWorkoutID: String?  // Set if group workout
    
    // Privacy control
    let sharingLevel: String     // WorkoutSharingLevel.rawValue
    let expiredTimestamp: Date?  // Auto-delete after this time
    let allowedUserIDs: [String]? // Specific users who can see (for coach/custom)
    
    // Real-time metrics (all optional based on privacy settings)
    let heartRate: Double?
    let activeEnergyBurned: Double?
    let distance: Double?
    let pace: Double?
    let cadence: Double?
    let power: Double?
    let altitude: Double?
    let speed: Double?
    
    // Workout progress
    let elapsedTime: TimeInterval
    let isActive: Bool
    let isPaused: Bool
    
    // Device & location info
    let sourceDevice: String
    let locationLatitude: Double?    // Only shared if user allows
    let locationLongitude: Double?
    
    // User display info (cached for performance)
    let username: String?
    let userImageURL: String?
    
    init(
        id: String = UUID().uuidString,
        workoutID: String,
        userID: String,
        creationDate: Date = Date(),
        workoutType: String,
        groupWorkoutID: String? = nil,
        sharingLevel: WorkoutSharingLevel = .privateOnly,
        expiredTimestamp: Date? = nil,
        allowedUserIDs: [String]? = nil,
        heartRate: Double? = nil,
        activeEnergyBurned: Double? = nil,
        distance: Double? = nil,
        pace: Double? = nil,
        cadence: Double? = nil,
        power: Double? = nil,
        altitude: Double? = nil,
        speed: Double? = nil,
        elapsedTime: TimeInterval,
        isActive: Bool = true,
        isPaused: Bool = false,
        sourceDevice: String = "Apple Watch",
        locationLatitude: Double? = nil,
        locationLongitude: Double? = nil,
        username: String? = nil,
        userImageURL: String? = nil
    ) {
        self.id = id
        self.workoutID = workoutID
        self.userID = userID
        self.creationDate = creationDate
        self.workoutType = workoutType
        self.groupWorkoutID = groupWorkoutID
        self.sharingLevel = sharingLevel.rawValue
        self.expiredTimestamp = expiredTimestamp ?? Date().addingTimeInterval(86400) // Default 24h expiry
        self.allowedUserIDs = allowedUserIDs
        self.heartRate = heartRate
        self.activeEnergyBurned = activeEnergyBurned
        self.distance = distance
        self.pace = pace
        self.cadence = cadence
        self.power = power
        self.altitude = altitude
        self.speed = speed
        self.elapsedTime = elapsedTime
        self.isActive = isActive
        self.isPaused = isPaused
        self.sourceDevice = sourceDevice
        self.locationLatitude = locationLatitude
        self.locationLongitude = locationLongitude
        self.username = username
        self.userImageURL = userImageURL
    }
}

// MARK: - CloudKit Conversion

extension WorkoutMetrics {
    init?(from record: CKRecord) {
        guard record.recordType == "WorkoutMetrics",
              let workoutID = record["workoutID"] as? String,
              let userID = record["userID"] as? String,
              let creationDate = record.creationDate,
              let workoutType = record["workoutType"] as? String,
              let sharingLevel = record["sharingLevel"] as? String,
              let elapsedTime = record["elapsedTime"] as? Double else {
            return nil
        }
        
        self.id = record.recordID.recordName
        self.workoutID = workoutID
        self.userID = userID
        self.creationDate = creationDate
        self.workoutType = workoutType
        self.groupWorkoutID = record["groupWorkoutID"] as? String
        self.sharingLevel = sharingLevel
        self.expiredTimestamp = record["expiredTimestamp"] as? Date
        self.allowedUserIDs = record["allowedUserIDs"] as? [String]
        
        // Metrics
        self.heartRate = record["heartRate"] as? Double
        self.activeEnergyBurned = record["activeEnergyBurned"] as? Double
        self.distance = record["distance"] as? Double
        self.pace = record["pace"] as? Double
        self.cadence = record["cadence"] as? Double
        self.power = record["power"] as? Double
        self.altitude = record["altitude"] as? Double
        self.speed = record["speed"] as? Double
        
        // Status
        self.elapsedTime = elapsedTime
        self.isActive = (record["isActive"] as? Int64 ?? 1) != 0
        self.isPaused = (record["isPaused"] as? Int64 ?? 0) != 0
        
        // Device & User info
        self.sourceDevice = record["sourceDevice"] as? String ?? "Apple Watch"
        if let loc = record["location"] as? CLLocation {
            self.locationLatitude = loc.coordinate.latitude
            self.locationLongitude = loc.coordinate.longitude
        } else {
            self.locationLatitude = nil
            self.locationLongitude = nil
        }
        self.username = record["username"] as? String
        self.userImageURL = record["userImageURL"] as? String
    }
    
    func toCKRecord() -> CKRecord {
        let record = CKRecord(recordType: "WorkoutMetrics", recordID: CKRecord.ID(recordName: id))
        
        // Core fields
        record["workoutID"] = workoutID
        record["userID"] = userID
        
        record["workoutType"] = workoutType
        
        // Context
        record["groupWorkoutID"] = groupWorkoutID
        
        // Privacy
        record["sharingLevel"] = sharingLevel
        record["expiredTimestamp"] = expiredTimestamp
        record["allowedUserIDs"] = allowedUserIDs
        
        // Metrics (only include non-nil values)
        record["heartRate"] = heartRate
        record["activeEnergyBurned"] = activeEnergyBurned
        record["distance"] = distance
        record["pace"] = pace
        record["cadence"] = cadence
        record["power"] = power
        record["altitude"] = altitude
        record["speed"] = speed
        
        // Status
        record["elapsedTime"] = elapsedTime
        record["isActive"] = isActive ? Int64(1) : Int64(0)
        record["isPaused"] = isPaused ? Int64(1) : Int64(0)
        
        // Device & User info
        record["sourceDevice"] = sourceDevice
        if let lat = locationLatitude, let long = locationLongitude {
            record["location"] = CLLocation(latitude: lat, longitude: long)
        }
        record["username"] = username
        record["userImageURL"] = userImageURL
        
        return record
    }
}

// MARK: - Aggregated Metrics

/// Aggregated metrics for multiple workout participants
struct AggregatedWorkoutMetrics {
    let workoutID: String?        // Individual workout
    let groupWorkoutID: String?   // Group workout
    let creationDate: Date
    let participantCount: Int
    
    // Averages
    let averageHeartRate: Double?
    let averagePace: Double?
    let totalActiveEnergy: Double
    let totalDistance: Double
    
    // Individual participant metrics
    let participantMetrics: [String: WorkoutMetrics] // Key is userID
    
    // Leaderboard positions
    var distanceLeader: String? {
        participantMetrics.max(by: { ($0.value.distance ?? 0) < ($1.value.distance ?? 0) })?.key
    }
    
    var energyLeader: String? {
        participantMetrics
            .filter { $0.value.activeEnergyBurned != nil }
            .max(by: { $0.value.activeEnergyBurned! < $1.value.activeEnergyBurned! })?.key
    }
    
    var paceLeader: String? {
        // Lower pace is better (faster)
        participantMetrics
            .filter { $0.value.pace != nil }
            .min(by: { $0.value.pace! < $1.value.pace! })?.key
    }
}

// MARK: - Privacy Helpers

extension WorkoutMetrics {
    /// Check if a user can view these metrics
    func canBeViewedBy(userID: String, followingIDs: [String]? = nil, groupParticipantIDs: [String]? = nil) -> Bool {
        // Owner can always see their own metrics
        if self.userID == userID {
            return true
        }
        
        // Check sharing level
        switch WorkoutSharingLevel(rawValue: sharingLevel) {
        case .privateOnly:
            return false
            
        case .friendsOnly:
            return followingIDs?.contains(self.userID) ?? false
            
        case .groupOnly:
            guard groupWorkoutID != nil else { return false }
            return groupParticipantIDs?.contains(userID) ?? false
            
        case .coachOnly:
            return allowedUserIDs?.contains(userID) ?? false
            
        case .publicFeed:
            return true
            
        case .none:
            return false
        }
    }
    
    /// Filter metrics based on user's privacy settings
    func filteredForPrivacy(settings: WorkoutPrivacySettings) -> WorkoutMetrics {
        // For group workouts, show full data
        if groupWorkoutID != nil {
            return self
        }
        
        // For non-group workouts, filter based on privacy settings
        return WorkoutMetrics(
            id: id,
            workoutID: workoutID,
            userID: userID,
            creationDate: creationDate,
            workoutType: workoutType,
            groupWorkoutID: groupWorkoutID,
            sharingLevel: WorkoutSharingLevel(rawValue: sharingLevel) ?? .privateOnly,
            expiredTimestamp: expiredTimestamp,
            allowedUserIDs: allowedUserIDs,
            heartRate: settings.allowDataSharing ? heartRate : nil,
            activeEnergyBurned: settings.allowDataSharing ? activeEnergyBurned : nil,
            distance: settings.allowDataSharing ? distance : nil,
            pace: settings.allowDataSharing ? pace : nil,
            cadence: settings.allowDataSharing ? cadence : nil,
            power: settings.allowDataSharing ? power : nil,
            altitude: settings.allowDataSharing ? altitude : nil,
            speed: settings.allowDataSharing ? speed : nil,
            elapsedTime: elapsedTime,
            isActive: isActive,
            isPaused: isPaused,
            sourceDevice: sourceDevice,
            locationLatitude: settings.shareLocation ? locationLatitude : nil,
            locationLongitude: settings.shareLocation ? locationLongitude : nil,
            username: username,
            userImageURL: userImageURL
        )
    }
}


// MARK: - CloudKit Schema Documentation

/*
 CloudKit Record Type: WorkoutMetrics
 
 Core Fields:
 - workoutID (String) - Links to private Workout - QUERYABLE, SORTABLE
 - userID (String) - User sharing metrics - QUERYABLE
 - creationDate (Date/Time) - When recorded - QUERYABLE, SORTABLE
 - workoutType (String) - Type of workout - QUERYABLE
 
 Context Fields:
 - groupWorkoutID (String) - Group workout ID - QUERYABLE
 
 Privacy Fields:
 - sharingLevel (String) - Privacy level - QUERYABLE
 - expiredTimestamp (Date/Time) - Auto-delete time - QUERYABLE
 - allowedUserIDs ([String]) - Specific allowed users
 
 Metric Fields (all optional):
 - heartRate (Double) - Current BPM
 - activeEnergyBurned (Double) - Total calories - QUERYABLE
 - distance (Double) - Total meters - QUERYABLE
 - pace (Double) - Current pace
 - cadence (Double) - Steps/RPM
 - power (Double) - Watts
 - altitude (Double) - Elevation meters
 - speed (Double) - Current speed
 
 Status Fields:
 - elapsedTime (Double) - Workout duration - QUERYABLE
 - isActive (Int64) - 1 if active, 0 if ended
 - isPaused (Int64) - 1 if paused, 0 if running
 
 Device Fields:
 - sourceDevice (String) - Device type
 - location (Location) - GPS coordinates
 
 Cache Fields:
 - username (String) - Cached for performance
 - userImageURL (String) - Cached avatar URL
 
 Indexes Required:
 - workoutID_creationDate (QUERYABLE) - For workout timeline
 - userID_creationDate (QUERYABLE) - For user's metrics
 - groupWorkoutID_creationDate (QUERYABLE) - For group metrics
 - sharingLevel_creationDate (QUERYABLE) - For privacy queries
 - expiredTimestamp (QUERYABLE) - For cleanup queries
 - ___recordID (QUERYABLE) - System index
 
 Subscriptions:
 - Group workouts: Subscribe where groupWorkoutID matches
 - Friend activity: Subscribe where userID in following list
 */