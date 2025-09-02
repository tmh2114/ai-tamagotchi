import CloudKit
import SwiftData
import Combine
import os.log

/// Manages CloudKit synchronization for the AI Tamagotchi app
@MainActor
public class CloudKitSyncManager: ObservableObject {
    // MARK: - Properties
    
    @Published public private(set) var syncStatus: SyncStatus = .idle
    @Published public private(set) var lastSyncDate: Date?
    @Published public private(set) var syncProgress: Double = 0.0
    @Published public private(set) var syncErrors: [Error] = []
    
    private let container: CKContainer
    private let database: CKDatabase
    private var syncTimer: Timer?
    private var changeToken: CKServerChangeToken?
    private var cancellables = Set<AnyCancellable>()
    private let syncQueue = DispatchQueue(label: "com.tamagotchi.cloudkit.sync", qos: .background)
    
    // Sync state
    private var isSyncing = false
    private var pendingOperations: [CKDatabaseOperation] = []
    
    // MARK: - Initialization
    
    public init() {
        self.container = CloudKitConfiguration.container
        self.database = CloudKitConfiguration.privateDatabase
        
        loadChangeToken()
        setupNotificationHandling()
    }
    
    // MARK: - Public Methods
    
    /// Start automatic synchronization
    public func startSync() {
        guard !isSyncing else {
            CloudKitConfiguration.logger.info("Sync already in progress")
            return
        }
        
        Task {
            await performSync()
        }
        
        // Setup periodic sync if enabled
        if CloudKitConfiguration.SyncConfiguration.enableBackgroundSync {
            setupPeriodicSync()
        }
    }
    
    /// Stop automatic synchronization
    public func stopSync() {
        syncTimer?.invalidate()
        syncTimer = nil
        cancelPendingOperations()
    }
    
    /// Force immediate synchronization
    public func forceSync() async throws {
        guard !isSyncing else {
            throw CloudKitConfiguration.CloudKitError.syncInProgress
        }
        
        await performSync()
    }
    
    /// Upload local changes to CloudKit
    public func uploadChanges(_ records: [CKRecord]) async throws {
        syncStatus = .uploading
        
        // Split into batches
        let batches = records.chunked(into: CloudKitConfiguration.SyncConfiguration.batchSize)
        var totalUploaded = 0
        
        for batch in batches {
            try await uploadBatch(batch)
            totalUploaded += batch.count
            syncProgress = Double(totalUploaded) / Double(records.count)
        }
        
        syncStatus = .idle
        lastSyncDate = Date()
    }
    
    /// Download changes from CloudKit
    public func downloadChanges() async throws -> [CKRecord] {
        syncStatus = .downloading
        var allRecords: [CKRecord] = []
        
        let query = CKQuery(recordType: CloudKitConfiguration.RecordType.pet, predicate: NSPredicate(value: true))
        
        do {
            let records = try await fetchRecords(matching: query)
            allRecords.append(contentsOf: records)
            
            syncProgress = 1.0
            syncStatus = .idle
            lastSyncDate = Date()
            
            return allRecords
        } catch {
            syncStatus = .error(error)
            throw error
        }
    }
    
    /// Resolve conflict between local and remote records
    public func resolveConflict(
        local: CKRecord,
        remote: CKRecord,
        strategy: CloudKitConfiguration.ConflictResolutionStrategy = .merge
    ) async throws -> CKRecord {
        switch strategy {
        case .serverWins:
            return remote
            
        case .clientWins:
            // Update the record's change tag to match the server's version
            local.setParent(remote)
            return local
            
        case .merge:
            return mergeRecords(local: local, remote: remote)
            
        case .userChoice:
            // In a real app, this would present UI for user to choose
            // For now, default to merge
            return mergeRecords(local: local, remote: remote)
        }
    }
    
    // MARK: - Private Methods
    
    private func performSync() async {
        guard !isSyncing else { return }
        
        isSyncing = true
        syncStatus = .syncing
        syncProgress = 0.0
        
        do {
            // Check CloudKit availability
            let isAvailable = try await CloudKitConfiguration.checkAvailability()
            guard isAvailable else {
                throw CloudKitConfiguration.CloudKitError.containerNotAvailable
            }
            
            // Ensure zone exists
            try await CloudKitConfiguration.createZoneIfNeeded()
            
            // Fetch changes from CloudKit
            let changes = try await fetchChanges()
            syncProgress = 0.5
            
            // Process and apply changes
            await processChanges(changes)
            
            // Upload local changes
            let localChanges = await gatherLocalChanges()
            if !localChanges.isEmpty {
                try await uploadChanges(localChanges)
            }
            
            syncProgress = 1.0
            syncStatus = .idle
            lastSyncDate = Date()
            saveChangeToken()
            
        } catch {
            CloudKitConfiguration.logger.error("Sync failed: \(error.localizedDescription)")
            syncStatus = .error(error)
            syncErrors.append(error)
        }
        
        isSyncing = false
    }
    
    private func fetchChanges() async throws -> [CKRecord] {
        var allRecords: [CKRecord] = []
        var hasMoreChanges = true
        
        while hasMoreChanges {
            let options = CKFetchRecordZoneChangesOperation.ZoneConfiguration()
            options.previousServerChangeToken = changeToken
            
            let operation = CKFetchRecordZoneChangesOperation(
                recordZoneIDs: [CloudKitConfiguration.petZoneID],
                configurationsByRecordZoneID: [CloudKitConfiguration.petZoneID: options]
            )
            
            var fetchedRecords: [CKRecord] = []
            
            operation.recordWasChangedBlock = { _, result in
                switch result {
                case .success(let record):
                    fetchedRecords.append(record)
                case .failure(let error):
                    CloudKitConfiguration.logger.error("Failed to fetch record: \(error.localizedDescription)")
                }
            }
            
            operation.recordZoneFetchResultBlock = { zoneID, result in
                switch result {
                case .success(let (token, _, moreComing)):
                    self.changeToken = token
                    hasMoreChanges = moreComing
                case .failure(let error):
                    CloudKitConfiguration.logger.error("Zone fetch failed: \(error.localizedDescription)")
                    hasMoreChanges = false
                }
            }
            
            database.add(operation)
            
            // Wait for operation to complete
            await withCheckedContinuation { continuation in
                operation.fetchRecordZoneChangesResultBlock = { result in
                    continuation.resume()
                }
            }
            
            allRecords.append(contentsOf: fetchedRecords)
        }
        
        return allRecords
    }
    
    private func uploadBatch(_ records: [CKRecord]) async throws {
        let operation = CKModifyRecordsOperation(
            recordsToSave: records,
            recordIDsToDelete: nil
        )
        
        operation.savePolicy = .changedKeys
        operation.qualityOfService = .userInitiated
        
        return try await withCheckedThrowingContinuation { continuation in
            operation.modifyRecordsResultBlock = { result in
                switch result {
                case .success:
                    continuation.resume()
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
            
            database.add(operation)
        }
    }
    
    private func fetchRecords(matching query: CKQuery) async throws -> [CKRecord] {
        var allRecords: [CKRecord] = []
        var cursor: CKQueryOperation.Cursor?
        
        repeat {
            let operation: CKQueryOperation
            
            if let cursor = cursor {
                operation = CKQueryOperation(cursor: cursor)
            } else {
                operation = CKQueryOperation(query: query)
                operation.zoneID = CloudKitConfiguration.petZoneID
                operation.resultsLimit = CloudKitConfiguration.SyncConfiguration.batchSize
            }
            
            var fetchedRecords: [CKRecord] = []
            
            operation.recordMatchedBlock = { _, result in
                switch result {
                case .success(let record):
                    fetchedRecords.append(record)
                case .failure(let error):
                    CloudKitConfiguration.logger.error("Failed to match record: \(error.localizedDescription)")
                }
            }
            
            let result = try await withCheckedThrowingContinuation { continuation in
                operation.queryResultBlock = { result in
                    continuation.resume(with: result)
                }
                database.add(operation)
            }
            
            allRecords.append(contentsOf: fetchedRecords)
            cursor = try result.get()
            
        } while cursor != nil
        
        return allRecords
    }
    
    private func processChanges(_ records: [CKRecord]) async {
        // This would integrate with SwiftData to update local database
        // Implementation depends on your SwiftData models
        CloudKitConfiguration.logger.info("Processing \(records.count) changes from CloudKit")
        
        // Notify observers of changes
        NotificationCenter.default.post(
            name: .cloudKitDataChanged,
            object: nil,
            userInfo: ["records": records]
        )
    }
    
    private func gatherLocalChanges() async -> [CKRecord] {
        // This would query SwiftData for changes that need to be uploaded
        // Implementation depends on your SwiftData models
        return []
    }
    
    private func mergeRecords(local: CKRecord, remote: CKRecord) -> CKRecord {
        let merged = remote
        
        // Compare modification dates
        let localModified = local.modificationDate ?? Date.distantPast
        let remoteModified = remote.modificationDate ?? Date.distantPast
        
        // Merge strategy: newer values win for each field
        for key in local.allKeys() {
            if let localValue = local[key],
               let remoteValue = remote[key] {
                // For now, use the newer value
                // In a real app, this would be more sophisticated
                if localModified > remoteModified {
                    merged[key] = localValue
                }
            }
        }
        
        return merged
    }
    
    private func setupPeriodicSync() {
        syncTimer?.invalidate()
        syncTimer = Timer.scheduledTimer(
            withTimeInterval: CloudKitConfiguration.SyncConfiguration.syncInterval,
            repeats: true
        ) { _ in
            Task {
                await self.performSync()
            }
        }
    }
    
    private func setupNotificationHandling() {
        // Handle push notifications for real-time sync
        NotificationCenter.default.publisher(for: .cloudKitRemoteNotification)
            .sink { _ in
                Task {
                    await self.performSync()
                }
            }
            .store(in: &cancellables)
    }
    
    private func cancelPendingOperations() {
        pendingOperations.forEach { $0.cancel() }
        pendingOperations.removeAll()
    }
    
    // MARK: - Change Token Management
    
    private func loadChangeToken() {
        if let data = UserDefaults.standard.data(forKey: "CloudKitChangeToken"),
           let token = try? NSKeyedUnarchiver.unarchivedObject(ofClass: CKServerChangeToken.self, from: data) {
            changeToken = token
        }
    }
    
    private func saveChangeToken() {
        guard let changeToken = changeToken else { return }
        
        if let data = try? NSKeyedArchiver.archivedData(withRootObject: changeToken, requiringSecureCoding: true) {
            UserDefaults.standard.set(data, forKey: "CloudKitChangeToken")
        }
    }
}

// MARK: - Supporting Types

public extension CloudKitSyncManager {
    enum SyncStatus: Equatable {
        case idle
        case syncing
        case uploading
        case downloading
        case error(Error)
        
        public static func == (lhs: SyncStatus, rhs: SyncStatus) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle),
                 (.syncing, .syncing),
                 (.uploading, .uploading),
                 (.downloading, .downloading):
                return true
            case (.error(let e1), .error(let e2)):
                return (e1 as NSError) == (e2 as NSError)
            default:
                return false
            }
        }
        
        public var description: String {
            switch self {
            case .idle:
                return "Ready"
            case .syncing:
                return "Syncing..."
            case .uploading:
                return "Uploading..."
            case .downloading:
                return "Downloading..."
            case .error(let error):
                return "Error: \(error.localizedDescription)"
            }
        }
    }
}

// MARK: - Notifications

public extension Notification.Name {
    static let cloudKitDataChanged = Notification.Name("CloudKitDataChanged")
    static let cloudKitRemoteNotification = Notification.Name("CloudKitRemoteNotification")
    static let cloudKitSyncCompleted = Notification.Name("CloudKitSyncCompleted")
    static let cloudKitSyncFailed = Notification.Name("CloudKitSyncFailed")
}

// MARK: - Array Extension

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}

// MARK: - CKRecord Extension

private extension CKRecord {
    func setParent(_ parent: CKRecord) {
        self.parent = CKRecord.Reference(record: parent, action: .none)
    }
}