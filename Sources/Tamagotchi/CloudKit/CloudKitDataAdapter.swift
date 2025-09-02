import CloudKit
import SwiftData
import Foundation

/// Adapter to bridge between SwiftData models and CloudKit records
@MainActor
public class CloudKitDataAdapter {
    private let modelContext: ModelContext
    private let syncManager: CloudKitSyncManager
    
    // Track synced records to avoid duplicates
    private var syncedRecordIDs: Set<String> = []
    
    public init(modelContext: ModelContext, syncManager: CloudKitSyncManager) {
        self.modelContext = modelContext
        self.syncManager = syncManager
    }
    
    // MARK: - SwiftData to CloudKit
    
    /// Convert SwiftData Pet to CloudKit record
    public func petToCloudKit(_ pet: Pet) -> CKRecord {
        let recordID = CKRecord.ID(
            recordName: pet.id.uuidString,
            zoneID: CloudKitConfiguration.petZoneID
        )
        
        let cloudKitPet = CloudKitPet(
            recordID: recordID,
            name: pet.name,
            species: pet.species.rawValue,
            birthDate: pet.birthDate,
            personality: PersonalityData(
                traits: pet.personality.traits,
                mood: pet.personality.currentMood.rawValue,
                preferredActivities: pet.personality.preferredActivities,
                dislikes: pet.personality.dislikes
            ),
            appearance: AppearanceData(
                color: pet.appearance.color,
                size: pet.appearance.size.rawValue,
                accessories: pet.appearance.accessories,
                customizations: pet.appearance.customizations
            )
        )
        
        return cloudKitPet.toRecord()
    }
    
    /// Convert SwiftData PetStats to CloudKit record
    public func statsToCloudKit(_ stats: PetStats, petID: UUID) -> CKRecord {
        let recordID = CKRecord.ID(
            recordName: "stats-\(petID.uuidString)",
            zoneID: CloudKitConfiguration.petZoneID
        )
        
        let petRecordID = CKRecord.ID(
            recordName: petID.uuidString,
            zoneID: CloudKitConfiguration.petZoneID
        )
        
        let record = CKRecord(recordType: CloudKitConfiguration.RecordType.petStats, recordID: recordID)
        record["pet"] = CKRecord.Reference(recordID: petRecordID, action: .deleteSelf)
        record[CloudKitConfiguration.FieldKeys.happiness] = stats.happiness
        record[CloudKitConfiguration.FieldKeys.health] = stats.health
        record[CloudKitConfiguration.FieldKeys.hunger] = stats.hunger
        record[CloudKitConfiguration.FieldKeys.energy] = stats.energy
        record[CloudKitConfiguration.FieldKeys.experience] = stats.experience
        record[CloudKitConfiguration.FieldKeys.level] = stats.level
        
        return record
    }
    
    /// Convert SwiftData Interaction to CloudKit record
    public func interactionToCloudKit(_ interaction: Interaction, petID: UUID) -> CKRecord {
        let recordID = CKRecord.ID(
            recordName: interaction.id.uuidString,
            zoneID: CloudKitConfiguration.petZoneID
        )
        
        let petRecordID = CKRecord.ID(
            recordName: petID.uuidString,
            zoneID: CloudKitConfiguration.petZoneID
        )
        
        let record = CKRecord(recordType: CloudKitConfiguration.RecordType.interaction, recordID: recordID)
        record["pet"] = CKRecord.Reference(recordID: petRecordID, action: .deleteSelf)
        record[CloudKitConfiguration.FieldKeys.interactionType] = interaction.type.rawValue
        record[CloudKitConfiguration.FieldKeys.interactionDate] = interaction.timestamp
        record[CloudKitConfiguration.FieldKeys.interactionDuration] = interaction.duration
        record[CloudKitConfiguration.FieldKeys.interactionResponse] = interaction.petResponse
        
        return record
    }
    
    /// Convert SwiftData Memory to CloudKit record
    public func memoryToCloudKit(_ memory: Memory, petID: UUID) -> CKRecord {
        let recordID = CKRecord.ID(
            recordName: memory.id.uuidString,
            zoneID: CloudKitConfiguration.petZoneID
        )
        
        let petRecordID = CKRecord.ID(
            recordName: petID.uuidString,
            zoneID: CloudKitConfiguration.petZoneID
        )
        
        let record = CKRecord(recordType: CloudKitConfiguration.RecordType.memory, recordID: recordID)
        record["pet"] = CKRecord.Reference(recordID: petRecordID, action: .deleteSelf)
        
        // Apply privacy settings
        let content = memory.content
        let maxLength = CloudKitConfiguration.PrivacyConfiguration.maxMemoryContentLength
        let truncatedContent = content.count > maxLength ? String(content.prefix(maxLength)) : content
        
        record[CloudKitConfiguration.FieldKeys.memoryContent] = truncatedContent
        record[CloudKitConfiguration.FieldKeys.memoryEmotion] = memory.emotionalContext
        record[CloudKitConfiguration.FieldKeys.memoryImportance] = memory.importance
        record[CloudKitConfiguration.FieldKeys.memoryDate] = memory.timestamp
        
        return record
    }
    
    // MARK: - CloudKit to SwiftData
    
    /// Update or create Pet from CloudKit record
    public func updatePetFromCloudKit(_ record: CKRecord) throws {
        guard let cloudKitPet = CloudKitPet(from: record) else {
            throw CloudKitConfiguration.CloudKitError.invalidData
        }
        
        let petID = UUID(uuidString: record.recordID.recordName) ?? UUID()
        
        // Check if pet already exists
        let descriptor = FetchDescriptor<Pet>(
            predicate: #Predicate { $0.id == petID }
        )
        
        let existingPets = try modelContext.fetch(descriptor)
        
        let pet: Pet
        if let existingPet = existingPets.first {
            // Update existing pet
            pet = existingPet
        } else {
            // Create new pet
            pet = Pet(
                id: petID,
                name: cloudKitPet.name,
                species: Pet.Species(rawValue: cloudKitPet.species) ?? .cat
            )
            modelContext.insert(pet)
        }
        
        // Update pet properties
        pet.name = cloudKitPet.name
        pet.species = Pet.Species(rawValue: cloudKitPet.species) ?? pet.species
        pet.birthDate = cloudKitPet.birthDate
        
        // Update personality
        pet.personality.traits = cloudKitPet.personality.traits
        pet.personality.currentMood = Pet.Mood(rawValue: cloudKitPet.personality.mood) ?? .neutral
        pet.personality.preferredActivities = cloudKitPet.personality.preferredActivities
        pet.personality.dislikes = cloudKitPet.personality.dislikes
        
        // Update appearance
        pet.appearance.color = cloudKitPet.appearance.color
        pet.appearance.size = Pet.Size(rawValue: cloudKitPet.appearance.size) ?? .medium
        pet.appearance.accessories = cloudKitPet.appearance.accessories
        pet.appearance.customizations = cloudKitPet.appearance.customizations
        
        // Mark as synced
        syncedRecordIDs.insert(record.recordID.recordName)
        
        try modelContext.save()
    }
    
    /// Update or create PetStats from CloudKit record
    public func updateStatsFromCloudKit(_ record: CKRecord) throws {
        guard let cloudKitStats = CloudKitPetStats(from: record) else {
            throw CloudKitConfiguration.CloudKitError.invalidData
        }
        
        let petID = UUID(uuidString: cloudKitStats.petRecordID.recordName) ?? UUID()
        
        // Find the associated pet
        let petDescriptor = FetchDescriptor<Pet>(
            predicate: #Predicate { $0.id == petID }
        )
        
        guard let pet = try modelContext.fetch(petDescriptor).first else {
            CloudKitConfiguration.logger.warning("Pet not found for stats: \(petID)")
            return
        }
        
        // Update stats
        pet.stats.happiness = cloudKitStats.happiness
        pet.stats.health = cloudKitStats.health
        pet.stats.hunger = cloudKitStats.hunger
        pet.stats.energy = cloudKitStats.energy
        pet.stats.experience = cloudKitStats.experience
        pet.stats.level = cloudKitStats.level
        
        try modelContext.save()
    }
    
    /// Update or create Interaction from CloudKit record
    public func updateInteractionFromCloudKit(_ record: CKRecord) throws {
        guard let cloudKitInteraction = CloudKitInteraction(from: record) else {
            throw CloudKitConfiguration.CloudKitError.invalidData
        }
        
        let interactionID = UUID(uuidString: record.recordID.recordName) ?? UUID()
        let petID = UUID(uuidString: cloudKitInteraction.petRecordID.recordName) ?? UUID()
        
        // Check if interaction already exists
        let descriptor = FetchDescriptor<Interaction>(
            predicate: #Predicate { $0.id == interactionID }
        )
        
        let existingInteractions = try modelContext.fetch(descriptor)
        
        if existingInteractions.isEmpty {
            // Find the associated pet
            let petDescriptor = FetchDescriptor<Pet>(
                predicate: #Predicate { $0.id == petID }
            )
            
            guard let pet = try modelContext.fetch(petDescriptor).first else {
                CloudKitConfiguration.logger.warning("Pet not found for interaction: \(petID)")
                return
            }
            
            // Create new interaction
            let interaction = Interaction(
                id: interactionID,
                type: Interaction.InteractionType(rawValue: cloudKitInteraction.type.rawValue) ?? .play,
                timestamp: cloudKitInteraction.date,
                duration: cloudKitInteraction.duration
            )
            
            interaction.petResponse = cloudKitInteraction.response
            pet.interactions.append(interaction)
            
            modelContext.insert(interaction)
        }
        
        try modelContext.save()
    }
    
    /// Update or create Memory from CloudKit record
    public func updateMemoryFromCloudKit(_ record: CKRecord) throws {
        guard let cloudKitMemory = CloudKitMemory(from: record) else {
            throw CloudKitConfiguration.CloudKitError.invalidData
        }
        
        let memoryID = UUID(uuidString: record.recordID.recordName) ?? UUID()
        let petID = UUID(uuidString: cloudKitMemory.petRecordID.recordName) ?? UUID()
        
        // Check if memory already exists
        let descriptor = FetchDescriptor<Memory>(
            predicate: #Predicate { $0.id == memoryID }
        )
        
        let existingMemories = try modelContext.fetch(descriptor)
        
        if existingMemories.isEmpty {
            // Find the associated pet
            let petDescriptor = FetchDescriptor<Pet>(
                predicate: #Predicate { $0.id == petID }
            )
            
            guard let pet = try modelContext.fetch(petDescriptor).first else {
                CloudKitConfiguration.logger.warning("Pet not found for memory: \(petID)")
                return
            }
            
            // Create new memory
            let memory = Memory(
                id: memoryID,
                content: cloudKitMemory.content,
                timestamp: cloudKitMemory.date,
                importance: cloudKitMemory.importance,
                emotionalContext: cloudKitMemory.emotion.rawValue
            )
            
            pet.memories.append(memory)
            modelContext.insert(memory)
        }
        
        try modelContext.save()
    }
    
    // MARK: - Batch Operations
    
    /// Sync all local changes to CloudKit
    public func syncLocalChangesToCloudKit() async throws {
        var recordsToUpload: [CKRecord] = []
        
        // Fetch all pets
        let petDescriptor = FetchDescriptor<Pet>()
        let pets = try modelContext.fetch(petDescriptor)
        
        for pet in pets {
            // Skip if already synced recently
            if syncedRecordIDs.contains(pet.id.uuidString) {
                continue
            }
            
            // Convert pet to CloudKit record
            recordsToUpload.append(petToCloudKit(pet))
            
            // Convert stats
            recordsToUpload.append(statsToCloudKit(pet.stats, petID: pet.id))
            
            // Convert recent interactions (last 100)
            let recentInteractions = pet.interactions
                .sorted { $0.timestamp > $1.timestamp }
                .prefix(100)
            
            for interaction in recentInteractions {
                recordsToUpload.append(interactionToCloudKit(interaction, petID: pet.id))
            }
            
            // Convert important memories
            let importantMemories = pet.memories
                .filter { $0.importance > 0.7 }
                .sorted { $0.importance > $1.importance }
                .prefix(50)
            
            for memory in importantMemories {
                recordsToUpload.append(memoryToCloudKit(memory, petID: pet.id))
            }
        }
        
        // Upload in batches
        if !recordsToUpload.isEmpty {
            try await syncManager.uploadChanges(recordsToUpload)
            
            // Mark all as synced
            for record in recordsToUpload {
                syncedRecordIDs.insert(record.recordID.recordName)
            }
        }
    }
    
    /// Process CloudKit changes and update local database
    public func processCloudKitChanges(_ records: [CKRecord]) async throws {
        for record in records {
            switch record.recordType {
            case CloudKitConfiguration.RecordType.pet:
                try updatePetFromCloudKit(record)
                
            case CloudKitConfiguration.RecordType.petStats:
                try updateStatsFromCloudKit(record)
                
            case CloudKitConfiguration.RecordType.interaction:
                try updateInteractionFromCloudKit(record)
                
            case CloudKitConfiguration.RecordType.memory:
                try updateMemoryFromCloudKit(record)
                
            default:
                CloudKitConfiguration.logger.warning("Unknown record type: \(record.recordType)")
            }
        }
    }
    
    // MARK: - Conflict Resolution
    
    /// Resolve conflicts between local and remote data
    public func resolveConflict(
        localRecord: CKRecord,
        remoteRecord: CKRecord,
        strategy: CloudKitConfiguration.ConflictResolutionStrategy = .merge
    ) async throws -> CKRecord {
        return try await syncManager.resolveConflict(
            local: localRecord,
            remote: remoteRecord,
            strategy: strategy
        )
    }
}

// MARK: - SwiftData Model Placeholders
// These would be defined in your SwiftData models

// Placeholder types - replace with your actual SwiftData models
struct Pet {
    let id: UUID
    var name: String
    var species: Species
    var birthDate: Date
    var personality: Personality
    var appearance: Appearance
    var stats: PetStats
    var interactions: [Interaction]
    var memories: [Memory]
    
    enum Species: String {
        case cat, dog, bird, fish, reptile
    }
    
    enum Mood: String {
        case happy, sad, excited, calm, anxious, playful, tired, neutral
    }
    
    enum Size: String {
        case small, medium, large
    }
    
    struct Personality {
        var traits: [String: Double]
        var currentMood: Mood
        var preferredActivities: [String]
        var dislikes: [String]
    }
    
    struct Appearance {
        var color: String
        var size: Size
        var accessories: [String]
        var customizations: [String: String]
    }
}

struct PetStats {
    var happiness: Double
    var health: Double
    var hunger: Double
    var energy: Double
    var experience: Int
    var level: Int
}

struct Interaction {
    let id: UUID
    var type: InteractionType
    var timestamp: Date
    var duration: TimeInterval
    var petResponse: String?
    
    enum InteractionType: String {
        case play, feed, talk, pet, train, sleep, wake, gift
    }
}

struct Memory {
    let id: UUID
    var content: String
    var timestamp: Date
    var importance: Double
    var emotionalContext: String
}