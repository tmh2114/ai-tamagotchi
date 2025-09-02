# CoreML Integration Documentation

## Overview

The AI Tamagotchi uses CoreML for all on-device AI capabilities, ensuring complete privacy and offline functionality. This document details the CoreML integration architecture, components, and usage patterns.

## 🎯 Key Features

- **100% On-Device Processing**: All AI inference happens locally on the user's device
- **Privacy-First Design**: No data leaves the device for AI processing
- **Offline Capable**: Full functionality without internet connection
- **Optimized Performance**: Device-specific optimizations for iPhone and Apple Watch
- **Secure Data Handling**: Military-grade encryption for sensitive data

## 📁 Architecture

### Component Overview

```
AITamagotchi/Core/AI/
├── CoreML/
│   ├── MLModelManager.swift           # Model lifecycle management
│   └── OfflineCapabilityManager.swift # Offline functionality
├── Processing/
│   └── AIProcessor.swift              # Inference pipeline
├── Privacy/
│   └── PrivacyManager.swift           # Privacy & encryption
└── Models/
    └── ModelConfiguration.swift       # Model optimization
```

### Core Components

#### 1. MLModelManager
Manages the lifecycle of CoreML models with privacy-focused design.

**Key Responsibilities:**
- Model initialization and loading
- On-device model caching
- Privacy-preserving model updates
- Resource management

**Usage Example:**
```swift
// Initialize model manager
let modelManager = MLModelManager.shared

// Initialize model (happens on-device)
Task {
    try await modelManager.initializeModel()
    
    // Process input
    let output = try await modelManager.processInput(features)
}
```

#### 2. AIProcessor
Handles the complete AI inference pipeline for Tamagotchi interactions.

**Key Features:**
- Natural language processing
- Emotion recognition
- Behavior prediction
- Context-aware responses

**Usage Example:**
```swift
let processor = AIProcessor()

// Process user interaction
let input = AIProcessor.TamagotchiInput(
    text: "Hello buddy!",
    context: .general
)

let response = try await processor.processInteraction(input)
print(response.message)     // "Hi there! I'm happy to see you!"
print(response.emotion)     // .happy
print(response.action)      // .jump
```

#### 3. PrivacyManager
Ensures all AI operations meet strict privacy requirements.

**Privacy Levels:**
- **Maximum** (default): All processing on-device, no telemetry
- **Enhanced**: Limited anonymized telemetry
- **Standard**: Standard privacy protections
- **Minimum**: Basic protections only

**Features:**
- AES-256 encryption for data at rest
- Secure data deletion (DoD 5220.22-M standard)
- Privacy audit logging
- Consent management

**Usage Example:**
```swift
let privacyManager = PrivacyManager.shared

// Encrypt sensitive data
let encrypted = try privacyManager.encryptData(sensitiveData)

// Anonymize user data
let anonymized = privacyManager.anonymizeData(userData)

// Request consent for operation
let hasConsent = await privacyManager.requestConsent(for: .process)
```

#### 4. OfflineCapabilityManager
Ensures full AI functionality without network connectivity.

**Capabilities:**
- Text generation
- Emotion recognition
- Behavior prediction
- Interaction history
- Personality evolution
- Gameplay mechanics

**Usage Example:**
```swift
let offlineManager = OfflineCapabilityManager.shared

// Check network status
if offlineManager.networkStatus == .offline {
    // Get offline response
    let response = await offlineManager.getOfflineResponse(
        for: "How are you?",
        capability: .textGeneration
    )
}

// Prepare for offline mode
await offlineManager.prepareForOfflineMode()
```

## 🚀 Model Configuration

### Device-Specific Optimizations

#### iPhone Configuration
```swift
let config = ModelConfiguration.iPhoneOptimized(modelType: .phi3Mini)
// Uses Neural Engine, FP16 quantization, balanced optimization
```

#### Apple Watch Configuration
```swift
let config = ModelConfiguration.watchOptimized(modelType: .emotionClassifier)
// Uses CPU+GPU, INT8 quantization, aggressive optimization
```

#### Battery Saving Mode
```swift
let config = ModelConfiguration.batterySaving(modelType: .behaviorPredictor)
// CPU only, INT8 quantization, minimal memory usage
```

### Model Types

| Model | Purpose | Size | Device |
|-------|---------|------|---------|
| Phi-3 Mini | Main language model | ~2GB | iPhone |
| EmotionClassifier | Emotion detection | ~50MB | Both |
| BehaviorPredictor | Behavior prediction | ~100MB | Both |

## 🔒 Privacy & Security

### Data Protection

1. **Encryption at Rest**
   - All cached models encrypted with AES-256
   - Keychain storage for encryption keys
   - File protection: `.completeUntilFirstUserAuthentication`

2. **Secure Deletion**
   - DoD 5220.22-M standard (3-pass overwrite)
   - Random data overwrite before deletion
   - Immediate memory cleanup

3. **Privacy Audit**
   - Automatic daily audits
   - Operation logging (local only)
   - Consent tracking

### Privacy Compliance

```swift
// Validate privacy compliance
let operation = DataOperation(
    type: .process,
    isOnDeviceOnly: true,
    isAnonymized: false,
    isEssential: true
)

if privacyManager.validatePrivacyCompliance(for: operation) {
    // Operation is privacy-compliant
}
```

## 📱 Integration Examples

### Basic Tamagotchi Interaction

```swift
class TamagotchiViewModel: ObservableObject {
    private let aiProcessor = AIProcessor()
    private let modelManager = MLModelManager.shared
    
    func handleUserInput(_ text: String) async {
        // Ensure model is ready
        guard modelManager.isModelReady else {
            try? await modelManager.initializeModel()
            return
        }
        
        // Process interaction
        let input = AIProcessor.TamagotchiInput(
            text: text,
            context: determineContext(from: text)
        )
        
        do {
            let response = try await aiProcessor.processInteraction(input)
            updatePetState(with: response)
        } catch {
            // Handle error with fallback response
            handleError(error)
        }
    }
    
    private func updatePetState(with response: AIProcessor.TamagotchiResponse) {
        // Update UI with response
        petMessage = response.message
        petEmotion = response.emotion
        
        // Trigger animation
        if let action = response.action {
            triggerAnimation(action)
        }
    }
}
```

### Offline-First Implementation

```swift
class OfflineFirstAI {
    private let offlineManager = OfflineCapabilityManager.shared
    private let aiProcessor = AIProcessor()
    
    func processInput(_ text: String) async -> String {
        // Check if we're offline
        if case .offline = offlineManager.networkStatus {
            // Use offline capabilities
            let response = await offlineManager.getOfflineResponse(
                for: text,
                capability: .textGeneration
            )
            return response.text
        }
        
        // Online processing (still on-device)
        let input = AIProcessor.TamagotchiInput(text: text)
        if let response = try? await aiProcessor.processInteraction(input) {
            return response.message
        }
        
        // Fallback
        return "Hi there!"
    }
}
```

## 🔧 Performance Optimization

### Model Optimization

```swift
let optimizer = ModelOptimizer()

// Optimize for specific device
let optimizedURL = try await optimizer.optimizeModel(
    at: modelURL,
    configuration: .iPhoneOptimized(modelType: .phi3Mini)
)

// Profile performance
let profile = try await optimizer.profileModel(at: optimizedURL)
print(profile.description)
// Performance Profile:
// - Inference Time: 45.23 ms
// - Memory Usage: 512 MB
// - Estimated Power: 800.0 mW
```

### Memory Management

```swift
// Configure memory constraints
let config = ModelConfiguration(
    modelType: .phi3Mini,
    memoryConstraints: ModelConfiguration.MemoryConstraints(
        maxMemoryMB: 512,
        cacheEnabled: true,
        swapEnabled: false  // Avoid swapping for privacy
    )
)
```

## 📊 Monitoring & Analytics

### Privacy-Preserving Metrics

```swift
// Get processing statistics (local only)
let stats = aiProcessor.processingStats
print("Total processed: \(stats.totalProcessed)")
print("Average time: \(stats.averageProcessingTime)ms")
print("Cache hit rate: \(stats.cacheHitRate * 100)%")

// Storage statistics
let storage = offlineManager.getStorageStats()
print("Cache size: \(storage.formattedTotalCache)")
print("Available space: \(storage.formattedAvailableSpace)")
```

## 🚨 Error Handling

### Common Errors

```swift
enum MLModelError: LocalizedError {
    case modelNotFound      // Model file missing
    case modelNotReady      // Model not initialized
    case invalidInput       // Invalid input format
    case processingFailed   // Inference failed
}

// Handle errors gracefully
do {
    let response = try await processor.processInteraction(input)
} catch MLModelError.modelNotReady {
    // Initialize model
    try await modelManager.initializeModel()
} catch MLModelError.processingFailed {
    // Use fallback response
    return generateFallbackResponse()
}
```

## 🔄 Model Updates

Models can be updated while maintaining privacy:

1. **Privacy-Preserving Update Check**
   - Only version manifest downloaded
   - No user data transmitted
   - No tracking or telemetry

2. **Differential Updates**
   - Only changed weights downloaded
   - Encrypted transmission
   - Local validation

3. **Rollback Support**
   - Previous model kept as backup
   - Automatic rollback on failure
   - User consent required

## 📝 Best Practices

1. **Always Initialize Models Early**
   ```swift
   // In app launch
   Task {
       try? await MLModelManager.shared.initializeModel()
   }
   ```

2. **Handle Offline Scenarios**
   ```swift
   // Always provide offline fallbacks
   if !modelManager.isModelReady {
       return offlineResponse
   }
   ```

3. **Respect Privacy Settings**
   ```swift
   // Check privacy level before operations
   if privacyManager.privacyLevel == .maximum {
       // Ensure no telemetry
   }
   ```

4. **Optimize for Device**
   ```swift
   // Use appropriate configuration
   let config = UIDevice.current.userInterfaceIdiom == .pad
       ? .iPhoneOptimized(modelType: type)
       : .watchOptimized(modelType: type)
   ```

## 🎓 Additional Resources

- [Apple CoreML Documentation](https://developer.apple.com/documentation/coreml)
- [Privacy Best Practices](https://developer.apple.com/documentation/uikit/protecting_the_user_s_privacy)
- [On-Device Machine Learning](https://developer.apple.com/machine-learning/core-ml/)

## 📄 License

All CoreML integration code is part of the AI Tamagotchi project and follows the same privacy-first principles throughout the application.