import UIKit
import CoreText

@MainActor
class MagazineLayoutGenerator: ObservableObject {
    private let imageProcessor = ImageProcessor()

    func createInstagramStoryLayout(content: ShareContent, images: [ProcessedImage]) async -> UIImage {
        let canvasSize = CGSize(width: 1080, height: 1920) // 9:16 ratio
        let renderer = UIGraphicsImageRenderer(size: canvasSize)

        return renderer.image { context in
            // Gradient background
            drawGradientBackground(context: context.cgContext, size: canvasSize, style: .vibrant)

            // Main outfit image
            if let firstImage = images.first {
                let imageRect = CGRect(x: 100, y: 200, width: 880, height: 1100)
                drawRoundedImage(firstImage.processed, in: imageRect, context: context.cgContext, cornerRadius: 30)
            }

            // Style quote overlay
            if let quote = generateStyleQuote(for: content) {
                drawQuoteOverlay(quote, in: context.cgContext, canvasSize: canvasSize, style: .story)
            }

            // Bottom info panel
            drawInfoPanel(content: content, in: context.cgContext, rect: CGRect(x: 0, y: 1400, width: 1080, height: 520))

            // Branding
            drawBranding(in: context.cgContext, position: CGPoint(x: 50, y: 100), style: .light)
        }
    }

    func createInstagramPostLayout(content: ShareContent, images: [ProcessedImage]) async -> UIImage {
        let canvasSize = CGSize(width: 1080, height: 1080) // 1:1 ratio
        let renderer = UIGraphicsImageRenderer(size: canvasSize)

        return renderer.image { context in
            // Clean white background
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: canvasSize))

            // Create collage layout
            switch images.count {
            case 1:
                drawSingleImageLayout(images[0], context: context.cgContext, canvasSize: canvasSize, content: content)
            case 2:
                drawDoubleImageLayout(Array(images.prefix(2)), context: context.cgContext, canvasSize: canvasSize)
            case 3:
                drawTripleImageLayout(Array(images.prefix(3)), context: context.cgContext, canvasSize: canvasSize)
            default:
                drawQuadLayout(Array(images.prefix(4)), context: context.cgContext, canvasSize: canvasSize)
            }

            // Add title and description
            if let title = content.title {
                drawTitle(title, in: context.cgContext, rect: CGRect(x: 40, y: 900, width: 1000, height: 60))
            }

            // Style tags
            if !content.styleNotes.isEmpty {
                drawStyleTags(content.styleNotes, in: context.cgContext, startY: 970, width: 1000)
            }
        }
    }

    func createPinterestLayout(content: ShareContent, images: [ProcessedImage]) async -> UIImage {
        let canvasSize = CGSize(width: 1000, height: 1500) // 2:3 ratio
        let renderer = UIGraphicsImageRenderer(size: canvasSize)

        return renderer.image { context in
            // Pinterest-style background
            UIColor.systemBackground.setFill()
            context.fill(CGRect(origin: .zero, size: canvasSize))

            // Main image with shadow
            if let mainImage = images.first {
                let imageRect = CGRect(x: 50, y: 100, width: 900, height: 900)
                drawImageWithShadow(mainImage.processed, in: imageRect, context: context.cgContext)
            }

            // Pinterest-style info card
            drawPinterestInfoCard(
                content: content,
                in: context.cgContext,
                rect: CGRect(x: 50, y: 1050, width: 900, height: 400)
            )

            // Subtle watermark
            drawBranding(in: context.cgContext, position: CGPoint(x: 50, y: 50), style: .subtle)
        }
    }

    func createOutfitCollage(content: ShareContent, images: [ProcessedImage]) async -> UIImage {
        let canvasSize = CGSize(width: 1080, height: 1350) // 4:5 ratio
        let renderer = UIGraphicsImageRenderer(size: canvasSize)

        return renderer.image { context in
            // Modern gradient background
            drawGradientBackground(context: context.cgContext, size: canvasSize, style: .modern)

            // Dynamic grid layout
            drawDynamicGrid(images, context: context.cgContext, canvasSize: canvasSize)

            // Outfit details sidebar
            drawOutfitDetailsSidebar(content: content, in: context.cgContext, canvasSize: canvasSize)

            // Color palette strip
            if !content.colors.isEmpty {
                drawColorPalette(content.colors, in: context.cgContext, rect: CGRect(x: 0, y: 1250, width: 1080, height: 100))
            }
        }
    }

    func createMagazineSpread(content: ShareContent, images: [ProcessedImage]) async -> UIImage {
        let canvasSize = CGSize(width: 1920, height: 1080) // 16:9 ratio
        let renderer = UIGraphicsImageRenderer(size: canvasSize)

        return renderer.image { context in
            // Magazine paper background
            drawPaperTexture(context: context.cgContext, size: canvasSize)

            // Left page - main image
            if let heroImage = images.first {
                let leftPageRect = CGRect(x: 100, y: 100, width: 860, height: 880)
                drawMagazineImage(heroImage.processed, in: leftPageRect, context: context.cgContext)
            }

            // Right page - content
            drawMagazineContent(content: content, images: Array(images.dropFirst().prefix(3)),
                              context: context.cgContext, pageRect: CGRect(x: 960, y: 100, width: 860, height: 880))

            // Magazine header
            drawMagazineHeader(in: context.cgContext, width: 1920)

            // Page number
            drawPageNumber(in: context.cgContext, position: CGPoint(x: 1800, y: 1000))
        }
    }

    func createStyleReport(content: ShareContent, images: [ProcessedImage]) async -> UIImage {
        let canvasSize = CGSize(width: 2480, height: 3508) // A4 300dpi
        let renderer = UIGraphicsImageRenderer(size: canvasSize)

        return renderer.image { context in
            // Professional document background
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: canvasSize))

            // Header section
            drawReportHeader(content: content, in: context.cgContext, canvasSize: canvasSize)

            // Executive summary
            drawExecutiveSummary(content: content, in: context.cgContext,
                                rect: CGRect(x: 200, y: 600, width: 2080, height: 400))

            // Image gallery
            drawReportImageGallery(images, context: context.cgContext,
                                 rect: CGRect(x: 200, y: 1100, width: 2080, height: 800))

            // Style analysis
            drawStyleAnalysis(content: content, in: context.cgContext,
                            rect: CGRect(x: 200, y: 2000, width: 2080, height: 800))

            // Recommendations
            drawRecommendations(content: content, in: context.cgContext,
                              rect: CGRect(x: 200, y: 2900, width: 2080, height: 400))

            // Footer
            drawReportFooter(in: context.cgContext, canvasSize: canvasSize)
        }
    }

    // MARK: - Drawing Helpers

    private func drawGradientBackground(context: CGContext, size: CGSize, style: GradientStyle) {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let colors: [CGColor]

        switch style {
        case .vibrant:
            colors = [
                UIColor.systemPurple.withAlphaComponent(0.8).cgColor,
                UIColor.systemPink.withAlphaComponent(0.6).cgColor,
                UIColor.systemBlue.withAlphaComponent(0.4).cgColor
            ]
        case .modern:
            colors = [
                UIColor.systemGray6.cgColor,
                UIColor.white.cgColor,
                UIColor.systemGray6.cgColor
            ]
        case .magazine:
            colors = [
                UIColor(red: 0.95, green: 0.95, blue: 0.97, alpha: 1.0).cgColor,
                UIColor.white.cgColor
            ]
        }

        let locations: [CGFloat] = Array(stride(from: 0.0, through: 1.0, by: 1.0 / Double(colors.count - 1)))

        if let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: locations) {
            context.drawLinearGradient(
                gradient,
                start: CGPoint(x: 0, y: 0),
                end: CGPoint(x: 0, y: size.height),
                options: []
            )
        }
    }

    private func drawRoundedImage(_ image: UIImage, in rect: CGRect, context: CGContext, cornerRadius: CGFloat) {
        context.saveGState()

        let path = UIBezierPath(roundedRect: rect, cornerRadius: cornerRadius)
        path.addClip()

        if let cgImage = image.cgImage {
            context.draw(cgImage, in: rect)
        }

        context.restoreGState()
    }

    private func drawQuoteOverlay(_ quote: String, in context: CGContext, canvasSize: CGSize, style: QuoteStyle) {
        let rect: CGRect
        let font: UIFont
        let color: UIColor

        switch style {
        case .story:
            rect = CGRect(x: 100, y: 300, width: 880, height: 200)
            font = UIFont.systemFont(ofSize: 48, weight: .light)
            color = .white
        case .post:
            rect = CGRect(x: 40, y: 40, width: 1000, height: 120)
            font = UIFont.systemFont(ofSize: 32, weight: .medium)
            color = .darkGray
        }

        // Semi-transparent background
        context.setFillColor(UIColor.black.withAlphaComponent(0.3).cgColor)
        context.fillEllipse(in: rect.insetBy(dx: -20, dy: -10))

        // Draw quote text
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: {
                let style = NSMutableParagraphStyle()
                style.alignment = .center
                style.lineSpacing = 8
                return style
            }()
        ]

        let attributedQuote = NSAttributedString(string: quote, attributes: attributes)
        attributedQuote.draw(in: rect)
    }

    private func drawInfoPanel(content: ShareContent, in context: CGContext, rect: CGRect) {
        // Semi-transparent background
        context.setFillColor(UIColor.black.withAlphaComponent(0.7).cgColor)
        context.fill(rect)

        let margin: CGFloat = 40
        var currentY = rect.minY + margin

        // Title
        if let title = content.title {
            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 36, weight: .bold),
                .foregroundColor: UIColor.white
            ]
            let attributedTitle = NSAttributedString(string: title, attributes: titleAttributes)
            let titleRect = CGRect(x: rect.minX + margin, y: currentY, width: rect.width - margin * 2, height: 50)
            attributedTitle.draw(in: titleRect)
            currentY += 70
        }

        // Description
        if let description = content.description {
            let descAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 24, weight: .regular),
                .foregroundColor: UIColor.white.withAlphaComponent(0.9)
            ]
            let attributedDesc = NSAttributedString(string: description, attributes: descAttributes)
            let descRect = CGRect(x: rect.minX + margin, y: currentY, width: rect.width - margin * 2, height: 100)
            attributedDesc.draw(in: descRect)
            currentY += 120
        }

        // Style notes as tags
        if !content.styleNotes.isEmpty {
            drawStyleTags(content.styleNotes, in: context, startY: currentY, width: Int(rect.width - margin * 2),
                         textColor: .white, backgroundColor: UIColor.white.withAlphaComponent(0.2))
        }
    }

    private func drawBranding(in context: CGContext, position: CGPoint, style: BrandingStyle) {
        let text = "StyleSync"
        let font: UIFont
        let color: UIColor

        switch style {
        case .light:
            font = UIFont.systemFont(ofSize: 24, weight: .light)
            color = .white.withAlphaComponent(0.8)
        case .dark:
            font = UIFont.systemFont(ofSize: 24, weight: .medium)
            color = .black.withAlphaComponent(0.7)
        case .subtle:
            font = UIFont.systemFont(ofSize: 18, weight: .light)
            color = .gray
        }

        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color
        ]

        let attributedText = NSAttributedString(string: text, attributes: attributes)
        attributedText.draw(at: position)
    }

    private func drawSingleImageLayout(_ image: ProcessedImage, context: CGContext, canvasSize: CGSize, content: ShareContent) {
        // Center the image with margins
        let margin: CGFloat = 60
        let imageRect = CGRect(
            x: margin,
            y: margin,
            width: canvasSize.width - margin * 2,
            height: canvasSize.height - 200
        )

        drawRoundedImage(image.processed, in: imageRect, context: context, cornerRadius: 20)

        // Add subtle shadow
        context.setShadow(offset: CGSize(width: 0, height: 10), blur: 20, color: UIColor.black.withAlphaComponent(0.2).cgColor)
    }

    private func drawStyleTags(_ tags: [String], in context: CGContext, startY: CGFloat, width: Int,
                             textColor: UIColor = .white, backgroundColor: UIColor = UIColor.blue.withAlphaComponent(0.8)) {
        let tagFont = UIFont.systemFont(ofSize: 18, weight: .medium)
        let tagHeight: CGFloat = 36
        let tagSpacing: CGFloat = 12
        let lineSpacing: CGFloat = 12

        var currentX: CGFloat = 40
        var currentY = startY

        for tag in tags {
            let tagText = "  \(tag)  "
            let textSize = tagText.size(withAttributes: [.font: tagFont])
            let tagWidth = textSize.width + 20

            // Check if we need a new line
            if currentX + tagWidth > CGFloat(width - 40) {
                currentX = 40
                currentY += tagHeight + lineSpacing
            }

            // Draw tag background
            let tagRect = CGRect(x: currentX, y: currentY, width: tagWidth, height: tagHeight)
            context.setFillColor(backgroundColor.cgColor)
            context.fill(tagRect)

            // Draw tag text
            let textAttributes: [NSAttributedString.Key: Any] = [
                .font: tagFont,
                .foregroundColor: textColor
            ]
            let attributedText = NSAttributedString(string: tagText, attributes: textAttributes)
            attributedText.draw(in: tagRect)

            currentX += tagWidth + tagSpacing
        }
    }

    private func generateStyleQuote(for content: ShareContent) -> String? {
        let quotes = [
            "Style is a way to say who you are without having to speak.",
            "Fashion is what you buy, style is what you do with it.",
            "Elegance is the only beauty that never fades.",
            "Style is knowing who you are and what you want to say.",
            "Fashion fades, but style is eternal.",
            "Dress how you want to be addressed.",
            "Your outfit is your armor for the day ahead."
        ]

        return quotes.randomElement()
    }

    private func drawDoubleImageLayout(_ images: [ProcessedImage], context: CGContext, canvasSize: CGSize) {
        let spacing: CGFloat = 20
        let imageWidth = (canvasSize.width - spacing * 3) / 2
        let imageHeight = canvasSize.height - 200

        for (index, image) in images.enumerated() {
            let x = spacing + CGFloat(index) * (imageWidth + spacing)
            let rect = CGRect(x: x, y: spacing, width: imageWidth, height: imageHeight)
            drawRoundedImage(image.processed, in: rect, context: context, cornerRadius: 15)
        }
    }

    private func drawTripleImageLayout(_ images: [ProcessedImage], context: CGContext, canvasSize: CGSize) {
        let spacing: CGFloat = 15
        let mainImageWidth = canvasSize.width * 0.6
        let sideImageWidth = canvasSize.width * 0.35
        let imageHeight = (canvasSize.height - 200 - spacing) / 2

        // Main image (left, full height)
        let mainRect = CGRect(x: spacing, y: spacing, width: mainImageWidth, height: canvasSize.height - 200)
        drawRoundedImage(images[0].processed, in: mainRect, context: context, cornerRadius: 15)

        // Two smaller images (right, stacked)
        for i in 1..<3 {
            let y = spacing + CGFloat(i - 1) * (imageHeight + spacing)
            let rect = CGRect(x: mainImageWidth + spacing * 2, y: y, width: sideImageWidth, height: imageHeight)
            drawRoundedImage(images[i].processed, in: rect, context: context, cornerRadius: 10)
        }
    }

    private func drawQuadLayout(_ images: [ProcessedImage], context: CGContext, canvasSize: CGSize) {
        let spacing: CGFloat = 15
        let imageSize = (canvasSize.width - spacing * 3) / 2
        let availableHeight = canvasSize.height - 200

        for (index, image) in images.enumerated() {
            let row = index / 2
            let col = index % 2
            let x = spacing + CGFloat(col) * (imageSize + spacing)
            let y = spacing + CGFloat(row) * (imageSize + spacing)

            let rect = CGRect(x: x, y: y, width: imageSize, height: min(imageSize, availableHeight / 2 - spacing))
            drawRoundedImage(image.processed, in: rect, context: context, cornerRadius: 12)
        }
    }

    private func drawTitle(_ title: String, in context: CGContext, rect: CGRect) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 32, weight: .bold),
            .foregroundColor: UIColor.darkGray
        ]

        let attributedTitle = NSAttributedString(string: title, attributes: attributes)
        attributedTitle.draw(in: rect)
    }

    // Additional helper methods would continue here...
    // For brevity, I'm including the key structure and some representative implementations
}

// MARK: - Supporting Enums
enum GradientStyle {
    case vibrant
    case modern
    case magazine
}

enum QuoteStyle {
    case story
    case post
}

enum BrandingStyle {
    case light
    case dark
    case subtle
}

// MARK: - Additional drawing methods (abbreviated for space)
extension MagazineLayoutGenerator {
    private func drawImageWithShadow(_ image: UIImage, in rect: CGRect, context: CGContext) {
        context.setShadow(offset: CGSize(width: 0, height: 8), blur: 16, color: UIColor.black.withAlphaComponent(0.25).cgColor)
        drawRoundedImage(image, in: rect, context: context, cornerRadius: 12)
        context.setShadow(offset: .zero, blur: 0, color: nil)
    }

    private func drawPinterestInfoCard(content: ShareContent, in context: CGContext, rect: CGRect) {
        // Implementation for Pinterest-style info card
        context.setFillColor(UIColor.white.cgColor)
        context.fill(rect)

        // Add border
        context.setStrokeColor(UIColor.systemGray5.cgColor)
        context.setLineWidth(1)
        context.stroke(rect)
    }

    private func drawDynamicGrid(_ images: [ProcessedImage], context: CGContext, canvasSize: CGSize) {
        // Implementation for dynamic grid layout
    }

    private func drawOutfitDetailsSidebar(content: ShareContent, in context: CGContext, canvasSize: CGSize) {
        // Implementation for outfit details sidebar
    }

    private func drawColorPalette(_ colors: [String], in context: CGContext, rect: CGRect) {
        let colorWidth = rect.width / CGFloat(colors.count)

        for (index, colorName) in colors.enumerated() {
            let colorRect = CGRect(
                x: rect.minX + CGFloat(index) * colorWidth,
                y: rect.minY,
                width: colorWidth,
                height: rect.height
            )

            // Convert color name to UIColor (simplified)
            let color = UIColor(named: colorName) ?? UIColor.gray
            context.setFillColor(color.cgColor)
            context.fill(colorRect)
        }
    }

    // Magazine-specific methods
    private func drawPaperTexture(context: CGContext, size: CGSize) {
        UIColor(red: 0.98, green: 0.98, blue: 0.96, alpha: 1.0).setFill()
        context.fill(CGRect(origin: .zero, size: size))
    }

    private func drawMagazineImage(_ image: UIImage, in rect: CGRect, context: CGContext) {
        drawRoundedImage(image, in: rect, context: context, cornerRadius: 8)
    }

    private func drawMagazineContent(content: ShareContent, images: [ProcessedImage], context: CGContext, pageRect: CGRect) {
        // Implementation for magazine content layout
    }

    private func drawMagazineHeader(in context: CGContext, width: CGFloat) {
        let headerText = "STYLE SYNC MAGAZINE"
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 18, weight: .light),
            .foregroundColor: UIColor.darkGray,
            .kern: 2.0
        ]

        let attributedText = NSAttributedString(string: headerText, attributes: attributes)
        attributedText.draw(at: CGPoint(x: 100, y: 50))
    }

    private func drawPageNumber(in context: CGContext, position: CGPoint) {
        let pageText = "01"
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 14, weight: .light),
            .foregroundColor: UIColor.gray
        ]

        let attributedText = NSAttributedString(string: pageText, attributes: attributes)
        attributedText.draw(at: position)
    }

    // Report-specific methods
    private func drawReportHeader(content: ShareContent, in context: CGContext, canvasSize: CGSize) {
        // Professional report header with title and date
    }

    private func drawExecutiveSummary(content: ShareContent, in context: CGContext, rect: CGRect) {
        // Executive summary section
    }

    private func drawReportImageGallery(_ images: [ProcessedImage], context: CGContext, rect: CGRect) {
        // Grid layout for report images
    }

    private func drawStyleAnalysis(content: ShareContent, in context: CGContext, rect: CGRect) {
        // Style analysis charts and text
    }

    private func drawRecommendations(content: ShareContent, in context: CGContext, rect: CGRect) {
        // Recommendations section
    }

    private func drawReportFooter(in context: CGContext, canvasSize: CGSize) {
        // Professional footer with branding
    }
}

#Preview {
    struct MagazineLayoutPreview: View {
        @StateObject private var generator = MagazineLayoutGenerator()

        var body: some View {
            VStack {
                Text("Magazine Layout Generator")
                    .font(.headline)

                Button("Generate Sample Layout") {
                    Task {
                        let _ = await generator.createInstagramStoryLayout(
                            content: ShareContent(
                                images: [],
                                title: "Summer Style",
                                description: "Perfect for sunny days",
                                occasion: "Casual",
                                styleNotes: ["Comfortable", "Trendy"],
                                colors: ["Blue", "White"],
                                brands: ["Zara", "Nike"],
                                price: 120.0
                            ),
                            images: []
                        )
                    }
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
    }

    return MagazineLayoutPreview()
}