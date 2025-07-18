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
    let followersEarned: Int
    let source: String
    
    var formattedDuration: String {
        let minutes = Int(duration) / 60
        return "\(minutes) min"
    }
    
    var formattedCalories: String {
        return "\(Int(totalEnergyBurned)) cal"
    }
    
    var formattedDistance: String? {
        guard let distance = totalDistance, distance > 0 else { return nil }
        let km = distance / 1000
        return String(format: "%.2f km", km)
    }
    
    var workoutActivityType: HKWorkoutActivityType {
        HKWorkoutActivityType.from(name: workoutType)
    }
}

extension WorkoutHistoryItem {
    init(from workout: HKWorkout, followersEarned: Int = 5) {
        self.id = UUID()
        self.workoutType = workout.workoutActivityType.name
        self.startDate = workout.startDate
        self.endDate = workout.endDate
        self.duration = workout.duration
        // Use the new iOS 18 API for getting statistics
        if let energyBurnedType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned),
           let energyBurned = workout.statistics(for: energyBurnedType)?.sumQuantity() {
            self.totalEnergyBurned = energyBurned.doubleValue(for: .kilocalorie())
        } else {
            self.totalEnergyBurned = 0
        }
        
        if let distanceType = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning),
           let distance = workout.statistics(for: distanceType)?.sumQuantity() {
            self.totalDistance = distance.doubleValue(for: .meter())
        } else {
            self.totalDistance = nil
        }
        self.averageHeartRate = workout.averageHeartRate?.doubleValue(for: .count().unitDivided(by: .minute()))
        self.followersEarned = followersEarned
        self.source = workout.sourceRevision.source.name
    }
}

extension HKWorkout {
    var averageHeartRate: HKQuantity? {
        return statistics(for: HKQuantityType(.heartRate))?.averageQuantity()
    }
}