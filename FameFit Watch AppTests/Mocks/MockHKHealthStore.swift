//
//  MockHKHealthStore.swift
//  FameFit Watch AppTests
//
//  Mock HKHealthStore subclass for testing Watch app
//

import Foundation
import HealthKit
@testable import FameFit_Watch_App

class MockHKHealthStore: HKHealthStore, @unchecked Sendable {
    var authorizationSuccess = true
    var authorizationError: Error?
    var requestedTypes: Set<HKSampleType>?
    
    override func requestAuthorization(toShare typesToShare: Set<HKSampleType>?, 
                                     read typesToRead: Set<HKObjectType>?, 
                                     completion: @escaping (Bool, Error?) -> Void) {
        requestedTypes = typesToShare
        completion(authorizationSuccess, authorizationError)
    }
    
    override func authorizationStatus(for type: HKObjectType) -> HKAuthorizationStatus {
        return authorizationSuccess ? .sharingAuthorized : .notDetermined
    }
}