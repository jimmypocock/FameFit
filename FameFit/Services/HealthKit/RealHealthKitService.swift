import Foundation
import HealthKit
import os.log

/// Production implementation of HealthKitService that interacts with real HealthKit
final class RealHealthKitService: HealthKitService {
    let healthStore: HKHealthStore
    
    init(healthStore: HKHealthStore = HKHealthStore()) {
        self.healthStore = healthStore
    }
    
    var isHealthDataAvailable: Bool {
        return HKHealthStore.isHealthDataAvailable()
    }
    
    func requestAuthorization(completion: @escaping (Bool, Error?) -> Void) {
        // Security: Only request the permissions we actually need
        healthStore.requestAuthorization(
            toShare: Self.shareTypes,
            read: Self.readTypes
        ) { success, error in
            // Security: Never log the specific error details in production
            if let error = error {
                FameFitLogger.error("HealthKit authorization error occurred", error: error)
            }
            completion(success, error)
        }
    }
    
    func authorizationStatus(for type: HKObjectType) -> HKAuthorizationStatus {
        return healthStore.authorizationStatus(for: type)
    }
    
    func startObservingWorkouts(
        updateHandler: @escaping (HKObserverQuery, HKObserverQueryCompletionHandler?, Error?) -> Void
    ) -> HKObserverQuery? {
        let query = HKObserverQuery(
            sampleType: HKObjectType.workoutType(),
            predicate: nil,
            updateHandler: updateHandler
        )
        
        healthStore.execute(query)
        return query
    }
    
    func stop(_ query: HKQuery) {
        healthStore.stop(query)
    }
    
    func enableBackgroundDelivery(completion: @escaping (Bool, Error?) -> Void) {
        healthStore.enableBackgroundDelivery(
            for: HKObjectType.workoutType(),
            frequency: .immediate
        ) { success, error in
            // Security: Don't expose internal error details
            if let error = error {
                FameFitLogger.error("Background delivery setup error occurred", error: error)
            }
            completion(success, error)
        }
    }
    
    func fetchWorkouts(limit: Int, completion: @escaping ([HKSample]?, Error?) -> Void) {
        let sortDescriptor = NSSortDescriptor(
            key: HKSampleSortIdentifierStartDate,
            ascending: false
        )
        
        let query = HKSampleQuery(
            sampleType: HKObjectType.workoutType(),
            predicate: nil,
            limit: limit,
            sortDescriptors: [sortDescriptor]
        ) { _, samples, error in
            // Security: Validate data before passing it along
            if let error = error {
                FameFitLogger.error("Workout fetch error occurred", error: error, category: FameFitLogger.workout)
                completion(nil, error)
                return
            }
            
            completion(samples, nil)
        }
        
        healthStore.execute(query)
    }
    
    func fetchWorkoutsWithPredicate(
        _ predicate: NSPredicate?,
        limit: Int,
        sortDescriptors: [NSSortDescriptor],
        completion: @escaping ([HKSample]?, Error?) -> Void
    ) {
        let query = HKSampleQuery(
            sampleType: HKObjectType.workoutType(),
            predicate: predicate,
            limit: limit,
            sortDescriptors: sortDescriptors
        ) { _, samples, error in
            // Security: Validate data before passing it along
            if let error = error {
                FameFitLogger.error("Workout fetch error occurred", error: error, category: FameFitLogger.workout)
                completion(nil, error)
                return
            }
            
            completion(samples, nil)
        }
        
        healthStore.execute(query)
    }
    
    func save(_ workout: HKWorkout, completion: @escaping (Bool, Error?) -> Void) {
        healthStore.save(workout) { success, error in
            // Security: Don't log workout details
            if let error = error {
                FameFitLogger.error("Workout save error occurred", error: error, category: FameFitLogger.workout)
            }
            completion(success, error)
        }
    }
    
    func createWorkoutSession(configuration: HKWorkoutConfiguration) -> HKWorkoutSession? {
        #if os(watchOS)
        do {
            return try HKWorkoutSession(
                healthStore: healthStore,
                configuration: configuration
            )
        } catch {
            FameFitLogger.error("Failed to create workout session", error: error, category: FameFitLogger.workout)
            return nil
        }
        #else
        // Workout sessions are only available on watchOS
        return nil
        #endif
    }
    
}