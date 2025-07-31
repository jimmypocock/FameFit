import Combine
import Foundation
import HealthKit
import os.log
import UserNotifications

class WorkoutObserver: NSObject, ObservableObject, WorkoutObserving {
    private let healthKitService: HealthKitService
    private var observerQuery: HKObserverQuery?
    private weak var cloudKitManager: CloudKitManager?
    weak var notificationStore: (any NotificationStoring)?
    weak var apnsManager: (any APNSManaging)?
    private var preferences: NotificationPreferences = .load()

    @Published var lastError: FameFitError?
    @Published var allWorkouts: [HKWorkout] = []
    @Published var todaysWorkouts: [HKWorkout] = []
    @Published var isAuthorized = false

    private var lastNotificationDate: Date?
    private let notificationThrottleInterval: TimeInterval = 300 // 5 minutes between notifications

    // Publisher for workout completion events (for sharing prompt)
    private let workoutCompletedSubject = PassthroughSubject<Workout, Never>()
    var workoutCompletedPublisher: AnyPublisher<Workout, Never> {
        workoutCompletedSubject.eraseToAnyPublisher()
    }

    init(cloudKitManager: CloudKitManager, healthKitService: HealthKitService? = nil) {
        self.cloudKitManager = cloudKitManager
        self.healthKitService = healthKitService ?? RealHealthKitService()
        super.init()
        requestNotificationPermissions()
    }

    func updatePreferences(_ newPreferences: NotificationPreferences) {
        preferences = newPreferences
    }

    func startObservingWorkouts() {
        guard healthKitService.isHealthDataAvailable else {
            FameFitLogger.error("HealthKit not available")
            DispatchQueue.main.async {
                self.lastError = .healthKitNotAvailable
            }
            return
        }

        _ = HKObjectType.workoutType()

        // First, catch up on any workouts we might have missed
        FameFitLogger.info(
            "Starting workout observation - checking for missed workouts",
            category: FameFitLogger.workout
        )
        fetchLatestWorkout()

        observerQuery = healthKitService.startObservingWorkouts { [weak self] _, completionHandler, error in
            if let error {
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
            if let error {
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
        _ = HKObjectType.workoutType()
        let sortDescriptor = NSSortDescriptor(
            key: HKSampleSortIdentifierEndDate,
            ascending: true
        ) // Changed to ascending to process oldest first
        let limit = 10 // Process up to 10 workouts at a time to avoid overload

        let lastProcessedKey = UserDefaultsKeys.lastProcessedWorkoutDate
        let appInstallDateKey = UserDefaultsKeys.appInstallDate

        // Track app install date to avoid counting pre-install workouts
        if UserDefaults.standard.object(forKey: appInstallDateKey) == nil {
            UserDefaults.standard.set(Date(), forKey: appInstallDateKey)
            FameFitLogger.info("First launch - setting install date", category: FameFitLogger.app)
        }

        let appInstallDate = UserDefaults.standard.object(forKey: appInstallDateKey) as? Date ?? Date()
        let lastProcessedDate = UserDefaults.standard.object(forKey: lastProcessedKey) as? Date ?? appInstallDate

        // Ensure we're using the later of the two dates
        let startDate = max(lastProcessedDate, appInstallDate)

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .medium

        FameFitLogger.debug(
            "App installed: \(dateFormatter.string(from: appInstallDate))",
            category: FameFitLogger.workout
        )
        FameFitLogger.debug(
            "Checking for workouts after: \(dateFormatter.string(from: lastProcessedDate))",
            category: FameFitLogger.workout
        )
        FameFitLogger.debug("Current time: \(dateFormatter.string(from: Date()))", category: FameFitLogger.workout)

        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: Date(), options: .strictEndDate)

        // Use the healthKitService to fetch workouts with our custom predicate
        healthKitService
            .fetchWorkoutsWithPredicate(
                predicate,
                limit: limit,
                sortDescriptors: [sortDescriptor]
            ) { [weak self] samples, error in
                if let error {
                    DispatchQueue.main.async {
                        self?.lastError = error.fameFitError
                    }
                    return
                }

                guard let workouts = samples as? [HKWorkout], !workouts.isEmpty else {
                    FameFitLogger.debug("No new workouts found in query results", category: FameFitLogger.workout)
                    FameFitLogger.debug(
                        "Query returned \(samples?.count ?? 0) samples",
                        category: FameFitLogger.workout
                    )
                    // No workouts to process
                    return
                }

                FameFitLogger.info("Found \(workouts.count) new workout(s) to process", category: FameFitLogger.workout)
                // Processing workouts

                // Process all workouts found
                var latestEndDate = lastProcessedDate
                for workout in workouts {
                    let endDate = workout.endDate
                    FameFitLogger.info(
                        "Processing workout: \(workout.workoutActivityType) ended at \(endDate)",
                        category: FameFitLogger.workout
                    )
                    self?.processCompletedWorkout(workout)

                    // Track the latest end date
                    if endDate > latestEndDate {
                        latestEndDate = endDate
                    }
                }

                // Update the last processed date to the latest workout's end date
                if latestEndDate > lastProcessedDate {
                    UserDefaults.standard.set(latestEndDate, forKey: lastProcessedKey)
                    // UserDefaults automatically synchronizes
                    FameFitLogger.debug(
                        "Updated last processed date to: \(latestEndDate)",
                        category: FameFitLogger.workout
                    )
                    // Saved last processed date
                }
            }
    }

    private func processCompletedWorkout(_ workout: HKWorkout) {
        // Validate workout data
        guard workout.duration > 0,
              workout.duration < 86_400, // Less than 24 hours
              workout.endDate > workout.startDate
        else {
            FameFitLogger.notice("Invalid workout data detected, skipping", category: FameFitLogger.workout)
            return
        }

        let workoutType = workout.workoutActivityType
        let duration = workout.duration / 60

        // Log workout info
        FameFitLogger.info(
            "Processing workout: \(workoutType.displayName) - Duration: \(Int(duration)) min",
            category: FameFitLogger.workout
        )

        // Get energy burned using the new API
        var calories: Double = 0
        if let energyBurnedType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) {
            let energyBurned = workout.statistics(for: energyBurnedType)?.sumQuantity()
            calories = energyBurned?.doubleValue(for: .kilocalorie()) ?? 0
        }

        // Create workout history item (includes average heart rate from workout)
        let historyItem = Workout(from: workout, followersEarned: 0)

        // Calculate XP using the XPCalculator
        let currentStreak = cloudKitManager?.currentStreak ?? 0
        var calculatedXP = XPCalculator.calculateXP(
            for: historyItem,
            currentStreak: currentStreak
        )

        // Check for special bonuses (first workout, milestones, etc.)
        let workoutCount = (cloudKitManager?.totalWorkouts ?? 0) + 1
        let bonusXP = XPCalculator.calculateSpecialBonus(
            workoutNumber: workoutCount,
            isPersonalRecord: false // Could implement PR detection later
        )
        calculatedXP += bonusXP

        let character = FameFitCharacter.characterForWorkoutType(workoutType)

        FameFitLogger.info(
            "Adding \(calculatedXP) XP for workout (base + \(bonusXP) bonus)",
            category: FameFitLogger.workout
        )
        // Add XP for completed workout
        cloudKitManager?.addXP(calculatedXP)

        // Create final history item with calculated XP
        let finalHistoryItem = Workout(from: workout, followersEarned: calculatedXP, xpEarned: calculatedXP)

        // Save workout history to CloudKit
        FameFitLogger.info(
            "💾 Saving workout to CloudKit: \(finalHistoryItem.workoutType) with \(calculatedXP) XP",
            category: FameFitLogger.workout
        )
        cloudKitManager?.saveWorkoutHistory(finalHistoryItem)

        // Publish workout completion for sharing prompt (only for recent workouts)
        let workoutAge = Date().timeIntervalSince(workout.endDate)
        if workoutAge < 3_600 { // Only prompt for workouts completed within the last hour
            workoutCompletedSubject.send(finalHistoryItem)
        }

        sendWorkoutFameFitNotification(
            character: character,
            duration: Int(duration),
            calories: Int(calories),
            xpEarned: calculatedXP
        )
    }

    private func requestNotificationPermissions() {
        UNUserNotificationCenter.current().requestAuthorization(options: [
            .alert,
            .sound,
            .badge
        ]) { [weak self] granted, error in
            if let error {
                DispatchQueue.main.async {
                    self?.lastError = .unknownError(error)
                }
            } else if granted {
            } else {}
        }
    }

    private func sendWorkoutFameFitNotification(character: FameFitCharacter, duration: Int, calories: Int, xpEarned: Int) {
        // Throttle notifications to prevent spam
        if let lastDate = lastNotificationDate,
           Date().timeIntervalSince(lastDate) < notificationThrottleInterval {
            FameFitLogger.debug(
                "Skipping notification - too soon since last notification",
                category: FameFitLogger.workout
            )
            return
        }

        let title = "\(character.emoji) \(character.fullName)"
        let body = character.workoutCompletionMessage(followers: xpEarned)

        // Add to notification store
        let notificationItem = FameFitNotification(
            title: title,
            body: body,
            character: character,
            workoutDuration: duration,
            calories: calories,
            followersEarned: xpEarned
        )

        DispatchQueue.main.async { [weak self] in
            self?.notificationStore?.addFameFitNotification(notificationItem)
        }

        // Also send push notification if enabled
        guard preferences.pushNotificationsEnabled,
              preferences.isEnabled(for: .workoutCompleted)
        else {
            return
        }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = preferences.shouldPlaySound(for: .workoutCompleted) ? .default : nil
        content.badge = preferences.badgeEnabled ? NSNumber(value: notificationStore?.unreadCount ?? 0) : nil

        content.userInfo = [
            "character": character.rawValue,
            "duration": duration,
            "calories": calories,
            "newFollowers": xpEarned
        ]

        // Use workout-specific identifier to prevent duplicates
        let notificationId = "workout-\(character.rawValue)-\(Date().timeIntervalSince1970)"
        let request = UNNotificationRequest(identifier: notificationId, content: content, trigger: nil)

        UNUserNotificationCenter.current().add(request) { [weak self] error in
            if let error {
                DispatchQueue.main.async {
                    self?.lastError = .unknownError(error)
                }
            } else {
                self?.lastNotificationDate = Date()
                FameFitLogger.debug("Local notification sent successfully", category: FameFitLogger.workout)
            }
        }

        // Also trigger remote push notification via APNS if configured
        Task { [weak self] in
            await self?.sendWorkoutPushFameFitNotification(
                character: character,
                duration: duration,
                calories: calories,
                xpEarned: xpEarned
            )
        }
    }

    private func sendWorkoutPushFameFitNotification(
        character: FameFitCharacter,
        duration: Int,
        calories: Int,
        xpEarned: Int
    ) async {
        // Only send remote push if APNS manager is configured and user is registered
        guard let apnsManager,
              apnsManager.isRegistered
        else {
            FameFitLogger.debug(
                "APNS not configured or not registered, skipping remote push",
                category: FameFitLogger.workout
            )
            return
        }

        // Create a rich notification payload with character-based messaging
        let title = "\(character.emoji) \(character.fullName)"
        let body = character.workoutCompletionMessage(followers: xpEarned)

        _ = PushNotificationPayload(
            aps: PushNotificationPayload.APSPayload(
                alert: PushNotificationPayload.APSPayload.Alert(
                    title: title,
                    body: body,
                    subtitle: nil
                ),
                badge: preferences.badgeEnabled ? (notificationStore?.unreadCount ?? 0) + 1 : nil,
                sound: preferences.shouldPlaySound(for: .workoutCompleted) ? "default" : nil,
                threadId: "workout-completed",
                category: "WORKOUT_COMPLETED"
            ),
            notificationType: "workoutCompleted",
            metadata: [
                "character": character.rawValue,
                "duration": "\(duration)",
                "calories": "\(calories)",
                "xpEarned": "\(xpEarned)"
            ]
        )

        // Note: The actual sending would happen through a backend service
        // For now, we log that this would be sent and update badge count
        FameFitLogger.debug("Would send remote push notification: \(title) - \(body)", category: FameFitLogger.workout)

        // Update the local badge count to match what the push notification would show
        await apnsManager.updateBadgeCount((notificationStore?.unreadCount ?? 0) + 1)
    }

    // Clear all pending notifications
    func clearAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        UNUserNotificationCenter.current().setBadgeCount(0) { error in
            if let error {
                FameFitLogger.error("Failed to clear badge count", error: error, category: FameFitLogger.workout)
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
                if let error {
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
                if let error {
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
