# Technology Stack

## Platform Requirements

### Target Platforms
- **iOS**: 17.0+
- **watchOS**: 10.0+
- **macOS**: 14.0+ (Catalyst support)
- **visionOS**: 1.0+ (Future consideration)

### Development Environment
- **Xcode**: 15.0+ (Required for iOS 17 and watchOS 10 SDKs)
- **Swift**: 5.9+ (Minimum for macro support and modern concurrency)
- **macOS**: Sonoma 14.0+ (for development)
- **Reality Composer Pro**: For future AR/VR assets
- **Create ML**: For on-device model training

## Core Technologies

### Language & Frameworks

#### Swift 5.9+ Features
- **Macros**: For code generation and boilerplate reduction
  - `@Observable`: Simplified state management
  - `@Model`: SwiftData model definitions
  - Custom macros for pet behavior patterns
- **Structured Concurrency**: async/await, actors for thread-safe state management
  - Actor isolation for AI inference
  - TaskGroup for parallel processing
  - AsyncStream for real-time updates
- **Parameter Packs**: Generic programming improvements
- **Non-copyable Types**: Memory-efficient value types
- **Typed Throws**: Better error handling
- **Consuming and Borrowing**: Ownership control

#### SwiftUI (iOS 17+ & watchOS 10+)
- **Primary UI Framework**: All interfaces built with SwiftUI
- **Navigation Stack**: Type-safe navigation with value-based routing
- **Observable Framework**: @Observable macro for state management
- **Charts**: Native visualization for pet stats and mood tracking
- **Widget Kit**: Home screen, Lock Screen, and StandBy widgets
- **App Intents**: Siri and Shortcuts integration
- **ScrollView Enhancements**: Content margins and safe area handling
- **Animation**: Keyframe animations and spring animations
- **Metal Shaders**: Custom visual effects for pet rendering
- **TipKit**: User onboarding and feature discovery

#### UIKit (Limited Use)
- **Haptic Feedback**: Advanced haptics on iPhone
- **Custom Animations**: Where SwiftUI limitations exist
- **Legacy Integration**: If needed for specific features

### Data & Storage

#### SwiftData
- **Primary Database**: On-device persistence
- **Schema Versioning**: Migration support
- **CloudKit Sync**: Cross-device synchronization
- **Relationships**: Pet data, interactions, history

#### Core Data (Fallback)
- **Migration Path**: From existing Core Data if needed
- **Background Processing**: Heavy data operations

### AI & Machine Learning

#### Core ML
- **Framework**: On-device inference
- **Model Format**: Core ML models (.mlmodel, .mlpackage)
- **Optimization**: Neural Engine utilization
- **Model Updates**: Background asset downloads

#### Phi-3 Mini Integration
- **Model Size**: ~3.8B parameters
- **Quantization**: 4-bit quantization for mobile
- **Memory Requirements**: ~2GB RAM
- **Inference**: Metal Performance Shaders
- **Context Window**: 4K tokens (128K with RoPE)
- **Response Time**: <2 seconds for typical queries
- **Batch Processing**: Offline conversation generation
- **Fine-tuning**: User personality adaptation

#### Create ML
- **Personalization**: User-specific model fine-tuning
- **Activity Classification**: Pet behavior patterns
- **Text Classification**: Message sentiment analysis

### Swift 5.9+ Language Enhancements

#### Macro System
- **@Observable**: Automatic UI updates without @Published
- **@Model**: SwiftData model synthesis
- **@Transient**: Non-persistent properties
- **Custom Macros**: Domain-specific code generation
  - Pet behavior state machines
  - Interaction pattern matching
  - Achievement system generation

#### Concurrency Improvements
- **Task Priority Propagation**: AI inference prioritization
- **Task Local Values**: Per-task context storage
- **Async Algorithms**: Stream processing for real-time data
- **Actor Reentrancy**: Safe concurrent pet state updates
- **Sendable Conformance**: Thread-safe data passing

#### Type System Enhancements
- **Noncopyable Types**: Resource management for AI models
- **Typed Throws**: Precise error handling for network/AI failures
- **Generic Parameter Packs**: Flexible pet trait systems
- **Ownership Modifiers**: Memory optimization for large models

### System Frameworks

#### HealthKit
- **User Activity**: Steps, exercise, sleep patterns
- **Heart Rate**: Stress detection via Apple Watch
- **Mindful Minutes**: Meditation tracking
- **Authorization**: Privacy-preserving data access

#### GameplayKit
- **State Machines**: Pet behavior states
- **Random Generation**: Personality traits
- **Entity-Component**: Game architecture
- **Pathfinding**: Pet movement in AR (future)

#### SpriteKit
- **2D Graphics**: Pet animations
- **Particle Systems**: Visual effects
- **Physics**: Interactive elements
- **Scene Management**: Game scenes

#### AVFoundation
- **Sound Effects**: Pet sounds
- **Haptic Patterns**: Custom feedback
- **Speech Synthesis**: Pet voice (optional)
- **Audio Session**: Background audio

#### WatchConnectivity
- **Data Transfer**: iPhone ↔ Watch sync
- **Message Passing**: Real-time updates
- **Application Context**: Shared state
- **File Transfer**: Large data sync

### Cloud & Networking

#### CloudKit
- **Private Database**: User data sync
- **Public Database**: Shared content (future)
- **Push Notifications**: Silent updates
- **Asset Storage**: Model updates

#### URLSession
- **Background Downloads**: Model updates
- **Metrics Collection**: Anonymous analytics
- **Configuration**: Adaptive networking

### Security & Privacy

#### CryptoKit
- **Encryption**: Sensitive data protection
- **Key Management**: Secure enclave usage
- **Hashing**: Data integrity
- **Authentication**: Biometric integration

#### Local Authentication
- **Face ID/Touch ID**: App access
- **Passcode**: Fallback authentication
- **Biometric Changes**: Detection and handling

### Development Tools

#### Testing
- **XCTest**: Unit and UI testing
- **Swift Testing**: New testing framework (Swift 5.9+)
- **XCUITest**: Automated UI testing
- **TestFlight**: Beta distribution

#### Performance
- **Instruments**: Profiling and optimization
- **MetricKit**: Production performance monitoring
- **os_log**: Structured logging
- **Xcode Organizer**: Crash reports and metrics

#### CI/CD
- **Xcode Cloud**: Automated builds and tests
- **App Store Connect API**: Automated submissions
- **Fastlane**: Build automation (optional)

## Architecture Patterns

### Design Patterns
- **MVVM**: Model-View-ViewModel with SwiftUI
- **Repository Pattern**: Data access abstraction
- **Coordinator**: Navigation management
- **Observer**: Reactive updates

### Architectural Principles
- **Protocol-Oriented**: Swift protocols for abstraction
- **Dependency Injection**: Testability and modularity
- **Actor Model**: Thread-safe state management
- **Functional Reactive**: Combine framework usage

## Package Management & Dependencies

### Swift Package Manager (SPM)
- **Primary Tool**: All dependencies via SPM
- **Local Packages**: Modular architecture support
- **Binary Targets**: Pre-compiled AI models
- **Version Resolution**: Semantic versioning
- **Platform Conditionals**: iOS/watchOS specific packages

### Core Dependencies
```swift
// Package.swift targets
.package(url: "https://github.com/apple/swift-algorithms", from: "1.2.0"),
.package(url: "https://github.com/apple/swift-async-algorithms", from: "1.0.0"),
.package(url: "https://github.com/apple/swift-collections", from: "1.1.0"),
.package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0") // CLI tools
```

### Development Dependencies
- **SwiftLint**: Code style enforcement (development only)
- **SwiftFormat**: Automatic code formatting
- **Periphery**: Dead code detection
- **SwiftGen**: Code generation for resources

### Potential Libraries (Evaluated Case-by-Case)
- **Lottie**: Only if native animations insufficient
- **TelemetryDeck**: Privacy-focused analytics
- **RevenueCat**: Subscription management (if needed)

## Build Configuration

### Compilation Settings
- **Swift Language Version**: 5.9
- **Build Active Architecture Only**: Debug only
- **Optimization Level**: -Os (Size) for Release
- **Whole Module Optimization**: Enabled for Release
- **Link Time Optimization**: Enabled for Release

### Swift Compiler Flags
- **Debug**: `-D DEBUG -Onone`
- **Release**: `-D RELEASE -O -whole-module-optimization`
- **Strict Concurrency**: `complete` checking
- **Enable Upcoming Features**: For Swift 6 preparation

### Platform-Specific Settings
#### iOS Target
- **Deployment Target**: iOS 17.0
- **Device Family**: iPhone only
- **Requires Full Screen**: No (multitasking support)
- **Supported Orientations**: All

#### watchOS Target  
- **Deployment Target**: watchOS 10.0
- **Device Family**: Apple Watch
- **Independent App**: Yes
- **Supports Running Without iOS**: Yes

## Platform-Specific Features

### iOS 17+ Exclusive Features
- **Interactive Widgets**: Live Activities and dynamic updates
- **StandBy Mode**: Always-on display support with pet animations
- **Sensitive Content Analysis**: On-device safety for user inputs
- **Screen Distance**: Eye health monitoring and reminders
- **Journal Suggestions**: Pet mood correlation with daily events
- **Contact Posters**: Pet-themed contact customization
- **Animated Symbols**: SF Symbols 5 with animations
- **SwiftData**: Modern persistence framework
- **TipKit**: Contextual user guidance
- **Observation Framework**: Simplified state management

### watchOS 10+ Exclusive Features
- **Smart Stack**: Intelligent widget suggestions based on context
- **Digital Crown**: Precise pet interaction controls
- **Always-On Display**: Ambient pet state updates
- **Double Tap Gesture**: Quick pet interactions
- **Vertical Pagination**: New navigation paradigm
- **Control Center**: Quick access to pet controls
- **Enhanced Complications**: Rich pet status displays
- **Background App Refresh**: Autonomous pet updates
- **Workout APIs**: Pet activity during exercise
- **Depth App**: Environmental awareness (Ultra only)

### Shared Features
- **App Groups**: Data sharing
- **Universal Links**: Deep linking
- **Handoff**: Continuity between devices
- **iCloud Keychain**: Secure data sync

## Performance Targets

### Memory
- **iOS App**: <150MB baseline
- **Watch App**: <50MB baseline
- **AI Model**: <2GB loaded
- **Background**: <30MB

### Battery
- **Screen Time**: <5% battery/hour
- **Background**: <1% battery/hour
- **AI Inference**: Batch processing
- **Watch**: 18+ hours with app

### Launch Time
- **Cold Start**: <1 second
- **Warm Start**: <0.5 seconds
- **Model Load**: <3 seconds
- **Watch App**: <2 seconds

## watchOS 10+ Development Considerations

### Architecture
- **Independent App**: Standalone functionality without iPhone
- **Companion Mode**: Enhanced features when paired
- **Background Processing**: Autonomous pet updates
- **Complication Timeline**: Predictive pet state updates

### Performance Optimization
- **Lazy Loading**: On-demand resource loading
- **Image Caching**: Efficient pet sprite management
- **Background Tasks**: Scheduled pet updates
- **Power Management**: Battery-aware AI inference

### User Interface
- **Vertical Navigation**: Primary interaction model
- **Digital Crown Input**: Analog pet interactions
- **Force Touch Alternatives**: Long press menus
- **Glanceable Information**: Quick pet status checks

### Connectivity
- **Watch Connectivity**: Real-time iPhone sync
- **CloudKit Direct**: Independent cloud sync
- **Bluetooth**: Peer-to-peer pet sharing
- **Cellular**: LTE/5G for independent operation

## iOS 17+ Specific APIs

### New Frameworks
- **TipKit**: Progressive disclosure of features
- **Observation**: Simplified state management
- **SwiftData**: Modern Core Data replacement
- **SensitiveContentAnalysis**: Content moderation

### Enhanced APIs
- **WidgetKit**: Interactive and Smart Stack widgets
- **StoreKit 2**: Modern in-app purchase flow
- **WeatherKit**: Environmental pet reactions
- **MapKit**: Location-based pet behaviors

## Development Phases

### Phase 1: Foundation
- SwiftUI interfaces
- SwiftData setup
- Basic pet mechanics
- CloudKit sync

### Phase 2: Intelligence
- Core ML integration
- Phi-3 Mini implementation
- Personality system
- Learning algorithms

### Phase 3: Enhancement
- Advanced animations
- HealthKit integration
- Widget implementation
- Watch complications

### Phase 4: Polish
- Performance optimization
- Accessibility
- Localization
- App Store preparation

## Compatibility Matrix

| Component | Minimum | Recommended | Notes |
|-----------|---------|-------------|-------|
| iOS | 17.0 | 17.2+ | Latest features, TipKit |
| watchOS | 10.0 | 10.2+ | Smart Stack, Double Tap |
| Swift | 5.9 | 5.9.2+ | Macros, typed throws |
| Xcode | 15.0 | 15.2+ | visionOS SDK support |
| iPhone | iPhone 12 | iPhone 15 Pro | Neural Engine, Action Button |
| Apple Watch | Series 6 | Series 9/Ultra 2 | S9 chip, Double Tap |
| RAM | 4GB | 8GB+ | AI inference headroom |
| Storage | 500MB | 3GB+ | Model + user data |
| Neural Engine | A14+ | A17 Pro+ | 16-core for best performance |

## Future Considerations

### visionOS Support (2024+)
- Spatial computing pet with 3D presence
- Hand tracking for natural interactions
- Immersive environments for pet habitats
- Shared space and full space experiences

### Mac Catalyst
- Desktop companion app with extended features
- Development and debugging tools
- Larger screen optimizations
- Keyboard and trackpad support

### HomeKit Integration
- Home automation triggers based on pet mood
- Ambient computing with pet presence
- Matter protocol support
- Location-based pet behaviors

### ARKit Integration
- AR pet visualization in real world
- Object tracking and occlusion
- Spatial anchoring for persistent placement
- LiDAR-enhanced interactions (Pro models)

### Apple Intelligence (iOS 18+)
- Enhanced on-device language models
- Multimodal understanding
- Federated learning for personalization
- Private Cloud Compute integration