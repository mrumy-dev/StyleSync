import SwiftUI

struct ColorPickerView: View {
    let onColorSelected: (Color) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var hapticManager: HapticFeedbackManager
    
    @State private var selectedColor = Color.blue
    @State private var hue: Double = 0.5
    @State private var saturation: Double = 1.0
    @State private var brightness: Double = 1.0
    @State private var opacity: Double = 1.0
    @State private var selectedTab: ColorPickerTab = .wheel
    @State private var recentColors: [Color] = []
    @State private var favoriteColors: [Color] = []
    
    enum ColorPickerTab: String, CaseIterable {
        case wheel = "Wheel"
        case sliders = "Sliders"
        case swatches = "Swatches"
        case recent = "Recent"
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Header
                header
                
                // Tab Selection
                tabSelector
                
                // Color Preview
                colorPreview
                
                // Color Picker Content
                Spacer()
                
                Group {
                    switch selectedTab {
                    case .wheel:
                        colorWheelView
                    case .sliders:
                        colorSlidersView
                    case .swatches:
                        colorSwatchesView
                    case .recent:
                        recentColorsView
                    }
                }
                
                Spacer()
                
                // Action buttons
                actionButtons
            }
            .padding()
            .background(
                GradientMeshBackground(colors: themeManager.currentTheme.gradients.mesh)
                    .opacity(0.1)
            )
            .navigationBarHidden(true)
        }
        .onAppear {
            loadRecentColors()
            updateSelectedColor()
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
            
            Text("Pick a Color")
                .typography(.heading4, theme: .modern)
                .foregroundColor(themeManager.currentTheme.colors.primary)
            
            Spacer()
            
            Button("Done") {
                onColorSelected(selectedColor)
                saveRecentColor(selectedColor)
                dismiss()
            }
            .foregroundColor(themeManager.currentTheme.colors.accent)
            .fontWeight(.semibold)
        }
    }
    
    // MARK: - Tab Selector
    private var tabSelector: some View {
        HStack(spacing: 0) {
            ForEach(ColorPickerTab.allCases, id: \.self) { tab in
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedTab = tab
                    }
                    hapticManager.playHaptic(.light)
                }) {
                    Text(tab.rawValue)
                        .typography(.body2, theme: .modern)
                        .foregroundColor(selectedTab == tab ? .white : themeManager.currentTheme.colors.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(selectedTab == tab ? themeManager.currentTheme.colors.accent : Color.clear)
                        )
                }
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(themeManager.currentTheme.colors.surface.opacity(0.5))
                .glassmorphism(intensity: .light)
        )
    }
    
    // MARK: - Color Preview
    private var colorPreview: some View {
        VStack(spacing: 12) {
            // Main color preview
            RoundedRectangle(cornerRadius: 20)
                .fill(selectedColor)
                .frame(height: 80)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
                .shadow(color: selectedColor.opacity(0.3), radius: 10, x: 0, y: 5)
            
            // Color information
            VStack(spacing: 4) {
                Text(getColorName(selectedColor))
                    .typography(.body1, theme: .modern)
                    .foregroundColor(themeManager.currentTheme.colors.primary)
                    .fontWeight(.medium)
                
                Text(getColorHex(selectedColor))
                    .typography(.caption1, theme: .modern)
                    .foregroundColor(themeManager.currentTheme.colors.secondary)
                    .monospaced()
            }
        }
    }
    
    // MARK: - Color Wheel View
    private var colorWheelView: some View {
        VStack(spacing: 20) {
            // Color wheel
            ZStack {
                ColorWheelView(hue: $hue, saturation: $saturation)
                    .frame(width: 250, height: 250)
                    .onAppear {
                        updateSelectedColor()
                    }
                    .onChange(of: hue) { _ in updateSelectedColor() }
                    .onChange(of: saturation) { _ in updateSelectedColor() }
            }
            
            // Brightness slider
            VStack(spacing: 8) {
                Text("Brightness")
                    .typography(.caption1, theme: .modern)
                    .foregroundColor(themeManager.currentTheme.colors.secondary)
                
                CustomSlider(
                    value: $brightness,
                    range: 0...1,
                    trackColors: [Color.black, Color(hue: hue, saturation: saturation, brightness: 1.0)]
                )
                .onChange(of: brightness) { _ in updateSelectedColor() }
            }
        }
    }
    
    // MARK: - Color Sliders View
    private var colorSlidersView: some View {
        VStack(spacing: 24) {
            // Hue slider
            VStack(spacing: 8) {
                Text("Hue")
                    .typography(.caption1, theme: .modern)
                    .foregroundColor(themeManager.currentTheme.colors.secondary)
                
                CustomSlider(
                    value: $hue,
                    range: 0...1,
                    trackColors: [.red, .orange, .yellow, .green, .blue, .purple, .red]
                )
                .onChange(of: hue) { _ in updateSelectedColor() }
            }
            
            // Saturation slider
            VStack(spacing: 8) {
                Text("Saturation")
                    .typography(.caption1, theme: .modern)
                    .foregroundColor(themeManager.currentTheme.colors.secondary)
                
                CustomSlider(
                    value: $saturation,
                    range: 0...1,
                    trackColors: [
                        Color(hue: hue, saturation: 0, brightness: brightness),
                        Color(hue: hue, saturation: 1, brightness: brightness)
                    ]
                )
                .onChange(of: saturation) { _ in updateSelectedColor() }
            }
            
            // Brightness slider
            VStack(spacing: 8) {
                Text("Brightness")
                    .typography(.caption1, theme: .modern)
                    .foregroundColor(themeManager.currentTheme.colors.secondary)
                
                CustomSlider(
                    value: $brightness,
                    range: 0...1,
                    trackColors: [
                        Color.black,
                        Color(hue: hue, saturation: saturation, brightness: 1)
                    ]
                )
                .onChange(of: brightness) { _ in updateSelectedColor() }
            }
            
            // Opacity slider
            VStack(spacing: 8) {
                Text("Opacity")
                    .typography(.caption1, theme: .modern)
                    .foregroundColor(themeManager.currentTheme.colors.secondary)
                
                CustomSlider(
                    value: $opacity,
                    range: 0...1,
                    trackColors: [
                        Color(hue: hue, saturation: saturation, brightness: brightness, opacity: 0),
                        Color(hue: hue, saturation: saturation, brightness: brightness, opacity: 1)
                    ]
                )
                .onChange(of: opacity) { _ in updateSelectedColor() }
            }
        }
    }
    
    // MARK: - Color Swatches View
    private var colorSwatchesView: some View {
        ScrollView {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                ForEach(predefinedColors, id: \.self) { color in
                    ColorSwatchButton(
                        color: color,
                        isSelected: selectedColor.isEqual(to: color),
                        onTap: {
                            selectedColor = color
                            extractColorComponents(from: color)
                            hapticManager.playHaptic(.light)
                        }
                    )
                }
            }
        }
    }
    
    // MARK: - Recent Colors View
    private var recentColorsView: some View {
        VStack(spacing: 20) {
            // Recent colors
            if !recentColors.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Recent Colors")
                        .typography(.body1, theme: .modern)
                        .foregroundColor(themeManager.currentTheme.colors.primary)
                        .fontWeight(.medium)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                        ForEach(recentColors, id: \.self) { color in
                            ColorSwatchButton(
                                color: color,
                                isSelected: selectedColor.isEqual(to: color),
                                onTap: {
                                    selectedColor = color
                                    extractColorComponents(from: color)
                                    hapticManager.playHaptic(.light)
                                }
                            )
                        }
                    }
                }
            }
            
            // Favorite colors
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Favorite Colors")
                        .typography(.body1, theme: .modern)
                        .foregroundColor(themeManager.currentTheme.colors.primary)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Button(action: {
                        addToFavorites(selectedColor)
                    }) {
                        Image(systemName: "heart")
                            .foregroundColor(themeManager.currentTheme.colors.accent)
                    }
                    .tapWithHaptic(.light)
                }
                
                if favoriteColors.isEmpty {
                    Text("Add colors to favorites by tapping the heart")
                        .typography(.caption1, theme: .modern)
                        .foregroundColor(themeManager.currentTheme.colors.secondary)
                        .italic()
                } else {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                        ForEach(favoriteColors, id: \.self) { color in
                            ColorSwatchButton(
                                color: color,
                                isSelected: selectedColor.isEqual(to: color),
                                onTap: {
                                    selectedColor = color
                                    extractColorComponents(from: color)
                                    hapticManager.playHaptic(.light)
                                }
                            )
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Action Buttons
    private var actionButtons: some View {
        HStack(spacing: 16) {
            // Copy color code
            Button(action: {
                UIPasteboard.general.string = getColorHex(selectedColor)
                hapticManager.playHaptic(.light)
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "doc.on.clipboard")
                    Text("Copy")
                }
                .foregroundColor(themeManager.currentTheme.colors.secondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(themeManager.currentTheme.colors.surface.opacity(0.5))
                )
            }
            .tapWithHaptic(.light)
            
            Spacer()
            
            // Send color button
            Button(action: {
                onColorSelected(selectedColor)
                saveRecentColor(selectedColor)
                dismiss()
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "paperplane.fill")
                    Text("Send Color")
                }
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                colors: [selectedColor, selectedColor.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
            }
            .tapWithHaptic(.medium)
        }
    }
    
    // MARK: - Helper Methods
    private func updateSelectedColor() {
        selectedColor = Color(hue: hue, saturation: saturation, brightness: brightness, opacity: opacity)
    }
    
    private func extractColorComponents(from color: Color) {
        // This is a simplified extraction - in practice, you'd need proper color space conversion
        let uiColor = UIColor(color)
        var h: CGFloat = 0
        var s: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        
        uiColor.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        
        hue = Double(h)
        saturation = Double(s)
        brightness = Double(b)
        opacity = Double(a)
    }
    
    private func getColorName(_ color: Color) -> String {
        // Simplified color naming - in practice, this would use a comprehensive color database
        let uiColor = UIColor(color)
        var h: CGFloat = 0
        var s: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        
        uiColor.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        
        let hueValue = h * 360
        
        switch hueValue {
        case 0..<30, 330..<360: return "Red"
        case 30..<60: return "Orange"
        case 60..<90: return "Yellow"
        case 90..<150: return "Green"
        case 150..<210: return "Cyan"
        case 210..<270: return "Blue"
        case 270..<330: return "Purple"
        default: return "Color"
        }
    }
    
    private func getColorHex(_ color: Color) -> String {
        let uiColor = UIColor(color)
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        
        return String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
    }
    
    private func saveRecentColor(_ color: Color) {
        recentColors.removeAll { $0.isEqual(to: color) }
        recentColors.insert(color, at: 0)
        
        if recentColors.count > 12 {
            recentColors = Array(recentColors.prefix(12))
        }
        
        // Save to UserDefaults
        let colorData = recentColors.compactMap { try? NSKeyedArchiver.archivedData(withRootObject: UIColor($0), requiringSecureCoding: false) }
        UserDefaults.standard.set(colorData, forKey: "RecentColors")
    }
    
    private func loadRecentColors() {
        if let colorData = UserDefaults.standard.array(forKey: "RecentColors") as? [Data] {
            recentColors = colorData.compactMap { data in
                if let uiColor = try? NSKeyedUnarchiver.unarchivedObject(ofClass: UIColor.self, from: data) {
                    return Color(uiColor)
                }
                return nil
            }
        }
        
        // Load favorites
        if let favoriteData = UserDefaults.standard.array(forKey: "FavoriteColors") as? [Data] {
            favoriteColors = favoriteData.compactMap { data in
                if let uiColor = try? NSKeyedUnarchiver.unarchivedObject(ofClass: UIColor.self, from: data) {
                    return Color(uiColor)
                }
                return nil
            }
        }
    }
    
    private func addToFavorites(_ color: Color) {
        if !favoriteColors.contains(where: { $0.isEqual(to: color) }) {
            favoriteColors.append(color)
            
            // Save to UserDefaults
            let colorData = favoriteColors.compactMap { try? NSKeyedArchiver.archivedData(withRootObject: UIColor($0), requiringSecureCoding: false) }
            UserDefaults.standard.set(colorData, forKey: "FavoriteColors")
            
            hapticManager.playHaptic(.success)
        }
    }
    
    // MARK: - Predefined Colors
    private var predefinedColors: [Color] {
        [
            // Basic colors
            .red, .orange, .yellow, .green, .blue, .purple,
            .pink, .indigo, .teal, .mint, .cyan, .brown,
            
            // Neutral colors
            .black, .gray, .white,
            Color(red: 0.2, green: 0.2, blue: 0.2),
            Color(red: 0.5, green: 0.5, blue: 0.5),
            Color(red: 0.8, green: 0.8, blue: 0.8),
            
            // Fashion colors
            Color(red: 0.8, green: 0.4, blue: 0.4), // Dusty rose
            Color(red: 0.6, green: 0.8, blue: 0.6), // Sage green
            Color(red: 0.4, green: 0.6, blue: 0.8), // Powder blue
            Color(red: 0.8, green: 0.6, blue: 0.4), // Terracotta
            Color(red: 0.6, green: 0.4, blue: 0.8), // Lavender
            Color(red: 0.4, green: 0.8, blue: 0.8), // Aqua
            
            // Seasonal colors
            Color(red: 0.9, green: 0.7, blue: 0.5), // Warm beige
            Color(red: 0.7, green: 0.5, blue: 0.3), // Camel
            Color(red: 0.3, green: 0.5, blue: 0.7), // Steel blue
            Color(red: 0.5, green: 0.3, blue: 0.5), // Plum
            Color(red: 0.7, green: 0.7, blue: 0.5), // Olive
            Color(red: 0.5, green: 0.7, blue: 0.7), // Teal
        ]
    }
}

// MARK: - Supporting Views
struct ColorWheelView: UIViewRepresentable {
    @Binding var hue: Double
    @Binding var saturation: Double
    
    func makeUIView(context: Context) -> ColorWheelUIView {
        let view = ColorWheelUIView()
        view.delegate = context.coordinator
        return view
    }
    
    func updateUIView(_ uiView: ColorWheelUIView, context: Context) {
        // Update view if needed
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(hue: $hue, saturation: $saturation)
    }
    
    class Coordinator: ColorWheelDelegate {
        @Binding var hue: Double
        @Binding var saturation: Double
        
        init(hue: Binding<Double>, saturation: Binding<Double>) {
            self._hue = hue
            self._saturation = saturation
        }
        
        func colorChanged(hue: Double, saturation: Double) {
            self.hue = hue
            self.saturation = saturation
        }
    }
}

protocol ColorWheelDelegate: AnyObject {
    func colorChanged(hue: Double, saturation: Double)
}

class ColorWheelUIView: UIView {
    weak var delegate: ColorWheelDelegate?
    private var wheelLayer: CALayer!
    private var indicatorLayer: CALayer!
    
    override func layoutSubviews() {
        super.layoutSubviews()
        createColorWheel()
    }
    
    private func createColorWheel() {
        wheelLayer?.removeFromSuperlayer()
        indicatorLayer?.removeFromSuperlayer()
        
        let radius = min(bounds.width, bounds.height) / 2
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        
        wheelLayer = CALayer()
        wheelLayer.frame = bounds
        wheelLayer.contents = createWheelImage(radius: radius, center: center)?.cgImage
        layer.addSublayer(wheelLayer)
        
        indicatorLayer = CALayer()
        indicatorLayer.frame = CGRect(x: 0, y: 0, width: 20, height: 20)
        indicatorLayer.cornerRadius = 10
        indicatorLayer.borderWidth = 3
        indicatorLayer.borderColor = UIColor.white.cgColor
        indicatorLayer.shadowOffset = CGSize(width: 0, height: 2)
        indicatorLayer.shadowRadius = 4
        indicatorLayer.shadowOpacity = 0.3
        layer.addSublayer(indicatorLayer)
        
        updateIndicatorPosition()
    }
    
    private func createWheelImage(radius: CGFloat, center: CGPoint) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(bounds.size, false, 0)
        guard let context = UIGraphicsGetCurrentContext() else { return nil }
        
        for angle in stride(from: 0, to: 360, by: 1) {
            let hue = Double(angle) / 360.0
            let color = UIColor(hue: hue, saturation: 1.0, brightness: 1.0, alpha: 1.0)
            
            context.setFillColor(color.cgColor)
            
            let startAngle = CGFloat(angle - 1) * .pi / 180
            let endAngle = CGFloat(angle) * .pi / 180
            
            context.move(to: center)
            context.addArc(center: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: false)
            context.fillPath()
        }
        
        // Create saturation gradient
        let gradientColors = [UIColor.white.cgColor, UIColor.clear.cgColor]
        let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: gradientColors as CFArray, locations: nil)!
        
        context.drawRadialGradient(gradient, startCenter: center, startRadius: 0, endCenter: center, endRadius: radius, options: [])
        
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return image
    }
    
    private func updateIndicatorPosition() {
        // Update indicator position based on current hue and saturation
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        handleTouch(touches.first)
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        handleTouch(touches.first)
    }
    
    private func handleTouch(_ touch: UITouch?) {
        guard let touch = touch else { return }
        
        let point = touch.location(in: self)
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let radius = min(bounds.width, bounds.height) / 2
        
        let dx = point.x - center.x
        let dy = point.y - center.y
        let distance = sqrt(dx * dx + dy * dy)
        
        if distance <= radius {
            let angle = atan2(dy, dx)
            let hue = (angle + .pi) / (2 * .pi)
            let saturation = min(distance / radius, 1.0)
            
            delegate?.colorChanged(hue: Double(hue), saturation: Double(saturation))
        }
    }
}

struct CustomSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let trackColors: [Color]
    
    @EnvironmentObject private var themeManager: ThemeManager
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Track
                RoundedRectangle(cornerRadius: 4)
                    .fill(
                        LinearGradient(
                            colors: trackColors,
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: 8)
                
                // Thumb
                Circle()
                    .fill(Color.white)
                    .frame(width: 20, height: 20)
                    .shadow(radius: 2)
                    .offset(x: thumbOffset(geometry.size.width))
            }
        }
        .frame(height: 20)
        .gesture(
            DragGesture()
                .onChanged { gesture in
                    let newValue = range.lowerBound + (range.upperBound - range.lowerBound) * Double(gesture.location.x / geometry.size.width)
                    value = max(range.lowerBound, min(range.upperBound, newValue))
                }
        )
    }
    
    private func thumbOffset(_ width: CGFloat) -> CGFloat {
        let percentage = (value - range.lowerBound) / (range.upperBound - range.lowerBound)
        return CGFloat(percentage) * (width - 20)
    }
}

struct ColorSwatchButton: View {
    let color: Color
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            Circle()
                .fill(color)
                .frame(width: 44, height: 44)
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: isSelected ? 3 : 1)
                )
                .overlay(
                    Circle()
                        .stroke(Color.black.opacity(0.1), lineWidth: 1)
                )
                .scaleEffect(isSelected ? 1.1 : 1.0)
                .animation(.spring(response: 0.2, dampingFraction: 0.8), value: isSelected)
        }
    }
}

// MARK: - Color Extension
extension Color {
    func isEqual(to other: Color) -> Bool {
        let selfUIColor = UIColor(self)
        let otherUIColor = UIColor(other)
        
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        
        selfUIColor.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        otherUIColor.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        
        return abs(r1 - r2) < 0.01 && abs(g1 - g2) < 0.01 && abs(b1 - b2) < 0.01 && abs(a1 - a2) < 0.01
    }
}