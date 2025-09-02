import Foundation
import CoreML
import os.log

/// Monitors CoreML model performance and resource usage
class PerformanceMonitor {
    private let logger = Logger(subsystem: "com.aitamagotchi.ai", category: "Performance")
    private var metrics = PerformanceMetrics()
    private let metricsQueue = DispatchQueue(label: "performance.metrics", qos: .utility)
    
    // MARK: - Performance Tracking
    
    func startInferenceTracking() -> InferenceTracker {
        return InferenceTracker(monitor: self)
    }
    
    func recordInference(
        modelName: String,
        duration: TimeInterval,
        inputSize: Int,
        outputSize: Int
    ) {
        metricsQueue.async { [weak self] in
            guard let self = self else { return }
            
            let inference = InferenceMetric(
                modelName: modelName,
                duration: duration,
                inputSize: inputSize,
                outputSize: outputSize,
                timestamp: Date(),
                memoryUsed: self.currentMemoryUsage(),
                cpuUsage: self.currentCPUUsage()
            )
            
            self.metrics.inferences.append(inference)
            self.updateAggregateMetrics(with: inference)
            
            // Keep only recent metrics (last 1000)
            if self.metrics.inferences.count > 1000 {
                self.metrics.inferences.removeFirst(500)
            }
            
            // Log if performance degrades
            if duration > 1.0 {
                self.logger.warning("Slow inference detected: \(modelName) took \(duration)s")
            }
        }
    }
    
    // MARK: - Resource Monitoring
    
    func currentMemoryUsage() -> Double {
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
        
        return result == KERN_SUCCESS ? Double(info.resident_size) / 1024.0 / 1024.0 : 0
    }
    
    func currentCPUUsage() -> Double {
        var info = thread_basic_info()
        var count = mach_msg_type_number_t(THREAD_BASIC_INFO_COUNT)
        
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                thread_info(mach_thread_self(),
                           thread_flavor_t(THREAD_BASIC_INFO),
                           $0,
                           &count)
            }
        }
        
        if result == KERN_SUCCESS {
            let userTime = Double(info.user_time.seconds) + Double(info.user_time.microseconds) / 1_000_000
            let systemTime = Double(info.system_time.seconds) + Double(info.system_time.microseconds) / 1_000_000
            return (userTime + systemTime) * 100
        }
        
        return 0
    }
    
    func thermalState() -> ProcessInfo.ThermalState {
        return ProcessInfo.processInfo.thermalState
    }
    
    // MARK: - Performance Analysis
    
    func getPerformanceReport() -> PerformanceReport {
        return metricsQueue.sync {
            PerformanceReport(
                averageInferenceTime: metrics.averageInferenceTime,
                p95InferenceTime: calculatePercentile(95),
                p99InferenceTime: calculatePercentile(99),
                totalInferences: metrics.totalInferences,
                failedInferences: metrics.failedInferences,
                averageMemoryUsage: metrics.averageMemoryUsage,
                peakMemoryUsage: metrics.peakMemoryUsage,
                modelMetrics: getModelSpecificMetrics(),
                recommendations: generateRecommendations()
            )
        }
    }
    
    private func calculatePercentile(_ percentile: Int) -> TimeInterval {
        let sortedDurations = metrics.inferences.map { $0.duration }.sorted()
        guard !sortedDurations.isEmpty else { return 0 }
        
        let index = Int(Double(sortedDurations.count) * Double(percentile) / 100.0)
        return sortedDurations[min(index, sortedDurations.count - 1)]
    }
    
    private func getModelSpecificMetrics() -> [String: ModelMetric] {
        var modelMetrics: [String: ModelMetric] = [:]
        
        for inference in metrics.inferences {
            var metric = modelMetrics[inference.modelName, default: ModelMetric()]
            metric.invocations += 1
            metric.totalTime += inference.duration
            metric.averageTime = metric.totalTime / Double(metric.invocations)
            metric.lastUsed = inference.timestamp
            modelMetrics[inference.modelName] = metric
        }
        
        return modelMetrics
    }
    
    // MARK: - Optimization Recommendations
    
    private func generateRecommendations() -> [PerformanceRecommendation] {
        var recommendations: [PerformanceRecommendation] = []
        
        // Check memory usage
        if metrics.averageMemoryUsage > 200 {
            recommendations.append(
                PerformanceRecommendation(
                    type: .memory,
                    severity: .high,
                    message: "High memory usage detected. Consider using smaller models or batch processing.",
                    action: .reduceModelSize
                )
            )
        }
        
        // Check inference times
        if metrics.averageInferenceTime > 0.5 {
            recommendations.append(
                PerformanceRecommendation(
                    type: .speed,
                    severity: .medium,
                    message: "Slow inference times. Consider model quantization or using Neural Engine.",
                    action: .optimizeModel
                )
            )
        }
        
        // Check thermal state
        if thermalState() == .serious || thermalState() == .critical {
            recommendations.append(
                PerformanceRecommendation(
                    type: .thermal,
                    severity: .high,
                    message: "Device is thermally throttled. Reduce inference frequency.",
                    action: .throttleInference
                )
            )
        }
        
        return recommendations
    }
    
    // MARK: - Adaptive Performance
    
    func adaptPerformanceSettings() -> PerformanceSettings {
        let thermal = thermalState()
        let memoryPressure = metrics.averageMemoryUsage > 150
        
        return PerformanceSettings(
            maxConcurrentInferences: thermal == .nominal ? 3 : 1,
            useNeuralEngine: true,
            allowLowPrecision: memoryPressure || thermal != .nominal,
            batchSize: thermal == .nominal ? 32 : 16,
            cacheModels: metrics.averageMemoryUsage < 100
        )
    }
    
    // MARK: - Helpers
    
    private func updateAggregateMetrics(with inference: InferenceMetric) {
        metrics.totalInferences += 1
        
        // Update average inference time
        let currentTotal = metrics.averageInferenceTime * Double(metrics.totalInferences - 1)
        metrics.averageInferenceTime = (currentTotal + inference.duration) / Double(metrics.totalInferences)
        
        // Update memory metrics
        metrics.peakMemoryUsage = max(metrics.peakMemoryUsage, inference.memoryUsed)
        let currentMemTotal = metrics.averageMemoryUsage * Double(metrics.totalInferences - 1)
        metrics.averageMemoryUsage = (currentMemTotal + inference.memoryUsed) / Double(metrics.totalInferences)
    }
}

// MARK: - Inference Tracker

class InferenceTracker {
    private let startTime: CFAbsoluteTime
    private let startMemory: Double
    private weak var monitor: PerformanceMonitor?
    
    init(monitor: PerformanceMonitor) {
        self.monitor = monitor
        self.startTime = CFAbsoluteTimeGetCurrent()
        self.startMemory = monitor.currentMemoryUsage()
    }
    
    func complete(
        modelName: String,
        inputSize: Int,
        outputSize: Int
    ) {
        let duration = CFAbsoluteTimeGetCurrent() - startTime
        monitor?.recordInference(
            modelName: modelName,
            duration: duration,
            inputSize: inputSize,
            outputSize: outputSize
        )
    }
}

// MARK: - Supporting Types

struct PerformanceMetrics {
    var inferences: [InferenceMetric] = []
    var totalInferences: Int = 0
    var failedInferences: Int = 0
    var averageInferenceTime: TimeInterval = 0
    var averageMemoryUsage: Double = 0
    var peakMemoryUsage: Double = 0
}

struct InferenceMetric {
    let modelName: String
    let duration: TimeInterval
    let inputSize: Int
    let outputSize: Int
    let timestamp: Date
    let memoryUsed: Double
    let cpuUsage: Double
}

struct ModelMetric {
    var invocations: Int = 0
    var totalTime: TimeInterval = 0
    var averageTime: TimeInterval = 0
    var lastUsed: Date = Date()
}

struct PerformanceReport {
    let averageInferenceTime: TimeInterval
    let p95InferenceTime: TimeInterval
    let p99InferenceTime: TimeInterval
    let totalInferences: Int
    let failedInferences: Int
    let averageMemoryUsage: Double
    let peakMemoryUsage: Double
    let modelMetrics: [String: ModelMetric]
    let recommendations: [PerformanceRecommendation]
}

struct PerformanceRecommendation {
    enum RecommendationType {
        case memory
        case speed
        case thermal
        case battery
    }
    
    enum Severity {
        case low
        case medium
        case high
    }
    
    enum Action {
        case reduceModelSize
        case optimizeModel
        case throttleInference
        case enableCaching
        case useBatchProcessing
    }
    
    let type: RecommendationType
    let severity: Severity
    let message: String
    let action: Action
}

struct PerformanceSettings {
    let maxConcurrentInferences: Int
    let useNeuralEngine: Bool
    let allowLowPrecision: Bool
    let batchSize: Int
    let cacheModels: Bool
}