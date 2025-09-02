import Foundation
import CloudKit

// MARK: - Tamagotchi Pet Model

/// Main pet model for CloudKit sync
public struct TamagotchiPet: Codable, Identifiable {
    public let id: String
    public var name: String
    public var species: String
    public var personality: String
    public var happiness: Double
    public var hunger: Double
    public var health: Double
    public var age: Int
    public var evolutionStage: Int
    public var lastInteraction: Date
    public var birthDate: Date
    public var personalityTraits: PersonalityTraits
    
    public init(
        id: String = UUID().uuidString,
        name: String,
        species: String,
        personality: String,
        happiness: Double = 100,
        hunger: Double = 50,
        health: Double = 100,
        age: Int = 0,
        evolutionStage: Int = 0,
        lastInteraction: Date = Date(),
        birthDate: Date = Date(),
        personalityTraits: PersonalityTraits = PersonalityTraits()
    ) {
        self.id = id
        self.name = name
        self.species = species
        self.personality = personality
        self.happiness = happiness
        self.hunger = hunger
        self.health = health
        self.age = age
        self.evolutionStage = evolutionStage
        self.lastInteraction = lastInteraction
        self.birthDate = birthDate
        self.personalityTraits = personalityTraits
    }
    
    /// Convert to dictionary for sync queue
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "id": id,
            "name": name,
            "species": species,
            "personality": personality,
            "happiness": happiness,
            "hunger": hunger,
            "health": health,
            "age": age,
            "evolutionStage": evolutionStage,
            "lastInteraction": lastInteraction,
            "birthDate": birthDate
        ]
        
        if let traitsData = try? JSONEncoder().encode(personalityTraits),
           let traitsDict = try? JSONSerialization.jsonObject(with: traitsData) as? [String: Any] {
            dict["personalityTraits"] = traitsDict
        }
        
        return dict
    }
    
    /// Create from dictionary
    static func from(dictionary: [String: Any]) -> TamagotchiPet? {
        guard let id = dictionary["id"] as? String,
              let name = dictionary["name"] as? String,
              let species = dictionary["species"] as? String,
              let personality = dictionary["personality"] as? String else {
            return nil
        }
        
        let happiness = dictionary["happiness"] as? Double ?? 100
        let hunger = dictionary["hunger"] as? Double ?? 50
        let health = dictionary["health"] as? Double ?? 100
        let age = dictionary["age"] as? Int ?? 0
        let evolutionStage = dictionary["evolutionStage"] as? Int ?? 0
        let lastInteraction = dictionary["lastInteraction"] as? Date ?? Date()
        let birthDate = dictionary["birthDate"] as? Date ?? Date()
        
        var personalityTraits = PersonalityTraits()
        if let traitsDict = dictionary["personalityTraits"] as? [String: Any],
           let traitsData = try? JSONSerialization.data(withJSONObject: traitsDict),
           let traits = try? JSONDecoder().decode(PersonalityTraits.self, from: traitsData) {
            personalityTraits = traits
        }
        
        return TamagotchiPet(
            id: id,
            name: name,
            species: species,
            personality: personality,
            happiness: happiness,
            hunger: hunger,
            health: health,
            age: age,
            evolutionStage: evolutionStage,
            lastInteraction: lastInteraction,
            birthDate: birthDate,
            personalityTraits: personalityTraits
        )
    }
    
    /// Create from CloudKit record
    static func from(record: CKRecord) -> TamagotchiPet? {
        guard let id = record["id"] as? String,
              let name = record["name"] as? String,
              let species = record["species"] as? String,
              let personality = record["personality"] as? String else {
            return nil
        }
        
        let happiness = record["happiness"] as? Double ?? 100
        let hunger = record["hunger"] as? Double ?? 50
        let health = record["health"] as? Double ?? 100
        let age = record["age"] as? Int ?? 0
        let evolutionStage = record["evolutionStage"] as? Int ?? 0
        let lastInteraction = record["lastInteraction"] as? Date ?? Date()
        let birthDate = record["birthDate"] as? Date ?? Date()
        
        var personalityTraits = PersonalityTraits()
        if let traitsData = record["personalityTraits"] as? Data,
           let traits = try? JSONDecoder().decode(PersonalityTraits.self, from: traitsData) {
            personalityTraits = traits
        }
        
        return TamagotchiPet(
            id: id,
            name: name,
            species: species,
            personality: personality,
            happiness: happiness,
            hunger: hunger,
            health: health,
            age: age,
            evolutionStage: evolutionStage,
            lastInteraction: lastInteraction,
            birthDate: birthDate,
            personalityTraits: personalityTraits
        )
    }
}

// MARK: - Personality Traits

/// Personality traits that evolve over time
public struct PersonalityTraits: Codable {
    public var playfulness: Double
    public var affection: Double
    public var independence: Double
    public var curiosity: Double
    public var energy: Double
    public var introversion: Double
    
    public init(
        playfulness: Double = 50,
        affection: Double = 50,
        independence: Double = 50,
        curiosity: Double = 50,
        energy: Double = 50,
        introversion: Double = 50
    ) {
        self.playfulness = playfulness
        self.affection = affection
        self.independence = independence
        self.curiosity = curiosity
        self.energy = energy
        self.introversion = introversion
    }
}

// MARK: - Interaction Model

/// Interaction between user and pet
public struct Interaction: Codable, Identifiable {
    public let id: String
    public let petId: String
    public let type: String
    public let message: String
    public let response: String
    public let timestamp: Date
    public let emotionalImpact: Double
    
    public init(
        id: String = UUID().uuidString,
        petId: String,
        type: String,
        message: String,
        response: String,
        timestamp: Date = Date(),
        emotionalImpact: Double = 0
    ) {
        self.id = id
        self.petId = petId
        self.type = type
        self.message = message
        self.response = response
        self.timestamp = timestamp
        self.emotionalImpact = emotionalImpact
    }
    
    /// Convert to dictionary for sync queue
    func toDictionary() -> [String: Any] {
        return [
            "id": id,
            "petId": petId,
            "type": type,
            "message": message,
            "response": response,
            "timestamp": timestamp,
            "emotionalImpact": emotionalImpact
        ]
    }
    
    /// Create from dictionary
    static func from(dictionary: [String: Any]) -> Interaction? {
        guard let id = dictionary["id"] as? String,
              let petId = dictionary["petId"] as? String,
              let type = dictionary["type"] as? String,
              let message = dictionary["message"] as? String,
              let response = dictionary["response"] as? String else {
            return nil
        }
        
        let timestamp = dictionary["timestamp"] as? Date ?? Date()
        let emotionalImpact = dictionary["emotionalImpact"] as? Double ?? 0
        
        return Interaction(
            id: id,
            petId: petId,
            type: type,
            message: message,
            response: response,
            timestamp: timestamp,
            emotionalImpact: emotionalImpact
        )
    }
    
    /// Create from CloudKit record
    static func from(record: CKRecord) -> Interaction? {
        guard let id = record["id"] as? String,
              let petId = record["petId"] as? String,
              let type = record["type"] as? String,
              let message = record["message"] as? String,
              let response = record["response"] as? String else {
            return nil
        }
        
        let timestamp = record["timestamp"] as? Date ?? Date()
        let emotionalImpact = record["emotionalImpact"] as? Double ?? 0
        
        return Interaction(
            id: id,
            petId: petId,
            type: type,
            message: message,
            response: response,
            timestamp: timestamp,
            emotionalImpact: emotionalImpact
        )
    }
}

// MARK: - Achievement Model

/// Achievement unlocked by the pet
public struct Achievement: Codable, Identifiable {
    public let id: String
    public let petId: String
    public let type: String
    public let name: String
    public let description: String
    public let unlockedDate: Date
    
    public init(
        id: String = UUID().uuidString,
        petId: String,
        type: String,
        name: String,
        description: String,
        unlockedDate: Date = Date()
    ) {
        self.id = id
        self.petId = petId
        self.type = type
        self.name = name
        self.description = description
        self.unlockedDate = unlockedDate
    }
    
    /// Convert to dictionary for sync queue
    func toDictionary() -> [String: Any] {
        return [
            "id": id,
            "petId": petId,
            "type": type,
            "name": name,
            "description": description,
            "unlockedDate": unlockedDate
        ]
    }
    
    /// Create from dictionary
    static func from(dictionary: [String: Any]) -> Achievement? {
        guard let id = dictionary["id"] as? String,
              let petId = dictionary["petId"] as? String,
              let type = dictionary["type"] as? String,
              let name = dictionary["name"] as? String,
              let description = dictionary["description"] as? String else {
            return nil
        }
        
        let unlockedDate = dictionary["unlockedDate"] as? Date ?? Date()
        
        return Achievement(
            id: id,
            petId: petId,
            type: type,
            name: name,
            description: description,
            unlockedDate: unlockedDate
        )
    }
    
    /// Create from CloudKit record
    static func from(record: CKRecord) -> Achievement? {
        guard let id = record["id"] as? String,
              let petId = record["petId"] as? String,
              let type = record["type"] as? String,
              let name = record["name"] as? String,
              let description = record["description"] as? String else {
            return nil
        }
        
        let unlockedDate = record["unlockedDate"] as? Date ?? Date()
        
        return Achievement(
            id: id,
            petId: petId,
            type: type,
            name: name,
            description: description,
            unlockedDate: unlockedDate
        )
    }
}