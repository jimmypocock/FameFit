import Foundation
import HealthKit
@testable import FameFit

/// Mock implementation of HealthKitService for testing
final class MockHealthKitService: HealthKitService {
    // MARK: - Mock Control Properties
    
    var isHealthDataAvailableValue = true
    var authorizationSuccess = true
    var authorizationError: Error?
    var authorizationStatusValue: HKAuthorizationStatus = .sharingAuthorized
    var savedWorkouts: [HKWorkout] = []
    var mockWorkouts: [HKSample] = []
    var activeQueries: [HKQuery] = []
    var backgroundDeliveryEnabled = false
    var anchoredQueryStarted = false
    var lastUsedAnchor: HKQueryAnchor?
    
    // MARK: - Tracking Properties
    
    var requestAuthorizationCalled = false
    var startObservingWorkoutsCalled = false
    var fetchWorkoutsCalled = false
    var saveWorkoutCalled = false
    var enableBackgroundDeliveryCalled = false
    
    // MARK: - Callback Storage
    
    var workoutUpdateHandler: ((HKObserverQuery, HKObserverQueryCompletionHandler?, Error?) -> Void)?
    var anchoredQueryHandler: ((HKAnchoredObjectQuery, [HKSample]?, [HKDeletedObject]?, HKQueryAnchor?, Error?) -> Void)?
    var anchoredQueryUpdateHandler: ((HKAnchoredObjectQuery, [HKSample]?, [HKDeletedObject]?, HKQueryAnchor?, Error?) -> Void)?
    var anchoredQueryInitialHandler: ((HKAnchoredObjectQuery, [HKSample]?, [HKDeletedObject]?, HKQueryAnchor?, Error?) -> Void)?
    
    // MARK: - HealthKitService Implementation
    
    var isHealthDataAvailable: Bool {
        get {
            return isHealthDataAvailableValue
        }
        set {
            isHealthDataAvailableValue = newValue
        }
    }
    
    func requestAuthorization(completion: @escaping (Bool, Error?) -> Void) {
        requestAuthorizationCalled = true
        
        DispatchQueue.main.async {
            if let error = self.authorizationError {
                completion(false, error)
            } else {
                completion(self.authorizationSuccess, nil)
            }
        }
    }
    
    func authorizationStatus(for type: HKObjectType) -> HKAuthorizationStatus {
        return authorizationStatusValue
    }
    
    func startObservingWorkouts(
        updateHandler: @escaping (HKObserverQuery, HKObserverQueryCompletionHandler?, Error?) -> Void
    ) -> HKObserverQuery? {
        startObservingWorkoutsCalled = true
        self.workoutUpdateHandler = updateHandler
        
        // Create a mock query
        let query = HKObserverQuery(
            sampleType: HKObjectType.workoutType(),
            predicate: nil
        ) { _, _, _ in }
        
        activeQueries.append(query)
        
        // Don't fire immediately - tests will manually trigger using triggerWorkoutObserver()
        
        return query
    }
    
    func stop(_ query: HKQuery) {
        activeQueries.removeAll { $0 === query }
    }
    
    func enableBackgroundDelivery(completion: @escaping (Bool, Error?) -> Void) {
        enableBackgroundDeliveryCalled = true
        backgroundDeliveryEnabled = true
        
        DispatchQueue.main.async {
            completion(true, nil)
        }
    }
    
    func fetchWorkouts(limit: Int, completion: @escaping ([HKSample]?, Error?) -> Void) {
        fetchWorkoutsCalled = true
        
        DispatchQueue.main.async {
            let workoutsToReturn = Array(self.mockWorkouts.prefix(limit))
            completion(workoutsToReturn, nil)
        }
    }
    
    func fetchWorkoutsWithPredicate(
        _ predicate: NSPredicate?,
        limit: Int,
        sortDescriptors: [NSSortDescriptor],
        completion: @escaping ([HKSample]?, Error?) -> Void
    ) {
        fetchWorkoutsCalled = true
        
        DispatchQueue.main.async {
            var workoutsToReturn = self.mockWorkouts
            
            // Apply predicate if provided
            if let predicate = predicate {
                // Handle HKQuery date predicates for testing
                // HKQuery.predicateForSamples returns a predicate with format like:
                // "startDate >= CAST(123456789, \"NSDate\") AND endDate <= CAST(123456789, \"NSDate\")"
                
                // For testing, we'll parse common date predicates
                let predicateString = predicate.description
                
                // Extract date boundaries if this is a date range predicate
                if predicateString.contains("startDate") || predicateString.contains("endDate") {
                    // Filter workouts based on their end date
                    workoutsToReturn = workoutsToReturn.compactMap { sample -> HKSample? in
                        guard let workout = sample as? HKWorkout else { return nil }
                        
                        // Check if we can extract date from predicate string
                        // For now, we'll use a simpler approach: check UserDefaults
                        let lastProcessedKey = UserDefaultsKeys.lastProcessedWorkoutDate
                        let appInstallDateKey = UserDefaultsKeys.appInstallDate
                        
                        let appInstallDate = UserDefaults.standard.object(forKey: appInstallDateKey) as? Date ?? Date.distantPast
                        let lastProcessedDate = UserDefaults.standard.object(forKey: lastProcessedKey) as? Date ?? appInstallDate
                        let startDate = max(lastProcessedDate, appInstallDate)
                        
                        // Only return workouts after the start date
                        if workout.endDate > startDate {
                            // Including workout
                            return workout
                        }
                        // Filtering out workout
                        return nil
                    }
                    
                    // Filtering complete
                }
            }
            
            // Apply sort descriptors
            if !sortDescriptors.isEmpty {
                workoutsToReturn = (workoutsToReturn as NSArray).sortedArray(using: sortDescriptors) as? [HKSample] ?? []
            }
            
            // Apply limit
            workoutsToReturn = Array(workoutsToReturn.prefix(limit))
            
            completion(workoutsToReturn, nil)
        }
    }
    
    func save(_ workout: HKWorkout, completion: @escaping (Bool, Error?) -> Void) {
        saveWorkoutCalled = true
        savedWorkouts.append(workout)
        
        DispatchQueue.main.async {
            completion(true, nil)
        }
    }
    
    func createWorkoutSession(configuration: HKWorkoutConfiguration) -> HKWorkoutSession? {
        // Return nil for iOS tests (sessions only work on watchOS)
        return nil
    }
    
    #if os(watchOS)
    func createWorkoutBuilder(
        healthStore: HKHealthStore,
        configuration: HKWorkoutConfiguration
    ) -> HKLiveWorkoutBuilder {
        // Return a real builder for now (we'd need to mock this too for full testing)
        return HKLiveWorkoutBuilder(
            healthStore: healthStore,
            configuration: configuration,
            device: .local()
        )
    }
    #endif
    
    // MARK: - Test Helper Methods
    
    func reset() {
        isHealthDataAvailableValue = true
        authorizationSuccess = true
        authorizationError = nil
        authorizationStatusValue = .sharingAuthorized
        savedWorkouts.removeAll()
        mockWorkouts.removeAll()
        activeQueries.removeAll()
        backgroundDeliveryEnabled = false
        
        requestAuthorizationCalled = false
        startObservingWorkoutsCalled = false
        fetchWorkoutsCalled = false
        saveWorkoutCalled = false
        enableBackgroundDeliveryCalled = false
        
        workoutUpdateHandler = nil
        anchoredQueryHandler = nil
        anchoredQueryUpdateHandler = nil
        anchoredQueryInitialHandler = nil
    }
    
    /// Manually trigger the workout observer for testing
    func triggerWorkoutObserver() {
        if let handler = workoutUpdateHandler,
           let query = activeQueries.first as? HKObserverQuery {
            DispatchQueue.main.async {
                handler(query, { }, nil)
            }
        }
    }
    
    func simulateNewWorkout(_ workout: HKWorkout) {
        mockWorkouts.insert(workout, at: 0)
        
        // Trigger any active observer queries
        if let handler = workoutUpdateHandler,
           let query = activeQueries.first(where: { $0 is HKObserverQuery }) as? HKObserverQuery {
            DispatchQueue.main.async {
                handler(query, { }, nil)
            }
        }
    }
    
    func simulateAuthorizationDenied() {
        authorizationStatusValue = .sharingDenied
        authorizationSuccess = false
        authorizationError = NSError(
            domain: "HealthKit",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "User denied authorization"]
        )
    }
    
    func simulateHealthKitNotAvailable() {
        isHealthDataAvailableValue = false
    }
    
    func executeAnchoredQuery(
        anchor: HKQueryAnchor?,
        initialHandler: @escaping (HKAnchoredObjectQuery, [HKSample]?, [HKDeletedObject]?, HKQueryAnchor?, Error?) -> Void,
        updateHandler: @escaping (HKAnchoredObjectQuery, [HKSample]?, [HKDeletedObject]?, HKQueryAnchor?, Error?) -> Void
    ) -> HKAnchoredObjectQuery {
        anchoredQueryStarted = true
        lastUsedAnchor = anchor
        
        // Store handlers for testing
        self.anchoredQueryInitialHandler = initialHandler
        self.anchoredQueryUpdateHandler = updateHandler
        
        // Create a mock query
        let query = HKAnchoredObjectQuery(
            type: HKObjectType.workoutType(),
            predicate: nil,
            anchor: anchor,
            limit: HKObjectQueryNoLimit
        ) { _, _, _, _, _ in }
        
        activeQueries.append(query)
        
        // Don't fire immediately - tests will manually trigger
        return query
    }
    
    // MARK: - Anchored Query Simulation Methods
    
    /// Simulates initial anchored query results
    func simulateInitialAnchoredQueryResults(workouts: [HKWorkout]) {
        guard let handler = anchoredQueryInitialHandler,
              let query = activeQueries.first(where: { $0 is HKAnchoredObjectQuery }) as? HKAnchoredObjectQuery else {
            return
        }
        
        // Pass nil for anchor since we can't instantiate HKQueryAnchor in tests
        DispatchQueue.main.async {
            handler(query, workouts, nil, nil, nil)
        }
    }
    
    /// Simulates incremental anchored query results
    func simulateIncrementalAnchoredQueryResults(workouts: [HKWorkout]) {
        guard let handler = anchoredQueryUpdateHandler,
              let query = activeQueries.first(where: { $0 is HKAnchoredObjectQuery }) as? HKAnchoredObjectQuery else {
            return
        }
        
        DispatchQueue.main.async {
            handler(query, workouts, nil, nil, nil)
        }
    }
    
    /// Simulates anchored query results (defaults to incremental)
    func simulateAnchoredQueryResults(workouts: [HKWorkout]) {
        simulateIncrementalAnchoredQueryResults(workouts: workouts)
    }
}