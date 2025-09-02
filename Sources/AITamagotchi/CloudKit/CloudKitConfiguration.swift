import Foundation
import CloudKit

@MainActor
final class CloudKitConfiguration {
    
    static let shared = CloudKitConfiguration()
    
    let containerIdentifier = "iCloud.com.totomono.AITamagotchi"
    
    lazy var container: CKContainer = {
        CKContainer(identifier: containerIdentifier)
    }()
    
    lazy var privateDatabase: CKDatabase = {
        container.privateCloudDatabase
    }()
    
    lazy var sharedDatabase: CKDatabase = {
        container.sharedCloudDatabase
    }()
    
    lazy var publicDatabase: CKDatabase = {
        container.publicCloudDatabase
    }()
    
    struct RecordTypes {
        static let pet = "Pet"
        static let interaction = "Interaction"
        static let personality = "Personality"
        static let health = "HealthMetrics"
        static let achievement = "Achievement"
        static let settings = "UserSettings"
        static let memory = "Memory"
        static let syncMetadata = "SyncMetadata"
    }
    
    struct RecordKeys {
        struct Pet {
            static let id = "petID"
            static let name = "name"
            static let species = "species"
            static let birthDate = "birthDate"
            static let personalityData = "personalityData"
            static let healthData = "healthData"
            static let level = "level"
            static let experience = "experience"
            static let lastInteraction = "lastInteraction"
            static let modelVersion = "modelVersion"
            static let customization = "customization"
        }
        
        struct Interaction {
            static let id = "interactionID"
            static let petID = "petID"
            static let type = "interactionType"
            static let timestamp = "timestamp"
            static let duration = "duration"
            static let sentiment = "sentiment"
            static let content = "content"
            static let response = "response"
            static let impact = "impactMetrics"
        }
        
        struct Personality {
            static let id = "personalityID"
            static let petID = "petID"
            static let traits = "traits"
            static let preferences = "preferences"
            static let moodHistory = "moodHistory"
            static let relationshipLevel = "relationshipLevel"
            static let evolutionStage = "evolutionStage"
            static let lastUpdated = "lastUpdated"
        }
        
        struct HealthMetrics {
            static let id = "healthID"
            static let petID = "petID"
            static let happiness = "happiness"
            static let hunger = "hunger"
            static let energy = "energy"
            static let hygiene = "hygiene"
            static let health = "health"
            static let lastFed = "lastFed"
            static let lastPlayed = "lastPlayed"
            static let lastCleaned = "lastCleaned"
            static let timestamp = "timestamp"
        }
        
        struct Achievement {
            static let id = "achievementID"
            static let petID = "petID"
            static let type = "achievementType"
            static let unlockedDate = "unlockedDate"
            static let progress = "progress"
            static let metadata = "metadata"
        }
        
        struct UserSettings {
            static let id = "settingsID"
            static let userID = "userID"
            static let notifications = "notificationSettings"
            static let syncPreferences = "syncPreferences"
            static let privacySettings = "privacySettings"
            static let gameplaySettings = "gameplaySettings"
            static let lastModified = "lastModified"
        }
        
        struct Memory {
            static let id = "memoryID"
            static let petID = "petID"
            static let type = "memoryType"
            static let content = "content"
            static let embedding = "embedding"
            static let importance = "importance"
            static let timestamp = "timestamp"
            static let associations = "associations"
        }
        
        struct SyncMetadata {
            static let id = "syncID"
            static let deviceID = "deviceID"
            static let lastSyncDate = "lastSyncDate"
            static let syncToken = "syncToken"
            static let recordVersions = "recordVersions"
            static let conflicts = "conflicts"
        }
    }
    
    enum CloudKitError: LocalizedError {
        case containerNotAvailable
        case recordNotFound
        case syncConflict
        case quotaExceeded
        case networkUnavailable
        case permissionDenied
        case invalidConfiguration
        
        var errorDescription: String? {
            switch self {
            case .containerNotAvailable:
                return "iCloud container is not available"
            case .recordNotFound:
                return "Record not found in CloudKit"
            case .syncConflict:
                return "Sync conflict detected"
            case .quotaExceeded:
                return "iCloud storage quota exceeded"
            case .networkUnavailable:
                return "Network connection unavailable"
            case .permissionDenied:
                return "Permission denied for CloudKit operation"
            case .invalidConfiguration:
                return "CloudKit configuration is invalid"
            }
        }
    }
    
    func checkAccountStatus() async throws -> CKAccountStatus {
        try await container.accountStatus()
    }
    
    func requestPermission() async throws -> CKContainer.ApplicationPermissionStatus {
        try await container.requestApplicationPermission(.userDiscoverability)
    }
    
    func setupSubscriptions() async throws {
        let recordTypes = [
            RecordTypes.pet,
            RecordTypes.interaction,
            RecordTypes.personality,
            RecordTypes.health,
            RecordTypes.settings
        ]
        
        for recordType in recordTypes {
            let subscription = CKDatabaseSubscription(subscriptionID: "\(recordType)Subscription")
            
            let notificationInfo = CKSubscription.NotificationInfo()
            notificationInfo.shouldSendContentAvailable = true
            notificationInfo.shouldBadge = false
            subscription.notificationInfo = notificationInfo
            
            do {
                try await privateDatabase.save(subscription)
            } catch {
                if !error.localizedDescription.contains("duplicate") {
                    throw error
                }
            }
        }
    }
    
    private init() {}
}

extension CloudKitConfiguration {
    
    func createZoneIfNeeded() async throws {
        let zoneID = CKRecordZone.ID(zoneName: "AITamagotchiZone", ownerName: CKCurrentUserDefaultName)
        let zone = CKRecordZone(zoneID: zoneID)
        
        do {
            _ = try await privateDatabase.save(zone)
        } catch {
            if !error.localizedDescription.contains("duplicate") {
                throw error
            }
        }
    }
    
    var defaultZoneID: CKRecordZone.ID {
        CKRecordZone.ID(zoneName: "AITamagotchiZone", ownerName: CKCurrentUserDefaultName)
    }
}