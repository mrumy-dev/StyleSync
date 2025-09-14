import SwiftUI
import Photos
import PDFKit
import Vision
import CoreImage
import CoreImage.CIFilterBuiltins

@MainActor
class ShareManager: ObservableObject {
    @Published var isGeneratingShare = false
    @Published var sharePreview: UIImage?
    @Published var shareError: ShareError?
    @Published var privacySettings = PrivacySettings()

    private let imageProcessor = ImageProcessor()
    private let layoutGenerator = MagazineLayoutGenerator()
    private let shareURLManager = ShareURLManager()

    func createShare(
        content: ShareContent,
        format: ShareFormat,
        privacy: PrivacySettings
    ) async -> ShareResult? {
        isGeneratingShare = true
        defer { isGeneratingShare = false }

        do {
            // Process images with privacy controls
            let processedImages = await processImages(content.images, privacy: privacy)

            // Generate layout
            let layoutImage = await generateLayout(
                content: content,
                images: processedImages,
                format: format
            )

            // Create share result
            let shareResult = ShareResult(
                image: layoutImage,
                format: format,
                shareURL: await generateShareURL(image: layoutImage, privacy: privacy),
                expirationDate: privacy.expiringLinks ? Calendar.current.date(byAdding: .day, value: privacy.linkExpirationDays, to: Date()) : nil
            )

            sharePreview = layoutImage
            return shareResult

        } catch {
            shareError = ShareError.processingFailed(error.localizedDescription)
            return nil
        }
    }

    private func processImages(_ images: [UIImage], privacy: PrivacySettings) async -> [ProcessedImage] {
        var processedImages: [ProcessedImage] = []

        for image in images {
            var processedImage = image

            // Face blur
            if privacy.automaticFaceBlur {
                processedImage = await imageProcessor.blurFaces(in: processedImage)
            }

            // Background removal
            if privacy.removeBackground {
                processedImage = await imageProcessor.removeBackground(from: processedImage)
            }

            // Metadata stripping (automatic)
            processedImage = imageProcessor.stripMetadata(from: processedImage)

            processedImages.append(ProcessedImage(
                original: image,
                processed: processedImage,
                hasModifications: privacy.automaticFaceBlur || privacy.removeBackground
            ))
        }

        return processedImages
    }

    private func generateLayout(
        content: ShareContent,
        images: [ProcessedImage],
        format: ShareFormat
    ) async -> UIImage {
        switch format {
        case .instagramStory:
            return await layoutGenerator.createInstagramStoryLayout(content: content, images: images)
        case .instagramPost:
            return await layoutGenerator.createInstagramPostLayout(content: content, images: images)
        case .pinterestBoard:
            return await layoutGenerator.createPinterestLayout(content: content, images: images)
        case .outfitCollage:
            return await layoutGenerator.createOutfitCollage(content: content, images: images)
        case .magazineSpread:
            return await layoutGenerator.createMagazineSpread(content: content, images: images)
        case .styleReport:
            return await layoutGenerator.createStyleReport(content: content, images: images)
        }
    }

    private func generateShareURL(image: UIImage, privacy: PrivacySettings) async -> URL? {
        guard privacy.enableShareURLs else { return nil }

        return await shareURLManager.createShareURL(
            for: image,
            expiresAfter: privacy.expiringLinks ? privacy.linkExpirationDays : nil,
            requiresPassword: privacy.passwordProtectedLinks
        )
    }
}

struct ShareView: View {
    let content: ShareContent
    @StateObject private var shareManager = ShareManager()
    @StateObject private var premiumManager = PremiumManager()
    @Environment(\.dismiss) private var dismiss

    @State private var selectedFormat: ShareFormat = .outfitCollage
    @State private var showingPrivacySettings = false
    @State private var showingFormatSelection = false
    @State private var generatedShare: ShareResult?

    var body: some View {
        NavigationStack {
            VStack {
                if premiumManager.hasFeatureAccess(.magazineStyleExports) {
                    shareContent
                } else {
                    premiumPromptView
                }
            }
            .navigationTitle("Share Style")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    if premiumManager.hasFeatureAccess(.magazineStyleExports) {
                        Button("Privacy") {
                            showingPrivacySettings = true
                        }
                    }
                }
            }
            .sheet(isPresented: $showingPrivacySettings) {
                PrivacySettingsView(settings: $shareManager.privacySettings)
            }
            .sheet(isPresented: $showingFormatSelection) {
                FormatSelectionView(selectedFormat: $selectedFormat)
            }
        }
    }

    private var shareContent: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Preview section
                sharePreviewSection

                // Format selection
                formatSelectionSection

                // Style customization
                styleCustomizationSection

                // Privacy summary
                privacySummarySection

                // Generate and share buttons
                actionButtonsSection
            }
            .padding()
        }
    }

    private var premiumPromptView: some View {
        VStack(spacing: 24) {
            Image(systemName: "photo.stack.fill")
                .font(.system(size: 60))
                .foregroundColor(.purple)

            VStack(spacing: 16) {
                Text("Premium Sharing")
                    .font(.title)
                    .fontWeight(.bold)

                Text("Create beautiful magazine-style layouts and share your outfits with privacy-first controls.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            VStack(spacing: 12) {
                FeatureHighlight(icon: "doc.richtext.fill", title: "Magazine Layouts", description: "Professional-quality outfit spreads")
                FeatureHighlight(icon: "person.crop.circle.badge.xmark", title: "Privacy Controls", description: "Automatic face blur and metadata removal")
                FeatureHighlight(icon: "square.and.arrow.up.fill", title: "Multiple Formats", description: "Instagram, Pinterest, PDF exports")
                FeatureHighlight(icon: "link.circle.fill", title: "Secure Sharing", description: "Expiring links with password protection")
            }
            .padding(.horizontal)

            Button("Upgrade to Premium") {
                // Show paywall
            }
            .buttonStyle(PremiumButtonStyle())
        }
        .padding()
    }

    private var sharePreviewSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Preview")
                .font(.headline)
                .fontWeight(.medium)

            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemGray6))
                    .frame(height: 300)

                if shareManager.isGeneratingShare {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.2)

                        Text("Creating your share...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                } else if let preview = shareManager.sharePreview {
                    Image(uiImage: preview)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "photo.badge.plus")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary)

                        Text("Preview will appear here")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }

    private var formatSelectionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Share Format")
                .font(.headline)
                .fontWeight(.medium)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(ShareFormat.allCases, id: \.self) { format in
                        FormatCard(
                            format: format,
                            isSelected: selectedFormat == format
                        ) {
                            selectedFormat = format
                            Task {
                                await generatePreview()
                            }
                        }
                    }
                }
                .padding(.horizontal)
            }
            .padding(.horizontal, -16)
        }
    }

    private var styleCustomizationSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Style Options")
                .font(.headline)
                .fontWeight(.medium)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                StyleOptionCard(
                    icon: "quote.bubble.fill",
                    title: "Add Quote",
                    description: "Include style inspiration",
                    isEnabled: true
                ) {
                    // Toggle quote
                }

                StyleOptionCard(
                    icon: "seal.fill",
                    title: "Watermark",
                    description: "StyleSync branding",
                    isEnabled: false
                ) {
                    // Toggle watermark
                }

                StyleOptionCard(
                    icon: "paintbrush.fill",
                    title: "Color Theme",
                    description: "Match your style",
                    isEnabled: true
                ) {
                    // Choose color theme
                }

                StyleOptionCard(
                    icon: "textformat.size",
                    title: "Typography",
                    description: "Font style selection",
                    isEnabled: true
                ) {
                    // Choose typography
                }
            }
        }
    }

    private var privacySummarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Privacy Protection")
                    .font(.headline)
                    .fontWeight(.medium)

                Spacer()

                Button("Settings") {
                    showingPrivacySettings = true
                }
                .font(.caption)
                .buttonStyle(.bordered)
            }

            VStack(alignment: .leading, spacing: 8) {
                PrivacyIndicator(
                    icon: "person.crop.circle.badge.xmark",
                    title: "Face Blur",
                    isEnabled: shareManager.privacySettings.automaticFaceBlur
                )

                PrivacyIndicator(
                    icon: "location.slash",
                    title: "Location Removal",
                    isEnabled: shareManager.privacySettings.removeLocation
                )

                PrivacyIndicator(
                    icon: "doc.badge.minus",
                    title: "Metadata Stripped",
                    isEnabled: true // Always enabled
                )

                if shareManager.privacySettings.expiringLinks {
                    PrivacyIndicator(
                        icon: "clock.badge.xmark",
                        title: "Expiring Links (\(shareManager.privacySettings.linkExpirationDays)d)",
                        isEnabled: true
                    )
                }
            }
        }
        .padding(16)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var actionButtonsSection: some View {
        VStack(spacing: 12) {
            Button("Generate Share") {
                Task {
                    await generateShare()
                }
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(Color.blue)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .disabled(shareManager.isGeneratingShare)

            if let shareResult = generatedShare {
                shareActionsView(shareResult)
            }
        }
    }

    private func shareActionsView(_ shareResult: ShareResult) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 16) {
                ShareActionButton(
                    icon: "square.and.arrow.up",
                    title: "Share",
                    action: {
                        shareToSystem(shareResult)
                    }
                )

                ShareActionButton(
                    icon: "square.and.arrow.down",
                    title: "Save",
                    action: {
                        saveToPhotos(shareResult.image)
                    }
                )

                if let shareURL = shareResult.shareURL {
                    ShareActionButton(
                        icon: "link",
                        title: "Copy Link",
                        action: {
                            copyLink(shareURL)
                        }
                    )
                }

                ShareActionButton(
                    icon: "doc.pdf",
                    title: "PDF",
                    action: {
                        exportToPDF(shareResult)
                    }
                )
            }

            if let expirationDate = shareResult.expirationDate {
                Text("Link expires \(expirationDate, style: .relative)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    private func generatePreview() async {
        _ = await shareManager.createShare(
            content: content,
            format: selectedFormat,
            privacy: shareManager.privacySettings
        )
    }

    private func generateShare() async {
        generatedShare = await shareManager.createShare(
            content: content,
            format: selectedFormat,
            privacy: shareManager.privacySettings
        )
    }

    private func shareToSystem(_ shareResult: ShareResult) {
        let activityViewController = UIActivityViewController(
            activityItems: [shareResult.image],
            applicationActivities: nil
        )

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.present(activityViewController, animated: true)
        }
    }

    private func saveToPhotos(_ image: UIImage) {
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            if status == .authorized {
                UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
            }
        }
    }

    private func copyLink(_ url: URL) {
        UIPasteboard.general.url = url
    }

    private func exportToPDF(_ shareResult: ShareResult) {
        // Implementation for PDF export
    }
}

struct FormatCard: View {
    let format: ShareFormat
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGray6))
                        .frame(width: 80, height: 100)

                    // Format preview
                    formatPreview
                }

                VStack(spacing: 4) {
                    Text(format.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Text(format.dimensions)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 100)
            .padding(12)
            .background(isSelected ? Color.blue.opacity(0.1) : Color.clear)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var formatPreview: some View {
        Group {
            switch format {
            case .instagramStory:
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.purple)
                    .frame(width: 30, height: 60)
            case .instagramPost:
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.pink)
                    .frame(width: 50, height: 50)
            case .pinterestBoard:
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.red)
                    .frame(width: 40, height: 60)
            case .outfitCollage:
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 2), spacing: 2) {
                    ForEach(0..<4, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.blue)
                            .frame(width: 18, height: 18)
                    }
                }
            case .magazineSpread:
                HStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.orange)
                        .frame(width: 35, height: 50)
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.yellow)
                        .frame(width: 35, height: 50)
                }
            case .styleReport:
                VStack(spacing: 2) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.green)
                        .frame(width: 50, height: 15)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.mint)
                        .frame(width: 40, height: 10)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.teal)
                        .frame(width: 45, height: 10)
                }
            }
        }
    }
}

struct StyleOptionCard: View {
    let icon: String
    let title: String
    let description: String
    let isEnabled: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(isEnabled ? .blue : .secondary)

                VStack(spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)

                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 80)
            .background(isEnabled ? Color.blue.opacity(0.1) : Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct PrivacyIndicator: View {
    let icon: String
    let title: String
    let isEnabled: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundColor(isEnabled ? .green : .secondary)

            Text(title)
                .font(.subheadline)
                .foregroundColor(isEnabled ? .primary : .secondary)

            Spacer()

            if isEnabled {
                Image(systemName: "checkmark.circle.fill")
                    .font(.subheadline)
                    .foregroundColor(.green)
            } else {
                Image(systemName: "circle")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct ShareActionButton: View {
    let icon: String
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.title3)

                Text(title)
                    .font(.caption)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 60)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct FeatureHighlight: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.purple)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
    }
}

// MARK: - Supporting Models
struct ShareContent {
    let images: [UIImage]
    let title: String?
    let description: String?
    let occasion: String?
    let styleNotes: [String]
    let colors: [String]
    let brands: [String]
    let price: Double?
}

enum ShareFormat: CaseIterable {
    case instagramStory
    case instagramPost
    case pinterestBoard
    case outfitCollage
    case magazineSpread
    case styleReport

    var displayName: String {
        switch self {
        case .instagramStory: return "IG Story"
        case .instagramPost: return "IG Post"
        case .pinterestBoard: return "Pinterest"
        case .outfitCollage: return "Collage"
        case .magazineSpread: return "Magazine"
        case .styleReport: return "Report"
        }
    }

    var dimensions: String {
        switch self {
        case .instagramStory: return "9:16"
        case .instagramPost: return "1:1"
        case .pinterestBoard: return "2:3"
        case .outfitCollage: return "4:5"
        case .magazineSpread: return "16:9"
        case .styleReport: return "A4"
        }
    }
}

struct ProcessedImage {
    let original: UIImage
    let processed: UIImage
    let hasModifications: Bool
}

struct ShareResult {
    let image: UIImage
    let format: ShareFormat
    let shareURL: URL?
    let expirationDate: Date?
}

struct PrivacySettings {
    var automaticFaceBlur: Bool = true
    var removeLocation: Bool = true
    var removeBackground: Bool = false
    var enableShareURLs: Bool = true
    var expiringLinks: Bool = true
    var linkExpirationDays: Int = 7
    var passwordProtectedLinks: Bool = false
}

enum ShareError: Error, LocalizedError {
    case processingFailed(String)
    case permissionDenied
    case networkError

    var errorDescription: String? {
        switch self {
        case .processingFailed(let message): return "Processing failed: \(message)"
        case .permissionDenied: return "Permission denied"
        case .networkError: return "Network error"
        }
    }
}

#Preview {
    ShareView(content: ShareContent(
        images: [],
        title: "Summer Casual Look",
        description: "Perfect for weekend brunch",
        occasion: "Casual",
        styleNotes: ["Comfortable", "Trendy", "Versatile"],
        colors: ["Navy", "White", "Denim"],
        brands: ["Zara", "Nike", "Levi's"],
        price: 180.50
    ))
}