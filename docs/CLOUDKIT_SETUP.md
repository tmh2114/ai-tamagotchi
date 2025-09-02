# CloudKit Setup and Integration Guide

## Overview

The AI Tamagotchi app uses CloudKit for seamless synchronization across all Apple devices. This ensures your pet's data, memories, and progress are always up-to-date whether you're using your iPhone, iPad, or Apple Watch.

## Features

### Core Capabilities
- **Automatic Sync**: Data syncs every 5 minutes or on-demand
- **Real-time Updates**: Push notifications trigger immediate sync
- **Offline Support**: Queue changes when offline, sync when connected
- **Conflict Resolution**: Smart merging of concurrent changes
- **Privacy-First**: All data stored in private CloudKit database
- **Cross-Device**: Seamless sync across iPhone, iPad, Apple Watch

### What Gets Synced
- Pet profile and appearance
- Stats (happiness, health, energy, etc.)
- Interactions and play history
- Important memories
- Achievements and milestones
- User preferences and settings

## Setup Instructions

### 1. Enable CloudKit Capability

In Xcode:
1. Select your project in the navigator
2. Select your app target
3. Go to "Signing & Capabilities" tab
4. Click "+ Capability"
5. Add "iCloud" capability
6. Check "CloudKit" checkbox
7. Select or create container: `iCloud.com.tamagotchi.ai`

### 2. Configure Entitlements

The `AITamagotchi.entitlements` file should already be configured with:
- CloudKit container identifier
- Push notifications
- Background modes
- App groups

### 3. Create CloudKit Schema

First time setup in CloudKit Dashboard:

1. Go to [CloudKit Dashboard](https://icloud.developer.apple.com/dashboard)
2. Select your container
3. Create the following record types:

#### Pet Record Type
```
Fields:
- name (String)
- species (String)
- birthDate (Date)
- personality (Bytes) - JSON encoded
- appearance (Bytes) - JSON encoded
- syncVersion (Int64)
- deviceID (String)
```

#### PetStats Record Type
```
Fields:
- pet (Reference to Pet)
- happiness (Double)
- health (Double)
- hunger (Double)
- energy (Double)
- experience (Int64)
- level (Int64)
```

#### Interaction Record Type
```
Fields:
- pet (Reference to Pet)
- type (String)
- date (Date)
- duration (Double)
- response (String)
- emotionalImpact (Double)
```

#### Memory Record Type
```
Fields:
- pet (Reference to Pet)
- content (String, max 1000 chars)
- emotion (String)
- importance (Double)
- date (Date)
- associations (String List)
```

### 4. Initialize CloudKit in Your App

```swift
import SwiftUI
import CloudKit

@main
struct AITamagotchiApp: App {
    @StateObject private var syncManager = CloudKitSyncManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(syncManager)
                .onAppear {
                    setupCloudKit()
                }
        }
    }
    
    private func setupCloudKit() {
        Task {
            do {
                // Check availability
                let isAvailable = try await CloudKitConfiguration.checkAvailability()
                guard isAvailable else {
                    print("CloudKit not available")
                    return
                }
                
                // Create zone if needed
                try await CloudKitConfiguration.createZoneIfNeeded()
                
                // Setup subscription for push notifications
                try await CloudKitConfiguration.createSubscription()
                
                // Start sync
                syncManager.startSync()
                
            } catch {
                print("CloudKit setup failed: \(error)")
            }
        }
    }
}
```

## Usage Examples

### Manual Sync

```swift
Button("Sync Now") {
    Task {
        do {
            try await syncManager.forceSync()
        } catch {
            print("Sync failed: \(error)")
        }
    }
}
```

### Monitor Sync Status

```swift
struct SyncStatusView: View {
    @EnvironmentObject var syncManager: CloudKitSyncManager
    
    var body: some View {
        HStack {
            Image(systemName: statusIcon)
                .foregroundColor(statusColor)
            
            Text(syncManager.syncStatus.description)
                .font(.caption)
            
            if syncManager.syncStatus == .syncing {
                ProgressView(value: syncManager.syncProgress)
                    .frame(width: 50)
            }
        }
    }
    
    private var statusIcon: String {
        switch syncManager.syncStatus {
        case .idle:
            return "checkmark.icloud"
        case .syncing, .uploading, .downloading:
            return "arrow.triangle.2.circlepath.icloud"
        case .error:
            return "exclamationmark.icloud"
        }
    }
    
    private var statusColor: Color {
        switch syncManager.syncStatus {
        case .idle:
            return .green
        case .syncing, .uploading, .downloading:
            return .blue
        case .error:
            return .red
        }
    }
}
```

### Handle Conflicts

```swift
// Configure conflict resolution strategy
let strategy: CloudKitConfiguration.ConflictResolutionStrategy = .merge

// Resolve conflict when detected
Task {
    let resolvedRecord = try await syncManager.resolveConflict(
        local: localRecord,
        remote: remoteRecord,
        strategy: strategy
    )
}
```

### SwiftData Integration

```swift
import SwiftData

@Model
class Pet {
    // Your pet model
}

// Use the adapter to bridge SwiftData and CloudKit
let adapter = CloudKitDataAdapter(
    modelContext: modelContext,
    syncManager: syncManager
)

// Sync local changes to CloudKit
Task {
    try await adapter.syncLocalChangesToCloudKit()
}

// Process CloudKit changes
Task {
    let changes = try await syncManager.downloadChanges()
    try await adapter.processCloudKitChanges(changes)
}
```

## Privacy and Security

### Data Protection
- All data stored in private CloudKit database
- Only accessible by authenticated user
- No data shared between users by default
- Sensitive data can be encrypted before upload

### Privacy Configuration
```swift
// Configure privacy settings
CloudKitConfiguration.PrivacyConfiguration.encryptSensitiveData = true
CloudKitConfiguration.PrivacyConfiguration.maxMemoryContentLength = 1000
```

### Excluded Fields
Some fields are never synced for privacy:
- Local notification tokens
- Debug logs
- Device-specific identifiers

## Performance Optimization

### Batch Operations
- Records uploaded in batches of 100
- Automatic chunking for large datasets
- Delta sync using server change tokens

### Background Sync
- Automatic sync every 5 minutes
- Push notifications for immediate updates
- Intelligent retry with exponential backoff

### Offline Queue
- Changes queued when offline
- Automatic sync when connection restored
- Conflict resolution for concurrent edits

## Troubleshooting

### Common Issues

#### "Not Signed In to iCloud"
- User needs to sign in to iCloud in Settings
- Enable iCloud Drive for the app

#### "Container Not Available"
- Check entitlements file
- Verify container ID matches
- Ensure CloudKit capability is enabled

#### "Sync Conflicts"
- Review conflict resolution strategy
- Check for concurrent edits
- Ensure proper record versioning

#### "Quota Exceeded"
- User's iCloud storage is full
- Implement data cleanup strategies
- Consider limiting sync data size

### Debug Logging

Enable detailed logging:
```swift
CloudKitConfiguration.logger.logLevel = .debug
```

View sync errors:
```swift
for error in syncManager.syncErrors {
    print("Sync error: \(error)")
}
```

## Testing

### Simulator Testing
- CloudKit works in simulator with Apple ID
- Sign in to iCloud in simulator settings
- Use development environment

### Device Testing
1. Install app on multiple devices
2. Sign in with same Apple ID
3. Make changes on one device
4. Verify sync on other devices

### Test Scenarios
- Create pet on iPhone, verify on iPad
- Modify stats on Apple Watch, check iPhone
- Test offline changes and sync
- Simulate conflicts with concurrent edits
- Test with poor network conditions

## Best Practices

1. **Always check CloudKit availability** before operations
2. **Handle errors gracefully** with user-friendly messages
3. **Respect user privacy** - minimal data collection
4. **Optimize for battery** - batch operations, smart scheduling
5. **Test thoroughly** - multiple devices, network conditions
6. **Monitor performance** - track sync times, failures
7. **Document changes** - maintain schema version history

## Migration Guide

If updating from local-only storage:

1. Export existing local data
2. Convert to CloudKit format
3. Upload in batches
4. Verify data integrity
5. Enable ongoing sync

## Support

For CloudKit issues:
- Check Apple's CloudKit documentation
- Review CloudKit Dashboard for errors
- Monitor push notification delivery
- Use Console.app for detailed logs

## Future Enhancements

Planned improvements:
- Public database for community features
- Shared pet experiences
- Cross-user pet interactions
- CloudKit sharing for family pets
- Advanced conflict resolution UI