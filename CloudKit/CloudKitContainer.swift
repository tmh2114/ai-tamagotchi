import CloudKit
import Foundation

/// CloudKit container configuration for AI Tamagotchi
public class CloudKitContainer {
    
    // MARK: - Properties
    
    /// Shared instance for CloudKit container
    static let shared = CloudKitContainer()
    
    /// CloudKit container identifier - should match your app's CloudKit container
    private let containerIdentifier = "iCloud.com.yourcompany.AITamagotchi"
    
    /// CloudKit container
    public let container: CKContainer
    
    /// Private database for user data
    public var privateDatabase: CKDatabase {
        container.privateCloudDatabase
    }
    
    /// Shared database for public features (if needed)
    public var sharedDatabase: CKDatabase {
        container.sharedCloudDatabase
    }
    
    /// Public database for leaderboards or community features
    public var publicDatabase: CKDatabase {
        container.publicCloudDatabase
    }
    
    // MARK: - Initialization
    
    private init() {
        self.container = CKContainer(identifier: containerIdentifier)
        setupSubscriptions()
    }
    
    // MARK: - Setup
    
    /// Setup CloudKit subscriptions for real-time sync
    private func setupSubscriptions() {
        // Subscribe to pet data changes
        createPetDataSubscription()
        
        // Subscribe to interaction history changes
        createInteractionSubscription()
        
        // Subscribe to achievement changes
        createAchievementSubscription()
    }
    
    // MARK: - Subscriptions
    
    /// Create subscription for pet data changes
    private func createPetDataSubscription() {
        let subscription = CKQuerySubscription(
            recordType: CloudKitRecordType.pet.rawValue,
            predicate: NSPredicate(value: true),
            options: [.firesOnRecordCreation, .firesOnRecordUpdate, .firesOnRecordDeletion]
        )
        
        let notificationInfo = CKSubscription.NotificationInfo()
        notificationInfo.shouldSendContentAvailable = true
        notificationInfo.alertBody = "Your Tamagotchi has been updated!"
        subscription.notificationInfo = notificationInfo
        
        privateDatabase.save(subscription) { _, error in
            if let error = error {
                print("Failed to create pet subscription: \(error)")
            }
        }
    }
    
    /// Create subscription for interaction history
    private func createInteractionSubscription() {
        let subscription = CKQuerySubscription(
            recordType: CloudKitRecordType.interaction.rawValue,
            predicate: NSPredicate(value: true),
            options: [.firesOnRecordCreation]
        )
        
        let notificationInfo = CKSubscription.NotificationInfo()
        notificationInfo.shouldSendContentAvailable = true
        subscription.notificationInfo = notificationInfo
        
        privateDatabase.save(subscription) { _, error in
            if let error = error {
                print("Failed to create interaction subscription: \(error)")
            }
        }
    }
    
    /// Create subscription for achievements
    private func createAchievementSubscription() {
        let subscription = CKQuerySubscription(
            recordType: CloudKitRecordType.achievement.rawValue,
            predicate: NSPredicate(value: true),
            options: [.firesOnRecordCreation]
        )
        
        let notificationInfo = CKSubscription.NotificationInfo()
        notificationInfo.shouldSendContentAvailable = true
        notificationInfo.alertBody = "New achievement unlocked!"
        subscription.notificationInfo = notificationInfo
        
        privateDatabase.save(subscription) { _, error in
            if let error = error {
                print("Failed to create achievement subscription: \(error)")
            }
        }
    }
    
    // MARK: - Account Status
    
    /// Check CloudKit account status
    public func checkAccountStatus(completion: @escaping (Bool, Error?) -> Void) {
        container.accountStatus { status, error in
            switch status {
            case .available:
                completion(true, nil)
            case .noAccount:
                completion(false, CloudKitError.noAccount)
            case .restricted:
                completion(false, CloudKitError.restricted)
            case .couldNotDetermine:
                completion(false, CloudKitError.couldNotDetermine)
            case .temporarilyUnavailable:
                completion(false, CloudKitError.temporarilyUnavailable)
            @unknown default:
                completion(false, CloudKitError.unknown)
            }
        }
    }
}

// MARK: - CloudKit Errors

enum CloudKitError: LocalizedError {
    case noAccount
    case restricted
    case couldNotDetermine
    case temporarilyUnavailable
    case unknown
    case syncConflict
    case networkError
    
    var errorDescription: String? {
        switch self {
        case .noAccount:
            return "iCloud account not available. Please sign in to iCloud in Settings."
        case .restricted:
            return "iCloud access is restricted."
        case .couldNotDetermine:
            return "Could not determine iCloud account status."
        case .temporarilyUnavailable:
            return "iCloud is temporarily unavailable."
        case .unknown:
            return "An unknown error occurred."
        case .syncConflict:
            return "Sync conflict detected. Resolving..."
        case .networkError:
            return "Network error. Data will sync when connection is restored."
        }
    }
}