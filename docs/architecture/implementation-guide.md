# AI Tamagotchi Implementation Guide

## Quick Start for Developers

This guide provides practical implementation details for the AI Tamagotchi architecture.

## Project Setup

### 1. Xcode Project Structure
```bash
# Create new Xcode project
# Select: iOS App
# Interface: SwiftUI
# Language: Swift
# Include: 
#   - Use Core Data ✓
#   - Include Tests ✓
#   - Use Git ✓
```

### 2. Target Configuration
```
Targets:
- AITamagotchi (iOS App)
- AITamagotchi Watch (watchOS App)
- AITamagotchiKit (Shared Framework)
- AITamagotchiTests (Unit Tests)
- AITamagotchiUITests (UI Tests)
```

### 3. Minimum Deployment Targets
- iOS: 17.0
- watchOS: 10.0

## MVVM-C Implementation

### Base Coordinator Protocol
```swift
// Coordinators/Coordinator.swift
protocol Coordinator: AnyObject {
    var childCoordinators: [Coordinator] { get set }
    var navigationController: UINavigationController? { get set }
    
    func start()
    func coordinate(to coordinator: Coordinator)
    func removeChild(_ coordinator: Coordinator)
}

extension Coordinator {
    func coordinate(to coordinator: Coordinator) {
        childCoordinators.append(coordinator)
        coordinator.start()
    }
    
    func removeChild(_ coordinator: Coordinator) {
        childCoordinators.removeAll { $0 === coordinator }
    }
}
```

### Base ViewModel
```swift
// ViewModels/BaseViewModel.swift
import Combine

class BaseViewModel: ObservableObject {
    var cancellables = Set<AnyCancellable>()
    
    @Published var isLoading = false
    @Published var error: Error?
    
    func handleError(_ error: Error) {
        self.error = error
        // Log error
        print("Error: \(error.localizedDescription)")
    }
}
```

### SwiftUI Coordinator Integration
```swift
// Views/CoordinatorView.swift
struct CoordinatorView: View {
    @StateObject var coordinator: AppCoordinator
    
    var body: some View {
        NavigationStack(path: $coordinator.path) {
            coordinator.rootView()
                .navigationDestination(for: Route.self) { route in
                    coordinator.view(for: route)
                }
        }
    }
}
```

## CoreML Integration Examples

### Model Loading
```swift
// AI/Services/ModelLoader.swift
import CoreML

class ModelLoader {
    static let shared = ModelLoader()
    private var modelCache = [String: MLModel]()
    
    func loadPhi3Mini() async throws -> MLModel {
        if let cached = modelCache["phi3mini"] {
            return cached
        }
        
        guard let modelURL = Bundle.main.url(
            forResource: "Phi3Mini",
            withExtension: "mlmodelc"
        ) else {
            throw ModelError.notFound
        }
        
        let config = MLModelConfiguration()
        config.computeUnits = .all
        
        let model = try await MLModel.load(
            contentsOf: modelURL,
            configuration: config
        )
        
        modelCache["phi3mini"] = model
        return model
    }
}
```

### AI Service Implementation
```swift
// AI/Services/AIService.swift
import CoreML

class AIService: ObservableObject {
    @Published var isProcessing = false
    private var model: MLModel?
    private let tokenizer = Phi3Tokenizer()
    
    func initialize() async {
        do {
            model = try await ModelLoader.shared.loadPhi3Mini()
        } catch {
            print("Failed to load model: \(error)")
        }
    }
    
    func generateResponse(for input: String) async -> String {
        guard let model = model else { return "Model not loaded" }
        
        isProcessing = true
        defer { isProcessing = false }
        
        // Tokenize input
        let tokens = tokenizer.encode(input)
        
        // Prepare MLFeatureProvider
        let input = try! MLDictionaryFeatureProvider(
            dictionary: ["input": MLMultiArray(tokens)]
        )
        
        // Run prediction
        let output = try! await model.prediction(from: input)
        
        // Decode output
        let outputTokens = output.featureValue(for: "output")?.multiArrayValue
        return tokenizer.decode(outputTokens)
    }
}
```

## SwiftUI Views Implementation

### Main Pet View
```swift
// Features/Pet/Views/PetView.swift
import SwiftUI

struct PetView: View {
    @StateObject private var viewModel = PetViewModel()
    @EnvironmentObject var coordinator: PetCoordinator
    
    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [.blue.opacity(0.3), .purple.opacity(0.3)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack {
                // Pet Display
                PetDisplayView(pet: viewModel.pet)
                    .frame(height: 300)
                
                // Status Bars
                PetStatusBars(pet: viewModel.pet)
                    .padding()
                
                // Interaction Area
                InteractionButtons(
                    actions: viewModel.availableActions,
                    onAction: viewModel.performAction
                )
                
                Spacer()
            }
        }
        .task {
            await viewModel.loadPet()
        }
    }
}
```

### Reusable Components
```swift
// Features/Pet/Views/Components/PetStatusBars.swift
struct PetStatusBars: View {
    let pet: Pet
    
    var body: some View {
        VStack(spacing: 12) {
            StatusBar(
                label: "Happiness",
                value: pet.happiness,
                color: .yellow
            )
            StatusBar(
                label: "Health",
                value: pet.health,
                color: .red
            )
            StatusBar(
                label: "Energy",
                value: pet.energy,
                color: .green
            )
        }
    }
}

struct StatusBar: View {
    let label: String
    let value: Double
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.2))
                    
                    RoundedRectangle(cornerRadius: 8)
                        .fill(color)
                        .frame(width: geometry.size.width * value)
                        .animation(.spring(), value: value)
                }
            }
            .frame(height: 20)
        }
    }
}
```

## Data Layer Implementation

### Core Data Models
```swift
// Models/CoreData/Pet+CoreDataClass.swift
import CoreData

@objc(Pet)
public class Pet: NSManagedObject {
    
}

extension Pet {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<Pet> {
        return NSFetchRequest<Pet>(entityName: "Pet")
    }
    
    @NSManaged public var id: UUID
    @NSManaged public var name: String
    @NSManaged public var happiness: Double
    @NSManaged public var health: Double
    @NSManaged public var energy: Double
    @NSManaged public var personality: Data // JSON encoded
    @NSManaged public var createdAt: Date
    @NSManaged public var lastInteraction: Date
}
```

### Data Service
```swift
// Services/DataService.swift
import CoreData

class DataService {
    static let shared = DataService()
    
    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "AITamagotchi")
        container.loadPersistentStores { _, error in
            if let error = error {
                fatalError("Core Data failed: \(error)")
            }
        }
        return container
    }()
    
    func save() {
        let context = persistentContainer.viewContext
        
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                print("Save failed: \(error)")
            }
        }
    }
    
    func fetchPet() -> Pet? {
        let request: NSFetchRequest<Pet> = Pet.fetchRequest()
        request.fetchLimit = 1
        request.sortDescriptors = [
            NSSortDescriptor(key: "createdAt", ascending: false)
        ]
        
        do {
            return try persistentContainer.viewContext.fetch(request).first
        } catch {
            print("Fetch failed: \(error)")
            return nil
        }
    }
}
```

## Watch App Implementation

### Simplified Watch Views
```swift
// Watch/Views/PetWatchView.swift
import SwiftUI

struct PetWatchView: View {
    @StateObject private var viewModel = WatchPetViewModel()
    
    var body: some View {
        ScrollView {
            VStack {
                // Simplified pet display
                Image(viewModel.petImageName)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 100)
                
                // Quick stats
                HStack {
                    StatIcon(icon: "heart.fill", value: viewModel.health)
                    StatIcon(icon: "star.fill", value: viewModel.happiness)
                    StatIcon(icon: "bolt.fill", value: viewModel.energy)
                }
                
                // Quick actions
                VStack {
                    Button("Feed") { viewModel.feed() }
                    Button("Play") { viewModel.play() }
                    Button("Rest") { viewModel.rest() }
                }
                .buttonStyle(.bordered)
            }
        }
    }
}
```

### Watch Complications
```swift
// Watch/Complications/PetComplication.swift
import WidgetKit
import SwiftUI

struct PetComplication: Widget {
    let kind: String = "PetComplication"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            PetComplicationView(entry: entry)
        }
        .configurationDisplayName("AI Pet")
        .description("Your pet's status")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline
        ])
    }
}
```

## Testing Implementation

### Unit Test Example
```swift
// Tests/ViewModelTests/PetViewModelTests.swift
import XCTest
@testable import AITamagotchi

class PetViewModelTests: XCTestCase {
    var viewModel: PetViewModel!
    
    override func setUp() {
        super.setUp()
        viewModel = PetViewModel()
    }
    
    func testFeedingIncreasesSatisfaction() async {
        let initialHunger = viewModel.pet.hunger
        
        await viewModel.performAction(.feed)
        
        XCTAssertLessThan(viewModel.pet.hunger, initialHunger)
        XCTAssertGreaterThan(viewModel.pet.happiness, 0)
    }
}
```

### UI Test Example
```swift
// UITests/PetInteractionTests.swift
import XCTest

class PetInteractionTests: XCTestCase {
    func testFeedingInteraction() {
        let app = XCUIApplication()
        app.launch()
        
        // Navigate to pet view
        app.buttons["Pet"].tap()
        
        // Perform feeding
        app.buttons["Feed"].tap()
        
        // Verify feedback
        XCTAssertTrue(app.staticTexts["Yummy!"].exists)
    }
}
```

## Performance Monitoring

### Memory Management
```swift
// Utilities/MemoryMonitor.swift
class MemoryMonitor {
    static func logMemoryUsage() {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if result == KERN_SUCCESS {
            let usedMB = Double(info.resident_size) / 1024.0 / 1024.0
            print("Memory used: \(String(format: "%.1f", usedMB)) MB")
        }
    }
}
```

## Build and Deployment

### Build Configuration
```swift
// In Xcode Build Settings
// Debug Configuration
SWIFT_OPTIMIZATION_LEVEL = -Onone
DEBUG_INFORMATION_FORMAT = dwarf

// Release Configuration  
SWIFT_OPTIMIZATION_LEVEL = -O
DEBUG_INFORMATION_FORMAT = dwarf-with-dsym
ENABLE_BITCODE = NO // For CoreML
```

### App Store Preparation
```bash
# Archive for App Store
xcodebuild archive \
  -scheme AITamagotchi \
  -archivePath ./build/AITamagotchi.xcarchive

# Export IPA
xcodebuild -exportArchive \
  -archivePath ./build/AITamagotchi.xcarchive \
  -exportPath ./build \
  -exportOptionsPlist ExportOptions.plist
```

## Next Steps

1. Set up Xcode project with targets
2. Implement base coordinators and view models
3. Integrate CoreML model
4. Build core UI components
5. Set up data persistence
6. Implement Watch app
7. Add unit and UI tests
8. Configure CI/CD pipeline