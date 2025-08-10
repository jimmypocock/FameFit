//
//  WorkoutObserverProtocol.swift
//  FameFit
//
//  Protocol for workout observation services
//

import Combine
import Foundation
import HealthKit

protocol WorkoutObserverProtocol: ObservableObject {
    var allWorkouts: [HKWorkout] { get }
    var todaysWorkouts: [HKWorkout] { get }
    var isAuthorized: Bool { get }
    var lastError: FameFitError? { get }
    
    // Publisher for workout completion events
    var workoutCompletedPublisher: AnyPublisher<Workout, Never> { get }

    func requestHealthKitAuthorization(completion: @escaping (Bool, FameFitError?) -> Void)
    func startObservingWorkouts()
    func fetchInitialWorkouts()
}