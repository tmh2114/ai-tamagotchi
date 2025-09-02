import Foundation
import SwiftUI
import CloudKit
import Combine

/// ViewModel for CloudKit sync operations
@MainActor
public class CloudKitViewModel: ObservableObject {
    
    // MARK: - Properties
    
    /// Sync manager instance
    private let syncManager = CloudKitSyncManager.shared
    
    /// Network monitor
    private let networkMonitor = NetworkMonitor.shared
    
    /// Current pet data
    @Published public var currentPet: TamagotchiPet?
    
    /// Interaction history
    @Published public var interactions: [Interaction] = []
    
    /// Achievements
    @Published public var achievements: [Achievement] = []
    
    /// Sync status
    @Published public var syncStatus: SyncStatus = .idle
    
    /// Last sync time
    @Published public var lastSyncTime: Date?
    
    /// Is syncing
    @Published public var isSyncing: Bool = false
    
    /// Error message
    @Published public var errorMessage: String?
    
    /// Auto-sync enabled
    @AppStorage("autoSyncEnabled") public var autoSyncEnabled: Bool = true
    
    /// Sync interval in seconds
    @AppStorage("syncInterval") public var syncInterval: TimeInterval = 300 // 5 minutes
    
    /// Cancellables
    private var cancellables = Set<AnyCancellable>()
    
    /// Auto-sync timer
    private var autoSyncTimer: Timer?
    
    // MARK: - Initialization
    
    public init() {
        setupBindings()
        setupAutoSync()
        checkCloudKitAvailability()
    }
    
    // MARK: - Setup
    
    /// Setup bindings to sync manager
    private func setupBindings() {
        syncManager.$syncStatus
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.syncStatus = status
                self?.isSyncing = status == .syncing
                
                if case .error(let error) = status {
                    self?.errorMessage = error.localizedDescription
                }
            }
            .store(in: &cancellables)
        
        syncManager.$lastSyncTime
            .receive(on: DispatchQueue.main)
            .assign(to: &$lastSyncTime)
        
        // Listen for network changes
        networkMonitor.$isConnected
            .sink { [weak self] isConnected in
                if isConnected && self?.autoSyncEnabled == true {
                    Task {
                        await self?.syncIfNeeded()
                    }
                }
            }
            .store(in: &cancellables)
        
        // Listen for pet data updates
        NotificationCenter.default.publisher(for: .petDataUpdated)
            .compactMap { $0.object as? TamagotchiPet }
            .receive(on: DispatchQueue.main)
            .assign(to: &$currentPet)
    }
    
    /// Setup auto-sync timer
    private func setupAutoSync() {
        guard autoSyncEnabled else { return }
        
        autoSyncTimer?.invalidate()
        autoSyncTimer = Timer.scheduledTimer(withTimeInterval: syncInterval, repeats: true) { [weak self] _ in
            Task {
                await self?.syncIfNeeded()
            }
        }
    }
    
    /// Check CloudKit availability
    private func checkCloudKitAvailability() {
        Task {
            do {
                let available = try await withCheckedThrowingContinuation { continuation in
                    CloudKitContainer.shared.checkAccountStatus { available, error in
                        if let error = error {
                            continuation.resume(throwing: error)
                        } else {
                            continuation.resume(returning: available)
                        }
                    }
                }
                
                if available {
                    await performInitialSync()
                } else {
                    errorMessage = "iCloud account not available. Please sign in to iCloud in Settings."
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
    
    // MARK: - Sync Operations
    
    /// Perform initial sync on app launch
    public func performInitialSync() async {
        do {
            try await syncManager.performFullSync()
            
            // Fetch interaction history if pet exists
            if let pet = currentPet {
                await fetchInteractionHistory(for: pet.id)
                await fetchAchievements(for: pet.id)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    /// Sync if needed based on last sync time
    public func syncIfNeeded() async {
        guard networkMonitor.shouldSync else { return }
        
        // Check if enough time has passed since last sync
        if let lastSync = lastSyncTime,
           Date().timeIntervalSince(lastSync) < 60 { // Don't sync more than once per minute
            return
        }
        
        await performSync()
    }
    
    /// Perform manual sync
    public func performSync() async {
        guard !isSyncing else { return }
        
        do {
            // Sync current pet data
            if let pet = currentPet {
                try await syncManager.syncPetData(pet)
            }
            
            // Process any queued operations
            syncManager.processSyncQueue()
            
            // Fetch latest data
            if let updatedPet = try await syncManager.fetchPetData() {
                currentPet = updatedPet
                
                // Fetch related data
                await fetchInteractionHistory(for: updatedPet.id)
                await fetchAchievements(for: updatedPet.id)
            }
            
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    // MARK: - Pet Operations
    
    /// Create new pet and sync to CloudKit
    public func createPet(name: String, species: String) async {
        let pet = TamagotchiPet(
            name: name,
            species: species,
            personality: "Friendly"
        )
        
        currentPet = pet
        
        do {
            try await syncManager.syncPetData(pet)
            errorMessage = nil
        } catch {
            errorMessage = "Failed to sync new pet: \(error.localizedDescription)"
        }
    }
    
    /// Update pet data and sync
    public func updatePet(_ pet: TamagotchiPet) async {
        currentPet = pet
        
        do {
            try await syncManager.syncPetData(pet)
            errorMessage = nil
        } catch {
            errorMessage = "Failed to sync pet updates: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Interaction Operations
    
    /// Add new interaction and sync
    public func addInteraction(
        type: String,
        message: String,
        response: String,
        emotionalImpact: Double = 0
    ) async {
        guard let pet = currentPet else { return }
        
        let interaction = Interaction(
            petId: pet.id,
            type: type,
            message: message,
            response: response,
            emotionalImpact: emotionalImpact
        )
        
        interactions.append(interaction)
        
        do {
            try await syncManager.syncInteraction(interaction)
            errorMessage = nil
        } catch {
            errorMessage = "Failed to sync interaction: \(error.localizedDescription)"
        }
    }
    
    /// Fetch interaction history
    public func fetchInteractionHistory(for petId: String) async {
        do {
            interactions = try await syncManager.fetchInteractionHistory(for: petId)
            errorMessage = nil
        } catch {
            errorMessage = "Failed to fetch interaction history: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Achievement Operations
    
    /// Unlock achievement and sync
    public func unlockAchievement(
        type: String,
        name: String,
        description: String
    ) async {
        guard let pet = currentPet else { return }
        
        let achievement = Achievement(
            petId: pet.id,
            type: type,
            name: name,
            description: description
        )
        
        achievements.append(achievement)
        
        do {
            try await syncManager.syncAchievement(achievement)
            errorMessage = nil
        } catch {
            errorMessage = "Failed to sync achievement: \(error.localizedDescription)"
        }
    }
    
    /// Fetch achievements
    public func fetchAchievements(for petId: String) async {
        // Implementation would fetch from CloudKit
        // For now, using local array
    }
    
    // MARK: - Settings
    
    /// Toggle auto-sync
    public func toggleAutoSync() {
        autoSyncEnabled.toggle()
        
        if autoSyncEnabled {
            setupAutoSync()
        } else {
            autoSyncTimer?.invalidate()
            autoSyncTimer = nil
        }
    }
    
    /// Update sync interval
    public func updateSyncInterval(_ interval: TimeInterval) {
        syncInterval = interval
        if autoSyncEnabled {
            setupAutoSync()
        }
    }
    
    // MARK: - Debug
    
    /// Force sync for debugging
    public func forceSync() async {
        await performSync()
    }
    
    /// Clear all CloudKit data (danger!)
    public func clearCloudKitData() async {
        // Implementation would delete all records
        // Use with caution
    }
}