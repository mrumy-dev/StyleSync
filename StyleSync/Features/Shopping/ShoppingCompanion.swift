import SwiftUI
import SwiftData
import AVFoundation
import Vision
import ARKit
import RealityKit
import VisionKit
import UserNotifications
import Combine

struct ShoppingCompanionView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var wardrobeItems: [StyleItem]
    @StateObject private var shoppingState = ShoppingState()
    @StateObject private var cameraManager = ShoppingCameraManager()
    @StateObject private var arManager = ARTryOnManager()
    @StateObject private var priceTracker = PriceTracker()
    @StateObject private var budgetManager = BudgetManager()
    @State private var selectedTab: ShoppingTab = .camera
    @State private var showingReceiptScanner = false
    @State private var showingBarcodeScanner = false
    @State private var showingWishlist = false
    @State private var showingBudgetManager = false

    var body: some View {
        NavigationStack {
            TabView(selection: $selectedTab) {
                // Live Camera Shopping
                CameraShoppingView()
                    .tabItem {
                        Image(systemName: "camera.viewfinder")
                        Text("Camera")
                    }
                    .tag(ShoppingTab.camera)

                // AR Try-On
                ARTryOnView()
                    .tabItem {
                        Image(systemName: "person.crop.rectangle.badge.plus")
                        Text("Try On")
                    }
                    .tag(ShoppingTab.tryOn)

                // Gap Analysis
                GapAnalysisView()
                    .tabItem {
                        Image(systemName: "chart.pie.fill")
                        Text("Gaps")
                    }
                    .tag(ShoppingTab.gaps)

                // Capsule Builder
                CapsuleBuilderView()
                    .tabItem {
                        Image(systemName: "square.grid.3x3")
                        Text("Capsule")
                    }
                    .tag(ShoppingTab.capsule)

                // Budget Tracker
                BudgetTrackerView()
                    .tabItem {
                        Image(systemName: "creditcard.fill")
                        Text("Budget")
                    }
                    .tag(ShoppingTab.budget)
            }
            .navigationTitle(selectedTab.title)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        ShoppingMenuView(
                            onReceiptScan: { showingReceiptScanner = true },
                            onBarcodesScan: { showingBarcodeScanner = true },
                            onWishlist: { showingWishlist = true },
                            onBudgetSettings: { showingBudgetManager = true }
                        )
                    } label: {
                        Image(systemName: "plus.circle")
                            .font(.title2)
                            .foregroundStyle(DesignSystem.Colors.accent)
                    }
                }

                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        showingWishlist = true
                    }) {
                        ZStack {
                            Image(systemName: "heart")
                                .font(.title2)
                                .foregroundStyle(DesignSystem.Colors.primary)

                            if shoppingState.wishlistCount > 0 {
                                Text("\(shoppingState.wishlistCount)")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(.white)
                                    .padding(4)
                                    .background(Circle().fill(.red))
                                    .offset(x: 12, y: -8)
                            }
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingReceiptScanner) {
            ReceiptScannerView()
                .presentationDetents([.large])
        }
        .sheet(isPresented: $showingBarcodeScanner) {
            BarcodeScannerView()
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showingWishlist) {
            WishlistView()
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showingBudgetManager) {
            BudgetManagerView()
                .presentationDetents([.medium, .large])
        }
        .environment(shoppingState)
    }
}

// MARK: - Camera Shopping View

struct CameraShoppingView: View {
    @Environment(ShoppingState.self) private var shoppingState
    @StateObject private var cameraManager = ShoppingCameraManager()
    @State private var detectedItems: [DetectedShoppingItem] = []
    @State private var isScanning = false

    var body: some View {
        ZStack {
            // Camera Feed
            CameraPreviewView(cameraManager: cameraManager)
                .ignoresSafeArea()

            // Overlay UI
            VStack {
                // Top Controls
                HStack {
                    Button("Flash") {
                        cameraManager.toggleFlash()
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(.black.opacity(0.6))
                    )

                    Spacer()

                    Button("Scan Mode") {
                        isScanning.toggle()
                        HapticManager.HapticType.selection.trigger()
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(isScanning ? DesignSystem.Colors.accent : .black.opacity(0.6))
                    )
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)

                Spacer()

                // Detection Overlay
                if isScanning && !detectedItems.isEmpty {
                    DetectionOverlayView(items: detectedItems)
                }

                Spacer()

                // Bottom Actions
                HStack(spacing: 24) {
                    Button(action: {
                        cameraManager.capturePhoto { image in
                            analyzeCapturedImage(image)
                        }
                    }) {
                        ZStack {
                            Circle()
                                .fill(.white)
                                .frame(width: 70, height: 70)

                            Circle()
                                .stroke(.white, lineWidth: 4)
                                .frame(width: 80, height: 80)

                            Image(systemName: "camera.fill")
                                .font(.title)
                                .foregroundStyle(.black)
                        }
                    }

                    Button("Visual Search") {
                        performVisualSearch()
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(
                        Capsule()
                            .fill(DesignSystem.Colors.accent)
                    )
                }
                .padding(.bottom, 30)
            }

            // Scanning Animation
            if isScanning {
                ScanningAnimationView()
            }
        }
        .onAppear {
            cameraManager.startSession()
            startRealTimeDetection()
        }
        .onDisappear {
            cameraManager.stopSession()
        }
    }

    private func startRealTimeDetection() {
        // Start real-time object detection
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            if isScanning {
                performItemDetection()
            }
        }
    }

    private func performItemDetection() {
        // Simulate fashion item detection
        detectedItems = [
            DetectedShoppingItem(
                name: "Black Leather Jacket",
                confidence: 0.92,
                price: 299.99,
                brand: "Zara",
                boundingBox: CGRect(x: 0.3, y: 0.2, width: 0.4, height: 0.6),
                similarity: 0.85
            ),
            DetectedShoppingItem(
                name: "Dark Jeans",
                confidence: 0.87,
                price: 89.99,
                brand: "Levi's",
                boundingBox: CGRect(x: 0.2, y: 0.5, width: 0.6, height: 0.4),
                similarity: 0.73
            )
        ]
    }

    private func analyzeCapturedImage(_ image: UIImage) {
        // Analyze captured image for shopping items
        HapticManager.HapticType.success.trigger()
    }

    private func performVisualSearch() {
        // Perform visual search on current camera frame
        HapticManager.HapticType.success.trigger()
    }
}

// MARK: - AR Try-On View

struct ARTryOnView: View {
    @StateObject private var arManager = ARTryOnManager()
    @State private var selectedItem: ShoppingItem?
    @State private var arItems: [ARWearableItem] = []

    var body: some View {
        ZStack {
            // AR Session View
            ARViewContainer(arManager: arManager)
                .ignoresSafeArea()

            // AR Controls
            VStack {
                // Top Controls
                HStack {
                    Button("Reset") {
                        arManager.resetSession()
                        HapticManager.HapticType.lightImpact.trigger()
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(.black.opacity(0.6))
                    )

                    Spacer()

                    Button("Record") {
                        arManager.startRecording()
                        HapticManager.HapticType.success.trigger()
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(.red.opacity(0.8))
                    )
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)

                Spacer()

                // Item Selection Carousel
                ARItemCarousel(
                    items: arItems,
                    selectedItem: $selectedItem,
                    onItemSelect: { item in
                        arManager.addItemToScene(item)
                    }
                )
                .padding(.bottom, 30)
            }

            // Try-On Instructions
            if arManager.trackingState == .initializing {
                ARInstructionsView()
            }

            // Fit Analysis Overlay
            if let analysis = arManager.fitAnalysis {
                ARFitAnalysisOverlay(analysis: analysis)
            }
        }
        .onAppear {
            setupARItems()
            arManager.startSession()
        }
        .onDisappear {
            arManager.pauseSession()
        }
    }

    private func setupARItems() {
        arItems = [
            ARWearableItem(
                id: UUID(),
                name: "Classic T-Shirt",
                category: .top,
                colors: [.white, .black, .gray],
                sizes: ["S", "M", "L", "XL"],
                price: 29.99,
                arModel: "tshirt_model"
            ),
            ARWearableItem(
                id: UUID(),
                name: "Denim Jacket",
                category: .outerwear,
                colors: [.blue, .black],
                sizes: ["S", "M", "L"],
                price: 89.99,
                arModel: "denim_jacket_model"
            )
        ]
    }
}

// MARK: - Gap Analysis View

struct GapAnalysisView: View {
    @Environment(ShoppingState.self) private var shoppingState
    @Query private var wardrobeItems: [StyleItem]
    @State private var analysis: WardrobeGapAnalysis?
    @State private var showingVisualGaps = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Analysis Header
                GapAnalysisHeaderView(analysis: analysis)

                // Visual Gap Overview
                if let analysis = analysis {
                    VisualGapOverviewCard(
                        analysis: analysis,
                        onViewDetails: { showingVisualGaps = true }
                    )

                    // Category Gaps
                    CategoryGapsSection(gaps: analysis.categoryGaps)

                    // Color Gaps
                    ColorGapsSection(colorGaps: analysis.colorGaps)

                    // Seasonal Gaps
                    SeasonalGapsSection(seasonalGaps: analysis.seasonalGaps)

                    // Investment Recommendations
                    InvestmentRecommendationsSection(recommendations: analysis.investmentPieces)
                }
            }
            .padding(20)
        }
        .onAppear {
            analyzeWardrobeGaps()
        }
        .sheet(isPresented: $showingVisualGaps) {
            VisualGapAnalysisView(analysis: analysis)
                .presentationDetents([.large])
        }
    }

    private func analyzeWardrobeGaps() {
        Task {
            let gapAnalysis = await GapAnalyzer.shared.analyzeWardrobe(wardrobeItems)
            await MainActor.run {
                analysis = gapAnalysis
            }
        }
    }
}

// MARK: - Capsule Builder View

struct CapsuleBuilderView: View {
    @Environment(ShoppingState.self) private var shoppingState
    @StateObject private var capsuleBuilder = CapsuleBuilder()
    @State private var selectedCapsuleType: CapsuleType = .minimal
    @State private var showingCapsulePreview = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Capsule Type Selector
                CapsuleTypeSelectorView(
                    selectedType: $selectedCapsuleType,
                    onTypeChange: { type in
                        capsuleBuilder.buildCapsule(type: type)
                    }
                )

                // Capsule Overview
                if let capsule = capsuleBuilder.currentCapsule {
                    CapsuleOverviewCard(
                        capsule: capsule,
                        onPreview: { showingCapsulePreview = true }
                    )

                    // Essential Items
                    EssentialItemsSection(essentials: capsule.essentialItems)

                    // Mix & Match Matrix
                    MixMatchMatrixView(combinations: capsule.combinations)

                    // Cost Analysis
                    CapsuleCostAnalysisView(costAnalysis: capsule.costAnalysis)

                    // Shopping List
                    CapsuleShoppingListView(
                        missingItems: capsule.missingItems,
                        onAddToWishlist: { item in
                            shoppingState.addToWishlist(item)
                        }
                    )
                }
            }
            .padding(20)
        }
        .onAppear {
            capsuleBuilder.buildCapsule(type: selectedCapsuleType)
        }
        .sheet(isPresented: $showingCapsulePreview) {
            CapsulePreviewView(capsule: capsuleBuilder.currentCapsule)
                .presentationDetents([.large])
        }
    }
}

// MARK: - Budget Tracker View

struct BudgetTrackerView: View {
    @Environment(ShoppingState.self) private var shoppingState
    @StateObject private var budgetManager = BudgetManager()
    @State private var showingBudgetSetup = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Budget Overview
                BudgetOverviewCard(budget: budgetManager.currentBudget)

                // Spending Analysis
                SpendingAnalysisView(
                    spending: budgetManager.monthlySpending,
                    budget: budgetManager.currentBudget
                )

                // Category Breakdown
                CategorySpendingView(categorySpending: budgetManager.categorySpending)

                // Cost Per Wear Analysis
                CostPerWearSection(items: budgetManager.trackedItems)

                // Investment Tracker
                InvestmentTrackerView(investments: budgetManager.investmentPieces)

                // Alerts & Notifications
                BudgetAlertsView(alerts: budgetManager.budgetAlerts)
            }
            .padding(20)
        }
        .onAppear {
            budgetManager.loadBudget()
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Setup") {
                    showingBudgetSetup = true
                }
            }
        }
        .sheet(isPresented: $showingBudgetSetup) {
            BudgetSetupView()
                .presentationDetents([.medium, .large])
        }
    }
}

// MARK: - Detection Overlay

struct DetectionOverlayView: View {
    let items: [DetectedShoppingItem]

    var body: some View {
        GeometryReader { geometry in
            ForEach(items, id: \.id) { item in
                DetectionBoxView(item: item, geometry: geometry)
            }
        }
    }
}

struct DetectionBoxView: View {
    let item: DetectedShoppingItem
    let geometry: GeometryProxy

    var body: some View {
        let box = CGRect(
            x: item.boundingBox.minX * geometry.size.width,
            y: item.boundingBox.minY * geometry.size.height,
            width: item.boundingBox.width * geometry.size.width,
            height: item.boundingBox.height * geometry.size.height
        )

        ZStack {
            Rectangle()
                .stroke(DesignSystem.Colors.accent, lineWidth: 2)
                .frame(width: box.width, height: box.height)
                .position(x: box.midX, y: box.midY)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white)

                HStack {
                    Text("$\(String(format: "%.0f", item.price))")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(DesignSystem.Colors.accent)

                    Text("\(Int(item.confidence * 100))%")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.8))
                }

                if item.similarity > 0.7 {
                    HStack(spacing: 2) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption2)
                            .foregroundStyle(.yellow)

                        Text("\(Int(item.similarity * 100))% similar")
                            .font(.caption2)
                            .foregroundStyle(.yellow)
                    }
                }
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(.black.opacity(0.8))
            )
            .position(x: box.midX, y: box.minY - 20)
        }
    }
}

// MARK: - Scanning Animation

struct ScanningAnimationView: View {
    @State private var scannerPosition: CGFloat = -200

    var body: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [
                        .clear,
                        DesignSystem.Colors.accent.opacity(0.3),
                        .clear
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(height: 2)
            .offset(y: scannerPosition)
            .onAppear {
                withAnimation(
                    .linear(duration: 2.0)
                    .repeatForever(autoreverses: false)
                ) {
                    scannerPosition = 200
                }
            }
    }
}

// MARK: - Receipt Scanner

struct ReceiptScannerView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var receiptScanner = ReceiptScanner()
    @State private var scannedReceipt: ScannedReceipt?
    @State private var isScanning = false

    var body: some View {
        NavigationStack {
            VStack {
                if let receipt = scannedReceipt {
                    ReceiptResultsView(receipt: receipt)
                } else {
                    VStack(spacing: 24) {
                        Image(systemName: "doc.text.viewfinder")
                            .font(.system(size: 80))
                            .foregroundStyle(DesignSystem.Colors.accent)

                        VStack(spacing: 12) {
                            Text("Scan Receipt")
                                .font(.title2.weight(.semibold))
                                .foregroundStyle(DesignSystem.Colors.primary)

                            Text("Automatically track purchases and analyze spending patterns")
                                .font(.body)
                                .foregroundStyle(DesignSystem.Colors.secondary)
                                .multilineTextAlignment(.center)
                        }

                        Button("Start Scanning") {
                            startScanning()
                        }
                        .buttonStyle(PrimaryButtonStyle())
                    }
                    .padding(32)
                }

                Spacer()
            }
            .navigationTitle("Receipt Scanner")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                if scannedReceipt != nil {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Save") {
                            saveReceipt()
                            dismiss()
                        }
                    }
                }
            }
        }
    }

    private func startScanning() {
        isScanning = true
        Task {
            let receipt = await receiptScanner.scanReceipt()
            await MainActor.run {
                scannedReceipt = receipt
                isScanning = false
            }
        }
    }

    private func saveReceipt() {
        guard let receipt = scannedReceipt else { return }
        receiptScanner.saveReceipt(receipt)
        HapticManager.HapticType.success.trigger()
    }
}

// MARK: - Barcode Scanner

struct BarcodeScannerView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var barcodeScanner = BarcodeScanner()
    @State private var scannedProduct: ScannedProduct?

    var body: some View {
        NavigationStack {
            VStack {
                if let product = scannedProduct {
                    ProductInfoView(product: product)
                } else {
                    ZStack {
                        CameraPreviewView(cameraManager: ShoppingCameraManager())
                            .ignoresSafeArea()

                        BarcodeScanningOverlay()
                    }
                }
            }
            .navigationTitle("Barcode Scanner")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            barcodeScanner.startScanning { product in
                scannedProduct = product
                HapticManager.HapticType.success.trigger()
            }
        }
    }
}

// MARK: - Wishlist View

struct WishlistView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ShoppingState.self) private var shoppingState

    var body: some View {
        NavigationStack {
            List {
                ForEach(shoppingState.wishlistItems) { item in
                    WishlistItemRow(
                        item: item,
                        onRemove: { item in
                            shoppingState.removeFromWishlist(item)
                        },
                        onPriceAlert: { item in
                            shoppingState.setPriceAlert(for: item)
                        }
                    )
                }
                .onDelete(perform: deleteItems)
            }
            .navigationTitle("Wishlist")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
            }
        }
    }

    private func deleteItems(offsets: IndexSet) {
        for index in offsets {
            shoppingState.removeFromWishlist(shoppingState.wishlistItems[index])
        }
    }
}

// MARK: - Data Models and State

@MainActor
class ShoppingState: ObservableObject {
    @Published var wishlistItems: [WishlistItem] = []
    @Published var priceAlerts: [PriceAlert] = []
    @Published var budgetAlerts: [BudgetAlert] = []
    @Published var currentBudget: ShoppingBudget?

    var wishlistCount: Int {
        wishlistItems.count
    }

    func addToWishlist(_ item: ShoppingItem) {
        let wishlistItem = WishlistItem(
            id: UUID(),
            item: item,
            addedAt: Date(),
            targetPrice: item.price * 0.8,
            isOnSale: false,
            lastChecked: Date()
        )
        wishlistItems.append(wishlistItem)
    }

    func removeFromWishlist(_ item: WishlistItem) {
        wishlistItems.removeAll { $0.id == item.id }
    }

    func setPriceAlert(for item: WishlistItem) {
        let alert = PriceAlert(
            id: UUID(),
            itemId: item.id,
            targetPrice: item.targetPrice,
            isActive: true,
            createdAt: Date()
        )
        priceAlerts.append(alert)
    }
}

enum ShoppingTab: CaseIterable {
    case camera, tryOn, gaps, capsule, budget

    var title: String {
        switch self {
        case .camera: return "Camera Shopping"
        case .tryOn: return "AR Try-On"
        case .gaps: return "Gap Analysis"
        case .capsule: return "Capsule Builder"
        case .budget: return "Budget Tracker"
        }
    }
}

struct DetectedShoppingItem: Identifiable {
    let id = UUID()
    let name: String
    let confidence: Double
    let price: Double
    let brand: String
    let boundingBox: CGRect
    let similarity: Double
}

struct ShoppingItem: Identifiable {
    let id = UUID()
    let name: String
    let brand: String
    let price: Double
    let category: String
    let imageURL: URL?
    let colors: [Color]
    let sizes: [String]
    let description: String
}

struct WishlistItem: Identifiable {
    let id: UUID
    let item: ShoppingItem
    let addedAt: Date
    let targetPrice: Double
    let isOnSale: Bool
    let lastChecked: Date
}

struct PriceAlert: Identifiable {
    let id: UUID
    let itemId: UUID
    let targetPrice: Double
    let isActive: Bool
    let createdAt: Date
}

struct BudgetAlert: Identifiable {
    let id = UUID()
    let message: String
    let type: BudgetAlertType
    let createdAt: Date
}

enum BudgetAlertType {
    case overspending, nearLimit, monthlyReset
}

struct WardrobeGapAnalysis {
    let categoryGaps: [CategoryGap]
    let colorGaps: [ColorGap]
    let seasonalGaps: [SeasonalGap]
    let investmentPieces: [InvestmentRecommendation]
    let overallScore: Double
    let completeness: Double
}

struct CategoryGap {
    let category: String
    let priority: GapPriority
    let missingItems: [String]
    let recommendations: [ShoppingItem]
}

struct ColorGap {
    let color: Color
    let importance: Double
    let suggestions: [ShoppingItem]
}

struct SeasonalGap {
    let season: String
    let gaps: [CategoryGap]
    let urgency: GapUrgency
}

struct InvestmentRecommendation {
    let item: ShoppingItem
    let justification: String
    let costPerWearProjection: Double
    let qualityScore: Double
}

enum GapPriority: CaseIterable {
    case high, medium, low

    var color: Color {
        switch self {
        case .high: return .red
        case .medium: return .orange
        case .low: return .blue
        }
    }
}

enum GapUrgency {
    case immediate, upcoming, future
}

// MARK: - Managers and Services

class ShoppingCameraManager: ObservableObject {
    private let captureSession = AVCaptureSession()
    private var photoOutput = AVCapturePhotoOutput()

    func startSession() {
        // Start camera session
    }

    func stopSession() {
        // Stop camera session
    }

    func toggleFlash() {
        // Toggle camera flash
    }

    func capturePhoto(completion: @escaping (UIImage) -> Void) {
        // Capture photo and return UIImage
    }
}

class ARTryOnManager: ObservableObject {
    @Published var trackingState: ARTrackingState = .initializing
    @Published var fitAnalysis: ARFitAnalysis?

    func startSession() {
        // Start AR session
    }

    func pauseSession() {
        // Pause AR session
    }

    func resetSession() {
        // Reset AR session
    }

    func addItemToScene(_ item: ARWearableItem) {
        // Add 3D item to AR scene
    }

    func startRecording() {
        // Start AR recording
    }
}

enum ARTrackingState {
    case initializing, tracking, limited, notAvailable
}

class PriceTracker: ObservableObject {
    @Published var trackedItems: [TrackedItem] = []

    func trackPrice(for item: ShoppingItem) {
        // Track price changes
    }

    func checkPriceUpdates() async {
        // Check for price updates
    }
}

class BudgetManager: ObservableObject {
    @Published var currentBudget: ShoppingBudget?
    @Published var monthlySpending: Double = 0
    @Published var categorySpending: [String: Double] = [:]
    @Published var trackedItems: [TrackedPurchase] = []
    @Published var investmentPieces: [InvestmentPiece] = []
    @Published var budgetAlerts: [BudgetAlert] = []

    func loadBudget() {
        // Load budget data
    }

    func updateSpending(_ amount: Double, category: String) {
        // Update spending tracking
    }
}

class ReceiptScanner: ObservableObject {
    func scanReceipt() async -> ScannedReceipt {
        // OCR receipt scanning
        return ScannedReceipt(
            id: UUID(),
            store: "Zara",
            date: Date(),
            total: 127.98,
            items: [
                ReceiptItem(name: "Black T-Shirt", price: 29.99, quantity: 2),
                ReceiptItem(name: "Jeans", price: 67.99, quantity: 1)
            ],
            tax: 10.24,
            paymentMethod: "Credit Card"
        )
    }

    func saveReceipt(_ receipt: ScannedReceipt) {
        // Save receipt to database
    }
}

class BarcodeScanner: ObservableObject {
    func startScanning(completion: @escaping (ScannedProduct) -> Void) {
        // Start barcode scanning
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            completion(ScannedProduct(
                id: UUID(),
                barcode: "123456789",
                name: "Classic White T-Shirt",
                brand: "H&M",
                price: 19.99,
                availability: .inStock
            ))
        }
    }
}

class GapAnalyzer {
    static let shared = GapAnalyzer()

    func analyzeWardrobe(_ items: [StyleItem]) async -> WardrobeGapAnalysis {
        // Analyze wardrobe gaps
        return WardrobeGapAnalysis(
            categoryGaps: [
                CategoryGap(
                    category: "Blazers",
                    priority: .high,
                    missingItems: ["Navy Blazer", "Black Blazer"],
                    recommendations: []
                )
            ],
            colorGaps: [],
            seasonalGaps: [],
            investmentPieces: [],
            overallScore: 7.2,
            completeness: 0.72
        )
    }
}

class CapsuleBuilder: ObservableObject {
    @Published var currentCapsule: CapsuleWardrobe?

    func buildCapsule(type: CapsuleType) {
        // Build capsule wardrobe
        currentCapsule = CapsuleWardrobe(
            type: type,
            essentialItems: [],
            combinations: [],
            missingItems: [],
            costAnalysis: CapsuleCostAnalysis(
                totalCost: 1250,
                averageCostPerWear: 15.50,
                investmentValue: 0.85
            )
        )
    }
}

enum CapsuleType: CaseIterable {
    case minimal, professional, casual, travel

    var title: String {
        switch self {
        case .minimal: return "Minimalist"
        case .professional: return "Professional"
        case .casual: return "Casual"
        case .travel: return "Travel"
        }
    }
}

// MARK: - Supporting Models

struct ARWearableItem: Identifiable {
    let id: UUID
    let name: String
    let category: WearableCategory
    let colors: [Color]
    let sizes: [String]
    let price: Double
    let arModel: String
}

enum WearableCategory {
    case top, bottom, outerwear, accessory
}

struct ARFitAnalysis {
    let overallFit: FitQuality
    let recommendations: [String]
    let measurements: BodyMeasurements
}

struct BodyMeasurements {
    let chest: Double?
    let waist: Double?
    let hips: Double?
    let shoulderWidth: Double?
}

struct ScannedReceipt: Identifiable {
    let id: UUID
    let store: String
    let date: Date
    let total: Double
    let items: [ReceiptItem]
    let tax: Double
    let paymentMethod: String
}

struct ReceiptItem {
    let name: String
    let price: Double
    let quantity: Int
}

struct ScannedProduct: Identifiable {
    let id: UUID
    let barcode: String
    let name: String
    let brand: String
    let price: Double
    let availability: ProductAvailability
}

enum ProductAvailability {
    case inStock, lowStock, outOfStock, unknown
}

struct TrackedItem: Identifiable {
    let id = UUID()
    let item: ShoppingItem
    let currentPrice: Double
    let priceHistory: [PricePoint]
    let alerts: [PriceAlert]
}

struct PricePoint {
    let date: Date
    let price: Double
}

struct ShoppingBudget {
    let monthlyLimit: Double
    let categoryLimits: [String: Double]
    let currentSpending: Double
    let remainingBudget: Double
}

struct TrackedPurchase: Identifiable {
    let id = UUID()
    let item: ShoppingItem
    let purchaseDate: Date
    let price: Double
    let wearCount: Int
    let costPerWear: Double
}

struct InvestmentPiece: Identifiable {
    let id = UUID()
    let item: ShoppingItem
    let purchaseDate: Date
    let originalPrice: Double
    let projectedLifespan: Int
    let qualityRating: Double
}

struct CapsuleWardrobe {
    let type: CapsuleType
    let essentialItems: [EssentialItem]
    let combinations: [OutfitCombination]
    let missingItems: [ShoppingItem]
    let costAnalysis: CapsuleCostAnalysis
}

struct EssentialItem {
    let item: ShoppingItem
    let importance: Double
    let versatility: Double
    let owned: Bool
}

struct OutfitCombination {
    let id = UUID()
    let items: [ShoppingItem]
    let occasion: String
    let season: String
    let styleScore: Double
}

struct CapsuleCostAnalysis {
    let totalCost: Double
    let averageCostPerWear: Double
    let investmentValue: Double
}

// MARK: - Supporting Views

struct CameraPreviewView: UIViewRepresentable {
    let cameraManager: ShoppingCameraManager

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        // Setup camera preview layer
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}

struct ARViewContainer: UIViewRepresentable {
    let arManager: ARTryOnManager

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        // Setup AR session
        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {}
}

// MARK: - Placeholder Views

struct ARItemCarousel: View {
    let items: [ARWearableItem]
    @Binding var selectedItem: ShoppingItem?
    let onItemSelect: (ARWearableItem) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(items) { item in
                    Button(item.name) {
                        onItemSelect(item)
                    }
                    .padding()
                    .background(DesignSystem.Colors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            .padding(.horizontal, 20)
        }
    }
}

struct ARInstructionsView: View {
    var body: some View {
        VStack(spacing: 16) {
            Text("Position yourself in good lighting")
                .font(.headline)
                .foregroundStyle(.white)

            Text("Move slowly to help the camera track your body")
                .font(.body)
                .foregroundStyle(.white.opacity(0.8))
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.black.opacity(0.7))
        )
    }
}

struct ARFitAnalysisOverlay: View {
    let analysis: ARFitAnalysis

    var body: some View {
        VStack {
            Spacer()
            HStack {
                VStack(alignment: .leading) {
                    Text("Fit Analysis")
                        .font(.headline.weight(.medium))
                        .foregroundStyle(.white)

                    Text("Overall: \(analysis.overallFit.description)")
                        .font(.body)
                        .foregroundStyle(.white.opacity(0.8))
                }
                Spacer()
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.black.opacity(0.7))
            )
            .padding(.horizontal, 20)
            .padding(.bottom, 100)
        }
    }
}

struct ShoppingMenuView: View {
    let onReceiptScan: () -> Void
    let onBarcodesScan: () -> Void
    let onWishlist: () -> Void
    let onBudgetSettings: () -> Void

    var body: some View {
        Button("Scan Receipt", systemImage: "doc.text.viewfinder") {
            onReceiptScan()
        }

        Button("Scan Barcode", systemImage: "barcode.viewfinder") {
            onBarcodesScan()
        }

        Button("Wishlist", systemImage: "heart") {
            onWishlist()
        }

        Divider()

        Button("Budget Settings", systemImage: "dollarsign.circle") {
            onBudgetSettings()
        }
    }
}

// MARK: - Placeholder views for complex features

struct GapAnalysisHeaderView: View {
    let analysis: WardrobeGapAnalysis?

    var body: some View {
        VStack {
            Text("Gap Analysis")
                .font(.title2.weight(.semibold))
            if let analysis = analysis {
                Text("Completeness: \(Int(analysis.completeness * 100))%")
                    .font(.body)
                    .foregroundStyle(DesignSystem.Colors.secondary)
            }
        }
    }
}

struct VisualGapOverviewCard: View {
    let analysis: WardrobeGapAnalysis
    let onViewDetails: () -> Void

    var body: some View {
        Button("View Visual Gaps", action: onViewDetails)
            .buttonStyle(PrimaryButtonStyle())
    }
}

struct CategoryGapsSection: View {
    let gaps: [CategoryGap]

    var body: some View {
        VStack {
            Text("Category Gaps")
                .font(.headline)
            // Implementation placeholder
        }
    }
}

struct ColorGapsSection: View {
    let colorGaps: [ColorGap]

    var body: some View {
        VStack {
            Text("Color Gaps")
                .font(.headline)
            // Implementation placeholder
        }
    }
}

struct SeasonalGapsSection: View {
    let seasonalGaps: [SeasonalGap]

    var body: some View {
        VStack {
            Text("Seasonal Gaps")
                .font(.headline)
            // Implementation placeholder
        }
    }
}

struct InvestmentRecommendationsSection: View {
    let recommendations: [InvestmentRecommendation]

    var body: some View {
        VStack {
            Text("Investment Pieces")
                .font(.headline)
            // Implementation placeholder
        }
    }
}

struct VisualGapAnalysisView: View {
    let analysis: WardrobeGapAnalysis?

    var body: some View {
        Text("Visual Gap Analysis")
            .font(.title)
    }
}

struct CapsuleTypeSelectorView: View {
    @Binding var selectedType: CapsuleType
    let onTypeChange: (CapsuleType) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                ForEach(CapsuleType.allCases, id: \.self) { type in
                    Button(type.title) {
                        selectedType = type
                        onTypeChange(type)
                    }
                    .buttonStyle(selectedType == type ? PrimaryButtonStyle() : SecondaryButtonStyle())
                }
            }
            .padding(.horizontal)
        }
    }
}

struct CapsuleOverviewCard: View {
    let capsule: CapsuleWardrobe
    let onPreview: () -> Void

    var body: some View {
        Button("Preview Capsule", action: onPreview)
            .buttonStyle(PrimaryButtonStyle())
    }
}

struct EssentialItemsSection: View {
    let essentials: [EssentialItem]

    var body: some View {
        VStack {
            Text("Essential Items")
                .font(.headline)
            // Implementation placeholder
        }
    }
}

struct MixMatchMatrixView: View {
    let combinations: [OutfitCombination]

    var body: some View {
        VStack {
            Text("Mix & Match Matrix")
                .font(.headline)
            // Implementation placeholder
        }
    }
}

struct CapsuleCostAnalysisView: View {
    let costAnalysis: CapsuleCostAnalysis

    var body: some View {
        VStack {
            Text("Cost Analysis")
                .font(.headline)
            Text("Total: $\(String(format: "%.0f", costAnalysis.totalCost))")
        }
    }
}

struct CapsuleShoppingListView: View {
    let missingItems: [ShoppingItem]
    let onAddToWishlist: (ShoppingItem) -> Void

    var body: some View {
        VStack {
            Text("Shopping List")
                .font(.headline)
            // Implementation placeholder
        }
    }
}

struct CapsulePreviewView: View {
    let capsule: CapsuleWardrobe?

    var body: some View {
        Text("Capsule Preview")
            .font(.title)
    }
}

struct BudgetOverviewCard: View {
    let budget: ShoppingBudget?

    var body: some View {
        VStack {
            Text("Budget Overview")
                .font(.headline)
            // Implementation placeholder
        }
    }
}

struct SpendingAnalysisView: View {
    let spending: Double
    let budget: ShoppingBudget?

    var body: some View {
        VStack {
            Text("Spending Analysis")
                .font(.headline)
            // Implementation placeholder
        }
    }
}

struct CategorySpendingView: View {
    let categorySpending: [String: Double]

    var body: some View {
        VStack {
            Text("Category Spending")
                .font(.headline)
            // Implementation placeholder
        }
    }
}

struct CostPerWearSection: View {
    let items: [TrackedPurchase]

    var body: some View {
        VStack {
            Text("Cost Per Wear")
                .font(.headline)
            // Implementation placeholder
        }
    }
}

struct InvestmentTrackerView: View {
    let investments: [InvestmentPiece]

    var body: some View {
        VStack {
            Text("Investment Tracker")
                .font(.headline)
            // Implementation placeholder
        }
    }
}

struct BudgetAlertsView: View {
    let alerts: [BudgetAlert]

    var body: some View {
        VStack {
            Text("Budget Alerts")
                .font(.headline)
            // Implementation placeholder
        }
    }
}

struct BudgetSetupView: View {
    var body: some View {
        Text("Budget Setup")
            .font(.title)
    }
}

struct ReceiptResultsView: View {
    let receipt: ScannedReceipt

    var body: some View {
        VStack {
            Text("Receipt Results")
                .font(.headline)
            Text("Store: \(receipt.store)")
            Text("Total: $\(String(format: "%.2f", receipt.total))")
        }
    }
}

struct ProductInfoView: View {
    let product: ScannedProduct

    var body: some View {
        VStack {
            Text("Product Info")
                .font(.headline)
            Text(product.name)
            Text("$\(String(format: "%.2f", product.price))")
        }
    }
}

struct BarcodeScanningOverlay: View {
    var body: some View {
        Rectangle()
            .stroke(DesignSystem.Colors.accent, lineWidth: 2)
            .frame(width: 200, height: 100)
            .overlay(
                Text("Position barcode here")
                    .font(.caption)
                    .foregroundStyle(.white)
                    .offset(y: -60)
            )
    }
}

struct WishlistItemRow: View {
    let item: WishlistItem
    let onRemove: (WishlistItem) -> Void
    let onPriceAlert: (WishlistItem) -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(item.item.name)
                    .font(.headline)
                Text("$\(String(format: "%.2f", item.item.price))")
                    .font(.subheadline)
                    .foregroundStyle(DesignSystem.Colors.secondary)
            }

            Spacer()

            Button("Alert") {
                onPriceAlert(item)
            }
            .buttonStyle(SecondaryButtonStyle())
        }
    }
}

extension FitQuality {
    var description: String {
        switch self {
        case .excellent: return "Excellent"
        case .good: return "Good"
        case .fair: return "Fair"
        case .poor: return "Poor"
        case .unknown: return "Unknown"
        }
    }
}

#Preview {
    ShoppingCompanionView()
        .modelContainer(for: [StyleItem.self], inMemory: true)
}