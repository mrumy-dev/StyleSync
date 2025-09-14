import SwiftUI
import CoreImage
import Vision
import PhotosUI

struct PhotoEditView: View {
    let originalImage: UIImage
    let onSave: (UIImage) -> Void

    @StateObject private var editingEngine = PhotoEditingEngine()
    @State private var selectedTool: EditingTool = .crop
    @State private var isProcessing = false
    @State private var showingFilters = false
    @State private var showingSaveOptions = false
    @State private var magicWandSelection: [CGPoint] = []
    @State private var undoStack: [EditingState] = []
    @State private var redoStack: [EditingState] = []

    enum EditingTool: String, CaseIterable {
        case crop = "Crop"
        case brightness = "Brightness"
        case contrast = "Contrast"
        case saturation = "Saturation"
        case shadows = "Shadows"
        case highlights = "Highlights"
        case magicWand = "Magic Wand"
        case filter = "Filter"
        case background = "Background"

        var icon: String {
            switch self {
            case .crop: return "crop"
            case .brightness: return "sun.max"
            case .contrast: return "circle.lefthalf.filled"
            case .saturation: return "drop.fill"
            case .shadows: return "moon.fill"
            case .highlights: return "sun.dust.fill"
            case .magicWand: return "wand.and.stars"
            case .filter: return "camera.filters"
            case .background: return "person.crop.rectangle"
            }
        }
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Image Canvas
                    ImageCanvasView(
                        editingEngine: editingEngine,
                        selectedTool: selectedTool,
                        magicWandSelection: $magicWandSelection
                    )
                    .clipped()

                    // Tool Controls
                    EditingControlsView(
                        editingEngine: editingEngine,
                        selectedTool: $selectedTool,
                        isProcessing: $isProcessing
                    )
                    .background(.ultraThinMaterial)
                }

                // Processing Overlay
                if isProcessing {
                    ProcessingOverlay()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        // Dismiss without saving
                    }
                    .foregroundStyle(.white)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveEditedImage()
                    }
                    .foregroundStyle(.yellow)
                    .font(.headline.weight(.semibold))
                }
            }
            .onAppear {
                editingEngine.setOriginalImage(originalImage)
            }
        }
    }

    private func saveEditedImage() {
        isProcessing = true

        Task {
            if let editedImage = await editingEngine.generateFinalImage() {
                DispatchQueue.main.async {
                    isProcessing = false
                    onSave(editedImage)
                    HapticManager.HapticType.success.trigger()
                    SoundManager.SoundType.success.play(volume: 0.7)
                }
            }
        }
    }
}

// MARK: - Photo Editing Engine

@MainActor
class PhotoEditingEngine: ObservableObject {
    @Published var currentImage: UIImage?
    @Published var adjustments = ImageAdjustments()

    private var originalImage: UIImage?
    private let ciContext = CIContext(options: [.useSoftwareRenderer: false])

    struct ImageAdjustments {
        var brightness: Float = 0.0
        var contrast: Float = 1.0
        var saturation: Float = 1.0
        var shadows: Float = 0.0
        var highlights: Float = 0.0
        var cropRect: CGRect = CGRect(x: 0, y: 0, width: 1, height: 1)
        var selectedFilter: ClothingFilter = .none
        var backgroundRemoved: Bool = false
    }

    enum ClothingFilter: String, CaseIterable {
        case none = "None"
        case fashion = "Fashion"
        case vintage = "Vintage"
        case professional = "Professional"
        case vibrant = "Vibrant"
        case moody = "Moody"
        case clean = "Clean"

        var ciFilterName: String? {
            switch self {
            case .none: return nil
            case .fashion: return "CIColorControls"
            case .vintage: return "CISepiaTone"
            case .professional: return "CIUnsharpMask"
            case .vibrant: return "CIVibrance"
            case .moody: return "CIColorMonochrome"
            case .clean: return "CIExposureAdjust"
            }
        }

        var parameters: [String: Any] {
            switch self {
            case .none: return [:]
            case .fashion: return [kCIInputSaturationKey: 1.2, kCIInputContrastKey: 1.1]
            case .vintage: return [kCIInputIntensityKey: 0.5]
            case .professional: return [kCIInputIntensityKey: 0.5, kCIInputRadiusKey: 2.5]
            case .vibrant: return [kCIInputAmountKey: 0.3]
            case .moody: return [kCIInputColorKey: CIColor.gray, kCIInputIntensityKey: 0.3]
            case .clean: return [kCIInputEVKey: 0.2]
            }
        }
    }

    func setOriginalImage(_ image: UIImage) {
        originalImage = image
        currentImage = image
    }

    func updateBrightness(_ value: Float) {
        adjustments.brightness = value
        applyAdjustments()
    }

    func updateContrast(_ value: Float) {
        adjustments.contrast = value
        applyAdjustments()
    }

    func updateSaturation(_ value: Float) {
        adjustments.saturation = value
        applyAdjustments()
    }

    func updateShadows(_ value: Float) {
        adjustments.shadows = value
        applyAdjustments()
    }

    func updateHighlights(_ value: Float) {
        adjustments.highlights = value
        applyAdjustments()
    }

    func updateCrop(_ rect: CGRect) {
        adjustments.cropRect = rect
        applyAdjustments()
    }

    func applyFilter(_ filter: ClothingFilter) {
        adjustments.selectedFilter = filter
        applyAdjustments()
    }

    private func applyAdjustments() {
        guard let originalImage = originalImage,
              let ciImage = CIImage(image: originalImage) else { return }

        Task {
            let processedImage = await processImage(ciImage)
            DispatchQueue.main.async {
                self.currentImage = processedImage
            }
        }
    }

    private func processImage(_ ciImage: CIImage) async -> UIImage? {
        var workingImage = ciImage

        // Apply basic adjustments
        if let colorControlsFilter = CIFilter(name: "CIColorControls") {
            colorControlsFilter.setValue(workingImage, forKey: kCIInputImageKey)
            colorControlsFilter.setValue(adjustments.brightness, forKey: kCIInputBrightnessKey)
            colorControlsFilter.setValue(adjustments.contrast, forKey: kCIInputContrastKey)
            colorControlsFilter.setValue(adjustments.saturation, forKey: kCIInputSaturationKey)

            if let output = colorControlsFilter.outputImage {
                workingImage = output
            }
        }

        // Apply shadow/highlight adjustments
        if let shadowHighlightFilter = CIFilter(name: "CIHighlightShadowAdjust") {
            shadowHighlightFilter.setValue(workingImage, forKey: kCIInputImageKey)
            shadowHighlightFilter.setValue(adjustments.shadows, forKey: "inputShadowAmount")
            shadowHighlightFilter.setValue(adjustments.highlights, forKey: "inputHighlightAmount")

            if let output = shadowHighlightFilter.outputImage {
                workingImage = output
            }
        }

        // Apply selected filter
        if let filterName = adjustments.selectedFilter.ciFilterName,
           let filter = CIFilter(name: filterName) {
            filter.setValue(workingImage, forKey: kCIInputImageKey)

            for (key, value) in adjustments.selectedFilter.parameters {
                filter.setValue(value, forKey: key)
            }

            if let output = filter.outputImage {
                workingImage = output
            }
        }

        // Apply crop
        let cropRect = CGRect(
            x: workingImage.extent.width * adjustments.cropRect.minX,
            y: workingImage.extent.height * adjustments.cropRect.minY,
            width: workingImage.extent.width * adjustments.cropRect.width,
            height: workingImage.extent.height * adjustments.cropRect.height
        )

        workingImage = workingImage.cropped(to: cropRect)

        // Convert to UIImage
        guard let cgImage = ciContext.createCGImage(workingImage, from: workingImage.extent) else {
            return nil
        }

        return UIImage(cgImage: cgImage)
    }

    func generateFinalImage() async -> UIImage? {
        guard let originalImage = originalImage,
              let ciImage = CIImage(image: originalImage) else { return nil }

        return await processImage(ciImage)
    }

    func performMagicWandSelection(at point: CGPoint, tolerance: Float = 0.1) async -> [CGPoint] {
        guard let originalImage = originalImage else { return [] }

        // Convert point to image coordinates
        let imagePoint = CGPoint(
            x: point.x * originalImage.size.width,
            y: point.y * originalImage.size.height
        )

        // Perform flood fill selection
        return await floodFillSelection(at: imagePoint, tolerance: tolerance)
    }

    private func floodFillSelection(at point: CGPoint, tolerance: Float) async -> [CGPoint] {
        guard let originalImage = originalImage,
              let cgImage = originalImage.cgImage else { return [] }

        // This is a simplified version - a full implementation would use
        // a proper flood fill algorithm
        var selectedPoints: [CGPoint] = []

        let width = cgImage.width
        let height = cgImage.height

        // Sample area around the point
        let sampleRadius = 5
        for x in -sampleRadius...sampleRadius {
            for y in -sampleRadius...sampleRadius {
                let samplePoint = CGPoint(
                    x: point.x + CGFloat(x),
                    y: point.y + CGFloat(y)
                )

                if samplePoint.x >= 0 && samplePoint.x < CGFloat(width) &&
                   samplePoint.y >= 0 && samplePoint.y < CGFloat(height) {
                    selectedPoints.append(samplePoint)
                }
            }
        }

        return selectedPoints
    }
}

// MARK: - Image Canvas View

struct ImageCanvasView: View {
    @ObservedObject var editingEngine: PhotoEditingEngine
    let selectedTool: PhotoEditView.EditingTool
    @Binding var magicWandSelection: [CGPoint]

    @State private var cropRect: CGRect = CGRect(x: 0, y: 0, width: 1, height: 1)
    @State private var isDragging = false

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if let image = editingEngine.currentImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .clipShape(Rectangle())
                        .onTapGesture { location in
                            handleImageTap(at: location, in: geometry)
                        }
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    handleDragChanged(value, in: geometry)
                                }
                                .onEnded { value in
                                    handleDragEnded(value, in: geometry)
                                }
                        )

                    // Crop overlay
                    if selectedTool == .crop {
                        CropOverlay(cropRect: $cropRect)
                            .onChange(of: cropRect) { rect in
                                editingEngine.updateCrop(rect)
                            }
                    }

                    // Magic wand selection overlay
                    if selectedTool == .magicWand && !magicWandSelection.isEmpty {
                        MagicWandSelectionOverlay(points: magicWandSelection)
                    }
                }
            }
        }
    }

    private func handleImageTap(at location: CGPoint, in geometry: GeometryProxy) {
        switch selectedTool {
        case .magicWand:
            performMagicWandSelection(at: location, in: geometry)
        default:
            break
        }
    }

    private func performMagicWandSelection(at location: CGPoint, in geometry: GeometryProxy) {
        let normalizedPoint = CGPoint(
            x: location.x / geometry.size.width,
            y: location.y / geometry.size.height
        )

        Task {
            let selectedPoints = await editingEngine.performMagicWandSelection(at: normalizedPoint)
            DispatchQueue.main.async {
                magicWandSelection = selectedPoints
                HapticManager.HapticType.success.trigger()
                SoundManager.SoundType.magicChime.play(volume: 0.5)
            }
        }
    }

    private func handleDragChanged(_ value: DragGesture.Value, in geometry: GeometryProxy) {
        if selectedTool == .crop {
            updateCropRect(with: value, in: geometry)
        }
    }

    private func handleDragEnded(_ value: DragGesture.Value, in geometry: GeometryProxy) {
        HapticManager.HapticType.light.trigger()
    }

    private func updateCropRect(with dragValue: DragGesture.Value, in geometry: GeometryProxy) {
        let startPoint = dragValue.startLocation
        let currentPoint = dragValue.location

        let rect = CGRect(
            x: min(startPoint.x, currentPoint.x) / geometry.size.width,
            y: min(startPoint.y, currentPoint.y) / geometry.size.height,
            width: abs(currentPoint.x - startPoint.x) / geometry.size.width,
            height: abs(currentPoint.y - startPoint.y) / geometry.size.height
        )

        cropRect = rect
    }
}

// MARK: - Editing Controls

struct EditingControlsView: View {
    @ObservedObject var editingEngine: PhotoEditingEngine
    @Binding var selectedTool: PhotoEditView.EditingTool
    @Binding var isProcessing: Bool

    var body: some View {
        VStack(spacing: 16) {
            // Tool Selection
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(PhotoEditView.EditingTool.allCases, id: \.self) { tool in
                        EditingToolButton(
                            tool: tool,
                            isSelected: selectedTool == tool
                        ) {
                            selectedTool = tool
                            HapticManager.HapticType.selection.trigger()
                        }
                    }
                }
                .padding(.horizontal)
            }

            // Tool-specific controls
            Group {
                switch selectedTool {
                case .brightness:
                    AdjustmentSlider(
                        title: "Brightness",
                        value: editingEngine.adjustments.brightness,
                        range: -1.0...1.0
                    ) { value in
                        editingEngine.updateBrightness(value)
                    }

                case .contrast:
                    AdjustmentSlider(
                        title: "Contrast",
                        value: editingEngine.adjustments.contrast,
                        range: 0.0...2.0
                    ) { value in
                        editingEngine.updateContrast(value)
                    }

                case .saturation:
                    AdjustmentSlider(
                        title: "Saturation",
                        value: editingEngine.adjustments.saturation,
                        range: 0.0...2.0
                    ) { value in
                        editingEngine.updateSaturation(value)
                    }

                case .shadows:
                    AdjustmentSlider(
                        title: "Shadows",
                        value: editingEngine.adjustments.shadows,
                        range: -1.0...1.0
                    ) { value in
                        editingEngine.updateShadows(value)
                    }

                case .highlights:
                    AdjustmentSlider(
                        title: "Highlights",
                        value: editingEngine.adjustments.highlights,
                        range: -1.0...1.0
                    ) { value in
                        editingEngine.updateHighlights(value)
                    }

                case .filter:
                    FilterSelectionView(editingEngine: editingEngine)

                default:
                    EmptyView()
                }
            }
            .frame(height: 80)
            .padding(.horizontal)
        }
        .padding(.vertical)
    }
}

struct EditingToolButton: View {
    let tool: PhotoEditView.EditingTool
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: tool.icon)
                    .font(.title2)
                    .foregroundStyle(isSelected ? .yellow : .white)

                Text(tool.rawValue)
                    .font(.caption2)
                    .foregroundStyle(isSelected ? .yellow : .secondary)
            }
            .frame(width: 60, height: 60)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? .white.opacity(0.1) : .clear)
            )
        }
    }
}

struct AdjustmentSlider: View {
    let title: String
    let value: Float
    let range: ClosedRange<Float>
    let onChange: (Float) -> Void

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white)

                Spacer()

                Text(String(format: "%.2f", value))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Slider(
                value: Binding(
                    get: { value },
                    set: { newValue in
                        onChange(newValue)
                        HapticManager.HapticType.light.trigger()
                    }
                ),
                in: range
            )
            .tint(.yellow)
        }
    }
}

struct FilterSelectionView: View {
    @ObservedObject var editingEngine: PhotoEditingEngine

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ForEach(PhotoEditingEngine.ClothingFilter.allCases, id: \.self) { filter in
                    FilterPreviewButton(
                        filter: filter,
                        isSelected: editingEngine.adjustments.selectedFilter == filter
                    ) {
                        editingEngine.applyFilter(filter)
                        HapticManager.HapticType.selection.trigger()
                    }
                }
            }
            .padding(.horizontal)
        }
    }
}

struct FilterPreviewButton: View {
    let filter: PhotoEditingEngine.ClothingFilter
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? .yellow : .gray.opacity(0.3))
                    .frame(width: 50, height: 50)
                    .overlay(
                        Text(String(filter.rawValue.prefix(2)))
                            .font(.caption.weight(.bold))
                            .foregroundStyle(isSelected ? .black : .white)
                    )

                Text(filter.rawValue)
                    .font(.caption2)
                    .foregroundStyle(isSelected ? .yellow : .secondary)
            }
        }
    }
}

// MARK: - Overlays

struct CropOverlay: View {
    @Binding var cropRect: CGRect

    var body: some View {
        GeometryReader { geometry in
            Rectangle()
                .strokeBorder(.yellow, lineWidth: 2)
                .background(.black.opacity(0.5))
                .frame(
                    width: geometry.size.width * cropRect.width,
                    height: geometry.size.height * cropRect.height
                )
                .position(
                    x: geometry.size.width * (cropRect.minX + cropRect.width / 2),
                    y: geometry.size.height * (cropRect.minY + cropRect.height / 2)
                )
        }
    }
}

struct MagicWandSelectionOverlay: View {
    let points: [CGPoint]

    var body: some View {
        Canvas { context, size in
            for point in points {
                let rect = CGRect(
                    x: point.x - 2,
                    y: point.y - 2,
                    width: 4,
                    height: 4
                )
                context.fill(Path(ellipseIn: rect), with: .color(.yellow))
            }
        }
        .allowsHitTesting(false)
    }
}

struct ProcessingOverlay: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()

            GlassCardView {
                VStack(spacing: 16) {
                    ProMotionLoadingView()

                    Text("Processing...")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.primary)
                }
                .padding(24)
            }
        }
    }
}

#Preview {
    PhotoEditView(originalImage: UIImage(systemName: "photo")!) { _ in }
}