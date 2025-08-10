//
//  ActivityFeedSettingsProtocol.swift
//  FameFit
//
//  Protocol for activity feed settings service operations
//

import Combine
import Foundation

protocol ActivityFeedSettingsProtocol: AnyObject {
    func loadSettings() async throws -> ActivityFeedSettings
    func saveSettings(_ settings: ActivityFeedSettings) async throws
    func resetToDefaults() async throws
    
    // Publisher for settings changes
    var settingsPublisher: AnyPublisher<ActivityFeedSettings, Never> { get }
}