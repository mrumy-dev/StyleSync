import Foundation
import SwiftUI

class CrashReporter: NSObject {
    static let shared = CrashReporter()

    private var crashHandler: (@convention(c) (Int32) -> Void)?
    private let crashQueue = DispatchQueue(label: "com.stylesync.crash-reporter", qos: .utility)

    override init() {
        super.init()
        setupCrashHandling()
    }

    private func setupCrashHandling() {
        NSSetUncaughtExceptionHandler { exception in
            CrashReporter.shared.handleException(exception)
        }

        signal(SIGABRT) { signal in
            CrashReporter.shared.handleSignal(signal, name: "SIGABRT")
        }

        signal(SIGILL) { signal in
            CrashReporter.shared.handleSignal(signal, name: "SIGILL")
        }

        signal(SIGSEGV) { signal in
            CrashReporter.shared.handleSignal(signal, name: "SIGSEGV")
        }

        signal(SIGFPE) { signal in
            CrashReporter.shared.handleSignal(signal, name: "SIGFPE")
        }

        signal(SIGBUS) { signal in
            CrashReporter.shared.handleSignal(signal, name: "SIGBUS")
        }

        signal(SIGPIPE) { signal in
            CrashReporter.shared.handleSignal(signal, name: "SIGPIPE")
        }
    }

    private func handleException(_ exception: NSException) {
        let crashReport = createCrashReport(
            type: .exception,
            name: exception.name.rawValue,
            reason: exception.reason ?? "Unknown reason",
            callStack: exception.callStackSymbols
        )

        saveCrashReport(crashReport)
    }

    private func handleSignal(_ signal: Int32, name: String) {
        let crashReport = createCrashReport(
            type: .signal,
            name: name,
            reason: "Signal \(signal) received",
            callStack: Thread.callStackSymbols
        )

        saveCrashReport(crashReport)
        exit(signal)
    }

    private func createCrashReport(
        type: CrashType,
        name: String,
        reason: String,
        callStack: [String]
    ) -> CrashReport {
        return CrashReport(
            id: UUID(),
            timestamp: Date(),
            type: type,
            name: name,
            reason: reason,
            callStack: callStack,
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown",
            buildNumber: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown",
            deviceInfo: DeviceInfo.current(),
            systemInfo: SystemInfo.current(),
            memoryInfo: MemoryInfo.current(),
            userActions: UserActionTracker.shared.getRecentActions()
        )
    }

    private func saveCrashReport(_ crashReport: CrashReport) {
        crashQueue.async {
            do {
                let data = try JSONEncoder().encode(crashReport)
                let crashReportsDir = self.getCrashReportsDirectory()
                let fileName = "crash_\(crashReport.id.uuidString).json"
                let filePath = crashReportsDir.appendingPathComponent(fileName)

                try data.write(to: filePath)
                self.cleanupOldCrashReports()

                DispatchQueue.main.async {
                    self.submitCrashReport(crashReport)
                }
            } catch {
                print("Failed to save crash report: \(error)")
            }
        }
    }

    private func getCrashReportsDirectory() -> URL {
        let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let crashReportsDir = documentsDir.appendingPathComponent("CrashReports")

        if !FileManager.default.fileExists(atPath: crashReportsDir.path) {
            try? FileManager.default.createDirectory(at: crashReportsDir, withIntermediateDirectories: true)
        }

        return crashReportsDir
    }

    private func cleanupOldCrashReports() {
        do {
            let crashReportsDir = getCrashReportsDirectory()
            let files = try FileManager.default.contentsOfDirectory(at: crashReportsDir, includingPropertiesForKeys: [.creationDateKey])

            let sortedFiles = files.sorted { file1, file2 in
                let date1 = (try? file1.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
                let date2 = (try? file2.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
                return date1 > date2
            }

            if sortedFiles.count > 10 {
                let filesToDelete = Array(sortedFiles.dropFirst(10))
                for file in filesToDelete {
                    try FileManager.default.removeItem(at: file)
                }
            }
        } catch {
            print("Failed to cleanup old crash reports: \(error)")
        }
    }

    func submitCrashReport(_ crashReport: CrashReport) {
        guard let crashData = try? JSONEncoder().encode(crashReport) else { return }

        var request = URLRequest(url: URL(string: "https://crash-reports.stylesync.app/submit")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = crashData

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Crash report submission failed: \(error.localizedDescription)")
            } else if let httpResponse = response as? HTTPURLResponse,
                      httpResponse.statusCode == 200 {
                self.deleteCrashReport(crashReport.id)
            }
        }.resume()
    }

    private func deleteCrashReport(_ crashId: UUID) {
        crashQueue.async {
            let crashReportsDir = self.getCrashReportsDirectory()
            let fileName = "crash_\(crashId.uuidString).json"
            let filePath = crashReportsDir.appendingPathComponent(fileName)

            try? FileManager.default.removeItem(at: filePath)
        }
    }

    func getPendingCrashReports() -> [CrashReport] {
        do {
            let crashReportsDir = getCrashReportsDirectory()
            let files = try FileManager.default.contentsOfDirectory(at: crashReportsDir, includingPropertiesForKeys: nil)

            var crashReports: [CrashReport] = []

            for file in files where file.pathExtension == "json" {
                if let data = try? Data(contentsOf: file),
                   let crashReport = try? JSONDecoder().decode(CrashReport.self, from: data) {
                    crashReports.append(crashReport)
                }
            }

            return crashReports.sorted { $0.timestamp > $1.timestamp }
        } catch {
            print("Failed to get pending crash reports: \(error)")
            return []
        }
    }

    func retryPendingCrashReports() {
        let pendingReports = getPendingCrashReports()
        for report in pendingReports {
            submitCrashReport(report)
        }
    }

    func recordBreadcrumb(_ breadcrumb: String, category: String = "General") {
        UserActionTracker.shared.recordAction(breadcrumb, category: category)
    }
}

struct CrashReport: Codable {
    let id: UUID
    let timestamp: Date
    let type: CrashType
    let name: String
    let reason: String
    let callStack: [String]
    let appVersion: String
    let buildNumber: String
    let deviceInfo: DeviceInfo
    let systemInfo: SystemInfo
    let memoryInfo: MemoryInfo
    let userActions: [UserAction]
}

enum CrashType: String, Codable {
    case exception = "Exception"
    case signal = "Signal"
    case manual = "Manual"
}

struct SystemInfo: Codable {
    let totalStorage: Int64
    let availableStorage: Int64
    let batteryLevel: Float
    let batteryState: String
    let thermalState: String

    static func current() -> SystemInfo {
        let device = UIDevice.current
        device.isBatteryMonitoringEnabled = true

        let fileManager = FileManager.default
        let paths = fileManager.urls(for: .documentDirectory, in: .userDomainMask)
        let totalStorage = (try? paths.first?.resourceValues(forKeys: [.volumeTotalCapacityKey])?.volumeTotalCapacity) ?? 0
        let availableStorage = (try? paths.first?.resourceValues(forKeys: [.volumeAvailableCapacityKey])?.volumeAvailableCapacity) ?? 0

        return SystemInfo(
            totalStorage: Int64(totalStorage),
            availableStorage: Int64(availableStorage),
            batteryLevel: device.batteryLevel,
            batteryState: batteryStateString(device.batteryState),
            thermalState: thermalStateString(ProcessInfo.processInfo.thermalState)
        )
    }

    private static func batteryStateString(_ state: UIDevice.BatteryState) -> String {
        switch state {
        case .unknown: return "Unknown"
        case .unplugged: return "Unplugged"
        case .charging: return "Charging"
        case .full: return "Full"
        @unknown default: return "Unknown"
        }
    }

    private static func thermalStateString(_ state: ProcessInfo.ThermalState) -> String {
        switch state {
        case .nominal: return "Nominal"
        case .fair: return "Fair"
        case .serious: return "Serious"
        case .critical: return "Critical"
        @unknown default: return "Unknown"
        }
    }
}

struct MemoryInfo: Codable {
    let physicalMemory: UInt64
    let usedMemory: UInt64
    let availableMemory: UInt64

    static func current() -> MemoryInfo {
        let physicalMemory = ProcessInfo.processInfo.physicalMemory

        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        let usedMemory = result == KERN_SUCCESS ? UInt64(info.resident_size) : 0
        let availableMemory = physicalMemory - usedMemory

        return MemoryInfo(
            physicalMemory: physicalMemory,
            usedMemory: usedMemory,
            availableMemory: availableMemory
        )
    }
}

class UserActionTracker {
    static let shared = UserActionTracker()

    private var actions: [UserAction] = []
    private let maxActions = 50
    private let queue = DispatchQueue(label: "com.stylesync.user-action-tracker")

    private init() {}

    func recordAction(_ action: String, category: String = "User") {
        queue.async {
            let userAction = UserAction(
                action: action,
                category: category,
                timestamp: Date()
            )

            self.actions.append(userAction)

            if self.actions.count > self.maxActions {
                self.actions.removeFirst(self.actions.count - self.maxActions)
            }
        }
    }

    func getRecentActions() -> [UserAction] {
        queue.sync {
            return Array(actions.suffix(20))
        }
    }

    func clearActions() {
        queue.async {
            self.actions.removeAll()
        }
    }
}

struct UserAction: Codable {
    let action: String
    let category: String
    let timestamp: Date
}

extension CrashReporter {
    func recordManualCrash(reason: String, additionalInfo: [String: Any] = [:]) {
        let crashReport = createCrashReport(
            type: .manual,
            name: "Manual Crash Report",
            reason: reason,
            callStack: Thread.callStackSymbols
        )

        saveCrashReport(crashReport)
    }
}

struct CrashReportingView: View {
    @State private var pendingReports: [CrashReport] = []
    @State private var isSubmitting = false

    var body: some View {
        NavigationView {
            List {
                if pendingReports.isEmpty {
                    ContentUnavailableView(
                        "No Crash Reports",
                        systemImage: "checkmark.circle.fill",
                        description: Text("Your app is running smoothly!")
                    )
                } else {
                    Section("Pending Reports") {
                        ForEach(pendingReports, id: \.id) { report in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(report.name)
                                    .font(.headline)

                                Text(report.reason)
                                    .font(.caption)
                                    .foregroundColor(.secondary)

                                Text(report.timestamp, style: .relative)
                                    .font(.caption2)
                                    .foregroundColor(.tertiary)
                            }
                            .padding(.vertical, 2)
                        }
                    }

                    Section {
                        Button(action: retrySubmission) {
                            if isSubmitting {
                                HStack {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                    Text("Submitting...")
                                }
                            } else {
                                Text("Retry Submission")
                            }
                        }
                        .disabled(isSubmitting)
                    }
                }
            }
            .navigationTitle("Crash Reports")
            .onAppear {
                loadPendingReports()
            }
        }
    }

    private func loadPendingReports() {
        pendingReports = CrashReporter.shared.getPendingCrashReports()
    }

    private func retrySubmission() {
        isSubmitting = true

        CrashReporter.shared.retryPendingCrashReports()

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            isSubmitting = false
            loadPendingReports()
        }
    }
}

extension View {
    func crashReporting() -> some View {
        onAppear {
            CrashReporter.shared.recordBreadcrumb("View appeared: \(String(describing: type(of: self)))")
        }
        .onDisappear {
            CrashReporter.shared.recordBreadcrumb("View disappeared: \(String(describing: type(of: self)))")
        }
    }

    func recordAction(_ action: String, category: String = "UI") -> some View {
        onTapGesture {
            CrashReporter.shared.recordBreadcrumb(action, category: category)
        }
    }
}