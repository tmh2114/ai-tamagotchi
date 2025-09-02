# ADR-001: MVVM-C Architecture Pattern

## Status
Accepted

## Context
The AI Tamagotchi app requires a clean, testable, and scalable architecture that can handle complex state management, navigation flows, and AI model integration while maintaining separation of concerns.

## Decision
We will adopt the MVVM-C (Model-View-ViewModel-Coordinator) pattern for the following reasons:

### Architecture Components

#### Models
- **Domain Models**: Pet, User, Activity, Interaction
- **Core Data Models**: Persistent storage entities
- **AI Models**: CoreML model wrappers and prediction structures
- **Network Models**: API request/response structures (if needed)

#### Views (SwiftUI)
- Declarative UI components
- Stateless presentation layer
- Composed of reusable view components
- Reactive to ViewModel state changes

#### ViewModels
- Business logic and state management
- Published properties for data binding
- Handle user interactions
- Transform model data for presentation
- Manage AI inference requests

#### Coordinators
- Navigation flow control
- Dependency injection
- Scene transition management
- Deep linking support
- Module initialization

### Implementation Structure

```
AITamagotchi/
├── App/
│   ├── AITamagotchiApp.swift
│   ├── AppCoordinator.swift
│   └── AppDelegate.swift
│
├── Core/
│   ├── Models/
│   │   ├── Pet.swift
│   │   ├── User.swift
│   │   ├── Interaction.swift
│   │   └── Activity.swift
│   │
│   ├── Services/
│   │   ├── AIService.swift
│   │   ├── DataService.swift
│   │   ├── SyncService.swift
│   │   └── NotificationService.swift
│   │
│   └── Utilities/
│       ├── Extensions/
│       ├── Helpers/
│       └── Constants.swift
│
├── Features/
│   ├── Pet/
│   │   ├── Views/
│   │   │   ├── PetView.swift
│   │   │   └── Components/
│   │   ├── ViewModels/
│   │   │   └── PetViewModel.swift
│   │   └── Coordinator/
│   │       └── PetCoordinator.swift
│   │
│   ├── Interaction/
│   │   ├── Views/
│   │   ├── ViewModels/
│   │   └── Coordinator/
│   │
│   ├── Stats/
│   │   ├── Views/
│   │   ├── ViewModels/
│   │   └── Coordinator/
│   │
│   └── Settings/
│       ├── Views/
│       ├── ViewModels/
│       └── Coordinator/
│
├── Resources/
│   ├── Assets.xcassets
│   ├── Localizable.strings
│   └── Info.plist
│
└── AI/
    ├── Models/
    │   └── Phi3Mini.mlmodelc
    ├── Processors/
    └── Predictors/
```

## Consequences

### Positive
- **Separation of Concerns**: Clear boundaries between UI, business logic, and navigation
- **Testability**: ViewModels can be unit tested independently
- **Reusability**: Coordinators enable feature modules to be reused
- **Scalability**: New features can be added as independent modules
- **SwiftUI Compatible**: Natural fit with SwiftUI's declarative nature
- **Type Safety**: Strong typing throughout the architecture

### Negative
- **Initial Complexity**: More boilerplate code initially
- **Learning Curve**: Team needs to understand coordinator pattern
- **Memory Management**: Need to carefully manage coordinator lifecycle

### Mitigation Strategies
- Use protocol-oriented programming for flexibility
- Implement base classes for common coordinator functionality
- Use dependency injection container for service management
- Create code templates for new features