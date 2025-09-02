import Foundation
import CryptoKit
import LocalAuthentication
import Combine
import os.log

/// Manages privacy and data protection for AI operations
@MainActor
public final class PrivacyManager: ObservableObject {
    // MARK: - Singleton
    public static let shared = PrivacyManager()
    
    // MARK: - Published Properties
    @Published public private(set) var privacyLevel: PrivacyLevel = .maximum
    @Published public private(set) var isDataEncrypted: Bool = true
    @Published public private(set) var consentStatus: ConsentStatus = .notDetermined
    @Published public private(set) var lastPrivacyAudit: Date?
    
    // MARK: - Private Properties
    private let logger = Logger(subsystem: "com.ai.tamagotchi", category: "Privacy")
    private let keychain = KeychainManager()
    private var encryptionKey: SymmetricKey?
    private let auditLog = PrivacyAuditLog()
    
    // MARK: - Types
    public enum PrivacyLevel: Int, CaseIterable {
        case minimum = 0    // Basic privacy (not recommended)
        case standard = 1   // Standard privacy protections
        case enhanced = 2   // Enhanced privacy with additional safeguards
        case maximum = 3    // Maximum privacy (default)
        
        public var description: String {
            switch self {
            case .minimum: return "Basic"
            case .standard: return "Standard"
            case .enhanced: return "Enhanced"
            case .maximum: return "Maximum"
            }
        }
    }
    
    public enum ConsentStatus {
        case notDetermined
        case granted
        case denied
        case limited
    }
    
    public struct PrivacyPolicy {
        public let dataCollection: DataCollectionPolicy
        public let dataRetention: DataRetentionPolicy
        public let dataSharing: DataSharingPolicy
        
        public static let `default` = PrivacyPolicy(
            dataCollection: .onDeviceOnly,
            dataRetention: .minimal,
            dataSharing: .never
        )
    }
    
    public enum DataCollectionPolicy {
        case onDeviceOnly       // All data stays on device
        case anonymized         // Only anonymized data if needed
        case withConsent        // With explicit user consent
    }
    
    public enum DataRetentionPolicy {
        case minimal            // Delete as soon as possible
        case shortTerm          // 7 days
        case standard           // 30 days
        case longTerm           // 90 days
    }
    
    public enum DataSharingPolicy {
        case never              // Never share data
        case anonymizedOnly     // Only share anonymized data
        case withExplicitConsent // Only with explicit consent
    }
    
    // MARK: - Initialization
    private init() {
        setupEncryption()
        configurePrivacySettings()
        startPrivacyAudit()
    }
    
    // MARK: - Public Methods
    
    /// Encrypt sensitive data before storage
    public func encryptData(_ data: Data) throws -> Data {
        guard let key = encryptionKey else {
            throw PrivacyError.encryptionKeyUnavailable
        }
        
        let sealedBox = try AES.GCM.seal(data, using: key)
        guard let encrypted = sealedBox.combined else {
            throw PrivacyError.encryptionFailed
        }
        
        auditLog.logDataOperation(.encryption, size: data.count)
        return encrypted
    }
    
    /// Decrypt data for on-device processing
    public func decryptData(_ encryptedData: Data) throws -> Data {
        guard let key = encryptionKey else {
            throw PrivacyError.encryptionKeyUnavailable
        }
        
        let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
        let decrypted = try AES.GCM.open(sealedBox, using: key)
        
        auditLog.logDataOperation(.decryption, size: decrypted.count)
        return decrypted
    }
    
    /// Anonymize user data for privacy
    public func anonymizeData<T: Codable>(_ data: T) -> AnonymizedData {
        // Generate one-way hash for identification without revealing identity
        let identifier = generateAnonymousIdentifier()
        
        // Remove or hash any personally identifiable information
        let sanitized = sanitizeData(data)
        
        auditLog.logDataOperation(.anonymization, size: 0)
        
        return AnonymizedData(
            identifier: identifier,
            data: sanitized,
            timestamp: Date(),
            privacyLevel: privacyLevel
        )
    }
    
    /// Request user consent for data operations
    public func requestConsent(for operation: DataOperation) async -> Bool {
        logger.info("Requesting consent for: \(operation.description)")
        
        // In a real app, this would show a consent dialog
        // For now, we'll respect the current consent status
        switch consentStatus {
        case .granted:
            auditLog.logConsentRequest(operation, granted: true)
            return true
        case .denied:
            auditLog.logConsentRequest(operation, granted: false)
            return false
        case .limited:
            // Check if this specific operation is allowed
            return await checkLimitedConsent(for: operation)
        case .notDetermined:
            // Prompt for consent (simulated)
            return await promptForConsent(operation)
        }
    }
    
    /// Validate that an operation meets privacy requirements
    public func validatePrivacyCompliance(for operation: DataOperation) -> Bool {
        switch privacyLevel {
        case .maximum:
            // Only allow on-device operations
            return operation.isOnDeviceOnly
        case .enhanced:
            // Allow anonymized operations
            return operation.isOnDeviceOnly || operation.isAnonymized
        case .standard:
            // Standard compliance checks
            return operation.meetsStandardCompliance
        case .minimum:
            // Basic checks only
            return true
        }
    }
    
    /// Securely delete user data
    public func securelyDeleteData(at url: URL) throws {
        logger.info("Securely deleting data at: \(url.lastPathComponent)")
        
        // Overwrite with random data multiple times
        let fileHandle = try FileHandle(forWritingTo: url)
        let fileSize = try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int ?? 0
        
        // DoD 5220.22-M standard: 3-pass overwrite
        for pass in 1...3 {
            fileHandle.seek(toFileOffset: 0)
            let randomData = generateRandomData(size: fileSize)
            fileHandle.write(randomData)
            logger.debug("Overwrite pass \(pass) completed")
        }
        
        fileHandle.closeFile()
        try FileManager.default.removeItem(at: url)
        
        auditLog.logDataOperation(.deletion, size: fileSize)
    }
    
    /// Perform privacy audit
    public func performPrivacyAudit() async -> PrivacyAuditReport {
        logger.info("Performing privacy audit")
        
        let report = PrivacyAuditReport(
            timestamp: Date(),
            privacyLevel: privacyLevel,
            encryptionEnabled: isDataEncrypted,
            consentStatus: consentStatus,
            dataOperations: auditLog.recentOperations,
            recommendations: generatePrivacyRecommendations()
        )
        
        lastPrivacyAudit = Date()
        return report
    }
    
    /// Update privacy level
    public func updatePrivacyLevel(_ level: PrivacyLevel) {
        logger.info("Updating privacy level to: \(level.description)")
        privacyLevel = level
        configurePrivacySettings()
        auditLog.logPrivacyLevelChange(level)
    }
    
    // MARK: - Private Methods
    
    private func setupEncryption() {
        // Generate or retrieve encryption key from Keychain
        if let existingKey = keychain.retrieveEncryptionKey() {
            encryptionKey = existingKey
        } else {
            encryptionKey = SymmetricKey(size: .bits256)
            keychain.storeEncryptionKey(encryptionKey!)
        }
        
        logger.info("Encryption configured successfully")
    }
    
    private func configurePrivacySettings() {
        // Configure system privacy settings based on level
        switch privacyLevel {
        case .maximum:
            // Disable all telemetry, analytics, and external communication
            disableAllTelemetry()
            enableMaximumEncryption()
        case .enhanced:
            // Limited telemetry with anonymization
            configureLimitedTelemetry()
            enableStandardEncryption()
        case .standard:
            // Standard privacy protections
            enableStandardEncryption()
        case .minimum:
            // Basic protections only
            logger.warning("Running with minimum privacy level")
        }
    }
    
    private func startPrivacyAudit() {
        // Schedule regular privacy audits
        Task {
            while true {
                try await Task.sleep(nanoseconds: 86_400_000_000_000) // 24 hours
                _ = await performPrivacyAudit()
            }
        }
    }
    
    private func generateAnonymousIdentifier() -> String {
        // Generate a consistent but anonymous identifier
        let data = UUID().uuidString.data(using: .utf8)!
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    private func sanitizeData<T: Codable>(_ data: T) -> Data {
        // Remove PII from data
        // This is a simplified version - real implementation would be more sophisticated
        do {
            let encoded = try JSONEncoder().encode(data)
            return encoded
        } catch {
            return Data()
        }
    }
    
    private func generateRandomData(size: Int) -> Data {
        var randomData = Data(count: size)
        _ = randomData.withUnsafeMutableBytes { bytes in
            SecRandomCopyBytes(kSecRandomDefault, size, bytes.baseAddress!)
        }
        return randomData
    }
    
    private func checkLimitedConsent(for operation: DataOperation) async -> Bool {
        // Check if specific operation is allowed under limited consent
        return operation.isEssential
    }
    
    private func promptForConsent(_ operation: DataOperation) async -> Bool {
        // In production, this would show a consent dialog
        // For now, default to privacy-preserving behavior
        consentStatus = .limited
        return false
    }
    
    private func disableAllTelemetry() {
        // Disable all telemetry and analytics
        UserDefaults.standard.set(false, forKey: "telemetryEnabled")
        UserDefaults.standard.set(false, forKey: "analyticsEnabled")
    }
    
    private func configureLimitedTelemetry() {
        // Configure limited, anonymized telemetry
        UserDefaults.standard.set(true, forKey: "telemetryEnabled")
        UserDefaults.standard.set(true, forKey: "anonymizeTelemetry")
    }
    
    private func enableMaximumEncryption() {
        isDataEncrypted = true
        // Configure maximum encryption settings
    }
    
    private func enableStandardEncryption() {
        isDataEncrypted = true
        // Configure standard encryption settings
    }
    
    private func generatePrivacyRecommendations() -> [String] {
        var recommendations: [String] = []
        
        if privacyLevel < .maximum {
            recommendations.append("Consider upgrading to Maximum privacy level")
        }
        
        if consentStatus == .notDetermined {
            recommendations.append("Review and update consent preferences")
        }
        
        if let lastAudit = lastPrivacyAudit,
           Date().timeIntervalSince(lastAudit) > 2592000 { // 30 days
            recommendations.append("Privacy audit overdue")
        }
        
        return recommendations
    }
}

// MARK: - Supporting Types

public struct AnonymizedData {
    public let identifier: String
    public let data: Data
    public let timestamp: Date
    public let privacyLevel: PrivacyManager.PrivacyLevel
}

public struct DataOperation {
    public let type: OperationType
    public let isOnDeviceOnly: Bool
    public let isAnonymized: Bool
    public let isEssential: Bool
    
    public var description: String {
        "\(type.rawValue) operation"
    }
    
    public var meetsStandardCompliance: Bool {
        isOnDeviceOnly || isAnonymized
    }
    
    public enum OperationType: String {
        case read = "Read"
        case write = "Write"
        case process = "Process"
        case transmit = "Transmit"
    }
}

public struct PrivacyAuditReport {
    public let timestamp: Date
    public let privacyLevel: PrivacyManager.PrivacyLevel
    public let encryptionEnabled: Bool
    public let consentStatus: PrivacyManager.ConsentStatus
    public let dataOperations: [AuditLogEntry]
    public let recommendations: [String]
}

// MARK: - Keychain Manager

private class KeychainManager {
    private let service = "com.ai.tamagotchi.privacy"
    private let account = "encryption-key"
    
    func storeEncryptionKey(_ key: SymmetricKey) {
        let keyData = key.withUnsafeBytes { Data($0) }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: keyData,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }
    
    func retrieveEncryptionKey() -> SymmetricKey? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let keyData = result as? Data else {
            return nil
        }
        
        return SymmetricKey(data: keyData)
    }
}

// MARK: - Audit Log

private class PrivacyAuditLog {
    private var operations: [AuditLogEntry] = []
    private let maxEntries = 1000
    
    var recentOperations: [AuditLogEntry] {
        Array(operations.suffix(100))
    }
    
    func logDataOperation(_ type: AuditLogEntry.OperationType, size: Int) {
        let entry = AuditLogEntry(
            timestamp: Date(),
            type: type,
            dataSize: size
        )
        
        operations.append(entry)
        if operations.count > maxEntries {
            operations.removeFirst()
        }
    }
    
    func logConsentRequest(_ operation: DataOperation, granted: Bool) {
        // Log consent requests
    }
    
    func logPrivacyLevelChange(_ level: PrivacyManager.PrivacyLevel) {
        // Log privacy level changes
    }
}

public struct AuditLogEntry {
    public let timestamp: Date
    public let type: OperationType
    public let dataSize: Int
    
    public enum OperationType {
        case encryption
        case decryption
        case anonymization
        case deletion
    }
}

// MARK: - Errors

public enum PrivacyError: LocalizedError {
    case encryptionKeyUnavailable
    case encryptionFailed
    case decryptionFailed
    case consentDenied
    
    public var errorDescription: String? {
        switch self {
        case .encryptionKeyUnavailable:
            return "Encryption key is not available"
        case .encryptionFailed:
            return "Failed to encrypt data"
        case .decryptionFailed:
            return "Failed to decrypt data"
        case .consentDenied:
            return "User consent denied for this operation"
        }
    }
}