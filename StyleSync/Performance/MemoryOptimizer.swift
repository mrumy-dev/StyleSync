import Foundation
import SwiftUI
import UIKit

@MainActor
class MemoryOptimizer: ObservableObject {
    static let shared = MemoryOptimizer()

    @Published var memoryUsage: MemoryUsage = MemoryUsage()
    @Published var isOptimizing = false

    private let memoryWarningThreshold: UInt64 = 200 * 1024 * 1024 // 200MB
    private let memoryPressureThreshold: Float = 0.8
    private var memoryTimer: Timer?

    init() {
        startMemoryMonitoring()
        setupMemoryPressureHandling()
    }

    private func startMemoryMonitoring() {
        memoryTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            Task { @MainActor in
                self.updateMemoryUsage()
                self.checkMemoryPressure()
            }
        }
    }

    private func updateMemoryUsage() {
        let usage = getMemoryUsage()
        memoryUsage = usage

        if usage.usedMemory > memoryWarningThreshold {
            performMemoryOptimization()
        }
    }

    private func checkMemoryPressure() {
        let pressure = Float(memoryUsage.usedMemory) / Float(memoryUsage.totalMemory)
        if pressure > memoryPressureThreshold {
            performAggressiveMemoryCleanup()
        }
    }

    private func setupMemoryPressureHandling() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
    }

    @objc private func handleMemoryWarning() {
        Task { @MainActor in
            await performEmergencyMemoryCleanup()
        }
    }

    func performMemoryOptimization() {
        guard !isOptimizing else { return }
        isOptimizing = true

        Task {
            await cleanupImageCache()
            await cleanupUnusedData()
            await optimizeDataStructures()

            await MainActor.run {
                isOptimizing = false
            }
        }
    }

    private func performAggressiveMemoryCleanup() {
        Task {
            await cleanupImageCache(aggressive: true)
            await clearTemporaryData()
            await compactMemoryUsage()
        }
    }

    private func performEmergencyMemoryCleanup() async {
        ImageLoader.clearCache()
        await clearAllCaches()
        await releaseUnusedResources()
        System.gc()
    }

    private func getMemoryUsage() -> MemoryUsage {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        let usedMemory = result == KERN_SUCCESS ? UInt64(info.resident_size) : 0
        let totalMemory = ProcessInfo.processInfo.physicalMemory

        return MemoryUsage(
            usedMemory: usedMemory,
            totalMemory: totalMemory,
            availableMemory: totalMemory - usedMemory,
            memoryPressure: calculateMemoryPressure(used: usedMemory, total: totalMemory)
        )
    }

    private func calculateMemoryPressure(used: UInt64, total: UInt64) -> MemoryPressure {
        let ratio = Float(used) / Float(total)
        switch ratio {
        case 0..<0.5: return .low
        case 0.5..<0.7: return .moderate
        case 0.7..<0.9: return .high
        default: return .critical
        }
    }

    private func cleanupImageCache(aggressive: Bool = false) async {
        if aggressive {
            ImageLoader.clearCache()
        } else {
            URLCache.shared.removeAllCachedResponses()
        }
    }

    private func cleanupUnusedData() async {
        await DataManager.shared.cleanupUnusedData()
    }

    private func optimizeDataStructures() async {
        await DataManager.shared.optimizeDataStructures()
    }

    private func clearTemporaryData() async {
        let fileManager = FileManager.default
        let tempDir = NSTemporaryDirectory()

        do {
            let contents = try fileManager.contentsOfDirectory(atPath: tempDir)
            for item in contents {
                try fileManager.removeItem(atPath: tempDir + item)
            }
        } catch {
            print("Failed to clear temporary data: \(error)")
        }
    }

    private func compactMemoryUsage() async {
        malloc_zone_pressure_relief(nil, 0)
    }

    private func clearAllCaches() async {
        URLCache.shared.removeAllCachedResponses()
        UserDefaults.standard.synchronize()
    }

    private func releaseUnusedResources() async {

    }
}

struct MemoryUsage {
    let usedMemory: UInt64
    let totalMemory: UInt64
    let availableMemory: UInt64
    let memoryPressure: MemoryPressure

    init(
        usedMemory: UInt64 = 0,
        totalMemory: UInt64 = ProcessInfo.processInfo.physicalMemory,
        availableMemory: UInt64 = 0,
        memoryPressure: MemoryPressure = .low
    ) {
        self.usedMemory = usedMemory
        self.totalMemory = totalMemory
        self.availableMemory = availableMemory
        self.memoryPressure = memoryPressure
    }

    var usedMemoryMB: Double {
        Double(usedMemory) / 1024.0 / 1024.0
    }

    var totalMemoryMB: Double {
        Double(totalMemory) / 1024.0 / 1024.0
    }

    var memoryUsagePercentage: Double {
        guard totalMemory > 0 else { return 0 }
        return Double(usedMemory) / Double(totalMemory) * 100
    }
}

enum MemoryPressure {
    case low
    case moderate
    case high
    case critical

    var color: Color {
        switch self {
        case .low: return .green
        case .moderate: return .yellow
        case .high: return .orange
        case .critical: return .red
        }
    }

    var description: String {
        switch self {
        case .low: return "Low"
        case .moderate: return "Moderate"
        case .high: return "High"
        case .critical: return "Critical"
        }
    }
}

class SmartCache<Key: Hashable, Value> {
    private var cache: [Key: CacheEntry<Value>] = [:]
    private let maxSize: Int
    private let maxAge: TimeInterval
    private let queue = DispatchQueue(label: "com.stylesync.cache", attributes: .concurrent)

    struct CacheEntry<T> {
        let value: T
        let timestamp: Date
        let accessCount: Int

        init(value: T) {
            self.value = value
            self.timestamp = Date()
            self.accessCount = 1
        }

        func accessed() -> CacheEntry<T> {
            CacheEntry(value: value, timestamp: timestamp, accessCount: accessCount + 1)
        }
    }

    init(maxSize: Int = 100, maxAge: TimeInterval = 3600) {
        self.maxSize = maxSize
        self.maxAge = maxAge
    }

    func setValue(_ value: Value, forKey key: Key) {
        queue.async(flags: .barrier) {
            self.cache[key] = CacheEntry(value: value)
            self.evictIfNeeded()
        }
    }

    func getValue(forKey key: Key) -> Value? {
        return queue.sync {
            guard let entry = cache[key] else { return nil }

            if Date().timeIntervalSince(entry.timestamp) > maxAge {
                cache.removeValue(forKey: key)
                return nil
            }

            cache[key] = entry.accessed()
            return entry.value
        }
    }

    func removeValue(forKey key: Key) {
        queue.async(flags: .barrier) {
            self.cache.removeValue(forKey: key)
        }
    }

    func clearAll() {
        queue.async(flags: .barrier) {
            self.cache.removeAll()
        }
    }

    private func evictIfNeeded() {
        while cache.count > maxSize {
            let leastUsed = cache.min { lhs, rhs in
                if lhs.value.accessCount != rhs.value.accessCount {
                    return lhs.value.accessCount < rhs.value.accessCount
                }
                return lhs.value.timestamp < rhs.value.timestamp
            }

            if let keyToRemove = leastUsed?.key {
                cache.removeValue(forKey: keyToRemove)
            }
        }
    }
}

class DataManager {
    static let shared = DataManager()

    private var outfitCache = SmartCache<String, OutfitData>()
    private var imageMetadataCache = SmartCache<String, ImageMetadata>()

    func cleanupUnusedData() async {
        let now = Date()
        let calendar = Calendar.current

        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                self.cleanupOldOutfits(olderThan: calendar.date(byAdding: .day, value: -30, to: now)!)
            }

            group.addTask {
                self.cleanupTempImages()
            }

            group.addTask {
                self.cleanupAnalyticsData(olderThan: calendar.date(byAdding: .day, value: -90, to: now)!)
            }
        }
    }

    func optimizeDataStructures() async {
        outfitCache.clearAll()
        imageMetadataCache.clearAll()

        await compactCoreData()
    }

    private func cleanupOldOutfits(olderThan date: Date) {

    }

    private func cleanupTempImages() {
        let fileManager = FileManager.default
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let tempImagesPath = documentsPath.appendingPathComponent("TempImages")

        do {
            let contents = try fileManager.contentsOfDirectory(at: tempImagesPath, includingPropertiesForKeys: [.creationDateKey])
            let cutoffDate = Date().addingTimeInterval(-24 * 60 * 60) // 24 hours ago

            for url in contents {
                let creationDate = try url.resourceValues(forKeys: [.creationDateKey]).creationDate
                if let date = creationDate, date < cutoffDate {
                    try fileManager.removeItem(at: url)
                }
            }
        } catch {
            print("Failed to cleanup temp images: \(error)")
        }
    }

    private func cleanupAnalyticsData(olderThan date: Date) {

    }

    private func compactCoreData() async {

    }
}

struct OutfitData {
    let id: String
    let items: [String]
    let createdAt: Date
}

struct MemoryOptimizedView<Content: View>: View {
    @StateObject private var optimizer = MemoryOptimizer.shared
    @ViewBuilder let content: Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .onAppear {
                optimizer.performMemoryOptimization()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didReceiveMemoryWarningNotification)) { _ in
                Task {
                    await optimizer.performEmergencyMemoryCleanup()
                }
            }
    }
}

extension View {
    func memoryOptimized() -> some View {
        MemoryOptimizedView {
            self
        }
    }
}

struct MemoryMonitorView: View {
    @StateObject private var optimizer = MemoryOptimizer.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Memory Usage")
                    .font(.headline)
                    .fontWeight(.semibold)

                Spacer()

                Text(String(format: "%.1f MB", optimizer.memoryUsage.usedMemoryMB))
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(optimizer.memoryUsage.memoryPressure.color)
            }

            VStack(spacing: 8) {
                ProgressView(value: optimizer.memoryUsage.memoryUsagePercentage / 100)
                    .progressViewStyle(LinearProgressViewStyle(tint: optimizer.memoryUsage.memoryPressure.color))

                HStack {
                    Text("Pressure: \(optimizer.memoryUsage.memoryPressure.description)")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Spacer()

                    Text(String(format: "%.1f%%", optimizer.memoryUsage.memoryUsagePercentage))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            if optimizer.isOptimizing {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)

                    Text("Optimizing memory...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

enum System {
    static func gc() {
        let app = UIApplication.shared
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            app.perform(Selector(("_performMemoryWarning")))
        }
    }
}