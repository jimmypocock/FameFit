import Foundation
import HealthKit
#if !os(watchOS)
import CloudKit
#endif

struct Workout: Identifiable, Codable {
    let id: String
    let workoutType: String
    let startDate: Date
    let endDate: Date
    let duration: TimeInterval
    let totalEnergyBurned: Double
    let totalDistance: Double?
    let averageHeartRate: Double?
    let followersEarned: Int // Deprecated - use xpEarned
    let xpEarned: Int?
    let source: String
    let groupWorkoutID: String? // Reference to associated GroupWorkout if any

    // Computed property for backward compatibility
    var effectiveXPEarned: Int {
        xpEarned ?? followersEarned
    }

    // Custom decoding to handle missing xpEarned and groupWorkoutID
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        workoutType = try container.decode(String.self, forKey: .workoutType)
        startDate = try container.decode(Date.self, forKey: .startDate)
        endDate = try container.decode(Date.self, forKey: .endDate)
        duration = try container.decode(TimeInterval.self, forKey: .duration)
        totalEnergyBurned = try container.decode(Double.self, forKey: .totalEnergyBurned)
        totalDistance = try container.decodeIfPresent(Double.self, forKey: .totalDistance)
        averageHeartRate = try container.decodeIfPresent(Double.self, forKey: .averageHeartRate)
        followersEarned = try container.decode(Int.self, forKey: .followersEarned)
        xpEarned = try container.decodeIfPresent(Int.self, forKey: .xpEarned)
        source = try container.decode(String.self, forKey: .source)
        groupWorkoutID = try container.decodeIfPresent(String.self, forKey: .groupWorkoutID)
    }

    // Standard init
    init(
        id: String,
        workoutType: String,
        startDate: Date,
        endDate: Date,
        duration: TimeInterval,
        totalEnergyBurned: Double,
        totalDistance: Double?,
        averageHeartRate: Double?,
        followersEarned: Int,
        xpEarned: Int?,
        source: String,
        groupWorkoutID: String? = nil
    ) {
        self.id = id
        self.workoutType = workoutType
        self.startDate = startDate
        self.endDate = endDate
        self.duration = duration
        self.totalEnergyBurned = totalEnergyBurned
        self.totalDistance = totalDistance
        self.averageHeartRate = averageHeartRate
        self.followersEarned = followersEarned
        self.xpEarned = xpEarned
        self.source = source
        self.groupWorkoutID = groupWorkoutID
    }

    var formattedDuration: String {
        let minutes = Int(duration) / 60
        return "\(minutes) min"
    }

    var formattedCalories: String {
        "\(Int(totalEnergyBurned)) cal"
    }

    var formattedDistance: String? {
        guard let distance = totalDistance, distance > 0 else { return nil }
        let km = distance / 1_000
        return String(format: "%.2f km", km)
    }

    var workoutActivityType: HKWorkoutActivityType {
        HKWorkoutActivityType.from(storageKey: workoutType) ?? .other
    }
    
    var displayName: String {
        // Convert storage key back to display name for UI
        workoutActivityType.displayName
    }
    
    #if !os(watchOS)
    /// Convert this Workout to a CloudKit record for saving
    /// - Parameter userID: The CloudKit user ID (required for queries)
    /// - Returns: A CKRecord configured with all workout fields matching the CloudKit schema
    func toCKRecord(userID: String) -> CKRecord {
        let record = CKRecord(recordType: "Workouts")
        
        // Map to CloudKit schema fields (must match exactly)
        record["id"] = id  // Note: Schema uses "id" not "workoutID"
        record["userID"] = userID
        record["workoutType"] = workoutType
        record["startDate"] = startDate
        record["endDate"] = endDate
        record["duration"] = duration
        record["totalEnergyBurned"] = totalEnergyBurned
        record["totalDistance"] = totalDistance ?? 0.0
        record["averageHeartRate"] = averageHeartRate ?? 0.0
        record["followersEarned"] = Int64(followersEarned)
        record["xpEarned"] = Int64(xpEarned ?? followersEarned)
        record["source"] = source
        
        if let groupWorkoutID = groupWorkoutID {
            record["groupWorkoutID"] = groupWorkoutID
        }
        
        return record
    }
    #endif
}

extension Workout {
    #if !os(watchOS)
    /// Initialize a Workout from a CloudKit record
    /// - Parameter record: The CKRecord from CloudKit with Workouts record type
    init?(from record: CKRecord) {
        // Required fields - if any are missing, return nil
        guard let id = record["id"] as? String,  // Note: Schema uses "id" not "workoutID"
              let workoutType = record["workoutType"] as? String,
              let startDate = record["startDate"] as? Date,
              let endDate = record["endDate"] as? Date else {
            return nil
        }
        
        self.id = id
        self.workoutType = workoutType
        self.startDate = startDate
        self.endDate = endDate
        self.duration = record["duration"] as? TimeInterval ?? 0
        self.totalEnergyBurned = record["totalEnergyBurned"] as? Double ?? 0
        self.totalDistance = record["totalDistance"] as? Double
        self.averageHeartRate = record["averageHeartRate"] as? Double
        self.followersEarned = (record["followersEarned"] as? Int64).map { Int($0) } ?? 0
        self.xpEarned = (record["xpEarned"] as? Int64).map { Int($0) }
        self.source = record["source"] as? String ?? "Unknown"
        self.groupWorkoutID = record["groupWorkoutID"] as? String
    }
    #endif
    
    init(from workout: HKWorkout, followersEarned: Int = 5, xpEarned: Int? = nil, groupWorkoutID: String? = nil) {
        id = workout.uuid.uuidString
        // Use storageKey for consistency across the app (not displayName)
        workoutType = workout.workoutActivityType.storageKey
        startDate = workout.startDate
        endDate = workout.endDate
        duration = workout.duration
        self.xpEarned = xpEarned ?? followersEarned // Use provided XP or fallback to followers
        // Use the new iOS 18 API for getting statistics
        if let energyBurnedType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned),
           let energyBurned = workout.statistics(for: energyBurnedType)?.sumQuantity() {
            totalEnergyBurned = energyBurned.doubleValue(for: .kilocalorie())
        } else {
            totalEnergyBurned = 0
        }

        if let distanceType = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning),
           let distance = workout.statistics(for: distanceType)?.sumQuantity() {
            totalDistance = distance.doubleValue(for: .meter())
        } else {
            totalDistance = nil
        }
        averageHeartRate = workout.averageHeartRate?.doubleValue(for: .count().unitDivided(by: .minute()))
        self.followersEarned = followersEarned
        source = workout.sourceRevision.source.name
        // Extract groupWorkoutID from metadata if not explicitly provided
        if let providedGroupID = groupWorkoutID {
            self.groupWorkoutID = providedGroupID
        } else if let metadataGroupID = workout.metadata?["groupWorkoutID"] as? String {
            self.groupWorkoutID = metadataGroupID
        } else {
            self.groupWorkoutID = nil
        }
    }
}

extension HKWorkout {
    var averageHeartRate: HKQuantity? {
        statistics(for: HKQuantityType(.heartRate))?.averageQuantity()
    }
}
