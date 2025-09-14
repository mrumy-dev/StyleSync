import SwiftUI

struct PrivacyTopicDetailView: View {
    let topic: PrivacyDashboard.PrivacyTopic
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    topicHeader

                    // Details based on topic
                    topicContent

                    // Controls
                    topicControls
                }
                .padding()
            }
            .navigationTitle(topic.rawValue)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var topicHeader: some View {
        GlassCardView {
            VStack(spacing: 16) {
                Image(systemName: topic.icon)
                    .font(.system(size: 50))
                    .foregroundStyle(topic.color)

                VStack(spacing: 8) {
                    Text(topic.rawValue)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.primary)

                    Text(topicDescription)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding()
        }
    }

    private var topicContent: some View {
        Group {
            switch topic {
            case .encryption:
                EncryptionDetailsView()
            case .biometrics:
                BiometricsDetailsView()
            case .cloudSync:
                CloudSyncDetailsView()
            case .analytics:
                AnalyticsDetailsView()
            case .sharing:
                SharingDetailsView()
            case .storage:
                StorageDetailsView()
            }
        }
    }

    private var topicControls: some View {
        GlassCardView {
            VStack(spacing: 16) {
                Text("Privacy Controls")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Topic-specific controls would go here
                Text("Advanced controls for \(topic.rawValue.lowercased()) privacy settings")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
    }

    private var topicDescription: String {
        switch topic {
        case .encryption:
            return "End-to-end encryption protects your data with military-grade security"
        case .biometrics:
            return "Biometric authentication keeps your style collection secure"
        case .cloudSync:
            return "Zero-knowledge cloud sync ensures your data remains private"
        case .analytics:
            return "Differential privacy protects your identity in usage analytics"
        case .sharing:
            return "Secure sharing with expiring links and access controls"
        case .storage:
            return "Local storage encryption and secure data management"
        }
    }
}

// MARK: - Topic Detail Views

struct EncryptionDetailsView: View {
    var body: some View {
        GlassCardView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Encryption Details")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)

                VStack(spacing: 12) {
                    DetailRow(title: "Algorithm", value: "AES-256-GCM")
                    DetailRow(title: "Key Storage", value: "Secure Enclave")
                    DetailRow(title: "Key Derivation", value: "PBKDF2")
                    DetailRow(title: "Salt Length", value: "256 bits")
                }
            }
            .padding()
        }
    }
}

struct BiometricsDetailsView: View {
    var body: some View {
        GlassCardView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Biometric Security")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)

                VStack(spacing: 12) {
                    DetailRow(title: "Type", value: SecurityVault.shared.biometricType.displayName)
                    DetailRow(title: "Fallback", value: "Device Passcode")
                    DetailRow(title: "Storage", value: "Secure Enclave")
                    DetailRow(title: "Local Processing", value: "Yes")
                }
            }
            .padding()
        }
    }
}

struct CloudSyncDetailsView: View {
    var body: some View {
        GlassCardView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Cloud Synchronization")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)

                VStack(spacing: 12) {
                    DetailRow(title: "Provider", value: "iCloud Private")
                    DetailRow(title: "Encryption", value: "End-to-End")
                    DetailRow(title: "Key Access", value: "Zero Knowledge")
                    DetailRow(title: "Data Residency", value: "User's Region")
                }
            }
            .padding()
        }
    }
}

struct AnalyticsDetailsView: View {
    var body: some View {
        GlassCardView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Privacy Analytics")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)

                VStack(spacing: 12) {
                    DetailRow(title: "Method", value: "Differential Privacy")
                    DetailRow(title: "Epsilon Value", value: "1.0")
                    DetailRow(title: "Data Processing", value: "On-Device")
                    DetailRow(title: "Identifiability", value: "Mathematically Impossible")
                }
            }
            .padding()
        }
    }
}

struct SharingDetailsView: View {
    var body: some View {
        GlassCardView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Secure Sharing")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)

                VStack(spacing: 12) {
                    DetailRow(title: "Link Encryption", value: "AES-256")
                    DetailRow(title: "Access Control", value: "Time-based")
                    DetailRow(title: "View Tracking", value: "Optional")
                    DetailRow(title: "Geographic Limits", value: "Available")
                }
            }
            .padding()
        }
    }
}

struct StorageDetailsView: View {
    var body: some View {
        GlassCardView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Local Storage")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)

                VStack(spacing: 12) {
                    DetailRow(title: "Database", value: "SQLite Encrypted")
                    DetailRow(title: "File System", value: "iOS Secure")
                    DetailRow(title: "Cache Protection", value: "Memory Encrypted")
                    DetailRow(title: "Backup Encryption", value: "iTunes/Finder")
                }
            }
            .padding()
        }
    }
}

struct DetailRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)

            Spacer()

            Text(value)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    PrivacyTopicDetailView(topic: .encryption)
}