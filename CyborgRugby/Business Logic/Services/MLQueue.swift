import Foundation
import OSLog

// Enhanced ML queue with proper error isolation and resource management
actor MLQueue {
    static let shared = MLQueue()
    
    private let queue = DispatchQueue(label: "com.standardcyborg.cyborgRugby.ml", qos: .userInitiated)
    private let logger = Logger(subsystem: "com.standardcyborg.CyborgRugby", category: "ml")
    private var activeOperations = 0
    private let maxConcurrentOperations = 3
    
    // Memory pressure monitoring
    private var isUnderMemoryPressure = false
    
    init() {
        // Monitor memory pressure
        let source = DispatchSource.makeMemoryPressureSource(eventMask: .all, queue: queue)
        source.setEventHandler { [weak self] in
            Task { await self?.handleMemoryPressure() }
        }
        source.resume()
    }
    
    /// Execute ML operations with proper error isolation and resource management
    func run<T>(_ operation: @escaping () throws -> T) async throws -> T {
        // Check resource availability
        guard activeOperations < maxConcurrentOperations else {
            logger.warning("ML queue at capacity, queuing operation")
            throw MLQueueError.resourcesUnavailable
        }
        
        guard !isUnderMemoryPressure else {
            logger.error("ML operations suspended due to memory pressure")
            throw MLQueueError.memoryPressure
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            queue.async { [weak self] in
                Task {
                    await self?.incrementActiveOperations()
                    defer { 
                        Task { await self?.decrementActiveOperations() }
                    }
                    
                    do {
                        let result = try operation()
                        continuation.resume(returning: result)
                    } catch {
                        self?.logger.error("ML operation failed: \(error.localizedDescription)")
                        continuation.resume(throwing: MLQueueError.operationFailed(underlying: error))
                    }
                }
            }
        }
    }
    
    /// Execute ML operations with timeout protection
    func runWithTimeout<T>(
        _ operation: @escaping () throws -> T,
        timeout: TimeInterval = 10.0
    ) async throws -> T {
        return try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await self.run(operation)
            }
            
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                throw MLQueueError.timeout
            }
            
            guard let result = try await group.next() else {
                throw MLQueueError.unknown
            }
            
            group.cancelAll()
            return result
        }
    }
    
    private func incrementActiveOperations() {
        activeOperations += 1
        logger.debug("Active ML operations: \(self.activeOperations)")
    }
    
    private func decrementActiveOperations() {
        activeOperations = max(0, activeOperations - 1)
        logger.debug("Active ML operations: \(self.activeOperations)")
    }
    
    private func handleMemoryPressure() {
        isUnderMemoryPressure = true
        logger.warning("Memory pressure detected, suspending ML operations")
        
        // Resume after delay
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            isUnderMemoryPressure = false
            logger.info("Memory pressure resolved, resuming ML operations")
        }
    }
    
    /// Get current queue status for debugging
    var status: MLQueueStatus {
        return MLQueueStatus(
            activeOperations: activeOperations,
            maxConcurrentOperations: maxConcurrentOperations,
            isUnderMemoryPressure: isUnderMemoryPressure
        )
    }
}

// MARK: - Supporting Types

enum MLQueueError: LocalizedError {
    case resourcesUnavailable
    case memoryPressure
    case timeout
    case operationFailed(underlying: Error)
    case unknown
    
    var errorDescription: String? {
        switch self {
        case .resourcesUnavailable:
            return "ML processing resources are currently unavailable"
        case .memoryPressure:
            return "ML operations suspended due to memory pressure"
        case .timeout:
            return "ML operation timed out"
        case .operationFailed(let underlying):
            return "ML operation failed: \(underlying.localizedDescription)"
        case .unknown:
            return "Unknown ML queue error"
        }
    }
}

struct MLQueueStatus {
    let activeOperations: Int
    let maxConcurrentOperations: Int
    let isUnderMemoryPressure: Bool
    
    var isAtCapacity: Bool {
        return activeOperations >= maxConcurrentOperations
    }
}
