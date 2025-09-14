import UIKit
import Vision
import CoreImage
import CoreImage.CIFilterBuiltins
import Photos

@MainActor
class ImageProcessor: ObservableObject {
    private let ciContext = CIContext()

    func blurFaces(in image: UIImage) async -> UIImage {
        guard let ciImage = CIImage(image: image) else { return image }

        do {
            // Detect faces using Vision framework
            let faceRectangles = try await detectFaces(in: ciImage)

            guard !faceRectangles.isEmpty else { return image }

            var processedImage = ciImage

            // Apply blur to each detected face
            for faceRect in faceRectangles {
                processedImage = blurRegion(in: processedImage, rect: faceRect)
            }

            // Convert back to UIImage
            if let cgImage = ciContext.createCGImage(processedImage, from: processedImage.extent) {
                return UIImage(cgImage: cgImage)
            }

        } catch {
            print("Face detection failed: \(error)")
        }

        return image
    }

    func removeBackground(from image: UIImage) async -> UIImage {
        guard let ciImage = CIImage(image: image) else { return image }

        do {
            // Use Vision to detect subject and create mask
            let maskImage = try await createSubjectMask(from: ciImage)

            // Apply mask to original image
            let maskedImage = applyMask(maskImage, to: ciImage)

            // Add transparent background or solid color
            let finalImage = addTransparentBackground(to: maskedImage)

            if let cgImage = ciContext.createCGImage(finalImage, from: finalImage.extent) {
                return UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
            }

        } catch {
            print("Background removal failed: \(error)")
        }

        return image
    }

    func stripMetadata(from image: UIImage) -> UIImage {
        // Create new image without metadata
        guard let cgImage = image.cgImage else { return image }

        let newImage = UIImage(
            cgImage: cgImage,
            scale: 1.0,
            orientation: .up
        )

        return newImage
    }

    func createOutfitCollage(images: [UIImage], layout: CollageLayout) async -> UIImage {
        let canvasSize = CGSize(width: 1080, height: 1350) // Instagram post ratio
        let renderer = UIGraphicsImageRenderer(size: canvasSize)

        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let collageImage = renderer.image { context in
                    // Fill background
                    UIColor.white.setFill()
                    context.fill(CGRect(origin: .zero, size: canvasSize))

                    // Draw images based on layout
                    switch layout {
                    case .grid2x2:
                        self.drawGrid2x2(images: images, in: context.cgContext, canvasSize: canvasSize)
                    case .grid3x3:
                        self.drawGrid3x3(images: images, in: context.cgContext, canvasSize: canvasSize)
                    case .magazine:
                        self.drawMagazineLayout(images: images, in: context.cgContext, canvasSize: canvasSize)
                    case .story:
                        self.drawStoryLayout(images: images, in: context.cgContext, canvasSize: canvasSize)
                    }
                }

                DispatchQueue.main.async {
                    continuation.resume(returning: collageImage)
                }
            }
        }
    }

    func addWatermark(to image: UIImage, text: String, position: WatermarkPosition) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: image.size)

        return renderer.image { context in
            // Draw original image
            image.draw(at: .zero)

            // Configure text attributes
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 24, weight: .medium),
                .foregroundColor: UIColor.white,
                .strokeColor: UIColor.black,
                .strokeWidth: -2.0
            ]

            let attributedText = NSAttributedString(string: text, attributes: attributes)
            let textSize = attributedText.size()

            // Calculate position
            let textPosition = calculateWatermarkPosition(
                textSize: textSize,
                imageSize: image.size,
                position: position
            )

            // Draw watermark with shadow
            let shadowOffset = CGSize(width: 1, height: 1)
            context.cgContext.setShadow(offset: shadowOffset, blur: 3, color: UIColor.black.cgColor)

            attributedText.draw(at: textPosition)
        }
    }

    // MARK: - Private Methods

    private func detectFaces(in image: CIImage) async throws -> [CGRect] {
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNDetectFaceRectanglesRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                let faceObservations = request.results as? [VNFaceObservation] ?? []
                let imageSize = image.extent.size

                let faceRectangles = faceObservations.map { observation in
                    // Convert normalized coordinates to image coordinates
                    let faceRect = VNImageRectForNormalizedRect(
                        observation.boundingBox,
                        Int(imageSize.width),
                        Int(imageSize.height)
                    )

                    // Expand the rectangle slightly for better coverage
                    return faceRect.insetBy(dx: -faceRect.width * 0.1, dy: -faceRect.height * 0.1)
                }

                continuation.resume(returning: faceRectangles)
            }

            let handler = VNImageRequestHandler(ciImage: image)
            try? handler.perform([request])
        }
    }

    private func blurRegion(in image: CIImage, rect: CGRect) -> CIImage {
        // Create blur filter
        let blurFilter = CIFilter.gaussianBlur()
        blurFilter.inputImage = image
        blurFilter.radius = 25.0

        guard let blurredImage = blurFilter.outputImage else { return image }

        // Create mask for the region
        let maskFilter = CIFilter.constantColorGenerator()
        maskFilter.color = CIColor.white

        guard let maskImage = maskFilter.outputImage?.cropped(to: rect) else { return image }

        // Create inverse mask for the rest of the image
        let invertFilter = CIFilter.colorInvert()
        invertFilter.inputImage = maskImage
        guard let invertedMask = invertFilter.outputImage else { return image }

        // Blend original and blurred images using the mask
        let blendFilter = CIFilter.blendWithMask()
        blendFilter.inputImage = image
        blendFilter.backgroundImage = blurredImage
        blendFilter.maskImage = maskImage

        return blendFilter.outputImage ?? image
    }

    private func createSubjectMask(from image: CIImage) async throws -> CIImage {
        // This is a simplified version - in production, you'd use more sophisticated segmentation
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNGeneratePersonSegmentationRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                if let observation = request.results?.first as? VNPixelBufferObservation {
                    let maskImage = CIImage(cvPixelBuffer: observation.pixelBuffer)
                    continuation.resume(returning: maskImage)
                } else {
                    // Fallback: create a simple edge-based mask
                    let edgeFilter = CIFilter.edgeWork()
                    edgeFilter.inputImage = image
                    let edgeImage = edgeFilter.outputImage ?? image
                    continuation.resume(returning: edgeImage)
                }
            }

            request.qualityLevel = .accurate
            request.outputPixelFormat = kCVPixelFormatType_OneComponent8

            let handler = VNImageRequestHandler(ciImage: image)
            try? handler.perform([request])
        }
    }

    private func applyMask(_ mask: CIImage, to image: CIImage) -> CIImage {
        let maskFilter = CIFilter.blendWithAlphaMask()
        maskFilter.inputImage = image
        maskFilter.maskImage = mask
        maskFilter.backgroundImage = CIImage.empty()

        return maskFilter.outputImage ?? image
    }

    private func addTransparentBackground(to image: CIImage) -> CIImage {
        // Create transparent background
        let backgroundFilter = CIFilter.constantColorGenerator()
        backgroundFilter.color = CIColor.clear

        guard let background = backgroundFilter.outputImage?.cropped(to: image.extent) else {
            return image
        }

        // Composite the subject over transparent background
        let compositeFilter = CIFilter.sourceOverCompositing()
        compositeFilter.inputImage = image
        compositeFilter.backgroundImage = background

        return compositeFilter.outputImage ?? image
    }

    private func drawGrid2x2(images: [UIImage], in context: CGContext, canvasSize: CGSize) {
        let spacing: CGFloat = 10
        let cellSize = CGSize(
            width: (canvasSize.width - spacing * 3) / 2,
            height: (canvasSize.height - spacing * 3) / 2
        )

        let positions = [
            CGPoint(x: spacing, y: spacing),
            CGPoint(x: spacing * 2 + cellSize.width, y: spacing),
            CGPoint(x: spacing, y: spacing * 2 + cellSize.height),
            CGPoint(x: spacing * 2 + cellSize.width, y: spacing * 2 + cellSize.height)
        ]

        for (index, image) in images.prefix(4).enumerated() {
            let rect = CGRect(origin: positions[index], size: cellSize)
            context.draw(image.cgImage!, in: rect)
        }
    }

    private func drawGrid3x3(images: [UIImage], in context: CGContext, canvasSize: CGSize) {
        let spacing: CGFloat = 8
        let cellSize = CGSize(
            width: (canvasSize.width - spacing * 4) / 3,
            height: (canvasSize.height - spacing * 4) / 3
        )

        for (index, image) in images.prefix(9).enumerated() {
            let row = index / 3
            let col = index % 3

            let x = spacing + CGFloat(col) * (cellSize.width + spacing)
            let y = spacing + CGFloat(row) * (cellSize.height + spacing)

            let rect = CGRect(x: x, y: y, width: cellSize.width, height: cellSize.height)
            context.draw(image.cgImage!, in: rect)
        }
    }

    private func drawMagazineLayout(images: [UIImage], in context: CGContext, canvasSize: CGSize) {
        guard !images.isEmpty else { return }

        let margin: CGFloat = 40
        let spacing: CGFloat = 20

        // Main image (large)
        if images.count >= 1 {
            let mainImageRect = CGRect(
                x: margin,
                y: margin,
                width: canvasSize.width * 0.6 - margin,
                height: canvasSize.height * 0.7
            )
            context.draw(images[0].cgImage!, in: mainImageRect)
        }

        // Secondary images (smaller, stacked)
        let sideX = canvasSize.width * 0.6 + spacing
        let sideWidth = canvasSize.width * 0.4 - margin - spacing
        let sideHeight = (canvasSize.height * 0.7 - spacing) / 2

        if images.count >= 2 {
            let topRect = CGRect(x: sideX, y: margin, width: sideWidth, height: sideHeight)
            context.draw(images[1].cgImage!, in: topRect)
        }

        if images.count >= 3 {
            let bottomRect = CGRect(x: sideX, y: margin + sideHeight + spacing, width: sideWidth, height: sideHeight)
            context.draw(images[2].cgImage!, in: bottomRect)
        }

        // Add text area at bottom
        drawTextArea(in: context, rect: CGRect(
            x: margin,
            y: canvasSize.height * 0.75,
            width: canvasSize.width - margin * 2,
            height: canvasSize.height * 0.25 - margin
        ))
    }

    private func drawStoryLayout(images: [UIImage], in context: CGContext, canvasSize: CGSize) {
        // Story format is vertical, so arrange images in a vertical stack
        let imageHeight = canvasSize.height / CGFloat(max(1, images.count))
        let spacing: CGFloat = 10

        for (index, image) in images.enumerated() {
            let y = CGFloat(index) * imageHeight + spacing
            let rect = CGRect(
                x: spacing,
                y: y,
                width: canvasSize.width - spacing * 2,
                height: imageHeight - spacing * 2
            )
            context.draw(image.cgImage!, in: rect)
        }
    }

    private func drawTextArea(in context: CGContext, rect: CGRect) {
        // Draw subtle background for text
        context.setFillColor(UIColor.black.withAlphaComponent(0.05).cgColor)
        context.fill(rect)

        // Add placeholder text styling
        let text = "StyleSync - Your Perfect Look"
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 16, weight: .medium),
            .foregroundColor: UIColor.darkGray
        ]

        let attributedText = NSAttributedString(string: text, attributes: attributes)
        let textSize = attributedText.size()

        let textRect = CGRect(
            x: rect.midX - textSize.width / 2,
            y: rect.midY - textSize.height / 2,
            width: textSize.width,
            height: textSize.height
        )

        attributedText.draw(in: textRect)
    }

    private func calculateWatermarkPosition(
        textSize: CGSize,
        imageSize: CGSize,
        position: WatermarkPosition
    ) -> CGPoint {
        let margin: CGFloat = 20

        switch position {
        case .topLeft:
            return CGPoint(x: margin, y: margin)
        case .topRight:
            return CGPoint(x: imageSize.width - textSize.width - margin, y: margin)
        case .bottomLeft:
            return CGPoint(x: margin, y: imageSize.height - textSize.height - margin)
        case .bottomRight:
            return CGPoint(
                x: imageSize.width - textSize.width - margin,
                y: imageSize.height - textSize.height - margin
            )
        case .center:
            return CGPoint(
                x: (imageSize.width - textSize.width) / 2,
                y: (imageSize.height - textSize.height) / 2
            )
        }
    }
}

// MARK: - Supporting Types
enum CollageLayout: CaseIterable {
    case grid2x2
    case grid3x3
    case magazine
    case story

    var displayName: String {
        switch self {
        case .grid2x2: return "2×2 Grid"
        case .grid3x3: return "3×3 Grid"
        case .magazine: return "Magazine"
        case .story: return "Story"
        }
    }
}

enum WatermarkPosition: CaseIterable {
    case topLeft
    case topRight
    case bottomLeft
    case bottomRight
    case center

    var displayName: String {
        switch self {
        case .topLeft: return "Top Left"
        case .topRight: return "Top Right"
        case .bottomLeft: return "Bottom Left"
        case .bottomRight: return "Bottom Right"
        case .center: return "Center"
        }
    }
}

// MARK: - Privacy Extensions
extension ImageProcessor {
    func anonymizeImage(_ image: UIImage) async -> UIImage {
        // Comprehensive anonymization
        var processedImage = image

        // Step 1: Blur faces
        processedImage = await blurFaces(in: processedImage)

        // Step 2: Strip metadata
        processedImage = stripMetadata(from: processedImage)

        // Step 3: Remove any visible text that might contain personal info
        processedImage = await blurVisibleText(in: processedImage)

        return processedImage
    }

    private func blurVisibleText(in image: UIImage) async -> UIImage {
        guard let ciImage = CIImage(image: image) else { return image }

        do {
            let textRectangles = try await detectText(in: ciImage)
            var processedImage = ciImage

            for textRect in textRectangles {
                processedImage = blurRegion(in: processedImage, rect: textRect)
            }

            if let cgImage = ciContext.createCGImage(processedImage, from: processedImage.extent) {
                return UIImage(cgImage: cgImage)
            }

        } catch {
            print("Text detection failed: \(error)")
        }

        return image
    }

    private func detectText(in image: CIImage) async throws -> [CGRect] {
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNDetectTextRectanglesRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                let textObservations = request.results as? [VNTextObservation] ?? []
                let imageSize = image.extent.size

                let textRectangles = textObservations.map { observation in
                    VNImageRectForNormalizedRect(
                        observation.boundingBox,
                        Int(imageSize.width),
                        Int(imageSize.height)
                    )
                }

                continuation.resume(returning: textRectangles)
            }

            let handler = VNImageRequestHandler(ciImage: image)
            try? handler.perform([request])
        }
    }
}

#Preview {
    struct ImageProcessorPreview: View {
        @StateObject private var processor = ImageProcessor()
        @State private var originalImage: UIImage?
        @State private var processedImage: UIImage?

        var body: some View {
            VStack {
                Text("Image Processor")
                    .font(.headline)

                Button("Test Face Blur") {
                    testFaceBlur()
                }
                .buttonStyle(.borderedProminent)

                if let processed = processedImage {
                    Image(uiImage: processed)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 300)
                }
            }
            .padding()
        }

        private func testFaceBlur() {
            // Create a test image
            let renderer = UIGraphicsImageRenderer(size: CGSize(width: 300, height: 300))
            let testImage = renderer.image { _ in
                UIColor.lightGray.setFill()
                UIBezierPath(rect: CGRect(x: 0, y: 0, width: 300, height: 300)).fill()
            }

            originalImage = testImage
            Task {
                processedImage = await processor.blurFaces(in: testImage)
            }
        }
    }

    return ImageProcessorPreview()
}