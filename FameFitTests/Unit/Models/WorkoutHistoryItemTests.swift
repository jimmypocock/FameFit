import XCTest
import HealthKit
@testable import FameFit

final class WorkoutHistoryItemTests: XCTestCase {
    
    func testWorkoutHistoryItemInitialization() {
        let id = UUID()
        let workoutType = "Running"
        let startDate = Date().addingTimeInterval(-3600) // 1 hour ago
        let endDate = Date()
        let duration: TimeInterval = 3600
        let totalEnergyBurned = 350.0
        let totalDistance = 5000.0
        let averageHeartRate = 145.0
        let followersEarned = 5
        let source = "Apple Watch"
        
        let historyItem = WorkoutHistoryItem(
            id: id,
            workoutType: workoutType,
            startDate: startDate,
            endDate: endDate,
            duration: duration,
            totalEnergyBurned: totalEnergyBurned,
            totalDistance: totalDistance,
            averageHeartRate: averageHeartRate,
            followersEarned: followersEarned,
            source: source
        )
        
        XCTAssertEqual(historyItem.id, id)
        XCTAssertEqual(historyItem.workoutType, workoutType)
        XCTAssertEqual(historyItem.startDate, startDate)
        XCTAssertEqual(historyItem.endDate, endDate)
        XCTAssertEqual(historyItem.duration, duration)
        XCTAssertEqual(historyItem.totalEnergyBurned, totalEnergyBurned)
        XCTAssertEqual(historyItem.totalDistance, totalDistance)
        XCTAssertEqual(historyItem.averageHeartRate, averageHeartRate)
        XCTAssertEqual(historyItem.followersEarned, followersEarned)
        XCTAssertEqual(historyItem.source, source)
    }
    
    func testFormattedDuration() {
        let historyItem = WorkoutHistoryItem(
            id: UUID(),
            workoutType: "Running",
            startDate: Date(),
            endDate: Date(),
            duration: 3600, // 1 hour
            totalEnergyBurned: 350.0,
            totalDistance: nil,
            averageHeartRate: nil,
            followersEarned: 5,
            source: "Apple Watch"
        )
        
        XCTAssertEqual(historyItem.formattedDuration, "60 min")
    }
    
    func testFormattedCalories() {
        let historyItem = WorkoutHistoryItem(
            id: UUID(),
            workoutType: "Running",
            startDate: Date(),
            endDate: Date(),
            duration: 3600,
            totalEnergyBurned: 350.5,
            totalDistance: nil,
            averageHeartRate: nil,
            followersEarned: 5,
            source: "Apple Watch"
        )
        
        XCTAssertEqual(historyItem.formattedCalories, "350 cal")
    }
    
    func testFormattedDistance() {
        let historyItem = WorkoutHistoryItem(
            id: UUID(),
            workoutType: "Running",
            startDate: Date(),
            endDate: Date(),
            duration: 3600,
            totalEnergyBurned: 350.0,
            totalDistance: 5243.0, // 5.243 km
            averageHeartRate: nil,
            followersEarned: 5,
            source: "Apple Watch"
        )
        
        XCTAssertEqual(historyItem.formattedDistance, "5.24 km")
    }
    
    func testFormattedDistanceNil() {
        let historyItem = WorkoutHistoryItem(
            id: UUID(),
            workoutType: "Yoga",
            startDate: Date(),
            endDate: Date(),
            duration: 3600,
            totalEnergyBurned: 150.0,
            totalDistance: nil,
            averageHeartRate: nil,
            followersEarned: 5,
            source: "Apple Watch"
        )
        
        XCTAssertNil(historyItem.formattedDistance)
    }
    
    func testWorkoutActivityTypeConversion() {
        let historyItem = WorkoutHistoryItem(
            id: UUID(),
            workoutType: "Running",
            startDate: Date(),
            endDate: Date(),
            duration: 3600,
            totalEnergyBurned: 350.0,
            totalDistance: nil,
            averageHeartRate: nil,
            followersEarned: 5,
            source: "Apple Watch"
        )
        
        XCTAssertEqual(historyItem.workoutActivityType, .running)
    }
    
    func testCodable() throws {
        let historyItem = WorkoutHistoryItem(
            id: UUID(),
            workoutType: "Running",
            startDate: Date(),
            endDate: Date(),
            duration: 3600,
            totalEnergyBurned: 350.0,
            totalDistance: 5000.0,
            averageHeartRate: 145.0,
            followersEarned: 5,
            source: "Apple Watch"
        )
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(historyItem)
        
        let decoder = JSONDecoder()
        let decodedItem = try decoder.decode(WorkoutHistoryItem.self, from: data)
        
        XCTAssertEqual(historyItem.id, decodedItem.id)
        XCTAssertEqual(historyItem.workoutType, decodedItem.workoutType)
        XCTAssertEqual(historyItem.duration, decodedItem.duration)
        XCTAssertEqual(historyItem.totalEnergyBurned, decodedItem.totalEnergyBurned)
        XCTAssertEqual(historyItem.totalDistance, decodedItem.totalDistance)
        XCTAssertEqual(historyItem.averageHeartRate, decodedItem.averageHeartRate)
        XCTAssertEqual(historyItem.followersEarned, decodedItem.followersEarned)
        XCTAssertEqual(historyItem.source, decodedItem.source)
    }
}