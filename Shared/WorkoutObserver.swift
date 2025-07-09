import Foundation
import HealthKit
import UserNotifications

class WorkoutObserver: NSObject, ObservableObject, WorkoutObserving {
    private let healthStore = HKHealthStore()
    private var observerQuery: HKObserverQuery?
    private weak var cloudKitManager: CloudKitManager?
    
    @Published var lastError: FameFitError?
    @Published var allWorkouts: [HKWorkout] = []
    @Published var todaysWorkouts: [HKWorkout] = []
    @Published var isAuthorized = false
    
    init(cloudKitManager: CloudKitManager) {
        self.cloudKitManager = cloudKitManager
        super.init()
        requestNotificationPermissions()
    }
    
    func startObservingWorkouts() {
        guard HKHealthStore.isHealthDataAvailable() else {
            DispatchQueue.main.async {
                self.lastError = .healthKitNotAvailable
            }
            return
        }
        
        let workoutType = HKObjectType.workoutType()
        
        observerQuery = HKObserverQuery(sampleType: workoutType, predicate: nil) { [weak self] query, completionHandler, error in
            if let error = error {
                DispatchQueue.main.async {
                    self?.lastError = error.fameFitError
                }
                completionHandler()
                return
            }
            
            self?.fetchLatestWorkout()
            completionHandler()
        }
        
        if let query = observerQuery {
            healthStore.execute(query)
        }
        
        healthStore.enableBackgroundDelivery(for: workoutType, frequency: .immediate) { [weak self] success, error in
            if let error = error {
                DispatchQueue.main.async {
                    self?.lastError = error.fameFitError
                }
            } else if success {
                DispatchQueue.main.async {
                    self?.lastError = nil
                }
            }
        }
    }
    
    func stopObservingWorkouts() {
        if let query = observerQuery {
            healthStore.stop(query)
        }
    }
    
    private func fetchLatestWorkout() {
        let workoutType = HKObjectType.workoutType()
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let limit = 1
        
        let lastProcessedKey = "LastProcessedWorkoutDate"
        let lastProcessedDate = UserDefaults.standard.object(forKey: lastProcessedKey) as? Date ?? Date.distantPast
        
        let predicate = HKQuery.predicateForSamples(withStart: lastProcessedDate, end: Date(), options: .strictEndDate)
        
        let query = HKSampleQuery(sampleType: workoutType, predicate: predicate, limit: limit, sortDescriptors: [sortDescriptor]) { [weak self] query, samples, error in
            if let error = error {
                DispatchQueue.main.async {
                    self?.lastError = error.fameFitError
                }
                return
            }
            
            guard let workout = samples?.first as? HKWorkout else {
                return
            }
            
            
            let endDate = workout.endDate
            if endDate > lastProcessedDate {
                UserDefaults.standard.set(endDate, forKey: lastProcessedKey)
                self?.processCompletedWorkout(workout)
            }
        }
        
        healthStore.execute(query)
    }
    
    private func processCompletedWorkout(_ workout: HKWorkout) {
        let workoutType = workout.workoutActivityType
        let duration = workout.duration / 60
        
        // Get energy burned using the new API
        var calories: Double = 0
        if let energyBurnedType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) {
            let energyBurned = workout.statistics(for: energyBurnedType)?.sumQuantity()
            calories = energyBurned?.doubleValue(for: .kilocalorie()) ?? 0
        }
        
        let character = FameFitCharacter.characterForWorkoutType(workoutType)
        
        cloudKitManager?.addFollowers(5)
        
        sendWorkoutNotification(character: character, duration: Int(duration), calories: Int(calories))
    }
    
    private func requestNotificationPermissions() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { [weak self] granted, error in
            if let error = error {
                DispatchQueue.main.async {
                    self?.lastError = .unknownError(error)
                }
            } else if granted {
            } else {
            }
        }
    }
    
    private func sendWorkoutNotification(character: FameFitCharacter, duration: Int, calories: Int) {
        let content = UNMutableNotificationContent()
        content.title = "\(character.emoji) \(character.fullName)"
        content.body = character.workoutCompletionMessage(followers: 5)
        content.sound = .default
        content.badge = NSNumber(value: cloudKitManager?.followerCount ?? 0)
        
        content.userInfo = [
            "character": character.rawValue,
            "duration": duration,
            "calories": calories,
            "newFollowers": 5
        ]
        
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        
        UNUserNotificationCenter.current().add(request) { [weak self] error in
            if let error = error {
                DispatchQueue.main.async {
                    self?.lastError = .unknownError(error)
                }
            } else {
            }
        }
    }
    
    func requestHealthKitAuthorization(completion: @escaping (Bool, FameFitError?) -> Void) {
        guard HKHealthStore.isHealthDataAvailable() else {
            DispatchQueue.main.async {
                self.lastError = .healthKitNotAvailable
                completion(false, .healthKitNotAvailable)
            }
            return
        }
        
        var typesToRead: Set<HKObjectType> = [.workoutType()]
        
        if let activeEnergyType = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) {
            typesToRead.insert(activeEnergyType)
        }
        if let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate) {
            typesToRead.insert(heartRateType)
        }
        if let walkingRunningType = HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning) {
            typesToRead.insert(walkingRunningType)
        }
        if let cyclingType = HKObjectType.quantityType(forIdentifier: .distanceCycling) {
            typesToRead.insert(cyclingType)
        }
        
        healthStore.requestAuthorization(toShare: nil, read: typesToRead) { [weak self] success, error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.lastError = error.fameFitError
                    completion(false, error.fameFitError)
                } else if !success {
                    self?.lastError = .healthKitAuthorizationDenied
                    completion(false, .healthKitAuthorizationDenied)
                } else {
                    self?.isAuthorized = true
                    self?.lastError = nil
                    completion(true, nil)
                    self?.startObservingWorkouts()
                }
            }
        }
    }
    
    func fetchInitialWorkouts() {
        let workoutType = HKObjectType.workoutType()
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        let query = HKSampleQuery(
            sampleType: workoutType,
            predicate: nil,
            limit: 50,
            sortDescriptors: [sortDescriptor]
        ) { [weak self] _, samples, error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.lastError = error.fameFitError
                    return
                }
                
                guard let workouts = samples as? [HKWorkout] else { return }
                self?.allWorkouts = workouts
                
                // Filter today's workouts
                let calendar = Calendar.current
                let today = calendar.startOfDay(for: Date())
                self?.todaysWorkouts = workouts.filter { workout in
                    calendar.isDate(workout.startDate, inSameDayAs: today)
                }
            }
        }
        
        healthStore.execute(query)
    }
}