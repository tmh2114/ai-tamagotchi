# CloudKit Integration for AI Tamagotchi

## Overview

This CloudKit implementation provides seamless synchronization of AI Tamagotchi data across all Apple devices (iPhone, iPad, Apple Watch, Mac) using Apple's native cloud infrastructure.

## Features

### Core Functionality
- ✅ **Automatic Sync**: Real-time synchronization across all devices
- ✅ **Offline Support**: Queue operations when offline, sync when connected
- ✅ **Conflict Resolution**: Smart last-write-wins strategy with metadata preservation
- ✅ **Background Sync**: Silent push notifications for instant updates
- ✅ **Privacy-First**: All data stored in user's private CloudKit database

### Data Types Synced
1. **Pet Data**: Name, stats, personality, evolution stage
2. **Interactions**: Chat history with AI responses
3. **Achievements**: Unlocked milestones and badges
4. **Settings**: User preferences (optional)

## Setup Instructions

### 1. Enable CloudKit Capability

In Xcode:
1. Select your project target
2. Go to "Signing & Capabilities"
3. Click "+" and add "CloudKit"
4. Select or create a CloudKit container

### 2. Configure CloudKit Dashboard

1. Go to [CloudKit Dashboard](https://icloud.developer.apple.com/dashboard)
2. Select your container
3. Create the following record types:

#### Pet Record Type
```
Fields:
- id (String)
- name (String)
- species (String)
- personality (String)
- happiness (Double)
- hunger (Double)
- health (Double)
- age (Int64)
- evolutionStage (Int64)
- lastInteraction (Date/Time)
- birthDate (Date/Time)
- personalityTraits (Bytes)
- modifiedDate (Date/Time)
```

#### Interaction Record Type
```
Fields:
- id (String)
- petId (String)
- type (String)
- message (String)
- response (String)
- timestamp (Date/Time)
- emotionalImpact (Double)
```

#### Achievement Record Type
```
Fields:
- id (String)
- petId (String)
- type (String)
- name (String)
- description (String)
- unlockedDate (Date/Time)
```

### 3. Update Info.plist

Add CloudKit container identifier:
```xml
<key>CKSharingSupported</key>
<true/>
```

### 4. Initialize in App

```swift
import SwiftUI

@main
struct AITamagotchiApp: App {
    @StateObject private var cloudKitViewModel = CloudKitViewModel()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(cloudKitViewModel)
                .task {
                    await cloudKitViewModel.performInitialSync()
                }
        }
    }
}
```

## Usage Examples

### Creating a New Pet
```swift
await viewModel.createPet(name: "Buddy", species: "Dragon")
```

### Adding an Interaction
```swift
await viewModel.addInteraction(
    type: "chat",
    message: "How are you today?",
    response: "I'm feeling great! Want to play?",
    emotionalImpact: 5.0
)
```

### Manual Sync
```swift
await viewModel.performSync()
```

### Checking Sync Status
```swift
if viewModel.syncStatus == .syncing {
    // Show loading indicator
}

if let lastSync = viewModel.lastSyncTime {
    Text("Last synced: \(lastSync, formatter: dateFormatter)")
}
```

## Architecture

### Components

1. **CloudKitContainer.swift**
   - Manages CloudKit container and databases
   - Sets up push notification subscriptions
   - Handles account status checks

2. **CloudKitSyncManager.swift**
   - Core sync logic and operations
   - Offline queue management
   - Conflict resolution
   - Batch operations

3. **CloudKitViewModel.swift**
   - SwiftUI integration layer
   - Auto-sync timer management
   - User-facing operations

4. **NetworkMonitor.swift**
   - Network connectivity monitoring
   - Automatic sync triggers
   - Connection type detection

5. **CloudKitModels.swift**
   - Data models with CloudKit support
   - Conversion utilities
   - Codable implementations

### Sync Flow

```
1. User Action → 
2. Update Local Data → 
3. Queue Sync Operation →
4. Check Network Status →
   - If Online: Execute Immediately
   - If Offline: Store in Queue
5. Process Sync Queue →
6. Handle Conflicts →
7. Update UI
```

## Best Practices

### Performance
- Batch operations when possible
- Use query limits for large datasets
- Implement pagination for history
- Cache frequently accessed data

### Security
- All data in private database by default
- No sensitive data in record names
- Use CloudKit sharing for multiplayer features

### Error Handling
- Graceful degradation when offline
- Clear error messages to users
- Retry logic for transient failures
- Conflict resolution UI when needed

## Testing

### Unit Tests
```swift
func testPetDataSync() async throws {
    let pet = TamagotchiPet(name: "Test", species: "Cat")
    try await syncManager.syncPetData(pet)
    
    let fetched = try await syncManager.fetchPetData()
    XCTAssertEqual(fetched?.name, "Test")
}
```

### Integration Tests
- Test offline queue persistence
- Verify conflict resolution
- Check subscription delivery
- Validate data integrity

## Troubleshooting

### Common Issues

1. **"No iCloud Account"**
   - User needs to sign in to iCloud
   - Check Settings → Apple ID → iCloud

2. **Sync Not Working**
   - Verify CloudKit entitlements
   - Check container identifier
   - Review CloudKit Dashboard logs

3. **Data Not Appearing**
   - Ensure proper record types created
   - Check database (private vs public)
   - Verify subscription setup

## Future Enhancements

- [ ] CloudKit Sharing for multiplayer
- [ ] Public database for leaderboards
- [ ] Asset storage for custom pet images
- [ ] Advanced conflict resolution UI
- [ ] Sync analytics and metrics

## Resources

- [CloudKit Documentation](https://developer.apple.com/documentation/cloudkit)
- [CloudKit Best Practices](https://developer.apple.com/videos/play/wwdc2021/10015/)
- [CloudKit Dashboard](https://icloud.developer.apple.com/dashboard)