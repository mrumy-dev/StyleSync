import Foundation
import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins
import AVFoundation

// MARK: - Content Editor Manager
@MainActor
final class ContentEditorManager: ObservableObject {
    // MARK: - Published Properties
    @Published var originalImage: UIImage?
    @Published var processedImage: UIImage?
    @Published var selectedFilter: FilterType = .none
    @Published var appliedEffects: Set<EffectType> = []
    @Published var overlayElements: [OverlayElement] = []
    @Published var textElements: [TextElement] = []
    @Published var selectedStickerCategory: StickerCategory?

    // Image Adjustments
    @Published var brightness: Double = 0
    @Published var contrast: Double = 1
    @Published var saturation: Double = 1
    @Published var warmth: Double = 0
    @Published var highlights: Double = 0
    @Published var shadows: Double = 0
    @Published var vignette: Double = 0
    @Published var sharpness: Double = 0
    @Published var clarity: Double = 0

    // Video Properties
    @Published var videoURL: URL?
    @Published var musicTrack: MusicTrack?
    @Published var videoEffects: [VideoEffect] = []

    // MARK: - Private Properties
    private let context = CIContext()
    private var editingSteps: [EditingStep] = []
    private let storageManager = SandboxedStorageManager.shared
    private let cryptoEngine = CryptoEngine.shared

    // MARK: - Constants
    private enum Constants {
        static let maxImageSize: CGFloat = 2048
        static let filterCacheSize = 50
        static let editingHistoryLimit = 20
    }

    init() {
        setupImageProcessing()
        setupObservers()
    }

    // MARK: - Media Loading
    func loadMedia(_ capturedMedia: CapturedMedia) {
        switch capturedMedia.type {
        case .image(let image):
            loadImage(image)
        case .video(let url):
            loadVideo(url)
        }
    }

    private func loadImage(_ image: UIImage) {
        originalImage = resizeImage(image, maxSize: Constants.maxImageSize)
        processedImage = originalImage
        resetAdjustments()
    }

    func loadVideo(_ url: URL) {
        videoURL = url
        // Extract thumbnail for preview
        extractVideoThumbnail(url) { [weak self] thumbnail in
            DispatchQueue.main.async {
                self?.loadImage(thumbnail)
            }
        }
    }

    // MARK: - Filter Management
    func applyFilter(_ filter: FilterType) {
        selectedFilter = filter
        processImage()

        addEditingStep(.apply_filter, parameters: ["filter": filter.rawValue])
    }

    private func processImage() {
        guard let originalImage = originalImage,
              let ciImage = CIImage(image: originalImage) else { return }

        var processedCIImage = ciImage

        // Apply filter
        if selectedFilter != .none {
            processedCIImage = applyFilterToCIImage(processedCIImage, filter: selectedFilter)
        }

        // Apply adjustments
        processedCIImage = applyAdjustments(processedCIImage)

        // Apply effects
        for effect in appliedEffects {
            processedCIImage = applyEffect(processedCIImage, effect: effect)
        }

        // Convert back to UIImage
        if let cgImage = context.createCGImage(processedCIImage, from: processedCIImage.extent) {
            processedImage = UIImage(cgImage: cgImage)
        }
    }

    private func applyFilterToCIImage(_ image: CIImage, filter: FilterType) -> CIImage {
        switch filter {
        case .none:
            return image

        case .vintage:
            let sepiaFilter = CIFilter.sepiaTone()
            sepiaFilter.inputImage = image
            sepiaFilter.intensity = 0.7
            return sepiaFilter.outputImage ?? image

        case .blackWhite:
            let bwFilter = CIFilter.colorMonochrome()
            bwFilter.inputImage = image
            bwFilter.color = CIColor.white
            bwFilter.intensity = 1.0
            return bwFilter.outputImage ?? image

        case .vibrant:
            let vibranceFilter = CIFilter.vibrance()
            vibranceFilter.inputImage = image
            vibranceFilter.amount = 1.5
            return vibranceFilter.outputImage ?? image

        case .dramatic:
            let contrastFilter = CIFilter.colorControls()
            contrastFilter.inputImage = image
            contrastFilter.contrast = 1.5
            contrastFilter.brightness = 0.1
            contrastFilter.saturation = 1.2
            return contrastFilter.outputImage ?? image

        case .dreamy:
            let bloomFilter = CIFilter.bloom()
            bloomFilter.inputImage = image
            bloomFilter.radius = 10
            bloomFilter.intensity = 0.5
            return bloomFilter.outputImage ?? image

        case .film:
            let colorMatrixFilter = CIFilter.colorMatrix()
            colorMatrixFilter.inputImage = image
            // Film-like color grading
            colorMatrixFilter.rVector = CIVector(x: 1.1, y: 0, z: 0, w: 0)
            colorMatrixFilter.gVector = CIVector(x: 0, y: 1.0, z: 0, w: 0)
            colorMatrixFilter.bVector = CIVector(x: 0, y: 0, z: 0.9, w: 0)
            return colorMatrixFilter.outputImage ?? image

        case .retro:
            let colorCubeFilter = CIFilter.colorCube()
            colorCubeFilter.inputImage = image
            colorCubeFilter.cubeDimension = 16
            // Retro color cube data would be loaded here
            return colorCubeFilter.outputImage ?? image

        case .natural:
            let exposureFilter = CIFilter.exposureAdjust()
            exposureFilter.inputImage = image
            exposureFilter.ev = 0.3
            return exposureFilter.outputImage ?? image
        }
    }

    private func applyAdjustments(_ image: CIImage) -> CIImage {
        var adjustedImage = image

        // Brightness and contrast
        if brightness != 0 || contrast != 1 {
            let colorControls = CIFilter.colorControls()
            colorControls.inputImage = adjustedImage
            colorControls.brightness = Float(brightness)
            colorControls.contrast = Float(contrast)
            colorControls.saturation = Float(saturation)
            adjustedImage = colorControls.outputImage ?? adjustedImage
        }

        // Temperature (warmth)
        if warmth != 0 {
            let temperatureFilter = CIFilter.temperatureAndTint()
            temperatureFilter.inputImage = adjustedImage
            temperatureFilter.neutral = CIVector(x: 6500 + (warmth * 2000), y: 0)
            adjustedImage = temperatureFilter.outputImage ?? adjustedImage
        }

        // Highlights and shadows
        if highlights != 0 || shadows != 0 {
            let highlightShadowFilter = CIFilter.highlightShadowAdjust()
            highlightShadowFilter.inputImage = adjustedImage
            highlightShadowFilter.highlightAmount = Float(1 + highlights)
            highlightShadowFilter.shadowAmount = Float(1 + shadows)
            adjustedImage = highlightShadowFilter.outputImage ?? adjustedImage
        }

        // Vignette
        if vignette != 0 {
            let vignetteFilter = CIFilter.vignette()
            vignetteFilter.inputImage = adjustedImage
            vignetteFilter.intensity = Float(vignette)
            adjustedImage = vignetteFilter.outputImage ?? adjustedImage
        }

        // Sharpness
        if sharpness != 0 {
            let sharpenFilter = CIFilter.sharpenLuminance()
            sharpenFilter.inputImage = adjustedImage
            sharpenFilter.sharpness = Float(sharpness * 2)
            adjustedImage = sharpenFilter.outputImage ?? adjustedImage
        }

        return adjustedImage
    }

    private func applyEffect(_ image: CIImage, effect: EffectType) -> CIImage {
        switch effect {
        case .blur:
            let blurFilter = CIFilter.gaussianBlur()
            blurFilter.inputImage = image
            blurFilter.radius = 5.0
            return blurFilter.outputImage ?? image

        case .glow:
            let bloomFilter = CIFilter.bloom()
            bloomFilter.inputImage = image
            bloomFilter.radius = 15
            bloomFilter.intensity = 0.8
            return bloomFilter.outputImage ?? image

        case .sparkle:
            let starburstFilter = CIFilter.starBurstGenerator()
            starburstFilter.center = CIVector(x: image.extent.midX, y: image.extent.midY)
            starburstFilter.color = CIColor.white
            starburstFilter.radius = 50

            let blendFilter = CIFilter.additionCompositing()
            blendFilter.inputImage = image
            blendFilter.backgroundImage = starburstFilter.outputImage
            return blendFilter.outputImage ?? image

        case .vintage:
            return applyFilterToCIImage(image, filter: .vintage)

        case .glitch:
            // Glitch effect implementation
            let displacementFilter = CIFilter.displacementDistortion()
            displacementFilter.inputImage = image
            // Would need displacement map
            return displacementFilter.outputImage ?? image
        }
    }

    // MARK: - Adjustment Observers
    private func setupObservers() {
        // Observe adjustment changes and reprocess image
        [
            $brightness, $contrast, $saturation, $warmth,
            $highlights, $shadows, $vignette, $sharpness, $clarity
        ].forEach { publisher in
            publisher
                .debounce(for: .milliseconds(100), scheduler: RunLoop.main)
                .sink { [weak self] _ in
                    self?.processImage()
                }
                .store(in: &cancellables)
        }
    }

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Effect Management
    func toggleEffect(_ effect: EffectType) {
        if appliedEffects.contains(effect) {
            appliedEffects.remove(effect)
        } else {
            appliedEffects.insert(effect)
        }
        processImage()

        addEditingStep(.apply_filter, parameters: ["effect": effect.rawValue])
    }

    // MARK: - Text Management
    func addTextElement(_ text: String) {
        let textElement = TextElement(
            id: UUID(),
            text: text,
            style: .modern,
            color: .white,
            size: 24,
            position: CGPoint(x: 200, y: 300),
            rotation: 0,
            opacity: 1.0
        )

        textElements.append(textElement)

        let overlayElement = OverlayElement(
            id: textElement.id,
            type: .text(textElement),
            position: textElement.position,
            scale: 1.0,
            rotation: textElement.rotation,
            opacity: textElement.opacity
        )

        overlayElements.append(overlayElement)

        addEditingStep(.add_text, parameters: ["text": text])
    }

    func applyTextStyle(_ style: TextStyle) {
        for index in textElements.indices {
            textElements[index].style = style
        }
        updateOverlayElements()
    }

    // MARK: - Sticker Management
    func showStickerCategory(_ category: StickerCategory) {
        selectedStickerCategory = category
    }

    func addSticker(_ emoji: String, category: StickerCategory) {
        let stickerElement = StickerElement(
            id: UUID(),
            emoji: emoji,
            category: category,
            size: 32,
            position: CGPoint(x: 200, y: 200),
            rotation: 0,
            opacity: 1.0
        )

        let overlayElement = OverlayElement(
            id: stickerElement.id,
            type: .sticker(stickerElement),
            position: stickerElement.position,
            scale: 1.0,
            rotation: stickerElement.rotation,
            opacity: stickerElement.opacity
        )

        overlayElements.append(overlayElement)

        addEditingStep(.add_sticker, parameters: ["emoji": emoji])
    }

    // MARK: - Overlay Element Management
    func updateElementPosition(_ elementId: UUID, position: CGPoint) {
        if let index = overlayElements.firstIndex(where: { $0.id == elementId }) {
            overlayElements[index].position = position
        }
    }

    func updateScale(_ scale: CGFloat) {
        // Apply scale to all overlay elements
        for index in overlayElements.indices {
            overlayElements[index].scale = scale
        }
    }

    func updatePosition(_ offset: CGSize) {
        // Apply position offset to all overlay elements
        for index in overlayElements.indices {
            overlayElements[index].position.x += offset.width
            overlayElements[index].position.y += offset.height
        }
    }

    private func updateOverlayElements() {
        for index in overlayElements.indices {
            switch overlayElements[index].type {
            case .text(let textElement):
                if let textIndex = textElements.firstIndex(where: { $0.id == textElement.id }) {
                    overlayElements[index].type = .text(textElements[textIndex])
                }
            default:
                break
            }
        }
    }

    // MARK: - Editing History
    private func addEditingStep(_ action: EditingAction, parameters: [String: Any] = [:]) {
        let step = EditingStep(action: action, parameters: parameters)
        editingSteps.append(step)

        // Limit history size
        if editingSteps.count > Constants.editingHistoryLimit {
            editingSteps.removeFirst()
        }
    }

    func undo() {
        guard !editingSteps.isEmpty else { return }

        editingSteps.removeLast()
        reprocessFromHistory()
    }

    private func reprocessFromHistory() {
        resetAdjustments()
        overlayElements.removeAll()
        textElements.removeAll()
        appliedEffects.removeAll()
        selectedFilter = .none

        for step in editingSteps {
            applyEditingStep(step)
        }

        processImage()
    }

    private func applyEditingStep(_ step: EditingStep) {
        switch step.action {
        case .apply_filter:
            if let filterName = step.parameters["filter"] as? String,
               let filter = FilterType(rawValue: filterName) {
                selectedFilter = filter
            }

        case .add_text:
            if let text = step.parameters["text"] as? String {
                addTextElement(text)
            }

        case .add_sticker:
            if let emoji = step.parameters["emoji"] as? String {
                addSticker(emoji, category: .fashion)
            }

        default:
            break
        }
    }

    // MARK: - Export
    func getEditedMedia() -> EditedMedia {
        let editingMetadata = EditingMetadata(
            originalImageData: originalImage?.jpegData(compressionQuality: 1.0),
            editingSteps: editingSteps,
            totalEditingTime: TimeInterval(editingSteps.count * 30), // Estimate
            filtersApplied: [selectedFilter].compactMap { $0 == .none ? nil : PhotoFilter(id: UUID(), name: $0.rawValue, intensity: 1.0, parameters: [:], category: .modern) },
            adjustments: ImageAdjustments(
                brightness: Float(brightness),
                contrast: Float(contrast),
                saturation: Float(saturation),
                warmth: Float(warmth),
                highlights: Float(highlights),
                shadows: Float(shadows),
                vignette: Float(vignette),
                sharpness: Float(sharpness),
                clarity: Float(clarity)
            )
        )

        return EditedMedia(
            processedImage: processedImage,
            videoURL: videoURL,
            overlayElements: overlayElements,
            musicTrack: musicTrack,
            editingMetadata: editingMetadata
        )
    }

    // MARK: - Utility Methods
    private func resetAdjustments() {
        brightness = 0
        contrast = 1
        saturation = 1
        warmth = 0
        highlights = 0
        shadows = 0
        vignette = 0
        sharpness = 0
        clarity = 0
    }

    private func setupImageProcessing() {
        // Configure Core Image context for optimal performance
        // This would include GPU acceleration setup
    }

    private func resizeImage(_ image: UIImage, maxSize: CGFloat) -> UIImage {
        let size = image.size
        let ratio = min(maxSize / size.width, maxSize / size.height)

        if ratio >= 1.0 {
            return image
        }

        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)

        UIGraphicsBeginImageContextWithOptions(newSize, false, 0.0)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return resizedImage ?? image
    }

    private func extractVideoThumbnail(_ url: URL, completion: @escaping (UIImage) -> Void) {
        let asset = AVAsset(url: url)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let cgImage = try imageGenerator.copyCGImage(at: .zero, actualTime: nil)
                let thumbnail = UIImage(cgImage: cgImage)
                completion(thumbnail)
            } catch {
                // Fallback to default image
                completion(UIImage(systemName: "photo") ?? UIImage())
            }
        }
    }
}

// MARK: - Supporting Types
enum FilterType: String, CaseIterable {
    case none = "none"
    case vintage = "vintage"
    case blackWhite = "black_white"
    case vibrant = "vibrant"
    case dramatic = "dramatic"
    case dreamy = "dreamy"
    case film = "film"
    case retro = "retro"
    case natural = "natural"

    var displayName: String {
        switch self {
        case .none: return "Original"
        case .vintage: return "Vintage"
        case .blackWhite: return "B&W"
        case .vibrant: return "Vibrant"
        case .dramatic: return "Dramatic"
        case .dreamy: return "Dreamy"
        case .film: return "Film"
        case .retro: return "Retro"
        case .natural: return "Natural"
        }
    }

    var color: Color {
        switch self {
        case .none: return .gray
        case .vintage: return .brown
        case .blackWhite: return .black
        case .vibrant: return .pink
        case .dramatic: return .red
        case .dreamy: return .purple
        case .film: return .orange
        case .retro: return .yellow
        case .natural: return .green
        }
    }
}

enum EffectType: String, CaseIterable {
    case blur = "blur"
    case glow = "glow"
    case sparkle = "sparkle"
    case vintage = "vintage"
    case glitch = "glitch"

    var displayName: String {
        switch self {
        case .blur: return "Blur"
        case .glow: return "Glow"
        case .sparkle: return "Sparkle"
        case .vintage: return "Vintage"
        case .glitch: return "Glitch"
        }
    }

    var icon: String {
        switch self {
        case .blur: return "circle.dotted"
        case .glow: return "sun.max"
        case .sparkle: return "sparkles"
        case .vintage: return "camera.vintage"
        case .glitch: return "waveform"
        }
    }
}

enum TextStyle: String, CaseIterable {
    case modern = "modern"
    case classic = "classic"
    case bold = "bold"
    case script = "script"
    case handwritten = "handwritten"

    var displayName: String {
        rawValue.capitalized
    }

    var font: Font {
        switch self {
        case .modern: return .system(.title2, design: .rounded, weight: .medium)
        case .classic: return .system(.title2, design: .serif, weight: .regular)
        case .bold: return .system(.title2, design: .default, weight: .bold)
        case .script: return .system(.title2, design: .default, weight: .light)
        case .handwritten: return .system(.title2, design: .rounded, weight: .light)
        }
    }
}

struct TextElement: Identifiable {
    let id: UUID
    var text: String
    var style: TextStyle
    var color: Color
    var size: CGFloat
    var position: CGPoint
    var rotation: Double
    var opacity: Double
}

struct StickerElement: Identifiable {
    let id: UUID
    var emoji: String
    var category: StickerCategory
    var size: CGFloat
    var position: CGPoint
    var rotation: Double
    var opacity: Double
}

struct OverlayElement: Identifiable {
    let id: UUID
    var type: OverlayElementType
    var position: CGPoint
    var scale: CGFloat
    var rotation: Double
    var opacity: Double
}

enum OverlayElementType {
    case text(TextElement)
    case sticker(StickerElement)
}

struct EditedMedia {
    let processedImage: UIImage?
    let videoURL: URL?
    let overlayElements: [OverlayElement]
    let musicTrack: MusicTrack?
    let editingMetadata: EditingMetadata
}

// MARK: - Content Creator Manager
@MainActor
final class ContentCreatorManager: ObservableObject {
    static let shared = ContentCreatorManager()

    @Published var isRecording = false
    @Published var recordingDuration: TimeInterval = 0
    @Published var availableTemplates: [ContentTemplate] = []
    @Published var recentlyUsedFilters: [PhotoFilter] = []

    private init() {
        loadAvailableTemplates()
        loadRecentFilters()
    }

    private func loadAvailableTemplates() {
        // Load content templates from storage
        availableTemplates = generateMockTemplates()
    }

    private func loadRecentFilters() {
        // Load recently used filters
        recentlyUsedFilters = []
    }

    private func generateMockTemplates() -> [ContentTemplate] {
        return [
            ContentTemplate(
                name: "Fashion Grid",
                category: .grid,
                layout: LayoutData(
                    type: .grid3x3,
                    dimensions: CGSize(width: 1080, height: 1080),
                    frames: [],
                    backgroundColor: CodableColor(color: .white),
                    borderStyle: nil
                ),
                filters: [],
                effects: []
            )
        ]
    }
}