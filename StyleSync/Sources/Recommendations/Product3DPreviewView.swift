import SwiftUI
import SceneKit
import ARKit

struct Product3DPreviewView: View {
    let product: Product
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var themeManager: ThemeManager
    @State private var currentView: ViewMode = .model3D
    @State private var isARAvailable = ARWorldTrackingConfiguration.isSupported
    @State private var selectedAnimation: AnimationType = .none
    @State private var showAnimationControls = false
    @State private var rotationAngle: Float = 0
    @State private var zoomLevel: Float = 1.0
    @State private var lightingIntensity: Float = 1.0

    enum ViewMode: String, CaseIterable {
        case model3D = "3D Model"
        case augmentedReality = "AR Try-On"
        case comparison = "Size Compare"
        case materials = "Materials"

        var icon: String {
            switch self {
            case .model3D: return "cube"
            case .augmentedReality: return "arkit"
            case .comparison: return "ruler"
            case .materials: return "eyedropper"
            }
        }
    }

    enum AnimationType: String, CaseIterable {
        case none = "None"
        case rotate = "Rotate"
        case bounce = "Bounce"
        case float = "Float"
        case wave = "Wave"

        var icon: String {
            switch self {
            case .none: return "stop"
            case .rotate: return "arrow.clockwise"
            case .bounce: return "arrow.up.and.down"
            case .float: return "cloud"
            case .wave: return "waveform"
            }
        }
    }

    var body: some View {
        NavigationView {
            ZStack {
                backgroundGradient

                VStack(spacing: 0) {
                    headerSection
                    mainContentArea
                    controlsSection
                }
            }
        }
        .navigationBarHidden(true)
    }

    private var backgroundGradient: some View {
        LinearGradient(
            gradient: Gradient(colors: [
                Color.black.opacity(0.9),
                Color.black.opacity(0.7)
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    private var headerSection: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(Color.black.opacity(0.3))
                            .backdrop(BlurView(style: .systemThinMaterial))
                    )
            }
            .tapWithHaptic(.light)

            Spacer()

            VStack(alignment: .center, spacing: 4) {
                Text(product.name)
                    .typography(.body1, theme: .modern)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .lineLimit(1)

                Text(product.brand)
                    .typography(.caption1, theme: .minimal)
                    .foregroundColor(.white.opacity(0.7))
            }

            Spacer()

            Button(action: { showAnimationControls.toggle() }) {
                Image(systemName: "gearshape")
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(Color.black.opacity(0.3))
                            .backdrop(BlurView(style: .systemThinMaterial))
                    )
            }
            .tapWithHaptic(.light)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    private var mainContentArea: some View {
        GeometryReader { geometry in
            ZStack {
                switch currentView {
                case .model3D:
                    SceneView3D(
                        product: product,
                        animation: selectedAnimation,
                        rotationAngle: rotationAngle,
                        zoomLevel: zoomLevel,
                        lightingIntensity: lightingIntensity
                    )
                case .augmentedReality:
                    if isARAvailable {
                        ARPreviewView(product: product)
                    } else {
                        ARUnavailableView()
                    }
                case .comparison:
                    SizeComparisonView(product: product)
                case .materials:
                    MaterialsDetailView(product: product)
                }

                if showAnimationControls {
                    AnimationControlsOverlay(
                        selectedAnimation: $selectedAnimation,
                        rotationAngle: $rotationAngle,
                        zoomLevel: $zoomLevel,
                        lightingIntensity: $lightingIntensity,
                        isVisible: $showAnimationControls
                    )
                    .transition(.opacity.combined(with: .scale))
                }
            }
        }
        .clipped()
    }

    private var controlsSection: some View {
        VStack(spacing: 16) {
            viewModeSelector
            actionButtons
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 34)
    }

    private var viewModeSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(ViewMode.allCases, id: \.self) { mode in
                    ViewModeButton(
                        mode: mode,
                        isSelected: currentView == mode,
                        isEnabled: mode != .augmentedReality || isARAvailable
                    ) {
                        currentView = mode
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }

    private var actionButtons: some View {
        HStack(spacing: 16) {
            ActionButton(
                icon: "square.and.arrow.up",
                title: "Share",
                color: .blue
            ) {
                shareProduct()
            }

            ActionButton(
                icon: "heart",
                title: "Save",
                color: .red
            ) {
                saveProduct()
            }

            ActionButton(
                icon: "cart.badge.plus",
                title: "Add to Cart",
                color: .green
            ) {
                addToCart()
            }
        }
    }

    private func shareProduct() {
        // Implementation for sharing 3D model or AR experience
        print("Sharing product: \(product.name)")
    }

    private func saveProduct() {
        // Implementation for saving to wishlist
        print("Saved product: \(product.name)")
    }

    private func addToCart() {
        // Implementation for adding to cart
        print("Added to cart: \(product.name)")
    }
}

struct SceneView3D: View {
    let product: Product
    let animation: Product3DPreviewView.AnimationType
    let rotationAngle: Float
    let zoomLevel: Float
    let lightingIntensity: Float

    @State private var scene: SCNScene?
    @State private var cameraNode: SCNNode?

    var body: some View {
        GeometryReader { geometry in
            if let scene = scene {
                SceneView(
                    scene: scene,
                    pointOfView: cameraNode,
                    options: [.allowsCameraControl, .autoenablesDefaultLighting]
                )
                .background(Color.clear)
                .onAppear {
                    setupScene()
                    applyAnimation()
                }
                .onChange(of: animation) { _, _ in
                    applyAnimation()
                }
                .onChange(of: rotationAngle) { _, _ in
                    updateRotation()
                }
                .onChange(of: zoomLevel) { _, _ in
                    updateZoom()
                }
                .onChange(of: lightingIntensity) { _, _ in
                    updateLighting()
                }
            } else {
                LoadingSceneView()
                    .onAppear {
                        loadScene()
                    }
            }
        }
    }

    private func loadScene() {
        // Create a new scene
        let newScene = SCNScene()

        // Add product model (simplified - in real app would load actual 3D model)
        let productNode = createProductNode()
        newScene.rootNode.addChildNode(productNode)

        // Setup camera
        let camera = SCNCamera()
        camera.fieldOfView = 45
        let cameraNode = SCNNode()
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(0, 0, 3)
        newScene.rootNode.addChildNode(cameraNode)

        // Setup lighting
        setupLighting(in: newScene)

        self.scene = newScene
        self.cameraNode = cameraNode
    }

    private func createProductNode() -> SCNNode {
        // Create a basic geometric representation of the product
        // In a real app, this would load the actual 3D model file
        let geometry: SCNGeometry

        switch product.category {
        case "Dresses", "Tops":
            geometry = SCNCylinder(radius: 0.5, height: 1.0)
        case "Shoes":
            geometry = SCNBox(width: 0.8, height: 0.3, length: 1.2, chamferRadius: 0.1)
        case "Accessories":
            geometry = SCNSphere(radius: 0.4)
        default:
            geometry = SCNBox(width: 0.8, height: 1.0, length: 0.2, chamferRadius: 0.1)
        }

        let material = SCNMaterial()
        material.diffuse.contents = UIColor.systemBlue // Would use actual product colors
        material.specular.contents = UIColor.white
        material.shininess = 0.8

        geometry.materials = [material]

        let node = SCNNode(geometry: geometry)
        node.name = "product"

        return node
    }

    private func setupScene() {
        guard let scene = scene else { return }

        // Additional scene setup
        scene.background.contents = UIColor.clear
    }

    private func setupLighting(in scene: SCNScene) {
        // Ambient light
        let ambientLight = SCNLight()
        ambientLight.type = .ambient
        ambientLight.intensity = 200 * lightingIntensity
        let ambientNode = SCNNode()
        ambientNode.light = ambientLight
        scene.rootNode.addChildNode(ambientNode)

        // Directional light
        let directionalLight = SCNLight()
        directionalLight.type = .directional
        directionalLight.intensity = 1000 * lightingIntensity
        let directionalNode = SCNNode()
        directionalNode.light = directionalLight
        directionalNode.position = SCNVector3(0, 5, 5)
        directionalNode.look(at: SCNVector3(0, 0, 0))
        scene.rootNode.addChildNode(directionalNode)
    }

    private func applyAnimation() {
        guard let scene = scene,
              let productNode = scene.rootNode.childNode(withName: "product", recursively: true) else { return }

        // Remove existing animations
        productNode.removeAllAnimations()

        switch animation {
        case .none:
            break
        case .rotate:
            let rotation = SCNAction.rotateBy(x: 0, y: .pi * 2, z: 0, duration: 3)
            let repeatRotation = SCNAction.repeatForever(rotation)
            productNode.runAction(repeatRotation, forKey: "rotation")
        case .bounce:
            let moveUp = SCNAction.moveBy(x: 0, y: 0.2, z: 0, duration: 1)
            let moveDown = SCNAction.moveBy(x: 0, y: -0.2, z: 0, duration: 1)
            let bounce = SCNAction.sequence([moveUp, moveDown])
            let repeatBounce = SCNAction.repeatForever(bounce)
            productNode.runAction(repeatBounce, forKey: "bounce")
        case .float:
            let float = SCNAction.moveBy(x: 0, y: 0.1, z: 0, duration: 2)
            float.timingMode = .easeInEaseOut
            let sequence = SCNAction.sequence([float, float.reversed()])
            let repeatFloat = SCNAction.repeatForever(sequence)
            productNode.runAction(repeatFloat, forKey: "float")
        case .wave:
            let wave = SCNAction.customAction(duration: 4) { node, elapsedTime in
                let angle = elapsedTime * 2 * .pi
                node.position.y = sin(angle) * 0.1
                node.rotation = SCNVector4(0, 1, 0, sin(angle * 0.5) * 0.2)
            }
            let repeatWave = SCNAction.repeatForever(wave)
            productNode.runAction(repeatWave, forKey: "wave")
        }
    }

    private func updateRotation() {
        guard let scene = scene,
              let productNode = scene.rootNode.childNode(withName: "product", recursively: true) else { return }

        productNode.rotation = SCNVector4(0, 1, 0, rotationAngle)
    }

    private func updateZoom() {
        guard let cameraNode = cameraNode else { return }
        cameraNode.position = SCNVector3(0, 0, 3 / zoomLevel)
    }

    private func updateLighting() {
        guard let scene = scene else { return }

        scene.rootNode.enumerateChildNodes { node, _ in
            if let light = node.light {
                switch light.type {
                case .ambient:
                    light.intensity = 200 * lightingIntensity
                case .directional:
                    light.intensity = 1000 * lightingIntensity
                default:
                    break
                }
            }
        }
    }
}

struct ARPreviewView: UIViewRepresentable {
    let product: Product

    func makeUIView(context: Context) -> ARSCNView {
        let arView = ARSCNView()
        arView.delegate = context.coordinator
        arView.session.delegate = context.coordinator

        // Configure AR session
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal]
        arView.session.run(configuration)

        return arView
    }

    func updateUIView(_ uiView: ARSCNView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(product: product)
    }

    class Coordinator: NSObject, ARSCNViewDelegate, ARSessionDelegate {
        let product: Product
        private var productNode: SCNNode?

        init(product: Product) {
            self.product = product
        }

        func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
            guard let planeAnchor = anchor as? ARPlaneAnchor else { return }

            // Add product to detected plane
            if productNode == nil {
                let productNode = createARProductNode()
                productNode.position = SCNVector3(planeAnchor.center.x, 0, planeAnchor.center.z)
                node.addChildNode(productNode)
                self.productNode = productNode
            }
        }

        private func createARProductNode() -> SCNNode {
            // Similar to 3D scene but optimized for AR
            let geometry = SCNBox(width: 0.2, height: 0.3, length: 0.05, chamferRadius: 0.01)
            let material = SCNMaterial()
            material.diffuse.contents = UIColor.systemBlue
            geometry.materials = [material]

            let node = SCNNode(geometry: geometry)
            node.name = "ar_product"

            // Add subtle animation
            let rotation = SCNAction.rotateBy(x: 0, y: .pi * 2, z: 0, duration: 8)
            let repeatRotation = SCNAction.repeatForever(rotation)
            node.runAction(repeatRotation)

            return node
        }
    }
}

struct LoadingSceneView: View {
    @State private var rotationAngle = 0.0

    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.2), lineWidth: 4)
                    .frame(width: 60, height: 60)

                Circle()
                    .trim(from: 0, to: 0.3)
                    .stroke(Color.blue, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 60, height: 60)
                    .rotationEffect(.degrees(rotationAngle))
            }

            Text("Loading 3D Model...")
                .typography(.body2, theme: .minimal)
                .foregroundColor(.white.opacity(0.7))
        }
        .onAppear {
            withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) {
                rotationAngle = 360
            }
        }
    }
}

struct ARUnavailableView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "arkit")
                .font(.system(size: 64))
                .foregroundColor(.gray)

            VStack(spacing: 8) {
                Text("AR Not Available")
                    .typography(.title3, theme: .modern)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)

                Text("AR features require a device with ARKit support")
                    .typography(.body2, theme: .minimal)
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
            }
        }
        .padding(40)
    }
}

struct SizeComparisonView: View {
    let product: Product

    var body: some View {
        VStack(spacing: 24) {
            Text("Size Comparison")
                .typography(.title2, theme: .modern)
                .fontWeight(.semibold)
                .foregroundColor(.white)

            HStack(spacing: 20) {
                // Reference object (e.g., phone)
                VStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray)
                        .frame(width: 60, height: 120)

                    Text("iPhone")
                        .typography(.caption2, theme: .minimal)
                        .foregroundColor(.white.opacity(0.7))
                }

                Image(systemName: "arrow.left.and.right")
                    .font(.title3)
                    .foregroundColor(.blue)

                // Product size
                VStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.blue)
                        .frame(width: 80, height: 140)

                    Text(product.name)
                        .typography(.caption2, theme: .minimal)
                        .foregroundColor(.white.opacity(0.7))
                        .lineLimit(1)
                }
            }

            VStack(spacing: 12) {
                Text("Actual Size Reference")
                    .typography(.body1, theme: .modern)
                    .fontWeight(.medium)
                    .foregroundColor(.white)

                Text("This gives you a sense of the actual size when compared to everyday objects")
                    .typography(.caption1, theme: .minimal)
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct MaterialsDetailView: View {
    let product: Product

    private let materials = [
        "Cotton": "Natural, breathable, soft",
        "Polyester": "Durable, wrinkle-resistant",
        "Spandex": "Stretchy, form-fitting"
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Text("Materials & Care")
                    .typography(.title2, theme: .modern)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)

                VStack(spacing: 16) {
                    ForEach(Array(materials.keys), id: \.self) { material in
                        MaterialCard(
                            name: material,
                            description: materials[material] ?? ""
                        )
                    }
                }

                CareInstructionsView()
            }
            .padding()
        }
    }
}

struct MaterialCard: View {
    let name: String
    let description: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(name)
                .typography(.body1, theme: .modern)
                .fontWeight(.semibold)
                .foregroundColor(.white)

            Text(description)
                .typography(.caption1, theme: .minimal)
                .foregroundColor(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.1))
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
    }
}

struct CareInstructionsView: View {
    private let instructions = [
        ("thermometer.low", "Machine wash cold"),
        ("wind", "Tumble dry low"),
        ("iron", "Iron on low heat"),
        ("drop.triangle", "Do not bleach")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Care Instructions")
                .typography(.title3, theme: .modern)
                .fontWeight(.semibold)
                .foregroundColor(.white)

            VStack(spacing: 12) {
                ForEach(Array(instructions.enumerated()), id: \.offset) { _, instruction in
                    HStack(spacing: 12) {
                        Image(systemName: instruction.0)
                            .font(.title3)
                            .foregroundColor(.blue)
                            .frame(width: 24)

                        Text(instruction.1)
                            .typography(.body2, theme: .minimal)
                            .foregroundColor(.white)

                        Spacer()
                    }
                }
            }
        }
    }
}

struct ViewModeButton: View {
    let mode: Product3DPreviewView.ViewMode
    let isSelected: Bool
    let isEnabled: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                Image(systemName: mode.icon)
                    .font(.title3)
                    .foregroundColor(isSelected ? .white : (isEnabled ? .white.opacity(0.7) : .gray))

                Text(mode.rawValue)
                    .typography(.caption2, theme: .minimal)
                    .foregroundColor(isSelected ? .white : (isEnabled ? .white.opacity(0.7) : .gray))
            }
            .frame(width: 80, height: 60)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.blue : Color.white.opacity(0.1))
                    .stroke(isSelected ? Color.blue : Color.white.opacity(0.2), lineWidth: 1)
            )
        }
        .disabled(!isEnabled)
        .tapWithHaptic(.light)
    }
}

struct ActionButton: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(.white)

                Text(title)
                    .typography(.caption2, theme: .minimal)
                    .foregroundColor(.white)
            }
            .frame(height: 60)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(color)
                    .shadow(color: color.opacity(0.3), radius: 8, x: 0, y: 4)
            )
        }
        .tapWithHaptic(.medium)
    }
}

struct AnimationControlsOverlay: View {
    @Binding var selectedAnimation: Product3DPreviewView.AnimationType
    @Binding var rotationAngle: Float
    @Binding var zoomLevel: Float
    @Binding var lightingIntensity: Float
    @Binding var isVisible: Bool

    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Text("Controls")
                    .typography(.title3, theme: .modern)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)

                Spacer()

                Button(action: { isVisible = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.white.opacity(0.7))
                }
            }

            VStack(spacing: 16) {
                // Animation selector
                VStack(alignment: .leading, spacing: 8) {
                    Text("Animation")
                        .typography(.body2, theme: .minimal)
                        .foregroundColor(.white.opacity(0.8))

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(Product3DPreviewView.AnimationType.allCases, id: \.self) { animation in
                                AnimationButton(
                                    animation: animation,
                                    isSelected: selectedAnimation == animation
                                ) {
                                    selectedAnimation = animation
                                }
                            }
                        }
                        .padding(.horizontal, 4)
                    }
                }

                Divider().background(Color.white.opacity(0.2))

                // Manual controls
                ControlSlider(
                    title: "Rotation",
                    value: $rotationAngle,
                    range: 0...Float.pi * 2,
                    step: 0.1
                )

                ControlSlider(
                    title: "Zoom",
                    value: $zoomLevel,
                    range: 0.5...3.0,
                    step: 0.1
                )

                ControlSlider(
                    title: "Lighting",
                    value: $lightingIntensity,
                    range: 0.2...2.0,
                    step: 0.1
                )
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.8))
                .backdrop(BlurView(style: .systemThickMaterial))
        )
        .padding(20)
    }
}

struct AnimationButton: View {
    let animation: Product3DPreviewView.AnimationType
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Image(systemName: animation.icon)
                    .font(.caption)

                Text(animation.rawValue)
                    .typography(.caption2, theme: .minimal)
            }
            .foregroundColor(isSelected ? .white : .white.opacity(0.7))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.blue : Color.white.opacity(0.2))
            )
        }
        .tapWithHaptic(.light)
    }
}

struct ControlSlider: View {
    let title: String
    @Binding var value: Float
    let range: ClosedRange<Float>
    let step: Float

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .typography(.body2, theme: .minimal)
                    .foregroundColor(.white.opacity(0.8))

                Spacer()

                Text(String(format: "%.1f", value))
                    .typography(.caption2, theme: .minimal)
                    .foregroundColor(.blue)
                    .fontWeight(.semibold)
            }

            Slider(
                value: $value,
                in: range,
                step: step
            ) {
                Text(title)
            }
            .tint(.blue)
        }
    }
}

#Preview {
    Product3DPreviewView(
        product: Product(
            id: "1",
            name: "Elegant Summer Dress",
            brand: "Zara",
            currentPrice: 79.99,
            originalPrice: 99.99,
            imageUrl: "https://example.com/dress.jpg",
            store: "Zara",
            inStock: true,
            colors: ["#FF6B6B", "#4ECDC4"],
            onSale: true,
            salePercentage: 20,
            sustainabilityScore: 8,
            rating: 4.5
        )
    )
    .environmentObject(ThemeManager())
}