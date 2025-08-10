//
//  RealTimeSyncCoordinatorProtocol.swift
//  FameFit
//
//  Protocol for real-time sync coordination operations
//

import Foundation

protocol RealTimeSyncCoordinatorProtocol {
    func startRealTimeSync() async
    func stopRealTimeSync() async
    func handleRemoteChange(_ notification: CloudKitNotificationInfo) async
}