import Foundation
import CoreML
import NaturalLanguage
import Combine
import os.log

/// Privacy-focused AI processing pipeline for Tamagotchi interactions
@MainActor
public final class AIProcessor: ObservableObject {
    // MARK: - Properties
    @Published public private(set) var isProcessing: Bool = false
    @Published public private(set) var lastProcessingTime: TimeInterval = 0
    @Published public private(set) var processingStats: ProcessingStatistics
    
    private let modelManager = MLModelManager.shared
    private let logger = Logger(subsystem: "com.ai.tamagotchi", category: "AIProcessor")
    private var cancellables = Set<AnyCancellable>()
    
    // Privacy-focused processing queue
    private let processingQueue = DispatchQueue(label: "ai.processing", 
                                               qos: .userInitiated,
                                               attributes: .concurrent)
    
    // On-device tokenizer for text processing
    private let tokenizer: NLTokenizer
    private let embedding: NLEmbedding?
    
    // MARK: - Processing Statistics
    public struct ProcessingStatistics {
        public var totalProcessed: Int = 0
        public var averageProcessingTime: TimeInterval = 0
        public var cacheHitRate: Double = 0
        public var lastProcessedAt: Date?
        
        // All statistics are local-only, never transmitted
        public var privacyCompliant: Bool { true }
    }
    
    // MARK: - Input/Output Types
    public struct TamagotchiInput {
        public let text: String?
        public let context: InteractionContext
        public let timestamp: Date
        
        public init(text: String? = nil, 
                   context: InteractionContext = .general,
                   timestamp: Date = Date()) {
            self.text = text
            self.context = context
            self.timestamp = timestamp
        }
    }
    
    public struct TamagotchiResponse {
        public let message: String
        public let emotion: EmotionState
        public let action: PetAction?
        public let confidence: Double
        
        // Privacy flag - response generated entirely on-device
        public let isPrivate: Bool = true
    }
    
    public enum InteractionContext {
        case general
        case feeding
        case playing
        case training
        case emotional
        case health
    }
    
    public enum EmotionState: String, CaseIterable {
        case happy
        case sad
        case excited
        case tired
        case hungry
        case playful
        case content
        case anxious
    }
    
    public enum PetAction: String {
        case jump
        case sleep
        case eat
        case play
        case dance
        case cuddle
        case explore
    }
    
    // MARK: - Initialization
    public init() {
        self.processingStats = ProcessingStatistics()
        self.tokenizer = NLTokenizer(unit: .word)
        self.embedding = NLEmbedding.wordEmbedding(for: .english)
        
        setupModelObserver()
    }
    
    // MARK: - Public Methods
    
    /// Process user input and generate Tamagotchi response (fully on-device)
    public func processInteraction(_ input: TamagotchiInput) async throws -> TamagotchiResponse {
        guard modelManager.isModelReady else {
            // Fallback to rule-based response if model not ready
            return generateFallbackResponse(for: input)
        }
        
        isProcessing = true
        let startTime = Date()
        
        defer {
            isProcessing = false
            lastProcessingTime = Date().timeIntervalSince(startTime)
            updateStatistics()
        }
        
        logger.info("Processing interaction on-device")
        
        // Prepare input features (all processing on-device)
        let features = try await prepareFeatures(from: input)
        
        // Run inference through CoreML
        let modelOutput = try await modelManager.processInput(features)
        
        // Interpret model output
        let response = try interpretModelOutput(modelOutput, context: input.context)
        
        return response
    }
    
    /// Generate contextual suggestions without network calls
    public func generateSuggestions(for context: InteractionContext) async -> [String] {
        logger.info("Generating offline suggestions for context: \(String(describing: context))")
        
        // All suggestions generated locally based on context
        switch context {
        case .feeding:
            return [
                "Time for a snack!",
                "I'm getting hungry...",
                "That looks delicious!"
            ]
        case .playing:
            return [
                "Let's play together!",
                "I want to show you a new trick!",
                "This is so much fun!"
            ]
        case .training:
            return [
                "I'm ready to learn!",
                "Show me what to do!",
                "Practice makes perfect!"
            ]
        case .emotional:
            return [
                "I'm here for you!",
                "You make me happy!",
                "Thanks for taking care of me!"
            ]
        case .health:
            return [
                "I feel great today!",
                "Time for a checkup?",
                "Let's stay healthy together!"
            ]
        case .general:
            return [
                "What should we do today?",
                "I missed you!",
                "Hello friend!"
            ]
        }
    }
    
    /// Analyze sentiment locally without external APIs
    public func analyzeSentiment(text: String) async -> Double {
        // On-device sentiment analysis using NaturalLanguage framework
        let tagger = NLTagger(tagSchemes: [.sentimentScore])
        tagger.string = text
        
        var totalScore: Double = 0
        var wordCount = 0
        
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, 
                            unit: .word,
                            scheme: .sentimentScore) { tag, _ in
            if let tag = tag,
               let score = Double(tag.rawValue) {
                totalScore += score
                wordCount += 1
            }
            return true
        }
        
        return wordCount > 0 ? totalScore / Double(wordCount) : 0.0
    }
    
    // MARK: - Private Methods
    
    private func prepareFeatures(from input: TamagotchiInput) async throws -> MLFeatureProvider {
        // Tokenize text locally
        var tokens: [String] = []
        
        if let text = input.text {
            tokenizer.string = text
            tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
                tokens.append(String(text[range]))
                return true
            }
        }
        
        // Create embeddings (on-device)
        var embeddings: [Double] = []
        if let embedding = self.embedding {
            for token in tokens.prefix(50) { // Limit context window
                if let vector = embedding.vector(for: token) {
                    embeddings.append(contentsOf: vector)
                }
            }
        }
        
        // Pad or truncate to fixed size
        let targetSize = 768 // Phi-3 Mini embedding size
        while embeddings.count < targetSize {
            embeddings.append(0.0)
        }
        if embeddings.count > targetSize {
            embeddings = Array(embeddings.prefix(targetSize))
        }
        
        // Create MLFeatureProvider
        let featureDict: [String: Any] = [
            "input_embeddings": try MLMultiArray(embeddings),
            "context_type": input.context.rawValue,
            "timestamp": input.timestamp.timeIntervalSince1970
        ]
        
        return try MLDictionaryFeatureProvider(dictionary: featureDict)
    }
    
    private func interpretModelOutput(_ output: MLFeatureProvider,
                                    context: InteractionContext) throws -> TamagotchiResponse {
        // Extract features from model output
        guard let logits = output.featureValue(for: "output_logits")?.multiArrayValue else {
            throw MLModelError.processingFailed("Invalid model output")
        }
        
        // Convert logits to response
        let (message, confidence) = generateMessage(from: logits, context: context)
        let emotion = determineEmotion(from: logits)
        let action = determineAction(from: logits, emotion: emotion)
        
        return TamagotchiResponse(
            message: message,
            emotion: emotion,
            action: action,
            confidence: confidence
        )
    }
    
    private func generateMessage(from logits: MLMultiArray,
                                context: InteractionContext) -> (String, Double) {
        // Simplified message generation - in production, this would use
        // proper decoding with vocabulary mapping
        let templates = messageTemplates(for: context)
        let index = Int(logits[0].doubleValue * Double(templates.count)) % templates.count
        let confidence = min(max(logits[0].doubleValue, 0.0), 1.0)
        
        return (templates[index], confidence)
    }
    
    private func messageTemplates(for context: InteractionContext) -> [String] {
        switch context {
        case .feeding:
            return ["Yummy!", "Thanks for the food!", "I was so hungry!"]
        case .playing:
            return ["This is fun!", "Let's play more!", "You're the best!"]
        case .training:
            return ["I'm learning!", "Watch this!", "Did I do good?"]
        case .emotional:
            return ["I love you!", "You're my best friend!", "I'm so happy!"]
        case .health:
            return ["I feel good!", "Thanks for taking care of me!", "Healthy and happy!"]
        case .general:
            return ["Hello!", "What's up?", "Nice to see you!"]
        }
    }
    
    private func determineEmotion(from logits: MLMultiArray) -> EmotionState {
        // Map model output to emotion
        let emotionValue = abs(logits[1].doubleValue)
        let emotions = EmotionState.allCases
        let index = Int(emotionValue * Double(emotions.count)) % emotions.count
        return emotions[index]
    }
    
    private func determineAction(from logits: MLMultiArray,
                                emotion: EmotionState) -> PetAction? {
        // Determine action based on emotion and model output
        switch emotion {
        case .happy, .excited:
            return [.jump, .dance].randomElement()
        case .tired:
            return .sleep
        case .hungry:
            return .eat
        case .playful:
            return .play
        case .content:
            return .cuddle
        case .anxious:
            return .explore
        case .sad:
            return nil
        }
    }
    
    private func generateFallbackResponse(for input: TamagotchiInput) -> TamagotchiResponse {
        // Rule-based fallback when model is unavailable
        logger.info("Using fallback response generator")
        
        let emotion: EmotionState = .content
        let message = "Hi there! I'm happy to see you!"
        let action: PetAction? = .jump
        
        return TamagotchiResponse(
            message: message,
            emotion: emotion,
            action: action,
            confidence: 0.5
        )
    }
    
    private func updateStatistics() {
        processingStats.totalProcessed += 1
        processingStats.lastProcessedAt = Date()
        
        // Update average processing time
        let currentAvg = processingStats.averageProcessingTime
        let newAvg = (currentAvg * Double(processingStats.totalProcessed - 1) + lastProcessingTime) 
                     / Double(processingStats.totalProcessed)
        processingStats.averageProcessingTime = newAvg
    }
    
    private func setupModelObserver() {
        modelManager.$isModelReady
            .sink { [weak self] isReady in
                if isReady {
                    self?.logger.info("AI model ready for processing")
                }
            }
            .store(in: &cancellables)
    }
}

// MARK: - Extensions
extension AIProcessor.InteractionContext: RawRepresentable {
    public typealias RawValue = Int
    
    public init?(rawValue: Int) {
        switch rawValue {
        case 0: self = .general
        case 1: self = .feeding
        case 2: self = .playing
        case 3: self = .training
        case 4: self = .emotional
        case 5: self = .health
        default: return nil
        }
    }
    
    public var rawValue: Int {
        switch self {
        case .general: return 0
        case .feeding: return 1
        case .playing: return 2
        case .training: return 3
        case .emotional: return 4
        case .health: return 5
        }
    }
}