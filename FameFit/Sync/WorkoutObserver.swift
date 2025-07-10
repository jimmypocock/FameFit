import Foundation
import HealthKit
import UserNotifications
import os.log

class WorkoutObserver: NSObject, ObservableObject, WorkoutObserving {
    private let healthKitService: HealthKitService
    private var observerQuery: HKObserverQuery?
    private weak var cloudKitManager: CloudKitManager?
    
    @Published var lastError: FameFitError?
    @Published var allWorkouts: [HKWorkout] = []
    @Published var todaysWorkouts: [HKWorkout] = []
    @Published var isAuthorized = false
    
    init(cloudKitManager: CloudKitManager, healthKitService: HealthKitService? = nil) {
        self.cloudKitManager = cloudKitManager
        self.healthKitService = healthKitService ?? RealHealthKitService()
        super.init()
        requestNotificationPermissions()
    }
    
    func startObservingWorkouts() {
        guard healthKitService.isHealthDataAvailable else {
            FameFitLogger.error("HealthKit not available")
            DispatchQueue.main.async {
                self.lastError = .healthKitNotAvailable
            }
            return
        }
        
        let workoutType = HKObjectType.workoutType()
        
        // First, catch up on any workouts we might have missed
        FameFitLogger.info("Starting workout observation - checking for missed workouts", category: FameFitLogger.workout)
        fetchLatestWorkout()
        
        observerQuery = healthKitService.startObservingWorkouts { [weak self] query, completionHandler, error in
            if let error = error {
                DispatchQueue.main.async {
                    self?.lastError = error.fameFitError
                }
                completionHandler?()
                return
            }
            
            FameFitLogger.debug("Observer query fired - checking for new workouts", category: FameFitLogger.workout)
            self?.fetchLatestWorkout()
            completionHandler?()
        }
        
        healthKitService.enableBackgroundDelivery { [weak self] success, error in
            if let error = error {
                DispatchQueue.main.async {
                    self?.lastError = error.fameFitError
                }
            } else if success {
                FameFitLogger.info("Background delivery enabled successfully", category: FameFitLogger.workout)
                DispatchQueue.main.async {
                    self?.lastError = nil
                }
            }
        }
    }
    
    func stopObservingWorkouts() {
        if let query = observerQuery {
            healthKitService.stop(query)
        }
    }
    
    func fetchLatestWorkout() {
        let workoutType = HKObjectType.workoutType()
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: true) // Changed to ascending to process oldest first
        let limit = 10 // Process up to 10 workouts at a time to avoid overload
        
        let lastProcessedKey = "LastProcessedWorkoutDate"
        let appInstallDateKey = "FameFitInstallDate"
        
        // Track app install date to avoid counting pre-install workouts
        if UserDefaults.standard.object(forKey: appInstallDateKey) == nil {
            UserDefaults.standard.set(Date(), forKey: appInstallDateKey)
            FameFitLogger.info("First launch - setting install date", category: FameFitLogger.app)
        }
        
        let appInstallDate = UserDefaults.standard.object(forKey: appInstallDateKey) as? Date ?? Date()
        let lastProcessedDate = UserDefaults.standard.object(forKey: lastProcessedKey) as? Date ?? appInstallDate
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .medium
        
        FameFitLogger.debug("App installed: \(dateFormatter.string(from: appInstallDate))", category: FameFitLogger.workout)
        FameFitLogger.debug("Checking for workouts after: \(dateFormatter.string(from: lastProcessedDate))", category: FameFitLogger.workout)
        FameFitLogger.debug("Current time: \(dateFormatter.string(from: Date()))", category: FameFitLogger.workout)
        
        let predicate = HKQuery.predicateForSamples(withStart: lastProcessedDate, end: Date(), options: .strictEndDate)
        
        // Use the healthKitService to fetch workouts with our custom predicate
        healthKitService.fetchWorkoutsWithPredicate(predicate, limit: limit, sortDescriptors: [sortDescriptor]) { [weak self] samples, error in
            if let error = error {
                DispatchQueue.main.async {
                    self?.lastError = error.fameFitError
                }
                return
            }
            
            guard let workouts = samples as? [HKWorkout], !workouts.isEmpty else {
                FameFitLogger.debug("No new workouts found in query results", category: FameFitLogger.workout)
                FameFitLogger.debug("Query returned \(samples?.count ?? 0) samples", category: FameFitLogger.workout)
                return
            }
            
            FameFitLogger.info("Found \(workouts.count) new workout(s) to process", category: FameFitLogger.workout)
            
            // Process all workouts found
            var latestEndDate = lastProcessedDate
            for workout in workouts {
                let endDate = workout.endDate
                if endDate > lastProcessedDate {
                    FameFitLogger.info("Processing workout: \(workout.workoutActivityType) ended at \(endDate)", category: FameFitLogger.workout)
                    self?.processCompletedWorkout(workout)
                    
                    // Track the latest end date
                    if endDate > latestEndDate {
                        latestEndDate = endDate
                    }
                }
            }
            
            // Update the last processed date to the latest workout's end date
            if latestEndDate > lastProcessedDate {
                UserDefaults.standard.set(latestEndDate, forKey: lastProcessedKey)
                FameFitLogger.debug("Updated last processed date to: \(latestEndDate)", category: FameFitLogger.workout)
            }
        }
    }
    
    private func processCompletedWorkout(_ workout: HKWorkout) {
        // Validate workout data
        guard workout.duration > 0,
              workout.duration < 86400, // Less than 24 hours
              workout.endDate > workout.startDate else {
            FameFitLogger.notice("Invalid workout data detected, skipping", category: FameFitLogger.workout)
            return
        }
        
        let workoutType = workout.workoutActivityType
        let duration = workout.duration / 60
        
        // Log workout info
        FameFitLogger.info("Processing workout: \(workoutType.name) - Duration: \(Int(duration)) min", category: FameFitLogger.workout)
        
        // Get energy burned using the new API
        var calories: Double = 0
        if let energyBurnedType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) {
            let energyBurned = workout.statistics(for: energyBurnedType)?.sumQuantity()
            calories = energyBurned?.doubleValue(for: .kilocalorie()) ?? 0
        }
        
        let character = FameFitCharacter.characterForWorkoutType(workoutType)
        
        FameFitLogger.info("Adding 5 followers for workout", category: FameFitLogger.workout)
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
        guard healthKitService.isHealthDataAvailable else {
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
        
        healthKitService.requestAuthorization { [weak self] success, error in
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
        healthKitService.fetchWorkouts(limit: 50) { [weak self] samples, error in
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
    }
}