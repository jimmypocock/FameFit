//
//  CloudKitSubscriptionProtocol.swift
//  FameFit
//
//  Protocol for CloudKit subscription management operations
//

import CloudKit
import Combine
import Foundation

protocol CloudKitSubscriptionProtocol {
    func setupSubscriptions() async throws
    func removeAllSubscriptions() async throws
    func handleFameFitNotification(_ notification: CKQueryNotification) async
    var notificationPublisher: AnyPublisher<CloudKitNotificationInfo, Never> { get }
}