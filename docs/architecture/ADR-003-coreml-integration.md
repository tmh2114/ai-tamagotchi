# ADR-003: CoreML Integration Architecture

## Status
Accepted

## Context
The AI Tamagotchi requires on-device AI capabilities using Phi-3 Mini through CoreML. We need to define how CoreML models will be integrated, managed, and optimized for both iPhone and Apple Watch platforms.

## Decision

### CoreML Architecture Overview

#### 1. Model Management Layer

```swift
// AIModelManager.swift
protocol AIModelManager {
    func loadModel() async throws -> MLModel
    func predict(_ input: AIInput) async throws -> AIPrediction
    func updateModel(_ newModel: MLModel) async throws
    func compileModel(from url: URL) async throws -> URL
}

class Phi3MiniManager: AIModelManager {
    private var model: MLModel?
    private let modelURL: URL
    private let configuration: MLModelConfiguration
    
    init() {
        configuration = MLModelConfiguration()
        configuration.computeUnits = .all // CPU, GPU, Neural Engine
        configuration.allowLowPrecisionAccumulationOnGPU = true
    }
}
```

#### 2. Model Integration Structure

```
AI/
├── Models/
│   ├── Phi3Mini/
│   │   ├── Phi3Mini.mlmodelc          # Compiled model
│   │   ├── Phi3MiniConfig.swift       # Model configuration
│   │   └── Phi3MiniTokenizer.swift    # Text tokenization
│   │
│   └── Supporting/
│       ├── EmotionClassifier.mlmodelc # Supplementary models
│       └── ActivityPredictor.mlmodelc
│
├── Services/
│   ├── AIService.swift                # Main AI service interface
│   ├── ModelLoader.swift              # Model loading and caching
│   └── PredictionQueue.swift          # Async prediction management
│
├── Processors/
│   ├── InputProcessor.swift           # Input preparation
│   ├── OutputProcessor.swift          # Output interpretation
│   └── ContextBuilder.swift           # Context window management
│
└── Optimization/
    ├── ModelQuantization.swift        # Model size optimization
    ├── CacheManager.swift             # Prediction caching
    └── PerformanceMonitor.swift      # Performance tracking
```

### Model Loading Strategy

#### 1. Lazy Loading with Caching
```swift
class ModelLoader {
    private var loadedModels: [String: MLModel] = [:]
    private let modelCache = NSCache<NSString, MLModel>()
    
    func loadModel(named name: String) async throws -> MLModel {
        // Check memory cache
        if let cached = modelCache.object(forKey: name as NSString) {
            return cached
        }
        
        // Load from disk
        let modelURL = Bundle.main.url(forResource: name, withExtension: "mlmodelc")!
        let model = try await MLModel.load(contentsOf: modelURL, configuration: configuration)
        
        // Cache for future use
        modelCache.setObject(model, forKey: name as NSString)
        return model
    }
}
```

#### 2. Background Model Updates
```swift
class ModelUpdateService {
    func checkForUpdates() async throws {
        // Check for model updates
        // Download in background if available
        // Compile and validate new model
        // Hot-swap without app restart
    }
}
```

### Input/Output Processing

#### 1. Text Processing Pipeline
```swift
struct TextProcessor {
    let tokenizer: Phi3Tokenizer
    let maxTokens = 2048 // Phi-3 context window
    
    func prepareInput(text: String, context: ConversationContext) -> MLFeatureProvider {
        // Tokenize input
        let tokens = tokenizer.encode(text)
        
        // Add context from conversation history
        let contextTokens = buildContext(from: context)
        
        // Truncate if needed
        let combined = truncateToFit(tokens + contextTokens, maxLength: maxTokens)
        
        // Convert to MLMultiArray
        return Phi3Input(tokens: combined)
    }
}
```

#### 2. Response Generation
```swift
struct ResponseGenerator {
    func generateResponse(from output: MLFeatureProvider) -> PetResponse {
        // Decode model output
        let tokens = output.featureValue(for: "output")?.multiArrayValue
        let text = tokenizer.decode(tokens)
        
        // Parse response for actions
        let actions = parseActions(from: text)
        let emotion = detectEmotion(from: text)
        
        return PetResponse(
            text: text,
            actions: actions,
            emotion: emotion
        )
    }
}
```

### Platform-Specific Optimizations

#### iPhone
```swift
class iPhoneAIService: AIService {
    override init() {
        super.init()
        configuration.computeUnits = .all // Use all available hardware
        configuration.allowLowPrecisionAccumulationOnGPU = true
        enableAdvancedFeatures = true
    }
    
    // Full model capabilities
    func generateDetailedResponse(_ input: String) async -> Response {
        // Use full Phi-3 Mini model
    }
}
```

#### Apple Watch
```swift
class WatchAIService: AIService {
    override init() {
        super.init()
        configuration.computeUnits = .cpuOnly // Conserve battery
        configuration.allowLowPrecisionAccumulationOnGPU = false
        useQuantizedModel = true
    }
    
    // Simplified predictions
    func generateQuickResponse(_ input: String) async -> Response {
        // Use quantized or smaller model variant
        // Cache frequent responses
        // Limit context window
    }
}
```

### Performance Optimization

#### 1. Model Quantization
```swift
extension MLModel {
    func quantized(to bits: Int = 8) throws -> MLModel {
        // Reduce model precision for smaller size
        // Trade-off between accuracy and performance
    }
}
```

#### 2. Prediction Caching
```swift
class PredictionCache {
    private let cache = NSCache<NSString, AIPrediction>()
    
    func getCachedPrediction(for input: String) -> AIPrediction? {
        let key = hashInput(input)
        return cache.object(forKey: key as NSString)
    }
    
    func cachePrediction(_ prediction: AIPrediction, for input: String) {
        let key = hashInput(input)
        cache.setObject(prediction, forKey: key as NSString)
    }
}
```

#### 3. Batch Processing
```swift
class BatchProcessor {
    func processBatch(_ inputs: [AIInput]) async -> [AIPrediction] {
        // Process multiple predictions in parallel
        return await withTaskGroup(of: AIPrediction.self) { group in
            for input in inputs {
                group.addTask {
                    await self.predict(input)
                }
            }
            
            var results: [AIPrediction] = []
            for await result in group {
                results.append(result)
            }
            return results
        }
    }
}
```

### Memory Management

#### 1. Model Lifecycle
```swift
class ModelLifecycleManager {
    func loadModelForActiveUse() async {
        // Load model when app becomes active
    }
    
    func unloadModelForBackground() {
        // Release model memory when backgrounded
        // Keep minimal state for quick resume
    }
    
    func handleMemoryWarning() {
        // Clear caches
        // Switch to smaller model if available
    }
}
```

### Privacy and Security

#### 1. On-Device Processing
- All AI inference happens on-device
- No data sent to external servers
- User conversations stay private

#### 2. Model Security
```swift
struct ModelSecurity {
    static func validateModel(_ modelURL: URL) throws {
        // Verify model signature
        // Check model integrity
        // Validate model source
    }
}
```

## Consequences

### Positive
- **Privacy-First**: All processing on-device
- **Low Latency**: No network round trips
- **Offline Capable**: Works without internet
- **Hardware Optimized**: Uses Neural Engine when available
- **Battery Efficient**: Optimized for mobile devices

### Negative
- **Model Size**: Phi-3 Mini still requires ~1.5GB storage
- **Memory Usage**: Significant RAM required during inference
- **Update Complexity**: Model updates require app updates
- **Limited Context**: Smaller context window than cloud models

### Mitigation Strategies
1. Use model quantization to reduce size
2. Implement aggressive caching strategies
3. Provide fallback to simpler models on older devices
4. Stream model downloads during initial setup
5. Use background processing for non-critical predictions