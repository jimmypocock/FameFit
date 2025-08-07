//
//  UserProfileService.swift
//  FameFit
//
//  Service for managing user profiles with CloudKit
//

import CloudKit
import Combine
import Foundation
import UIKit

final class UserProfileService: UserProfileServicing {
    // MARK: - Properties

    @Published private var currentProfile: UserProfile?
    @Published private var isLoading = false

    private let cloudKitManager: any CloudKitManaging
    private let publicDatabase: CKDatabase
    private let privateDatabase: CKDatabase

    // Cache with shorter TTL for better freshness
    private var profileCache: [String: (profile: UserProfile, timestamp: Date)] = [:]
    private let cacheTTL: TimeInterval = 5 * 60 // 5 minutes - more aggressive caching

    // Content moderation word list (basic implementation)
    private let inappropriateWords = Set<String>([
        // Add inappropriate words here
        // This is a simplified version - in production, use a proper content moderation service
    ])

    // MARK: - Publishers

    var currentProfilePublisher: AnyPublisher<UserProfile?, Never> {
        $currentProfile.eraseToAnyPublisher()
    }

    var isLoadingPublisher: AnyPublisher<Bool, Never> {
        $isLoading.eraseToAnyPublisher()
    }

    // MARK: - Initialization

    init(cloudKitManager: any CloudKitManaging) {
        self.cloudKitManager = cloudKitManager
        publicDatabase = CKContainer.default().publicCloudDatabase
        privateDatabase = CKContainer.default().privateCloudDatabase
    }

    // MARK: - Profile Operations

    func fetchProfile(userId: String) async throws -> UserProfile {
        // Check cache first
        if let cached = getCachedProfile(userId: userId) {
            return cached
        }

        isLoading = true
        defer { isLoading = false }

        let recordID = CKRecord.ID(recordName: userId)

        do {
            let record = try await publicDatabase.record(for: recordID)
            guard let profile = UserProfile(from: record) else {
                throw ProfileServiceError.profileNotFound
            }

            // Cache the profile
            cacheProfile(profile)

            return profile
        } catch let error as CKError {
            if error.code == .unknownItem {
                throw ProfileServiceError.profileNotFound
            } else {
                throw ProfileServiceError.networkError(error)
            }
        } catch {
            throw ProfileServiceError.networkError(error)
        }
    }

    func fetchCurrentUserProfile() async throws -> UserProfile {
        guard cloudKitManager.isAvailable else {
            throw ProfileServiceError.networkError(CKError(.networkUnavailable))
        }

        guard let userId = cloudKitManager.currentUserID else {
            throw ProfileServiceError.profileNotFound
        }

        // Try to fetch profile by userId field (not record ID)
        var profile = try await fetchProfileByUserID(userId)
        
        // Fetch fresh stats from Users record
        do {
            let freshStats = try await fetchFreshUserStats(userId: userId)
            // Create updated profile with fresh stats
            profile = UserProfile(
                id: profile.id,
                userID: profile.userID,
                username: profile.username,
                bio: profile.bio,
                workoutCount: freshStats.workoutCount,
                totalXP: freshStats.totalXP,
                createdTimestamp: profile.createdTimestamp,
                modifiedTimestamp: profile.modifiedTimestamp,
                isVerified: profile.isVerified,
                privacyLevel: profile.privacyLevel,
                profileImageURL: profile.profileImageURL,
                headerImageURL: profile.headerImageURL
            )
        } catch {
            // If we can't fetch fresh stats, continue with cached values
            print("Warning: Could not fetch fresh stats: \(error)")
        }
        
        currentProfile = profile
        return profile
    }
    
    func fetchCurrentUserProfileFresh() async throws -> UserProfile {
        guard cloudKitManager.isAvailable else {
            throw ProfileServiceError.networkError(CKError(.networkUnavailable))
        }

        guard let userId = cloudKitManager.currentUserID else {
            throw ProfileServiceError.profileNotFound
        }

        // Clear cache for current user to force fresh data
        if let existingProfile = profileCache.values.first(where: { $0.profile.userID == userId }) {
            profileCache.removeValue(forKey: existingProfile.profile.id)
        }

        // Fetch fresh profile by userId field
        var profile = try await fetchProfileByUserID(userId)
        
        // Always fetch fresh stats from Users record
        do {
            let freshStats = try await fetchFreshUserStats(userId: userId)
            // Create updated profile with fresh stats
            profile = UserProfile(
                id: profile.id,
                userID: profile.userID,
                username: profile.username,
                bio: profile.bio,
                workoutCount: freshStats.workoutCount,
                totalXP: freshStats.totalXP,
                createdTimestamp: profile.createdTimestamp,
                modifiedTimestamp: profile.modifiedTimestamp,
                isVerified: profile.isVerified,
                privacyLevel: profile.privacyLevel,
                profileImageURL: profile.profileImageURL,
                headerImageURL: profile.headerImageURL
            )
        } catch {
            // If we can't fetch fresh stats, continue with cached values
            print("Warning: Could not fetch fresh stats: \(error)")
        }
        
        currentProfile = profile
        return profile
    }

    /// Fetches a profile by the userID field (reference to Users table)
    func fetchProfileByUserID(_ userID: String) async throws -> UserProfile {
        // Check cache first
        if let cachedProfile = profileCache.values.first(where: { $0.profile.userID == userID })?.profile {
            if Date().timeIntervalSince(profileCache[cachedProfile.id]!.timestamp) < cacheTTL {
                return cachedProfile
            }
        }

        isLoading = true
        defer { isLoading = false }

        let predicate = NSPredicate(format: "userID == %@", userID)
        let query = CKQuery(recordType: "UserProfiles", predicate: predicate)

        do {
            let results = try await publicDatabase.records(matching: query, resultsLimit: 1)
            guard let (_, result) = results.matchResults.first,
                  case let .success(record) = result,
                  let profile = UserProfile(from: record)
            else {
                throw ProfileServiceError.profileNotFound
            }

            // Cache the profile
            cacheProfile(profile)

            return profile
        } catch {
            throw ProfileServiceError.networkError(error)
        }
    }

    func createProfile(_ profile: UserProfile) async throws -> UserProfile {
        isLoading = true
        defer { isLoading = false }

        // Validate all fields
        try validateProfile(profile)

        // Check username availability
        let isAvailable = try await isUsernameAvailable(profile.username)
        guard isAvailable else {
            throw ProfileServiceError.usernameAlreadyTaken
        }

        // Content moderation
        try moderateContent(profile)

        // Create CloudKit record
        let record = profile.toCKRecord()

        do {
            let savedRecord = try await publicDatabase.save(record)
            guard let savedProfile = UserProfile(from: savedRecord) else {
                throw ProfileServiceError.networkError(CKError(.internalError))
            }

            // Cache and set as current
            cacheProfile(savedProfile)
            currentProfile = savedProfile

            // Create default settings in private database
            let settings = UserSettings.defaultSettings(for: savedProfile.id)
            _ = try await updateSettings(settings)

            return savedProfile
        } catch {
            throw ProfileServiceError.networkError(error)
        }
    }

    func updateProfile(_ profile: UserProfile) async throws -> UserProfile {
        isLoading = true
        defer { isLoading = false }

        // Validate fields (except username which can't change)
        guard UserProfile.isValidUsername(profile.username) else {
            throw ProfileServiceError.invalidUsername
        }

        guard UserProfile.isValidBio(profile.bio) else {
            throw ProfileServiceError.invalidBio
        }

        // Content moderation
        try moderateContent(profile)

        // Fetch existing record to update
        let recordID = CKRecord.ID(recordName: profile.id)

        do {
            let existingRecord = try await publicDatabase.record(for: recordID)

            // Update fields
            existingRecord["displayName"] = profile.username
            existingRecord["bio"] = profile.bio
            existingRecord["workoutCount"] = Int64(profile.workoutCount)
            existingRecord["totalXP"] = Int64(profile.totalXP)
            // modifiedTimestamp is managed by CloudKit automatically
            existingRecord["privacyLevel"] = profile.privacyLevel.rawValue

            if let profileImageURL = profile.profileImageURL {
                existingRecord["profileImageURL"] = profileImageURL
            }
            if let headerImageURL = profile.headerImageURL {
                existingRecord["headerImageURL"] = headerImageURL
            }

            let savedRecord = try await publicDatabase.save(existingRecord)
            guard let updatedProfile = UserProfile(from: savedRecord) else {
                throw ProfileServiceError.networkError(CKError(.internalError))
            }

            // Update cache and current profile
            cacheProfile(updatedProfile)
            if currentProfile?.id == updatedProfile.id {
                currentProfile = updatedProfile
            }

            return updatedProfile
        } catch {
            throw ProfileServiceError.networkError(error)
        }
    }

    func deleteProfile(userId: String) async throws {
        isLoading = true
        defer { isLoading = false }

        let recordID = CKRecord.ID(recordName: userId)

        do {
            // Delete from public database
            _ = try await publicDatabase.deleteRecord(withID: recordID)

            // Delete settings from private database
            let settingsID = CKRecord.ID(recordName: "settings-\(userId)")
            _ = try? await privateDatabase.deleteRecord(withID: settingsID)

            // Clear from cache
            profileCache.removeValue(forKey: userId)

            if currentProfile?.id == userId {
                currentProfile = nil
            }
        } catch {
            throw ProfileServiceError.networkError(error)
        }
    }

    // MARK: - Username Validation

    func isUsernameAvailable(_ username: String) async throws -> Bool {
        // Always check with lowercase to ensure case-insensitive uniqueness
        let normalizedUsername = username.lowercased()
        let predicate = NSPredicate(format: "username == %@", normalizedUsername)
        let query = CKQuery(recordType: "UserProfiles", predicate: predicate)

        do {
            let results = try await publicDatabase.records(matching: query, resultsLimit: 1)
            return results.matchResults.isEmpty
        } catch {
            throw ProfileServiceError.networkError(error)
        }
    }

    func validateUsername(_ username: String) -> Result<Void, ProfileServiceError> {
        guard UserProfile.isValidUsername(username) else {
            return .failure(.invalidUsername)
        }

        // Check for inappropriate content
        let lowercaseUsername = username.lowercased()
        for word in inappropriateWords {
            if lowercaseUsername.contains(word) {
                return .failure(.contentModerated)
            }
        }

        return .success(())
    }

    // MARK: - Settings Operations

    func fetchSettings(userId: String) async throws -> UserSettings {
        let recordID = CKRecord.ID(recordName: "settings-\(userId)")

        do {
            let record = try await privateDatabase.record(for: recordID)
            return UserSettings(from: record) ?? UserSettings.defaultSettings(for: userId)
        } catch let error as CKError {
            if error.code == .unknownItem {
                // Settings don't exist, return defaults
                return UserSettings.defaultSettings(for: userId)
            } else {
                throw ProfileServiceError.networkError(error)
            }
        }
    }

    func updateSettings(_ settings: UserSettings) async throws -> UserSettings {
        isLoading = true
        defer { isLoading = false }

        let recordID = CKRecord.ID(recordName: "settings-\(settings.userID)")
        let record = settings.toCKRecord(recordID: recordID)

        do {
            let savedRecord = try await privateDatabase.save(record)
            return UserSettings(from: savedRecord) ?? settings
        } catch {
            throw ProfileServiceError.networkError(error)
        }
    }

    // MARK: - Search and Discovery

    func searchProfiles(query: String, limit: Int) async throws -> [UserProfile] {
        // CloudKit doesn't support CONTAINS operator well
        // For now, fetch all public profiles and filter locally
        // In production, you'd want to implement CloudKit full-text search
        
        let predicate = NSPredicate(format: "privacyLevel == %@", ProfilePrivacyLevel.publicProfile.rawValue)
        let ckQuery = CKQuery(recordType: "UserProfiles", predicate: predicate)
        ckQuery.sortDescriptors = [NSSortDescriptor(key: "totalXP", ascending: false)]
        
        do {
            // Fetch more records to filter from
            let results = try await publicDatabase.records(matching: ckQuery, resultsLimit: 100)
            let profiles = results.matchResults.compactMap { _, result in
                try? result.get()
            }.compactMap { UserProfile(from: $0) }
            
            // Filter locally by username or display name
            let lowercaseQuery = query.lowercased()
            let filteredProfiles = profiles.filter { profile in
                profile.username.lowercased().contains(lowercaseQuery) ||
                profile.username.lowercased().contains(lowercaseQuery)
            }
            
            // Cache results
            filteredProfiles.forEach { cacheProfile($0) }
            
            // Return limited results
            return Array(filteredProfiles.prefix(limit))
        } catch {
            throw ProfileServiceError.networkError(error)
        }
    }

    func fetchLeaderboard(limit: Int) async throws -> [UserProfile] {
        let predicate = NSPredicate(format: "privacyLevel == %@", ProfilePrivacyLevel.publicProfile.rawValue)
        let query = CKQuery(recordType: "UserProfiles", predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "totalXP", ascending: false)]

        do {
            let results = try await publicDatabase.records(matching: query, resultsLimit: limit)
            let profiles = results.matchResults.compactMap { _, result in
                try? result.get()
            }.compactMap { UserProfile(from: $0) }

            // Cache results
            profiles.forEach { cacheProfile($0) }

            return profiles
        } catch {
            throw ProfileServiceError.networkError(error)
        }
    }

    func fetchLeaderboardWithTimeFilter(
        limit: Int,
        startDate: Date,
        endDate: Date
    ) async throws -> [UserProfile] {
        // For time-filtered leaderboards, we need to query workout history
        // This is a simplified implementation - in production, we'd have a dedicated
        // leaderboard table that tracks XP earned per time period

        let predicate = NSPredicate(format: "privacyLevel == %@", ProfilePrivacyLevel.publicProfile.rawValue)
        let query = CKQuery(recordType: "UserProfiles", predicate: predicate)

        // For now, sort by total XP as a proxy
        // In a real implementation, we'd calculate XP earned during the period
        query.sortDescriptors = [NSSortDescriptor(key: "totalXP", ascending: false)]

        do {
            let results = try await publicDatabase
                .records(matching: query, resultsLimit: limit * 2) // Fetch extra for filtering
            let profiles = results.matchResults.compactMap { _, result in
                try? result.get()
            }.compactMap { UserProfile(from: $0) }

            // Filter profiles that were active in the time period
            let activeProfiles = profiles.filter { profile in
                // Check if profile was updated within the time range
                profile.modifiedTimestamp >= startDate && profile.modifiedTimestamp <= endDate
            }

            // Cache results
            activeProfiles.forEach { cacheProfile($0) }

            return Array(activeProfiles.prefix(limit))
        } catch {
            throw ProfileServiceError.networkError(error)
        }
    }

    func fetchRecentlyActiveProfiles(limit: Int) async throws -> [UserProfile] {
        let sevenDaysAgo = Date().addingTimeInterval(-7 * 24 * 60 * 60)
        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            NSPredicate(format: "privacyLevel == %@", ProfilePrivacyLevel.publicProfile.rawValue),
            NSPredicate(format: "modifiedTimestamp >= %@", sevenDaysAgo as NSDate)
        ])

        let query = CKQuery(recordType: "UserProfiles", predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "modifiedTimestamp", ascending: false)]

        do {
            let results = try await publicDatabase.records(matching: query, resultsLimit: limit)
            let profiles = results.matchResults.compactMap { _, result in
                try? result.get()
            }.compactMap { UserProfile(from: $0) }

            // Cache results
            profiles.forEach { cacheProfile($0) }

            return profiles
        } catch {
            throw ProfileServiceError.networkError(error)
        }
    }

    // MARK: - Caching

    func clearCache() {
        profileCache.removeAll()
    }

    func preloadProfiles(_ userIds: [String]) async {
        await withTaskGroup(of: Void.self) { group in
            for userId in userIds {
                group.addTask { [weak self] in
                    _ = try? await self?.fetchProfile(userId: userId)
                }
            }
        }
    }

    // MARK: - Public Cache Management

    func clearCache(for userId: String) {
        profileCache.removeValue(forKey: userId)
    }

    func clearAllCache() {
        profileCache.removeAll()
    }

    // MARK: - Private Methods
    
    private func fetchFreshUserStats(userId: String) async throws -> (workoutCount: Int, totalXP: Int) {
        // Fetch fresh stats directly from the Users record in private database
        let recordID = CKRecord.ID(recordName: userId)
        
        do {
            let userRecord = try await privateDatabase.record(for: recordID)
            let workoutCount = userRecord["totalWorkouts"] as? Int ?? 0
            let totalXP = userRecord["totalXP"] as? Int ?? 0
            
            print("🔍 Fresh stats from Users record:")
            print("   Record ID: \(recordID.recordName)")
            print("   totalWorkouts: \(userRecord["totalWorkouts"] ?? "nil")")
            print("   totalXP: \(userRecord["totalXP"] ?? "nil")")
            print("   Final values: workouts=\(workoutCount), XP=\(totalXP)")
            
            return (workoutCount: workoutCount, totalXP: totalXP)
        } catch {
            throw ProfileServiceError.networkError(error)
        }
    }

    private func getCachedProfile(userId: String) -> UserProfile? {
        guard let cached = profileCache[userId] else { return nil }

        // Check if cache is still valid
        if Date().timeIntervalSince(cached.timestamp) < cacheTTL {
            return cached.profile
        } else {
            // Cache expired
            profileCache.removeValue(forKey: userId)
            return nil
        }
    }

    private func cacheProfile(_ profile: UserProfile) {
        profileCache[profile.id] = (profile, Date())
    }

    private func validateProfile(_ profile: UserProfile) throws {
        guard case .success = validateUsername(profile.username) else {
            throw ProfileServiceError.invalidUsername
        }

        guard UserProfile.isValidUsername(profile.username) else {
            throw ProfileServiceError.invalidUsername
        }

        guard UserProfile.isValidBio(profile.bio) else {
            throw ProfileServiceError.invalidBio
        }
    }

    private func moderateContent(_ profile: UserProfile) throws {
        let contentToCheck = [
            profile.username.lowercased(),
            profile.username.lowercased(),
            profile.bio.lowercased()
        ]

        for content in contentToCheck {
            for word in inappropriateWords {
                if content.contains(word) {
                    throw ProfileServiceError.contentModerated
                }
            }
        }
    }
}

// MARK: - Photo Upload Extension

extension UserProfileService {
    /// Uploads a profile photo for the user
    /// - Parameters:
    ///   - image: The UIImage to upload
    ///   - userId: The user's profile ID
    ///   - isHeader: Whether this is a header image (false for profile photo)
    /// - Returns: The URL of the uploaded image
    func uploadProfilePhoto(_ image: UIImage, for userId: String, isHeader: Bool = false) async throws -> String {
        isLoading = true
        defer { isLoading = false }

        // Compress and resize the image
        let processedImage = try processImage(image, isHeader: isHeader)

        // Create a temporary file
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("jpg")

        guard let imageData = processedImage.jpegData(compressionQuality: 0.8) else {
            throw ProfileServiceError.imageProcessingFailed
        }

        try imageData.write(to: tempURL)

        // Create CKAsset
        let asset = CKAsset(fileURL: tempURL)

        // Fetch the user's profile record
        let recordID = CKRecord.ID(recordName: userId)

        do {
            let record = try await publicDatabase.record(for: recordID)

            // Update the appropriate field
            if isHeader {
                record["headerImageAsset"] = asset
            } else {
                record["profileImageAsset"] = asset
            }

            // Save the updated record
            let savedRecord = try await publicDatabase.save(record)

            // Clean up temp file
            try? FileManager.default.removeItem(at: tempURL)

            // Get the asset URL from the saved record
            if let savedAsset = savedRecord[isHeader ? "headerImageAsset" : "profileImageAsset"] as? CKAsset,
               let url = savedAsset.fileURL?.absoluteString {
                // Update the profile cache with the new URL
                if let profile = UserProfile(from: savedRecord) {
                    cacheProfile(profile)
                    if currentProfile?.id == profile.id {
                        currentProfile = profile
                    }
                }

                return url
            } else {
                throw ProfileServiceError.imageProcessingFailed
            }
        } catch {
            // Clean up temp file on error
            try? FileManager.default.removeItem(at: tempURL)
            throw ProfileServiceError.networkError(error)
        }
    }

    /// Deletes a profile photo
    func deleteProfilePhoto(for userId: String, isHeader: Bool = false) async throws {
        isLoading = true
        defer { isLoading = false }

        let recordID = CKRecord.ID(recordName: userId)

        do {
            let record = try await publicDatabase.record(for: recordID)

            // Remove the appropriate field
            if isHeader {
                record["headerImageAsset"] = nil
                record["headerImageURL"] = nil
            } else {
                record["profileImageAsset"] = nil
                record["profileImageURL"] = nil
            }

            // Save the updated record
            let savedRecord = try await publicDatabase.save(record)

            // Update cache
            if let profile = UserProfile(from: savedRecord) {
                cacheProfile(profile)
                if currentProfile?.id == profile.id {
                    currentProfile = profile
                }
            }
        } catch {
            throw ProfileServiceError.networkError(error)
        }
    }

    // MARK: - Private Photo Methods

    private func processImage(_ image: UIImage, isHeader: Bool) throws -> UIImage {
        let maxSize: CGFloat = isHeader ? 1_200 : 400 // Header images can be larger
        let targetSize = CGSize(width: maxSize, height: maxSize)

        // Calculate aspect ratio
        let widthRatio = targetSize.width / image.size.width
        let heightRatio = targetSize.height / image.size.height
        let ratio = isHeader ? min(widthRatio, heightRatio) : widthRatio // Headers maintain aspect, profiles are square

        let newSize = CGSize(
            width: image.size.width * ratio,
            height: image.size.height * ratio
        )

        // Create renderer
        let renderer = UIGraphicsImageRenderer(size: isHeader ? newSize : targetSize)

        let processedImage = renderer.image { _ in
            if isHeader {
                // Headers maintain aspect ratio
                image.draw(in: CGRect(origin: .zero, size: newSize))
            } else {
                // Profile photos are cropped to square
                let drawRect = CGRect(
                    x: (targetSize.width - newSize.width) / 2,
                    y: (targetSize.height - newSize.height) / 2,
                    width: newSize.width,
                    height: newSize.height
                )
                image.draw(in: drawRect)
            }
        }

        // Check file size (max 5MB for CloudKit)
        guard let data = processedImage.jpegData(compressionQuality: 0.8),
              data.count < 5 * 1_024 * 1_024
        else {
            // Try with lower quality
            guard let lowQualityData = processedImage.jpegData(compressionQuality: 0.5),
                  lowQualityData.count < 5 * 1_024 * 1_024
            else {
                throw ProfileServiceError.imageTooLarge
            }
            return processedImage
        }

        return processedImage
    }
}

// MARK: - Profile Service Error Extension

extension ProfileServiceError {
    static let imageProcessingFailed = ProfileServiceError.networkError(
        NSError(domain: "UserProfileService", code: 1_001, userInfo: [
            NSLocalizedDescriptionKey: "Failed to process image"
        ])
    )

    static let imageTooLarge = ProfileServiceError.networkError(
        NSError(domain: "UserProfileService", code: 1_002, userInfo: [
            NSLocalizedDescriptionKey: "Image file size is too large. Please choose a smaller image."
        ])
    )
}
