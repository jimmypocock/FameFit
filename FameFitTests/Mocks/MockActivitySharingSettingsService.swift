//
//  MockActivitySharingSettingsService.swift
//  FameFitTests
//
//  Mock implementation of ActivitySharingSettingsServicing for testing
//

@testable import FameFit
import Combine
import Foundation

final class MockActivitySharingSettingsService: ActivitySharingSettingsServicing {
    // MARK: - Mock State
    
    var mockSettings = ActivitySharingSettings()
    var shouldFail = false
    var loadSettingsCallCount = 0
    var saveSettingsCallCount = 0
    var resetToDefaultsCallCount = 0
    var lastSavedSettings: ActivitySharingSettings?
    
    private let settingsSubject = CurrentValueSubject<ActivitySharingSettings, Never>(ActivitySharingSettings())
    
    // MARK: - Protocol Implementation
    
    var settingsPublisher: AnyPublisher<ActivitySharingSettings, Never> {
        settingsSubject.eraseToAnyPublisher()
    }
    
    func loadSettings() async throws -> ActivitySharingSettings {
        loadSettingsCallCount += 1
        
        if shouldFail {
            throw MockError.testError
        }
        
        return mockSettings
    }
    
    func saveSettings(_ settings: ActivitySharingSettings) async throws {
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
        
        mockSettings = ActivitySharingSettings()
        settingsSubject.send(mockSettings)
    }
    
    // MARK: - Test Helpers
    
    func reset() {
        mockSettings = ActivitySharingSettings()
        shouldFail = false
        loadSettingsCallCount = 0
        saveSettingsCallCount = 0
        resetToDefaultsCallCount = 0
        lastSavedSettings = nil
        settingsSubject.send(ActivitySharingSettings())
    }
    
    func updateSettings(_ settings: ActivitySharingSettings) {
        mockSettings = settings
        settingsSubject.send(settings)
    }
    
    enum MockError: Error {
        case testError
    }
}