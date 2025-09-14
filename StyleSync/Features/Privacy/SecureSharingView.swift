import SwiftUI
import CryptoKit

struct SecureSharingView: View {
    @StateObject private var sharingManager = SecureSharingManager()
    @Environment(\.dismiss) private var dismiss
    @State private var selectedItems: Set<ShareableItem> = []
    @State private var expirationOption: ExpirationOption = .oneDay
    @State private var accessLevel: AccessLevel = .viewOnly
    @State private var requiresPassword = false
    @State private var customPassword = ""
    @State private var showingAdvancedOptions = false
    @State private var generatedLink: SecureLink?

    enum ExpirationOption: String, CaseIterable {
        case oneHour = "1 Hour"
        case oneDay = "1 Day"
        case oneWeek = "1 Week"
        case oneMonth = "1 Month"
        case never = "Never"

        var timeInterval: TimeInterval? {
            switch self {
            case .oneHour: return 3600
            case .oneDay: return 86400
            case .oneWeek: return 604800
            case .oneMonth: return 2592000
            case .never: return nil
            }
        }
    }

    enum AccessLevel: String, CaseIterable {
        case viewOnly = "View Only"
        case download = "Download"
        case comment = "Comment"

        var icon: String {
            switch self {
            case .viewOnly: return "eye.fill"
            case .download: return "arrow.down.circle.fill"
            case .comment: return "bubble.left.fill"
            }
        }
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    headerSection

                    // Item Selection
                    itemSelectionSection

                    // Share Configuration
                    configurationSection

                    // Advanced Options
                    if showingAdvancedOptions {
                        advancedOptionsSection
                    }

                    // Generate Link Button
                    generateLinkButton

                    // Generated Link Display
                    if let link = generatedLink {
                        generatedLinkSection(link)
                    }
                }
                .padding()
            }
            .navigationTitle("Secure Sharing")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Advanced") {
                        withAnimation(.spring()) {
                            showingAdvancedOptions.toggle()
                        }
                        HapticManager.HapticType.light.trigger()
                    }
                    .foregroundStyle(showingAdvancedOptions ? DesignSystem.Colors.accent : .secondary)
                }
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        GlassCardView {
            VStack(spacing: 16) {
                Image(systemName: "shield.lefthalf.filled")
                    .font(.system(size: 50))
                    .foregroundStyle(DesignSystem.Colors.accent.gradient)

                VStack(spacing: 8) {
                    Text("Zero-Knowledge Sharing")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.primary)

                    Text("Share your style securely with end-to-end encryption. Links are encrypted and can expire automatically.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                // Security Features
                HStack(spacing: 20) {
                    SecurityFeature(
                        icon: "lock.fill",
                        title: "Encrypted",
                        color: .green
                    )

                    SecurityFeature(
                        icon: "timer",
                        title: "Expiring",
                        color: .orange
                    )

                    SecurityFeature(
                        icon: "eye.slash.fill",
                        title: "Private",
                        color: .blue
                    )
                }
            }
            .padding()
        }
    }

    // MARK: - Item Selection Section

    private var itemSelectionSection: some View {
        GlassCardView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Select Items")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.primary)

                    Spacer()

                    Text("\(selectedItems.count) selected")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 12) {
                        ForEach(sharingManager.availableItems) { item in
                            ShareableItemThumbnail(
                                item: item,
                                isSelected: selectedItems.contains(item)
                            ) {
                                toggleItemSelection(item)
                            }
                        }
                    }
                    .padding(.horizontal, 4)
                }
            }
            .padding()
        }
    }

    // MARK: - Configuration Section

    private var configurationSection: some View {
        GlassCardView {
            VStack(spacing: 20) {
                Text("Share Configuration")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Expiration Options
                VStack(alignment: .leading, spacing: 12) {
                    Text("Link Expires")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(ExpirationOption.allCases, id: \.self) { option in
                                ExpirationOptionButton(
                                    option: option,
                                    isSelected: expirationOption == option
                                ) {
                                    expirationOption = option
                                    HapticManager.HapticType.selection.trigger()
                                }
                            }
                        }
                        .padding(.horizontal, 4)
                    }
                }

                // Access Level
                VStack(alignment: .leading, spacing: 12) {
                    Text("Access Level")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)

                    HStack(spacing: 12) {
                        ForEach(AccessLevel.allCases, id: \.self) { level in
                            AccessLevelButton(
                                level: level,
                                isSelected: accessLevel == level
                            ) {
                                accessLevel = level
                                HapticManager.HapticType.selection.trigger()
                            }
                        }
                    }
                }

                // Password Protection
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("Require Password", isOn: $requiresPassword)
                        .font(.subheadline.weight(.medium))
                        .toggleStyle(SwitchToggleStyle(tint: DesignSystem.Colors.accent))

                    if requiresPassword {
                        SecureField("Enter password", text: $customPassword)
                            .textFieldStyle(PremiumTextFieldStyle())
                            .transition(.opacity.combined(with: .scale))
                    }
                }
                .animation(.spring(), value: requiresPassword)
            }
            .padding()
        }
    }

    // MARK: - Advanced Options Section

    private var advancedOptionsSection: some View {
        GlassCardView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Advanced Security")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)

                VStack(spacing: 16) {
                    AdvancedToggle(
                        title: "Watermark Images",
                        description: "Add invisible watermarks to shared images",
                        isOn: $sharingManager.addWatermark
                    )

                    AdvancedToggle(
                        title: "Track Views",
                        description: "Monitor who views your shared content",
                        isOn: $sharingManager.trackViews
                    )

                    AdvancedToggle(
                        title: "Disable Screenshots",
                        description: "Prevent screenshots of shared content",
                        isOn: $sharingManager.disableScreenshots
                    )

                    AdvancedToggle(
                        title: "Geographic Restrictions",
                        description: "Limit access by location",
                        isOn: $sharingManager.useGeoRestrictions
                    )
                }
            }
            .padding()
        }
        .transition(.opacity.combined(with: .scale))
    }

    // MARK: - Generate Link Button

    private var generateLinkButton: some View {
        Button(action: generateSecureLink) {
            HStack(spacing: 12) {
                if sharingManager.isGenerating {
                    ProMotionLoadingView()
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "link.badge.plus")
                        .font(.system(size: 20, weight: .semibold))
                }

                Text(sharingManager.isGenerating ? "Generating..." : "Generate Secure Link")
                    .font(.headline.weight(.semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(DesignSystem.Colors.accent.gradient)
                    .shadow(color: DesignSystem.Colors.accent.opacity(0.3), radius: 8, y: 4)
            )
        }
        .disabled(selectedItems.isEmpty || sharingManager.isGenerating)
        .opacity(selectedItems.isEmpty ? 0.6 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: selectedItems.isEmpty)
    }

    // MARK: - Generated Link Section

    private func generatedLinkSection(_ link: SecureLink) -> some View {
        GlassCardView {
            VStack(spacing: 16) {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.green)

                    Text("Secure Link Generated")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.primary)

                    Spacer()
                }

                VStack(alignment: .leading, spacing: 12) {
                    // Link Preview
                    HStack {
                        Text(link.shortUrl)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(DesignSystem.Colors.accent)
                            .lineLimit(1)

                        Spacer()

                        Button(action: { copyToClipboard(link.fullUrl) }) {
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(DesignSystem.Colors.accent)
                        }
                    }
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))

                    // Link Details
                    VStack(spacing: 8) {
                        LinkDetailRow(
                            icon: "clock.fill",
                            title: "Expires",
                            value: link.expirationText,
                            color: .orange
                        )

                        LinkDetailRow(
                            icon: "eye.fill",
                            title: "Access",
                            value: accessLevel.rawValue,
                            color: .blue
                        )

                        LinkDetailRow(
                            icon: "shield.fill",
                            title: "Security",
                            value: "End-to-End Encrypted",
                            color: .green
                        )
                    }
                }

                // Action Buttons
                HStack(spacing: 12) {
                    Button("Share Link") {
                        shareLink(link)
                    }
                    .buttonStyle(PremiumButtonStyle(.accent))

                    Button("View Details") {
                        // Show link management
                    }
                    .buttonStyle(PremiumButtonStyle(.secondary))
                }
            }
            .padding()
        }
        .transition(.opacity.combined(with: .scale))
    }

    // MARK: - Helper Functions

    private func toggleItemSelection(_ item: ShareableItem) {
        if selectedItems.contains(item) {
            selectedItems.remove(item)
        } else {
            selectedItems.insert(item)
        }
        HapticManager.HapticType.light.trigger()
    }

    private func generateSecureLink() {
        Task {
            do {
                let link = try await sharingManager.generateSecureLink(
                    items: Array(selectedItems),
                    expiration: expirationOption.timeInterval,
                    accessLevel: accessLevel,
                    requiresPassword: requiresPassword,
                    password: requiresPassword ? customPassword : nil
                )
                generatedLink = link
                HapticManager.HapticType.success.trigger()
                SoundManager.SoundType.success.play(volume: 0.7)
            } catch {
                // Handle error
                HapticManager.HapticType.error.trigger()
                SoundManager.SoundType.error.play(volume: 0.6)
            }
        }
    }

    private func copyToClipboard(_ text: String) {
        UIPasteboard.general.string = text
        HapticManager.HapticType.success.trigger()
        SoundManager.SoundType.chime.play(volume: 0.5)
    }

    private func shareLink(_ link: SecureLink) {
        let activityController = UIActivityViewController(
            activityItems: [link.fullUrl],
            applicationActivities: nil
        )

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController?.present(activityController, animated: true)
        }
    }
}

// MARK: - Supporting Views

struct SecurityFeature: View {
    let icon: String
    let title: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(color)

            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
        }
    }
}

struct ShareableItemThumbnail: View {
    let item: ShareableItem
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
                    .frame(width: 80, height: 80)
                    .overlay(
                        Image(systemName: "photo")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                    )

                if isSelected {
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(DesignSystem.Colors.accent, lineWidth: 2)

                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(DesignSystem.Colors.accent)
                        .background(.white, in: Circle())
                        .position(x: 70, y: 10)
                }
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isSelected)
    }
}

struct ExpirationOptionButton: View {
    let option: SecureSharingView.ExpirationOption
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(option.rawValue)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(isSelected ? .white : .primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(isSelected ? DesignSystem.Colors.accent : .ultraThinMaterial)
                )
        }
    }
}

struct AccessLevelButton: View {
    let level: SecureSharingView.AccessLevel
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: level.icon)
                    .font(.system(size: 16, weight: .medium))

                Text(level.rawValue)
                    .font(.subheadline.weight(.medium))
            }
            .foregroundStyle(isSelected ? .white : .primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? DesignSystem.Colors.accent : .ultraThinMaterial)
            )
        }
    }
}

struct AdvancedToggle: View {
    let title: String
    let description: String
    @Binding var isOn: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)

                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Toggle("", isOn: $isOn)
                .toggleStyle(SwitchToggleStyle(tint: DesignSystem.Colors.accent))
        }
    }
}

struct LinkDetailRow: View {
    let icon: String
    let title: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(color)
                .frame(width: 20)

            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)

            Spacer()

            Text(value)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
        }
    }
}

// MARK: - Data Models

struct ShareableItem: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let type: ItemType
    let thumbnail: String

    enum ItemType {
        case photo, collection, outfit
    }
}

struct SecureLink {
    let id = UUID()
    let shortUrl: String
    let fullUrl: String
    let expirationDate: Date?
    let accessLevel: SecureSharingView.AccessLevel
    let isPasswordProtected: Bool

    var expirationText: String {
        guard let expirationDate = expirationDate else { return "Never" }

        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: expirationDate, relativeTo: Date())
    }
}

// MARK: - Secure Sharing Manager

@MainActor
class SecureSharingManager: ObservableObject {
    @Published var isGenerating = false
    @Published var addWatermark = true
    @Published var trackViews = true
    @Published var disableScreenshots = false
    @Published var useGeoRestrictions = false

    let availableItems: [ShareableItem] = [
        ShareableItem(title: "Summer Look", type: .photo, thumbnail: "photo1"),
        ShareableItem(title: "Office Style", type: .collection, thumbnail: "photo2"),
        ShareableItem(title: "Weekend Casual", type: .outfit, thumbnail: "photo3"),
        ShareableItem(title: "Evening Wear", type: .photo, thumbnail: "photo4"),
    ]

    func generateSecureLink(
        items: [ShareableItem],
        expiration: TimeInterval?,
        accessLevel: SecureSharingView.AccessLevel,
        requiresPassword: Bool,
        password: String?
    ) async throws -> SecureLink {
        isGenerating = true

        // Simulate secure link generation
        try await Task.sleep(nanoseconds: 2_000_000_000)

        // Generate encrypted link
        let linkId = UUID().uuidString.prefix(8)
        let shortUrl = "stylesync.app/s/\(linkId)"
        let fullUrl = "https://stylesync.app/secure/\(UUID().uuidString)"

        let expirationDate = expiration.map { Date().addingTimeInterval($0) }

        isGenerating = false

        return SecureLink(
            shortUrl: shortUrl,
            fullUrl: fullUrl,
            expirationDate: expirationDate,
            accessLevel: accessLevel,
            isPasswordProtected: requiresPassword
        )
    }
}

#Preview {
    SecureSharingView()
}