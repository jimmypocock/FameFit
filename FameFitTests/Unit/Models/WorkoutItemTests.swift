@testable import FameFit
import HealthKit
import XCTest

final class WorkoutTests: XCTestCase {
    func testWorkoutInitialization() {
        let id = UUID()
        let workoutType = "Running"
        let startDate = Date().addingTimeInterval(-3_600) // 1 hour ago
        let endDate = Date()
        let duration: TimeInterval = 3_600
        let totalEnergyBurned = 350.0
        let totalDistance = 5_000.0
        let averageHeartRate = 145.0
        let followersEarned = 5
        let source = "Apple Watch"

        let historyItem = Workout(
            id: id.uuidString,
            workoutType: workoutType,
            startDate: startDate,
            endDate: endDate,
            duration: duration,
            totalEnergyBurned: totalEnergyBurned,
            totalDistance: totalDistance,
            averageHeartRate: averageHeartRate,
            followersEarned: followersEarned,
            xpEarned: followersEarned,
            source: source
        )

        XCTAssertEqual(historyItem.id, id.uuidString)
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
        let historyItem = Workout(
            id: UUID().uuidString,
            workoutType: "Running",
            startDate: Date(),
            endDate: Date(),
            duration: 3_600, // 1 hour
            totalEnergyBurned: 350.0,
            totalDistance: nil,
            averageHeartRate: nil,
            followersEarned: 5,
            xpEarned: 5,
            source: "Apple Watch"
        )

        XCTAssertEqual(historyItem.formattedDuration, "60 min")
    }

    func testFormattedCalories() {
        let historyItem = Workout(
            id: UUID().uuidString,
            workoutType: "Running",
            startDate: Date(),
            endDate: Date(),
            duration: 3_600,
            totalEnergyBurned: 350.5,
            totalDistance: nil,
            averageHeartRate: nil,
            followersEarned: 5,
            xpEarned: 5,
            source: "Apple Watch"
        )

        XCTAssertEqual(historyItem.formattedCalories, "350 cal")
    }

    func testFormattedDistance() {
        let historyItem = Workout(
            id: UUID().uuidString,
            workoutType: "Running",
            startDate: Date(),
            endDate: Date(),
            duration: 3_600,
            totalEnergyBurned: 350.0,
            totalDistance: 5_243.0, // 5.243 km
            averageHeartRate: nil,
            followersEarned: 5,
            xpEarned: 5,
            source: "Apple Watch"
        )

        XCTAssertEqual(historyItem.formattedDistance, "5.24 km")
    }

    func testFormattedDistanceNil() {
        let historyItem = Workout(
            id: UUID().uuidString,
            workoutType: "Yoga",
            startDate: Date(),
            endDate: Date(),
            duration: 3_600,
            totalEnergyBurned: 150.0,
            totalDistance: nil,
            averageHeartRate: nil,
            followersEarned: 5,
            xpEarned: 5,
            source: "Apple Watch"
        )

        XCTAssertNil(historyItem.formattedDistance)
    }

    func testWorkoutActivityTypeConversion() {
        let historyItem = Workout(
            id: UUID().uuidString,
            workoutType: "running",
            startDate: Date(),
            endDate: Date(),
            duration: 3_600,
            totalEnergyBurned: 350.0,
            totalDistance: nil,
            averageHeartRate: nil,
            followersEarned: 5,
            xpEarned: 5,
            source: "Apple Watch"
        )

        XCTAssertEqual(historyItem.workoutActivityType, HKWorkoutActivityType.running)
    }

    func testCodable() throws {
        let historyItem = Workout(
            id: UUID().uuidString,
            workoutType: "Running",
            startDate: Date(),
            endDate: Date(),
            duration: 3_600,
            totalEnergyBurned: 350.0,
            totalDistance: 5_000.0,
            averageHeartRate: 145.0,
            followersEarned: 5,
            xpEarned: 5,
            source: "Apple Watch"
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(historyItem)

        let decoder = JSONDecoder()
        let decodedItem = try decoder.decode(Workout.self, from: data)

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
