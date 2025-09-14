import SwiftUI
import UIKit

@MainActor
class AccessibilityManager: ObservableObject {
    static let shared = AccessibilityManager()

    @Published var isVoiceOverEnabled = UIAccessibility.isVoiceOverRunning
    @Published var isVoiceControlEnabled = UIAccessibility.isVoiceControlRunning
    @Published var isDynamicTypeEnabled = true
    @Published var preferredContentSizeCategory = UIApplication.shared.preferredContentSizeCategory
    @Published var isReduceMotionEnabled = UIAccessibility.isReduceMotionEnabled
    @Published var colorBlindMode: ColorBlindMode = .none
    @Published var highContrastEnabled = UIAccessibility.isDarkerSystemColorsEnabled

    private init() {
        setupAccessibilityObservers()
        loadUserPreferences()
    }

    private func setupAccessibilityObservers() {
        NotificationCenter.default.addObserver(
            forName: UIAccessibility.voiceOverStatusDidChangeNotification,
            object: nil,
            queue: .main
        ) { _ in
            self.isVoiceOverEnabled = UIAccessibility.isVoiceOverRunning
        }

        NotificationCenter.default.addObserver(
            forName: UIAccessibility.voiceControlStatusDidChangeNotification,
            object: nil,
            queue: .main
        ) { _ in
            self.isVoiceControlEnabled = UIAccessibility.isVoiceControlRunning
        }

        NotificationCenter.default.addObserver(
            forName: UIContentSizeCategory.didChangeNotification,
            object: nil,
            queue: .main
        ) { _ in
            self.preferredContentSizeCategory = UIApplication.shared.preferredContentSizeCategory
        }

        NotificationCenter.default.addObserver(
            forName: UIAccessibility.reduceMotionStatusDidChangeNotification,
            object: nil,
            queue: .main
        ) { _ in
            self.isReduceMotionEnabled = UIAccessibility.isReduceMotionEnabled
        }

        NotificationCenter.default.addObserver(
            forName: UIAccessibility.darkerSystemColorsStatusDidChangeNotification,
            object: nil,
            queue: .main
        ) { _ in
            self.highContrastEnabled = UIAccessibility.isDarkerSystemColorsEnabled
        }
    }

    private func loadUserPreferences() {
        if let colorBlindModeString = UserDefaults.standard.string(forKey: "color_blind_mode"),
           let mode = ColorBlindMode(rawValue: colorBlindModeString) {
            colorBlindMode = mode
        }

        isDynamicTypeEnabled = UserDefaults.standard.bool(forKey: "dynamic_type_enabled")
    }

    func setColorBlindMode(_ mode: ColorBlindMode) {
        colorBlindMode = mode
        UserDefaults.standard.set(mode.rawValue, forKey: "color_blind_mode")
    }

    func setDynamicTypeEnabled(_ enabled: Bool) {
        isDynamicTypeEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: "dynamic_type_enabled")
    }

    // MARK: - Voice Control Helpers

    func generateVoiceControlLabels(for items: [String]) -> [String: String] {
        var labels: [String: String] = [:]
        let voiceControlCommands = [
            "generate_outfit": "Generate Outfit",
            "rate_outfit": "Rate Outfit",
            "save_outfit": "Save Outfit",
            "next_outfit": "Next Outfit",
            "previous_outfit": "Previous Outfit",
            "open_wardrobe": "Open Wardrobe",
            "add_item": "Add Item",
            "settings": "Settings"
        ]

        for item in items {
            if let command = voiceControlCommands[item] {
                labels[item] = command
            }
        }

        return labels
    }

    // MARK: - Dynamic Text Sizing

    func scaledValue(_ baseValue: CGFloat) -> CGFloat {
        guard isDynamicTypeEnabled else { return baseValue }

        let scalingFactor = dynamicTypeScalingFactor()
        return baseValue * scalingFactor
    }

    func scaledFont(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        guard isDynamicTypeEnabled else {
            return .system(size: size, weight: weight)
        }

        return .system(size: scaledValue(size), weight: weight)
    }

    private func dynamicTypeScalingFactor() -> CGFloat {
        switch preferredContentSizeCategory {
        case .extraSmall: return 0.8
        case .small: return 0.9
        case .medium: return 1.0
        case .large: return 1.1
        case .extraLarge: return 1.2
        case .extraExtraLarge: return 1.3
        case .extraExtraExtraLarge: return 1.4
        case .accessibilityMedium: return 1.6
        case .accessibilityLarge: return 1.8
        case .accessibilityExtraLarge: return 2.0
        case .accessibilityExtraExtraLarge: return 2.2
        case .accessibilityExtraExtraExtraLarge: return 2.4
        default: return 1.0
        }
    }

    // MARK: - Color Blind Adaptations

    func adaptColor(_ color: Color) -> Color {
        switch colorBlindMode {
        case .none:
            return color
        case .deuteranopia:
            return adaptColorForDeuteranopia(color)
        case .protanopia:
            return adaptColorForProtanopia(color)
        case .tritanopia:
            return adaptColorForTritanopia(color)
        }
    }

    private func adaptColorForDeuteranopia(_ color: Color) -> Color {
        // Deuteranopia: Difficulty distinguishing red and green
        let uiColor = UIColor(color)
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        // Enhance blue component and adjust red/green
        let adaptedRed = red * 0.8 + blue * 0.2
        let adaptedGreen = green * 0.8 + blue * 0.2
        let adaptedBlue = blue * 1.2

        return Color(red: adaptedRed, green: adaptedGreen, blue: min(adaptedBlue, 1.0))
    }

    private func adaptColorForProtanopia(_ color: Color) -> Color {
        // Protanopia: Difficulty with red perception
        let uiColor = UIColor(color)
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        let adaptedRed = red * 0.5 + green * 0.5
        let adaptedGreen = green * 1.2
        let adaptedBlue = blue * 1.1

        return Color(red: min(adaptedRed, 1.0), green: min(adaptedGreen, 1.0), blue: min(adaptedBlue, 1.0))
    }

    private func adaptColorForTritanopia(_ color: Color) -> Color {
        // Tritanopia: Difficulty with blue perception
        let uiColor = UIColor(color)
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        let adaptedRed = red * 1.1
        let adaptedGreen = green * 1.1
        let adaptedBlue = blue * 0.6 + red * 0.2 + green * 0.2

        return Color(red: min(adaptedRed, 1.0), green: min(adaptedGreen, 1.0), blue: min(adaptedBlue, 1.0))
    }

    // MARK: - Motion Adaptations

    func shouldUseReducedMotion() -> Bool {
        return isReduceMotionEnabled
    }

    func adaptedAnimation<V: Equatable>(_ animation: Animation, value: V) -> Animation? {
        guard !shouldUseReducedMotion() else { return nil }
        return animation
    }

    func adaptedTransition(_ transition: AnyTransition) -> AnyTransition {
        guard !shouldUseReducedMotion() else { return .opacity }
        return transition
    }
}

// MARK: - Enums

enum ColorBlindMode: String, CaseIterable {
    case none = "none"
    case deuteranopia = "deuteranopia"
    case protanopia = "protanopia"
    case tritanopia = "tritanopia"

    var displayName: String {
        switch self {
        case .none: return LocalizationManager.shared.localizedString("color_blind_none")
        case .deuteranopia: return LocalizationManager.shared.localizedString("color_blind_deuteranopia")
        case .protanopia: return LocalizationManager.shared.localizedString("color_blind_protanopia")
        case .tritanopia: return LocalizationManager.shared.localizedString("color_blind_tritanopia")
        }
    }

    var description: String {
        switch self {
        case .none: return "Normal color vision"
        case .deuteranopia: return "Difficulty distinguishing red and green"
        case .protanopia: return "Reduced sensitivity to red light"
        case .tritanopia: return "Reduced sensitivity to blue light"
        }
    }
}

// MARK: - Accessibility View Modifiers

struct AccessibilityEnhancedModifier: ViewModifier {
    let label: String
    let hint: String?
    let value: String?
    let traits: AccessibilityTraits
    let isHeader: Bool

    @StateObject private var accessibilityManager = AccessibilityManager.shared

    init(
        label: String,
        hint: String? = nil,
        value: String? = nil,
        traits: AccessibilityTraits = [],
        isHeader: Bool = false
    ) {
        self.label = label
        self.hint = hint
        self.value = value
        self.traits = traits
        self.isHeader = isHeader
    }

    func body(content: Content) -> some View {
        content
            .accessibilityLabel(label)
            .accessibilityHint(hint ?? "")
            .accessibilityValue(value ?? "")
            .accessibilityAddTraits(traits)
            .accessibilityAddTraits(isHeader ? .isHeader : [])
            .if(accessibilityManager.isVoiceOverEnabled) { view in
                view.accessibilityElement(children: .contain)
            }
    }
}

struct DynamicFontModifier: ViewModifier {
    let baseSize: CGFloat
    let weight: Font.Weight
    let design: Font.Design

    @StateObject private var accessibilityManager = AccessibilityManager.shared

    init(baseSize: CGFloat, weight: Font.Weight = .regular, design: Font.Design = .default) {
        self.baseSize = baseSize
        self.weight = weight
        self.design = design
    }

    func body(content: Content) -> some View {
        content
            .font(.system(
                size: accessibilityManager.scaledValue(baseSize),
                weight: weight,
                design: design
            ))
    }
}

struct ColorBlindAdaptedModifier: ViewModifier {
    let originalColor: Color

    @StateObject private var accessibilityManager = AccessibilityManager.shared

    func body(content: Content) -> some View {
        content
            .foregroundColor(accessibilityManager.adaptColor(originalColor))
    }
}

struct ReducedMotionModifier: ViewModifier {
    let animation: Animation

    @StateObject private var accessibilityManager = AccessibilityManager.shared

    func body(content: Content) -> some View {
        content
            .animation(
                accessibilityManager.shouldUseReducedMotion() ? nil : animation,
                value: UUID()
            )
    }
}

struct VoiceControlModifier: ViewModifier {
    let commands: [String]

    func body(content: Content) -> some View {
        content
            .accessibilityInputLabels(commands)
    }
}

// MARK: - View Extensions

extension View {
    func accessibilityEnhanced(
        label: String,
        hint: String? = nil,
        value: String? = nil,
        traits: AccessibilityTraits = [],
        isHeader: Bool = false
    ) -> some View {
        modifier(AccessibilityEnhancedModifier(
            label: label,
            hint: hint,
            value: value,
            traits: traits,
            isHeader: isHeader
        ))
    }

    func dynamicFont(
        size: CGFloat,
        weight: Font.Weight = .regular,
        design: Font.Design = .default
    ) -> some View {
        modifier(DynamicFontModifier(baseSize: size, weight: weight, design: design))
    }

    func colorBlindAdapted(_ color: Color) -> some View {
        modifier(ColorBlindAdaptedModifier(originalColor: color))
    }

    func reducedMotionAdapted(_ animation: Animation) -> some View {
        modifier(ReducedMotionModifier(animation: animation))
    }

    func voiceControlCommands(_ commands: [String]) -> some View {
        modifier(VoiceControlModifier(commands: commands))
    }

    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

// MARK: - Accessibility Settings View

struct AccessibilitySettingsView: View {
    @StateObject private var accessibilityManager = AccessibilityManager.shared
    @State private var showColorBlindPreview = false

    var body: some View {
        NavigationView {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("StyleSync Accessibility")
                            .dynamicFont(size: 20, weight: .bold)
                            .accessibilityEnhanced(label: "StyleSync Accessibility", isHeader: true)

                        Text("Making fashion accessible for everyone")
                            .dynamicFont(size: 14)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 8)
                }

                Section("Vision") {
                    HStack {
                        Image(systemName: "textformat.size")
                            .foregroundColor(.blue)
                            .frame(width: 24)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Dynamic Type")
                                .dynamicFont(size: 16, weight: .medium)

                            Text("Adjust text size automatically")
                                .dynamicFont(size: 12)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Toggle("", isOn: $accessibilityManager.isDynamicTypeEnabled)
                            .accessibilityLabel("Enable Dynamic Type")
                    }

                    HStack {
                        Image(systemName: "eye")
                            .foregroundColor(.green)
                            .frame(width: 24)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Color Blind Support")
                                .dynamicFont(size: 16, weight: .medium)

                            Text(accessibilityManager.colorBlindMode.displayName)
                                .dynamicFont(size: 12)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Button("Configure") {
                            showColorBlindPreview = true
                        }
                        .foregroundColor(.blue)
                    }

                    if accessibilityManager.highContrastEnabled {
                        HStack {
                            Image(systemName: "circle.lefthalf.filled")
                                .foregroundColor(.orange)
                                .frame(width: 24)

                            Text("High Contrast Mode")
                                .dynamicFont(size: 16, weight: .medium)

                            Spacer()

                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        }
                    }
                }

                Section("Voice & Control") {
                    if accessibilityManager.isVoiceOverEnabled {
                        HStack {
                            Image(systemName: "speaker.wave.3.fill")
                                .foregroundColor(.purple)
                                .frame(width: 24)

                            Text("VoiceOver Active")
                                .dynamicFont(size: 16, weight: .medium)

                            Spacer()

                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        }
                    }

                    if accessibilityManager.isVoiceControlEnabled {
                        HStack {
                            Image(systemName: "mic.fill")
                                .foregroundColor(.red)
                                .frame(width: 24)

                            Text("Voice Control Active")
                                .dynamicFont(size: 16, weight: .medium)

                            Spacer()

                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        }
                    }
                }

                Section("Motion") {
                    HStack {
                        Image(systemName: accessibilityManager.isReduceMotionEnabled ? "tortoise.fill" : "hare.fill")
                            .foregroundColor(.orange)
                            .frame(width: 24)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Motion Preference")
                                .dynamicFont(size: 16, weight: .medium)

                            Text(accessibilityManager.isReduceMotionEnabled ? "Reduced motion enabled" : "Full animations enabled")
                                .dynamicFont(size: 12)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        if accessibilityManager.isReduceMotionEnabled {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        }
                    }
                }
            }
            .navigationTitle("Accessibility")
            .navigationBarTitleDisplayMode(.large)
        }
        .sheet(isPresented: $showColorBlindPreview) {
            ColorBlindPreviewView()
        }
    }
}

struct ColorBlindPreviewView: View {
    @StateObject private var accessibilityManager = AccessibilityManager.shared
    @State private var selectedMode: ColorBlindMode = .none

    let previewColors: [(String, Color)] = [
        ("Red", .red),
        ("Green", .green),
        ("Blue", .blue),
        ("Orange", .orange),
        ("Purple", .purple),
        ("Yellow", .yellow)
    ]

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Choose the mode that makes colors easier to distinguish")
                    .dynamicFont(size: 16)
                    .multilineTextAlignment(.center)
                    .padding()

                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 12) {
                    ForEach(previewColors, id: \.0) { name, color in
                        VStack(spacing: 8) {
                            let adaptedColor = selectedMode == .none ? color : accessibilityManager.adaptColor(color)

                            RoundedRectangle(cornerRadius: 12)
                                .fill(adaptedColor)
                                .frame(height: 60)

                            Text(name)
                                .dynamicFont(size: 12, weight: .medium)
                        }
                    }
                }
                .padding()

                Picker("Color Blind Mode", selection: $selectedMode) {
                    ForEach(ColorBlindMode.allCases, id: \.self) { mode in
                        VStack(alignment: .leading) {
                            Text(mode.displayName)
                                .dynamicFont(size: 14, weight: .medium)
                            Text(mode.description)
                                .dynamicFont(size: 10)
                                .foregroundColor(.secondary)
                        }
                        .tag(mode)
                    }
                }
                .pickerStyle(.wheel)

                Button("Apply Settings") {
                    accessibilityManager.setColorBlindMode(selectedMode)
                }
                .buttonStyle(.borderedProminent)
                .padding()

                Spacer()
            }
            .navigationTitle("Color Blind Support")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                selectedMode = accessibilityManager.colorBlindMode
            }
        }
    }
}