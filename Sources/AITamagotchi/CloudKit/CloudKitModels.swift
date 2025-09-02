import Foundation
import CloudKit
import SwiftData

protocol CloudKitConvertible {
    associatedtype RecordType
    
    func toCKRecord() -> CKRecord
    static func fromCKRecord(_ record: CKRecord) throws -> RecordType
}

extension CKRecord {
    
    func setEncryptedValue<T: Codable>(_ value: T, forKey key: String) throws {
        let encoder = JSONEncoder()
        let data = try encoder.encode(value)
        self[key] = data as CKRecordValue
    }
    
    func encryptedValue<T: Codable>(_ type: T.Type, forKey key: String) throws -> T? {
        guard let data = self[key] as? Data else { return nil }
        let decoder = JSONDecoder()
        return try decoder.decode(type, from: data)
    }
}

struct PetCloudKitModel: CloudKitConvertible {
    let id: UUID
    let name: String
    let species: String
    let birthDate: Date
    let level: Int
    let experience: Int
    let lastInteraction: Date?
    let modelVersion: String
    let customization: Data?
    
    func toCKRecord() -> CKRecord {
        let recordID = CKRecord.ID(recordName: id.uuidString, zoneID: CloudKitConfiguration.shared.defaultZoneID)
        let record = CKRecord(recordType: CloudKitConfiguration.RecordTypes.pet, recordID: recordID)
        
        record[CloudKitConfiguration.RecordKeys.Pet.id] = id.uuidString
        record[CloudKitConfiguration.RecordKeys.Pet.name] = name
        record[CloudKitConfiguration.RecordKeys.Pet.species] = species
        record[CloudKitConfiguration.RecordKeys.Pet.birthDate] = birthDate
        record[CloudKitConfiguration.RecordKeys.Pet.level] = level
        record[CloudKitConfiguration.RecordKeys.Pet.experience] = experience
        record[CloudKitConfiguration.RecordKeys.Pet.lastInteraction] = lastInteraction
        record[CloudKitConfiguration.RecordKeys.Pet.modelVersion] = modelVersion
        record[CloudKitConfiguration.RecordKeys.Pet.customization] = customization
        
        return record
    }
    
    static func fromCKRecord(_ record: CKRecord) throws -> PetCloudKitModel {
        guard let idString = record[CloudKitConfiguration.RecordKeys.Pet.id] as? String,
              let id = UUID(uuidString: idString),
              let name = record[CloudKitConfiguration.RecordKeys.Pet.name] as? String,
              let species = record[CloudKitConfiguration.RecordKeys.Pet.species] as? String,
              let birthDate = record[CloudKitConfiguration.RecordKeys.Pet.birthDate] as? Date,
              let level = record[CloudKitConfiguration.RecordKeys.Pet.level] as? Int,
              let experience = record[CloudKitConfiguration.RecordKeys.Pet.experience] as? Int,
              let modelVersion = record[CloudKitConfiguration.RecordKeys.Pet.modelVersion] as? String
        else {
            throw CloudKitConfiguration.CloudKitError.recordNotFound
        }
        
        return PetCloudKitModel(
            id: id,
            name: name,
            species: species,
            birthDate: birthDate,
            level: level,
            experience: experience,
            lastInteraction: record[CloudKitConfiguration.RecordKeys.Pet.lastInteraction] as? Date,
            modelVersion: modelVersion,
            customization: record[CloudKitConfiguration.RecordKeys.Pet.customization] as? Data
        )
    }
}

struct InteractionCloudKitModel: CloudKitConvertible {
    let id: UUID
    let petID: UUID
    let type: String
    let timestamp: Date
    let duration: TimeInterval
    let sentiment: Double
    let content: String?
    let response: String?
    let impact: Data?
    
    func toCKRecord() -> CKRecord {
        let recordID = CKRecord.ID(recordName: id.uuidString, zoneID: CloudKitConfiguration.shared.defaultZoneID)
        let record = CKRecord(recordType: CloudKitConfiguration.RecordTypes.interaction, recordID: recordID)
        
        record[CloudKitConfiguration.RecordKeys.Interaction.id] = id.uuidString
        record[CloudKitConfiguration.RecordKeys.Interaction.petID] = petID.uuidString
        record[CloudKitConfiguration.RecordKeys.Interaction.type] = type
        record[CloudKitConfiguration.RecordKeys.Interaction.timestamp] = timestamp
        record[CloudKitConfiguration.RecordKeys.Interaction.duration] = duration
        record[CloudKitConfiguration.RecordKeys.Interaction.sentiment] = sentiment
        record[CloudKitConfiguration.RecordKeys.Interaction.content] = content
        record[CloudKitConfiguration.RecordKeys.Interaction.response] = response
        record[CloudKitConfiguration.RecordKeys.Interaction.impact] = impact
        
        return record
    }
    
    static func fromCKRecord(_ record: CKRecord) throws -> InteractionCloudKitModel {
        guard let idString = record[CloudKitConfiguration.RecordKeys.Interaction.id] as? String,
              let id = UUID(uuidString: idString),
              let petIDString = record[CloudKitConfiguration.RecordKeys.Interaction.petID] as? String,
              let petID = UUID(uuidString: petIDString),
              let type = record[CloudKitConfiguration.RecordKeys.Interaction.type] as? String,
              let timestamp = record[CloudKitConfiguration.RecordKeys.Interaction.timestamp] as? Date,
              let duration = record[CloudKitConfiguration.RecordKeys.Interaction.duration] as? TimeInterval,
              let sentiment = record[CloudKitConfiguration.RecordKeys.Interaction.sentiment] as? Double
        else {
            throw CloudKitConfiguration.CloudKitError.recordNotFound
        }
        
        return InteractionCloudKitModel(
            id: id,
            petID: petID,
            type: type,
            timestamp: timestamp,
            duration: duration,
            sentiment: sentiment,
            content: record[CloudKitConfiguration.RecordKeys.Interaction.content] as? String,
            response: record[CloudKitConfiguration.RecordKeys.Interaction.response] as? String,
            impact: record[CloudKitConfiguration.RecordKeys.Interaction.impact] as? Data
        )
    }
}

struct PersonalityCloudKitModel: CloudKitConvertible {
    let id: UUID
    let petID: UUID
    let traits: Data
    let preferences: Data
    let moodHistory: Data
    let relationshipLevel: Int
    let evolutionStage: String
    let lastUpdated: Date
    
    func toCKRecord() -> CKRecord {
        let recordID = CKRecord.ID(recordName: id.uuidString, zoneID: CloudKitConfiguration.shared.defaultZoneID)
        let record = CKRecord(recordType: CloudKitConfiguration.RecordTypes.personality, recordID: recordID)
        
        record[CloudKitConfiguration.RecordKeys.Personality.id] = id.uuidString
        record[CloudKitConfiguration.RecordKeys.Personality.petID] = petID.uuidString
        record[CloudKitConfiguration.RecordKeys.Personality.traits] = traits
        record[CloudKitConfiguration.RecordKeys.Personality.preferences] = preferences
        record[CloudKitConfiguration.RecordKeys.Personality.moodHistory] = moodHistory
        record[CloudKitConfiguration.RecordKeys.Personality.relationshipLevel] = relationshipLevel
        record[CloudKitConfiguration.RecordKeys.Personality.evolutionStage] = evolutionStage
        record[CloudKitConfiguration.RecordKeys.Personality.lastUpdated] = lastUpdated
        
        return record
    }
    
    static func fromCKRecord(_ record: CKRecord) throws -> PersonalityCloudKitModel {
        guard let idString = record[CloudKitConfiguration.RecordKeys.Personality.id] as? String,
              let id = UUID(uuidString: idString),
              let petIDString = record[CloudKitConfiguration.RecordKeys.Personality.petID] as? String,
              let petID = UUID(uuidString: petIDString),
              let traits = record[CloudKitConfiguration.RecordKeys.Personality.traits] as? Data,
              let preferences = record[CloudKitConfiguration.RecordKeys.Personality.preferences] as? Data,
              let moodHistory = record[CloudKitConfiguration.RecordKeys.Personality.moodHistory] as? Data,
              let relationshipLevel = record[CloudKitConfiguration.RecordKeys.Personality.relationshipLevel] as? Int,
              let evolutionStage = record[CloudKitConfiguration.RecordKeys.Personality.evolutionStage] as? String,
              let lastUpdated = record[CloudKitConfiguration.RecordKeys.Personality.lastUpdated] as? Date
        else {
            throw CloudKitConfiguration.CloudKitError.recordNotFound
        }
        
        return PersonalityCloudKitModel(
            id: id,
            petID: petID,
            traits: traits,
            preferences: preferences,
            moodHistory: moodHistory,
            relationshipLevel: relationshipLevel,
            evolutionStage: evolutionStage,
            lastUpdated: lastUpdated
        )
    }
}

struct HealthMetricsCloudKitModel: CloudKitConvertible {
    let id: UUID
    let petID: UUID
    let happiness: Double
    let hunger: Double
    let energy: Double
    let hygiene: Double
    let health: Double
    let lastFed: Date?
    let lastPlayed: Date?
    let lastCleaned: Date?
    let timestamp: Date
    
    func toCKRecord() -> CKRecord {
        let recordID = CKRecord.ID(recordName: id.uuidString, zoneID: CloudKitConfiguration.shared.defaultZoneID)
        let record = CKRecord(recordType: CloudKitConfiguration.RecordTypes.health, recordID: recordID)
        
        record[CloudKitConfiguration.RecordKeys.HealthMetrics.id] = id.uuidString
        record[CloudKitConfiguration.RecordKeys.HealthMetrics.petID] = petID.uuidString
        record[CloudKitConfiguration.RecordKeys.HealthMetrics.happiness] = happiness
        record[CloudKitConfiguration.RecordKeys.HealthMetrics.hunger] = hunger
        record[CloudKitConfiguration.RecordKeys.HealthMetrics.energy] = energy
        record[CloudKitConfiguration.RecordKeys.HealthMetrics.hygiene] = hygiene
        record[CloudKitConfiguration.RecordKeys.HealthMetrics.health] = health
        record[CloudKitConfiguration.RecordKeys.HealthMetrics.lastFed] = lastFed
        record[CloudKitConfiguration.RecordKeys.HealthMetrics.lastPlayed] = lastPlayed
        record[CloudKitConfiguration.RecordKeys.HealthMetrics.lastCleaned] = lastCleaned
        record[CloudKitConfiguration.RecordKeys.HealthMetrics.timestamp] = timestamp
        
        return record
    }
    
    static func fromCKRecord(_ record: CKRecord) throws -> HealthMetricsCloudKitModel {
        guard let idString = record[CloudKitConfiguration.RecordKeys.HealthMetrics.id] as? String,
              let id = UUID(uuidString: idString),
              let petIDString = record[CloudKitConfiguration.RecordKeys.HealthMetrics.petID] as? String,
              let petID = UUID(uuidString: petIDString),
              let happiness = record[CloudKitConfiguration.RecordKeys.HealthMetrics.happiness] as? Double,
              let hunger = record[CloudKitConfiguration.RecordKeys.HealthMetrics.hunger] as? Double,
              let energy = record[CloudKitConfiguration.RecordKeys.HealthMetrics.energy] as? Double,
              let hygiene = record[CloudKitConfiguration.RecordKeys.HealthMetrics.hygiene] as? Double,
              let health = record[CloudKitConfiguration.RecordKeys.HealthMetrics.health] as? Double,
              let timestamp = record[CloudKitConfiguration.RecordKeys.HealthMetrics.timestamp] as? Date
        else {
            throw CloudKitConfiguration.CloudKitError.recordNotFound
        }
        
        return HealthMetricsCloudKitModel(
            id: id,
            petID: petID,
            happiness: happiness,
            hunger: hunger,
            energy: energy,
            hygiene: hygiene,
            health: health,
            lastFed: record[CloudKitConfiguration.RecordKeys.HealthMetrics.lastFed] as? Date,
            lastPlayed: record[CloudKitConfiguration.RecordKeys.HealthMetrics.lastPlayed] as? Date,
            lastCleaned: record[CloudKitConfiguration.RecordKeys.HealthMetrics.lastCleaned] as? Date,
            timestamp: timestamp
        )
    }
}

struct UserSettingsCloudKitModel: CloudKitConvertible {
    let id: UUID
    let userID: String
    let notificationSettings: Data
    let syncPreferences: Data
    let privacySettings: Data
    let gameplaySettings: Data
    let lastModified: Date
    
    func toCKRecord() -> CKRecord {
        let recordID = CKRecord.ID(recordName: id.uuidString, zoneID: CloudKitConfiguration.shared.defaultZoneID)
        let record = CKRecord(recordType: CloudKitConfiguration.RecordTypes.settings, recordID: recordID)
        
        record[CloudKitConfiguration.RecordKeys.UserSettings.id] = id.uuidString
        record[CloudKitConfiguration.RecordKeys.UserSettings.userID] = userID
        record[CloudKitConfiguration.RecordKeys.UserSettings.notifications] = notificationSettings
        record[CloudKitConfiguration.RecordKeys.UserSettings.syncPreferences] = syncPreferences
        record[CloudKitConfiguration.RecordKeys.UserSettings.privacySettings] = privacySettings
        record[CloudKitConfiguration.RecordKeys.UserSettings.gameplaySettings] = gameplaySettings
        record[CloudKitConfiguration.RecordKeys.UserSettings.lastModified] = lastModified
        
        return record
    }
    
    static func fromCKRecord(_ record: CKRecord) throws -> UserSettingsCloudKitModel {
        guard let idString = record[CloudKitConfiguration.RecordKeys.UserSettings.id] as? String,
              let id = UUID(uuidString: idString),
              let userID = record[CloudKitConfiguration.RecordKeys.UserSettings.userID] as? String,
              let notificationSettings = record[CloudKitConfiguration.RecordKeys.UserSettings.notifications] as? Data,
              let syncPreferences = record[CloudKitConfiguration.RecordKeys.UserSettings.syncPreferences] as? Data,
              let privacySettings = record[CloudKitConfiguration.RecordKeys.UserSettings.privacySettings] as? Data,
              let gameplaySettings = record[CloudKitConfiguration.RecordKeys.UserSettings.gameplaySettings] as? Data,
              let lastModified = record[CloudKitConfiguration.RecordKeys.UserSettings.lastModified] as? Date
        else {
            throw CloudKitConfiguration.CloudKitError.recordNotFound
        }
        
        return UserSettingsCloudKitModel(
            id: id,
            userID: userID,
            notificationSettings: notificationSettings,
            syncPreferences: syncPreferences,
            privacySettings: privacySettings,
            gameplaySettings: gameplaySettings,
            lastModified: lastModified
        )
    }
}