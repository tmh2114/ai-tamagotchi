import CloudKit
import Foundation
import Combine

/// CloudKit sync manager for AI Tamagotchi data synchronization
public class CloudKitSyncManager: ObservableObject {
    
    // MARK: - Properties
    
    /// Shared instance
    static let shared = CloudKitSyncManager()
    
    /// CloudKit container
    private let container = CloudKitContainer.shared
    
    /// Sync queue for offline operations
    private var syncQueue: [SyncOperation] = []
    
    /// Active sync operations
    private var activeSyncs = Set<String>()
    
    /// Sync status publisher
    @Published public var syncStatus: SyncStatus = .idle
    
    /// Last sync timestamp
    @Published public var lastSyncTime: Date?
    
    /// Network monitor
    private let networkMonitor = NetworkMonitor()
    
    /// Cancellables for Combine
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    private init() {
        setupNetworkMonitoring()
        loadSyncQueue()
    }
    
    // MARK: - Setup
    
    /// Setup network monitoring for automatic sync
    private func setupNetworkMonitoring() {
        networkMonitor.$isConnected
            .sink { [weak self] isConnected in
                if isConnected {
                    self?.processSyncQueue()
                }
            }
            .store(in: &cancellables)
    }
    
    /// Load pending sync operations from persistent storage
    private func loadSyncQueue() {
        if let data = UserDefaults.standard.data(forKey: "syncQueue"),
           let queue = try? JSONDecoder().decode([SyncOperation].self, from: data) {
            self.syncQueue = queue
        }
    }
    
    /// Save sync queue to persistent storage
    private func saveSyncQueue() {
        if let data = try? JSONEncoder().encode(syncQueue) {
            UserDefaults.standard.set(data, forKey: "syncQueue")
        }
    }
    
    // MARK: - Pet Data Sync
    
    /// Sync pet data to CloudKit
    public func syncPetData(_ pet: TamagotchiPet) async throws {
        syncStatus = .syncing
        
        let record = CKRecord(recordType: CloudKitRecordType.pet.rawValue)
        record["id"] = pet.id as CKRecordValue
        record["name"] = pet.name as CKRecordValue
        record["species"] = pet.species as CKRecordValue
        record["personality"] = pet.personality as CKRecordValue
        record["happiness"] = pet.happiness as CKRecordValue
        record["hunger"] = pet.hunger as CKRecordValue
        record["health"] = pet.health as CKRecordValue
        record["age"] = pet.age as CKRecordValue
        record["evolutionStage"] = pet.evolutionStage as CKRecordValue
        record["lastInteraction"] = pet.lastInteraction as CKRecordValue
        record["birthDate"] = pet.birthDate as CKRecordValue
        record["modifiedDate"] = Date() as CKRecordValue
        
        if let personalityData = try? JSONEncoder().encode(pet.personalityTraits) {
            record["personalityTraits"] = personalityData as CKRecordValue
        }
        
        do {
            _ = try await container.privateDatabase.save(record)
            lastSyncTime = Date()
            syncStatus = .success
        } catch {
            if !networkMonitor.isConnected {
                // Add to sync queue for later
                let operation = SyncOperation(
                    type: .create,
                    recordType: .pet,
                    data: pet.toDictionary(),
                    timestamp: Date()
                )
                addToSyncQueue(operation)
                syncStatus = .queued
            } else {
                syncStatus = .error(error)
                throw error
            }
        }
    }
    
    /// Fetch pet data from CloudKit
    public func fetchPetData() async throws -> TamagotchiPet? {
        syncStatus = .syncing
        
        let predicate = NSPredicate(value: true)
        let query = CKQuery(recordType: CloudKitRecordType.pet.rawValue, predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "modifiedDate", ascending: false)]
        
        do {
            let records = try await container.privateDatabase.records(matching: query)
            
            if let record = records.matchResults.first?.0,
               let result = try? records.matchResults.first?.1.get() {
                let pet = TamagotchiPet.from(record: result)
                lastSyncTime = Date()
                syncStatus = .success
                return pet
            }
            
            syncStatus = .success
            return nil
        } catch {
            syncStatus = .error(error)
            throw error
        }
    }
    
    // MARK: - Interaction History Sync
    
    /// Sync interaction history to CloudKit
    public func syncInteraction(_ interaction: Interaction) async throws {
        let record = CKRecord(recordType: CloudKitRecordType.interaction.rawValue)
        record["id"] = interaction.id as CKRecordValue
        record["petId"] = interaction.petId as CKRecordValue
        record["type"] = interaction.type as CKRecordValue
        record["message"] = interaction.message as CKRecordValue
        record["response"] = interaction.response as CKRecordValue
        record["timestamp"] = interaction.timestamp as CKRecordValue
        record["emotionalImpact"] = interaction.emotionalImpact as CKRecordValue
        
        do {
            _ = try await container.privateDatabase.save(record)
        } catch {
            if !networkMonitor.isConnected {
                let operation = SyncOperation(
                    type: .create,
                    recordType: .interaction,
                    data: interaction.toDictionary(),
                    timestamp: Date()
                )
                addToSyncQueue(operation)
            } else {
                throw error
            }
        }
    }
    
    /// Fetch interaction history from CloudKit
    public func fetchInteractionHistory(for petId: String, limit: Int = 100) async throws -> [Interaction] {
        let predicate = NSPredicate(format: "petId == %@", petId)
        let query = CKQuery(recordType: CloudKitRecordType.interaction.rawValue, predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
        
        let operation = CKQueryOperation(query: query)
        operation.resultsLimit = limit
        
        var interactions: [Interaction] = []
        
        do {
            let records = try await container.privateDatabase.records(matching: query)
            
            for (_, result) in records.matchResults {
                if case .success(let record) = result {
                    if let interaction = Interaction.from(record: record) {
                        interactions.append(interaction)
                    }
                }
            }
            
            return interactions
        } catch {
            throw error
        }
    }
    
    // MARK: - Achievement Sync
    
    /// Sync achievement to CloudKit
    public func syncAchievement(_ achievement: Achievement) async throws {
        let record = CKRecord(recordType: CloudKitRecordType.achievement.rawValue)
        record["id"] = achievement.id as CKRecordValue
        record["petId"] = achievement.petId as CKRecordValue
        record["type"] = achievement.type as CKRecordValue
        record["name"] = achievement.name as CKRecordValue
        record["description"] = achievement.description as CKRecordValue
        record["unlockedDate"] = achievement.unlockedDate as CKRecordValue
        
        do {
            _ = try await container.privateDatabase.save(record)
        } catch {
            if !networkMonitor.isConnected {
                let operation = SyncOperation(
                    type: .create,
                    recordType: .achievement,
                    data: achievement.toDictionary(),
                    timestamp: Date()
                )
                addToSyncQueue(operation)
            } else {
                throw error
            }
        }
    }
    
    // MARK: - Conflict Resolution
    
    /// Resolve sync conflicts between devices
    public func resolveConflict(local: CKRecord, remote: CKRecord) async throws -> CKRecord {
        // Implement last-write-wins strategy with metadata preservation
        guard let localModified = local["modifiedDate"] as? Date,
              let remoteModified = remote["modifiedDate"] as? Date else {
            return remote
        }
        
        if localModified > remoteModified {
            // Local is newer, update remote with local data
            return try await mergeRecords(base: remote, updates: local)
        } else {
            // Remote is newer, keep remote
            return remote
        }
    }
    
    /// Merge two records preserving important fields
    private func mergeRecords(base: CKRecord, updates: CKRecord) async throws -> CKRecord {
        let merged = base
        
        // Copy all fields from updates to base
        for key in updates.allKeys() {
            merged[key] = updates[key]
        }
        
        // Preserve certain fields from base if needed
        // For example, keep creation date from base
        if let creationDate = base["creationDate"] {
            merged["creationDate"] = creationDate
        }
        
        return merged
    }
    
    // MARK: - Sync Queue Management
    
    /// Add operation to sync queue
    private func addToSyncQueue(_ operation: SyncOperation) {
        syncQueue.append(operation)
        saveSyncQueue()
    }
    
    /// Process pending sync operations
    public func processSyncQueue() {
        guard networkMonitor.isConnected, !syncQueue.isEmpty else { return }
        
        Task {
            var failedOperations: [SyncOperation] = []
            
            for operation in syncQueue {
                do {
                    try await processOperation(operation)
                } catch {
                    failedOperations.append(operation)
                }
            }
            
            syncQueue = failedOperations
            saveSyncQueue()
        }
    }
    
    /// Process individual sync operation
    private func processOperation(_ operation: SyncOperation) async throws {
        switch operation.recordType {
        case .pet:
            if let pet = TamagotchiPet.from(dictionary: operation.data) {
                try await syncPetData(pet)
            }
        case .interaction:
            if let interaction = Interaction.from(dictionary: operation.data) {
                try await syncInteraction(interaction)
            }
        case .achievement:
            if let achievement = Achievement.from(dictionary: operation.data) {
                try await syncAchievement(achievement)
            }
        }
    }
    
    // MARK: - Full Sync
    
    /// Perform full sync of all data
    public func performFullSync() async throws {
        syncStatus = .syncing
        
        do {
            // Check account status first
            try await withCheckedThrowingContinuation { continuation in
                container.checkAccountStatus { available, error in
                    if available {
                        continuation.resume()
                    } else {
                        continuation.resume(throwing: error ?? CloudKitError.unknown)
                    }
                }
            }
            
            // Process sync queue first
            processSyncQueue()
            
            // Fetch latest data
            if let pet = try await fetchPetData() {
                // Update local storage with fetched data
                await MainActor.run {
                    NotificationCenter.default.post(
                        name: .petDataUpdated,
                        object: pet
                    )
                }
            }
            
            lastSyncTime = Date()
            syncStatus = .success
        } catch {
            syncStatus = .error(error)
            throw error
        }
    }
}

// MARK: - Supporting Types

/// CloudKit record types
enum CloudKitRecordType: String, CaseIterable {
    case pet = "Pet"
    case interaction = "Interaction"
    case achievement = "Achievement"
}

/// Sync status
enum SyncStatus: Equatable {
    case idle
    case syncing
    case success
    case queued
    case error(Error)
    
    static func == (lhs: SyncStatus, rhs: SyncStatus) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.syncing, .syncing), (.success, .success), (.queued, .queued):
            return true
        case (.error(let e1), .error(let e2)):
            return (e1 as NSError) == (e2 as NSError)
        default:
            return false
        }
    }
}

/// Sync operation for queue
struct SyncOperation: Codable {
    let id = UUID().uuidString
    let type: OperationType
    let recordType: CloudKitRecordType
    let data: [String: Any]
    let timestamp: Date
    
    enum OperationType: String, Codable {
        case create, update, delete
    }
    
    enum CodingKeys: String, CodingKey {
        case id, type, recordType, timestamp
    }
    
    init(type: OperationType, recordType: CloudKitRecordType, data: [String: Any], timestamp: Date) {
        self.type = type
        self.recordType = recordType
        self.data = data
        self.timestamp = timestamp
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        type = try container.decode(OperationType.self, forKey: .type)
        recordType = try container.decode(CloudKitRecordType.self, forKey: .recordType)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        data = [:] // Will need custom decoding for dictionary
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(type, forKey: .type)
        try container.encode(recordType, forKey: .recordType)
        try container.encode(timestamp, forKey: .timestamp)
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let petDataUpdated = Notification.Name("petDataUpdated")
    static let syncCompleted = Notification.Name("syncCompleted")
    static let syncFailed = Notification.Name("syncFailed")
}