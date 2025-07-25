//
//  MockHKHealthStore.swift
//  FameFit Watch AppTests
//
//  Mock HKHealthStore subclass for testing Watch app
//

@testable import FameFit_Watch_App
import Foundation
import HealthKit

class MockHKHealthStore: HKHealthStore, @unchecked Sendable {
    var authorizationSuccess = true
    var authorizationError: Error?
    var requestedTypes: Set<HKSampleType>?

    override func requestAuthorization(
        toShare typesToShare: Set<HKSampleType>?,
        read _: Set<HKObjectType>?,
        completion: @escaping (Bool, Error?) -> Void
    ) {
        requestedTypes = typesToShare
        completion(authorizationSuccess, authorizationError)
    }

    override func authorizationStatus(for _: HKObjectType) -> HKAuthorizationStatus {
        authorizationSuccess ? .sharingAuthorized : .notDetermined
    }
}
