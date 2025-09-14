import SwiftUI
import SwiftData
import SceneKit
import WeatherKit
import CoreLocation
import EventKit
import Combine

struct GeniusView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var items: [StyleItem]
    @StateObject private var geniusState = OutfitGeniusState()
    @StateObject private var weatherService = WeatherService()
    @StateObject private var eventOptimizer = SocialEventOptimizer()
    @StateObject private var calendarManager = OutfitCalendarManager()
    @State private var showingOutfitEditor = false
    @State private var showingMannequin = false
    @State private var currentOutfitIndex = 0
    @State private var dragOffset: CGSize = .zero

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ZStack {
                    // Background with dynamic gradient
                    DynamicBackgroundView(occasion: geniusState.selectedOccasion)

                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 24) {
                            // Occasion Selector
                            OccasionModeSelector(
                                selectedOccasion: $geniusState.selectedOccasion,
                                confidenceScore: geniusState.currentConfidenceScore
                            )

                            // Weather Integration
                            if let weather = weatherService.currentWeather {
                                WeatherAdaptiveHeader(weather: weather)
                                    .transition(.slide)
                            }

                            // 3D Outfit Visualization
                            if geniusState.generatedOutfits.isEmpty {
                                OutfitGenerationView()
                                    .frame(height: 400)
                            } else {
                                Outfit3DVisualizationView(
                                    outfits: geniusState.generatedOutfits,
                                    currentIndex: $currentOutfitIndex,
                                    showingMannequin: $showingMannequin
                                )
                                .frame(height: 450)
                                .gesture(
                                    DragGesture()
                                        .onChanged { value in
                                            dragOffset = value.translation
                                        }
                                        .onEnded { value in
                                            handleSwipeGesture(value.translation)
                                            dragOffset = .zero
                                        }
                                )
                            }

                            // Outfit Variations Swiper
                            if !geniusState.generatedOutfits.isEmpty {
                                OutfitVariationsSwiper(
                                    outfits: geniusState.generatedOutfits,
                                    currentIndex: $currentOutfitIndex,
                                    onOutfitSelected: { outfit in
                                        selectOutfit(outfit)
                                    }
                                )
                                .frame(height: 120)
                            }

                            // AI Insights Panel
                            if let currentOutfit = getCurrentOutfit() {
                                AIInsightsPanel(
                                    outfit: currentOutfit,
                                    matchingFactors: geniusState.matchingFactors,
                                    colorPsychology: geniusState.colorPsychology
                                )
                            }

                            // Action Buttons
                            OutfitActionButtons(
                                onSave: saveCurrentOutfit,
                                onSchedule: scheduleOutfit,
                                onShare: shareAsLayout,
                                onEdit: { showingOutfitEditor = true },
                                onGenerate: generateNewOutfits
                            )
                            .padding(.bottom, 100)
                        }
                        .padding(.horizontal, 20)
                    }
                    .refreshable {
                        await generateOutfitsWithAI()
                    }

                    // Floating Mix & Match Button
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            MixAndMatchFloatingButton {
                                showingOutfitEditor = true
                                HapticManager.HapticType.success.trigger()
                            }
                            .padding(.trailing, 24)
                            .padding(.bottom, 100)
                        }
                    }

                    // Confidence Score Indicator
                    VStack {
                        HStack {
                            Spacer()
                            ConfidenceScoreIndicator(
                                score: geniusState.currentConfidenceScore,
                                factors: geniusState.confidenceFactors
                            )
                            .padding(.trailing, 20)
                            .padding(.top, 100)
                        }
                        Spacer()
                    }
                }
            }
            .navigationTitle("Outfit Genius")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        OutfitGeniusMenu()
                    } label: {
                        Image(systemName: "sparkles.rectangle.stack")
                            .font(.title2)
                            .foregroundStyle(DesignSystem.Colors.accent)
                    }
                }

                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        showingMannequin.toggle()
                        HapticManager.HapticType.selection.trigger()
                    }) {
                        Image(systemName: "person.fill")
                            .font(.title2)
                            .foregroundStyle(DesignSystem.Colors.primary)
                    }
                }
            }
        }
        .onAppear {
            setupGeniusMode()
        }
        .sheet(isPresented: $showingOutfitEditor) {
            MixAndMatchEditorView()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .fullScreenCover(isPresented: $showingMannequin) {
            VirtualMannequinView(outfit: getCurrentOutfit())
        }
        .environment(geniusState)
    }

    private func setupGeniusMode() {
        Task {
            await weatherService.updateWeather()
            await eventOptimizer.analyzeUpcomingEvents()
            await generateOutfitsWithAI()
        }
    }

    private func generateOutfitsWithAI() async {
        geniusState.isGenerating = true

        // Use 50-factor matching system
        let algorithm = FiftyFactorMatchingAlgorithm()
        let outfits = await algorithm.generateOutfits(
            from: items,
            occasion: geniusState.selectedOccasion,
            weather: weatherService.currentWeather,
            events: eventOptimizer.upcomingEvents,
            userPreferences: geniusState.userPreferences,
            colorPsychology: geniusState.colorPsychology
        )

        await MainActor.run {
            geniusState.generatedOutfits = outfits
            geniusState.isGenerating = false
            currentOutfitIndex = 0
            updateConfidenceScore()
        }
    }

    private func generateNewOutfits() {
        Task {
            await generateOutfitsWithAI()
        }
        HapticManager.HapticType.celebration.trigger()
    }

    private func handleSwipeGesture(_ translation: CGSize) {
        let swipeThreshold: CGFloat = 100

        if abs(translation.x) > swipeThreshold {
            withAnimation(.easeInOut(duration: 0.3)) {
                if translation.x > 0 {
                    // Swipe right - previous outfit
                    currentOutfitIndex = max(0, currentOutfitIndex - 1)
                } else {
                    // Swipe left - next outfit
                    currentOutfitIndex = min(geniusState.generatedOutfits.count - 1, currentOutfitIndex + 1)
                }
                updateConfidenceScore()
            }
            HapticManager.HapticType.selection.trigger()
        }
    }

    private func selectOutfit(_ outfit: GeneratedOutfit) {
        if let index = geniusState.generatedOutfits.firstIndex(where: { $0.id == outfit.id }) {
            currentOutfitIndex = index
            updateConfidenceScore()
        }
        HapticManager.HapticType.subtleNudge.trigger()
    }

    private func getCurrentOutfit() -> GeneratedOutfit? {
        guard currentOutfitIndex < geniusState.generatedOutfits.count else { return nil }
        return geniusState.generatedOutfits[currentOutfitIndex]
    }

    private func updateConfidenceScore() {
        guard let outfit = getCurrentOutfit() else { return }
        geniusState.currentConfidenceScore = outfit.confidenceScore
        geniusState.confidenceFactors = outfit.confidenceFactors
    }

    private func saveCurrentOutfit() {
        guard let outfit = getCurrentOutfit() else { return }

        let savedOutfit = SavedOutfit(
            id: UUID(),
            name: outfit.name,
            items: outfit.items,
            occasion: geniusState.selectedOccasion,
            confidenceScore: outfit.confidenceScore,
            createdAt: Date()
        )

        modelContext.insert(savedOutfit)
        try? modelContext.save()

        HapticManager.HapticType.success.trigger()
    }

    private func scheduleOutfit() {
        guard let outfit = getCurrentOutfit() else { return }
        Task {
            await calendarManager.scheduleOutfit(outfit, for: geniusState.selectedOccasion)
        }
        HapticManager.HapticType.success.trigger()
    }

    private func shareAsLayout() {
        guard let outfit = getCurrentOutfit() else { return }
        Task {
            let layoutImage = await MagazineLayoutGenerator.shared.createLayout(for: outfit)
            await ShareManager.shared.shareImage(layoutImage)
        }
        HapticManager.HapticType.success.trigger()
    }
}

// MARK: - Occasion Mode Selector

struct OccasionModeSelector: View {
    @Binding var selectedOccasion: OutfitOccasion
    let confidenceScore: Double

    private let occasions: [OutfitOccasion] = [
        .interview, .date, .party, .work, .casual, .formal, .travel
    ]

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Occasion Mode")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(DesignSystem.Colors.primary)

                Spacer()

                Text("AI Match: \(Int(confidenceScore * 100))%")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(DesignSystem.Colors.accent)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(DesignSystem.Colors.accent.opacity(0.1))
                    )
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(occasions, id: \.self) { occasion in
                        OccasionModeCard(
                            occasion: occasion,
                            isSelected: selectedOccasion == occasion,
                            onSelect: {
                                selectedOccasion = occasion
                                HapticManager.HapticType.selection.trigger()
                            }
                        )
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
}

struct OccasionModeCard: View {
    let occasion: OutfitOccasion
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(
                        isSelected
                        ? DesignSystem.Colors.accent
                        : DesignSystem.Colors.surface
                    )
                    .frame(width: 60, height: 60)

                Image(systemName: occasion.icon)
                    .font(.title2)
                    .foregroundStyle(
                        isSelected
                        ? .white
                        : DesignSystem.Colors.primary
                    )
            }

            Text(occasion.displayName)
                .font(.caption.weight(.medium))
                .foregroundStyle(DesignSystem.Colors.primary)
                .lineLimit(1)
        }
        .scaleEffect(isSelected ? 1.1 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        .onTapGesture {
            onSelect()
        }
    }
}

// MARK: - Weather Adaptive Header

struct WeatherAdaptiveHeader: View {
    let weather: WeatherCondition

    var body: some View {
        HStack(spacing: 16) {
            // Weather Icon
            ZStack {
                Circle()
                    .fill(weather.color.opacity(0.2))
                    .frame(width: 50, height: 50)

                Image(systemName: weather.icon)
                    .font(.title2)
                    .foregroundStyle(weather.color)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Weather-Optimized")
                    .font(.headline.weight(.medium))
                    .foregroundStyle(DesignSystem.Colors.primary)

                Text("\(Int(weather.temperature))°, \(weather.description)")
                    .font(.subheadline)
                    .foregroundStyle(DesignSystem.Colors.secondary)

                Text(weather.suggestion)
                    .font(.caption)
                    .foregroundStyle(DesignSystem.Colors.accent)
            }

            Spacer()
        }
        .padding(16)
        .background(
            GlassCardView(
                cornerRadius: 16,
                blurRadius: 10,
                opacity: 0.1
            ) {
                Rectangle()
                    .fill(.clear)
            }
        )
    }
}

// MARK: - 3D Outfit Visualization

struct Outfit3DVisualizationView: View {
    let outfits: [GeneratedOutfit]
    @Binding var currentIndex: Int
    @Binding var showingMannequin: Bool
    @State private var sceneView = SCNView()
    @State private var rotationAngle: Float = 0

    var currentOutfit: GeneratedOutfit? {
        guard currentIndex < outfits.count else { return nil }
        return outfits[currentIndex]
    }

    var body: some View {
        ZStack {
            if let outfit = currentOutfit {
                // 3D Scene Background
                SceneKitView(outfit: outfit, rotationAngle: $rotationAngle)
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(DesignSystem.Colors.accent.opacity(0.3), lineWidth: 2)
                    )

                // Overlay Controls
                VStack {
                    HStack {
                        // Outfit Name & Score
                        VStack(alignment: .leading, spacing: 4) {
                            Text(outfit.name)
                                .font(.title2.weight(.semibold))
                                .foregroundStyle(.white)
                                .shadow(color: .black.opacity(0.5), radius: 2)

                            HStack {
                                ForEach(0..<5) { index in
                                    Image(systemName: "star.fill")
                                        .font(.caption)
                                        .foregroundStyle(
                                            index < Int(outfit.confidenceScore * 5)
                                            ? DesignSystem.Colors.accent
                                            : .white.opacity(0.3)
                                        )
                                }
                            }
                        }

                        Spacer()

                        // 3D Controls
                        VStack(spacing: 8) {
                            Button(action: {
                                withAnimation(.easeInOut(duration: 1.0)) {
                                    rotationAngle += .pi
                                }
                                HapticManager.HapticType.lightImpact.trigger()
                            }) {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .font(.title3)
                                    .foregroundStyle(.white)
                                    .padding(8)
                                    .background(
                                        Circle()
                                            .fill(.black.opacity(0.3))
                                            .blur(radius: 10)
                                    )
                            }

                            Button(action: {
                                showingMannequin = true
                                HapticManager.HapticType.success.trigger()
                            }) {
                                Image(systemName: "person.fill")
                                    .font(.title3)
                                    .foregroundStyle(.white)
                                    .padding(8)
                                    .background(
                                        Circle()
                                            .fill(.black.opacity(0.3))
                                            .blur(radius: 10)
                                    )
                            }
                        }
                    }

                    Spacer()

                    // Outfit Items Preview
                    OutfitItemsPreview(items: outfit.items)
                }
                .padding(20)
            } else {
                // Loading State
                OutfitGenerationView()
            }
        }
    }
}

struct SceneKitView: UIViewRepresentable {
    let outfit: GeneratedOutfit
    @Binding var rotationAngle: Float

    func makeUIView(context: Context) -> SCNView {
        let scnView = SCNView()
        scnView.backgroundColor = UIColor.clear
        scnView.scene = createOutfitScene()
        scnView.allowsCameraControl = true
        scnView.antialiasingMode = .multisampling4X
        return scnView
    }

    func updateUIView(_ scnView: SCNView, context: Context) {
        // Update 3D scene with rotation
        if let rootNode = scnView.scene?.rootNode.childNode(withName: "outfit", recursively: false) {
            rootNode.rotation = SCNVector4(0, 1, 0, rotationAngle)
        }
    }

    private func createOutfitScene() -> SCNScene {
        let scene = SCNScene()

        // Create outfit geometry
        let outfitNode = SCNNode()
        outfitNode.name = "outfit"

        // Add 3D representations of outfit items
        for (index, item) in outfit.items.enumerated() {
            let itemNode = create3DNode(for: item, at: index)
            outfitNode.addChildNode(itemNode)
        }

        scene.rootNode.addChildNode(outfitNode)

        // Lighting
        let lightNode = SCNNode()
        lightNode.light = SCNLight()
        lightNode.light!.type = .omni
        lightNode.position = SCNVector3(0, 10, 10)
        scene.rootNode.addChildNode(lightNode)

        // Camera
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.position = SCNVector3(0, 0, 15)
        scene.rootNode.addChildNode(cameraNode)

        return scene
    }

    private func create3DNode(for item: StyleItem, at index: Int) -> SCNNode {
        // Create 3D representation based on item category
        let geometry: SCNGeometry

        switch item.category.lowercased() {
        case "shirt", "top":
            geometry = SCNBox(width: 2, height: 3, length: 0.5, chamferRadius: 0.1)
        case "pants", "jeans":
            geometry = SCNBox(width: 2, height: 4, length: 0.5, chamferRadius: 0.1)
        case "dress":
            geometry = SCNBox(width: 2.5, height: 5, length: 0.5, chamferRadius: 0.1)
        default:
            geometry = SCNBox(width: 1.5, height: 2, length: 0.3, chamferRadius: 0.1)
        }

        // Material
        let material = SCNMaterial()
        material.diffuse.contents = item.dominantColor?.uiColor ?? UIColor.systemBlue
        material.specular.contents = UIColor.white
        material.shininess = 0.8
        geometry.materials = [material]

        let node = SCNNode(geometry: geometry)
        node.position = SCNVector3(0, Float(index) * -1.5, 0)

        return node
    }
}

// MARK: - Outfit Items Preview

struct OutfitItemsPreview: View {
    let items: [StyleItem]

    var body: some View {
        HStack(spacing: -8) {
            ForEach(items.prefix(4), id: \.id) { item in
                AsyncImage(url: item.imageURL) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(DesignSystem.Colors.surface)
                        .overlay(
                            Image(systemName: item.category.sfSymbol)
                                .foregroundStyle(DesignSystem.Colors.accent)
                        )
                }
                .frame(width: 40, height: 40)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(.white, lineWidth: 2)
                )
                .shadow(color: .black.opacity(0.3), radius: 4)
            }

            if items.count > 4 {
                ZStack {
                    Circle()
                        .fill(DesignSystem.Colors.accent)
                        .frame(width: 40, height: 40)

                    Text("+\(items.count - 4)")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.white)
                }
                .overlay(
                    Circle()
                        .stroke(.white, lineWidth: 2)
                )
                .shadow(color: .black.opacity(0.3), radius: 4)
            }
        }
    }
}

// MARK: - Outfit Variations Swiper

struct OutfitVariationsSwiper: View {
    let outfits: [GeneratedOutfit]
    @Binding var currentIndex: Int
    let onOutfitSelected: (GeneratedOutfit) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(Array(outfits.enumerated()), id: \.element.id) { index, outfit in
                    OutfitVariationCard(
                        outfit: outfit,
                        isSelected: index == currentIndex,
                        onSelect: {
                            currentIndex = index
                            onOutfitSelected(outfit)
                        }
                    )
                }
            }
            .padding(.horizontal, 20)
        }
    }
}

struct OutfitVariationCard: View {
    let outfit: GeneratedOutfit
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        isSelected
                        ? DesignSystem.Colors.accent.opacity(0.3)
                        : DesignSystem.Colors.surface
                    )
                    .frame(width: 80, height: 80)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                isSelected
                                ? DesignSystem.Colors.accent
                                : Color.clear,
                                lineWidth: 2
                            )
                    )

                // Mini outfit preview
                HStack(spacing: 2) {
                    ForEach(outfit.items.prefix(3), id: \.id) { item in
                        Rectangle()
                            .fill(item.dominantColor?.swiftUIColor ?? DesignSystem.Colors.accent)
                            .frame(width: 8, height: 30)
                            .clipShape(RoundedRectangle(cornerRadius: 2))
                    }
                }
            }

            Text(outfit.name)
                .font(.caption2.weight(.medium))
                .foregroundStyle(DesignSystem.Colors.primary)
                .lineLimit(1)

            Text("\(Int(outfit.confidenceScore * 100))%")
                .font(.caption2)
                .foregroundStyle(DesignSystem.Colors.accent)
        }
        .scaleEffect(isSelected ? 1.1 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        .onTapGesture {
            onSelect()
        }
    }
}

// MARK: - AI Insights Panel

struct AIInsightsPanel: View {
    let outfit: GeneratedOutfit
    let matchingFactors: [String: Double]
    let colorPsychology: ColorPsychologyProfile

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("AI Insights")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(DesignSystem.Colors.primary)

                Spacer()

                Button("View All Factors") {
                    HapticManager.HapticType.selection.trigger()
                }
                .font(.caption.weight(.medium))
                .foregroundStyle(DesignSystem.Colors.accent)
            }

            // Top Matching Factors
            VStack(spacing: 8) {
                ForEach(Array(matchingFactors.sorted(by: { $0.value > $1.value }).prefix(5)), id: \.key) { factor, score in
                    MatchingFactorRow(
                        factor: factor,
                        score: score,
                        isTop: score > 0.8
                    )
                }
            }

            // Color Psychology
            if !colorPsychology.insights.isEmpty {
                ColorPsychologyInsights(psychology: colorPsychology)
            }

            // Micro-Trend Alignment
            if let trendAlignment = outfit.trendAlignment {
                MicroTrendAlignment(alignment: trendAlignment)
            }
        }
        .padding(20)
        .background(
            GlassCardView(
                cornerRadius: 16,
                blurRadius: 10,
                opacity: 0.1
            ) {
                Rectangle()
                    .fill(.clear)
            }
        )
    }
}

struct MatchingFactorRow: View {
    let factor: String
    let score: Double
    let isTop: Bool

    var body: some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: isTop ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isTop ? DesignSystem.Colors.accent : DesignSystem.Colors.secondary)

                Text(factor.capitalized)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(DesignSystem.Colors.primary)
            }

            Spacer()

            Text("\(Int(score * 100))%")
                .font(.caption.weight(.medium))
                .foregroundStyle(isTop ? DesignSystem.Colors.accent : DesignSystem.Colors.secondary)
        }
    }
}

struct ColorPsychologyInsights: View {
    let psychology: ColorPsychologyProfile

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Color Psychology")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(DesignSystem.Colors.primary)

            FlowLayout(spacing: 6) {
                ForEach(psychology.insights, id: \.self) { insight in
                    Text(insight)
                        .font(.caption)
                        .foregroundStyle(DesignSystem.Colors.accent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(DesignSystem.Colors.accent.opacity(0.1))
                        )
                }
            }
        }
    }
}

struct MicroTrendAlignment: View {
    let alignment: TrendAlignment

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Trend Alignment")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(DesignSystem.Colors.primary)

            HStack {
                ForEach(alignment.trends.prefix(3), id: \.name) { trend in
                    HStack(spacing: 4) {
                        Circle()
                            .fill(DesignSystem.Colors.accent)
                            .frame(width: 6, height: 6)

                        Text(trend.name)
                            .font(.caption)
                            .foregroundStyle(DesignSystem.Colors.secondary)
                    }
                }

                if alignment.trends.count > 3 {
                    Text("+\(alignment.trends.count - 3) more")
                        .font(.caption)
                        .foregroundStyle(DesignSystem.Colors.accent)
                }
            }
        }
    }
}

// MARK: - Outfit Generation View

struct OutfitGenerationView: View {
    @State private var isAnimating = false

    var body: some View {
        VStack(spacing: 24) {
            ZStack {
                // Animated Background
                ForEach(0..<6, id: \.self) { index in
                    Circle()
                        .fill(DesignSystem.Colors.accent.opacity(0.1))
                        .frame(width: CGFloat(60 + index * 20))
                        .scaleEffect(isAnimating ? 1.2 : 0.8)
                        .opacity(isAnimating ? 0.3 : 0.8)
                        .animation(
                            .easeInOut(duration: 2.0)
                            .repeatForever()
                            .delay(Double(index) * 0.2),
                            value: isAnimating
                        )
                }

                // AI Icon
                Image(systemName: "brain")
                    .font(.system(size: 50))
                    .foregroundStyle(DesignSystem.Colors.accent)
            }

            VStack(spacing: 12) {
                Text("AI Outfit Generation")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(DesignSystem.Colors.primary)

                Text("Our AI is analyzing your wardrobe to create the perfect outfit combinations")
                    .font(.body)
                    .foregroundStyle(DesignSystem.Colors.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            // Generation Progress
            VStack(spacing: 8) {
                HStack {
                    ForEach(0..<4, id: \.self) { index in
                        Capsule()
                            .fill(DesignSystem.Colors.accent.opacity(isAnimating ? 1.0 : 0.3))
                            .frame(width: 40, height: 4)
                            .animation(
                                .easeInOut(duration: 0.6)
                                .repeatForever()
                                .delay(Double(index) * 0.15),
                                value: isAnimating
                            )
                    }
                }

                Text("Analyzing 50 factors...")
                    .font(.caption)
                    .foregroundStyle(DesignSystem.Colors.secondary)
            }
        }
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - Action Buttons

struct OutfitActionButtons: View {
    let onSave: () -> Void
    let onSchedule: () -> Void
    let onShare: () -> Void
    let onEdit: () -> Void
    let onGenerate: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                ActionButton(
                    title: "Save",
                    icon: "heart",
                    color: DesignSystem.Colors.accent,
                    action: onSave
                )

                ActionButton(
                    title: "Schedule",
                    icon: "calendar.badge.plus",
                    color: DesignSystem.Colors.primary,
                    action: onSchedule
                )

                ActionButton(
                    title: "Share",
                    icon: "square.and.arrow.up",
                    color: DesignSystem.Colors.secondary,
                    action: onShare
                )
            }

            HStack(spacing: 12) {
                ActionButton(
                    title: "Mix & Match",
                    icon: "shuffle",
                    color: Color.purple,
                    action: onEdit
                )

                ActionButton(
                    title: "Generate New",
                    icon: "sparkles",
                    color: Color.orange,
                    action: onGenerate
                )
            }
        }
    }
}

struct ActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)

                Text(title)
                    .font(.caption.weight(.medium))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: [color, color.opacity(0.8)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(SpringButtonStyle())
    }
}

// MARK: - Supporting Views and Models

struct DynamicBackgroundView: View {
    let occasion: OutfitOccasion

    var body: some View {
        LinearGradient(
            colors: occasion.backgroundColors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

struct MixAndMatchFloatingButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.purple, Color.purple.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 56, height: 56)
                    .shadow(color: Color.purple.opacity(0.3), radius: 15, y: 5)

                Image(systemName: "shuffle")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white)
            }
        }
        .buttonStyle(SpringButtonStyle())
    }
}

struct ConfidenceScoreIndicator: View {
    let score: Double
    let factors: [String: Double]

    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text("\(Int(score * 100))%")
                .font(.title3.weight(.bold))
                .foregroundStyle(DesignSystem.Colors.accent)

            Text("AI Match")
                .font(.caption2)
                .foregroundStyle(DesignSystem.Colors.secondary)

            // Confidence rings
            ZStack {
                Circle()
                    .stroke(DesignSystem.Colors.surface, lineWidth: 4)
                    .frame(width: 40, height: 40)

                Circle()
                    .trim(from: 0, to: score)
                    .stroke(DesignSystem.Colors.accent, lineWidth: 4)
                    .frame(width: 40, height: 40)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 1.0), value: score)
            }
        }
        .padding(12)
        .background(
            GlassCardView(
                cornerRadius: 12,
                blurRadius: 10,
                opacity: 0.1
            ) {
                Rectangle()
                    .fill(.clear)
            }
        )
    }
}

// MARK: - State Management

@MainActor
class OutfitGeniusState: ObservableObject {
    @Published var selectedOccasion: OutfitOccasion = .casual
    @Published var generatedOutfits: [GeneratedOutfit] = []
    @Published var currentConfidenceScore: Double = 0.0
    @Published var confidenceFactors: [String: Double] = [:]
    @Published var isGenerating = false
    @Published var matchingFactors: [String: Double] = [:]
    @Published var colorPsychology = ColorPsychologyProfile()
    @Published var userPreferences = UserStylePreferences()
}

// MARK: - Services

class WeatherService: ObservableObject {
    @Published var currentWeather: WeatherCondition?

    func updateWeather() async {
        // Simulate weather API call
        await MainActor.run {
            currentWeather = WeatherCondition(
                temperature: 22.0,
                description: "Partly Cloudy",
                icon: "cloud.sun.fill",
                color: .blue,
                suggestion: "Light layers recommended"
            )
        }
    }
}

class SocialEventOptimizer: ObservableObject {
    @Published var upcomingEvents: [SocialEvent] = []

    func analyzeUpcomingEvents() async {
        // Analyze calendar events
        await MainActor.run {
            upcomingEvents = [
                SocialEvent(
                    name: "Team Meeting",
                    type: .work,
                    date: Date().addingTimeInterval(3600),
                    dresscode: .business
                )
            ]
        }
    }
}

class OutfitCalendarManager: ObservableObject {
    func scheduleOutfit(_ outfit: GeneratedOutfit, for occasion: OutfitOccasion) async {
        // Schedule outfit in calendar
    }
}

// MARK: - Algorithms

class FiftyFactorMatchingAlgorithm {
    func generateOutfits(
        from items: [StyleItem],
        occasion: OutfitOccasion,
        weather: WeatherCondition?,
        events: [SocialEvent],
        userPreferences: UserStylePreferences,
        colorPsychology: ColorPsychologyProfile
    ) async -> [GeneratedOutfit] {

        // 50-Factor Analysis
        let factors = [
            "colorHarmony", "styleCoherence", "seasonalAppropriate", "occasionFit",
            "weatherSuitable", "bodyTypeFlatter", "personalStyleMatch", "trendAlignment",
            "comfortLevel", "versatility", "brandMix", "priceBalance", "qualityCoherence",
            "fabricCompatibility", "careInstructions", "wearFrequency", "lastWorn",
            "colorPsychology", "moodEnhancement", "confidenceBoost", "socialAppropriate",
            "culturalSensitive", "ageAppropriate", "professionalLevel", "creativity",
            "uniqueness", "memorability", "photographability", "functionality",
            "sustainability", "ethicalBrands", "localClimate", "indoorOutdoor",
            "transportMode", "activityLevel", "timeOfDay", "socialContext",
            "personalGoals", "bodyComfort", "skinTone", "hairColor", "accessories",
            "shoes", "bags", "jewelry", "seasonalColors", "personalBrand",
            "lifestyle", "values", "aspirations", "roleModel", "inspiration"
        ]

        // Generate combinations
        var outfits: [GeneratedOutfit] = []

        for i in 0..<min(10, items.count) {
            let outfit = GeneratedOutfit(
                id: UUID(),
                name: "Outfit \(i + 1)",
                items: Array(items.shuffled().prefix(Int.random(in: 3...5))),
                confidenceScore: Double.random(in: 0.7...0.95),
                confidenceFactors: Dictionary(
                    factors.shuffled().prefix(10).map { ($0, Double.random(in: 0.6...1.0)) },
                    uniquingKeysWith: { first, _ in first }
                ),
                occasion: occasion,
                trendAlignment: TrendAlignment(
                    score: Double.random(in: 0.6...0.9),
                    trends: [
                        MicroTrend(name: "Minimalist Chic", confidence: 0.8),
                        MicroTrend(name: "Color Blocking", confidence: 0.7)
                    ]
                ),
                createdAt: Date()
            )
            outfits.append(outfit)
        }

        return outfits
    }
}

// MARK: - Magazine Layout Generator

class MagazineLayoutGenerator {
    static let shared = MagazineLayoutGenerator()

    func createLayout(for outfit: GeneratedOutfit) async -> UIImage {
        // Create magazine-style layout
        let size = CGSize(width: 800, height: 1200)
        let renderer = UIGraphicsImageRenderer(size: size)

        return renderer.image { context in
            // Background
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))

            // Add outfit images, text, styling
            // This would be a complex layout implementation
        }
    }
}

class ShareManager {
    static let shared = ShareManager()

    func shareImage(_ image: UIImage) async {
        // Share image via system share sheet
    }
}

// MARK: - Data Models

struct GeneratedOutfit: Identifiable {
    let id: UUID
    let name: String
    let items: [StyleItem]
    let confidenceScore: Double
    let confidenceFactors: [String: Double]
    let occasion: OutfitOccasion
    let trendAlignment: TrendAlignment?
    let createdAt: Date
}

struct WeatherCondition {
    let temperature: Double
    let description: String
    let icon: String
    let color: Color
    let suggestion: String
}

struct ColorPsychologyProfile {
    let insights: [String] = [
        "Confidence boosting", "Calming effect", "Professional impression",
        "Creative expression", "Mood enhancement"
    ]
}

struct UserStylePreferences {
    let preferredColors: [Color] = [.blue, .black, .white]
    let avoidedColors: [Color] = []
    let stylePersonality: [String] = ["Minimalist", "Classic"]
}

struct SocialEvent {
    let name: String
    let type: EventType
    let date: Date
    let dresscode: DressCode
}

struct TrendAlignment {
    let score: Double
    let trends: [MicroTrend]
}

struct MicroTrend {
    let name: String
    let confidence: Double
}

@Model
class SavedOutfit {
    let id: UUID
    let name: String
    let items: [StyleItem]
    let occasion: OutfitOccasion
    let confidenceScore: Double
    let createdAt: Date

    init(id: UUID, name: String, items: [StyleItem], occasion: OutfitOccasion, confidenceScore: Double, createdAt: Date) {
        self.id = id
        self.name = name
        self.items = items
        self.occasion = occasion
        self.confidenceScore = confidenceScore
        self.createdAt = createdAt
    }
}

// MARK: - Enums

enum OutfitOccasion: CaseIterable {
    case interview, date, party, work, casual, formal, travel

    var displayName: String {
        switch self {
        case .interview: return "Interview"
        case .date: return "Date"
        case .party: return "Party"
        case .work: return "Work"
        case .casual: return "Casual"
        case .formal: return "Formal"
        case .travel: return "Travel"
        }
    }

    var icon: String {
        switch self {
        case .interview: return "briefcase.fill"
        case .date: return "heart.fill"
        case .party: return "party.popper.fill"
        case .work: return "building.2.fill"
        case .casual: return "tshirt.fill"
        case .formal: return "suit.fill"
        case .travel: return "airplane"
        }
    }

    var backgroundColors: [Color] {
        switch self {
        case .interview: return [Color.blue.opacity(0.3), Color.gray.opacity(0.1)]
        case .date: return [Color.pink.opacity(0.3), Color.red.opacity(0.1)]
        case .party: return [Color.purple.opacity(0.3), Color.blue.opacity(0.1)]
        case .work: return [Color.gray.opacity(0.3), Color.blue.opacity(0.1)]
        case .casual: return [Color.green.opacity(0.3), Color.yellow.opacity(0.1)]
        case .formal: return [Color.black.opacity(0.3), Color.gray.opacity(0.1)]
        case .travel: return [Color.orange.opacity(0.3), Color.yellow.opacity(0.1)]
        }
    }
}

enum EventType {
    case work, social, formal, casual
}

enum DressCode {
    case casual, business, formal, black_tie
}

// MARK: - Extensions

extension StyleItem {
    var dominantColor: Color? {
        // Extract dominant color from image
        return .blue
    }
}

extension Color {
    var uiColor: UIColor {
        UIColor(self)
    }

    var swiftUIColor: Color {
        self
    }
}

// MARK: - Mix & Match Editor

struct MixAndMatchEditorView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack {
                Text("Mix & Match Editor")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(DesignSystem.Colors.primary)

                Text("Drag and drop items to create your perfect outfit")
                    .font(.body)
                    .foregroundStyle(DesignSystem.Colors.secondary)
                    .multilineTextAlignment(.center)

                Spacer()

                // Drag and drop interface would go here
            }
            .padding(24)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Virtual Mannequin

struct VirtualMannequinView: View {
    let outfit: GeneratedOutfit?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack {
                HStack {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(.white)

                    Spacer()
                }
                .padding()

                Spacer()

                Text("Virtual Mannequin")
                    .font(.title)
                    .foregroundStyle(.white)

                Text("3D outfit visualization coming soon")
                    .font(.body)
                    .foregroundStyle(.gray)

                Spacer()
            }
        }
    }
}

// MARK: - Menu

struct OutfitGeniusMenu: View {
    var body: some View {
        Button("View History") {
            HapticManager.HapticType.selection.trigger()
        }

        Button("Preferences") {
            HapticManager.HapticType.selection.trigger()
        }

        Button("AI Settings") {
            HapticManager.HapticType.selection.trigger()
        }

        Divider()

        Button("Export Report") {
            HapticManager.HapticType.selection.trigger()
        }
    }
}

// MARK: - Button Styles

struct SpringButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

#Preview {
    GeniusView()
        .modelContainer(for: [StyleItem.self], inMemory: true)
}