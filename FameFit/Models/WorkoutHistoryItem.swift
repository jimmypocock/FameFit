import Foundation
import HealthKit

struct WorkoutHistoryItem: Identifiable, Codable {
    let id: UUID
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

    // Computed property for backward compatibility
    var effectiveXPEarned: Int {
        xpEarned ?? followersEarned
    }

    // Custom decoding to handle missing xpEarned
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
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
    }

    // Standard init
    init(
        id: UUID,
        workoutType: String,
        startDate: Date,
        endDate: Date,
        duration: TimeInterval,
        totalEnergyBurned: Double,
        totalDistance: Double?,
        averageHeartRate: Double?,
        followersEarned: Int,
        xpEarned: Int?,
        source: String
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
}

extension WorkoutHistoryItem {
    init(from workout: HKWorkout, followersEarned: Int = 5, xpEarned: Int? = nil) {
        id = UUID()
        workoutType = workout.workoutActivityType.displayName
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
    }
}

extension HKWorkout {
    var averageHeartRate: HKQuantity? {
        statistics(for: HKQuantityType(.heartRate))?.averageQuantity()
    }
}
