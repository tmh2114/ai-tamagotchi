# ADR-002: SwiftUI Integration Strategy

## Status
Accepted

## Context
SwiftUI is Apple's modern declarative UI framework that provides a unified way to build user interfaces across all Apple platforms. We need to define how SwiftUI will be integrated with our MVVM-C architecture.

## Decision

### SwiftUI Core Principles

#### 1. Declarative UI Design
- Views are functions of state
- Use `@State`, `@StateObject`, `@ObservedObject`, and `@EnvironmentObject` appropriately
- Minimize view logic, delegate to ViewModels

#### 2. View Composition Strategy
```swift
// Example view composition
struct PetView: View {
    @StateObject private var viewModel: PetViewModel
    @EnvironmentObject var coordinator: PetCoordinator
    
    var body: some View {
        VStack {
            PetStatusHeader(status: viewModel.petStatus)
            PetInteractionArea(pet: viewModel.pet)
            PetActionButtons(actions: viewModel.availableActions)
        }
    }
}
```

#### 3. State Management

##### Local State (@State)
- UI-only state (animations, toggles, temporary values)
- Single view scope
```swift
@State private var isAnimating = false
@State private var selectedTab = 0
```

##### ViewModel State (@StateObject / @ObservedObject)
- Business logic state
- Shared across view hierarchy
```swift
@StateObject private var petViewModel = PetViewModel()
@ObservedObject var interactionViewModel: InteractionViewModel
```

##### App-wide State (@EnvironmentObject)
- Global app state
- User preferences
- Navigation coordinators
```swift
@EnvironmentObject var appState: AppState
@EnvironmentObject var coordinator: AppCoordinator
```

### Navigation Strategy

#### 1. NavigationStack with Coordinators
```swift
struct ContentView: View {
    @StateObject private var coordinator = AppCoordinator()
    
    var body: some View {
        NavigationStack(path: $coordinator.navigationPath) {
            RootView()
                .navigationDestination(for: Destination.self) { destination in
                    coordinator.view(for: destination)
                }
        }
        .environmentObject(coordinator)
    }
}
```

#### 2. Sheet and Alert Management
```swift
extension View {
    func sheet(item: Binding<SheetDestination?>) -> some View {
        self.sheet(item: item) { destination in
            SheetCoordinator.view(for: destination)
        }
    }
}
```

### Animation and Interaction Design

#### 1. Pet Animations
```swift
struct PetAnimationView: View {
    @State private var animationPhase = 0.0
    
    var body: some View {
        Image(petImageName)
            .scaleEffect(1.0 + sin(animationPhase) * 0.1)
            .animation(.easeInOut(duration: 2).repeatForever(), value: animationPhase)
            .onAppear { animationPhase = .pi * 2 }
    }
}
```

#### 2. Gesture Handling
```swift
struct InteractiveView: View {
    var body: some View {
        PetView()
            .gesture(
                DragGesture()
                    .onChanged { value in
                        viewModel.handleDrag(value)
                    }
            )
            .onTapGesture {
                viewModel.handleTap()
            }
    }
}
```

### Platform-Specific Considerations

#### iPhone
- Full feature set
- Complex navigation flows
- Rich animations
- Camera integration for AR features

#### Apple Watch
- Simplified UI
- Quick interactions
- Complication support
- Health integration

#### Shared Components
```swift
#if os(iOS)
struct PetDetailView: View {
    // iPhone-specific detailed view
}
#elseif os(watchOS)
struct PetDetailView: View {
    // Watch-specific compact view
}
#endif
```

### Performance Optimizations

#### 1. View Identity
- Use `.id()` modifier sparingly
- Implement Identifiable for list items
- Stable view identities for animations

#### 2. Lazy Loading
```swift
ScrollView {
    LazyVStack {
        ForEach(items) { item in
            ItemView(item: item)
        }
    }
}
```

#### 3. Task Management
```swift
.task {
    await viewModel.loadData()
}
.task(id: petId) {
    await viewModel.loadPet(id: petId)
}
```

### Accessibility

#### VoiceOver Support
```swift
PetView()
    .accessibilityLabel("Your pet \(pet.name)")
    .accessibilityHint("Double tap to interact")
    .accessibilityValue("\(pet.happiness) happiness")
```

#### Dynamic Type
```swift
Text(pet.status)
    .font(.body)
    .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
```

## Consequences

### Positive
- **Native Performance**: Direct use of Apple's optimized framework
- **Cross-Platform**: Single codebase for iPhone and Apple Watch
- **Modern Patterns**: Reactive programming and declarative syntax
- **Future-Proof**: Apple's primary UI framework investment
- **Built-in Animations**: Rich animation system included

### Negative
- **iOS 17+ Requirement**: Latest SwiftUI features require recent OS versions
- **Limited Customization**: Some UI elements harder to customize than UIKit
- **Learning Curve**: Different paradigm from imperative UI

### Best Practices
1. Keep views simple and focused
2. Extract reusable components
3. Use view modifiers for common styling
4. Leverage environment values for dependency injection
5. Test ViewModels independently from views
6. Use Previews for rapid UI development