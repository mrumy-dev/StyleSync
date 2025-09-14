import SwiftUI
import SceneKit

struct SuitcaseVisualizationView: View {
    @ObservedObject var travelManager: TravelProManager
    @State private var selectedSuitcaseType: SuitcaseType = .carryOn
    @State private var showingPackingGuide = false
    @State private var rotationAngle: Float = 0
    @State private var zoomScale: Float = 1.0

    var body: some View {
        NavigationStack {
            VStack {
                if let trip = travelManager.currentTrip,
                   let packingList = trip.packingList {

                    // Suitcase type selector
                    suitcaseTypeSelector

                    // 3D Visualization
                    SceneView(
                        scene: createSuitcaseScene(packingList: packingList),
                        options: [.allowsCameraControl, .autoenablesDefaultLighting]
                    )
                    .frame(height: 300)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .gesture(
                        MagnificationGesture()
                            .onChanged { value in
                                zoomScale = Float(value)
                            }
                    )

                    // Controls
                    visualizationControls

                    // Packing layers
                    packingLayersView(packingList: packingList)

                    Spacer()

                } else {
                    emptyStateView
                }
            }
            .padding()
            .navigationTitle("3D Suitcase")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Packing Guide") {
                        showingPackingGuide = true
                    }
                }
            }
            .sheet(isPresented: $showingPackingGuide) {
                PackingGuideView(
                    packingList: travelManager.currentTrip?.packingList,
                    suitcaseType: selectedSuitcaseType
                )
            }
        }
    }

    private var suitcaseTypeSelector: some View {
        Picker("Suitcase Type", selection: $selectedSuitcaseType) {
            ForEach(SuitcaseType.allCases, id: \.self) { type in
                Text(type.rawValue)
                    .tag(type)
            }
        }
        .pickerStyle(SegmentedPickerStyle())
        .padding(.horizontal)
    }

    private var visualizationControls: some View {
        HStack(spacing: 20) {
            Button(action: {
                rotationAngle += .pi / 4
            }) {
                Image(systemName: "arrow.clockwise")
                    .font(.title2)
                    .padding(12)
                    .background(Color(.systemGray5))
                    .clipShape(Circle())
            }

            VStack {
                Text("Zoom")
                    .font(.caption)
                Slider(value: Binding(
                    get: { Double(zoomScale) },
                    set: { zoomScale = Float($0) }
                ), in: 0.5...2.0)
                .frame(width: 100)
            }

            Button(action: {
                // Reset view
                rotationAngle = 0
                zoomScale = 1.0
            }) {
                Image(systemName: "arrow.counterclockwise")
                    .font(.title2)
                    .padding(12)
                    .background(Color(.systemGray5))
                    .clipShape(Circle())
            }
        }
        .padding(.vertical)
    }

    private func packingLayersView(packingList: PackingList) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Packing Layers")
                .font(.headline)
                .fontWeight(.medium)

            if let suitcaseLayout = generateSuitcaseLayout(packingList: packingList) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(suitcaseLayout.layers) { layer in
                            LayerCard(
                                layer: layer,
                                isSelected: false
                            ) {
                                // Handle layer selection
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "cube.transparent")
                .font(.system(size: 60))
                .foregroundColor(.gray)

            Text("No Trip Selected")
                .font(.title2)
                .fontWeight(.medium)

            Text("Create a trip to see 3D packing visualization")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    private func createSuitcaseScene(packingList: PackingList) -> SCNScene {
        let scene = SCNScene()

        // Create suitcase container
        let suitcaseDimensions = selectedSuitcaseType.standardDimensions
        let suitcaseGeometry = SCNBox(
            width: CGFloat(suitcaseDimensions.length / 100), // Convert cm to meters
            height: CGFloat(suitcaseDimensions.height / 100),
            length: CGFloat(suitcaseDimensions.width / 100),
            chamferRadius: 0.01
        )

        let suitcaseMaterial = SCNMaterial()
        suitcaseMaterial.diffuse.contents = UIColor.systemGray2
        suitcaseMaterial.transparency = 0.3
        suitcaseGeometry.materials = [suitcaseMaterial]

        let suitcaseNode = SCNNode(geometry: suitcaseGeometry)
        suitcaseNode.position = SCNVector3(0, 0, 0)
        scene.rootNode.addChildNode(suitcaseNode)

        // Add packed items as colored boxes
        if let suitcaseLayout = generateSuitcaseLayout(packingList: packingList) {
            for layer in suitcaseLayout.layers {
                for placedItem in layer.items {
                    let itemNode = createItemNode(placedItem: placedItem)
                    scene.rootNode.addChildNode(itemNode)
                }
            }
        }

        // Add camera
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.position = SCNVector3(0, 0, 2)
        scene.rootNode.addChildNode(cameraNode)

        // Add lighting
        let lightNode = SCNNode()
        lightNode.light = SCNLight()
        lightNode.light?.type = .omni
        lightNode.position = SCNVector3(0, 10, 10)
        scene.rootNode.addChildNode(lightNode)

        return scene
    }

    private func createItemNode(placedItem: PlacedItem) -> SCNNode {
        // Create a simple box for each item
        let dimensions = placedItem.item.dimensions ?? Dimensions(length: 10, width: 10, height: 5)

        let geometry = SCNBox(
            width: CGFloat(dimensions.width / 100),
            height: CGFloat(dimensions.height / 100),
            length: CGFloat(dimensions.length / 100),
            chamferRadius: 0.005
        )

        let material = SCNMaterial()
        material.diffuse.contents = itemColor(for: placedItem.item)
        geometry.materials = [material]

        let node = SCNNode(geometry: geometry)
        node.position = SCNVector3(
            Float(placedItem.position.x / 100),
            Float(placedItem.position.y / 100),
            Float(placedItem.position.z / 100)
        )

        // Apply rotation if needed
        node.eulerAngles = SCNVector3(
            Float(placedItem.rotation.x),
            Float(placedItem.rotation.y),
            Float(placedItem.rotation.z)
        )

        return node
    }

    private func itemColor(for item: PackingItem) -> UIColor {
        // Assign colors based on item category or type
        if item.name.lowercased().contains("shirt") || item.name.lowercased().contains("top") {
            return .systemBlue
        } else if item.name.lowercased().contains("pants") || item.name.lowercased().contains("trouser") {
            return .systemGreen
        } else if item.name.lowercased().contains("shoe") {
            return .systemBrown
        } else if item.name.lowercased().contains("electronic") || item.name.lowercased().contains("charger") {
            return .systemRed
        } else if item.weatherSpecific {
            return .systemOrange
        } else {
            return .systemPurple
        }
    }

    private func generateSuitcaseLayout(packingList: PackingList) -> SuitcaseLayout {
        let dimensions = selectedSuitcaseType.standardDimensions

        // Simple algorithm to distribute items in layers
        var layers: [PackingLayer] = []
        var currentZ: Double = 0
        let layerHeight: Double = 10 // cm

        let allItems = packingList.categories.flatMap(\.items)
        let sortedItems = allItems.sorted { $0.weight > $1.weight } // Heavy items first

        var itemsPerLayer: [[PackingItem]] = []
        var currentLayer: [PackingItem] = []
        var currentLayerWeight: Double = 0

        for item in sortedItems {
            if currentLayerWeight + item.weight > 5.0 || currentLayer.count >= 8 {
                if !currentLayer.isEmpty {
                    itemsPerLayer.append(currentLayer)
                    currentLayer = []
                    currentLayerWeight = 0
                }
            }

            currentLayer.append(item)
            currentLayerWeight += item.weight
        }

        if !currentLayer.isEmpty {
            itemsPerLayer.append(currentLayer)
        }

        // Create layers with positioned items
        for (layerIndex, layerItems) in itemsPerLayer.enumerated() {
            var placedItems: [PlacedItem] = []
            let gridSize = Int(ceil(sqrt(Double(layerItems.count))))

            for (index, item) in layerItems.enumerated() {
                let row = index / gridSize
                let col = index % gridSize

                let x = (Double(col) - Double(gridSize - 1) / 2) * (dimensions.width / Double(gridSize))
                let y = currentZ
                let z = (Double(row) - Double(gridSize - 1) / 2) * (dimensions.length / Double(gridSize))

                let placedItem = PlacedItem(
                    id: UUID(),
                    item: item,
                    position: Position3D(x: x, y: y, z: z),
                    rotation: Rotation3D(x: 0, y: 0, z: 0)
                )

                placedItems.append(placedItem)
            }

            let layer = PackingLayer(
                id: UUID(),
                level: layerIndex,
                items: placedItems,
                remainingSpace: max(0, dimensions.volume - Double(placedItems.count) * 1000) // Rough calculation
            )

            layers.append(layer)
            currentZ += layerHeight
        }

        return SuitcaseLayout(
            suitcaseType: selectedSuitcaseType,
            dimensions: dimensions,
            layers: layers,
            weightDistribution: generateWeightDistribution(layers: layers)
        )
    }

    private func generateWeightDistribution(layers: [PackingLayer]) -> [WeightPoint] {
        var weightPoints: [WeightPoint] = []

        for layer in layers {
            for placedItem in layer.items {
                let weightPoint = WeightPoint(
                    position: placedItem.position,
                    weight: placedItem.item.weight
                )
                weightPoints.append(weightPoint)
            }
        }

        return weightPoints
    }
}

struct LayerCard: View {
    let layer: PackingLayer
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Layer \(layer.level + 1)")
                        .font(.headline)
                        .fontWeight(.medium)

                    Spacer()

                    Text("\(layer.items.count) items")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // Item preview
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 4), spacing: 2) {
                    ForEach(layer.items.prefix(8), id: \.id) { placedItem in
                        Rectangle()
                            .fill(itemColor(for: placedItem.item))
                            .frame(height: 12)
                    }

                    if layer.items.count > 8 {
                        Text("+\(layer.items.count - 8)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .frame(height: 12)
                    }
                }

                Text("Space: \(Int(layer.remainingSpace))cm³ remaining")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(12)
            .frame(width: 160)
            .background(isSelected ? Color.blue.opacity(0.1) : Color(.systemBackground))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : Color(.systemGray4), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func itemColor(for item: PackingItem) -> Color {
        if item.name.lowercased().contains("shirt") {
            return .blue
        } else if item.name.lowercased().contains("pants") {
            return .green
        } else if item.name.lowercased().contains("shoe") {
            return .brown
        } else {
            return .purple
        }
    }
}

struct PackingGuideView: View {
    let packingList: PackingList?
    let suitcaseType: SuitcaseType
    @Environment(\.dismiss) private var dismiss
    @State private var showingExportOptions = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    headerSection

                    // Packing order
                    if let packingList = packingList {
                        packingOrderSection(packingList)
                    }

                    // Folding techniques
                    foldingTechniquesSection

                    // Weight distribution tips
                    weightDistributionSection
                }
                .padding()
            }
            .navigationTitle("Packing Guide")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Export PDF") {
                        showingExportOptions = true
                    }
                }
            }
            .sheet(isPresented: $showingExportOptions) {
                PDFExportView(packingList: packingList, suitcaseType: suitcaseType)
            }
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.title)
                    .foregroundColor(.blue)

                VStack(alignment: .leading) {
                    Text("Smart Packing Guide")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("Optimized for \(suitcaseType.rawValue)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            Text("Follow this guide to pack efficiently and maximize your luggage space.")
                .font(.body)
                .foregroundColor(.secondary)
        }
    }

    private func packingOrderSection(_ packingList: PackingList) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Recommended Packing Order")
                .font(.headline)
                .fontWeight(.medium)

            LazyVStack(alignment: .leading, spacing: 12) {
                ForEach(Array(packingList.spaceOptimization.recommendedPackingOrder.enumerated()), id: \.element) { index, itemID in
                    if let item = findItem(by: itemID, in: packingList) {
                        PackingStepView(
                            step: index + 1,
                            item: item,
                            instruction: packingInstruction(for: item, step: index + 1)
                        )
                    }
                }
            }
        }
    }

    private var foldingTechniquesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Folding Techniques")
                .font(.headline)
                .fontWeight(.medium)

            LazyVStack(spacing: 12) {
                FoldingTechniqueCard(
                    title: "Ranger Roll",
                    items: "T-shirts, Underwear",
                    spaceSaving: "40%",
                    icon: "arrow.clockwise.circle"
                )

                FoldingTechniqueCard(
                    title: "Flat Fold",
                    items: "Dress shirts, Pants",
                    spaceSaving: "25%",
                    icon: "rectangle.stack"
                )

                FoldingTechniqueCard(
                    title: "Bundle Wrapping",
                    items: "Delicate items",
                    spaceSaving: "30%",
                    icon: "gift.circle"
                )
            }
        }
    }

    private var weightDistributionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Weight Distribution Tips")
                .font(.headline)
                .fontWeight(.medium)

            LazyVStack(alignment: .leading, spacing: 12) {
                WeightTipRow(
                    icon: "arrow.down.to.line",
                    title: "Heavy items at bottom",
                    description: "Place shoes and heavy electronics at the suitcase bottom"
                )

                WeightTipRow(
                    icon: "arrow.up.and.down.and.arrow.left.and.right",
                    title: "Balance weight evenly",
                    description: "Distribute weight across the suitcase to prevent tipping"
                )

                WeightTipRow(
                    icon: "figure.walk",
                    title: "Wear heavy items",
                    description: "Wear boots and heavy jackets on the plane"
                )
            }
        }
    }

    private func findItem(by id: UUID, in packingList: PackingList) -> PackingItem? {
        return packingList.categories.flatMap(\.items).first { $0.id == id }
    }

    private func packingInstruction(for item: PackingItem, step: Int) -> String {
        if step <= 3 {
            return "Pack at the bottom for stability"
        } else if item.name.lowercased().contains("electronic") {
            return "Protect with soft items and keep accessible"
        } else if item.weatherSpecific {
            return "Keep easily accessible in case of weather changes"
        } else {
            return "Fill remaining space efficiently"
        }
    }
}

struct PackingStepView: View {
    let step: Int
    let item: PackingItem
    let instruction: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(step)")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 28, height: 28)
                .background(Color.blue)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(instruction)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
    }
}

struct FoldingTechniqueCard: View {
    let title: String
    let items: String
    let spaceSaving: String
    let icon: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.green)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text("Best for: \(items)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(spaceSaving)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.green)

                Text("space saved")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
    }
}

struct WeightTipRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.orange)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct PDFExportView: View {
    let packingList: PackingList?
    let suitcaseType: SuitcaseType
    @Environment(\.dismiss) private var dismiss
    @State private var isExporting = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "doc.pdf")
                    .font(.system(size: 60))
                    .foregroundColor(.red)

                VStack(spacing: 12) {
                    Text("Export Packing Guide")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("Generate a beautiful PDF with your packing checklist, tips, and 3D visualization.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }

                VStack(spacing: 16) {
                    Button(action: exportPDF) {
                        HStack {
                            if isExporting {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "doc.pdf.fill")
                                Text("Export PDF Guide")
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.red)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(isExporting)

                    Button("Share Checklist") {
                        shareChecklist()
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color(.systemGray5))
                    .foregroundColor(.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding()
            .navigationTitle("Export Options")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func exportPDF() {
        isExporting = true

        // Create PDF export task
        Task {
            let pdfExporter = TravelPDFExporter()
            await pdfExporter.exportPackingGuide(packingList: packingList, suitcaseType: suitcaseType)

            await MainActor.run {
                isExporting = false
                dismiss()
            }
        }
    }

    private func shareChecklist() {
        // Implement checklist sharing
    }
}

// MARK: - PDF Exporter
class TravelPDFExporter {
    func exportTrip(_ trip: TravelTrip) {
        // Implementation for full trip export
    }

    func exportPackingGuide(packingList: PackingList?, suitcaseType: SuitcaseType) async {
        // Simulate PDF generation
        await Task.sleep(nanoseconds: 2_000_000_000)

        // In a real implementation, this would:
        // 1. Generate PDF with packing list
        // 2. Include 3D visualization images
        // 3. Add folding technique illustrations
        // 4. Include weight distribution diagrams
        // 5. Save to Files app or share
    }
}

#Preview {
    SuitcaseVisualizationView(travelManager: TravelProManager())
}