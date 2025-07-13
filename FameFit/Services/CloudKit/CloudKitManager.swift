import Foundation
import CloudKit
import AuthenticationServices
import os.log
import HealthKit

class CloudKitManager: NSObject, ObservableObject, CloudKitManaging {
    private let container = CKContainer(identifier: "iCloud.com.jimmypocock.FameFit")
    private let privateDatabase: CKDatabase
    
    @Published var isSignedIn = false
    @Published var userRecord: CKRecord?
    @Published var followerCount: Int = 0
    @Published var userName: String = ""
    @Published var currentStreak: Int = 0
    @Published var totalWorkouts: Int = 0
    @Published var lastWorkoutTimestamp: Date?
    @Published var joinTimestamp: Date?
    @Published var lastError: FameFitError?
    
    weak var authenticationManager: AuthenticationManager?
    
    var isAvailable: Bool {
        isSignedIn
    }
    
    
    override init() {
        self.privateDatabase = container.privateCloudDatabase
        super.init()
        checkAccountStatus()
    }
    
    func checkAccountStatus() {
        container.accountStatus { [weak self] status, error in
            DispatchQueue.main.async {
                switch status {
                case .available:
                    self?.isSignedIn = true
                    self?.fetchUserRecord()
                case .noAccount:
                    self?.isSignedIn = false
                default:
                    self?.isSignedIn = false
                }
            }
        }
    }
    
    func setupUserRecord(userID: String, displayName: String) {
        // Use CloudKit's user record ID instead of Apple Sign In ID
        container.fetchUserRecordID { [weak self] recordID, error in
            guard let recordID = recordID else { return }
            
            self?.privateDatabase.fetch(withRecordID: recordID) { existingRecord, fetchError in
                let userRecord = existingRecord ?? CKRecord(recordType: "UserProfiles", recordID: recordID)
        
                // Only update if this is a new record
                if existingRecord == nil {
                    userRecord["displayName"] = displayName
                    userRecord["followerCount"] = 0
                    userRecord["totalWorkouts"] = 0
                    userRecord["currentStreak"] = 0
                    userRecord["joinTimestamp"] = Date()
                    userRecord["lastWorkoutTimestamp"] = Date()
                } else {
                    // Update display name if changed
                    userRecord["displayName"] = displayName
                }
                
                self?.privateDatabase.save(userRecord) { [weak self] record, error in
                    DispatchQueue.main.async {
                        if let error = error {
                            self?.lastError = error.fameFitError
                            return
                        }
                        
                        if let record = record {
                            self?.userRecord = record
                            self?.followerCount = record["followerCount"] as? Int ?? 0
                            self?.userName = record["displayName"] as? String ?? ""
                            self?.currentStreak = record["currentStreak"] as? Int ?? 0
                            self?.totalWorkouts = record["totalWorkouts"] as? Int ?? 0
                            self?.lastWorkoutTimestamp = record["lastWorkoutTimestamp"] as? Date
                            self?.joinTimestamp = record["joinTimestamp"] as? Date
                            self?.lastError = nil
                        }
                    }
                }
            }
        }
    }
    
    func fetchUserRecord() {
        container.fetchUserRecordID { [weak self] recordID, error in
            if let error = error {
                DispatchQueue.main.async {
                    self?.lastError = error.fameFitError
                }
                return
            }
            
            guard let recordID = recordID else {
                DispatchQueue.main.async {
                    self?.lastError = .cloudKitUserNotFound
                }
                return
            }
            
            self?.privateDatabase.fetch(withRecordID: recordID) { record, error in
                DispatchQueue.main.async {
                    if let error = error {
                        self?.lastError = error.fameFitError
                        return
                    }
                    
                    if let record = record {
                        self?.userRecord = record
                        self?.followerCount = record["followerCount"] as? Int ?? 0
                        self?.userName = record["displayName"] as? String ?? ""
                        self?.currentStreak = record["currentStreak"] as? Int ?? 0
                        self?.totalWorkouts = record["totalWorkouts"] as? Int ?? 0
                        self?.lastWorkoutTimestamp = record["lastWorkoutTimestamp"] as? Date
                        self?.joinTimestamp = record["joinTimestamp"] as? Date
                        self?.lastError = nil
                    }
                }
            }
        }
    }
    
    func addFollowers(_ count: Int = 5) {
        FameFitLogger.info("addFollowers called with count: \(count)", category: FameFitLogger.cloudKit)
        
        guard let userRecord = userRecord else {
            FameFitLogger.notice("No user record found - fetching...", category: FameFitLogger.cloudKit)
            fetchUserRecord()
            return
        }
        
        let currentCount = userRecord["followerCount"] as? Int ?? 0
        let currentTotal = userRecord["totalWorkouts"] as? Int ?? 0
        
        FameFitLogger.debug("Current followers: \(currentCount), workouts: \(currentTotal)", category: FameFitLogger.cloudKit)
        
        userRecord["followerCount"] = currentCount + count
        userRecord["totalWorkouts"] = currentTotal + 1
        userRecord["lastWorkoutTimestamp"] = Date()
        
        FameFitLogger.debug("New followers: \(currentCount + count), workouts: \(currentTotal + 1)", category: FameFitLogger.cloudKit)
        
        updateStreakIfNeeded(userRecord)
        
        privateDatabase.save(userRecord) { [weak self] record, error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.lastError = error.fameFitError
                    return
                }
                
                if let record = record {
                    self?.userRecord = record
                    self?.followerCount = record["followerCount"] as? Int ?? 0
                    self?.totalWorkouts = record["totalWorkouts"] as? Int ?? 0
                    self?.currentStreak = record["currentStreak"] as? Int ?? 0
                    self?.lastWorkoutTimestamp = record["lastWorkoutTimestamp"] as? Date
                    self?.joinTimestamp = record["joinTimestamp"] as? Date
                    self?.lastError = nil
                }
            }
        }
    }
    
    private func updateStreakIfNeeded(_ record: CKRecord) {
        let lastWorkoutTimestamp = record["lastWorkoutTimestamp"] as? Date ?? Date()
        let currentStreak = record["currentStreak"] as? Int ?? 0
        
        let calendar = Calendar.current
        let daysSinceLastWorkout = calendar.dateComponents([.day], from: lastWorkoutTimestamp, to: Date()).day ?? 0
        
        if daysSinceLastWorkout <= 1 {
            record["currentStreak"] = currentStreak + 1
        } else {
            record["currentStreak"] = 1
        }
    }
    
    func getFollowerTitle() -> String {
        switch followerCount {
        case 0..<100:
            return "Fitness Newbie"
        case 100..<1000:
            return "Micro-Influencer"
        case 1000..<10000:
            return "Rising Star"
        case 10000..<100000:
            return "Verified Influencer"
        default:
            return "FameFit Elite"
        }
    }
    
    
    func recordWorkout(_ workout: HKWorkout, completion: @escaping (Bool) -> Void) {
        // For now, just increase followers when a workout is recorded
        addFollowers(5)
        completion(true)
    }
}