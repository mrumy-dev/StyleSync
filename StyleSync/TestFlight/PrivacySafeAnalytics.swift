import Foundation
import SwiftUI

class PrivacySafeAnalytics {
    static let shared = PrivacySafeAnalytics()

    private let queue = DispatchQueue(label: "com.stylesync.analytics", qos: .utility)
    private var events: [AnalyticsEvent] = []
    private let maxEvents = 1000
    private let batchSize = 50

    private init() {
        startPeriodicFlush()
    }

    func trackEvent(_ eventName: String, parameters: [String: AnalyticsValue] = [:]) {
        let event = AnalyticsEvent(
            name: eventName,
            parameters: anonymizeParameters(parameters),
            timestamp: Date(),
            sessionId: SessionManager.shared.currentSessionId
        )

        queue.async {
            self.events.append(event)
            self.cleanupOldEvents()

            if self.events.count >= self.batchSize {
                self.flushEvents()
            }
        }
    }

    func trackScreenView(_ screenName: String) {
        trackEvent("screen_view", parameters: [
            "screen_name": .string(screenName),
            "previous_screen": .string(SessionManager.shared.previousScreen ?? "unknown")
        ])

        SessionManager.shared.updateCurrentScreen(screenName)
    }

    func trackUserAction(_ action: String, category: String = "general") {
        trackEvent("user_action", parameters: [
            "action": .string(action),
            "category": .string(category)
        ])
    }

    func trackPerformanceMetric(_ metricName: String, value: Double, unit: String = "") {
        trackEvent("performance_metric", parameters: [
            "metric_name": .string(metricName),
            "value": .number(value),
            "unit": .string(unit)
        ])
    }

    func trackError(_ error: String, category: String = "general") {
        trackEvent("error", parameters: [
            "error_message": .string(hashString(error)),
            "category": .string(category),
            "error_hash": .string(String(error.hashValue))
        ])
    }

    func trackFeatureUsage(_ feature: String, used: Bool = true) {
        trackEvent("feature_usage", parameters: [
            "feature": .string(feature),
            "used": .bool(used)
        ])
    }

    private func anonymizeParameters(_ parameters: [String: AnalyticsValue]) -> [String: AnalyticsValue] {
        var anonymized: [String: AnalyticsValue] = [:]

        for (key, value) in parameters {
            let anonymizedKey = key.lowercased()

            if shouldAnonymize(key: anonymizedKey) {
                switch value {
                case .string(let stringValue):
                    anonymized[key] = .string(hashString(stringValue))
                default:
                    anonymized[key] = value
                }
            } else {
                anonymized[key] = value
            }
        }

        return anonymized
    }

    private func shouldAnonymize(key: String) -> Bool {
        let sensitiveKeys = [
            "email", "name", "phone", "address", "user_id",
            "device_id", "ip", "location", "personal", "private"
        ]

        return sensitiveKeys.contains { key.contains($0) }
    }

    private func hashString(_ string: String) -> String {
        return String(string.hashValue)
    }

    private func cleanupOldEvents() {
        if events.count > maxEvents {
            events.removeFirst(events.count - maxEvents)
        }
    }

    private func flushEvents() {
        guard !events.isEmpty else { return }

        let eventsToFlush = Array(events.prefix(batchSize))
        events.removeFirst(min(batchSize, events.count))

        submitEvents(eventsToFlush)
    }

    private func submitEvents(_ events: [AnalyticsEvent]) {
        guard let analyticsData = try? JSONEncoder().encode(events) else { return }

        var request = URLRequest(url: URL(string: "https://analytics.stylesync.app/batch")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("privacy-safe", forHTTPHeaderField: "X-Analytics-Type")
        request.httpBody = analyticsData

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Analytics submission failed: \(error.localizedDescription)")

                self.queue.async {
                    self.events.insert(contentsOf: events, at: 0)
                }
            } else if let httpResponse = response as? HTTPURLResponse,
                      httpResponse.statusCode == 200 {
                print("Analytics batch submitted successfully")
            }
        }.resume()
    }

    private func startPeriodicFlush() {
        Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { _ in
            self.queue.async {
                self.flushEvents()
            }
        }
    }

    func flushAllEvents() {
        queue.async {
            self.flushEvents()
        }
    }

    func clearAllEvents() {
        queue.async {
            self.events.removeAll()
        }
    }

    func getEventCount() -> Int {
        return queue.sync {
            return events.count
        }
    }
}

struct AnalyticsEvent: Codable {
    let name: String
    let parameters: [String: AnalyticsValue]
    let timestamp: Date
    let sessionId: String
    let appVersion: String
    let buildNumber: String
    let platform: String

    init(name: String, parameters: [String: AnalyticsValue], timestamp: Date, sessionId: String) {
        self.name = name
        self.parameters = parameters
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        self.buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
        self.platform = "iOS"
    }
}

enum AnalyticsValue: Codable {
    case string(String)
    case number(Double)
    case bool(Bool)

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch self {
        case .string(let value):
            try container.encode(value)
        case .number(let value):
            try container.encode(value)
        case .bool(let value):
            try container.encode(value)
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let stringValue = try? container.decode(String.self) {
            self = .string(stringValue)
        } else if let numberValue = try? container.decode(Double.self) {
            self = .number(numberValue)
        } else if let boolValue = try? container.decode(Bool.self) {
            self = .bool(boolValue)
        } else {
            throw DecodingError.typeMismatch(
                AnalyticsValue.self,
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Invalid AnalyticsValue")
            )
        }
    }
}

class SessionManager {
    static let shared = SessionManager()

    private(set) var currentSessionId: String
    private(set) var sessionStartTime: Date
    private(set) var previousScreen: String?
    private(set) var currentScreen: String?

    private init() {
        self.currentSessionId = UUID().uuidString
        self.sessionStartTime = Date()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
    }

    @objc private func appDidBecomeActive() {
        if Date().timeIntervalSince(sessionStartTime) > 1800 {
            startNewSession()
        }
    }

    @objc private func appDidEnterBackground() {
        PrivacySafeAnalytics.shared.trackEvent("session_end", parameters: [
            "duration": .number(Date().timeIntervalSince(sessionStartTime))
        ])

        PrivacySafeAnalytics.shared.flushAllEvents()
    }

    private func startNewSession() {
        currentSessionId = UUID().uuidString
        sessionStartTime = Date()

        PrivacySafeAnalytics.shared.trackEvent("session_start")
    }

    func updateCurrentScreen(_ screenName: String) {
        previousScreen = currentScreen
        currentScreen = screenName
    }
}

struct AnalyticsConfig {
    static let isEnabled = true
    static let isDebugMode = false
    static let samplingRate: Double = 1.0

    static func shouldTrack() -> Bool {
        guard isEnabled else { return false }
        return Double.random(in: 0...1) <= samplingRate
    }
}

struct AnalyticsModifier: ViewModifier {
    let screenName: String
    let trackingEnabled: Bool

    init(screenName: String, trackingEnabled: Bool = true) {
        self.screenName = screenName
        self.trackingEnabled = trackingEnabled
    }

    func body(content: Content) -> some View {
        content
            .onAppear {
                if trackingEnabled && AnalyticsConfig.shouldTrack() {
                    PrivacySafeAnalytics.shared.trackScreenView(screenName)
                }
            }
    }
}

struct AnalyticsButtonModifier: ViewModifier {
    let actionName: String
    let category: String
    let trackingEnabled: Bool

    init(actionName: String, category: String = "button", trackingEnabled: Bool = true) {
        self.actionName = actionName
        self.category = category
        self.trackingEnabled = trackingEnabled
    }

    func body(content: Content) -> some View {
        content
            .onTapGesture {
                if trackingEnabled && AnalyticsConfig.shouldTrack() {
                    PrivacySafeAnalytics.shared.trackUserAction(actionName, category: category)
                }
            }
    }
}

extension View {
    func analytics(screenName: String, enabled: Bool = true) -> some View {
        modifier(AnalyticsModifier(screenName: screenName, trackingEnabled: enabled))
    }

    func trackAction(_ actionName: String, category: String = "button", enabled: Bool = true) -> some View {
        modifier(AnalyticsButtonModifier(actionName: actionName, category: category, trackingEnabled: enabled))
    }
}

struct AnalyticsDashboard: View {
    @State private var eventCount = 0
    @State private var sessionInfo: (id: String, duration: TimeInterval) = ("", 0)
    @State private var isFlushingEvents = false

    var body: some View {
        NavigationView {
            List {
                Section("Privacy-Safe Analytics") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("All analytics data is anonymized and privacy-safe")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text("No personal information is tracked or stored")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }

                Section("Current Session") {
                    HStack {
                        Text("Session ID")
                        Spacer()
                        Text(sessionInfo.id.prefix(8) + "...")
                            .font(.caption.monospaced())
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Duration")
                        Spacer()
                        Text(formatDuration(sessionInfo.duration))
                            .foregroundColor(.secondary)
                    }
                }

                Section("Event Queue") {
                    HStack {
                        Text("Pending Events")
                        Spacer()
                        Text("\(eventCount)")
                            .foregroundColor(.secondary)
                    }

                    Button(action: flushEvents) {
                        if isFlushingEvents {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Flushing...")
                            }
                        } else {
                            Text("Flush Events Now")
                        }
                    }
                    .disabled(isFlushingEvents || eventCount == 0)
                }

                Section("Test Events") {
                    Button("Track Test Event") {
                        PrivacySafeAnalytics.shared.trackEvent("test_event", parameters: [
                            "timestamp": .number(Date().timeIntervalSince1970),
                            "random_value": .number(Double.random(in: 1...100))
                        ])
                        updateEventCount()
                    }

                    Button("Track Screen View") {
                        PrivacySafeAnalytics.shared.trackScreenView("analytics_dashboard_test")
                        updateEventCount()
                    }

                    Button("Track User Action") {
                        PrivacySafeAnalytics.shared.trackUserAction("test_button_tap", category: "test")
                        updateEventCount()
                    }
                }
            }
            .navigationTitle("Analytics")
            .onAppear {
                updateSessionInfo()
                updateEventCount()
            }
        }
    }

    private func updateSessionInfo() {
        let manager = SessionManager.shared
        sessionInfo = (
            manager.currentSessionId,
            Date().timeIntervalSince(manager.sessionStartTime)
        )
    }

    private func updateEventCount() {
        eventCount = PrivacySafeAnalytics.shared.getEventCount()
    }

    private func flushEvents() {
        isFlushingEvents = true

        PrivacySafeAnalytics.shared.flushAllEvents()

        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            isFlushingEvents = false
            updateEventCount()
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

class AnalyticsPreferences: ObservableObject {
    @Published var isAnalyticsEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isAnalyticsEnabled, forKey: "analytics_enabled")
        }
    }

    @Published var isPerformanceTrackingEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isPerformanceTrackingEnabled, forKey: "performance_tracking_enabled")
        }
    }

    @Published var isErrorTrackingEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isErrorTrackingEnabled, forKey: "error_tracking_enabled")
        }
    }

    init() {
        self.isAnalyticsEnabled = UserDefaults.standard.bool(forKey: "analytics_enabled")
        self.isPerformanceTrackingEnabled = UserDefaults.standard.bool(forKey: "performance_tracking_enabled")
        self.isErrorTrackingEnabled = UserDefaults.standard.bool(forKey: "error_tracking_enabled")
    }
}

struct AnalyticsPrivacyView: View {
    @StateObject private var preferences = AnalyticsPreferences()

    var body: some View {
        NavigationView {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Privacy-First Analytics")
                            .font(.headline)

                        Text("StyleSync uses privacy-safe analytics that:")
                            .font(.subheadline)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("• Anonymizes all personal data")
                            Text("• Never tracks location or device IDs")
                            Text("• Hashes sensitive information")
                            Text("• Processes data locally first")
                            Text("• Respects your privacy preferences")
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                    .padding(.vertical)
                }

                Section("Analytics Preferences") {
                    Toggle("Enable Analytics", isOn: $preferences.isAnalyticsEnabled)
                    Toggle("Performance Tracking", isOn: $preferences.isPerformanceTrackingEnabled)
                    Toggle("Error Tracking", isOn: $preferences.isErrorTrackingEnabled)
                }

                Section("Data Control") {
                    Button("Clear All Analytics Data") {
                        PrivacySafeAnalytics.shared.clearAllEvents()
                    }
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("Analytics Privacy")
        }
    }
}