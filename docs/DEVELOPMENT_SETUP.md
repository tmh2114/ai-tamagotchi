# Development Setup Guide

## Prerequisites

### System Requirements
- **macOS**: Sonoma 14.0 or later
- **Xcode**: 15.0 or later (download from Mac App Store)
- **Storage**: At least 10GB free space for Xcode and development

### Hardware Requirements
- **Mac**: Apple Silicon (M1/M2/M3) or Intel Mac
- **iPhone**: iPhone 12 or later with iOS 17+ (for testing)
- **Apple Watch**: Series 6 or later with watchOS 10+ (optional)
- **RAM**: 8GB minimum, 16GB recommended

## Installation Steps

### 1. Install Xcode
```bash
# Install from Mac App Store or download from developer.apple.com
# After installation, accept license and install additional components
sudo xcode-select --install
sudo xcodebuild -license accept
```

### 2. Install Command Line Tools
```bash
# Install Swift and development tools
xcode-select --install
```

### 3. Verify Swift Version
```bash
swift --version
# Should show: Swift version 5.9 or later
```

### 4. Clone Repository
```bash
git clone https://github.com/yourusername/ai-tamagotchi.git
cd ai-tamagotchi
```

### 5. Open in Xcode
```bash
# Open workspace
open AITamagotchi.xcworkspace

# Or open project directly
open AITamagotchi.xcodeproj
```

## Project Configuration

### 1. Team & Signing
1. Open project settings in Xcode
2. Select the AITamagotchi target
3. Go to "Signing & Capabilities" tab
4. Select your development team
5. Enable "Automatically manage signing"

### 2. Bundle Identifier
```
com.yourcompany.aitamagotchi        # iOS App
com.yourcompany.aitamagotchi.watchkitapp  # watchOS App
```

### 3. Capabilities Setup

#### iOS App Capabilities
- ☑️ CloudKit
- ☑️ HealthKit
- ☑️ Push Notifications
- ☑️ Background Modes
  - Remote notifications
  - Background processing
  - Audio (if needed)
- ☑️ App Groups (create group.com.yourcompany.aitamagotchi)
- ☑️ Siri & Shortcuts

#### watchOS App Capabilities
- ☑️ CloudKit
- ☑️ HealthKit
- ☑️ Push Notifications
- ☑️ App Groups (same as iOS)

### 4. Provisioning Profiles
1. Automatic provisioning (recommended for development)
2. Manual provisioning for distribution

## Environment Setup

### 1. Create Configuration Files
```bash
# Copy example configurations
cp Config/Development.xcconfig.example Config/Development.xcconfig
cp Config/Production.xcconfig.example Config/Production.xcconfig
```

### 2. CloudKit Setup
1. Go to [CloudKit Dashboard](https://icloud.developer.apple.com)
2. Create new container: `iCloud.com.yourcompany.aitamagotchi`
3. Configure schema (will be auto-created on first run)

### 3. HealthKit Setup
1. Add HealthKit entitlement
2. Configure privacy descriptions in Info.plist
3. Select data types to access

## Build & Run

### Building for iOS Simulator
```bash
# Command line
xcodebuild -workspace AITamagotchi.xcworkspace \
  -scheme AITamagotchi \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  build

# Or in Xcode
# Select iPhone simulator from device menu
# Press Cmd+R to build and run
```

### Building for Physical Device
1. Connect iPhone via USB or WiFi
2. Trust the computer on device
3. Select device in Xcode
4. Build and run (Cmd+R)

### Building for Apple Watch
1. Pair Apple Watch with iPhone
2. Enable Developer Mode on Watch
3. Select Watch scheme
4. Build and run

## Swift Package Dependencies

### Adding Dependencies
```swift
// In Package.swift
dependencies: [
    .package(url: "https://github.com/example/package.git", from: "1.0.0")
]
```

### Updating Dependencies
```bash
# In Xcode
# File → Packages → Update to Latest Package Versions

# Or command line
swift package update
```

## Testing Setup

### Unit Tests
```bash
# Run all tests
swift test

# Or in Xcode
# Press Cmd+U
```

### UI Tests
```bash
# Run UI tests
xcodebuild test \
  -workspace AITamagotchi.xcworkspace \
  -scheme AITamagotchiUITests \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro'
```

### Test Plans
1. Create test plan in Xcode
2. Configure test settings
3. Set up CI/CD integration

## Debugging Tools

### Xcode Debugging
- Breakpoints (Cmd+\)
- View Debugger
- Memory Graph Debugger
- Thread Sanitizer
- Address Sanitizer

### Instruments
```bash
# Open Instruments
xcrun instruments

# Common templates:
# - Time Profiler
# - Memory Leaks
# - Energy Diagnostics
# - Core ML Performance
```

### Console Logging
```swift
import os

let logger = Logger(subsystem: "com.yourcompany.aitamagotchi", category: "PetEngine")
logger.debug("Pet state changed")
```

## Code Quality

### SwiftLint Setup (Optional)
```bash
# Install SwiftLint
brew install swiftlint

# Create configuration
touch .swiftlint.yml

# Add build phase in Xcode
# Build Phases → + → New Run Script Phase
# Add: swiftlint
```

### Code Formatting
```bash
# Install swift-format
brew install swift-format

# Format code
swift-format -i Sources/**/*.swift
```

## Troubleshooting

### Common Issues

#### Issue: "No team selected"
**Solution**: Select your Apple Developer team in project settings

#### Issue: "Provisioning profile doesn't match"
**Solution**: 
1. Clean build folder (Cmd+Shift+K)
2. Delete derived data
3. Regenerate provisioning profiles

#### Issue: "Module 'CoreML' not found"
**Solution**: Check minimum deployment target is iOS 17.0

#### Issue: "SwiftData schema error"
**Solution**: Delete app from simulator/device and reinstall

### Clean Build
```bash
# Clean build folder
xcodebuild clean -workspace AITamagotchi.xcworkspace -scheme AITamagotchi

# Delete derived data
rm -rf ~/Library/Developer/Xcode/DerivedData

# Reset simulator
xcrun simctl erase all
```

## Development Workflow

### 1. Feature Branch
```bash
git checkout -b feature/your-feature
```

### 2. Make Changes
- Write code
- Add tests
- Update documentation

### 3. Test
```bash
swift test
```

### 4. Commit
```bash
git add .
git commit -m "feat: add new feature"
```

### 5. Push & PR
```bash
git push origin feature/your-feature
# Create pull request on GitHub
```

## Resources

### Documentation
- [Swift Documentation](https://www.swift.org/documentation/)
- [SwiftUI Tutorials](https://developer.apple.com/tutorials/swiftui)
- [Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/)

### WWDC Sessions
- SwiftData introduction
- Core ML on device training
- HealthKit best practices
- CloudKit tips and tricks

### Community
- [Swift Forums](https://forums.swift.org)
- [iOS Dev Weekly](https://iosdevweekly.com)
- [r/iOSProgramming](https://reddit.com/r/iOSProgramming)

## Next Steps

1. ✅ Complete environment setup
2. ✅ Build and run the project
3. 📖 Read architecture documentation
4. 🚀 Start developing features
5. 🧪 Write tests
6. 📱 Test on real devices
7. 🎯 Submit to TestFlight