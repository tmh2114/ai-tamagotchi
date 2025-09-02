import Foundation
import CoreML
import Compression

/// Manages bundled models for offline AI capabilities
class OfflineModelBundle {
    static let shared = OfflineModelBundle()
    
    private let bundledModels: [ModelInfo] = [
        ModelInfo(
            name: "TamagotchiPersonality",
            version: "1.0.0",
            size: 15_000_000, // 15MB
            priority: .essential,
            description: "Core personality and behavior model"
        ),
        ModelInfo(
            name: "EmotionRecognition",
            version: "1.0.0",
            size: 8_000_000, // 8MB
            priority: .essential,
            description: "Recognizes and responds to user emotions"
        ),
        ModelInfo(
            name: "BehaviorPrediction",
            version: "1.0.0",
            size: 12_000_000, // 12MB
            priority: .high,
            description: "Predicts pet behavior patterns"
        ),
        ModelInfo(
            name: "NaturalLanguage",
            version: "1.0.0",
            size: 25_000_000, // 25MB
            priority: .medium,
            description: "Understands user text input"
        ),
        ModelInfo(
            name: "ActivityRecognition",
            version: "1.0.0",
            size: 10_000_000, // 10MB
            priority: .low,
            description: "Recognizes user activity patterns"
        )
    ]
    
    private let modelStorage = ModelStorage()
    private var loadedModels: [String: MLModel] = [:]
    
    private init() {}
    
    // MARK: - Model Loading
    
    /// Load essential models for offline operation
    func loadEssentialModels() async throws {
        let essentialModels = bundledModels.filter { $0.priority == .essential }
        
        for modelInfo in essentialModels {
            try await loadModel(modelInfo)
        }
    }
    
    /// Load all bundled models based on available storage
    func loadAllModels() async throws {
        let availableSpace = modelStorage.availableSpace()
        var usedSpace: Int64 = 0
        
        // Sort by priority
        let sortedModels = bundledModels.sorted { $0.priority.rawValue > $1.priority.rawValue }
        
        for modelInfo in sortedModels {
            if usedSpace + modelInfo.size <= availableSpace {
                try await loadModel(modelInfo)
                usedSpace += modelInfo.size
            }
        }
    }
    
    private func loadModel(_ modelInfo: ModelInfo) async throws {
        // Check if already loaded
        if loadedModels[modelInfo.name] != nil {
            return
        }
        
        // Try to load from bundle
        if let bundleURL = Bundle.main.url(
            forResource: modelInfo.name,
            withExtension: "mlmodelc"
        ) {
            let model = try MLModel(contentsOf: bundleURL)
            loadedModels[modelInfo.name] = model
            
            // Extract and store for offline access
            try await modelStorage.storeModel(
                model,
                info: modelInfo
            )
        } else {
            // Try to load from storage
            if let storedModel = try await modelStorage.loadModel(modelInfo.name) {
                loadedModels[modelInfo.name] = storedModel
            } else {
                throw ModelBundleError.modelNotFound(modelInfo.name)
            }
        }
    }
    
    // MARK: - Model Access
    
    func getModel(named name: String) -> MLModel? {
        return loadedModels[name]
    }
    
    func isModelAvailable(_ name: String) -> Bool {
        return loadedModels[name] != nil ||
               modelStorage.isModelStored(name)
    }
    
    // MARK: - Model Updates
    
    /// Download and update models when online
    func updateModelsIfNeeded() async throws {
        guard NetworkMonitor.shared.isConnected else { return }
        
        for modelInfo in bundledModels {
            if await shouldUpdateModel(modelInfo) {
                try await downloadAndUpdateModel(modelInfo)
            }
        }
    }
    
    private func shouldUpdateModel(_ modelInfo: ModelInfo) async -> Bool {
        // Check if newer version is available
        // In production, would check against server
        return false
    }
    
    private func downloadAndUpdateModel(_ modelInfo: ModelInfo) async throws {
        // Download model update
        let updateURL = URL(string: "https://example.com/models/\(modelInfo.name)")!
        
        let (data, _) = try await URLSession.shared.data(from: updateURL)
        
        // Decompress if needed
        let decompressedData = try decompressModel(data)
        
        // Validate and store
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(modelInfo.name).mlmodelc")
        try decompressedData.write(to: tempURL)
        
        let updatedModel = try MLModel(contentsOf: tempURL)
        
        // Replace existing model
        loadedModels[modelInfo.name] = updatedModel
        try await modelStorage.storeModel(updatedModel, info: modelInfo)
        
        // Clean up
        try? FileManager.default.removeItem(at: tempURL)
    }
    
    // MARK: - Compression
    
    private func decompressModel(_ compressedData: Data) throws -> Data {
        let decompressed = try (compressedData as NSData).decompressed(using: .zlib)
        return decompressed as Data
    }
    
    // MARK: - Storage Management
    
    func clearUnusedModels() async {
        let unusedThreshold = Date().addingTimeInterval(-30 * 24 * 60 * 60) // 30 days
        
        for (name, _) in loadedModels {
            if let lastUsed = await modelStorage.getLastUsedDate(for: name),
               lastUsed < unusedThreshold {
                loadedModels.removeValue(forKey: name)
                await modelStorage.removeModel(name)
            }
        }
    }
    
    func preloadForOffline() async throws {
        // Ensure all essential models are cached for offline use
        try await loadEssentialModels()
        
        // Cache additional models based on usage patterns
        let frequentlyUsedModels = await modelStorage.getFrequentlyUsedModels()
        for modelName in frequentlyUsedModels {
            if let modelInfo = bundledModels.first(where: { $0.name == modelName }) {
                try await loadModel(modelInfo)
            }
        }
    }
}

// MARK: - Model Storage

actor ModelStorage {
    private let storageDirectory: URL
    private let fileManager = FileManager.default
    private var modelUsageStats: [String: ModelUsageStats] = [:]
    
    init() {
        let documentsPath = fileManager.urls(for: .documentDirectory,
                                            in: .userDomainMask).first!
        self.storageDirectory = documentsPath.appendingPathComponent("OfflineModels")
        
        Task {
            await setupStorageDirectory()
        }
    }
    
    private func setupStorageDirectory() {
        if !fileManager.fileExists(atPath: storageDirectory.path) {
            try? fileManager.createDirectory(at: storageDirectory,
                                            withIntermediateDirectories: true)
        }
    }
    
    func storeModel(_ model: MLModel, info: ModelInfo) throws {
        let modelPath = storageDirectory.appendingPathComponent("\(info.name).mlmodelc")
        
        // Update usage stats
        modelUsageStats[info.name] = ModelUsageStats(
            lastUsed: Date(),
            usageCount: (modelUsageStats[info.name]?.usageCount ?? 0) + 1
        )
        
        // Note: Actual model serialization would be more complex
        // This is a simplified representation
    }
    
    func loadModel(_ name: String) throws -> MLModel? {
        let modelPath = storageDirectory.appendingPathComponent("\(name).mlmodelc")
        
        guard fileManager.fileExists(atPath: modelPath.path) else {
            return nil
        }
        
        // Update usage stats
        modelUsageStats[name] = ModelUsageStats(
            lastUsed: Date(),
            usageCount: (modelUsageStats[name]?.usageCount ?? 0) + 1
        )
        
        return try MLModel(contentsOf: modelPath)
    }
    
    func isModelStored(_ name: String) -> Bool {
        let modelPath = storageDirectory.appendingPathComponent("\(name).mlmodelc")
        return fileManager.fileExists(atPath: modelPath.path)
    }
    
    func removeModel(_ name: String) {
        let modelPath = storageDirectory.appendingPathComponent("\(name).mlmodelc")
        try? fileManager.removeItem(at: modelPath)
        modelUsageStats.removeValue(forKey: name)
    }
    
    func availableSpace() -> Int64 {
        guard let attributes = try? fileManager.attributesOfFileSystem(
            forPath: storageDirectory.path
        ) else { return 0 }
        
        return (attributes[.systemFreeSize] as? NSNumber)?.int64Value ?? 0
    }
    
    func getLastUsedDate(for modelName: String) -> Date? {
        return modelUsageStats[modelName]?.lastUsed
    }
    
    func getFrequentlyUsedModels(limit: Int = 5) -> [String] {
        return modelUsageStats
            .sorted { $0.value.usageCount > $1.value.usageCount }
            .prefix(limit)
            .map { $0.key }
    }
}

// MARK: - Supporting Types

struct ModelInfo {
    enum Priority: Int {
        case essential = 3
        case high = 2
        case medium = 1
        case low = 0
    }
    
    let name: String
    let version: String
    let size: Int64
    let priority: Priority
    let description: String
}

struct ModelUsageStats {
    let lastUsed: Date
    let usageCount: Int
}

enum ModelBundleError: LocalizedError {
    case modelNotFound(String)
    case insufficientStorage
    case downloadFailed
    case invalidModel
    
    var errorDescription: String? {
        switch self {
        case .modelNotFound(let name):
            return "Model '\(name)' not found in bundle or storage"
        case .insufficientStorage:
            return "Insufficient storage space for model"
        case .downloadFailed:
            return "Failed to download model update"
        case .invalidModel:
            return "Downloaded model is invalid or corrupted"
        }
    }
}

// MARK: - Network Monitor

class NetworkMonitor {
    static let shared = NetworkMonitor()
    
    var isConnected: Bool {
        // Simplified - would use NWPathMonitor in production
        return true
    }
    
    private init() {}
}