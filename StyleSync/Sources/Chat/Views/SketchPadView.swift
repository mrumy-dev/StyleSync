import SwiftUI
import PencilKit

struct SketchPadView: View {
    let onSketchComplete: (SketchData) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var hapticManager: HapticFeedbackManager
    
    @State private var canvasView = PKCanvasView()
    @State private var toolPicker = PKToolPicker()
    @State private var selectedTool: DrawingTool = .pen
    @State private var selectedColor = Color.black
    @State private var brushSize: CGFloat = 5.0
    @State private var showingColorPicker = false
    @State private var showingToolSettings = false
    @State private var strokes: [DrawingStroke] = []
    @State private var canUndo = false
    @State private var canRedo = false
    
    enum DrawingTool: String, CaseIterable {
        case pen = "Pen"
        case pencil = "Pencil"
        case marker = "Marker"
        case eraser = "Eraser"
        
        var systemImage: String {
            switch self {
            case .pen: return "pencil"
            case .pencil: return "pencil.tip"
            case .marker: return "highlighter"
            case .eraser: return "eraser"
            }
        }
        
        var pkTool: PKTool {
            switch self {
            case .pen:
                return PKInkingTool(.pen, color: UIColor.black, width: 5)
            case .pencil:
                return PKInkingTool(.pencil, color: UIColor.black, width: 3)
            case .marker:
                return PKInkingTool(.marker, color: UIColor.black, width: 15)
            case .eraser:
                return PKEraserTool(.bitmap)
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                header
                
                // Tool bar
                toolBar
                
                // Canvas
                canvasArea
                
                // Action buttons
                actionButtons
            }
            .background(Color.white)
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showingColorPicker) {
            ColorPickerView { color in
                selectedColor = color
                updateCanvasTool()
            }
        }
        .sheet(isPresented: $showingToolSettings) {
            ToolSettingsView(
                brushSize: $brushSize,
                selectedColor: $selectedColor,
                onSettingsChanged: updateCanvasTool
            )
        }
        .onAppear {
            setupCanvas()
        }
    }
    
    // MARK: - Header
    private var header: some View {
        HStack {
            Button("Cancel") {
                dismiss()
            }
            .foregroundColor(themeManager.currentTheme.colors.secondary)
            
            Spacer()
            
            Text("Sketch Pad")
                .typography(.heading4, theme: .modern)
                .foregroundColor(themeManager.currentTheme.colors.primary)
            
            Spacer()
            
            Button("Done") {
                saveSketch()
            }
            .foregroundColor(themeManager.currentTheme.colors.accent)
            .fontWeight(.semibold)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            themeManager.currentTheme.colors.surface
                .opacity(0.95)
        )
    }
    
    // MARK: - Tool Bar
    private var toolBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                // Drawing tools
                ForEach(DrawingTool.allCases, id: \.self) { tool in
                    ToolButton(
                        tool: tool,
                        isSelected: selectedTool == tool,
                        onTap: {
                            selectedTool = tool
                            updateCanvasTool()
                            hapticManager.playHaptic(.light)
                        }
                    )
                }
                
                Divider()
                    .frame(height: 30)
                
                // Color selector
                Button(action: {
                    showingColorPicker = true
                }) {
                    Circle()
                        .fill(selectedColor)
                        .frame(width: 30, height: 30)
                        .overlay(
                            Circle()
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                }
                .tapWithHaptic(.light)
                
                // Brush size
                Button(action: {
                    showingToolSettings = true
                }) {
                    VStack(spacing: 2) {
                        Circle()
                            .fill(Color.gray)
                            .frame(width: brushSize, height: brushSize)
                        
                        Text("Size")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                }
                .tapWithHaptic(.light)
                
                Divider()
                    .frame(height: 30)
                
                // Undo/Redo
                Button(action: undo) {
                    Image(systemName: "arrow.uturn.backward")
                        .foregroundColor(canUndo ? themeManager.currentTheme.colors.accent : .gray)
                }
                .disabled(!canUndo)
                .tapWithHaptic(.light)
                
                Button(action: redo) {
                    Image(systemName: "arrow.uturn.forward")
                        .foregroundColor(canRedo ? themeManager.currentTheme.colors.accent : .gray)
                }
                .disabled(!canRedo)
                .tapWithHaptic(.light)
                
                // Clear all
                Button(action: clearCanvas) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
                .tapWithHaptic(.medium)
            }
            .padding(.horizontal, 20)
        }
        .padding(.vertical, 12)
        .background(
            themeManager.currentTheme.colors.surface
                .opacity(0.5)
        )
    }
    
    // MARK: - Canvas Area
    private var canvasArea: some View {
        CanvasRepresentable(
            canvasView: canvasView,
            onDrawingChanged: { drawing in
                updateStrokesFromDrawing(drawing)
                updateUndoRedoState()
            }
        )
        .background(Color.white)
        .overlay(
            // Grid overlay (optional)
            GridPattern()
                .stroke(Color.gray.opacity(0.1), lineWidth: 0.5)
                .allowsHitTesting(false)
        )
    }
    
    // MARK: - Action Buttons
    private var actionButtons: some View {
        HStack(spacing: 16) {
            // Templates button
            Button(action: {
                // Show drawing templates
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "rectangle.3.group")
                    Text("Templates")
                        .typography(.caption1, theme: .modern)
                }
                .foregroundColor(themeManager.currentTheme.colors.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(themeManager.currentTheme.colors.surface.opacity(0.5))
                )
            }
            .tapWithHaptic(.light)
            
            Spacer()
            
            // Save and send
            Button(action: saveSketch) {
                HStack(spacing: 8) {
                    Image(systemName: "paperplane.fill")
                    Text("Send Sketch")
                        .typography(.body2, theme: .modern)
                        .fontWeight(.medium)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                colors: [
                                    themeManager.currentTheme.colors.accent,
                                    themeManager.currentTheme.colors.accent.opacity(0.8)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
            }
            .tapWithHaptic(.medium)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            themeManager.currentTheme.colors.surface
                .opacity(0.95)
        )
    }
    
    // MARK: - Canvas Setup
    private func setupCanvas() {
        canvasView.backgroundColor = UIColor.clear
        canvasView.isOpaque = false
        canvasView.tool = selectedTool.pkTool
        
        // Enable Apple Pencil features
        if #available(iOS 14.0, *) {
            canvasView.drawingPolicy = .anyInput
        }
        
        updateCanvasTool()
    }
    
    private func updateCanvasTool() {
        var tool = selectedTool.pkTool
        
        if let inkingTool = tool as? PKInkingTool {
            tool = PKInkingTool(inkingTool.inkType, color: UIColor(selectedColor), width: brushSize)
        }
        
        canvasView.tool = tool
        updateUndoRedoState()
    }
    
    // MARK: - Canvas Actions
    private func undo() {
        canvasView.undoManager?.undo()
        updateUndoRedoState()
        hapticManager.playHaptic(.light)
    }
    
    private func redo() {
        canvasView.undoManager?.redo()
        updateUndoRedoState()
        hapticManager.playHaptic(.light)
    }
    
    private func clearCanvas() {
        canvasView.drawing = PKDrawing()
        strokes.removeAll()
        updateUndoRedoState()
        hapticManager.playHaptic(.medium)
    }
    
    private func updateUndoRedoState() {
        canUndo = canvasView.undoManager?.canUndo ?? false
        canRedo = canvasView.undoManager?.canRedo ?? false
    }
    
    private func updateStrokesFromDrawing(_ drawing: PKDrawing) {
        // Convert PKDrawing to our DrawingStroke format
        strokes = drawing.strokes.map { pkStroke in
            let points = pkStroke.path.map { point in
                CGPoint(x: point.location.x, y: point.location.y)
            }
            
            return DrawingStroke(
                points: points,
                color: CodableColor(color: Color(pkStroke.ink.color)),
                width: pkStroke.ink.defaultWidth,
                timestamp: Date()
            )
        }
    }
    
    private func saveSketch() {
        // Convert drawing to image data
        let image = canvasView.drawing.image(from: canvasView.bounds, scale: UIScreen.main.scale)
        let imageData = image.jpegData(compressionQuality: 0.8) ?? Data()
        
        let sketchData = SketchData(
            data: imageData,
            strokes: strokes
        )
        
        onSketchComplete(sketchData)
        dismiss()
    }
}

// MARK: - Supporting Views
struct ToolButton: View {
    let tool: SketchPadView.DrawingTool
    let isSelected: Bool
    let onTap: () -> Void
    
    @EnvironmentObject private var themeManager: ThemeManager
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                Image(systemName: tool.systemImage)
                    .font(.system(size: 18))
                    .foregroundColor(isSelected ? .white : themeManager.currentTheme.colors.secondary)
                
                Text(tool.rawValue)
                    .font(.caption2)
                    .foregroundColor(isSelected ? .white : themeManager.currentTheme.colors.secondary)
            }
            .frame(width: 60, height: 50)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? themeManager.currentTheme.colors.accent : Color.clear)
            )
        }
    }
}

struct CanvasRepresentable: UIViewRepresentable {
    let canvasView: PKCanvasView
    let onDrawingChanged: (PKDrawing) -> Void
    
    func makeUIView(context: Context) -> PKCanvasView {
        canvasView.delegate = context.coordinator
        return canvasView
    }
    
    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        // No updates needed
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onDrawingChanged: onDrawingChanged)
    }
    
    class Coordinator: NSObject, PKCanvasViewDelegate {
        let onDrawingChanged: (PKDrawing) -> Void
        
        init(onDrawingChanged: @escaping (PKDrawing) -> Void) {
            self.onDrawingChanged = onDrawingChanged
        }
        
        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            onDrawingChanged(canvasView.drawing)
        }
    }
}

struct GridPattern: Shape {
    let spacing: CGFloat = 20
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        // Vertical lines
        for x in stride(from: 0, through: rect.width, by: spacing) {
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: rect.height))
        }
        
        // Horizontal lines
        for y in stride(from: 0, through: rect.height, by: spacing) {
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: rect.width, y: y))
        }
        
        return path
    }
}

struct ToolSettingsView: View {
    @Binding var brushSize: CGFloat
    @Binding var selectedColor: Color
    let onSettingsChanged: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var themeManager: ThemeManager
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                // Brush size
                VStack(spacing: 16) {
                    Text("Brush Size")
                        .typography(.heading4, theme: .modern)
                        .foregroundColor(themeManager.currentTheme.colors.primary)
                    
                    VStack(spacing: 12) {
                        // Size preview
                        Circle()
                            .fill(selectedColor)
                            .frame(width: brushSize, height: brushSize)
                            .animation(.easeInOut(duration: 0.2), value: brushSize)
                        
                        // Size slider
                        HStack {
                            Text("1")
                                .typography(.caption1, theme: .modern)
                                .foregroundColor(themeManager.currentTheme.colors.secondary)
                            
                            Slider(value: $brushSize, in: 1...30, step: 1)
                                .accentColor(themeManager.currentTheme.colors.accent)
                                .onChange(of: brushSize) { _ in
                                    onSettingsChanged()
                                }
                            
                            Text("30")
                                .typography(.caption1, theme: .modern)
                                .foregroundColor(themeManager.currentTheme.colors.secondary)
                        }
                        
                        Text("\(Int(brushSize)) pt")
                            .typography(.body2, theme: .modern)
                            .foregroundColor(themeManager.currentTheme.colors.secondary)
                            .monospacedDigit()
                    }
                }
                
                Divider()
                
                // Quick size presets
                VStack(spacing: 16) {
                    Text("Quick Sizes")
                        .typography(.body1, theme: .modern)
                        .foregroundColor(themeManager.currentTheme.colors.primary)
                        .fontWeight(.medium)
                    
                    HStack(spacing: 20) {
                        ForEach([3, 8, 15, 25], id: \.self) { size in
                            Button(action: {
                                brushSize = CGFloat(size)
                                onSettingsChanged()
                            }) {
                                VStack(spacing: 4) {
                                    Circle()
                                        .fill(selectedColor)
                                        .frame(width: CGFloat(size), height: CGFloat(size))
                                    
                                    Text("\(size)")
                                        .typography(.caption2, theme: .modern)
                                        .foregroundColor(themeManager.currentTheme.colors.secondary)
                                }
                            }
                        }
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Tool Settings")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden()
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(themeManager.currentTheme.colors.accent)
                }
            }
        }
    }
}