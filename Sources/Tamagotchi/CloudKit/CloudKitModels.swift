import CloudKit
import Foundation

// MARK: - CloudKit Record Protocol

/// Protocol for types that can be converted to/from CloudKit records
public protocol CloudKitRecordable {
    static var recordType: String { get }
    
    init?(from record: CKRecord)
    func toRecord() -> CKRecord
    func updateRecord(_ record: CKRecord)
}

// MARK: - Pet CloudKit Model

public struct CloudKitPet: CloudKitRecordable {
    public let recordID: CKRecord.ID
    public var name: String
    public var species: String
    public var birthDate: Date
    public var personality: PersonalityData
    public var appearance: AppearanceData
    public var lastModified: Date
    public var syncVersion: Int
    
    public static var recordType: String {
        CloudKitConfiguration.RecordType.pet
    }
    
    public init(
        recordID: CKRecord.ID = CKRecord.ID(recordName: UUID().uuidString, zoneID: CloudKitConfiguration.petZoneID),
        name: String,
        species: String,
        birthDate: Date,
        personality: PersonalityData,
        appearance: AppearanceData
    ) {
        self.recordID = recordID
        self.name = name
        self.species = species
        self.birthDate = birthDate
        self.personality = personality
        self.appearance = appearance
        self.lastModified = Date()
        self.syncVersion = 1
    }
    
    public init?(from record: CKRecord) {
        guard record.recordType == Self.recordType else { return nil }
        
        self.recordID = record.recordID
        self.name = record[CloudKitConfiguration.FieldKeys.petName] as? String ?? ""
        self.species = record[CloudKitConfiguration.FieldKeys.petSpecies] as? String ?? ""
        self.birthDate = record[CloudKitConfiguration.FieldKeys.petBirthDate] as? Date ?? Date()
        
        // Decode personality data
        if let personalityData = record[CloudKitConfiguration.FieldKeys.petPersonality] as? Data,
           let personality = try? JSONDecoder().decode(PersonalityData.self, from: personalityData) {
            self.personality = personality
        } else {
            self.personality = PersonalityData()
        }
        
        // Decode appearance data
        if let appearanceData = record[CloudKitConfiguration.FieldKeys.petAppearance] as? Data,
           let appearance = try? JSONDecoder().decode(AppearanceData.self, from: appearanceData) {
            self.appearance = appearance
        } else {
            self.appearance = AppearanceData()
        }
        
        self.lastModified = record.modificationDate ?? Date()
        self.syncVersion = record[CloudKitConfiguration.FieldKeys.syncVersion] as? Int ?? 1
    }
    
    public func toRecord() -> CKRecord {
        let record = CKRecord(recordType: Self.recordType, recordID: recordID)
        updateRecord(record)
        return record
    }
    
    public func updateRecord(_ record: CKRecord) {
        record[CloudKitConfiguration.FieldKeys.petName] = name
        record[CloudKitConfiguration.FieldKeys.petSpecies] = species
        record[CloudKitConfiguration.FieldKeys.petBirthDate] = birthDate
        
        // Encode personality data
        if let personalityData = try? JSONEncoder().encode(personality) {
            record[CloudKitConfiguration.FieldKeys.petPersonality] = personalityData
        }
        
        // Encode appearance data
        if let appearanceData = try? JSONEncoder().encode(appearance) {
            record[CloudKitConfiguration.FieldKeys.petAppearance] = appearanceData
        }
        
        record[CloudKitConfiguration.FieldKeys.modifiedAt] = lastModified
        record[CloudKitConfiguration.FieldKeys.syncVersion] = syncVersion
        record[CloudKitConfiguration.FieldKeys.deviceID] = UIDevice.current.identifierForVendor?.uuidString
    }
}

// MARK: - Pet Stats CloudKit Model

public struct CloudKitPetStats: CloudKitRecordable {
    public let recordID: CKRecord.ID
    public let petRecordID: CKRecord.ID
    public var happiness: Double
    public var health: Double
    public var hunger: Double
    public var energy: Double
    public var experience: Int
    public var level: Int
    public var lastUpdated: Date
    
    public static var recordType: String {
        CloudKitConfiguration.RecordType.petStats
    }
    
    public init?(from record: CKRecord) {
        guard record.recordType == Self.recordType else { return nil }
        
        self.recordID = record.recordID
        
        if let petReference = record["pet"] as? CKRecord.Reference {
            self.petRecordID = petReference.recordID
        } else {
            return nil
        }
        
        self.happiness = record[CloudKitConfiguration.FieldKeys.happiness] as? Double ?? 0.5
        self.health = record[CloudKitConfiguration.FieldKeys.health] as? Double ?? 1.0
        self.hunger = record[CloudKitConfiguration.FieldKeys.hunger] as? Double ?? 0.5
        self.energy = record[CloudKitConfiguration.FieldKeys.energy] as? Double ?? 1.0
        self.experience = record[CloudKitConfiguration.FieldKeys.experience] as? Int ?? 0
        self.level = record[CloudKitConfiguration.FieldKeys.level] as? Int ?? 1
        self.lastUpdated = record.modificationDate ?? Date()
    }
    
    public func toRecord() -> CKRecord {
        let record = CKRecord(recordType: Self.recordType, recordID: recordID)
        updateRecord(record)
        return record
    }
    
    public func updateRecord(_ record: CKRecord) {
        record["pet"] = CKRecord.Reference(recordID: petRecordID, action: .deleteSelf)
        record[CloudKitConfiguration.FieldKeys.happiness] = happiness
        record[CloudKitConfiguration.FieldKeys.health] = health
        record[CloudKitConfiguration.FieldKeys.hunger] = hunger
        record[CloudKitConfiguration.FieldKeys.energy] = energy
        record[CloudKitConfiguration.FieldKeys.experience] = experience
        record[CloudKitConfiguration.FieldKeys.level] = level
        record[CloudKitConfiguration.FieldKeys.modifiedAt] = lastUpdated
    }
}

// MARK: - Interaction CloudKit Model

public struct CloudKitInteraction: CloudKitRecordable {
    public let recordID: CKRecord.ID
    public let petRecordID: CKRecord.ID
    public var type: InteractionType
    public var date: Date
    public var duration: TimeInterval
    public var response: String?
    public var emotionalImpact: Double
    
    public static var recordType: String {
        CloudKitConfiguration.RecordType.interaction
    }
    
    public enum InteractionType: String, Codable {
        case play
        case feed
        case talk
        case pet
        case train
        case sleep
        case wake
        case gift
    }
    
    public init?(from record: CKRecord) {
        guard record.recordType == Self.recordType else { return nil }
        
        self.recordID = record.recordID
        
        if let petReference = record["pet"] as? CKRecord.Reference {
            self.petRecordID = petReference.recordID
        } else {
            return nil
        }
        
        let typeString = record[CloudKitConfiguration.FieldKeys.interactionType] as? String ?? ""
        self.type = InteractionType(rawValue: typeString) ?? .play
        self.date = record[CloudKitConfiguration.FieldKeys.interactionDate] as? Date ?? Date()
        self.duration = record[CloudKitConfiguration.FieldKeys.interactionDuration] as? TimeInterval ?? 0
        self.response = record[CloudKitConfiguration.FieldKeys.interactionResponse] as? String
        self.emotionalImpact = record["emotionalImpact"] as? Double ?? 0
    }
    
    public func toRecord() -> CKRecord {
        let record = CKRecord(recordType: Self.recordType, recordID: recordID)
        updateRecord(record)
        return record
    }
    
    public func updateRecord(_ record: CKRecord) {
        record["pet"] = CKRecord.Reference(recordID: petRecordID, action: .deleteSelf)
        record[CloudKitConfiguration.FieldKeys.interactionType] = type.rawValue
        record[CloudKitConfiguration.FieldKeys.interactionDate] = date
        record[CloudKitConfiguration.FieldKeys.interactionDuration] = duration
        record[CloudKitConfiguration.FieldKeys.interactionResponse] = response
        record["emotionalImpact"] = emotionalImpact
    }
}

// MARK: - Memory CloudKit Model

public struct CloudKitMemory: CloudKitRecordable {
    public let recordID: CKRecord.ID
    public let petRecordID: CKRecord.ID
    public var content: String
    public var emotion: EmotionType
    public var importance: Double
    public var date: Date
    public var associations: [String]
    
    public static var recordType: String {
        CloudKitConfiguration.RecordType.memory
    }
    
    public enum EmotionType: String, Codable {
        case happy
        case sad
        case excited
        case calm
        case anxious
        case playful
        case tired
        case curious
    }
    
    public init?(from record: CKRecord) {
        guard record.recordType == Self.recordType else { return nil }
        
        self.recordID = record.recordID
        
        if let petReference = record["pet"] as? CKRecord.Reference {
            self.petRecordID = petReference.recordID
        } else {
            return nil
        }
        
        self.content = record[CloudKitConfiguration.FieldKeys.memoryContent] as? String ?? ""
        
        let emotionString = record[CloudKitConfiguration.FieldKeys.memoryEmotion] as? String ?? ""
        self.emotion = EmotionType(rawValue: emotionString) ?? .calm
        
        self.importance = record[CloudKitConfiguration.FieldKeys.memoryImportance] as? Double ?? 0.5
        self.date = record[CloudKitConfiguration.FieldKeys.memoryDate] as? Date ?? Date()
        self.associations = record["associations"] as? [String] ?? []
    }
    
    public func toRecord() -> CKRecord {
        let record = CKRecord(recordType: Self.recordType, recordID: recordID)
        updateRecord(record)
        return record
    }
    
    public func updateRecord(_ record: CKRecord) {
        record["pet"] = CKRecord.Reference(recordID: petRecordID, action: .deleteSelf)
        
        // Truncate content if needed for privacy
        let maxLength = CloudKitConfiguration.PrivacyConfiguration.maxMemoryContentLength
        let truncatedContent = content.count > maxLength ? String(content.prefix(maxLength)) : content
        
        record[CloudKitConfiguration.FieldKeys.memoryContent] = truncatedContent
        record[CloudKitConfiguration.FieldKeys.memoryEmotion] = emotion.rawValue
        record[CloudKitConfiguration.FieldKeys.memoryImportance] = importance
        record[CloudKitConfiguration.FieldKeys.memoryDate] = date
        record["associations"] = associations
    }
}

// MARK: - Supporting Data Types

public struct PersonalityData: Codable {
    public var traits: [String: Double]
    public var mood: String
    public var preferredActivities: [String]
    public var dislikes: [String]
    
    public init(
        traits: [String: Double] = [:],
        mood: String = "neutral",
        preferredActivities: [String] = [],
        dislikes: [String] = []
    ) {
        self.traits = traits
        self.mood = mood
        self.preferredActivities = preferredActivities
        self.dislikes = dislikes
    }
}

public struct AppearanceData: Codable {
    public var color: String
    public var size: String
    public var accessories: [String]
    public var customizations: [String: String]
    
    public init(
        color: String = "default",
        size: String = "medium",
        accessories: [String] = [],
        customizations: [String: String] = [:]
    ) {
        self.color = color
        self.size = size
        self.accessories = accessories
        self.customizations = customizations
    }
}

// MARK: - Batch Operations

public struct CloudKitBatchOperation {
    public let recordsToSave: [CKRecord]
    public let recordIDsToDelete: [CKRecord.ID]
    
    public init(save: [CKRecord] = [], delete: [CKRecord.ID] = []) {
        self.recordsToSave = save
        self.recordIDsToDelete = delete
    }
    
    public var isEmpty: Bool {
        recordsToSave.isEmpty && recordIDsToDelete.isEmpty
    }
    
    public var operationCount: Int {
        recordsToSave.count + recordIDsToDelete.count
    }
}

// MARK: - CloudKit Query Helpers

public extension CloudKitModels {
    /// Create a query for all pets
    static func allPetsQuery() -> CKQuery {
        CKQuery(
            recordType: CloudKitConfiguration.RecordType.pet,
            predicate: NSPredicate(value: true)
        )
    }
    
    /// Create a query for pet stats by pet ID
    static func statsQuery(for petID: CKRecord.ID) -> CKQuery {
        let reference = CKRecord.Reference(recordID: petID, action: .none)
        let predicate = NSPredicate(format: "pet == %@", reference)
        return CKQuery(
            recordType: CloudKitConfiguration.RecordType.petStats,
            predicate: predicate
        )
    }
    
    /// Create a query for recent interactions
    static func recentInteractionsQuery(for petID: CKRecord.ID, days: Int = 7) -> CKQuery {
        let reference = CKRecord.Reference(recordID: petID, action: .none)
        let dateLimit = Date().addingTimeInterval(-TimeInterval(days * 24 * 60 * 60))
        let predicate = NSPredicate(
            format: "pet == %@ AND %K >= %@",
            reference,
            CloudKitConfiguration.FieldKeys.interactionDate,
            dateLimit as NSDate
        )
        
        let query = CKQuery(
            recordType: CloudKitConfiguration.RecordType.interaction,
            predicate: predicate
        )
        query.sortDescriptors = [
            NSSortDescriptor(key: CloudKitConfiguration.FieldKeys.interactionDate, ascending: false)
        ]
        return query
    }
    
    /// Create a query for important memories
    static func importantMemoriesQuery(for petID: CKRecord.ID, threshold: Double = 0.7) -> CKQuery {
        let reference = CKRecord.Reference(recordID: petID, action: .none)
        let predicate = NSPredicate(
            format: "pet == %@ AND %K >= %f",
            reference,
            CloudKitConfiguration.FieldKeys.memoryImportance,
            threshold
        )
        
        let query = CKQuery(
            recordType: CloudKitConfiguration.RecordType.memory,
            predicate: predicate
        )
        query.sortDescriptors = [
            NSSortDescriptor(key: CloudKitConfiguration.FieldKeys.memoryImportance, ascending: false)
        ]
        return query
    }
}

// MARK: - Namespace

public enum CloudKitModels {}