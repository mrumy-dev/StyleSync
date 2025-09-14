import SwiftUI
import SwiftData
import CoreMotion
import CoreML

struct WardrobeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var items: [StyleItem]
    @State private var appState = AppState()
    @StateObject private var wardrobeState = WardrobeState()
    @StateObject private var hapticManager = HapticManager.shared
    @StateObject private var motionManager = MotionManager()

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ZStack {
                    // Background with seasonal animation
                    SeasonalBackgroundView()

                    // Pull-to-refresh with custom animation
                    CustomRefreshableScrollView(
                        onRefresh: {
                            await refreshWardrobe()
                        }
                    ) {
                        if items.isEmpty {
                            WardrobeEmptyStateView()
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else {
                            // Pinterest-style waterfall layout
                            PinterestWaterfallLayout(
                                items: wardrobeState.filteredItems,
                                columns: wardrobeState.layoutColumns,
                                spacing: 16
                            ) { item in
                                WardrobeItemCard(
                                    item: item,
                                    onTap: { selectedItem in
                                        wardrobeState.selectedItem = selectedItem
                                        HapticManager.HapticType.subtleNudge.trigger()
                                    },
                                    onLongPress: { item in
                                        wardrobeState.showingItemActions = true
                                        wardrobeState.actionItem = item
                                        HapticManager.HapticType.customTap.trigger()
                                    }
                                )
                            }
                            .padding(.horizontal, 16)
                        }
                    }
                    .refreshable {
                        await refreshWardrobe()
                    }

                    // Floating action button with spring physics
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            FloatingActionButton {
                                wardrobeState.showingOutfitCreator = true
                                HapticManager.HapticType.celebration.trigger()
                            }
                            .padding(.trailing, 24)
                            .padding(.bottom, 100)
                        }
                    }

                    // Smart collections overlay
                    if wardrobeState.showingSmartCollections {
                        SmartCollectionsOverlay()
                            .transition(.asymmetric(
                                insertion: .move(edge: .bottom).combined(with: .opacity),
                                removal: .move(edge: .bottom).combined(with: .opacity)
                            ))
                    }
                }
            }
            .navigationTitle("Wardrobe")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        SmartCollectionsMenu()
                    } label: {
                        Image(systemName: "square.grid.3x3")
                            .font(.title2)
                            .foregroundStyle(DesignSystem.Colors.accent)
                    }
                }

                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        withAnimation(.interactiveSpring()) {
                            wardrobeState.showingSmartCollections.toggle()
                        }
                        HapticManager.HapticType.selection.trigger()
                    }) {
                        Image(systemName: "sparkles")
                            .font(.title2)
                            .foregroundStyle(DesignSystem.Colors.primary)
                    }
                }
            }
        }
        .onAppear {
            setupWardrobeState()
            motionManager.startMotionDetection { motion in
                handleShakeGesture(motion)
            }
        }
        .onDisappear {
            motionManager.stopMotionDetection()
        }
        .sheet(isPresented: $wardrobeState.showingOutfitCreator) {
            OutfitCreatorView()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .actionSheet(isPresented: $wardrobeState.showingItemActions) {
            if let item = wardrobeState.actionItem {
                return ActionSheet(
                    title: Text(item.title),
                    buttons: [
                        .default(Text("Edit")) {
                            wardrobeState.editingItem = item
                            HapticManager.HapticType.selection.trigger()
                        },
                        .default(Text("Add to Outfit")) {
                            wardrobeState.addingToOutfit = item
                            HapticManager.HapticType.success.trigger()
                        },
                        .default(Text("Share")) {
                            wardrobeState.sharingItem = item
                            HapticManager.HapticType.selection.trigger()
                        },
                        .destructive(Text("Delete")) {
                            deleteItem(item)
                            HapticManager.HapticType.error.trigger()
                        },
                        .cancel {
                            HapticManager.HapticType.selection.trigger()
                        }
                    ]
                )
            } else {
                return ActionSheet(title: Text("No item selected"))
            }
        }
        .environment(wardrobeState)
    }

    private func setupWardrobeState() {
        wardrobeState.filteredItems = items
        wardrobeState.organizeByColor()
        wardrobeState.createSmartCollections()
    }

    private func refreshWardrobe() async {
        wardrobeState.isRefreshing = true

        // Simulate AI processing and smart categorization
        try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds

        wardrobeState.organizeByColor()
        wardrobeState.createSmartCollections()
        wardrobeState.isRefreshing = false

        HapticManager.HapticType.success.trigger()
    }

    private func handleShakeGesture(_ motion: CMDeviceMotion) {
        let acceleration = motion.userAcceleration
        let magnitude = sqrt(pow(acceleration.x, 2) + pow(acceleration.y, 2) + pow(acceleration.z, 2))

        if magnitude > 2.5 && !wardrobeState.isShuffling {
            withAnimation(.easeInOut(duration: 0.8)) {
                wardrobeState.shuffleLayout()
            }
            HapticManager.HapticType.celebration.trigger()
        }
    }

    private func deleteItem(_ item: StyleItem) {
        modelContext.delete(item)
        try? modelContext.save()
    }
}

// MARK: - Pinterest Waterfall Layout

struct PinterestWaterfallLayout<Item: Identifiable, ItemView: View>: View {
    let items: [Item]
    let columns: Int
    let spacing: CGFloat
    let itemView: (Item) -> ItemView

    @State private var columnHeights: [CGFloat] = []

    init(
        items: [Item],
        columns: Int = 2,
        spacing: CGFloat = 16,
        @ViewBuilder itemView: @escaping (Item) -> ItemView
    ) {
        self.items = items
        self.columns = columns
        self.spacing = spacing
        self.itemView = itemView
    }

    var body: some View {
        GeometryReader { geometry in
            let columnWidth = (geometry.size.width - CGFloat(columns - 1) * spacing) / CGFloat(columns)

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        itemView(item)
                            .frame(width: columnWidth)
                            .background(
                                GeometryReader { itemGeometry in
                                    Color.clear
                                        .onAppear {
                                            updateColumnHeight(for: index, height: itemGeometry.size.height)
                                        }
                                }
                            )
                            .offset(
                                x: CGFloat(shortestColumnIndex()) * (columnWidth + spacing) - geometry.size.width / 2 + columnWidth / 2,
                                y: columnHeights.isEmpty ? 0 : columnHeights[shortestColumnIndex()]
                            )
                            .animation(
                                .interactiveSpring(response: 0.6, dampingFraction: 0.8, blendDuration: 0.25)
                                .delay(Double(index) * 0.05),
                                value: columnHeights
                            )
                    }
                }
                .frame(
                    height: columnHeights.isEmpty ? 0 : columnHeights.max()! + 100
                )
            }
        }
        .onAppear {
            if columnHeights.isEmpty {
                columnHeights = Array(repeating: 0, count: columns)
            }
        }
    }

    private func shortestColumnIndex() -> Int {
        guard !columnHeights.isEmpty else { return 0 }
        return columnHeights.indices.min { columnHeights[$0] < columnHeights[$1] } ?? 0
    }

    private func updateColumnHeight(for index: Int, height: CGFloat) {
        let columnIndex = shortestColumnIndex()
        if columnIndex < columnHeights.count {
            columnHeights[columnIndex] += height + spacing
        }
    }
}

// MARK: - Wardrobe Item Card

struct WardrobeItemCard: View {
    let item: StyleItem
    let onTap: (StyleItem) -> Void
    let onLongPress: (StyleItem) -> Void

    @State private var isPressed = false
    @State private var dragOffset: CGSize = .zero
    @State private var rotationAngle: Double = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Image with parallax effect
            AsyncImage(url: item.imageURL) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                RoundedRectangle(cornerRadius: 16)
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
                    .overlay(
                        Image(systemName: item.category.sfSymbol)
                            .font(.title)
                            .foregroundStyle(DesignSystem.Colors.accent)
                    )
            }
            .frame(height: CGFloat.random(in: 150...300))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                // 3D Touch Preview overlay
                RoundedRectangle(cornerRadius: 16)
                    .fill(.black.opacity(isPressed ? 0.2 : 0))
                    .animation(.easeInOut(duration: 0.2), value: isPressed)
            )

            // Item details
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(item.title)
                        .font(.headline.weight(.medium))
                        .foregroundStyle(DesignSystem.Colors.primary)
                        .lineLimit(2)

                    Spacer()

                    if item.isFavorite {
                        Image(systemName: "heart.fill")
                            .foregroundStyle(DesignSystem.Colors.accent)
                            .font(.caption)
                    }
                }

                Text(item.category)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(DesignSystem.Colors.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(DesignSystem.Colors.surface)
                    )

                // AI-generated tags
                if !item.tags.isEmpty {
                    FlowLayout(spacing: 4) {
                        ForEach(item.tags.prefix(3), id: \.self) { tag in
                            Text("#\(tag)")
                                .font(.caption2)
                                .foregroundStyle(DesignSystem.Colors.accent)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule()
                                        .fill(DesignSystem.Colors.accent.opacity(0.1))
                                )
                        }
                    }
                }
            }
            .padding(.horizontal, 4)
        }
        .padding(16)
        .background(
            GlassCardView(
                cornerRadius: 20,
                blurRadius: 15,
                opacity: 0.1,
                shadowRadius: isPressed ? 25 : 15
            ) {
                Rectangle()
                    .fill(.clear)
            }
        )
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .rotation3DEffect(
            .degrees(rotationAngle),
            axis: (x: dragOffset.height, y: -dragOffset.width, z: 0)
        )
        .offset(dragOffset)
        .gesture(
            DragGesture()
                .onChanged { value in
                    withAnimation(.interactiveSpring(response: 0.4, dampingFraction: 0.8)) {
                        dragOffset = CGSize(
                            width: value.translation.x * 0.1,
                            height: value.translation.y * 0.1
                        )
                        rotationAngle = Double(value.translation.x * 0.05)
                    }
                }
                .onEnded { _ in
                    withAnimation(.interactiveSpring(response: 0.6, dampingFraction: 0.8)) {
                        dragOffset = .zero
                        rotationAngle = 0
                    }
                }
        )
        .onTapGesture {
            onTap(item)
        }
        .onLongPressGesture(
            minimumDuration: 0.5,
            maximumDistance: 50
        ) {
            onLongPress(item)
        } onPressingChanged: { pressing in
            withAnimation(.easeInOut(duration: 0.2)) {
                isPressed = pressing
            }
        }
        .contextMenu {
            ContextMenuItems(item: item)
        }
    }
}

// MARK: - Context Menu Items

struct ContextMenuItems: View {
    let item: StyleItem

    var body: some View {
        Button(action: {}) {
            Label("Quick Look", systemImage: "eye")
        }

        Button(action: {}) {
            Label("Add to Outfit", systemImage: "plus.circle")
        }

        Button(action: {}) {
            Label("Share", systemImage: "square.and.arrow.up")
        }

        Button(action: {}) {
            Label(item.isFavorite ? "Remove from Favorites" : "Add to Favorites",
                  systemImage: item.isFavorite ? "heart.slash" : "heart")
        }

        Divider()

        Button(role: .destructive, action: {}) {
            Label("Delete", systemImage: "trash")
        }
    }
}

// MARK: - Smart Collections Menu

struct SmartCollectionsMenu: View {
    var body: some View {
        Button("Work") {
            HapticManager.HapticType.selection.trigger()
        }

        Button("Casual") {
            HapticManager.HapticType.selection.trigger()
        }

        Button("Date Night") {
            HapticManager.HapticType.selection.trigger()
        }

        Button("Seasonal") {
            HapticManager.HapticType.selection.trigger()
        }

        Divider()

        Button("Color Palette") {
            HapticManager.HapticType.selection.trigger()
        }

        Button("Recent") {
            HapticManager.HapticType.selection.trigger()
        }
    }
}

// MARK: - Smart Collections Overlay

struct SmartCollectionsOverlay: View {
    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 24) {
                Text("Smart Collections")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(DesignSystem.Colors.primary)

                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                    SmartCollectionCard(
                        title: "Work",
                        icon: "briefcase.fill",
                        color: DesignSystem.Colors.primary,
                        count: 23
                    )

                    SmartCollectionCard(
                        title: "Casual",
                        icon: "tshirt.fill",
                        color: DesignSystem.Colors.accent,
                        count: 45
                    )

                    SmartCollectionCard(
                        title: "Date Night",
                        icon: "heart.fill",
                        color: Color.pink,
                        count: 12
                    )

                    SmartCollectionCard(
                        title: "Seasonal",
                        icon: "leaf.fill",
                        color: Color.green,
                        count: 67
                    )
                }
            }
            .padding(24)
            .background(
                GlassCardView(
                    cornerRadius: 24,
                    blurRadius: 20,
                    opacity: 0.9
                ) {
                    Rectangle()
                        .fill(.clear)
                }
            )
            .padding(.horizontal, 24)
            .padding(.bottom, 100)
        }
    }
}

// MARK: - Smart Collection Card

struct SmartCollectionCard: View {
    let title: String
    let icon: String
    let color: Color
    let count: Int

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.2))
                    .frame(width: 60, height: 60)

                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(color)
            }

            VStack(spacing: 4) {
                Text(title)
                    .font(.headline.weight(.medium))
                    .foregroundStyle(DesignSystem.Colors.primary)

                Text("\(count) items")
                    .font(.caption)
                    .foregroundStyle(DesignSystem.Colors.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(DesignSystem.Colors.surface.opacity(0.8))
        )
        .onTapGesture {
            HapticManager.HapticType.selection.trigger()
        }
    }
}

// MARK: - Seasonal Background

struct SeasonalBackgroundView: View {
    @State private var animationOffset: CGFloat = 0

    var body: some View {
        ZStack {
            // Base gradient
            LinearGradient(
                colors: [
                    DesignSystem.Colors.background,
                    DesignSystem.Colors.surface.opacity(0.3)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Animated particles
            ForEach(0..<15, id: \.self) { index in
                Circle()
                    .fill(DesignSystem.Colors.accent.opacity(0.1))
                    .frame(width: CGFloat.random(in: 20...60))
                    .offset(
                        x: CGFloat.random(in: -200...200),
                        y: animationOffset + CGFloat(index * 50)
                    )
                    .animation(
                        .linear(duration: Double.random(in: 20...40))
                        .repeatForever(autoreverses: false),
                        value: animationOffset
                    )
            }
        }
        .onAppear {
            animationOffset = -1000
        }
    }
}

// MARK: - Floating Action Button

struct FloatingActionButton: View {
    let action: () -> Void
    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                DesignSystem.Colors.accent,
                                DesignSystem.Colors.accent.opacity(0.8)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 56, height: 56)
                    .shadow(
                        color: DesignSystem.Colors.accent.opacity(0.3),
                        radius: isPressed ? 20 : 15,
                        y: isPressed ? 8 : 5
                    )

                Image(systemName: "plus")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white)
            }
        }
        .scaleEffect(isPressed ? 0.9 : 1.0)
        .onLongPressGesture(
            minimumDuration: 0,
            maximumDistance: .infinity
        ) {
        } onPressingChanged: { pressing in
            withAnimation(.interactiveSpring(response: 0.4, dampingFraction: 0.6)) {
                isPressed = pressing
            }
        }
    }
}

// MARK: - Custom Refreshable ScrollView

struct CustomRefreshableScrollView<Content: View>: View {
    let onRefresh: () async -> Void
    let content: Content

    @State private var refreshOffset: CGFloat = 0
    @State private var isRefreshing = false

    init(
        onRefresh: @escaping () async -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.onRefresh = onRefresh
        self.content = content()
    }

    var body: some View {
        ScrollView {
            content
                .background(
                    GeometryReader { geometry in
                        Color.clear
                            .preference(key: RefreshPreferenceKey.self, value: geometry.frame(in: .named("refresh")).minY)
                    }
                )
        }
        .coordinateSpace(name: "refresh")
        .onPreferenceChange(RefreshPreferenceKey.self) { value in
            refreshOffset = value

            if value > 100 && !isRefreshing {
                Task {
                    isRefreshing = true
                    HapticManager.HapticType.success.trigger()
                    await onRefresh()
                    isRefreshing = false
                }
            }
        }
        .refreshable {
            await onRefresh()
        }
    }
}

struct RefreshPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    let spacing: CGFloat

    init(spacing: CGFloat = 8) {
        self.spacing = spacing
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        return layout(sizes: sizes, proposal: proposal).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        let offsets = layout(sizes: sizes, proposal: proposal).offsets

        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + offsets[index].x, y: bounds.minY + offsets[index].y), proposal: .unspecified)
        }
    }

    private func layout(sizes: [CGSize], proposal: ProposedViewSize) -> (offsets: [CGPoint], size: CGSize) {
        var result: [CGPoint] = []
        var currentPosition: CGPoint = .zero
        var lineHeight: CGFloat = 0
        var maxX: CGFloat = 0
        let maxWidth = proposal.width ?? .infinity

        for size in sizes {
            if currentPosition.x + size.width > maxWidth && currentPosition.x > 0 {
                currentPosition.x = 0
                currentPosition.y += lineHeight + spacing
                lineHeight = 0
            }

            result.append(currentPosition)
            currentPosition.x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
            maxX = max(maxX, currentPosition.x - spacing)
        }

        return (result, CGSize(width: maxX, height: currentPosition.y + lineHeight))
    }
}

// MARK: - Wardrobe Empty State

struct WardrobeEmptyStateView: View {
    var body: some View {
        VStack(spacing: 24) {
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

                Image(systemName: "tshirt")
                    .font(.system(size: 50))
                    .foregroundStyle(DesignSystem.Colors.accent)
            }

            VStack(spacing: 12) {
                Text("Build Your Wardrobe")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(DesignSystem.Colors.primary)

                Text("Start adding your favorite clothing items and create amazing outfits")
                    .font(.body)
                    .foregroundStyle(DesignSystem.Colors.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Button("Add First Item") {
                HapticManager.HapticType.success.trigger()
            }
            .buttonStyle(MagneticButtonStyle())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DesignSystem.Colors.background)
    }
}

// MARK: - Outfit Creator View

struct OutfitCreatorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedItems: [StyleItem] = []

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("Create New Outfit")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(DesignSystem.Colors.primary)

                Text("Drag and drop items to create your perfect look")
                    .font(.body)
                    .foregroundStyle(DesignSystem.Colors.secondary)
                    .multilineTextAlignment(.center)

                Spacer()
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
                    Button("Save") {
                        dismiss()
                    }
                    .disabled(selectedItems.isEmpty)
                }
            }
        }
    }
}

// MARK: - Motion Manager

class MotionManager: ObservableObject {
    private let motionManager = CMMotionManager()
    private var motionHandler: ((CMDeviceMotion) -> Void)?

    func startMotionDetection(handler: @escaping (CMDeviceMotion) -> Void) {
        motionHandler = handler

        if motionManager.isDeviceMotionAvailable {
            motionManager.deviceMotionUpdateInterval = 0.1
            motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, error in
                guard let motion = motion else { return }
                self?.motionHandler?(motion)
            }
        }
    }

    func stopMotionDetection() {
        motionManager.stopDeviceMotionUpdates()
        motionHandler = nil
    }
}

// MARK: - Wardrobe State

@MainActor
class WardrobeState: ObservableObject {
    @Published var filteredItems: [StyleItem] = []
    @Published var selectedItem: StyleItem?
    @Published var showingOutfitCreator = false
    @Published var showingItemActions = false
    @Published var showingSmartCollections = false
    @Published var actionItem: StyleItem?
    @Published var editingItem: StyleItem?
    @Published var addingToOutfit: StyleItem?
    @Published var sharingItem: StyleItem?
    @Published var isRefreshing = false
    @Published var isShuffling = false
    @Published var layoutColumns = 2

    @Published var smartCollections: [SmartCollection] = []
    @Published var colorPalettes: [ColorPalette] = []

    func organizeByColor() {
        // Simulate AI color analysis
        filteredItems.sort { item1, item2 in
            return item1.dominantColor?.hue ?? 0 < item2.dominantColor?.hue ?? 0
        }
    }

    func createSmartCollections() {
        smartCollections = [
            SmartCollection(name: "Work", items: filteredItems.filter { $0.category == "work" }),
            SmartCollection(name: "Casual", items: filteredItems.filter { $0.category == "casual" }),
            SmartCollection(name: "Date Night", items: filteredItems.filter { $0.category == "formal" }),
            SmartCollection(name: "Seasonal", items: filteredItems.filter { $0.isSeasonalItem })
        ]
    }

    func shuffleLayout() {
        isShuffling = true
        filteredItems.shuffle()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            self.isShuffling = false
        }
    }
}

// MARK: - Supporting Models

struct SmartCollection {
    let name: String
    let items: [StyleItem]
}

struct ColorPalette {
    let colors: [Color]
    let name: String
}

// MARK: - Extensions

extension StyleItem {
    var imageURL: URL? {
        // Convert imageData to URL or return placeholder
        nil
    }

    var dominantColor: Color? {
        // Extract dominant color from image
        Color.blue
    }

    var isSeasonalItem: Bool {
        tags.contains(where: { ["spring", "summer", "fall", "winter"].contains($0.lowercased()) })
    }
}

extension String {
    var sfSymbol: String {
        switch self.lowercased() {
        case "shirt", "top": return "tshirt"
        case "pants", "jeans": return "rectangle"
        case "dress": return "dress"
        case "shoes": return "shoe"
        case "accessory": return "bag"
        default: return "tshirt"
        }
    }
}

struct PremiumButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(
                LinearGradient(
                    colors: [
                        DesignSystem.Colors.accent,
                        DesignSystem.Colors.accent.opacity(0.8)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .foregroundStyle(.white)
            .font(.headline.weight(.medium))
            .clipShape(Capsule())
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: configuration.isPressed)
    }
}

#Preview {
    WardrobeView()
        .modelContainer(for: [StyleItem.self], inMemory: true)
}