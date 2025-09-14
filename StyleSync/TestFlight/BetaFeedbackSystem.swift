import SwiftUI
import MessageUI

struct BetaFeedbackSystem {
    static let shared = BetaFeedbackSystem()

    private init() {}

    func collectFeedback(type: FeedbackType, description: String, metadata: FeedbackMetadata) {
        let feedback = BetaFeedback(
            type: type,
            description: description,
            metadata: metadata,
            timestamp: Date(),
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown",
            buildNumber: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown",
            deviceInfo: DeviceInfo.current()
        )

        storeFeedbackLocally(feedback)
        submitFeedbackIfPossible(feedback)
    }

    private func storeFeedbackLocally(_ feedback: BetaFeedback) {
        var storedFeedback = getStoredFeedback()
        storedFeedback.append(feedback)

        if let data = try? JSONEncoder().encode(storedFeedback) {
            UserDefaults.standard.set(data, forKey: "stored_beta_feedback")
        }

        if storedFeedback.count > 50 {
            cleanupOldFeedback()
        }
    }

    private func submitFeedbackIfPossible(_ feedback: BetaFeedback) {
        guard let feedbackData = try? JSONEncoder().encode(feedback) else { return }

        var request = URLRequest(url: URL(string: "https://feedback.stylesync.app/beta")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = feedbackData

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Feedback submission failed: \(error.localizedDescription)")
            } else if let httpResponse = response as? HTTPURLResponse,
                      httpResponse.statusCode == 200 {
                removeFeedbackFromLocalStorage(feedback.id)
            }
        }.resume()
    }

    private func getStoredFeedback() -> [BetaFeedback] {
        guard let data = UserDefaults.standard.data(forKey: "stored_beta_feedback"),
              let feedback = try? JSONDecoder().decode([BetaFeedback].self, from: data) else {
            return []
        }
        return feedback
    }

    private func cleanupOldFeedback() {
        var storedFeedback = getStoredFeedback()
        storedFeedback = storedFeedback.sorted { $0.timestamp > $1.timestamp }
        storedFeedback = Array(storedFeedback.prefix(25))

        if let data = try? JSONEncoder().encode(storedFeedback) {
            UserDefaults.standard.set(data, forKey: "stored_beta_feedback")
        }
    }

    private func removeFeedbackFromLocalStorage(_ feedbackId: UUID) {
        var storedFeedback = getStoredFeedback()
        storedFeedback.removeAll { $0.id == feedbackId }

        if let data = try? JSONEncoder().encode(storedFeedback) {
            UserDefaults.standard.set(data, forKey: "stored_beta_feedback")
        }
    }

    func retryPendingFeedback() {
        let pendingFeedback = getStoredFeedback()

        for feedback in pendingFeedback {
            submitFeedbackIfPossible(feedback)
        }
    }
}

struct BetaFeedback: Codable {
    let id = UUID()
    let type: FeedbackType
    let description: String
    let metadata: FeedbackMetadata
    let timestamp: Date
    let appVersion: String
    let buildNumber: String
    let deviceInfo: DeviceInfo
}

enum FeedbackType: String, Codable, CaseIterable {
    case bug = "Bug Report"
    case feature = "Feature Request"
    case ui = "UI/UX Issue"
    case performance = "Performance Issue"
    case crash = "Crash Report"
    case general = "General Feedback"
}

struct FeedbackMetadata: Codable {
    let currentScreen: String
    let userActions: [String]
    let errorLogs: [String]
    let networkStatus: String
    let memoryUsage: Double
    let batteryLevel: Float
}

struct DeviceInfo: Codable {
    let model: String
    let systemVersion: String
    let screenSize: String
    let locale: String
    let timezone: String

    static func current() -> DeviceInfo {
        let device = UIDevice.current
        let screen = UIScreen.main

        return DeviceInfo(
            model: device.model,
            systemVersion: device.systemVersion,
            screenSize: "\(Int(screen.bounds.width))x\(Int(screen.bounds.height))",
            locale: Locale.current.identifier,
            timezone: TimeZone.current.identifier
        )
    }
}

struct BetaFeedbackView: View {
    @State private var selectedType: FeedbackType = .general
    @State private var feedbackText = ""
    @State private var isSubmitting = false
    @State private var showSuccess = false
    @Binding var isPresented: Bool

    var body: some View {
        NavigationView {
            Form {
                Section("Feedback Type") {
                    Picker("Type", selection: $selectedType) {
                        ForEach(FeedbackType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }

                Section("Description") {
                    TextEditor(text: $feedbackText)
                        .frame(minHeight: 120)
                }

                Section {
                    Button(action: submitFeedback) {
                        if isSubmitting {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Submitting...")
                            }
                        } else {
                            Text("Submit Feedback")
                        }
                    }
                    .disabled(feedbackText.isEmpty || isSubmitting)
                }
            }
            .navigationTitle("Beta Feedback")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
            .alert("Feedback Sent", isPresented: $showSuccess) {
                Button("OK") {
                    isPresented = false
                }
            } message: {
                Text("Thank you for helping us improve StyleSync!")
            }
        }
    }

    private func submitFeedback() {
        isSubmitting = true

        let metadata = FeedbackMetadata(
            currentScreen: "BetaFeedbackView",
            userActions: ["opened_feedback", "selected_\(selectedType.rawValue)"],
            errorLogs: [],
            networkStatus: "connected",
            memoryUsage: Double(ProcessInfo.processInfo.physicalMemory) / 1_000_000,
            batteryLevel: UIDevice.current.batteryLevel
        )

        BetaFeedbackSystem.shared.collectFeedback(
            type: selectedType,
            description: feedbackText,
            metadata: metadata
        )

        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            isSubmitting = false
            showSuccess = true
        }
    }
}

struct ShakeDetector: UIViewRepresentable {
    let onShake: () -> Void

    func makeUIView(context: Context) -> UIView {
        let view = ShakeDetectingView()
        view.onShake = onShake
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}

class ShakeDetectingView: UIView {
    var onShake: (() -> Void)?

    override func motionBegan(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        guard motion == .motionShake else { return }
        onShake?()
    }
}

struct FloatingFeedbackButton: View {
    @State private var showFeedbackView = false
    @State private var position = CGPoint(x: UIScreen.main.bounds.width - 60, y: UIScreen.main.bounds.height - 200)
    @State private var isDragging = false

    var body: some View {
        Button(action: {
            showFeedbackView = true
        }) {
            Image(systemName: "questionmark.bubble.fill")
                .font(.title2)
                .foregroundColor(.white)
                .frame(width: 50, height: 50)
                .background(.blue)
                .clipShape(Circle())
                .shadow(radius: 4)
        }
        .position(position)
        .scaleEffect(isDragging ? 1.1 : 1.0)
        .animation(.spring(response: 0.3), value: isDragging)
        .gesture(
            DragGesture()
                .onChanged { value in
                    isDragging = true
                    position = value.location
                }
                .onEnded { _ in
                    isDragging = false
                    snapToEdge()
                }
        )
        .sheet(isPresented: $showFeedbackView) {
            BetaFeedbackView(isPresented: $showFeedbackView)
        }
    }

    private func snapToEdge() {
        let screenWidth = UIScreen.main.bounds.width
        let screenHeight = UIScreen.main.bounds.height

        let leftDistance = position.x
        let rightDistance = screenWidth - position.x

        withAnimation(.spring()) {
            if leftDistance < rightDistance {
                position.x = 30
            } else {
                position.x = screenWidth - 30
            }

            position.y = max(100, min(screenHeight - 100, position.y))
        }
    }
}

extension View {
    func betaFeedbackOverlay() -> some View {
        ZStack {
            self

            if ProcessInfo.processInfo.environment["CONFIGURATION"] == "Beta" {
                FloatingFeedbackButton()
            }
        }
    }

    func shakeToFeedback() -> some View {
        background(
            ShakeDetector {
                NotificationCenter.default.post(name: .shakeDetected, object: nil)
            }
        )
    }
}

extension Notification.Name {
    static let shakeDetected = Notification.Name("shakeDetected")
}