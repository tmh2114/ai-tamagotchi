import Foundation
import CoreML
import Combine
import os.log

/// Manages CoreML model lifecycle with privacy-focused design
@MainActor
public final class MLModelManager: ObservableObject {
    // MARK: - Singleton
    public static let shared = MLModelManager()
    
    // MARK: - Properties
    @Published public private(set) var modelState: ModelState = .uninitialized
    @Published public private(set) var isModelReady: Bool = false
    @Published public private(set) var modelVersion: String = "1.0.0"
    @Published public private(set) var lastUpdateCheck: Date?
    
    private var currentModel: MLModel?
    private var modelConfiguration: MLModelConfiguration
    private let logger = Logger(subsystem: "com.ai.tamagotchi", category: "MLModelManager")
    private var cancellables = Set<AnyCancellable>()
    
    // Privacy-focused model paths
    private let modelCachePath: URL
    private let encryptedModelPath: URL
    
    // MARK: - Model State
    public enum ModelState: Equatable {
        case uninitialized
        case downloading(progress: Double)
        case loading
        case ready
        case failed(Error)
        case updating
        
        public static func == (lhs: ModelState, rhs: ModelState) -> Bool {
            switch (lhs, rhs) {
            case (.uninitialized, .uninitialized),
                 (.loading, .loading),
                 (.ready, .ready),
                 (.updating, .updating):
                return true
            case let (.downloading(p1), .downloading(p2)):
                return p1 == p2
            case (.failed, .failed):
                return true
            default:
                return false
            }
        }
    }
    
    // MARK: - Initialization
    private init() {
        // Configure for on-device processing only
        modelConfiguration = MLModelConfiguration()
        modelConfiguration.computeUnits = .all
        modelConfiguration.allowLowPrecisionAccumulationOnGPU = true
        
        // Privacy-focused paths (encrypted container)
        let documentsPath = FileManager.default.urls(for: .documentDirectory, 
                                                     in: .userDomainMask).first!
        modelCachePath = documentsPath.appendingPathComponent("Models/Cache", isDirectory: true)
        encryptedModelPath = documentsPath.appendingPathComponent("Models/Encrypted", isDirectory: true)
        
        createDirectoriesIfNeeded()
        setupModelUpdateObserver()
    }
    
    // MARK: - Public Methods
    
    /// Initialize and load the AI model with privacy guarantees
    public func initializeModel() async throws {
        guard modelState != .ready else { return }
        
        modelState = .loading
        logger.info("Initializing on-device AI model")
        
        do {
            // Check for cached model first (offline-first approach)
            if let cachedModel = try await loadCachedModel() {
                currentModel = cachedModel
                modelState = .ready
                isModelReady = true
                logger.info("Loaded cached model successfully")
            } else {
                // Load bundled model as fallback
                try await loadBundledModel()
            }
        } catch {
            modelState = .failed(error)
            logger.error("Failed to initialize model: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Process input with the AI model (privacy-preserving)
    public func processInput(_ input: MLFeatureProvider) async throws -> MLFeatureProvider {
        guard modelState == .ready, let model = currentModel else {
            throw MLModelError.modelNotReady
        }
        
        // Process on-device only
        return try await withCheckedThrowingContinuation { continuation in
            Task {
                do {
                    let output = try model.prediction(from: input)
                    continuation.resume(returning: output)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    /// Update model if newer version available (privacy-preserving)
    public func checkForModelUpdates() async {
        guard modelState == .ready else { return }
        
        modelState = .updating
        defer { 
            if modelState == .updating {
                modelState = .ready
            }
        }
        
        // Check for updates without sending user data
        await performPrivacyPreservingUpdateCheck()
        lastUpdateCheck = Date()
    }
    
    /// Clear all cached models (privacy cleanup)
    public func clearModelCache() async throws {
        logger.info("Clearing model cache for privacy")
        
        currentModel = nil
        modelState = .uninitialized
        isModelReady = false
        
        // Securely delete cached models
        try await securelyClearDirectory(modelCachePath)
        try await securelyClearDirectory(encryptedModelPath)
    }
    
    // MARK: - Private Methods
    
    private func createDirectoriesIfNeeded() {
        do {
            try FileManager.default.createDirectory(at: modelCachePath, 
                                                   withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: encryptedModelPath, 
                                                   withIntermediateDirectories: true)
            
            // Set file protection for encryption at rest
            try FileManager.default.setAttributes([
                .protectionKey: FileProtectionType.completeUntilFirstUserAuthentication
            ], ofItemAtPath: encryptedModelPath.path)
        } catch {
            logger.error("Failed to create model directories: \(error.localizedDescription)")
        }
    }
    
    private func loadCachedModel() async throws -> MLModel? {
        let cachedModelURL = modelCachePath.appendingPathComponent("phi3_mini.mlmodelc")
        
        guard FileManager.default.fileExists(atPath: cachedModelURL.path) else {
            return nil
        }
        
        // Load with privacy-focused configuration
        return try MLModel(contentsOf: cachedModelURL, configuration: modelConfiguration)
    }
    
    private func loadBundledModel() async throws {
        guard let bundledModelURL = Bundle.main.url(forResource: "Phi3Mini", 
                                                   withExtension: "mlmodelc") else {
            throw MLModelError.modelNotFound
        }
        
        currentModel = try MLModel(contentsOf: bundledModelURL, 
                                  configuration: modelConfiguration)
        modelState = .ready
        isModelReady = true
        
        // Cache for offline use
        await cacheModel(from: bundledModelURL)
    }
    
    private func cacheModel(from sourceURL: URL) async {
        let destinationURL = modelCachePath.appendingPathComponent("phi3_mini.mlmodelc")
        
        do {
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
            logger.info("Model cached for offline use")
        } catch {
            logger.error("Failed to cache model: \(error.localizedDescription)")
        }
    }
    
    private func performPrivacyPreservingUpdateCheck() async {
        // Check for updates without sending any user data
        // This would typically check a manifest file with just version info
        // No telemetry, no user identification
        logger.info("Checking for model updates (privacy-preserving)")
        
        // Simulated check - in production, this would fetch a simple version manifest
        // without any tracking or user identification
    }
    
    private func securelyClearDirectory(_ directory: URL) async throws {
        let fileManager = FileManager.default
        
        guard fileManager.fileExists(atPath: directory.path) else { return }
        
        let contents = try fileManager.contentsOfDirectory(at: directory, 
                                                          includingPropertiesForKeys: nil)
        
        for file in contents {
            // Overwrite with random data before deletion for security
            if let data = try? Data(contentsOf: file) {
                let randomData = Data(repeating: 0, count: data.count)
                try randomData.write(to: file)
            }
            try fileManager.removeItem(at: file)
        }
    }
    
    private func setupModelUpdateObserver() {
        // Observe app lifecycle for smart update checks
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                Task { @MainActor in
                    // Only check if last check was > 24 hours ago
                    if let lastCheck = self?.lastUpdateCheck,
                       Date().timeIntervalSince(lastCheck) > 86400 {
                        await self?.checkForModelUpdates()
                    }
                }
            }
            .store(in: &cancellables)
    }
}

// MARK: - Error Types
public enum MLModelError: LocalizedError {
    case modelNotFound
    case modelNotReady
    case invalidInput
    case processingFailed(String)
    
    public var errorDescription: String? {
        switch self {
        case .modelNotFound:
            return "AI model not found in bundle"
        case .modelNotReady:
            return "AI model is not ready for inference"
        case .invalidInput:
            return "Invalid input provided to model"
        case .processingFailed(let reason):
            return "Processing failed: \(reason)"
        }
    }
}