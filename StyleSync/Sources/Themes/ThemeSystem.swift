import SwiftUI
import Combine

// MARK: - Theme Protocol
public protocol Theme {
    var id: String { get }
    var name: String { get }
    var colors: ColorPalette { get }
    var gradients: GradientPalette { get }
    var effects: EffectPalette { get }
    var mood: ThemeMood { get }
    var timeOfDay: TimeOfDay? { get }
    var season: Season? { get }
}

// MARK: - Theme Mood
public enum ThemeMood: String, CaseIterable {
    case energetic = "energetic"
    case calm = "calm"
    case focused = "focused"
    case creative = "creative"
    case minimal = "minimal"
    case luxurious = "luxurious"
    case playful = "playful"
    case professional = "professional"
    case warm = "warm"
    case cool = "cool"
}

// MARK: - Time of Day
public enum TimeOfDay: String, CaseIterable {
    case sunrise = "sunrise"
    case morning = "morning"
    case midday = "midday"
    case afternoon = "afternoon"
    case evening = "evening"
    case night = "night"
    case midnight = "midnight"
}

// MARK: - Season
public enum Season: String, CaseIterable {
    case spring = "spring"
    case summer = "summer"
    case autumn = "autumn"
    case winter = "winter"
}

// MARK: - Color Palette
public struct ColorPalette {
    // Primary Colors
    public let primary: Color
    public let primaryLight: Color
    public let primaryDark: Color
    public let primaryVariant: Color
    
    // Secondary Colors
    public let secondary: Color
    public let secondaryLight: Color
    public let secondaryDark: Color
    public let secondaryVariant: Color
    
    // Surface Colors
    public let background: Color
    public let surface: Color
    public let surfaceVariant: Color
    public let surfaceElevated: Color
    
    // Text Colors
    public let onPrimary: Color
    public let onSecondary: Color
    public let onBackground: Color
    public let onSurface: Color
    public let onSurfaceVariant: Color
    
    // Status Colors
    public let success: Color
    public let warning: Color
    public let error: Color
    public let info: Color
    
    // Accent Colors
    public let accent1: Color
    public let accent2: Color
    public let accent3: Color
    
    // Neutral Colors
    public let neutral50: Color
    public let neutral100: Color
    public let neutral200: Color
    public let neutral300: Color
    public let neutral400: Color
    public let neutral500: Color
    public let neutral600: Color
    public let neutral700: Color
    public let neutral800: Color
    public let neutral900: Color
    
    public init(
        primary: Color, primaryLight: Color, primaryDark: Color, primaryVariant: Color,
        secondary: Color, secondaryLight: Color, secondaryDark: Color, secondaryVariant: Color,
        background: Color, surface: Color, surfaceVariant: Color, surfaceElevated: Color,
        onPrimary: Color, onSecondary: Color, onBackground: Color, onSurface: Color, onSurfaceVariant: Color,
        success: Color, warning: Color, error: Color, info: Color,
        accent1: Color, accent2: Color, accent3: Color,
        neutral50: Color, neutral100: Color, neutral200: Color, neutral300: Color, neutral400: Color,
        neutral500: Color, neutral600: Color, neutral700: Color, neutral800: Color, neutral900: Color
    ) {
        self.primary = primary
        self.primaryLight = primaryLight
        self.primaryDark = primaryDark
        self.primaryVariant = primaryVariant
        self.secondary = secondary
        self.secondaryLight = secondaryLight
        self.secondaryDark = secondaryDark
        self.secondaryVariant = secondaryVariant
        self.background = background
        self.surface = surface
        self.surfaceVariant = surfaceVariant
        self.surfaceElevated = surfaceElevated
        self.onPrimary = onPrimary
        self.onSecondary = onSecondary
        self.onBackground = onBackground
        self.onSurface = onSurface
        self.onSurfaceVariant = onSurfaceVariant
        self.success = success
        self.warning = warning
        self.error = error
        self.info = info
        self.accent1 = accent1
        self.accent2 = accent2
        self.accent3 = accent3
        self.neutral50 = neutral50
        self.neutral100 = neutral100
        self.neutral200 = neutral200
        self.neutral300 = neutral300
        self.neutral400 = neutral400
        self.neutral500 = neutral500
        self.neutral600 = neutral600
        self.neutral700 = neutral700
        self.neutral800 = neutral800
        self.neutral900 = neutral900
    }
}

// MARK: - Gradient Palette
public struct GradientPalette {
    public let primary: LinearGradient
    public let secondary: LinearGradient
    public let accent: LinearGradient
    public let surface: LinearGradient
    public let hero: LinearGradient
    public let mesh: [Color]
    
    public init(
        primary: LinearGradient,
        secondary: LinearGradient,
        accent: LinearGradient,
        surface: LinearGradient,
        hero: LinearGradient,
        mesh: [Color]
    ) {
        self.primary = primary
        self.secondary = secondary
        self.accent = accent
        self.surface = surface
        self.hero = hero
        self.mesh = mesh
    }
}

// MARK: - Effect Palette
public struct EffectPalette {
    public let glassmorphism: GlassmorphismEffect
    public let neumorphism: NeumorphismEffect
    public let blur: BlurEffect
    public let vibrancy: VibrancyEffect
    
    public init(
        glassmorphism: GlassmorphismEffect,
        neumorphism: NeumorphismEffect,
        blur: BlurEffect,
        vibrancy: VibrancyEffect
    ) {
        self.glassmorphism = glassmorphism
        self.neumorphism = neumorphism
        self.blur = blur
        self.vibrancy = vibrancy
    }
}

// MARK: - Effect Types
public struct GlassmorphismEffect {
    public let blur: CGFloat
    public let opacity: Double
    public let borderWidth: CGFloat
    public let borderOpacity: Double
    
    public init(blur: CGFloat, opacity: Double, borderWidth: CGFloat, borderOpacity: Double) {
        self.blur = blur
        self.opacity = opacity
        self.borderWidth = borderWidth
        self.borderOpacity = borderOpacity
    }
}

public struct NeumorphismEffect {
    public let lightShadow: ShadowToken
    public let darkShadow: ShadowToken
    public let inset: Bool
    
    public init(lightShadow: ShadowToken, darkShadow: ShadowToken, inset: Bool) {
        self.lightShadow = lightShadow
        self.darkShadow = darkShadow
        self.inset = inset
    }
}

public struct BlurEffect {
    public let intensity: CGFloat
    public let style: UIBlurEffect.Style
    
    public init(intensity: CGFloat, style: UIBlurEffect.Style) {
        self.intensity = intensity
        self.style = style
    }
}

public struct VibrancyEffect {
    public let intensity: Double
    public let blendMode: BlendMode
    
    public init(intensity: Double, blendMode: BlendMode) {
        self.intensity = intensity
        self.blendMode = blendMode
    }
}

// MARK: - Theme Manager
public class ThemeManager: ObservableObject {
    @Published public var currentTheme: Theme
    @Published public var isDynamicColorEnabled: Bool = true
    @Published public var isTimeBasedThemingEnabled: Bool = false
    @Published public var isMoodBasedThemingEnabled: Bool = false
    
    private var cancellables = Set<AnyCancellable>()
    private let themes: [Theme]
    
    public init() {
        self.themes = [
            LuxuryDarkTheme(),
            OceanDepthTheme(),
            SunsetGlowTheme(),
            ForestMistTheme(),
            CyberpunkNeonTheme(),
            MinimalZenTheme(),
            WarmAutumnTheme(),
            ArcticBlueTheme(),
            CosmicPurpleTheme(),
            HighContrastTheme()
        ]
        self.currentTheme = themes[0]
        
        setupTimeBasedTheming()
    }
    
    private func setupTimeBasedTheming() {
        Timer.publish(every: 3600, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.updateThemeBasedOnTime()
            }
            .store(in: &cancellables)
    }
    
    public func setTheme(_ theme: Theme) {
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            currentTheme = theme
        }
    }
    
    public func getTheme(by id: String) -> Theme? {
        return themes.first { $0.id == id }
    }
    
    public func getAllThemes() -> [Theme] {
        return themes
    }
    
    public func getThemesByMood(_ mood: ThemeMood) -> [Theme] {
        return themes.filter { $0.mood == mood }
    }
    
    public func getSeasonalThemes() -> [Theme] {
        let currentSeason = getCurrentSeason()
        return themes.filter { $0.season == currentSeason }
    }
    
    private func updateThemeBasedOnTime() {
        guard isTimeBasedThemingEnabled else { return }
        
        let currentTime = getCurrentTimeOfDay()
        let timeBasedThemes = themes.filter { $0.timeOfDay == currentTime }
        
        if let newTheme = timeBasedThemes.randomElement() {
            setTheme(newTheme)
        }
    }
    
    private func getCurrentTimeOfDay() -> TimeOfDay {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<7: return .sunrise
        case 7..<12: return .morning
        case 12..<15: return .midday
        case 15..<18: return .afternoon
        case 18..<21: return .evening
        case 21..<24, 0..<2: return .night
        default: return .midnight
        }
    }
    
    private func getCurrentSeason() -> Season {
        let month = Calendar.current.component(.month, from: Date())
        switch month {
        case 3...5: return .spring
        case 6...8: return .summer
        case 9...11: return .autumn
        default: return .winter
        }
    }
}

// MARK: - Environment Key
private struct ThemeEnvironmentKey: EnvironmentKey {
    static let defaultValue: Theme = LuxuryDarkTheme()
}

extension EnvironmentValues {
    public var theme: Theme {
        get { self[ThemeEnvironmentKey.self] }
        set { self[ThemeEnvironmentKey.self] = newValue }
    }
}

// MARK: - View Extension
extension View {
    public func theme(_ theme: Theme) -> some View {
        environment(\.theme, theme)
    }
}