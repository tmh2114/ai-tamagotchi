import Foundation
import CloudKit
import SwiftData
import Combine

@MainActor
final class CloudKitDataAdapter {
    
    private let syncManager = CloudKitSyncManager.shared
    private let configuration = CloudKitConfiguration.shared
    private var modelContext: ModelContext?
    private var cancellables = Set<AnyCancellable>()
    
    init(modelContext: ModelContext? = nil) {
        self.modelContext = modelContext
        setupObservers()
    }
    
    private func setupObservers() {
        NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave)
            .debounce(for: .seconds(1), scheduler: RunLoop.main)
            .sink { _ in
                Task {
                    await self.syncLocalChanges()
                }
            }
            .store(in: &cancellables)
    }
    
    func syncLocalChanges() async {
        guard let modelContext = modelContext else { return }
        
        do {
            let pets = try modelContext.fetch(FetchDescriptor<Pet>())
            for pet in pets where pet.needsSync {
                let record = createPetRecord(from: pet)
                try await uploadRecord(record)
                pet.needsSync = false
                pet.lastSyncDate = Date()
            }
            
            try modelContext.save()
        } catch {
            print("Failed to sync local changes: \(error)")
        }
    }
    
    func importCloudKitData() async throws {
        guard let modelContext = modelContext else { return }
        
        let query = CKQuery(
            recordType: CloudKitConfiguration.RecordTypes.pet,
            predicate: NSPredicate(value: true)
        )
        
        let records = try await configuration.privateDatabase.records(matching: query)
        
        for (_, result) in records.matchResults {
            switch result {
            case .success(let record):
                try await importPetRecord(record, into: modelContext)
            case .failure(let error):
                print("Failed to fetch record: \(error)")
            }
        }
        
        try modelContext.save()
    }
    
    private func createPetRecord(from pet: Pet) -> CKRecord {
        let model = PetCloudKitModel(
            id: pet.id,
            name: pet.name,
            species: pet.species,
            birthDate: pet.birthDate,
            level: pet.level,
            experience: pet.experience,
            lastInteraction: pet.lastInteraction,
            modelVersion: pet.modelVersion,
            customization: nil
        )
        
        return model.toCKRecord()
    }
    
    private func importPetRecord(_ record: CKRecord, into context: ModelContext) async throws {
        let cloudModel = try PetCloudKitModel.fromCKRecord(record)
        
        let fetchDescriptor = FetchDescriptor<Pet>(
            predicate: #Predicate { $0.id == cloudModel.id }
        )
        
        let existingPets = try context.fetch(fetchDescriptor)
        
        if let existingPet = existingPets.first {
            updatePet(existingPet, from: cloudModel)
        } else {
            let newPet = Pet(
                id: cloudModel.id,
                name: cloudModel.name,
                species: cloudModel.species,
                birthDate: cloudModel.birthDate
            )
            updatePet(newPet, from: cloudModel)
            context.insert(newPet)
        }
    }
    
    private func updatePet(_ pet: Pet, from model: PetCloudKitModel) {
        pet.name = model.name
        pet.species = model.species
        pet.birthDate = model.birthDate
        pet.level = model.level
        pet.experience = model.experience
        pet.lastInteraction = model.lastInteraction
        pet.modelVersion = model.modelVersion
        pet.lastSyncDate = Date()
        pet.needsSync = false
    }
    
    private func uploadRecord(_ record: CKRecord) async throws {
        _ = try await configuration.privateDatabase.save(record)
    }
    
    func resolveConflict(local: Pet, remote: PetCloudKitModel, strategy: CloudKitSyncManager.ConflictResolutionStrategy) {
        switch strategy {
        case .serverWins:
            updatePet(local, from: remote)
        case .clientWins:
            local.needsSync = true
        case .merge:
            if let remoteLastInteraction = remote.lastInteraction,
               let localLastInteraction = local.lastInteraction {
                local.lastInteraction = max(remoteLastInteraction, localLastInteraction)
            }
            local.level = max(local.level, remote.level)
            local.experience = max(local.experience, remote.experience)
        case .askUser:
            break
        }
    }
}

@Model
final class Pet {
    var id: UUID
    var name: String
    var species: String
    var birthDate: Date
    var level: Int
    var experience: Int
    var lastInteraction: Date?
    var modelVersion: String
    var lastSyncDate: Date?
    var needsSync: Bool
    
    init(id: UUID = UUID(), name: String, species: String, birthDate: Date) {
        self.id = id
        self.name = name
        self.species = species
        self.birthDate = birthDate
        self.level = 1
        self.experience = 0
        self.lastInteraction = Date()
        self.modelVersion = "1.0.0"
        self.needsSync = true
    }
}