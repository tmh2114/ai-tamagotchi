# CloudKit Setup Guide

## Overview

CloudKit provides seamless synchronization across all Apple devices, enabling your AI Tamagotchi pet to follow users everywhere in the Apple ecosystem. This implementation ensures data consistency, privacy, and optimal performance.

## Architecture

### Components

1. **CloudKitConfiguration.swift**
   - Central configuration for CloudKit container
   - Record type and key definitions
   - Error handling
   - Zone management

2. **CloudKitSyncManager.swift**
   - Orchestrates sync operations
   - Handles conflict resolution
   - Manages background sync
   - Push notification handling

3. **CloudKitModels.swift**
   - CloudKit-specific data models
   - Conversion between local and cloud formats
   - Type-safe record handling

4. **CloudKitDataAdapter.swift**
   - Bridges SwiftData and CloudKit
   - Manages data transformations
   - Handles model versioning

## Implementation Features

### 🔄 Automatic Synchronization
- **Background Sync**: Periodic sync every 5 minutes
- **Push Notifications**: Instant updates across devices
- **Smart Batching**: Efficient batch uploads (100 records per batch)
- **Delta Sync**: Only syncs changed data using server tokens

### 🔐 Privacy & Security
- **Private Database**: All user data stored in private CloudKit database
- **Encryption**: Sensitive data encrypted before upload
- **User Control**: Sync preferences and privacy settings
- **No Third-Party Access**: Data never leaves Apple's servers

### ⚡ Performance Optimization
- **Chunked Uploads**: Large datasets split into manageable chunks
- **Retry Logic**: Automatic retry with exponential backoff
- **Offline Support**: Queue changes when offline, sync when connected
- **Efficient Queries**: Zone-based fetching for minimal data transfer

### 🎯 Conflict Resolution
Multiple strategies available:
- **Server Wins**: Cloud data takes precedence
- **Client Wins**: Local data takes precedence
- **Merge**: Intelligent merging of non-conflicting changes
- **User Choice**: Present conflicts for manual resolution

## Setup Instructions

### 1. Configure Apple Developer Account

1. Sign in to [Apple Developer Portal](https://developer.apple.com)
2. Navigate to Certificates, Identifiers & Profiles
3. Create App ID with CloudKit capability enabled
4. Create CloudKit container: `iCloud.com.totomono.AITamagotchi`

### 2. Configure Xcode Project

1. Open project in Xcode
2. Select your target → Signing & Capabilities
3. Add CloudKit capability
4. Select the CloudKit container created above
5. Add Push Notifications capability
6. Add Background Modes → Remote notifications

### 3. Configure Entitlements

The `AITamagotchi.entitlements` file is already configured with:
- CloudKit container identifier
- Push notification environment
- App Groups for widget data sharing
- HealthKit integration

### 4. Initialize CloudKit in App

```swift
import SwiftUI
import CloudKit

@main
struct AITamagotchiApp: App {
    @StateObject private var syncManager = CloudKitSyncManager.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .task {
                    await syncManager.startSync()
                }
        }
    }
}
```

### 5. Handle Remote Notifications

```swift
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, 
                    didReceiveRemoteNotification userInfo: [AnyHashable : Any]) async {
        await CloudKitSyncManager.shared.handleRemoteNotification(userInfo)
    }
}
```

## Data Model Schema

### Pet Record
- `petID`: Unique identifier
- `name`: Pet's name
- `species`: Type of pet
- `birthDate`: Creation date
- `level`: Current level
- `experience`: XP points
- `personalityData`: Encoded personality traits
- `healthData`: Health metrics

### Interaction Record
- `interactionID`: Unique identifier
- `petID`: Associated pet
- `type`: Interaction type
- `timestamp`: When it occurred
- `sentiment`: Emotional analysis
- `content`: User input
- `response`: Pet's response

### Sync Metadata
- `deviceID`: Device identifier
- `lastSyncDate`: Last successful sync
- `syncToken`: Server change token
- `recordVersions`: Version tracking

## Usage Examples

### Manual Sync Trigger
```swift
Button("Sync Now") {
    Task {
        await CloudKitSyncManager.shared.startSync()
    }
}
```

### Monitor Sync Status
```swift
struct SyncStatusView: View {
    @ObservedObject private var syncManager = CloudKitSyncManager.shared
    
    var body: some View {
        VStack {
            switch syncManager.syncState {
            case .idle:
                Text("Ready to sync")
            case .syncing:
                ProgressView("Syncing...")
            case .completed(let date):
                Text("Last synced: \(date, style: .relative)")
            case .failed(let error):
                Text("Sync failed: \(error.localizedDescription)")
            case .offline:
                Text("Offline - will sync when connected")
            case .conflict:
                Text("Conflict detected - review required")
            }
        }
    }
}
```

### Configure Sync Options
```swift
let options = CloudKitSyncManager.SyncOptions(
    syncInterval: 300, // 5 minutes
    conflictResolution: .merge,
    batchSize: 100,
    retryAttempts: 3,
    includeSharedData: true,
    syncOnCellular: false
)

CloudKitSyncManager.shared.configureSyncOptions(options)
```

## Testing CloudKit

### Development Environment
1. Use CloudKit Dashboard to inspect records
2. Test with multiple simulators/devices
3. Verify push notifications delivery
4. Test offline/online transitions

### Production Readiness
1. Test with TestFlight users
2. Monitor CloudKit Dashboard for usage
3. Set up proper error logging
4. Configure rate limiting

## Troubleshooting

### Common Issues

1. **"Not Authenticated"**
   - Ensure user is signed into iCloud
   - Check Settings → [User] → iCloud

2. **"Quota Exceeded"**
   - Check CloudKit Dashboard for usage
   - Implement data cleanup strategies
   - Consider upgrading storage tier

3. **"Network Unavailable"**
   - Verify internet connection
   - Check airplane mode
   - Test cellular data settings

4. **Sync Not Working**
   - Verify entitlements configuration
   - Check CloudKit container ID
   - Ensure push notifications enabled
   - Review console logs for errors

### Debug Tools

```swift
// Enable verbose logging
CloudKitSyncManager.shared.enableDebugLogging = true

// View sync errors
let errors = CloudKitSyncManager.shared.syncErrors
errors.forEach { error in
    print("\(error.timestamp): \(error.error)")
}

// Reset sync state
await CloudKitSyncManager.shared.resetSync()
```

## Best Practices

1. **Data Modeling**
   - Keep records under 1MB
   - Use references for relationships
   - Batch related updates together

2. **Performance**
   - Implement progressive sync
   - Cache frequently accessed data
   - Use change tokens efficiently

3. **User Experience**
   - Show sync status in UI
   - Handle conflicts gracefully
   - Provide manual sync option
   - Respect cellular data preferences

4. **Privacy**
   - Encrypt sensitive data
   - Implement data retention policies
   - Provide export/delete options
   - Document data usage clearly

## Migration Guide

### From Core Data to CloudKit
1. Export existing Core Data records
2. Transform to CloudKit models
3. Upload in batches
4. Verify data integrity
5. Update app to use CloudKit

### Version Updates
- Use `modelVersion` field for compatibility
- Implement migration logic for schema changes
- Test thoroughly with production data

## Monitoring & Analytics

### Key Metrics to Track
- Sync success rate
- Average sync duration
- Conflict frequency
- Data transfer volume
- Error rates by type

### CloudKit Dashboard
Access at: https://icloud.developer.apple.com/dashboard
- Monitor usage statistics
- View record types and counts
- Inspect individual records
- Manage indexes and subscriptions

## Security Considerations

1. **Data Encryption**
   - Sensitive fields encrypted client-side
   - Use CryptoKit for encryption
   - Store keys in Keychain

2. **Access Control**
   - Private database for user data
   - Public database for shared content (future)
   - Implement proper authentication

3. **Data Validation**
   - Validate all inputs before sync
   - Implement size limits
   - Sanitize user-generated content

## Future Enhancements

### Planned Features
- [ ] Shared pet experiences (public database)
- [ ] Cross-user interactions
- [ ] CloudKit sharing for families
- [ ] Advanced conflict resolution UI
- [ ] Selective sync for large datasets
- [ ] Background refresh optimization

### Performance Improvements
- [ ] Predictive prefetching
- [ ] Compression for large records
- [ ] Intelligent sync scheduling
- [ ] Differential sync optimization

## Resources

- [CloudKit Documentation](https://developer.apple.com/documentation/cloudkit)
- [CloudKit Best Practices](https://developer.apple.com/videos/play/wwdc2020/10650/)
- [CloudKit Dashboard](https://icloud.developer.apple.com/dashboard)
- [WWDC CloudKit Sessions](https://developer.apple.com/videos/frameworks/cloudkit)