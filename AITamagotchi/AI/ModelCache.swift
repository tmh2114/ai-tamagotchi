import CoreML
import Foundation

/// Cache manager for CoreML models with offline support
actor ModelCache {
    private let cacheDirectory: URL
    private var cachedModels: [String: MLModel] = [:]
    private let maxCacheSize: Int64 = 500_000_000 // 500MB
    private let fileManager = FileManager.default
    
    init() {
        // Setup cache directory in app's documents
        let documentsPath = fileManager.urls(for: .documentDirectory, 
                                            in: .userDomainMask).first!
        self.cacheDirectory = documentsPath.appendingPathComponent("ModelCache")
        
        Task {
            await setupCacheDirectory()
        }
    }
    
    private func setupCacheDirectory() {
        if !fileManager.fileExists(atPath: cacheDirectory.path) {
            try? fileManager.createDirectory(at: cacheDirectory,
                                            withIntermediateDirectories: true)
        }
    }
    
    // MARK: - Cache Operations
    
    func getCachedModel(named name: String) -> MLModel? {
        // Check in-memory cache first
        if let model = cachedModels[name] {
            return model
        }
        
        // Check disk cache
        let modelPath = cacheDirectory.appendingPathComponent("\(name).mlmodelc")
        if fileManager.fileExists(atPath: modelPath.path) {
            do {
                let model = try MLModel(contentsOf: modelPath)
                cachedModels[name] = model
                return model
            } catch {
                print("Failed to load cached model: \(error)")
                return nil
            }
        }
        
        return nil
    }
    
    func cacheModel(_ model: MLModel, name: String) {
        // Store in memory
        cachedModels[name] = model
        
        // Store on disk for offline access
        let modelPath = cacheDirectory.appendingPathComponent("\(name).mlmodelc")
        
        // Note: In production, you'd need to properly serialize the model
        // This is a simplified version
        Task {
            await cleanupIfNeeded()
        }
    }
    
    func updateCachedModel(_ model: MLModel, name: String? = nil) {
        let modelName = name ?? "default"
        cachedModels[modelName] = model
    }
    
    func clearAll() {
        cachedModels.removeAll()
        
        // Clear disk cache
        try? fileManager.removeItem(at: cacheDirectory)
        setupCacheDirectory()
    }
    
    // MARK: - Cache Management
    
    private func cleanupIfNeeded() {
        let cacheSize = calculateCacheSize()
        
        if cacheSize > maxCacheSize {
            // Remove oldest models
            removeOldestModels(toFreeSpace: cacheSize - maxCacheSize)
        }
    }
    
    private func calculateCacheSize() -> Int64 {
        guard let files = try? fileManager.contentsOfDirectory(
            at: cacheDirectory,
            includingPropertiesForKeys: [.fileSizeKey]
        ) else { return 0 }
        
        return files.reduce(0) { total, file in
            let size = (try? file.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
            return total + Int64(size)
        }
    }
    
    private func removeOldestModels(toFreeSpace space: Int64) {
        guard let files = try? fileManager.contentsOfDirectory(
            at: cacheDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey]
        ) else { return }
        
        // Sort by modification date
        let sortedFiles = files.sorted { file1, file2 in
            let date1 = (try? file1.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? Date.distantPast
            let date2 = (try? file2.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? Date.distantPast
            return date1 < date2
        }
        
        var freedSpace: Int64 = 0
        for file in sortedFiles {
            if freedSpace >= space { break }
            
            let size = (try? file.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
            try? fileManager.removeItem(at: file)
            freedSpace += Int64(size)
            
            // Remove from memory cache
            let modelName = file.deletingPathExtension().lastPathComponent
            cachedModels.removeValue(forKey: modelName)
        }
    }
    
    // MARK: - Preloading
    
    func preloadEssentialModels() async {
        let essentialModels = ["TamagotchiPersonality", "EmotionRecognition", "BehaviorPrediction"]
        
        for modelName in essentialModels {
            if getCachedModel(named: modelName) == nil {
                // Attempt to load from bundle
                if let bundleURL = Bundle.main.url(forResource: modelName, withExtension: "mlmodelc") {
                    do {
                        let model = try MLModel(contentsOf: bundleURL)
                        cacheModel(model, name: modelName)
                    } catch {
                        print("Failed to preload model \(modelName): \(error)")
                    }
                }
            }
        }
    }
}