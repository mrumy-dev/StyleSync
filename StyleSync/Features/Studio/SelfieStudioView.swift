import SwiftUI
import SwiftData
import AVFoundation
import Vision
import CoreImage
import CoreImage.CIFilterBuiltins
import Photos
import PhotosUI

struct SelfieStudioView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var studioState = SelfieStudioState()
    @StateObject private var cameraManager = CameraManager()
    @StateObject private var analysisEngine = SelfieAnalysisEngine()
    @StateObject private var effectsProcessor = EffectsProcessor()
    @State private var selectedImage: UIImage?
    @State private var showingCamera = false
    @State private var showingPhotoPicker = false
    @State private var showingBeforeAfter = false
    @State private var showingInspirationBoard = false
    @State private var isAnalyzing = false

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ZStack {
                    // Studio Background
                    StudioBackgroundView()

                    if let image = selectedImage {
                        // Main Studio Interface
                        VStack(spacing: 0) {
                            // Image Preview Section
                            SelfiePreviewSection(
                                originalImage: image,
                                processedImage: studioState.processedImage,
                                showingBeforeAfter: $showingBeforeAfter,
                                geometry: geometry
                            )

                            // Effects Control Panel
                            EffectsControlPanel(
                                effects: $studioState.effects,
                                onEffectChange: { effect, value in
                                    applyEffect(effect, value: value, to: image)
                                }
                            )

                            // Analysis Results
                            if let analysis = studioState.currentAnalysis {
                                SelfieAnalysisPanel(
                                    analysis: analysis,
                                    onImprovementTap: showImprovementGuide,
                                    onSaveToBoard: saveToInspirationBoard
                                )
                            }
                        }
                    } else {
                        // Welcome/Capture State
                        SelfieStudioWelcomeView(
                            onCameraCapture: { showingCamera = true },
                            onPhotoLibrary: { showingPhotoPicker = true }
                        )
                    }

                    // Loading Overlay
                    if isAnalyzing {
                        AnalysisLoadingOverlay()
                    }

                    // Floating Action Buttons
                    VStack {
                        Spacer()
                        HStack {
                            if selectedImage != nil {
                                FloatingActionButton(
                                    icon: "photo.on.rectangle.angled",
                                    color: .blue,
                                    action: { showingInspirationBoard = true }
                                )

                                Spacer()

                                FloatingActionButton(
                                    icon: "arrow.up.arrow.down",
                                    color: .green,
                                    action: { showingBeforeAfter.toggle() }
                                )

                                Spacer()

                                FloatingActionButton(
                                    icon: "square.and.arrow.down",
                                    color: .purple,
                                    action: saveProcessedImage
                                )
                            }

                            Spacer()

                            FloatingActionButton(
                                icon: "camera.fill",
                                color: DesignSystem.Colors.accent,
                                action: { showingCamera = true }
                            )
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 100)
                    }
                }
            }
            .navigationTitle("Selfie Studio")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        StudioMenuView(
                            onSettings: showSettings,
                            onTutorial: showTutorial,
                            onClearPhoto: clearPhoto
                        )
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.title2)
                            .foregroundStyle(DesignSystem.Colors.accent)
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $showingCamera) {
            CameraView(onCapture: handleImageCapture)
        }
        .sheet(isPresented: $showingPhotoPicker) {
            PhotoPicker(onImageSelected: handleImageCapture)
        }
        .sheet(isPresented: $showingInspirationBoard) {
            InspirationBoardView()
                .presentationDetents([.large])
        }
        .environment(studioState)
    }

    private func handleImageCapture(_ image: UIImage) {
        selectedImage = image
        studioState.originalImage = image
        studioState.processedImage = image

        // Start analysis
        analyzeImage(image)
    }

    private func analyzeImage(_ image: UIImage) {
        isAnalyzing = true

        Task {
            let analysis = await analysisEngine.performDetailedAnalysis(image)

            await MainActor.run {
                studioState.currentAnalysis = analysis
                isAnalyzing = false
            }
        }

        HapticManager.HapticType.success.trigger()
    }

    private func applyEffect(_ effect: StudioEffect, value: Double, to image: UIImage) {
        Task {
            let processedImage = await effectsProcessor.applyEffect(
                effect,
                value: value,
                to: image,
                with: studioState.effects
            )

            await MainActor.run {
                studioState.processedImage = processedImage
            }
        }

        HapticManager.HapticType.lightImpact.trigger()
    }

    private func showImprovementGuide(_ improvement: ImprovementSuggestion) {
        studioState.selectedImprovement = improvement
        HapticManager.HapticType.selection.trigger()
    }

    private func saveToInspirationBoard() {
        guard let processedImage = studioState.processedImage,
              let analysis = studioState.currentAnalysis else { return }

        let inspiration = InspirationItem(
            id: UUID(),
            image: processedImage,
            analysis: analysis,
            effects: studioState.effects,
            createdAt: Date()
        )

        studioState.inspirationBoard.append(inspiration)
        HapticManager.HapticType.success.trigger()
    }

    private func saveProcessedImage() {
        guard let processedImage = studioState.processedImage else { return }

        UIImageWriteToSavedPhotosAlbum(processedImage, nil, nil, nil)
        HapticManager.HapticType.success.trigger()
    }

    private func clearPhoto() {
        selectedImage = nil
        studioState.reset()
        HapticManager.HapticType.selection.trigger()
    }

    private func showSettings() {
        HapticManager.HapticType.selection.trigger()
    }

    private func showTutorial() {
        HapticManager.HapticType.selection.trigger()
    }
}

// MARK: - Studio Background

struct StudioBackgroundView: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color.black.opacity(0.9),
                Color.gray.opacity(0.3),
                DesignSystem.Colors.background
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
        .overlay {
            // Professional studio grid pattern
            Canvas { context, size in
                let spacing: CGFloat = 40
                let lineWidth: CGFloat = 0.5

                for x in stride(from: 0, through: size.width, by: spacing) {
                    context.stroke(
                        Path { path in
                            path.move(to: CGPoint(x: x, y: 0))
                            path.addLine(to: CGPoint(x: x, y: size.height))
                        },
                        with: .color(.white.opacity(0.05)),
                        lineWidth: lineWidth
                    )
                }

                for y in stride(from: 0, through: size.height, by: spacing) {
                    context.stroke(
                        Path { path in
                            path.move(to: CGPoint(x: 0, y: y))
                            path.addLine(to: CGPoint(x: size.width, y: y))
                        },
                        with: .color(.white.opacity(0.05)),
                        lineWidth: lineWidth
                    )
                }
            }
        }
    }
}

// MARK: - Selfie Preview Section

struct SelfiePreviewSection: View {
    let originalImage: UIImage
    let processedImage: UIImage?
    @Binding var showingBeforeAfter: Bool
    let geometry: GeometryProxy

    var body: some View {
        ZStack {
            if showingBeforeAfter {
                BeforeAfterComparisonView(
                    originalImage: originalImage,
                    processedImage: processedImage ?? originalImage
                )
            } else {
                // Main preview
                Image(uiImage: processedImage ?? originalImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: geometry.size.height * 0.5)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(DesignSystem.Colors.accent.opacity(0.3), lineWidth: 2)
                    )
                    .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
            }

            // Privacy Blur Toggle
            VStack {
                HStack {
                    Spacer()
                    PrivacyBlurToggle()
                    .padding(.trailing, 16)
                    .padding(.top, 16)
                }
                Spacer()
            }
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - Before/After Comparison

struct BeforeAfterComparisonView: View {
    let originalImage: UIImage
    let processedImage: UIImage
    @State private var dividerPosition: CGFloat = 0.5

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Processed image (full)
                Image(uiImage: processedImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)

                // Original image (clipped)
                Image(uiImage: originalImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .mask(
                        Rectangle()
                            .frame(width: geometry.size.width * dividerPosition)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    )

                // Divider
                Rectangle()
                    .frame(width: 2)
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.5), radius: 2)
                    .position(x: geometry.size.width * dividerPosition, y: geometry.size.height / 2)

                // Drag handle
                Circle()
                    .fill(.white)
                    .frame(width: 30, height: 30)
                    .shadow(color: .black.opacity(0.3), radius: 4)
                    .position(x: geometry.size.width * dividerPosition, y: geometry.size.height / 2)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                let newPosition = max(0.1, min(0.9, value.location.x / geometry.size.width))
                                dividerPosition = newPosition
                            }
                    )

                // Labels
                VStack {
                    Spacer()
                    HStack {
                        Text("Before")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(.black.opacity(0.6))
                            )

                        Spacer()

                        Text("After")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(.black.opacity(0.6))
                            )
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Privacy Blur Toggle

struct PrivacyBlurToggle: View {
    @State private var isBlurred = false

    var body: some View {
        Button(action: {
            isBlurred.toggle()
            HapticManager.HapticType.selection.trigger()
        }) {
            HStack(spacing: 6) {
                Image(systemName: isBlurred ? "eye.slash.fill" : "eye.fill")
                    .font(.caption)

                Text(isBlurred ? "Blur" : "Clear")
                    .font(.caption.weight(.medium))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(.black.opacity(0.6))
                    .stroke(.white.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(SpringButtonStyle())
    }
}

// MARK: - Effects Control Panel

struct EffectsControlPanel: View {
    @Binding var effects: StudioEffects
    let onEffectChange: (StudioEffect, Double) -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("Effects")
                .font(.headline.weight(.medium))
                .foregroundStyle(DesignSystem.Colors.primary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 20) {
                    EffectSlider(
                        title: "Portrait",
                        icon: "person.crop.circle",
                        value: $effects.portraitIntensity,
                        color: .blue
                    ) { value in
                        onEffectChange(.portraitMode, value)
                    }

                    EffectSlider(
                        title: "Lighting",
                        icon: "lightbulb",
                        value: $effects.lightingIntensity,
                        color: .yellow
                    ) { value in
                        onEffectChange(.lighting, value)
                    }

                    EffectSlider(
                        title: "Background",
                        icon: "photo",
                        value: $effects.backgroundBlur,
                        color: .green
                    ) { value in
                        onEffectChange(.backgroundBlur, value)
                    }

                    EffectSlider(
                        title: "Warmth",
                        icon: "sun.max",
                        value: $effects.warmth,
                        color: .orange
                    ) { value in
                        onEffectChange(.warmth, value)
                    }

                    EffectSlider(
                        title: "Contrast",
                        icon: "circle.righthalf.filled",
                        value: $effects.contrast,
                        color: .purple
                    ) { value in
                        onEffectChange(.contrast, value)
                    }

                    EffectSlider(
                        title: "Saturation",
                        icon: "paintbrush",
                        value: $effects.saturation,
                        color: .pink
                    ) { value in
                        onEffectChange(.saturation, value)
                    }
                }
                .padding(.horizontal, 20)
            }

            // Preset Effects
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(EffectPreset.allCases, id: \.self) { preset in
                        EffectPresetButton(preset: preset) {
                            applyPreset(preset)
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
        .padding(.vertical, 16)
        .background(
            GlassCardView(
                cornerRadius: 16,
                blurRadius: 20,
                opacity: 0.1
            ) {
                Rectangle().fill(.clear)
            }
        )
        .padding(.horizontal, 20)
    }

    private func applyPreset(_ preset: EffectPreset) {
        withAnimation(.easeInOut(duration: 0.3)) {
            effects = preset.effects
        }

        // Apply all effects
        for effect in StudioEffect.allCases {
            onEffectChange(effect, effects.value(for: effect))
        }

        HapticManager.HapticType.success.trigger()
    }
}

// MARK: - Effect Slider

struct EffectSlider: View {
    let title: String
    let icon: String
    @Binding var value: Double
    let color: Color
    let onValueChange: (Double) -> Void

    var body: some View {
        VStack(spacing: 12) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.2))
                        .frame(width: 50, height: 50)

                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundStyle(color)
                }

                Text(title)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(DesignSystem.Colors.primary)
            }

            VStack(spacing: 8) {
                Slider(value: $value, in: 0...1) { _ in
                    onValueChange(value)
                }
                .tint(color)
                .frame(width: 80)

                Text("\(Int(value * 100))")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(DesignSystem.Colors.secondary)
            }
        }
        .frame(width: 100)
    }
}

// MARK: - Effect Preset Button

struct EffectPresetButton: View {
    let preset: EffectPreset
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Text(preset.name)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(DesignSystem.Colors.primary)

                Text(preset.description)
                    .font(.caption2)
                    .foregroundStyle(DesignSystem.Colors.secondary)
                    .lineLimit(2)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(preset.color.opacity(0.1))
                    .stroke(preset.color.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(SpringButtonStyle())
    }
}

// MARK: - Selfie Analysis Panel

struct SelfieAnalysisPanel: View {
    let analysis: SelfieAnalysis
    let onImprovementTap: (ImprovementSuggestion) -> Void
    let onSaveToBoard: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            // Overall Score
            HStack {
                Text("Style Analysis")
                    .font(.headline.weight(.medium))
                    .foregroundStyle(DesignSystem.Colors.primary)

                Spacer()

                OverallScoreView(score: analysis.overallScore)
            }

            // Detailed Scores
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                ScoreCard(title: "Fit", score: analysis.fitScore, color: .blue)
                ScoreCard(title: "Color", score: analysis.colorScore, color: .green)
                ScoreCard(title: "Style", score: analysis.styleScore, color: .purple)
                ScoreCard(title: "Overall", score: analysis.overallScore, color: .orange)
            }

            // Improvement Suggestions
            if !analysis.improvements.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Improvement Suggestions")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(DesignSystem.Colors.primary)

                    ForEach(analysis.improvements.prefix(3), id: \.id) { improvement in
                        ImprovementSuggestionCard(
                            improvement: improvement,
                            onTap: { onImprovementTap(improvement) }
                        )
                    }
                }
            }

            // Action Buttons
            HStack(spacing: 12) {
                Button("View Guide") {
                    if let firstImprovement = analysis.improvements.first {
                        onImprovementTap(firstImprovement)
                    }
                }
                .buttonStyle(PrimaryButtonStyle())

                Button("Save Look") {
                    onSaveToBoard()
                }
                .buttonStyle(SecondaryButtonStyle())
            }
        }
        .padding(20)
        .background(
            GlassCardView(
                cornerRadius: 16,
                blurRadius: 20,
                opacity: 0.1
            ) {
                Rectangle().fill(.clear)
            }
        )
        .padding(.horizontal, 20)
    }
}

// MARK: - Score Views

struct OverallScoreView: View {
    let score: Double

    var body: some View {
        HStack(spacing: 8) {
            Text("\(String(format: "%.1f", score))")
                .font(.title2.weight(.bold))
                .foregroundStyle(scoreColor)

            Text("/10")
                .font(.caption)
                .foregroundStyle(DesignSystem.Colors.secondary)

            ZStack {
                Circle()
                    .stroke(DesignSystem.Colors.surface, lineWidth: 3)
                    .frame(width: 30, height: 30)

                Circle()
                    .trim(from: 0, to: score / 10)
                    .stroke(scoreColor, lineWidth: 3)
                    .frame(width: 30, height: 30)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 1.0), value: score)
            }
        }
    }

    private var scoreColor: Color {
        switch score {
        case 8...: return .green
        case 6..<8: return .orange
        default: return .red
        }
    }
}

struct ScoreCard: View {
    let title: String
    let score: Double
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(DesignSystem.Colors.primary)

            Text("\(String(format: "%.1f", score))")
                .font(.title3.weight(.semibold))
                .foregroundStyle(color)

            ProgressView(value: score, total: 10)
                .tint(color)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(color.opacity(0.1))
        )
    }
}

// MARK: - Improvement Suggestion Card

struct ImprovementSuggestionCard: View {
    let improvement: ImprovementSuggestion
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: improvement.icon)
                    .font(.title2)
                    .foregroundStyle(improvement.priority.color)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 4) {
                    Text(improvement.title)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(DesignSystem.Colors.primary)
                        .lineLimit(1)

                    Text(improvement.description)
                        .font(.caption)
                        .foregroundStyle(DesignSystem.Colors.secondary)
                        .lineLimit(2)
                }

                Spacer()

                VStack(spacing: 4) {
                    Text(improvement.priority.displayName)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(improvement.priority.color)

                    if improvement.impact > 0 {
                        Text("+\(String(format: "%.1f", improvement.impact))")
                            .font(.caption2)
                            .foregroundStyle(.green)
                    }
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(DesignSystem.Colors.surface)
                    .stroke(improvement.priority.color.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(SpringButtonStyle())
    }
}

// MARK: - Studio Welcome View

struct SelfieStudioWelcomeView: View {
    let onCameraCapture: () -> Void
    let onPhotoLibrary: () -> Void

    var body: some View {
        VStack(spacing: 32) {
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    DesignSystem.Colors.accent.opacity(0.3),
                                    DesignSystem.Colors.primary.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 120, height: 120)

                    Image(systemName: "camera.aperture")
                        .font(.system(size: 50))
                        .foregroundStyle(DesignSystem.Colors.accent)
                }

                VStack(spacing: 12) {
                    Text("Professional Selfie Studio")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(DesignSystem.Colors.primary)

                    Text("Get detailed style analysis with AI-powered recommendations")
                        .font(.body)
                        .foregroundStyle(DesignSystem.Colors.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
            }

            VStack(spacing: 16) {
                Button(action: onCameraCapture) {
                    HStack {
                        Image(systemName: "camera.fill")
                            .font(.title2)

                        Text("Take Photo")
                            .font(.headline.weight(.medium))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [DesignSystem.Colors.accent, DesignSystem.Colors.accent.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(SpringButtonStyle())

                Button(action: onPhotoLibrary) {
                    HStack {
                        Image(systemName: "photo")
                            .font(.title2)

                        Text("Choose from Library")
                            .font(.headline.weight(.medium))
                    }
                    .foregroundStyle(DesignSystem.Colors.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(DesignSystem.Colors.surface)
                            .stroke(DesignSystem.Colors.accent.opacity(0.3), lineWidth: 2)
                    )
                }
                .buttonStyle(SpringButtonStyle())
            }
            .padding(.horizontal, 32)

            // Feature Highlights
            VStack(spacing: 12) {
                Text("Features")
                    .font(.headline.weight(.medium))
                    .foregroundStyle(DesignSystem.Colors.primary)

                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                    FeatureHighlight(
                        icon: "eye.fill",
                        title: "Portrait Effects",
                        color: .blue
                    )

                    FeatureHighlight(
                        icon: "chart.bar.fill",
                        title: "Detailed Analysis",
                        color: .green
                    )

                    FeatureHighlight(
                        icon: "lightbulb.fill",
                        title: "Smart Suggestions",
                        color: .orange
                    )

                    FeatureHighlight(
                        icon: "heart.fill",
                        title: "Save Looks",
                        color: .pink
                    )
                }
            }
            .padding(.horizontal, 32)
        }
    }
}

struct FeatureHighlight: View {
    let icon: String
    let title: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)

            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(DesignSystem.Colors.primary)
                .multilineTextAlignment(.center)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(color.opacity(0.1))
        )
    }
}

// MARK: - Analysis Loading Overlay

struct AnalysisLoadingOverlay: View {
    @State private var rotationAngle: Double = 0

    var body: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .stroke(DesignSystem.Colors.accent.opacity(0.3), lineWidth: 4)
                        .frame(width: 60, height: 60)

                    Circle()
                        .trim(from: 0, to: 0.7)
                        .stroke(DesignSystem.Colors.accent, lineWidth: 4)
                        .frame(width: 60, height: 60)
                        .rotationEffect(.degrees(rotationAngle))
                        .animation(
                            .linear(duration: 1.0)
                            .repeatForever(autoreverses: false),
                            value: rotationAngle
                        )
                }

                VStack(spacing: 8) {
                    Text("Analyzing Your Style")
                        .font(.headline.weight(.medium))
                        .foregroundStyle(.white)

                    Text("Our AI is examining fit, colors, and style elements")
                        .font(.body)
                        .foregroundStyle(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                }
            }
            .padding(32)
            .background(
                GlassCardView(
                    cornerRadius: 16,
                    blurRadius: 20,
                    opacity: 0.2
                ) {
                    Rectangle().fill(.clear)
                }
            )
            .padding(40)
        }
        .onAppear {
            rotationAngle = 360
        }
    }
}

// MARK: - Floating Action Button

struct FloatingActionButton: View {
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.white)
                .frame(width: 50, height: 50)
                .background(
                    Circle()
                        .fill(color)
                        .shadow(color: color.opacity(0.3), radius: 10, y: 5)
                )
        }
        .buttonStyle(SpringButtonStyle())
    }
}

// MARK: - Data Models and State

@MainActor
class SelfieStudioState: ObservableObject {
    @Published var originalImage: UIImage?
    @Published var processedImage: UIImage?
    @Published var currentAnalysis: SelfieAnalysis?
    @Published var effects = StudioEffects()
    @Published var selectedImprovement: ImprovementSuggestion?
    @Published var inspirationBoard: [InspirationItem] = []

    func reset() {
        originalImage = nil
        processedImage = nil
        currentAnalysis = nil
        effects = StudioEffects()
        selectedImprovement = nil
    }
}

struct StudioEffects {
    var portraitIntensity: Double = 0.5
    var lightingIntensity: Double = 0.5
    var backgroundBlur: Double = 0.0
    var warmth: Double = 0.5
    var contrast: Double = 0.5
    var saturation: Double = 0.5

    func value(for effect: StudioEffect) -> Double {
        switch effect {
        case .portraitMode: return portraitIntensity
        case .lighting: return lightingIntensity
        case .backgroundBlur: return backgroundBlur
        case .warmth: return warmth
        case .contrast: return contrast
        case .saturation: return saturation
        }
    }
}

enum StudioEffect: CaseIterable {
    case portraitMode
    case lighting
    case backgroundBlur
    case warmth
    case contrast
    case saturation
}

enum EffectPreset: CaseIterable {
    case natural
    case dramatic
    case vintage
    case bright
    case moody

    var name: String {
        switch self {
        case .natural: return "Natural"
        case .dramatic: return "Dramatic"
        case .vintage: return "Vintage"
        case .bright: return "Bright"
        case .moody: return "Moody"
        }
    }

    var description: String {
        switch self {
        case .natural: return "Subtle enhancement"
        case .dramatic: return "Bold lighting"
        case .vintage: return "Warm & classic"
        case .bright: return "High contrast"
        case .moody: return "Dark & artistic"
        }
    }

    var color: Color {
        switch self {
        case .natural: return .green
        case .dramatic: return .red
        case .vintage: return .orange
        case .bright: return .yellow
        case .moody: return .purple
        }
    }

    var effects: StudioEffects {
        switch self {
        case .natural:
            return StudioEffects(
                portraitIntensity: 0.3,
                lightingIntensity: 0.4,
                backgroundBlur: 0.2,
                warmth: 0.6,
                contrast: 0.5,
                saturation: 0.5
            )
        case .dramatic:
            return StudioEffects(
                portraitIntensity: 0.8,
                lightingIntensity: 0.9,
                backgroundBlur: 0.7,
                warmth: 0.4,
                contrast: 0.8,
                saturation: 0.7
            )
        case .vintage:
            return StudioEffects(
                portraitIntensity: 0.5,
                lightingIntensity: 0.6,
                backgroundBlur: 0.3,
                warmth: 0.8,
                contrast: 0.6,
                saturation: 0.4
            )
        case .bright:
            return StudioEffects(
                portraitIntensity: 0.6,
                lightingIntensity: 0.8,
                backgroundBlur: 0.4,
                warmth: 0.5,
                contrast: 0.9,
                saturation: 0.8
            )
        case .moody:
            return StudioEffects(
                portraitIntensity: 0.7,
                lightingIntensity: 0.3,
                backgroundBlur: 0.8,
                warmth: 0.3,
                contrast: 0.7,
                saturation: 0.3
            )
        }
    }
}

struct SelfieAnalysis {
    let overallScore: Double
    let fitScore: Double
    let colorScore: Double
    let styleScore: Double
    let improvements: [ImprovementSuggestion]
    let colorHarmony: ColorHarmonyAnalysis
    let fitAssessment: FitAssessment
    let accessories: [AccessorySuggestion]
    let alternativeOutfits: [OutfitMockup]
}

struct ImprovementSuggestion: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let icon: String
    let priority: ImprovementPriority
    let impact: Double
    let category: ImprovementCategory
}

enum ImprovementPriority {
    case high, medium, low

    var color: Color {
        switch self {
        case .high: return .red
        case .medium: return .orange
        case .low: return .blue
        }
    }

    var displayName: String {
        switch self {
        case .high: return "High"
        case .medium: return "Medium"
        case .low: return "Low"
        }
    }
}

enum ImprovementCategory {
    case fit, color, style, accessories
}

struct ColorHarmonyAnalysis {
    let dominantColors: [Color]
    let harmonyScore: Double
    let suggestions: [ColorSuggestion]
}

struct ColorSuggestion {
    let color: Color
    let reason: String
    let confidence: Double
}

struct FitAssessment {
    let overallFit: FitQuality
    let shoulderFit: FitQuality
    let bodyFit: FitQuality
    let lengthFit: FitQuality
    let suggestions: [FitSuggestion]
}

struct FitSuggestion {
    let area: String
    let suggestion: String
    let priority: ImprovementPriority
}

struct AccessorySuggestion: Identifiable {
    let id = UUID()
    let name: String
    let category: String
    let reason: String
    let visualizationURL: URL?
}

struct InspirationItem: Identifiable {
    let id: UUID
    let image: UIImage
    let analysis: SelfieAnalysis
    let effects: StudioEffects
    let createdAt: Date
}

// MARK: - Analysis Engine

class SelfieAnalysisEngine: ObservableObject {
    private let aiEngine = AIStyleEngine.shared

    func performDetailedAnalysis(_ image: UIImage) async -> SelfieAnalysis {
        // Simulate comprehensive analysis
        try? await Task.sleep(nanoseconds: 3_000_000_000)

        let improvements = [
            ImprovementSuggestion(
                title: "Adjust Collar",
                description: "A slightly higher collar would enhance your neckline",
                icon: "person.crop.rectangle",
                priority: .medium,
                impact: 0.8,
                category: .fit
            ),
            ImprovementSuggestion(
                title: "Add Statement Jewelry",
                description: "A bold necklace would elevate this look",
                icon: "circle.grid.2x2",
                priority: .high,
                impact: 1.2,
                category: .accessories
            ),
            ImprovementSuggestion(
                title: "Color Coordination",
                description: "Consider warmer tones to complement your complexion",
                icon: "paintpalette",
                priority: .low,
                impact: 0.6,
                category: .color
            )
        ]

        return SelfieAnalysis(
            overallScore: 7.8,
            fitScore: 8.2,
            colorScore: 7.1,
            styleScore: 8.0,
            improvements: improvements,
            colorHarmony: ColorHarmonyAnalysis(
                dominantColors: [.blue, .white, .gray],
                harmonyScore: 0.75,
                suggestions: []
            ),
            fitAssessment: FitAssessment(
                overallFit: .good,
                shoulderFit: .good,
                bodyFit: .excellent,
                lengthFit: .good,
                suggestions: []
            ),
            accessories: [],
            alternativeOutfits: []
        )
    }
}

// MARK: - Effects Processor

class EffectsProcessor: ObservableObject {
    private let context = CIContext()

    func applyEffect(_ effect: StudioEffect, value: Double, to image: UIImage, with effects: StudioEffects) async -> UIImage {
        guard let ciImage = CIImage(image: image) else { return image }

        var outputImage = ciImage

        // Apply portrait mode effect
        if effects.portraitIntensity > 0 {
            outputImage = applyPortraitEffect(to: outputImage, intensity: effects.portraitIntensity)
        }

        // Apply lighting adjustments
        if effects.lightingIntensity != 0.5 {
            outputImage = applyLightingEffect(to: outputImage, intensity: effects.lightingIntensity)
        }

        // Apply background blur
        if effects.backgroundBlur > 0 {
            outputImage = applyBackgroundBlur(to: outputImage, intensity: effects.backgroundBlur)
        }

        // Apply color adjustments
        outputImage = applyColorAdjustments(
            to: outputImage,
            warmth: effects.warmth,
            contrast: effects.contrast,
            saturation: effects.saturation
        )

        guard let cgImage = context.createCGImage(outputImage, from: outputImage.extent) else {
            return image
        }

        return UIImage(cgImage: cgImage)
    }

    private func applyPortraitEffect(to image: CIImage, intensity: Double) -> CIImage {
        // Simulate portrait mode with depth effect
        let depthBlur = CIFilter.maskedVariableBlur()
        depthBlur.inputImage = image
        depthBlur.radius = Float(intensity * 20)
        return depthBlur.outputImage ?? image
    }

    private func applyLightingEffect(to image: CIImage, intensity: Double) -> CIImage {
        let exposure = CIFilter.exposureAdjust()
        exposure.inputImage = image
        exposure.ev = Float((intensity - 0.5) * 2.0)
        return exposure.outputImage ?? image
    }

    private func applyBackgroundBlur(to image: CIImage, intensity: Double) -> CIImage {
        let blur = CIFilter.gaussianBlur()
        blur.inputImage = image
        blur.radius = Float(intensity * 10)
        return blur.outputImage ?? image
    }

    private func applyColorAdjustments(to image: CIImage, warmth: Double, contrast: Double, saturation: Double) -> CIImage {
        var outputImage = image

        // Temperature adjustment
        let temperature = CIFilter.temperatureAndTint()
        temperature.inputImage = outputImage
        temperature.neutral = CIVector(x: 6500 + (warmth - 0.5) * 2000, y: 0)
        outputImage = temperature.outputImage ?? outputImage

        // Contrast adjustment
        let contrastFilter = CIFilter.colorControls()
        contrastFilter.inputImage = outputImage
        contrastFilter.contrast = Float(0.5 + (contrast - 0.5) * 1.0)
        outputImage = contrastFilter.outputImage ?? outputImage

        // Saturation adjustment
        let saturationFilter = CIFilter.colorControls()
        saturationFilter.inputImage = outputImage
        saturationFilter.saturation = Float(0.5 + (saturation - 0.5) * 1.0)
        outputImage = saturationFilter.outputImage ?? outputImage

        return outputImage
    }
}

// MARK: - Supporting Views

struct CameraView: UIViewControllerRepresentable {
    let onCapture: (UIImage) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        picker.cameraDevice = .front
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraView

        init(_ parent: CameraView) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.onCapture(image)
            }
            picker.dismiss(animated: true)
        }
    }
}

struct PhotoPicker: UIViewControllerRepresentable {
    let onImageSelected: (UIImage) -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1

        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: PhotoPicker

        init(_ parent: PhotoPicker) {
            self.parent = parent
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)

            guard let provider = results.first?.itemProvider,
                  provider.canLoadObject(ofClass: UIImage.self) else { return }

            provider.loadObject(ofClass: UIImage.self) { image, _ in
                DispatchQueue.main.async {
                    if let image = image as? UIImage {
                        self.parent.onImageSelected(image)
                    }
                }
            }
        }
    }
}

struct InspirationBoardView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack {
                Text("Inspiration Board")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(DesignSystem.Colors.primary)

                Text("Your saved looks and style inspirations")
                    .font(.body)
                    .foregroundStyle(DesignSystem.Colors.secondary)

                Spacer()

                // Grid of saved inspirations would go here
                Text("No saved looks yet")
                    .font(.body)
                    .foregroundStyle(DesignSystem.Colors.secondary)

                Spacer()
            }
            .padding(24)
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

struct StudioMenuView: View {
    let onSettings: () -> Void
    let onTutorial: () -> Void
    let onClearPhoto: () -> Void

    var body: some View {
        Button("Tutorial") {
            onTutorial()
        }

        Button("Settings") {
            onSettings()
        }

        Divider()

        Button("Clear Photo", role: .destructive) {
            onClearPhoto()
        }
    }
}

// MARK: - Button Styles

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(DesignSystem.Colors.accent)
            .clipShape(Capsule())
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.medium))
            .foregroundStyle(DesignSystem.Colors.primary)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .stroke(DesignSystem.Colors.accent.opacity(0.3), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: configuration.isPressed)
    }
}

class CameraManager: ObservableObject {
    // Camera management would go here
}

#Preview {
    SelfieStudioView()
        .modelContainer(for: [StyleItem.self], inMemory: true)
}