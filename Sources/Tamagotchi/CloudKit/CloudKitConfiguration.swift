import CloudKit
import SwiftUI
import os.log

/// CloudKit configuration and constants for the AI Tamagotchi app
public struct CloudKitConfiguration {
    // MARK: - Container Configuration
    
    /// The CloudKit container identifier
    public static let containerIdentifier = "iCloud.com.tamagotchi.ai"
    
    /// Shared CloudKit container instance
    public static let container = CKContainer(identifier: containerIdentifier)
    
    /// Private CloudKit database for user data
    public static let privateDatabase = container.privateCloudDatabase
    
    /// Shared CloudKit database for community features (future)
    public static let sharedDatabase = container.sharedCloudDatabase
    
    // MARK: - Record Types
    
    public enum RecordType {
        static let pet = "Pet"
        static let petStats = "PetStats"
        static let interaction = "Interaction"
        static let memory = "Memory"
        static let achievement = "Achievement"
        static let settings = "Settings"
        static let personality = "Personality"
        static let relationship = "Relationship"
    }
    
    // MARK: - Zone Configuration
    
    /// Custom zone for all pet data
    public static let petZone = CKRecordZone(zoneName: "PetDataZone")
    
    /// Zone ID for the pet data zone
    public static let petZoneID = CKRecordZone.ID(
        zoneName: "PetDataZone",
        ownerName: CKCurrentUserDefaultName
    )
    
    // MARK: - Subscription Configuration
    
    /// Subscription ID for pet data changes
    public static let petDataSubscriptionID = "pet-data-subscription"
    
    // MARK: - Field Keys
    
    public enum FieldKeys {
        // Pet fields
        static let petName = "name"
        static let petSpecies = "species"
        static let petBirthDate = "birthDate"
        static let petPersonality = "personality"
        static let petAppearance = "appearance"
        
        // Stats fields
        static let happiness = "happiness"
        static let health = "health"
        static let hunger = "hunger"
        static let energy = "energy"
        static let experience = "experience"
        static let level = "level"
        
        // Interaction fields
        static let interactionType = "type"
        static let interactionDate = "date"
        static let interactionDuration = "duration"
        static let interactionResponse = "response"
        
        // Memory fields
        static let memoryContent = "content"
        static let memoryEmotion = "emotion"
        static let memoryImportance = "importance"
        static let memoryDate = "date"
        
        // Common fields
        static let createdAt = "createdAt"
        static let modifiedAt = "modifiedAt"
        static let deviceID = "deviceID"
        static let syncVersion = "syncVersion"
    }
    
    // MARK: - Sync Configuration
    
    public struct SyncConfiguration {
        /// Maximum number of records to fetch in a single operation
        public static let batchSize = 100
        
        /// Sync interval in seconds (5 minutes)
        public static let syncInterval: TimeInterval = 300
        
        /// Maximum retry attempts for failed operations
        public static let maxRetryAttempts = 3
        
        /// Retry delay in seconds
        public static let retryDelay: TimeInterval = 2.0
        
        /// Enable automatic background sync
        public static let enableBackgroundSync = true
        
        /// Enable push notifications for real-time sync
        public static let enablePushNotifications = true
    }
    
    // MARK: - Error Handling
    
    public enum CloudKitError: LocalizedError {
        case containerNotAvailable
        case zoneCreationFailed
        case subscriptionFailed
        case syncInProgress
        case networkUnavailable
        case quotaExceeded
        case unauthorized
        case conflictResolutionFailed
        case recordNotFound
        case invalidData
        
        public var errorDescription: String? {
            switch self {
            case .containerNotAvailable:
                return "iCloud container is not available. Please check your iCloud settings."
            case .zoneCreationFailed:
                return "Failed to create CloudKit zone for pet data."
            case .subscriptionFailed:
                return "Failed to subscribe to CloudKit changes."
            case .syncInProgress:
                return "A sync operation is already in progress."
            case .networkUnavailable:
                return "Network connection is unavailable."
            case .quotaExceeded:
                return "iCloud storage quota exceeded."
            case .unauthorized:
                return "Not authorized to access iCloud data."
            case .conflictResolutionFailed:
                return "Failed to resolve data conflict."
            case .recordNotFound:
                return "Record not found in CloudKit."
            case .invalidData:
                return "Invalid data format in CloudKit record."
            }
        }
        
        public var recoverySuggestion: String? {
            switch self {
            case .containerNotAvailable, .unauthorized:
                return "Sign in to iCloud in Settings and enable iCloud Drive for this app."
            case .networkUnavailable:
                return "Check your internet connection and try again."
            case .quotaExceeded:
                return "Free up iCloud storage space or upgrade your storage plan."
            case .syncInProgress:
                return "Wait for the current sync to complete."
            default:
                return "Try again later or contact support if the problem persists."
            }
        }
    }
    
    // MARK: - Logging
    
    /// Logger for CloudKit operations
    public static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.tamagotchi.ai",
        category: "CloudKit"
    )
    
    // MARK: - Conflict Resolution
    
    public enum ConflictResolutionStrategy {
        case serverWins
        case clientWins
        case merge
        case userChoice
    }
    
    // MARK: - Privacy Configuration
    
    public struct PrivacyConfiguration {
        /// Encrypt sensitive data before uploading
        public static let encryptSensitiveData = true
        
        /// Fields to exclude from sync (privacy-sensitive)
        public static let excludedFields: Set<String> = [
            "localNotificationToken",
            "debugLogs"
        ]
        
        /// Maximum memory content length to sync
        public static let maxMemoryContentLength = 1000
    }
}

// MARK: - CloudKit Availability

public extension CloudKitConfiguration {
    /// Check if CloudKit is available
    static func checkAvailability(completion: @escaping (Result<Bool, Error>) -> Void) {
        container.accountStatus { status, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            switch status {
            case .available:
                completion(.success(true))
            case .noAccount:
                completion(.failure(CloudKitError.unauthorized))
            case .restricted, .couldNotDetermine:
                completion(.failure(CloudKitError.containerNotAvailable))
            case .temporarilyUnavailable:
                completion(.failure(CloudKitError.networkUnavailable))
            @unknown default:
                completion(.failure(CloudKitError.containerNotAvailable))
            }
        }
    }
    
    /// Check if CloudKit is available (async)
    @available(iOS 15.0, watchOS 8.0, *)
    static func checkAvailability() async throws -> Bool {
        try await withCheckedThrowingContinuation { continuation in
            checkAvailability { result in
                continuation.resume(with: result)
            }
        }
    }
}

// MARK: - Zone Management

public extension CloudKitConfiguration {
    /// Create the custom zone if it doesn't exist
    static func createZoneIfNeeded(completion: @escaping (Result<Void, Error>) -> Void) {
        let operation = CKModifyRecordZonesOperation(
            recordZonesToSave: [petZone],
            recordZoneIDsToDelete: nil
        )
        
        operation.modifyRecordZonesResultBlock = { result in
            switch result {
            case .success:
                logger.info("Successfully created CloudKit zone")
                completion(.success(()))
            case .failure(let error):
                // Zone might already exist, which is fine
                if (error as NSError).code == CKError.serverRecordChanged.rawValue {
                    completion(.success(()))
                } else {
                    logger.error("Failed to create CloudKit zone: \(error.localizedDescription)")
                    completion(.failure(CloudKitError.zoneCreationFailed))
                }
            }
        }
        
        privateDatabase.add(operation)
    }
    
    /// Create the custom zone if it doesn't exist (async)
    @available(iOS 15.0, watchOS 8.0, *)
    static func createZoneIfNeeded() async throws {
        try await withCheckedThrowingContinuation { continuation in
            createZoneIfNeeded { result in
                continuation.resume(with: result)
            }
        }
    }
}

// MARK: - Subscription Management

public extension CloudKitConfiguration {
    /// Create subscription for pet data changes
    static func createSubscription(completion: @escaping (Result<Void, Error>) -> Void) {
        let subscription = CKRecordZoneSubscription(
            zoneID: petZoneID,
            subscriptionID: petDataSubscriptionID
        )
        
        let notificationInfo = CKSubscription.NotificationInfo()
        notificationInfo.shouldSendContentAvailable = true
        notificationInfo.alertBody = "Your pet data has been updated"
        subscription.notificationInfo = notificationInfo
        
        privateDatabase.save(subscription) { _, error in
            if let error = error {
                // Subscription might already exist
                if (error as NSError).code == CKError.serverRejectedRequest.rawValue {
                    completion(.success(()))
                } else {
                    logger.error("Failed to create subscription: \(error.localizedDescription)")
                    completion(.failure(CloudKitError.subscriptionFailed))
                }
            } else {
                logger.info("Successfully created CloudKit subscription")
                completion(.success(()))
            }
        }
    }
    
    /// Create subscription for pet data changes (async)
    @available(iOS 15.0, watchOS 8.0, *)
    static func createSubscription() async throws {
        try await withCheckedThrowingContinuation { continuation in
            createSubscription { result in
                continuation.resume(with: result)
            }
        }
    }
}