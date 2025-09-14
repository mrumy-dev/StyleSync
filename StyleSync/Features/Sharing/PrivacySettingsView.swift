import SwiftUI

struct PrivacySettingsView: View {
    @StateObject private var privacyManager = PrivacyManager.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Privacy Controls") {
                    Toggle("Automatic Face Blur", isOn: $privacyManager.autoBlurFaces)
                        .toggleStyle(SwitchToggleStyle(tint: .blue))

                    Toggle("Remove Location Data", isOn: $privacyManager.stripLocationData)
                        .toggleStyle(SwitchToggleStyle(tint: .blue))

                    Toggle("Strip Metadata", isOn: $privacyManager.stripMetadata)
                        .toggleStyle(SwitchToggleStyle(tint: .blue))
                }
                .listRowBackground(Color(.systemGray6))

                Section("Sharing Links") {
                    HStack {
                        Text("Default Link Expiry")
                        Spacer()
                        Menu {
                            ForEach(ShareLinkExpiry.allCases, id: \.self) { expiry in
                                Button(expiry.displayName) {
                                    privacyManager.defaultLinkExpiry = expiry
                                }
                            }
                        } label: {
                            Text(privacyManager.defaultLinkExpiry.displayName)
                                .foregroundColor(.blue)
                        }
                    }

                    Toggle("Private Links Only", isOn: $privacyManager.privateLinksOnly)
                        .toggleStyle(SwitchToggleStyle(tint: .blue))

                    Toggle("Require Access Code", isOn: $privacyManager.requireAccessCode)
                        .toggleStyle(SwitchToggleStyle(tint: .blue))
                }
                .listRowBackground(Color(.systemGray6))

                Section("Data Protection") {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Face Detection Accuracy")
                                .font(.subheadline)
                            Text("Higher accuracy may increase processing time")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Menu {
                            ForEach(FaceDetectionAccuracy.allCases, id: \.self) { accuracy in
                                Button(accuracy.displayName) {
                                    privacyManager.faceDetectionAccuracy = accuracy
                                }
                            }
                        } label: {
                            Text(privacyManager.faceDetectionAccuracy.displayName)
                                .foregroundColor(.blue)
                        }
                    }

                    HStack {
                        Text("Background Removal Quality")
                        Spacer()
                        Menu {
                            ForEach(BackgroundRemovalQuality.allCases, id: \.self) { quality in
                                Button(quality.displayName) {
                                    privacyManager.backgroundRemovalQuality = quality
                                }
                            }
                        } label: {
                            Text(privacyManager.backgroundRemovalQuality.displayName)
                                .foregroundColor(.blue)
                        }
                    }
                }
                .listRowBackground(Color(.systemGray6))

                Section("Active Share Links") {
                    if privacyManager.activeShareLinks.isEmpty {
                        Text("No active share links")
                            .foregroundColor(.secondary)
                            .font(.subheadline)
                    } else {
                        ForEach(privacyManager.activeShareLinks) { link in
                            ShareLinkRow(shareLink: link) {
                                privacyManager.revokeShareLink(link.id)
                            }
                        }
                    }
                }
                .listRowBackground(Color(.systemGray6))

                Section("Privacy Information") {
                    NavigationLink(destination: PrivacyInfoView()) {
                        Label("How We Protect Your Privacy", systemImage: "shield.checkered")
                    }

                    Button("Clear All Share Links") {
                        privacyManager.clearAllShareLinks()
                    }
                    .foregroundColor(.red)
                }
                .listRowBackground(Color(.systemGray6))
            }
            .navigationTitle("Privacy Settings")
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
}

struct ShareLinkRow: View {
    let shareLink: ShareLink
    let onRevoke: () -> Void

    private var timeRemaining: String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.day, .hour, .minute]
        formatter.unitsStyle = .abbreviated

        let timeInterval = shareLink.expiresAt.timeIntervalSince(Date())
        if timeInterval <= 0 {
            return "Expired"
        }

        return formatter.string(from: timeInterval) ?? "Unknown"
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(shareLink.title)
                    .font(.subheadline)
                    .fontWeight(.medium)

                HStack(spacing: 12) {
                    Label(timeRemaining, systemImage: "clock")
                        .font(.caption)
                        .foregroundColor(shareLink.isExpired ? .red : .secondary)

                    if shareLink.isPrivate {
                        Label("Private", systemImage: "lock")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }

                    Label("\(shareLink.viewCount) views", systemImage: "eye")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Menu {
                Button("Copy Link") {
                    UIPasteboard.general.string = shareLink.url.absoluteString
                }

                Button("Share") {
                    let activityVC = UIActivityViewController(
                        activityItems: [shareLink.url],
                        applicationActivities: nil
                    )

                    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                       let window = windowScene.windows.first {
                        window.rootViewController?.present(activityVC, animated: true)
                    }
                }

                Divider()

                Button("Revoke", role: .destructive) {
                    onRevoke()
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .foregroundColor(.blue)
            }
        }
        .padding(.vertical, 4)
    }
}

struct PrivacyInfoView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "face.dashed")
                                .foregroundColor(.blue)
                                .font(.title2)
                            Text("Face Detection & Blurring")
                                .font(.headline)
                                .fontWeight(.semibold)
                        }

                        Text("We use Apple's Vision framework to automatically detect and blur faces in your outfit photos. This processing happens entirely on your device - no face data is ever sent to our servers.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }

                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "location.slash")
                                .foregroundColor(.green)
                                .font(.title2)
                            Text("Location & Metadata Removal")
                                .font(.headline)
                                .fontWeight(.semibold)
                        }

                        Text("All location data, camera information, and other metadata is automatically stripped from photos before sharing. This includes GPS coordinates, device information, and timestamps.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }

                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "link.badge.plus")
                                .foregroundColor(.purple)
                                .font(.title2)
                            Text("Expiring Share Links")
                                .font(.headline)
                                .fontWeight(.semibold)
                        }

                        Text("Share links automatically expire after your chosen time period. You can revoke access at any time, and we provide detailed analytics on who accessed your shared content.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }

                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "shield.checkered")
                                .foregroundColor(.orange)
                                .font(.title2)
                            Text("Private by Default")
                                .font(.headline)
                                .fontWeight(.semibold)
                        }

                        Text("All sharing features are designed with privacy first. Your original photos remain on your device, and shared content is processed locally before being uploaded to secure, encrypted storage.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Text("Questions or Concerns?")
                        .font(.headline)
                        .fontWeight(.semibold)

                    Text("Contact us at privacy@stylesync.app for any privacy-related questions or to request data deletion.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
        }
        .navigationTitle("Privacy Information")
        .navigationBarTitleDisplayMode(.inline)
    }
}

@MainActor
class PrivacyManager: ObservableObject {
    static let shared = PrivacyManager()

    @Published var autoBlurFaces = true
    @Published var stripLocationData = true
    @Published var stripMetadata = true
    @Published var privateLinksOnly = false
    @Published var requireAccessCode = false
    @Published var defaultLinkExpiry: ShareLinkExpiry = .oneWeek
    @Published var faceDetectionAccuracy: FaceDetectionAccuracy = .balanced
    @Published var backgroundRemovalQuality: BackgroundRemovalQuality = .balanced
    @Published var activeShareLinks: [ShareLink] = []

    private init() {
        loadSettings()
    }

    func saveSettings() {
        UserDefaults.standard.set(autoBlurFaces, forKey: "privacy_auto_blur_faces")
        UserDefaults.standard.set(stripLocationData, forKey: "privacy_strip_location")
        UserDefaults.standard.set(stripMetadata, forKey: "privacy_strip_metadata")
        UserDefaults.standard.set(privateLinksOnly, forKey: "privacy_private_links_only")
        UserDefaults.standard.set(requireAccessCode, forKey: "privacy_require_access_code")
        UserDefaults.standard.set(defaultLinkExpiry.rawValue, forKey: "privacy_default_link_expiry")
        UserDefaults.standard.set(faceDetectionAccuracy.rawValue, forKey: "privacy_face_detection_accuracy")
        UserDefaults.standard.set(backgroundRemovalQuality.rawValue, forKey: "privacy_background_removal_quality")

        saveActiveShareLinks()
    }

    private func loadSettings() {
        autoBlurFaces = UserDefaults.standard.bool(forKey: "privacy_auto_blur_faces")
        stripLocationData = UserDefaults.standard.bool(forKey: "privacy_strip_location")
        stripMetadata = UserDefaults.standard.bool(forKey: "privacy_strip_metadata")
        privateLinksOnly = UserDefaults.standard.bool(forKey: "privacy_private_links_only")
        requireAccessCode = UserDefaults.standard.bool(forKey: "privacy_require_access_code")

        if let expiryRaw = UserDefaults.standard.object(forKey: "privacy_default_link_expiry") as? String,
           let expiry = ShareLinkExpiry(rawValue: expiryRaw) {
            defaultLinkExpiry = expiry
        }

        if let accuracyRaw = UserDefaults.standard.object(forKey: "privacy_face_detection_accuracy") as? String,
           let accuracy = FaceDetectionAccuracy(rawValue: accuracyRaw) {
            faceDetectionAccuracy = accuracy
        }

        if let qualityRaw = UserDefaults.standard.object(forKey: "privacy_background_removal_quality") as? String,
           let quality = BackgroundRemovalQuality(rawValue: qualityRaw) {
            backgroundRemovalQuality = quality
        }

        loadActiveShareLinks()
    }

    func revokeShareLink(_ linkId: String) {
        activeShareLinks.removeAll { $0.id == linkId }
        saveActiveShareLinks()

        Task {
            await ShareURLManager.shared.revokeLink(linkId)
        }
    }

    func clearAllShareLinks() {
        let linkIds = activeShareLinks.map { $0.id }
        activeShareLinks.removeAll()
        saveActiveShareLinks()

        Task {
            for linkId in linkIds {
                await ShareURLManager.shared.revokeLink(linkId)
            }
        }
    }

    private func saveActiveShareLinks() {
        if let data = try? JSONEncoder().encode(activeShareLinks) {
            UserDefaults.standard.set(data, forKey: "privacy_active_share_links")
        }
    }

    private func loadActiveShareLinks() {
        if let data = UserDefaults.standard.data(forKey: "privacy_active_share_links"),
           let links = try? JSONDecoder().decode([ShareLink].self, from: data) {
            activeShareLinks = links.filter { !$0.isExpired }
        }
    }

    func addShareLink(_ shareLink: ShareLink) {
        activeShareLinks.append(shareLink)
        saveActiveShareLinks()
    }
}

enum ShareLinkExpiry: String, CaseIterable, Codable {
    case oneHour = "1h"
    case sixHours = "6h"
    case oneDay = "1d"
    case oneWeek = "1w"
    case oneMonth = "1m"
    case never = "never"

    var displayName: String {
        switch self {
        case .oneHour: return "1 Hour"
        case .sixHours: return "6 Hours"
        case .oneDay: return "1 Day"
        case .oneWeek: return "1 Week"
        case .oneMonth: return "1 Month"
        case .never: return "Never"
        }
    }

    var timeInterval: TimeInterval? {
        switch self {
        case .oneHour: return 3600
        case .sixHours: return 21600
        case .oneDay: return 86400
        case .oneWeek: return 604800
        case .oneMonth: return 2592000
        case .never: return nil
        }
    }
}

enum FaceDetectionAccuracy: String, CaseIterable, Codable {
    case fast = "fast"
    case balanced = "balanced"
    case precise = "precise"

    var displayName: String {
        switch self {
        case .fast: return "Fast"
        case .balanced: return "Balanced"
        case .precise: return "Precise"
        }
    }
}

enum BackgroundRemovalQuality: String, CaseIterable, Codable {
    case fast = "fast"
    case balanced = "balanced"
    case highQuality = "high"

    var displayName: String {
        switch self {
        case .fast: return "Fast"
        case .balanced: return "Balanced"
        case .highQuality: return "High Quality"
        }
    }
}

#Preview {
    PrivacySettingsView()
}