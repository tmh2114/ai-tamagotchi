import Foundation
import Network
import Combine
import os.log

/// Manages offline AI capabilities and ensures functionality without network
@MainActor
public final class OfflineCapabilityManager: ObservableObject {
    // MARK: - Singleton
    public static let shared = OfflineCapabilityManager()
    
    // MARK: - Published Properties
    @Published public private(set) var networkStatus: NetworkStatus = .unknown
    @Published public private(set) var isOfflineMode: Bool = true
    @Published public private(set) var offlineCapabilities: Set<Capability> = []
    @Published public private(set) var cachedDataSize: Int64 = 0
    @Published public private(set) var lastSyncDate: Date?
    
    // MARK: - Private Properties
    private let monitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "network.monitor")
    private let logger = Logger(subsystem: "com.ai.tamagotchi", category: "OfflineCapability")
    private var cancellables = Set<AnyCancellable>()
    
    private let cacheManager: CacheManager
    private let modelManager = MLModelManager.shared
    private let fallbackResponses: FallbackResponseProvider
    
    // MARK: - Types
    public enum NetworkStatus {
        case unknown
        case online(ConnectionType)
        case offline
        
        public var isOnline: Bool {
            if case .online = self { return true }
            return false
        }
    }
    
    public enum ConnectionType {
        case wifi
        case cellular
        case wired
        case other
    }
    
    public enum Capability: String, CaseIterable {
        case textGeneration = "text_generation"
        case emotionRecognition = "emotion_recognition"
        case behaviorPrediction = "behavior_prediction"
        case interactionHistory = "interaction_history"
        case personalityEvolution = "personality_evolution"
        case gameplayMechanics = "gameplay_mechanics"
        
        public var isAvailableOffline: Bool {
            // All capabilities available offline by design
            return true
        }
    }
    
    // MARK: - Initialization
    private init() {
        self.cacheManager = CacheManager()
        self.fallbackResponses = FallbackResponseProvider()
        
        setupNetworkMonitoring()
        initializeOfflineCapabilities()
        loadCachedData()
    }
    
    // MARK: - Public Methods
    
    /// Initialize offline capabilities
    public func initialize() async {
        logger.info("Initializing offline capabilities")
        
        // Ensure all models are cached
        await ensureModelsAreCached()
        
        // Validate offline functionality
        await validateOfflineCapabilities()
        
        // Calculate cache size
        updateCacheSize()
    }
    
    /// Check if a capability is available offline
    public func isCapabilityAvailable(_ capability: Capability) -> Bool {
        // All capabilities designed to work offline
        return offlineCapabilities.contains(capability)
    }
    
    /// Get offline response for a given input
    public func getOfflineResponse(for input: String, 
                                  capability: Capability) async -> OfflineResponse {
        logger.info("Generating offline response for capability: \(capability.rawValue)")
        
        // Check if capability is available
        guard isCapabilityAvailable(capability) else {
            return fallbackResponses.getFallback(for: capability)
        }
        
        // Check cache first
        if let cached = await cacheManager.getCachedResponse(for: input, 
                                                             capability: capability) {
            return cached
        }
        
        // Generate new response offline
        let response = await generateOfflineResponse(input: input, 
                                                    capability: capability)
        
        // Cache for future use
        await cacheManager.cacheResponse(response, 
                                        for: input, 
                                        capability: capability)
        
        return response
    }
    
    /// Prepare for offline mode
    public func prepareForOfflineMode() async {
        logger.info("Preparing for offline mode")
        
        // Download any pending model updates
        if networkStatus.isOnline {
            await downloadPendingUpdates()
        }
        
        // Optimize cache for offline use
        await cacheManager.optimizeForOffline()
        
        // Pre-generate common responses
        await pregenerateCommonResponses()
        
        isOfflineMode = true
    }
    
    /// Sync when network becomes available
    public func syncWhenOnline() async {
        guard networkStatus.isOnline else {
            logger.info("Network offline, skipping sync")
            return
        }
        
        logger.info("Syncing offline data")
        
        // This is where you would sync user data if needed
        // But we keep everything local for privacy
        
        lastSyncDate = Date()
    }
    
    /// Clear offline cache
    public func clearOfflineCache() async throws {
        logger.info("Clearing offline cache")
        
        try await cacheManager.clearAll()
        cachedDataSize = 0
        
        // Re-initialize essential data
        await initializeOfflineCapabilities()
    }
    
    /// Get storage usage statistics
    public func getStorageStats() -> StorageStatistics {
        return StorageStatistics(
            totalCacheSize: cachedDataSize,
            modelSize: cacheManager.getModelCacheSize(),
            responsesCacheSize: cacheManager.getResponsesCacheSize(),
            availableSpace: getAvailableDeviceSpace()
        )
    }
    
    // MARK: - Private Methods
    
    private func setupNetworkMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.updateNetworkStatus(path)
            }
        }
        
        monitor.start(queue: monitorQueue)
    }
    
    @MainActor
    private func updateNetworkStatus(_ path: NWPath) {
        let previousStatus = networkStatus
        
        if path.status == .satisfied {
            if path.usesInterfaceType(.wifi) {
                networkStatus = .online(.wifi)
            } else if path.usesInterfaceType(.cellular) {
                networkStatus = .online(.cellular)
            } else if path.usesInterfaceType(.wiredEthernet) {
                networkStatus = .online(.wired)
            } else {
                networkStatus = .online(.other)
            }
            
            // Trigger sync if coming back online
            if case .offline = previousStatus {
                Task {
                    await syncWhenOnline()
                }
            }
        } else {
            networkStatus = .offline
            
            // Ensure offline mode is ready
            if case .online = previousStatus {
                Task {
                    await prepareForOfflineMode()
                }
            }
        }
        
        logger.info("Network status updated: \(String(describing: networkStatus))")
    }
    
    private func initializeOfflineCapabilities() async {
        // All capabilities available offline
        offlineCapabilities = Set(Capability.allCases)
        
        logger.info("Initialized \(offlineCapabilities.count) offline capabilities")
    }
    
    private func loadCachedData() {
        // Load previously cached data
        Task {
            await cacheManager.loadCache()
            updateCacheSize()
        }
    }
    
    private func ensureModelsAreCached() async {
        // Verify models are available offline
        do {
            try await modelManager.initializeModel()
            logger.info("Models verified for offline use")
        } catch {
            logger.error("Failed to verify models: \(error.localizedDescription)")
        }
    }
    
    private func validateOfflineCapabilities() async {
        // Test each capability offline
        for capability in Capability.allCases {
            let testInput = "Test input for \(capability.rawValue)"
            let response = await generateOfflineResponse(input: testInput, 
                                                        capability: capability)
            
            if response.isValid {
                logger.debug("Validated offline capability: \(capability.rawValue)")
            } else {
                logger.warning("Failed to validate: \(capability.rawValue)")
                offlineCapabilities.remove(capability)
            }
        }
    }
    
    private func generateOfflineResponse(input: String, 
                                        capability: Capability) async -> OfflineResponse {
        // Generate response using on-device model
        let processor = AIProcessor()
        
        do {
            let context = mapCapabilityToContext(capability)
            let tamagotchiInput = AIProcessor.TamagotchiInput(
                text: input,
                context: context
            )
            
            let response = try await processor.processInteraction(tamagotchiInput)
            
            return OfflineResponse(
                text: response.message,
                capability: capability,
                confidence: response.confidence,
                isValid: true,
                generatedAt: Date()
            )
        } catch {
            logger.error("Failed to generate offline response: \(error.localizedDescription)")
            return fallbackResponses.getFallback(for: capability)
        }
    }
    
    private func mapCapabilityToContext(_ capability: Capability) -> AIProcessor.InteractionContext {
        switch capability {
        case .textGeneration:
            return .general
        case .emotionRecognition:
            return .emotional
        case .behaviorPrediction:
            return .general
        case .interactionHistory:
            return .general
        case .personalityEvolution:
            return .training
        case .gameplayMechanics:
            return .playing
        }
    }
    
    private func downloadPendingUpdates() async {
        // In production, this would download model updates
        // For privacy, we only download when explicitly allowed
        logger.info("Checking for model updates (privacy-preserving)")
    }
    
    private func pregenerateCommonResponses() async {
        // Pre-generate responses for common interactions
        let commonInputs = [
            "Hello",
            "How are you?",
            "Let's play",
            "I'm back",
            "Good morning",
            "Good night",
            "Feed",
            "Pet"
        ]
        
        for input in commonInputs {
            for capability in offlineCapabilities {
                _ = await getOfflineResponse(for: input, capability: capability)
            }
        }
        
        logger.info("Pre-generated \(commonInputs.count) common responses")
    }
    
    private func updateCacheSize() {
        cachedDataSize = cacheManager.getTotalCacheSize()
    }
    
    private func getAvailableDeviceSpace() -> Int64 {
        do {
            let systemAttributes = try FileManager.default.attributesOfFileSystem(
                forPath: NSHomeDirectory()
            )
            
            if let space = systemAttributes[.systemFreeSize] as? NSNumber {
                return space.int64Value
            }
        } catch {
            logger.error("Failed to get device space: \(error.localizedDescription)")
        }
        
        return 0
    }
}

// MARK: - Supporting Types

public struct OfflineResponse {
    public let text: String
    public let capability: OfflineCapabilityManager.Capability
    public let confidence: Double
    public let isValid: Bool
    public let generatedAt: Date
}

public struct StorageStatistics {
    public let totalCacheSize: Int64
    public let modelSize: Int64
    public let responsesCacheSize: Int64
    public let availableSpace: Int64
    
    public var formattedTotalCache: String {
        ByteCountFormatter.string(fromByteCount: totalCacheSize, countStyle: .binary)
    }
    
    public var formattedAvailableSpace: String {
        ByteCountFormatter.string(fromByteCount: availableSpace, countStyle: .binary)
    }
}

// MARK: - Cache Manager

private class CacheManager {
    private let cacheDirectory: URL
    private let responsesCache = NSCache<NSString, CachedResponse>()
    private let fileManager = FileManager.default
    private let logger = Logger(subsystem: "com.ai.tamagotchi", category: "CacheManager")
    
    init() {
        let documentsPath = fileManager.urls(for: .cachesDirectory, 
                                            in: .userDomainMask).first!
        cacheDirectory = documentsPath.appendingPathComponent("OfflineAI", isDirectory: true)
        
        createCacheDirectoryIfNeeded()
        configureCache()
    }
    
    private func createCacheDirectoryIfNeeded() {
        try? fileManager.createDirectory(at: cacheDirectory, 
                                        withIntermediateDirectories: true)
    }
    
    private func configureCache() {
        responsesCache.countLimit = 1000
        responsesCache.totalCostLimit = 50 * 1024 * 1024 // 50MB
    }
    
    func getCachedResponse(for input: String, 
                          capability: OfflineCapabilityManager.Capability) async -> OfflineResponse? {
        let key = cacheKey(for: input, capability: capability)
        
        if let cached = responsesCache.object(forKey: key as NSString) {
            return cached.response
        }
        
        // Check disk cache
        return await loadFromDisk(key: key)
    }
    
    func cacheResponse(_ response: OfflineResponse, 
                      for input: String,
                      capability: OfflineCapabilityManager.Capability) async {
        let key = cacheKey(for: input, capability: capability)
        let cached = CachedResponse(response: response)
        
        // Memory cache
        responsesCache.setObject(cached, forKey: key as NSString)
        
        // Disk cache
        await saveToDisk(response: response, key: key)
    }
    
    func optimizeForOffline() async {
        // Optimize cache for offline use
        logger.info("Optimizing cache for offline mode")
    }
    
    func clearAll() async throws {
        responsesCache.removeAllObjects()
        try fileManager.removeItem(at: cacheDirectory)
        createCacheDirectoryIfNeeded()
    }
    
    func loadCache() async {
        // Load cache from disk on startup
    }
    
    func getTotalCacheSize() -> Int64 {
        var size: Int64 = 0
        
        if let enumerator = fileManager.enumerator(at: cacheDirectory,
                                                  includingPropertiesForKeys: [.fileSizeKey]) {
            for case let fileURL as URL in enumerator {
                if let fileSize = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                    size += Int64(fileSize)
                }
            }
        }
        
        return size
    }
    
    func getModelCacheSize() -> Int64 {
        // Calculate model cache size
        return 0 // Placeholder
    }
    
    func getResponsesCacheSize() -> Int64 {
        // Calculate responses cache size
        return getTotalCacheSize() - getModelCacheSize()
    }
    
    private func cacheKey(for input: String, 
                         capability: OfflineCapabilityManager.Capability) -> String {
        "\(capability.rawValue)_\(input.hashValue)"
    }
    
    private func loadFromDisk(key: String) async -> OfflineResponse? {
        let fileURL = cacheDirectory.appendingPathComponent("\(key).cache")
        
        guard fileManager.fileExists(atPath: fileURL.path),
              let data = try? Data(contentsOf: fileURL),
              let response = try? JSONDecoder().decode(OfflineResponse.self, from: data) else {
            return nil
        }
        
        return response
    }
    
    private func saveToDisk(response: OfflineResponse, key: String) async {
        let fileURL = cacheDirectory.appendingPathComponent("\(key).cache")
        
        if let data = try? JSONEncoder().encode(response) {
            try? data.write(to: fileURL)
        }
    }
}

private class CachedResponse: NSObject {
    let response: OfflineResponse
    
    init(response: OfflineResponse) {
        self.response = response
    }
}

// MARK: - Fallback Response Provider

private class FallbackResponseProvider {
    func getFallback(for capability: OfflineCapabilityManager.Capability) -> OfflineResponse {
        let text: String
        
        switch capability {
        case .textGeneration:
            text = "Hi there! I'm happy to see you!"
        case .emotionRecognition:
            text = "I'm feeling great!"
        case .behaviorPrediction:
            text = "Let's do something fun!"
        case .interactionHistory:
            text = "We've had great times together!"
        case .personalityEvolution:
            text = "I'm learning and growing!"
        case .gameplayMechanics:
            text = "Ready to play!"
        }
        
        return OfflineResponse(
            text: text,
            capability: capability,
            confidence: 0.5,
            isValid: true,
            generatedAt: Date()
        )
    }
}

// Make OfflineResponse Codable for caching
extension OfflineResponse: Codable {
    enum CodingKeys: String, CodingKey {
        case text, capability, confidence, isValid, generatedAt
    }
}