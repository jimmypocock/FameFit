import Foundation
import HealthKit

/// Protocol defining all HealthKit operations used by FameFit
/// This allows for easy mocking and testing
protocol HealthKitService {
    /// Check if HealthKit is available on this device
    var isHealthDataAvailable: Bool { get }
    
    /// Request authorization for required HealthKit types
    func requestAuthorization(completion: @escaping (Bool, Error?) -> Void)
    
    /// Check authorization status for a specific type
    func authorizationStatus(for type: HKObjectType) -> HKAuthorizationStatus
    
    /// Start observing for new workouts
    func startObservingWorkouts(
        updateHandler: @escaping (HKObserverQuery, HKObserverQueryCompletionHandler?, Error?) -> Void
    ) -> HKObserverQuery?
    
    /// Stop a specific query
    func stop(_ query: HKQuery)
    
    /// Enable background delivery for workout updates
    func enableBackgroundDelivery(completion: @escaping (Bool, Error?) -> Void)
    
    /// Fetch recent workouts
    func fetchWorkouts(
        limit: Int,
        completion: @escaping ([HKSample]?, Error?) -> Void
    )
    
    /// Fetch workouts with custom predicate and sort descriptors
    func fetchWorkoutsWithPredicate(
        _ predicate: NSPredicate?,
        limit: Int,
        sortDescriptors: [NSSortDescriptor],
        completion: @escaping ([HKSample]?, Error?) -> Void
    )
    
    /// Save a workout
    func save(_ workout: HKWorkout, completion: @escaping (Bool, Error?) -> Void)
    
    /// Create a workout session (Watch only)
    func createWorkoutSession(
        configuration: HKWorkoutConfiguration
    ) -> HKWorkoutSession?
}

/// Extension to define the types we need authorization for
extension HealthKitService {
    static var workoutType: HKObjectType {
        return HKObjectType.workoutType()
    }
    
    static var heartRateType: HKQuantityType {
        return HKQuantityType.quantityType(forIdentifier: .heartRate)!
    }
    
    static var activeEnergyType: HKQuantityType {
        return HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!
    }
    
    static var distanceType: HKQuantityType {
        return HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)!
    }
    
    static var readTypes: Set<HKObjectType> {
        return [
            workoutType,
            heartRateType,
            activeEnergyType,
            distanceType,
            HKObjectType.activitySummaryType()
        ]
    }
    
    static var shareTypes: Set<HKSampleType> {
        return [
            HKObjectType.workoutType(),
            heartRateType,
            activeEnergyType,
            distanceType
        ]
    }
}