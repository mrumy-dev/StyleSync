import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins

// MARK: - Content Editor View
struct ContentEditorView: View {
    let capturedMedia: CapturedMedia
    let creationType: CreationType
    @StateObject private var editorManager = ContentEditorManager()
    @Environment(\.theme) private var theme
    @Environment(\.presentationMode) var presentationMode
    @State private var selectedTool: EditorTool = .filters
    @State private var showingPublishView = false

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Preview Area
                    ContentPreviewArea(
                        capturedMedia: capturedMedia,
                        editorManager: editorManager
                    )

                    // Editor Tools
                    EditorToolsView(
                        selectedTool: $selectedTool,
                        editorManager: editorManager,
                        creationType: creationType
                    )
                }
            }
            .navigationBarHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(.white)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Next") {
                        showingPublishView = true
                    }
                    .foregroundColor(theme.colors.primary)
                    .fontWeight(.semibold)
                }
            }
        }
        .sheet(isPresented: $showingPublishView) {
            PublishContentView(
                editedMedia: editorManager.getEditedMedia(),
                creationType: creationType
            )
        }
        .onAppear {
            editorManager.loadMedia(capturedMedia)
        }
    }
}

// MARK: - Editor Tools
enum EditorTool: String, CaseIterable {
    case filters = "filters"
    case adjust = "adjust"
    case effects = "effects"
    case text = "text"
    case stickers = "stickers"
    case music = "music"
    case layout = "layout"
    case crop = "crop"

    var displayName: String {
        switch self {
        case .filters: return "Filters"
        case .adjust: return "Adjust"
        case .effects: return "Effects"
        case .text: return "Text"
        case .stickers: return "Stickers"
        case .music: return "Music"
        case .layout: return "Layout"
        case .crop: return "Crop"
        }
    }

    var icon: String {
        switch self {
        case .filters: return "camera.filters"
        case .adjust: return "slider.horizontal.3"
        case .effects: return "wand.and.stars"
        case .text: return "textformat"
        case .stickers: return "face.smiling"
        case .music: return "music.note"
        case .layout: return "rectangle.grid.2x2"
        case .crop: return "crop"
        }
    }
}

// MARK: - Content Preview Area
struct ContentPreviewArea: View {
    let capturedMedia: CapturedMedia
    let editorManager: ContentEditorManager
    @State private var dragOffset = CGSize.zero
    @State private var scale: CGFloat = 1.0

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Main Content
                switch capturedMedia.type {
                case .image(let image):
                    EditableImageView(
                        image: image,
                        editorManager: editorManager,
                        dragOffset: $dragOffset,
                        scale: $scale
                    )

                case .video(let url):
                    EditableVideoView(
                        videoURL: url,
                        editorManager: editorManager
                    )
                }

                // Overlay Elements (Text, Stickers, etc.)
                ForEach(editorManager.overlayElements, id: \.id) { element in
                    OverlayElementView(element: element, editorManager: editorManager)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
            .gesture(
                MagnificationGesture()
                    .onChanged { value in
                        scale = value
                    }
                    .onEnded { _ in
                        editorManager.updateScale(scale)
                    }
            )
        }
        .aspectRatio(9/16, contentMode: .fit)
        .background(Color.black)
    }
}

// MARK: - Editable Image View
struct EditableImageView: View {
    let image: UIImage
    let editorManager: ContentEditorManager
    @Binding var dragOffset: CGSize
    @Binding var scale: CGFloat

    var body: some View {
        Image(uiImage: editorManager.processedImage ?? image)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .scaleEffect(scale)
            .offset(dragOffset)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        dragOffset = value.translation
                    }
                    .onEnded { _ in
                        editorManager.updatePosition(dragOffset)
                        dragOffset = .zero
                    }
            )
    }
}

// MARK: - Editable Video View
struct EditableVideoView: View {
    let videoURL: URL
    let editorManager: ContentEditorManager
    @State private var player: AVPlayer?

    var body: some View {
        VideoPlayerView(player: player ?? AVPlayer(url: videoURL))
            .onAppear {
                player = AVPlayer(url: videoURL)
                editorManager.loadVideo(videoURL)
            }
            .onDisappear {
                player?.pause()
            }
    }
}

// MARK: - Video Player View
struct VideoPlayerView: UIViewControllerRepresentable {
    let player: AVPlayer

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = false
        return controller
    }

    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {}
}

// MARK: - Editor Tools View
struct EditorToolsView: View {
    @Binding var selectedTool: EditorTool
    let editorManager: ContentEditorManager
    let creationType: CreationType
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: 0) {
            // Tool Selector
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 20) {
                    ForEach(availableTools, id: \.self) { tool in
                        ToolButton(
                            tool: tool,
                            isSelected: selectedTool == tool
                        ) {
                            selectedTool = tool
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
            .padding(.vertical, 12)

            Divider()
                .background(Color.white.opacity(0.3))

            // Tool Content
            Group {
                switch selectedTool {
                case .filters:
                    FiltersToolView(editorManager: editorManager)
                case .adjust:
                    AdjustToolView(editorManager: editorManager)
                case .effects:
                    EffectsToolView(editorManager: editorManager)
                case .text:
                    TextToolView(editorManager: editorManager)
                case .stickers:
                    StickersToolView(editorManager: editorManager)
                case .music:
                    MusicToolView(editorManager: editorManager)
                case .layout:
                    LayoutToolView(editorManager: editorManager)
                case .crop:
                    CropToolView(editorManager: editorManager)
                }
            }
            .frame(height: 200)
        }
        .background(Color.black.opacity(0.9))
    }

    private var availableTools: [EditorTool] {
        switch creationType {
        case .photo, .outfit:
            return [.filters, .adjust, .effects, .text, .stickers, .layout, .crop]
        case .story:
            return [.filters, .adjust, .text, .stickers, .music]
        case .video, .reel:
            return [.filters, .adjust, .effects, .text, .stickers, .music]
        case .beforeAfter:
            return [.filters, .adjust, .text, .layout]
        default:
            return EditorTool.allCases
        }
    }
}

// MARK: - Tool Button
struct ToolButton: View {
    let tool: EditorTool
    let isSelected: Bool
    let action: () -> Void
    @Environment(\.theme) private var theme

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: tool.icon)
                    .font(.title3)
                    .foregroundColor(isSelected ? theme.colors.primary : .white.opacity(0.7))

                Text(tool.displayName)
                    .typography(.caption2, theme: .system)
                    .foregroundColor(isSelected ? theme.colors.primary : .white.opacity(0.7))
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 4)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? theme.colors.primary.opacity(0.2) : Color.clear)
            )
        }
    }
}

// MARK: - Filters Tool View
struct FiltersToolView: View {
    let editorManager: ContentEditorManager
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: 12) {
            Text("Filters")
                .typography(.caption1, theme: .system)
                .foregroundColor(.white.opacity(0.8))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(FilterType.allCases, id: \.self) { filter in
                        FilterPreview(
                            filter: filter,
                            isSelected: editorManager.selectedFilter == filter,
                            onSelect: {
                                editorManager.applyFilter(filter)
                            }
                        )
                    }
                }
                .padding(.horizontal, 20)
            }
        }
        .padding(.vertical, 12)
    }
}

// MARK: - Filter Preview
struct FilterPreview: View {
    let filter: FilterType
    let isSelected: Bool
    let onSelect: () -> Void
    @Environment(\.theme) private var theme

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 6) {
                // Filter thumbnail
                RoundedRectangle(cornerRadius: 8)
                    .fill(filter.color.opacity(0.6))
                    .frame(width: 60, height: 60)
                    .overlay(
                        Text(filter.rawValue.prefix(1).uppercased())
                            .typography(.heading4, theme: .modern)
                            .foregroundColor(.white)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(theme.colors.primary, lineWidth: isSelected ? 2 : 0)
                    )

                Text(filter.displayName)
                    .typography(.caption2, theme: .system)
                    .foregroundColor(isSelected ? theme.colors.primary : .white.opacity(0.8))
                    .lineLimit(1)
            }
        }
    }
}

// MARK: - Adjust Tool View
struct AdjustToolView: View {
    let editorManager: ContentEditorManager

    var body: some View {
        VStack(spacing: 16) {
            Text("Adjust")
                .typography(.caption1, theme: .system)
                .foregroundColor(.white.opacity(0.8))

            VStack(spacing: 12) {
                AdjustmentSlider(
                    title: "Brightness",
                    value: $editorManager.brightness,
                    range: -1...1
                )

                AdjustmentSlider(
                    title: "Contrast",
                    value: $editorManager.contrast,
                    range: 0...2
                )

                AdjustmentSlider(
                    title: "Saturation",
                    value: $editorManager.saturation,
                    range: 0...2
                )

                AdjustmentSlider(
                    title: "Warmth",
                    value: $editorManager.warmth,
                    range: -1...1
                )
            }
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - Adjustment Slider
struct AdjustmentSlider: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    @Environment(\.theme) private var theme

    var body: some View {
        HStack {
            Text(title)
                .typography(.caption1, theme: .system)
                .foregroundColor(.white.opacity(0.8))
                .frame(width: 70, alignment: .leading)

            Slider(value: $value, in: range)
                .accentColor(theme.colors.primary)

            Text("\(Int(value * 100))")
                .typography(.caption1, theme: .system)
                .foregroundColor(.white.opacity(0.6))
                .frame(width: 30)
        }
    }
}

// MARK: - Effects Tool View
struct EffectsToolView: View {
    let editorManager: ContentEditorManager

    var body: some View {
        VStack(spacing: 12) {
            Text("Effects")
                .typography(.caption1, theme: .system)
                .foregroundColor(.white.opacity(0.8))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(EffectType.allCases, id: \.self) { effect in
                        EffectButton(
                            effect: effect,
                            isApplied: editorManager.appliedEffects.contains(effect)
                        ) {
                            editorManager.toggleEffect(effect)
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
        .padding(.vertical, 12)
    }
}

// MARK: - Effect Button
struct EffectButton: View {
    let effect: EffectType
    let isApplied: Bool
    let onToggle: () -> Void
    @Environment(\.theme) private var theme

    var body: some View {
        Button(action: onToggle) {
            VStack(spacing: 6) {
                Image(systemName: effect.icon)
                    .font(.title2)
                    .foregroundColor(isApplied ? theme.colors.primary : .white.opacity(0.7))
                    .frame(width: 50, height: 50)
                    .background(
                        Circle()
                            .fill(isApplied ? theme.colors.primary.opacity(0.2) : Color.clear)
                            .overlay(
                                Circle()
                                    .stroke(theme.colors.primary, lineWidth: isApplied ? 2 : 0)
                            )
                    )

                Text(effect.displayName)
                    .typography(.caption2, theme: .system)
                    .foregroundColor(isApplied ? theme.colors.primary : .white.opacity(0.8))
            }
        }
    }
}

// MARK: - Text Tool View
struct TextToolView: View {
    let editorManager: ContentEditorManager
    @State private var showingTextEditor = false

    var body: some View {
        VStack(spacing: 16) {
            Text("Text")
                .typography(.caption1, theme: .system)
                .foregroundColor(.white.opacity(0.8))

            HStack(spacing: 20) {
                Button("Add Text") {
                    showingTextEditor = true
                }
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(.white.opacity(0.5), lineWidth: 1)
                )

                if !editorManager.textElements.isEmpty {
                    Button("Edit Text") {
                        // Edit existing text
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(.white.opacity(0.5), lineWidth: 1)
                    )
                }
            }

            // Text Style Options
            if !editorManager.textElements.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(TextStyle.allCases, id: \.self) { style in
                            TextStyleButton(style: style) {
                                editorManager.applyTextStyle(style)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
        .sheet(isPresented: $showingTextEditor) {
            TextEditorSheet(editorManager: editorManager)
        }
    }
}

// MARK: - Text Style Button
struct TextStyleButton: View {
    let style: TextStyle
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            Text("Aa")
                .font(style.font)
                .foregroundColor(.white)
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(.white.opacity(0.5), lineWidth: 1)
                )
        }
    }
}

// MARK: - Stickers Tool View
struct StickersToolView: View {
    let editorManager: ContentEditorManager

    var body: some View {
        VStack(spacing: 12) {
            Text("Stickers")
                .typography(.caption1, theme: .system)
                .foregroundColor(.white.opacity(0.8))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(StickerCategory.allCases, id: \.self) { category in
                        StickerCategoryButton(category: category) {
                            editorManager.showStickerCategory(category)
                        }
                    }
                }
                .padding(.horizontal, 20)
            }

            // Individual stickers would be shown here
            if let selectedCategory = editorManager.selectedStickerCategory {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(0..<10, id: \.self) { index in
                            StickerButton(sticker: "😀") { // Mock sticker
                                editorManager.addSticker("😀", category: selectedCategory)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
        .padding(.vertical, 12)
    }
}

// MARK: - Sticker Category Button
struct StickerCategoryButton: View {
    let category: StickerCategory
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 4) {
                Text(category.icon)
                    .font(.title2)

                Text(category.displayName)
                    .typography(.caption2, theme: .system)
                    .foregroundColor(.white.opacity(0.8))
            }
            .padding(8)
        }
    }
}

// MARK: - Sticker Button
struct StickerButton: View {
    let sticker: String
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            Text(sticker)
                .font(.title)
                .frame(width: 40, height: 40)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.white.opacity(0.1))
                )
        }
    }
}

// MARK: - Additional Tool Views (Simplified for brevity)
struct MusicToolView: View {
    let editorManager: ContentEditorManager

    var body: some View {
        VStack {
            Text("Music")
                .foregroundColor(.white)
            Text("Add soundtrack to your content")
                .foregroundColor(.white.opacity(0.6))
        }
    }
}

struct LayoutToolView: View {
    let editorManager: ContentEditorManager

    var body: some View {
        VStack {
            Text("Layout")
                .foregroundColor(.white)
            Text("Choose from different layout templates")
                .foregroundColor(.white.opacity(0.6))
        }
    }
}

struct CropToolView: View {
    let editorManager: ContentEditorManager

    var body: some View {
        VStack {
            Text("Crop")
                .foregroundColor(.white)
            Text("Adjust the framing of your content")
                .foregroundColor(.white.opacity(0.6))
        }
    }
}

// MARK: - Text Editor Sheet
struct TextEditorSheet: View {
    let editorManager: ContentEditorManager
    @State private var text = ""
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                TextField("Enter your text...", text: $text)
                    .font(.title2)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(.gray, lineWidth: 1)
                    )

                Spacer()
            }
            .padding()
            .navigationTitle("Add Text")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        editorManager.addTextElement(text)
                        presentationMode.wrappedValue.dismiss()
                    }
                    .disabled(text.isEmpty)
                }
            }
        }
    }
}

// MARK: - Overlay Element View
struct OverlayElementView: View {
    let element: OverlayElement
    let editorManager: ContentEditorManager

    var body: some View {
        Group {
            switch element.type {
            case .text(let textElement):
                Text(textElement.text)
                    .font(textElement.style.font)
                    .foregroundColor(textElement.color)

            case .sticker(let stickerElement):
                Text(stickerElement.emoji)
                    .font(.system(size: stickerElement.size))
            }
        }
        .position(element.position)
        .rotationEffect(.degrees(element.rotation))
        .scaleEffect(element.scale)
        .gesture(
            DragGesture()
                .onChanged { value in
                    editorManager.updateElementPosition(element.id, position: value.location)
                }
        )
    }
}