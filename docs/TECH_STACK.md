# Technology Stack

## Platform Requirements

### Target Platforms
- **iOS**: 17.0+
- **watchOS**: 10.0+
- **macOS**: 14.0+ (Catalyst support)
- **visionOS**: 1.0+ (Future consideration)

### Development Environment
- **Xcode**: 15.0+
- **Swift**: 5.9+
- **macOS**: Sonoma 14.0+ (for development)

## Core Technologies

### Language & Frameworks

#### Swift 5.9+ Features
- **Macros**: For code generation and boilerplate reduction
- **Structured Concurrency**: async/await, actors for thread-safe state management
- **Parameter Packs**: Generic programming improvements
- **Non-copyable Types**: Memory-efficient value types

#### SwiftUI
- **Primary UI Framework**: All interfaces built with SwiftUI
- **Navigation Stack**: Type-safe navigation
- **Observable Framework**: @Observable macro for state management
- **Charts**: Native visualization for pet stats
- **Widget Kit**: Home screen and Lock Screen widgets
- **App Intents**: Siri and Shortcuts integration

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

#### Create ML
- **Personalization**: User-specific model fine-tuning
- **Activity Classification**: Pet behavior patterns
- **Text Classification**: Message sentiment analysis

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

## Third-Party Dependencies

### Minimal External Dependencies
- **Philosophy**: Prefer native frameworks
- **Swift Package Manager**: Dependency management
- **Open Source**: MIT/Apache licensed only

### Potential Libraries (If Needed)
- **Lottie**: Complex animations (evaluate native first)
- **SwiftLint**: Code quality enforcement
- **Periphery**: Dead code detection

## Platform-Specific Features

### iOS 17+ Exclusive
- **Interactive Widgets**: Live Activities
- **StandBy Mode**: Always-on display support
- **Sensitive Content Analysis**: On-device safety
- **Screen Distance**: Eye health monitoring

### watchOS 10+ Exclusive
- **Smart Stack**: Widget suggestions
- **Digital Crown**: Precise interactions
- **Always-On Display**: Ambient updates
- **Double Tap Gesture**: Quick actions

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
| iOS | 17.0 | 17.2+ | Latest features |
| watchOS | 10.0 | 10.2+ | Smart Stack |
| Swift | 5.9 | 5.9+ | Macros support |
| Xcode | 15.0 | 15.2+ | Latest SDKs |
| iPhone | iPhone 12 | iPhone 14+ | Neural Engine |
| Apple Watch | Series 6 | Series 9+ | Performance |
| RAM | 4GB | 6GB+ | AI inference |
| Storage | 500MB | 2GB+ | With AI model |

## Future Considerations

### visionOS Support
- Spatial computing pet
- 3D interactions
- Immersive experiences

### Mac Catalyst
- Desktop companion app
- Extended features
- Development tools

### HomeKit Integration
- Home automation triggers
- Ambient computing
- Presence detection

### ARKit Integration
- AR pet visualization
- Real-world interactions
- Spatial anchoring