import Foundation
import CloudKit
import SwiftData
import Combine
import OSLog

@MainActor
final class CloudKitSyncManager: ObservableObject {
    
    static let shared = CloudKitSyncManager()
    
    private let configuration = CloudKitConfiguration.shared
    private let logger = Logger(subsystem: "com.totomono.AITamagotchi", category: "CloudKitSync")
    
    @Published private(set) var syncState: SyncState = .idle
    @Published private(set) var lastSyncDate: Date?
    @Published private(set) var isSyncing = false
    @Published private(set) var syncErrors: [SyncError] = []
    
    private var syncQueue = DispatchQueue(label: "com.totomono.AITamagotchi.syncQueue", qos: .background)
    private var cancellables = Set<AnyCancellable>()
    private var syncTimer: Timer?
    private var changeToken: CKServerChangeToken?
    
    enum SyncState {
        case idle
        case syncing
        case completed(Date)
        case failed(Error)
        case conflict([CKRecord])
        case offline
    }
    
    struct SyncError: Identifiable {
        let id = UUID()
        let timestamp: Date
        let error: Error
        let recordType: String?
        let operation: SyncOperation
        
        enum SyncOperation {
            case upload, download, delete, merge
        }
    }
    
    struct SyncOptions {
        var syncInterval: TimeInterval = 300
        var conflictResolution: ConflictResolutionStrategy = .serverWins
        var batchSize: Int = 100
        var retryAttempts: Int = 3
        var includeSharedData: Bool = true
        var syncOnCellular: Bool = false
    }
    
    enum ConflictResolutionStrategy {
        case serverWins
        case clientWins
        case merge
        case askUser
    }
    
    private var syncOptions = SyncOptions()
    
    private init() {
        setupNotifications()
        setupPeriodicSync()
        checkNetworkStatus()
    }
    
    func startSync() async {
        guard !isSyncing else { return }
        guard await checkCloudKitAvailability() else { return }
        
        isSyncing = true
        syncState = .syncing
        
        do {
            try await configuration.createZoneIfNeeded()
            try await configuration.setupSubscriptions()
            
            try await performFullSync()
            
            lastSyncDate = Date()
            syncState = .completed(Date())
            logger.info("Sync completed successfully")
        } catch {
            syncState = .failed(error)
            recordSyncError(error, operation: .download)
            logger.error("Sync failed: \(error.localizedDescription)")
        }
        
        isSyncing = false
    }
    
    private func performFullSync() async throws {
        try await downloadChanges()
        try await uploadLocalChanges()
        try await resolveConflicts()
        try await cleanupDeletedRecords()
    }
    
    private func downloadChanges() async throws {
        let database = configuration.privateDatabase
        let zoneID = configuration.defaultZoneID
        
        let options = CKFetchRecordZoneChangesOperation.ZoneConfiguration()
        options.previousServerChangeToken = changeToken
        
        let operation = CKFetchRecordZoneChangesOperation(
            recordZoneIDs: [zoneID],
            configurationsByRecordZoneID: [zoneID: options]
        )
        
        var fetchedRecords: [CKRecord] = []
        var deletedRecordIDs: [CKRecord.ID] = []
        
        operation.recordWasChangedBlock = { recordID, result in
            switch result {
            case .success(let record):
                fetchedRecords.append(record)
            case .failure(let error):
                self.logger.error("Failed to fetch record \(recordID): \(error)")
            }
        }
        
        operation.recordWithIDWasDeletedBlock = { recordID, recordType in
            deletedRecordIDs.append(recordID)
        }
        
        operation.recordZoneFetchResultBlock = { zoneID, result in
            switch result {
            case .success(let (token, _, _)):
                self.changeToken = token
            case .failure(let error):
                self.logger.error("Zone fetch failed: \(error)")
            }
        }
        
        database.add(operation)
        
        for record in fetchedRecords {
            try await processDownloadedRecord(record)
        }
        
        for recordID in deletedRecordIDs {
            try await processDeletedRecord(recordID)
        }
    }
    
    private func uploadLocalChanges() async throws {
        let recordsToUpload = try await gatherLocalChanges()
        
        guard !recordsToUpload.isEmpty else { return }
        
        let chunks = recordsToUpload.chunked(into: syncOptions.batchSize)
        
        for chunk in chunks {
            let operation = CKModifyRecordsOperation(
                recordsToSave: chunk,
                recordIDsToDelete: nil
            )
            
            operation.perRecordSaveBlock = { recordID, result in
                switch result {
                case .success(let record):
                    self.logger.debug("Uploaded record: \(recordID)")
                case .failure(let error):
                    self.recordSyncError(error, operation: .upload)
                }
            }
            
            operation.modifyRecordsResultBlock = { result in
                switch result {
                case .success:
                    self.logger.info("Batch upload completed")
                case .failure(let error):
                    self.recordSyncError(error, operation: .upload)
                }
            }
            
            configuration.privateDatabase.add(operation)
        }
    }
    
    private func resolveConflicts() async throws {
        switch syncOptions.conflictResolution {
        case .serverWins:
            break
        case .clientWins:
            try await forceUploadLocalChanges()
        case .merge:
            try await mergeConflictingRecords()
        case .askUser:
            await presentConflictResolution()
        }
    }
    
    private func cleanupDeletedRecords() async throws {
        
    }
    
    private func processDownloadedRecord(_ record: CKRecord) async throws {
        switch record.recordType {
        case CloudKitConfiguration.RecordTypes.pet:
            try await processPetRecord(record)
        case CloudKitConfiguration.RecordTypes.interaction:
            try await processInteractionRecord(record)
        case CloudKitConfiguration.RecordTypes.personality:
            try await processPersonalityRecord(record)
        case CloudKitConfiguration.RecordTypes.health:
            try await processHealthRecord(record)
        case CloudKitConfiguration.RecordTypes.settings:
            try await processSettingsRecord(record)
        default:
            logger.warning("Unknown record type: \(record.recordType)")
        }
    }
    
    private func processDeletedRecord(_ recordID: CKRecord.ID) async throws {
        logger.info("Processing deleted record: \(recordID.recordName)")
    }
    
    private func processPetRecord(_ record: CKRecord) async throws {
        
    }
    
    private func processInteractionRecord(_ record: CKRecord) async throws {
        
    }
    
    private func processPersonalityRecord(_ record: CKRecord) async throws {
        
    }
    
    private func processHealthRecord(_ record: CKRecord) async throws {
        
    }
    
    private func processSettingsRecord(_ record: CKRecord) async throws {
        
    }
    
    private func gatherLocalChanges() async throws -> [CKRecord] {
        []
    }
    
    private func forceUploadLocalChanges() async throws {
        
    }
    
    private func mergeConflictingRecords() async throws {
        
    }
    
    private func presentConflictResolution() async {
        
    }
    
    private func checkCloudKitAvailability() async -> Bool {
        do {
            let status = try await configuration.checkAccountStatus()
            switch status {
            case .available:
                return true
            case .noAccount:
                logger.error("No iCloud account")
                syncState = .failed(CloudKitConfiguration.CloudKitError.containerNotAvailable)
                return false
            case .restricted, .couldNotDetermine:
                logger.error("CloudKit restricted or unavailable")
                syncState = .failed(CloudKitConfiguration.CloudKitError.permissionDenied)
                return false
            case .temporarilyUnavailable:
                logger.warning("CloudKit temporarily unavailable")
                syncState = .offline
                return false
            @unknown default:
                return false
            }
        } catch {
            logger.error("Failed to check CloudKit status: \(error)")
            return false
        }
    }
    
    private func setupNotifications() {
        NotificationCenter.default.publisher(for: .CKAccountChanged)
            .sink { _ in
                Task {
                    await self.handleAccountChange()
                }
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { _ in
                Task {
                    await self.startSync()
                }
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)
            .sink { _ in
                self.pauseSync()
            }
            .store(in: &cancellables)
    }
    
    private func setupPeriodicSync() {
        syncTimer = Timer.scheduledTimer(withTimeInterval: syncOptions.syncInterval, repeats: true) { _ in
            Task {
                await self.startSync()
            }
        }
    }
    
    private func handleAccountChange() async {
        await checkCloudKitAvailability()
        await startSync()
    }
    
    private func pauseSync() {
        syncTimer?.invalidate()
    }
    
    private func resumeSync() {
        setupPeriodicSync()
    }
    
    private func checkNetworkStatus() {
        
    }
    
    private func recordSyncError(_ error: Error, operation: SyncError.SyncOperation, recordType: String? = nil) {
        let syncError = SyncError(
            timestamp: Date(),
            error: error,
            recordType: recordType,
            operation: operation
        )
        syncErrors.append(syncError)
        
        if syncErrors.count > 100 {
            syncErrors.removeFirst(syncErrors.count - 100)
        }
    }
    
    func configureSyncOptions(_ options: SyncOptions) {
        self.syncOptions = options
        syncTimer?.invalidate()
        setupPeriodicSync()
    }
    
    func clearSyncErrors() {
        syncErrors.removeAll()
    }
    
    func resetSync() async {
        changeToken = nil
        lastSyncDate = nil
        await startSync()
    }
}

extension CloudKitSyncManager {
    func handleRemoteNotification(_ userInfo: [AnyHashable: Any]) async {
        guard let notification = CKNotification(fromRemoteNotificationDictionary: userInfo) else { return }
        
        if notification.notificationType == .database {
            await startSync()
        }
    }
}

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}