import SwiftUI
import Vision
import CoreML
import AVFoundation

// MARK: - AI Capture Assistant

@MainActor
class AICaptureAssistant: ObservableObject {
    @Published var isClothingDetected = false
    @Published var clothingBounds: [CGRect] = []
    @Published var smartCropSuggestions: [CropSuggestion] = []
    @Published var backgroundRemovalPreview: UIImage?
    @Published var currentQualityScore: Double?
    @Published var showingGuidance = false
    @Published var multipleAnglesProgress: [AngleCapture] = []
    @Published var blurDetectionResult: BlurDetectionResult?

    private var visionSequenceHandler = VNSequenceRequestHandler()
    private var clothingClassifier: VNCoreMLModel?
    private var blurDetector: VNCoreMLModel?

    struct CropSuggestion {
        let rect: CGRect
        let confidence: Float
        let reason: String
    }

    struct AngleCapture {
        let angle: CaptureAngle
        let isCompleted: Bool
        let thumbnail: UIImage?
    }

    enum CaptureAngle: String, CaseIterable {
        case front = "Front"
        case back = "Back"
        case sideLeft = "Side Left"
        case sideRight = "Side Right"
        case detail = "Detail"

        var icon: String {
            switch self {
            case .front: return "person.fill"
            case .back: return "person.fill.turn.right"
            case .sideLeft: return "person.fill.turn.left"
            case .sideRight: return "person.fill.turn.right"
            case .detail: return "magnifyingglass"
            }
        }
    }

    enum BlurDetectionResult {
        case sharp(score: Double)
        case slightlyBlurred(score: Double)
        case blurred(score: Double)

        var qualityScore: Double {
            switch self {
            case .sharp(let score): return score
            case .slightlyBlurred(let score): return score * 0.7
            case .blurred(let score): return score * 0.3
            }
        }

        var color: Color {
            switch self {
            case .sharp: return .green
            case .slightlyBlurred: return .yellow
            case .blurred: return .red
            }
        }
    }

    init() {
        setupModels()
        setupMultipleAnglesGuide()
    }

    func start() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(processFrame(_:)),
            name: .newCameraFrame,
            object: nil
        )
    }

    private func setupModels() {
        // Load clothing detection model
        setupClothingClassifier()
        setupBlurDetector()
    }

    private func setupClothingClassifier() {
        // In a real implementation, you would load a custom trained model
        // For now, we'll use object detection as a placeholder
        guard let model = try? VNCoreMLModel(for: createClothingDetectionModel()) else {
            print("Failed to load clothing detection model")
            return
        }
        clothingClassifier = model
    }

    private func setupBlurDetector() {
        // Setup blur detection model
        guard let model = try? VNCoreMLModel(for: createBlurDetectionModel()) else {
            print("Failed to load blur detection model")
            return
        }
        blurDetector = model
    }

    private func setupMultipleAnglesGuide() {
        multipleAnglesProgress = CaptureAngle.allCases.map { angle in
            AngleCapture(angle: angle, isCompleted: false, thumbnail: nil)
        }
    }

    @objc private func processFrame(_ notification: Notification) {
        guard let sampleBuffer = notification.object as? CMSampleBuffer else { return }

        Task {
            await processClothingDetection(sampleBuffer: sampleBuffer)
            await processQualityAssessment(sampleBuffer: sampleBuffer)
            await generateSmartCropSuggestions(sampleBuffer: sampleBuffer)
        }
    }

    private func processClothingDetection(sampleBuffer: CMSampleBuffer) async {
        guard let clothingClassifier = clothingClassifier else { return }

        let request = VNCoreMLRequest(model: clothingClassifier) { [weak self] request, error in
            DispatchQueue.main.async {
                self?.handleClothingDetection(request: request, error: error)
            }
        }

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        do {
            try visionSequenceHandler.perform([request], on: pixelBuffer)
        } catch {
            print("Error performing clothing detection: \(error)")
        }
    }

    private func handleClothingDetection(request: VNRequest, error: Error?) {
        guard error == nil,
              let results = request.results as? [VNRecognizedObjectObservation] else {
            isClothingDetected = false
            return
        }

        let clothingResults = results.filter { observation in
            observation.labels.contains { label in
                ["shirt", "pants", "dress", "jacket", "clothing"].contains(label.identifier.lowercased())
            }
        }

        isClothingDetected = !clothingResults.isEmpty
        clothingBounds = clothingResults.map { $0.boundingBox }
    }

    private func processQualityAssessment(sampleBuffer: CMSampleBuffer) async {
        guard let blurDetector = blurDetector else { return }

        let request = VNCoreMLRequest(model: blurDetector) { [weak self] request, error in
            DispatchQueue.main.async {
                self?.handleQualityAssessment(request: request, error: error)
            }
        }

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        do {
            try visionSequenceHandler.perform([request], on: pixelBuffer)
        } catch {
            print("Error performing quality assessment: \(error)")
        }
    }

    private func handleQualityAssessment(request: VNRequest, error: Error?) {
        guard error == nil,
              let results = request.results as? [VNClassificationObservation],
              let topResult = results.first else {
            currentQualityScore = nil
            return
        }

        let sharpnessScore = Double(topResult.confidence)
        currentQualityScore = sharpnessScore

        if sharpnessScore > 0.8 {
            blurDetectionResult = .sharp(score: sharpnessScore)
        } else if sharpnessScore > 0.5 {
            blurDetectionResult = .slightlyBlurred(score: sharpnessScore)
        } else {
            blurDetectionResult = .blurred(score: sharpnessScore)
        }
    }

    private func generateSmartCropSuggestions(sampleBuffer: CMSampleBuffer) async {
        guard isClothingDetected else {
            smartCropSuggestions = []
            return
        }

        var suggestions: [CropSuggestion] = []

        // Generate crop suggestions based on clothing detection
        for (index, bound) in clothingBounds.enumerated() {
            // Expand bounding box for better composition
            let expandedRect = CGRect(
                x: max(0, bound.minX - 0.1),
                y: max(0, bound.minY - 0.1),
                width: min(1.0, bound.width + 0.2),
                height: min(1.0, bound.height + 0.2)
            )

            let suggestion = CropSuggestion(
                rect: expandedRect,
                confidence: 0.85,
                reason: "Clothing item \(index + 1) - Optimal framing"
            )
            suggestions.append(suggestion)
        }

        // Add rule of thirds suggestions
        let ruleOfThirdsSuggestion = CropSuggestion(
            rect: CGRect(x: 0.1, y: 0.1, width: 0.8, height: 0.8),
            confidence: 0.7,
            reason: "Rule of thirds composition"
        )
        suggestions.append(ruleOfThirdsSuggestion)

        DispatchQueue.main.async {
            self.smartCropSuggestions = suggestions
        }
    }

    func generateBackgroundRemovalPreview(from image: UIImage) {
        Task {
            let request = VNGeneratePersonSegmentationRequest { [weak self] request, error in
                DispatchQueue.main.async {
                    self?.handleBackgroundRemoval(request: request, error: error, originalImage: image)
                }
            }

            request.qualityLevel = .accurate
            request.outputPixelFormat = kCVPixelFormatType_OneComponent8

            guard let cgImage = image.cgImage else { return }

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            try? handler.perform([request])
        }
    }

    private func handleBackgroundRemoval(request: VNRequest, error: Error?, originalImage: UIImage) {
        guard let result = request.results?.first as? VNPixelBufferObservation else {
            backgroundRemovalPreview = nil
            return
        }

        // Create preview with transparent background
        backgroundRemovalPreview = createPreviewWithMask(
            originalImage: originalImage,
            maskBuffer: result.pixelBuffer
        )
    }

    private func createPreviewWithMask(originalImage: UIImage, maskBuffer: CVPixelBuffer) -> UIImage? {
        guard let originalCGImage = originalImage.cgImage else { return nil }

        let ciContext = CIContext()
        let originalCIImage = CIImage(cgImage: originalCGImage)
        let maskCIImage = CIImage(cvPixelBuffer: maskBuffer)

        guard let blendFilter = CIFilter(name: "CIBlendWithAlphaMask") else { return nil }
        blendFilter.setValue(originalCIImage, forKey: kCIInputImageKey)
        blendFilter.setValue(maskCIImage, forKey: kCIInputMaskImageKey)

        guard let outputImage = blendFilter.outputImage,
              let cgImage = ciContext.createCGImage(outputImage, from: outputImage.extent) else { return nil }

        return UIImage(cgImage: cgImage)
    }

    func markAngleAsCompleted(_ angle: CaptureAngle, thumbnail: UIImage) {
        if let index = multipleAnglesProgress.firstIndex(where: { $0.angle == angle }) {
            multipleAnglesProgress[index] = AngleCapture(
                angle: angle,
                isCompleted: true,
                thumbnail: thumbnail
            )

            HapticManager.HapticType.success.trigger()
            SoundManager.SoundType.chime.play(volume: 0.6)

            // Check if all angles are completed
            if multipleAnglesProgress.allSatisfy({ $0.isCompleted }) {
                showCompletionCelebration()
            }
        }
    }

    private func showCompletionCelebration() {
        HapticManager.HapticType.celebration.trigger()
        SoundManager.SoundType.celebration.play(volume: 0.8)
    }

    private func createClothingDetectionModel() -> MLModel {
        // This would be replaced with an actual trained model
        // For now, return a placeholder model
        let config = MLModelConfiguration()
        config.computeUnits = .cpuAndGPU

        // In a real implementation, you would load your custom clothing detection model
        // return try! ClothingDetectionModel(configuration: config).model

        // Placeholder - using a simple model structure
        return try! MLModel(contentsOf: Bundle.main.url(forResource: "placeholder", withExtension: "mlmodel") ?? URL(string: "placeholder")!)
    }

    private func createBlurDetectionModel() -> MLModel {
        // This would be replaced with an actual blur detection model
        let config = MLModelConfiguration()
        config.computeUnits = .cpuAndGPU

        // Placeholder
        return try! MLModel(contentsOf: Bundle.main.url(forResource: "placeholder", withExtension: "mlmodel") ?? URL(string: "placeholder")!)
    }
}

// MARK: - UI Overlays

struct ClothingDetectionOverlay: View {
    let boundingBoxes: [CGRect]
    let suggestions: [AICaptureAssistant.CropSuggestion]

    var body: some View {
        ZStack {
            // Clothing bounding boxes
            ForEach(Array(boundingBoxes.enumerated()), id: \.offset) { index, box in
                Rectangle()
                    .strokeBorder(.green, lineWidth: 2)
                    .frame(
                        width: UIScreen.main.bounds.width * box.width,
                        height: UIScreen.main.bounds.height * box.height
                    )
                    .position(
                        x: UIScreen.main.bounds.width * (box.minX + box.width / 2),
                        y: UIScreen.main.bounds.height * (box.minY + box.height / 2)
                    )
                    .overlay(
                        Text("Clothing \(index + 1)")
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.green.opacity(0.8))
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 4)),
                        alignment: .topLeading
                    )
            }

            // Crop suggestions
            ForEach(Array(suggestions.enumerated()), id: \.offset) { index, suggestion in
                if suggestion.confidence > 0.7 {
                    Rectangle()
                        .strokeBorder(.yellow, style: StrokeStyle(lineWidth: 1, dash: [5, 5]))
                        .frame(
                            width: UIScreen.main.bounds.width * suggestion.rect.width,
                            height: UIScreen.main.bounds.height * suggestion.rect.height
                        )
                        .position(
                            x: UIScreen.main.bounds.width * (suggestion.rect.minX + suggestion.rect.width / 2),
                            y: UIScreen.main.bounds.height * (suggestion.rect.minY + suggestion.rect.height / 2)
                        )
                }
            }
        }
    }
}

struct AIGuidanceOverlay: View {
    @ObservedObject var assistant: AICaptureAssistant

    var body: some View {
        VStack {
            Spacer()

            GlassCardView {
                VStack(spacing: 16) {
                    Text("AI Capture Assistant")
                        .font(.headline.weight(.semibold))

                    if assistant.isClothingDetected {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text("Clothing detected")
                                .font(.subheadline)
                        }
                    }

                    if !assistant.smartCropSuggestions.isEmpty {
                        Text("Smart crop suggestions available")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    // Multiple angles progress
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 12) {
                        ForEach(assistant.multipleAnglesProgress, id: \.angle.rawValue) { capture in
                            VStack(spacing: 4) {
                                Circle()
                                    .fill(capture.isCompleted ? .green : .gray.opacity(0.3))
                                    .frame(width: 40, height: 40)
                                    .overlay(
                                        Group {
                                            if let thumbnail = capture.thumbnail {
                                                Image(uiImage: thumbnail)
                                                    .resizable()
                                                    .aspectRatio(contentMode: .fill)
                                                    .clipShape(Circle())
                                            } else {
                                                Image(systemName: capture.angle.icon)
                                                    .foregroundStyle(capture.isCompleted ? .white : .gray)
                                                    .font(.system(size: 16, weight: .medium))
                                            }
                                        }
                                    )

                                Text(capture.angle.rawValue)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .padding()
            }
            .padding()
        }
    }
}

struct QualityIndicator: View {
    let score: Double

    private var color: Color {
        if score > 0.8 { return .green }
        else if score > 0.5 { return .yellow }
        else { return .red }
    }

    private var icon: String {
        if score > 0.8 { return "checkmark.circle.fill" }
        else if score > 0.5 { return "exclamationmark.triangle.fill" }
        else { return "xmark.circle.fill" }
    }

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)

            Text("\(Int(score * 100))%")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(color)
        }
        .padding(8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()

        ClothingDetectionOverlay(
            boundingBoxes: [CGRect(x: 0.2, y: 0.3, width: 0.6, height: 0.4)],
            suggestions: []
        )

        AIGuidanceOverlay(assistant: AICaptureAssistant())

        QualityIndicator(score: 0.85)
            .position(x: 350, y: 120)
    }
}