//
//  MockWorkoutGenerator.swift
//  FameFit
//
//  Generates realistic mock workout data for development and testing
//

#if DEBUG

import Foundation
import HealthKit

/// Generates realistic mock workout data with appropriate metrics for each workout type
struct MockWorkoutGenerator {
    
    // MARK: - Constants
    
    private enum Constants {
        static let defaultRestingHeartRate: Double = 60
        static let maxHeartRate: Double = 200
        static let walkingPace: Double = 4.8 // km/h
        static let runningPace: Double = 10.0 // km/h
        static let cyclingSpeed: Double = 25.0 // km/h
    }
    
    // MARK: - Workout Generation
    
    /// Generates a workout with realistic data based on the specified parameters
    static func generateWorkout(
        type: HKWorkoutActivityType,
        duration: TimeInterval,
        startDate: Date = Date(),
        intensity: Double = 0.7,
        source: String = "Apple Watch",
        metadata: [String: Any]? = nil
    ) -> HKWorkout {
        
        let endDate = startDate.addingTimeInterval(duration)
        
        // Calculate metrics based on workout type and intensity
        let metrics = calculateMetrics(
            for: type,
            duration: duration,
            intensity: intensity
        )
        
        // Generate device information
        let device = createDevice(source: source)
        
        // Combine default and custom metadata
        var workoutMetadata: [String: Any] = [
            HKMetadataKeyWasUserEntered: false,
            HKMetadataKeyWorkoutBrandName: source
        ]
        
        if let customMetadata = metadata {
            workoutMetadata.merge(customMetadata) { _, new in new }
        }
        
        // Create the workout
        let workout = HKWorkout(
            activityType: type,
            start: startDate,
            end: endDate,
            duration: duration,
            totalEnergyBurned: HKQuantity(unit: .kilocalorie(), doubleValue: metrics.calories),
            totalDistance: HKQuantity(unit: .meter(), doubleValue: metrics.distance),
            device: device,
            metadata: workoutMetadata
        )
        
        return workout
    }
    
    // MARK: - Heart Rate Data Generation
    
    /// Generates realistic heart rate data over time for a workout
    static func generateHeartRateData(
        for workoutType: HKWorkoutActivityType,
        duration: TimeInterval,
        intensity: Double = 0.7,
        samplingInterval: TimeInterval = 5.0
    ) -> [(timestamp: Date, heartRate: Double)] {
        
        let baseHeartRate = calculateBaseHeartRate(for: workoutType, intensity: intensity)
        let sampleCount = Int(duration / samplingInterval)
        var heartRateData: [(Date, Double)] = []
        
        let startDate = Date()
        
        for i in 0..<sampleCount {
            let timestamp = startDate.addingTimeInterval(Double(i) * samplingInterval)
            let progress = Double(i) / Double(sampleCount)
            
            // Generate heart rate based on workout phase
            let heartRate = calculateHeartRateForPhase(
                baseRate: baseHeartRate,
                progress: progress,
                workoutType: workoutType,
                intensity: intensity
            )
            
            heartRateData.append((timestamp, heartRate))
        }
        
        return heartRateData
    }
    
    // MARK: - Pace/Speed Data Generation
    
    /// Generates realistic pace data for distance-based workouts
    static func generatePaceData(
        for workoutType: HKWorkoutActivityType,
        duration: TimeInterval,
        totalDistance: Double,
        samplingInterval: TimeInterval = 60.0
    ) -> [(timestamp: Date, pace: Double)] {
        
        let sampleCount = Int(duration / samplingInterval)
        var paceData: [(Date, Double)] = []
        
        let startDate = Date()
        let averagePace = duration / (totalDistance / 1000) // min/km
        
        for i in 0..<sampleCount {
            let timestamp = startDate.addingTimeInterval(Double(i) * samplingInterval)
            let progress = Double(i) / Double(sampleCount)
            
            // Add variation to pace
            let variation = sin(progress * .pi * 4) * 0.1 + (Double.random(in: -0.05...0.05))
            let pace = averagePace * (1 + variation)
            
            paceData.append((timestamp, pace))
        }
        
        return paceData
    }
    
    // MARK: - Private Helpers
    
    private struct WorkoutMetrics {
        let calories: Double
        let distance: Double
        let averageHeartRate: Double
    }
    
    private static func calculateMetrics(
        for type: HKWorkoutActivityType,
        duration: TimeInterval,
        intensity: Double
    ) -> WorkoutMetrics {
        
        let durationMinutes = duration / 60
        
        // Calculate based on workout type and intensity
        let (caloriesPerMinute, metersPerMinute) = getWorkoutRates(for: type, intensity: intensity)
        
        let calories = caloriesPerMinute * durationMinutes
        let distance = metersPerMinute * durationMinutes
        let averageHeartRate = calculateBaseHeartRate(for: type, intensity: intensity)
        
        return WorkoutMetrics(
            calories: calories,
            distance: distance,
            averageHeartRate: averageHeartRate
        )
    }
    
    private static func getWorkoutRates(
        for type: HKWorkoutActivityType,
        intensity: Double
    ) -> (caloriesPerMinute: Double, metersPerMinute: Double) {
        
        // Base rates at moderate intensity (0.5)
        let baseRates: (calories: Double, meters: Double)
        
        switch type {
        case .running:
            baseRates = (10.0, 150.0)
        case .walking:
            baseRates = (4.0, 80.0)
        case .cycling:
            baseRates = (8.0, 400.0)
        case .swimming:
            baseRates = (11.0, 30.0)
        case .functionalStrengthTraining:
            baseRates = (6.0, 0.0)
        case .traditionalStrengthTraining:
            baseRates = (5.0, 0.0)
        case .highIntensityIntervalTraining:
            baseRates = (12.0, 50.0)
        case .yoga:
            baseRates = (3.0, 0.0)
        case .dance:
            baseRates = (6.0, 20.0)
        case .elliptical:
            baseRates = (9.0, 100.0)
        case .rowing:
            baseRates = (10.0, 120.0)
        case .stairClimbing:
            baseRates = (9.0, 30.0)
        default:
            baseRates = (5.0, 0.0)
        }
        
        // Adjust for intensity (0.3 to 1.0 scale)
        let intensityMultiplier = 0.5 + intensity
        
        return (
            baseRates.calories * intensityMultiplier,
            baseRates.meters * intensityMultiplier
        )
    }
    
    private static func calculateBaseHeartRate(
        for type: HKWorkoutActivityType,
        intensity: Double
    ) -> Double {
        
        let restingRate = Constants.defaultRestingHeartRate
        let maxRate = Constants.maxHeartRate
        
        // Target heart rate zones for different workout types
        let targetZonePercentage: Double
        
        switch type {
        case .running:
            targetZonePercentage = 0.7 + (intensity * 0.2)
        case .walking:
            targetZonePercentage = 0.5 + (intensity * 0.15)
        case .cycling:
            targetZonePercentage = 0.65 + (intensity * 0.2)
        case .highIntensityIntervalTraining:
            targetZonePercentage = 0.75 + (intensity * 0.2)
        case .functionalStrengthTraining,
             .traditionalStrengthTraining:
            targetZonePercentage = 0.6 + (intensity * 0.15)
        case .yoga:
            targetZonePercentage = 0.4 + (intensity * 0.1)
        default:
            targetZonePercentage = 0.6 + (intensity * 0.15)
        }
        
        return restingRate + ((maxRate - restingRate) * targetZonePercentage)
    }
    
    private static func calculateHeartRateForPhase(
        baseRate: Double,
        progress: Double,
        workoutType: HKWorkoutActivityType,
        intensity: Double
    ) -> Double {
        
        // Define workout phases
        let warmupEnd = 0.1
        let mainPhaseEnd = 0.8
        
        var heartRate: Double
        
        if progress < warmupEnd {
            // Warmup phase - gradual increase
            let warmupProgress = progress / warmupEnd
            heartRate = Constants.defaultRestingHeartRate + 
                       (baseRate - Constants.defaultRestingHeartRate) * warmupProgress
        } else if progress < mainPhaseEnd {
            // Main phase - at target with variations
            let variation = sin(progress * .pi * 6) * 5 + Double.random(in: -3...3)
            heartRate = baseRate + variation
            
            // Add intervals for HIIT
            if workoutType == .highIntensityIntervalTraining {
                let intervalPhase = Int(progress * 20) % 2
                heartRate += intervalPhase == 0 ? -10 : 20
            }
        } else {
            // Cooldown phase - gradual decrease
            let cooldownProgress = (progress - mainPhaseEnd) / (1 - mainPhaseEnd)
            heartRate = baseRate - (baseRate - Constants.defaultRestingHeartRate) * cooldownProgress * 0.5
        }
        
        // Add random variation and ensure within bounds
        heartRate += Double.random(in: -2...2)
        return max(Constants.defaultRestingHeartRate, min(Constants.maxHeartRate, heartRate))
    }
    
    private static func createDevice(source: String) -> HKDevice? {
        let deviceName: String
        let manufacturer: String
        let model: String
        let hardwareVersion: String
        let softwareVersion: String
        
        switch source {
        case "Apple Watch":
            deviceName = "Apple Watch"
            manufacturer = "Apple Inc."
            model = "Watch6,2"
            hardwareVersion = "1.0"
            softwareVersion = "10.0"
        case "Strava":
            deviceName = "Strava"
            manufacturer = "Strava Inc."
            model = "iPhone"
            hardwareVersion = "1.0"
            softwareVersion = "3.0"
        case "Nike Run Club":
            deviceName = "Nike Run Club"
            manufacturer = "Nike Inc."
            model = "iPhone"
            hardwareVersion = "1.0"
            softwareVersion = "7.0"
        default:
            deviceName = source
            manufacturer = "Unknown"
            model = "Unknown"
            hardwareVersion = "1.0"
            softwareVersion = "1.0"
        }
        
        return HKDevice(
            name: deviceName,
            manufacturer: manufacturer,
            model: model,
            hardwareVersion: hardwareVersion,
            firmwareVersion: nil,
            softwareVersion: softwareVersion,
            localIdentifier: nil,
            udiDeviceIdentifier: nil
        )
    }
}

#endif