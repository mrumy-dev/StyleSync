import SwiftUI
import CryptoKit

struct PrivacyDashboard: View {
    @StateObject private var securityVault = SecurityVault.shared
    @StateObject private var privacyManager = PrivacyManager()
    @State private var showingSecureSharing = false
    @State private var showingEncryptionDetails = false
    @State private var selectedPrivacyTopic: PrivacyTopic?

    enum PrivacyTopic: String, CaseIterable {
        case encryption = "Encryption"
        case biometrics = "Biometrics"
        case cloudSync = "Cloud Sync"
        case analytics = "Analytics"
        case sharing = "Sharing"
        case storage = "Storage"

        var icon: String {
            switch self {
            case .encryption: return "lock.shield.fill"
            case .biometrics: return "faceid"
            case .cloudSync: return "icloud.fill"
            case .analytics: return "chart.bar.xaxis"
            case .sharing: return "square.and.arrow.up"
            case .storage: return "externaldrive.fill"
            }
        }

        var color: Color {
            switch self {
            case .encryption: return .green
            case .biometrics: return .blue
            case .cloudSync: return .cyan
            case .analytics: return .purple
            case .sharing: return .orange
            case .storage: return .yellow
            }
        }
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Security Status Overview
                    SecurityStatusCard(securityVault: securityVault)

                    // Privacy Controls Grid
                    PrivacyControlsGrid(
                        privacyManager: privacyManager,
                        selectedTopic: $selectedPrivacyTopic
                    )

                    // Encryption Details
                    EncryptionStatusCard(
                        securityVault: securityVault,
                        showingDetails: $showingEncryptionDetails
                    )

                    // Data Usage Analytics
                    DataUsageCard(privacyManager: privacyManager)

                    // Secure Sharing
                    SecureSharingCard(showingSharing: $showingSecureSharing)

                    // Privacy Timeline
                    PrivacyTimelineCard()
                }
                .padding()
            }
            .navigationTitle("Privacy & Security")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { securityVault.lockVault() }) {
                        Image(systemName: "lock.fill")
                            .foregroundStyle(DesignSystem.Colors.accent)
                    }
                }
            }
        }
        .sheet(isPresented: $showingSecureSharing) {
            SecureSharingView()
        }
        .sheet(item: $selectedPrivacyTopic) { topic in
            PrivacyTopicDetailView(topic: topic)
        }
    }
}

// MARK: - Security Status Card

struct SecurityStatusCard: View {
    @ObservedObject var securityVault: SecurityVault
    @State private var pulseAnimation = false

    var body: some View {
        GlassCardView {
            VStack(spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Security Status")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.primary)

                        Text("Your data is protected")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    // Status Indicator
                    ZStack {
                        Circle()
                            .fill(statusColor.opacity(0.2))
                            .frame(width: 60, height: 60)
                            .scaleEffect(pulseAnimation ? 1.1 : 1.0)

                        Image(systemName: statusIcon)
                            .font(.system(size: 24, weight: .medium))
                            .foregroundStyle(statusColor)
                    }
                }

                Divider()

                // Security Metrics
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 16) {
                    SecurityMetric(
                        title: "Encryption",
                        value: "AES-256",
                        icon: "lock.shield.fill",
                        color: .green
                    )

                    SecurityMetric(
                        title: "Biometric",
                        value: securityVault.biometricType.displayName,
                        icon: securityVault.biometricType.icon,
                        color: .blue
                    )

                    SecurityMetric(
                        title: "Secure Enclave",
                        value: "Active",
                        icon: "cpu.fill",
                        color: .purple
                    )
                }
            }
            .padding()
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                pulseAnimation = true
            }
        }
    }

    private var statusColor: Color {
        securityVault.isUnlocked ? .green : .orange
    }

    private var statusIcon: String {
        securityVault.isUnlocked ? "checkmark.shield.fill" : "lock.shield.fill"
    }
}

struct SecurityMetric: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)

            VStack(spacing: 2) {
                Text(value)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)

                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Privacy Controls Grid

struct PrivacyControlsGrid: View {
    @ObservedObject var privacyManager: PrivacyManager
    @Binding var selectedTopic: PrivacyTopic?

    var body: some View {
        GlassCardView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Privacy Controls")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)

                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                    ForEach(PrivacyTopic.allCases, id: \.self) { topic in
                        PrivacyControlButton(
                            topic: topic,
                            isEnabled: privacyManager.isEnabled(topic)
                        ) {
                            selectedTopic = topic
                            HapticManager.HapticType.selection.trigger()
                        }
                    }
                }
            }
            .padding()
        }
    }
}

struct PrivacyControlButton: View {
    let topic: PrivacyTopic
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(topic.color.opacity(0.2))
                        .frame(width: 50, height: 50)

                    Image(systemName: topic.icon)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(topic.color)
                }

                VStack(spacing: 4) {
                    Text(topic.rawValue)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)

                    Circle()
                        .fill(isEnabled ? .green : .gray)
                        .frame(width: 8, height: 8)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(InteractiveButtonStyle())
    }
}

// MARK: - Encryption Status Card

struct EncryptionStatusCard: View {
    @ObservedObject var securityVault: SecurityVault
    @Binding var showingDetails: Bool

    var body: some View {
        GlassCardView {
            VStack(spacing: 16) {
                HStack {
                    Text("Encryption Status")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.primary)

                    Spacer()

                    Button("Details") {
                        showingDetails = true
                        HapticManager.HapticType.light.trigger()
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(DesignSystem.Colors.accent)
                }

                // Encryption Progress
                EncryptionProgressView(status: securityVault.encryptionStatus)

                // Quick Stats
                HStack(spacing: 20) {
                    EncryptionStat(
                        title: "Algorithm",
                        value: "AES-256-GCM",
                        icon: "key.fill"
                    )

                    Divider()

                    EncryptionStat(
                        title: "Key Storage",
                        value: "Secure Enclave",
                        icon: "cpu.fill"
                    )

                    Divider()

                    EncryptionStat(
                        title: "Status",
                        value: encryptionStatusText,
                        icon: "checkmark.shield.fill"
                    )
                }
            }
            .padding()
        }
    }

    private var encryptionStatusText: String {
        switch securityVault.encryptionStatus {
        case .idle: return "Ready"
        case .encrypting: return "Encrypting"
        case .decrypting: return "Decrypting"
        case .syncing: return "Syncing"
        case .error: return "Error"
        }
    }
}

struct EncryptionProgressView: View {
    let status: SecurityVault.EncryptionStatus
    @State private var progress: Double = 0.0

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Encryption Activity")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)

                Spacer()

                if case .encrypting = status {
                    ProMotionLoadingView()
                        .scaleEffect(0.5)
                }
            }

            ProgressView(value: progress, total: 1.0)
                .progressViewStyle(LinearProgressViewStyle(tint: DesignSystem.Colors.accent))
                .animation(.easeInOut(duration: 0.3), value: progress)
        }
        .onAppear {
            updateProgress()
        }
        .onChange(of: status) { _ in
            updateProgress()
        }
    }

    private func updateProgress() {
        switch status {
        case .idle:
            progress = 1.0
        case .encrypting, .decrypting, .syncing:
            progress = 0.5
        case .error:
            progress = 0.0
        }
    }
}

struct EncryptionStat: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(DesignSystem.Colors.accent)

            VStack(spacing: 2) {
                Text(value)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)

                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Data Usage Card

struct DataUsageCard: View {
    @ObservedObject var privacyManager: PrivacyManager

    var body: some View {
        GlassCardView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Data Usage")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)

                VStack(spacing: 12) {
                    DataUsageRow(
                        title: "Photos Encrypted",
                        value: privacyManager.photosEncrypted,
                        total: privacyManager.totalPhotos,
                        color: .green
                    )

                    DataUsageRow(
                        title: "Cloud Synced",
                        value: privacyManager.cloudSynced,
                        total: privacyManager.totalPhotos,
                        color: .blue
                    )

                    DataUsageRow(
                        title: "Storage Used",
                        value: privacyManager.storageUsed,
                        total: privacyManager.totalStorage,
                        color: .purple,
                        formatter: .byteCount
                    )
                }
            }
            .padding()
        }
    }
}

struct DataUsageRow: View {
    let title: String
    let value: Int
    let total: Int
    let color: Color
    var formatter: NumberFormatter.Style = .decimal

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)

                Text(formattedValue)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            CircularProgressView(
                progress: Double(value) / Double(total),
                color: color,
                lineWidth: 3,
                size: 30
            )
        }
    }

    private var formattedValue: String {
        if formatter == .byteCount {
            let byteFormatter = ByteCountFormatter()
            return "\(byteFormatter.string(fromByteCount: Int64(value))) / \(byteFormatter.string(fromByteCount: Int64(total)))"
        } else {
            return "\(value) / \(total)"
        }
    }
}

// MARK: - Secure Sharing Card

struct SecureSharingCard: View {
    @Binding var showingSharing: Bool
    @State private var activeShares = 3

    var body: some View {
        GlassCardView {
            VStack(spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Secure Sharing")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.primary)

                        Text("\(activeShares) active shares")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button("Create Link") {
                        showingSharing = true
                        HapticManager.HapticType.light.trigger()
                    }
                    .buttonStyle(PremiumButtonStyle(.accent))
                }

                // Recent Shares Preview
                VStack(spacing: 8) {
                    ForEach(0..<min(activeShares, 3), id: \.self) { index in
                        SecureShareRow(
                            title: "Style Collection \(index + 1)",
                            expiresIn: "2 days",
                            views: Int.random(in: 1...10)
                        )
                    }
                }
            }
            .padding()
        }
    }
}

struct SecureShareRow: View {
    let title: String
    let expiresIn: String
    let views: Int

    var body: some View {
        HStack {
            Image(systemName: "link")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(DesignSystem.Colors.accent)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)

                Text("Expires in \(expiresIn) • \(views) views")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(action: {}) {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Privacy Timeline Card

struct PrivacyTimelineCard: View {
    private let events = [
        PrivacyEvent(title: "Data encrypted", time: "2 minutes ago", type: .encryption),
        PrivacyEvent(title: "Biometric unlock", time: "5 minutes ago", type: .biometric),
        PrivacyEvent(title: "Cloud sync", time: "1 hour ago", type: .sync),
        PrivacyEvent(title: "Duplicate removed", time: "2 hours ago", type: .cleanup)
    ]

    var body: some View {
        GlassCardView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Privacy Timeline")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)

                VStack(spacing: 12) {
                    ForEach(events, id: \.id) { event in
                        PrivacyEventRow(event: event)
                    }
                }
            }
            .padding()
        }
    }
}

struct PrivacyEvent: Identifiable {
    let id = UUID()
    let title: String
    let time: String
    let type: EventType

    enum EventType {
        case encryption, biometric, sync, cleanup

        var icon: String {
            switch self {
            case .encryption: return "lock.fill"
            case .biometric: return "faceid"
            case .sync: return "icloud.fill"
            case .cleanup: return "trash.fill"
            }
        }

        var color: Color {
            switch self {
            case .encryption: return .green
            case .biometric: return .blue
            case .sync: return .cyan
            case .cleanup: return .orange
            }
        }
    }
}

struct PrivacyEventRow: View {
    let event: PrivacyEvent

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: event.type.icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(event.type.color)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)

                Text(event.time)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }
}

// MARK: - Privacy Manager

@MainActor
class PrivacyManager: ObservableObject {
    @Published var photosEncrypted: Int = 42
    @Published var totalPhotos: Int = 58
    @Published var cloudSynced: Int = 35
    @Published var storageUsed: Int = 1_024_000_000 // 1GB
    @Published var totalStorage: Int = 2_048_000_000 // 2GB

    private var enabledTopics: Set<PrivacyTopic> = [
        .encryption, .biometrics, .cloudSync, .sharing
    ]

    func isEnabled(_ topic: PrivacyTopic) -> Bool {
        enabledTopics.contains(topic)
    }

    func toggle(_ topic: PrivacyTopic) {
        if enabledTopics.contains(topic) {
            enabledTopics.remove(topic)
        } else {
            enabledTopics.insert(topic)
        }
    }
}

// MARK: - Helper Views

struct CircularProgressView: View {
    let progress: Double
    let color: Color
    let lineWidth: CGFloat
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.2), lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.5), value: progress)
        }
        .frame(width: size, height: size)
    }
}

#Preview {
    PrivacyDashboard()
}