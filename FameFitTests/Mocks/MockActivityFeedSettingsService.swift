//
//  MockActivityFeedSettingsService.swift
//  FameFitTests
//
//  Mock implementation of ActivityFeedSettingsServicing for testing
//

@testable import FameFit
import Combine
import Foundation

final class MockActivityFeedSettingsService: ActivityFeedSettingsServicing {
    // MARK: - Mock State
    
    var mockSettings = ActivityFeedSettings()
    var shouldFail = false
    var loadSettingsCallCount = 0
    var saveSettingsCallCount = 0
    var resetToDefaultsCallCount = 0
    var lastSavedSettings: ActivityFeedSettings?
    
    private let settingsSubject = CurrentValueSubject<ActivityFeedSettings, Never>(ActivityFeedSettings())
    
    // MARK: - Protocol Implementation
    
    var settingsPublisher: AnyPublisher<ActivityFeedSettings, Never> {
        settingsSubject.eraseToAnyPublisher()
    }
    
    func loadSettings() async throws -> ActivityFeedSettings {
        loadSettingsCallCount += 1
        
        if shouldFail {
            throw MockError.testError
        }
        
        return mockSettings
    }
    
    func saveSettings(_ settings: ActivityFeedSettings) async throws {
        saveSettingsCallCount += 1
        lastSavedSettings = settings
        
        if shouldFail {
            throw MockError.testError
        }
        
        mockSettings = settings
        settingsSubject.send(settings)
    }
    
    func resetToDefaults() async throws {
        resetToDefaultsCallCount += 1
        
        if shouldFail {
            throw MockError.testError
        }
        
        mockSettings = ActivityFeedSettings()
        settingsSubject.send(mockSettings)
    }
    
    // MARK: - Test Helpers
    
    func reset() {
        mockSettings = ActivityFeedSettings()
        shouldFail = false
        loadSettingsCallCount = 0
        saveSettingsCallCount = 0
        resetToDefaultsCallCount = 0
        lastSavedSettings = nil
        settingsSubject.send(ActivityFeedSettings())
    }
    
    func updateSettings(_ settings: ActivityFeedSettings) {
        mockSettings = settings
        settingsSubject.send(settings)
    }
    
    enum MockError: Error {
        case testError
    }
}