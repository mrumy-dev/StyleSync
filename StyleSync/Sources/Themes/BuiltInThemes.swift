import SwiftUI

// MARK: - 1. Luxury Dark Theme
public struct LuxuryDarkTheme: Theme {
    public let id = "luxury_dark"
    public let name = "Luxury Dark"
    public let mood = ThemeMood.luxurious
    public let timeOfDay: TimeOfDay? = .night
    public let season: Season? = nil
    
    public let colors = ColorPalette(
        primary: Color(hex: "D4AF37"), primaryLight: Color(hex: "F4D03F"), primaryDark: Color(hex: "B7950B"), primaryVariant: Color(hex: "F39C12"),
        secondary: Color(hex: "8E44AD"), secondaryLight: Color(hex: "BB8FCE"), secondaryDark: Color(hex: "6C3483"), secondaryVariant: Color(hex: "A569BD"),
        background: Color(hex: "0D1117"), surface: Color(hex: "161B22"), surfaceVariant: Color(hex: "21262D"), surfaceElevated: Color(hex: "30363D"),
        onPrimary: Color(hex: "0D1117"), onSecondary: Color.white, onBackground: Color(hex: "F0F6FC"), onSurface: Color(hex: "E6EDF3"), onSurfaceVariant: Color(hex: "7D8590"),
        success: Color(hex: "2EA043"), warning: Color(hex: "FB8500"), error: Color(hex: "DA3633"), info: Color(hex: "1F6FEB"),
        accent1: Color(hex: "FF6B9D"), accent2: Color(hex: "4ECDC4"), accent3: Color(hex: "45B7D1"),
        neutral50: Color(hex: "F8F9FA"), neutral100: Color(hex: "F1F3F4"), neutral200: Color(hex: "E8EAED"), neutral300: Color(hex: "DADCE0"), neutral400: Color(hex: "BDC1C6"), neutral500: Color(hex: "9AA0A6"), neutral600: Color(hex: "80868B"), neutral700: Color(hex: "5F6368"), neutral800: Color(hex: "3C4043"), neutral900: Color(hex: "202124")
    )
    
    public let gradients = GradientPalette(
        primary: LinearGradient(colors: [Color(hex: "D4AF37"), Color(hex: "F4D03F")], startPoint: .topLeading, endPoint: .bottomTrailing),
        secondary: LinearGradient(colors: [Color(hex: "8E44AD"), Color(hex: "BB8FCE")], startPoint: .topLeading, endPoint: .bottomTrailing),
        accent: LinearGradient(colors: [Color(hex: "FF6B9D"), Color(hex: "4ECDC4")], startPoint: .topLeading, endPoint: .bottomTrailing),
        surface: LinearGradient(colors: [Color(hex: "161B22"), Color(hex: "21262D")], startPoint: .top, endPoint: .bottom),
        hero: LinearGradient(colors: [Color(hex: "D4AF37"), Color(hex: "8E44AD"), Color(hex: "FF6B9D")], startPoint: .topLeading, endPoint: .bottomTrailing),
        mesh: [Color(hex: "D4AF37"), Color(hex: "8E44AD"), Color(hex: "FF6B9D"), Color(hex: "4ECDC4")]
    )
    
    public let effects = EffectPalette(
        glassmorphism: GlassmorphismEffect(blur: 20, opacity: 0.1, borderWidth: 1, borderOpacity: 0.2),
        neumorphism: NeumorphismEffect(
            lightShadow: ShadowToken(color: Color(hex: "30363D"), radius: 8, x: -4, y: -4, opacity: 0.6),
            darkShadow: ShadowToken(color: Color(hex: "0D1117"), radius: 8, x: 4, y: 4, opacity: 0.8),
            inset: false
        ),
        blur: BlurEffect(intensity: 25, style: .systemUltraThinMaterialDark),
        vibrancy: VibrancyEffect(intensity: 0.8, blendMode: .screen)
    )
}

// MARK: - 2. Ocean Depth Theme
public struct OceanDepthTheme: Theme {
    public let id = "ocean_depth"
    public let name = "Ocean Depth"
    public let mood = ThemeMood.calm
    public let timeOfDay: TimeOfDay? = .evening
    public let season: Season? = .summer
    
    public let colors = ColorPalette(
        primary: Color(hex: "0077BE"), primaryLight: Color(hex: "40A9FF"), primaryDark: Color(hex: "003F88"), primaryVariant: Color(hex: "1E88E5"),
        secondary: Color(hex: "26A69A"), secondaryLight: Color(hex: "80CBC4"), secondaryDark: Color(hex: "00695C"), secondaryVariant: Color(hex: "4DB6AC"),
        background: Color(hex: "001122"), surface: Color(hex: "002233"), surfaceVariant: Color(hex: "003344"), surfaceElevated: Color(hex: "004455"),
        onPrimary: Color.white, onSecondary: Color.white, onBackground: Color(hex: "B3E5FC"), onSurface: Color(hex: "E0F2F1"), onSurfaceVariant: Color(hex: "80DEEA"),
        success: Color(hex: "00C853"), warning: Color(hex: "FF6F00"), error: Color(hex: "D32F2F"), info: Color(hex: "0288D1"),
        accent1: Color(hex: "FF4081"), accent2: Color(hex: "7C4DFF"), accent3: Color(hex: "00BCD4"),
        neutral50: Color(hex: "ECEFF1"), neutral100: Color(hex: "CFD8DC"), neutral200: Color(hex: "B0BEC5"), neutral300: Color(hex: "90A4AE"), neutral400: Color(hex: "78909C"), neutral500: Color(hex: "607D8B"), neutral600: Color(hex: "546E7A"), neutral700: Color(hex: "455A64"), neutral800: Color(hex: "37474F"), neutral900: Color(hex: "263238")
    )
    
    public let gradients = GradientPalette(
        primary: LinearGradient(colors: [Color(hex: "0077BE"), Color(hex: "40A9FF")], startPoint: .topLeading, endPoint: .bottomTrailing),
        secondary: LinearGradient(colors: [Color(hex: "26A69A"), Color(hex: "80CBC4")], startPoint: .topLeading, endPoint: .bottomTrailing),
        accent: LinearGradient(colors: [Color(hex: "FF4081"), Color(hex: "7C4DFF")], startPoint: .topLeading, endPoint: .bottomTrailing),
        surface: LinearGradient(colors: [Color(hex: "002233"), Color(hex: "003344")], startPoint: .top, endPoint: .bottom),
        hero: LinearGradient(colors: [Color(hex: "001122"), Color(hex: "0077BE"), Color(hex: "26A69A")], startPoint: .topLeading, endPoint: .bottomTrailing),
        mesh: [Color(hex: "0077BE"), Color(hex: "26A69A"), Color(hex: "FF4081"), Color(hex: "7C4DFF")]
    )
    
    public let effects = EffectPalette(
        glassmorphism: GlassmorphismEffect(blur: 25, opacity: 0.15, borderWidth: 1, borderOpacity: 0.3),
        neumorphism: NeumorphismEffect(
            lightShadow: ShadowToken(color: Color(hex: "004455"), radius: 10, x: -5, y: -5, opacity: 0.5),
            darkShadow: ShadowToken(color: Color(hex: "001122"), radius: 10, x: 5, y: 5, opacity: 0.9),
            inset: false
        ),
        blur: BlurEffect(intensity: 30, style: .systemThinMaterialDark),
        vibrancy: VibrancyEffect(intensity: 0.7, blendMode: .overlay)
    )
}

// MARK: - 3. Sunset Glow Theme
public struct SunsetGlowTheme: Theme {
    public let id = "sunset_glow"
    public let name = "Sunset Glow"
    public let mood = ThemeMood.warm
    public let timeOfDay: TimeOfDay? = .sunset
    public let season: Season? = .autumn
    
    public let colors = ColorPalette(
        primary: Color(hex: "FF6B35"), primaryLight: Color(hex: "FF8A65"), primaryDark: Color(hex: "E64A19"), primaryVariant: Color(hex: "FF7043"),
        secondary: Color(hex: "FFC107"), secondaryLight: Color(hex: "FFD54F"), secondaryDark: Color(hex: "FFA000"), secondaryVariant: Color(hex: "FFCA28"),
        background: Color(hex: "1A0D0A"), surface: Color(hex: "2A1A17"), surfaceVariant: Color(hex: "3A2724"), surfaceElevated: Color(hex: "4A3431"),
        onPrimary: Color.white, onSecondary: Color(hex: "1A0D0A"), onBackground: Color(hex: "FFE0B2"), onSurface: Color(hex: "FFCCBC"), onSurfaceVariant: Color(hex: "BCAAA4"),
        success: Color(hex: "66BB6A"), warning: Color(hex: "FF9800"), error: Color(hex: "F44336"), info: Color(hex: "42A5F5"),
        accent1: Color(hex: "E91E63"), accent2: Color(hex: "9C27B0"), accent3: Color(hex: "FF5722"),
        neutral50: Color(hex: "FFF8E1"), neutral100: Color(hex: "FFECB3"), neutral200: Color(hex: "FFE082"), neutral300: Color(hex: "FFD54F"), neutral400: Color(hex: "FFCA28"), neutral500: Color(hex: "FFC107"), neutral600: Color(hex: "FFB300"), neutral700: Color(hex: "FFA000"), neutral800: Color(hex: "FF8F00"), neutral900: Color(hex: "FF6F00")
    )
    
    public let gradients = GradientPalette(
        primary: LinearGradient(colors: [Color(hex: "FF6B35"), Color(hex: "FFC107")], startPoint: .topLeading, endPoint: .bottomTrailing),
        secondary: LinearGradient(colors: [Color(hex: "FFC107"), Color(hex: "FF8A65")], startPoint: .topLeading, endPoint: .bottomTrailing),
        accent: LinearGradient(colors: [Color(hex: "E91E63"), Color(hex: "9C27B0")], startPoint: .topLeading, endPoint: .bottomTrailing),
        surface: LinearGradient(colors: [Color(hex: "2A1A17"), Color(hex: "3A2724")], startPoint: .top, endPoint: .bottom),
        hero: LinearGradient(colors: [Color(hex: "FF6B35"), Color(hex: "FFC107"), Color(hex: "E91E63")], startPoint: .topLeading, endPoint: .bottomTrailing),
        mesh: [Color(hex: "FF6B35"), Color(hex: "FFC107"), Color(hex: "E91E63"), Color(hex: "9C27B0")]
    )
    
    public let effects = EffectPalette(
        glassmorphism: GlassmorphismEffect(blur: 20, opacity: 0.12, borderWidth: 1.5, borderOpacity: 0.25),
        neumorphism: NeumorphismEffect(
            lightShadow: ShadowToken(color: Color(hex: "4A3431"), radius: 12, x: -6, y: -6, opacity: 0.4),
            darkShadow: ShadowToken(color: Color(hex: "1A0D0A"), radius: 12, x: 6, y: 6, opacity: 0.8),
            inset: false
        ),
        blur: BlurEffect(intensity: 22, style: .systemUltraThinMaterialDark),
        vibrancy: VibrancyEffect(intensity: 0.9, blendMode: .softLight)
    )
}

// MARK: - 4. Forest Mist Theme
public struct ForestMistTheme: Theme {
    public let id = "forest_mist"
    public let name = "Forest Mist"
    public let mood = ThemeMood.calm
    public let timeOfDay: TimeOfDay? = .morning
    public let season: Season? = .spring
    
    public let colors = ColorPalette(
        primary: Color(hex: "2E7D32"), primaryLight: Color(hex: "66BB6A"), primaryDark: Color(hex: "1B5E20"), primaryVariant: Color(hex: "388E3C"),
        secondary: Color(hex: "795548"), secondaryLight: Color(hex: "A1887F"), secondaryDark: Color(hex: "5D4037"), secondaryVariant: Color(hex: "8D6E63"),
        background: Color(hex: "F1F8E9"), surface: Color(hex: "E8F5E8"), surfaceVariant: Color(hex: "C8E6C9"), surfaceElevated: Color(hex: "A5D6A7"),
        onPrimary: Color.white, onSecondary: Color.white, onBackground: Color(hex: "1B5E20"), onSurface: Color(hex: "2E7D32"), onSurfaceVariant: Color(hex: "388E3C"),
        success: Color(hex: "4CAF50"), warning: Color(hex: "FF9800"), error: Color(hex: "F44336"), info: Color(hex: "2196F3"),
        accent1: Color(hex: "FF5722"), accent2: Color(hex: "9C27B0"), accent3: Color(hex: "00BCD4"),
        neutral50: Color(hex: "FAFAFA"), neutral100: Color(hex: "F5F5F5"), neutral200: Color(hex: "EEEEEE"), neutral300: Color(hex: "E0E0E0"), neutral400: Color(hex: "BDBDBD"), neutral500: Color(hex: "9E9E9E"), neutral600: Color(hex: "757575"), neutral700: Color(hex: "616161"), neutral800: Color(hex: "424242"), neutral900: Color(hex: "212121")
    )
    
    public let gradients = GradientPalette(
        primary: LinearGradient(colors: [Color(hex: "2E7D32"), Color(hex: "66BB6A")], startPoint: .topLeading, endPoint: .bottomTrailing),
        secondary: LinearGradient(colors: [Color(hex: "795548"), Color(hex: "A1887F")], startPoint: .topLeading, endPoint: .bottomTrailing),
        accent: LinearGradient(colors: [Color(hex: "FF5722"), Color(hex: "9C27B0")], startPoint: .topLeading, endPoint: .bottomTrailing),
        surface: LinearGradient(colors: [Color(hex: "E8F5E8"), Color(hex: "C8E6C9")], startPoint: .top, endPoint: .bottom),
        hero: LinearGradient(colors: [Color(hex: "F1F8E9"), Color(hex: "2E7D32"), Color(hex: "795548")], startPoint: .topLeading, endPoint: .bottomTrailing),
        mesh: [Color(hex: "2E7D32"), Color(hex: "795548"), Color(hex: "FF5722"), Color(hex: "9C27B0")]
    )
    
    public let effects = EffectPalette(
        glassmorphism: GlassmorphismEffect(blur: 15, opacity: 0.2, borderWidth: 1, borderOpacity: 0.3),
        neumorphism: NeumorphismEffect(
            lightShadow: ShadowToken(color: Color.white, radius: 8, x: -4, y: -4, opacity: 0.8),
            darkShadow: ShadowToken(color: Color(hex: "A5D6A7"), radius: 8, x: 4, y: 4, opacity: 0.6),
            inset: false
        ),
        blur: BlurEffect(intensity: 18, style: .systemUltraThinMaterialLight),
        vibrancy: VibrancyEffect(intensity: 0.6, blendMode: .multiply)
    )
}

// MARK: - 5. Cyberpunk Neon Theme
public struct CyberpunkNeonTheme: Theme {
    public let id = "cyberpunk_neon"
    public let name = "Cyberpunk Neon"
    public let mood = ThemeMood.energetic
    public let timeOfDay: TimeOfDay? = .midnight
    public let season: Season? = nil
    
    public let colors = ColorPalette(
        primary: Color(hex: "00FFFF"), primaryLight: Color(hex: "4DFFFF"), primaryDark: Color(hex: "00CCCC"), primaryVariant: Color(hex: "26E6E6"),
        secondary: Color(hex: "FF00FF"), secondaryLight: Color(hex: "FF4DFF"), secondaryDark: Color(hex: "CC00CC"), secondaryVariant: Color(hex: "E626E6"),
        background: Color(hex: "0A0A0A"), surface: Color(hex: "1A1A2E"), surfaceVariant: Color(hex: "16213E"), surfaceElevated: Color(hex: "0F3460"),
        onPrimary: Color(hex: "0A0A0A"), onSecondary: Color(hex: "0A0A0A"), onBackground: Color(hex: "00FFFF"), onSurface: Color(hex: "FFFFFF"), onSurfaceVariant: Color(hex: "B3B3B3"),
        success: Color(hex: "00FF00"), warning: Color(hex: "FFFF00"), error: Color(hex: "FF0040"), info: Color(hex: "0080FF"),
        accent1: Color(hex: "FF6B35"), accent2: Color(hex: "7C4DFF"), accent3: Color(hex: "00E676"),
        neutral50: Color(hex: "FAFAFA"), neutral100: Color(hex: "F5F5F5"), neutral200: Color(hex: "EEEEEE"), neutral300: Color(hex: "E0E0E0"), neutral400: Color(hex: "BDBDBD"), neutral500: Color(hex: "9E9E9E"), neutral600: Color(hex: "757575"), neutral700: Color(hex: "616161"), neutral800: Color(hex: "424242"), neutral900: Color(hex: "212121")
    )
    
    public let gradients = GradientPalette(
        primary: LinearGradient(colors: [Color(hex: "00FFFF"), Color(hex: "FF00FF")], startPoint: .topLeading, endPoint: .bottomTrailing),
        secondary: LinearGradient(colors: [Color(hex: "FF00FF"), Color(hex: "4DFFFF")], startPoint: .topLeading, endPoint: .bottomTrailing),
        accent: LinearGradient(colors: [Color(hex: "FF6B35"), Color(hex: "7C4DFF")], startPoint: .topLeading, endPoint: .bottomTrailing),
        surface: LinearGradient(colors: [Color(hex: "1A1A2E"), Color(hex: "16213E")], startPoint: .top, endPoint: .bottom),
        hero: LinearGradient(colors: [Color(hex: "0A0A0A"), Color(hex: "00FFFF"), Color(hex: "FF00FF")], startPoint: .topLeading, endPoint: .bottomTrailing),
        mesh: [Color(hex: "00FFFF"), Color(hex: "FF00FF"), Color(hex: "FF6B35"), Color(hex: "7C4DFF")]
    )
    
    public let effects = EffectPalette(
        glassmorphism: GlassmorphismEffect(blur: 30, opacity: 0.05, borderWidth: 2, borderOpacity: 0.4),
        neumorphism: NeumorphismEffect(
            lightShadow: ShadowToken(color: Color(hex: "0F3460"), radius: 15, x: -8, y: -8, opacity: 0.3),
            darkShadow: ShadowToken(color: Color(hex: "0A0A0A"), radius: 15, x: 8, y: 8, opacity: 0.9),
            inset: false
        ),
        blur: BlurEffect(intensity: 35, style: .systemUltraThinMaterialDark),
        vibrancy: VibrancyEffect(intensity: 1.0, blendMode: .screen)
    )
}

// MARK: - 6. Minimal Zen Theme
public struct MinimalZenTheme: Theme {
    public let id = "minimal_zen"
    public let name = "Minimal Zen"
    public let mood = ThemeMood.minimal
    public let timeOfDay: TimeOfDay? = .midday
    public let season: Season? = nil
    
    public let colors = ColorPalette(
        primary: Color(hex: "2C2C2C"), primaryLight: Color(hex: "5C5C5C"), primaryDark: Color(hex: "1C1C1C"), primaryVariant: Color(hex: "424242"),
        secondary: Color(hex: "757575"), secondaryLight: Color(hex: "A4A4A4"), secondaryDark: Color(hex: "616161"), secondaryVariant: Color(hex: "9E9E9E"),
        background: Color(hex: "FAFAFA"), surface: Color(hex: "FFFFFF"), surfaceVariant: Color(hex: "F5F5F5"), surfaceElevated: Color(hex: "F0F0F0"),
        onPrimary: Color.white, onSecondary: Color.white, onBackground: Color(hex: "2C2C2C"), onSurface: Color(hex: "1C1C1C"), onSurfaceVariant: Color(hex: "616161"),
        success: Color(hex: "4CAF50"), warning: Color(hex: "FF9800"), error: Color(hex: "F44336"), info: Color(hex: "2196F3"),
        accent1: Color(hex: "FF5722"), accent2: Color(hex: "9C27B0"), accent3: Color(hex: "00BCD4"),
        neutral50: Color(hex: "FAFAFA"), neutral100: Color(hex: "F5F5F5"), neutral200: Color(hex: "EEEEEE"), neutral300: Color(hex: "E0E0E0"), neutral400: Color(hex: "BDBDBD"), neutral500: Color(hex: "9E9E9E"), neutral600: Color(hex: "757575"), neutral700: Color(hex: "616161"), neutral800: Color(hex: "424242"), neutral900: Color(hex: "212121")
    )
    
    public let gradients = GradientPalette(
        primary: LinearGradient(colors: [Color(hex: "2C2C2C"), Color(hex: "5C5C5C")], startPoint: .topLeading, endPoint: .bottomTrailing),
        secondary: LinearGradient(colors: [Color(hex: "757575"), Color(hex: "A4A4A4")], startPoint: .topLeading, endPoint: .bottomTrailing),
        accent: LinearGradient(colors: [Color(hex: "FF5722"), Color(hex: "9C27B0")], startPoint: .topLeading, endPoint: .bottomTrailing),
        surface: LinearGradient(colors: [Color(hex: "FFFFFF"), Color(hex: "F5F5F5")], startPoint: .top, endPoint: .bottom),
        hero: LinearGradient(colors: [Color(hex: "FAFAFA"), Color(hex: "2C2C2C"), Color(hex: "757575")], startPoint: .topLeading, endPoint: .bottomTrailing),
        mesh: [Color(hex: "2C2C2C"), Color(hex: "757575"), Color(hex: "FF5722"), Color(hex: "9C27B0")]
    )
    
    public let effects = EffectPalette(
        glassmorphism: GlassmorphismEffect(blur: 10, opacity: 0.3, borderWidth: 0.5, borderOpacity: 0.2),
        neumorphism: NeumorphismEffect(
            lightShadow: ShadowToken(color: Color.white, radius: 6, x: -3, y: -3, opacity: 1.0),
            darkShadow: ShadowToken(color: Color(hex: "E0E0E0"), radius: 6, x: 3, y: 3, opacity: 0.8),
            inset: false
        ),
        blur: BlurEffect(intensity: 12, style: .systemThinMaterialLight),
        vibrancy: VibrancyEffect(intensity: 0.4, blendMode: .normal)
    )
}

// MARK: - 7. Warm Autumn Theme
public struct WarmAutumnTheme: Theme {
    public let id = "warm_autumn"
    public let name = "Warm Autumn"
    public let mood = ThemeMood.warm
    public let timeOfDay: TimeOfDay? = .afternoon
    public let season: Season? = .autumn
    
    public let colors = ColorPalette(
        primary: Color(hex: "BF360C"), primaryLight: Color(hex: "FF8A65"), primaryDark: Color(hex: "8C1F00"), primaryVariant: Color(hex: "FF5722"),
        secondary: Color(hex: "FF8F00"), secondaryLight: Color(hex: "FFCC02"), secondaryDark: Color(hex: "C56000"), secondaryVariant: Color(hex: "FFA000"),
        background: Color(hex: "FFF8E1"), surface: Color(hex: "FFFBF0"), surfaceVariant: Color(hex: "FFECB3"), surfaceElevated: Color(hex: "FFE0B2"),
        onPrimary: Color.white, onSecondary: Color(hex: "8C1F00"), onBackground: Color(hex: "BF360C"), onSurface: Color(hex: "8C1F00"), onSurfaceVariant: Color(hex: "C56000"),
        success: Color(hex: "689F38"), warning: Color(hex: "FF9800"), error: Color(hex: "D32F2F"), info: Color(hex: "1976D2"),
        accent1: Color(hex: "8BC34A"), accent2: Color(hex: "9C27B0"), accent3: Color(hex: "00ACC1"),
        neutral50: Color(hex: "FFF8E1"), neutral100: Color(hex: "FFECB3"), neutral200: Color(hex: "FFE082"), neutral300: Color(hex: "FFD54F"), neutral400: Color(hex: "FFCA28"), neutral500: Color(hex: "FFC107"), neutral600: Color(hex: "FFB300"), neutral700: Color(hex: "FFA000"), neutral800: Color(hex: "FF8F00"), neutral900: Color(hex: "FF6F00")
    )
    
    public let gradients = GradientPalette(
        primary: LinearGradient(colors: [Color(hex: "BF360C"), Color(hex: "FF8F00")], startPoint: .topLeading, endPoint: .bottomTrailing),
        secondary: LinearGradient(colors: [Color(hex: "FF8F00"), Color(hex: "FFCC02")], startPoint: .topLeading, endPoint: .bottomTrailing),
        accent: LinearGradient(colors: [Color(hex: "8BC34A"), Color(hex: "9C27B0")], startPoint: .topLeading, endPoint: .bottomTrailing),
        surface: LinearGradient(colors: [Color(hex: "FFFBF0"), Color(hex: "FFECB3")], startPoint: .top, endPoint: .bottom),
        hero: LinearGradient(colors: [Color(hex: "FFF8E1"), Color(hex: "BF360C"), Color(hex: "FF8F00")], startPoint: .topLeading, endPoint: .bottomTrailing),
        mesh: [Color(hex: "BF360C"), Color(hex: "FF8F00"), Color(hex: "8BC34A"), Color(hex: "9C27B0")]
    )
    
    public let effects = EffectPalette(
        glassmorphism: GlassmorphismEffect(blur: 18, opacity: 0.25, borderWidth: 1, borderOpacity: 0.35),
        neumorphism: NeumorphismEffect(
            lightShadow: ShadowToken(color: Color.white, radius: 10, x: -5, y: -5, opacity: 0.9),
            darkShadow: ShadowToken(color: Color(hex: "FFE0B2"), radius: 10, x: 5, y: 5, opacity: 0.7),
            inset: false
        ),
        blur: BlurEffect(intensity: 20, style: .systemThinMaterialLight),
        vibrancy: VibrancyEffect(intensity: 0.7, blendMode: .multiply)
    )
}

// MARK: - 8. Arctic Blue Theme
public struct ArcticBlueTheme: Theme {
    public let id = "arctic_blue"
    public let name = "Arctic Blue"
    public let mood = ThemeMood.cool
    public let timeOfDay: TimeOfDay? = .morning
    public let season: Season? = .winter
    
    public let colors = ColorPalette(
        primary: Color(hex: "0277BD"), primaryLight: Color(hex: "58A5F0"), primaryDark: Color(hex: "004C8C"), primaryVariant: Color(hex: "0288D1"),
        secondary: Color(hex: "00838F"), secondaryLight: Color(hex: "4FB3D9"), secondaryDark: Color(hex: "005662"), secondaryVariant: Color(hex: "00ACC1"),
        background: Color(hex: "E3F2FD"), surface: Color(hex: "F1F8FF"), surfaceVariant: Color(hex: "BBDEFB"), surfaceElevated: Color(hex: "90CAF9"),
        onPrimary: Color.white, onSecondary: Color.white, onBackground: Color(hex: "0277BD"), onSurface: Color(hex: "004C8C"), onSurfaceVariant: Color(hex: "005662"),
        success: Color(hex: "00C853"), warning: Color(hex: "FF8F00"), error: Color(hex: "D32F2F"), info: Color(hex: "1976D2"),
        accent1: Color(hex: "FF4081"), accent2: Color(hex: "7C4DFF"), accent3: Color(hex: "00E676"),
        neutral50: Color(hex: "FAFAFA"), neutral100: Color(hex: "F5F5F5"), neutral200: Color(hex: "EEEEEE"), neutral300: Color(hex: "E0E0E0"), neutral400: Color(hex: "BDBDBD"), neutral500: Color(hex: "9E9E9E"), neutral600: Color(hex: "757575"), neutral700: Color(hex: "616161"), neutral800: Color(hex: "424242"), neutral900: Color(hex: "212121")
    )
    
    public let gradients = GradientPalette(
        primary: LinearGradient(colors: [Color(hex: "0277BD"), Color(hex: "58A5F0")], startPoint: .topLeading, endPoint: .bottomTrailing),
        secondary: LinearGradient(colors: [Color(hex: "00838F"), Color(hex: "4FB3D9")], startPoint: .topLeading, endPoint: .bottomTrailing),
        accent: LinearGradient(colors: [Color(hex: "FF4081"), Color(hex: "7C4DFF")], startPoint: .topLeading, endPoint: .bottomTrailing),
        surface: LinearGradient(colors: [Color(hex: "F1F8FF"), Color(hex: "BBDEFB")], startPoint: .top, endPoint: .bottom),
        hero: LinearGradient(colors: [Color(hex: "E3F2FD"), Color(hex: "0277BD"), Color(hex: "00838F")], startPoint: .topLeading, endPoint: .bottomTrailing),
        mesh: [Color(hex: "0277BD"), Color(hex: "00838F"), Color(hex: "FF4081"), Color(hex: "7C4DFF")]
    )
    
    public let effects = EffectPalette(
        glassmorphism: GlassmorphismEffect(blur: 16, opacity: 0.2, borderWidth: 1, borderOpacity: 0.3),
        neumorphism: NeumorphismEffect(
            lightShadow: ShadowToken(color: Color.white, radius: 8, x: -4, y: -4, opacity: 0.8),
            darkShadow: ShadowToken(color: Color(hex: "90CAF9"), radius: 8, x: 4, y: 4, opacity: 0.6),
            inset: false
        ),
        blur: BlurEffect(intensity: 18, style: .systemThinMaterialLight),
        vibrancy: VibrancyEffect(intensity: 0.6, blendMode: .overlay)
    )
}

// MARK: - 9. Cosmic Purple Theme
public struct CosmicPurpleTheme: Theme {
    public let id = "cosmic_purple"
    public let name = "Cosmic Purple"
    public let mood = ThemeMood.creative
    public let timeOfDay: TimeOfDay? = .night
    public let season: Season? = nil
    
    public let colors = ColorPalette(
        primary: Color(hex: "6A1B9A"), primaryLight: Color(hex: "AB47BC"), primaryDark: Color(hex: "4A148C"), primaryVariant: Color(hex: "8E24AA"),
        secondary: Color(hex: "3F51B5"), secondaryLight: Color(hex: "7986CB"), secondaryDark: Color(hex: "303F9F"), secondaryVariant: Color(hex: "5C6BC0"),
        background: Color(hex: "120A1A"), surface: Color(hex: "1D0F2A"), surfaceVariant: Color(hex: "2D1B3D"), surfaceElevated: Color(hex: "3D2B4D"),
        onPrimary: Color.white, onSecondary: Color.white, onBackground: Color(hex: "E1BEE7"), onSurface: Color(hex: "D1C4E9"), onSurfaceVariant: Color(hex: "B39DDB"),
        success: Color(hex: "66BB6A"), warning: Color(hex: "FFA726"), error: Color(hex: "EF5350"), info: Color(hex: "42A5F5"),
        accent1: Color(hex: "FF4081"), accent2: Color(hex: "00E676"), accent3: Color(hex: "FFD740"),
        neutral50: Color(hex: "FAFAFA"), neutral100: Color(hex: "F5F5F5"), neutral200: Color(hex: "EEEEEE"), neutral300: Color(hex: "E0E0E0"), neutral400: Color(hex: "BDBDBD"), neutral500: Color(hex: "9E9E9E"), neutral600: Color(hex: "757575"), neutral700: Color(hex: "616161"), neutral800: Color(hex: "424242"), neutral900: Color(hex: "212121")
    )
    
    public let gradients = GradientPalette(
        primary: LinearGradient(colors: [Color(hex: "6A1B9A"), Color(hex: "3F51B5")], startPoint: .topLeading, endPoint: .bottomTrailing),
        secondary: LinearGradient(colors: [Color(hex: "3F51B5"), Color(hex: "7986CB")], startPoint: .topLeading, endPoint: .bottomTrailing),
        accent: LinearGradient(colors: [Color(hex: "FF4081"), Color(hex: "00E676")], startPoint: .topLeading, endPoint: .bottomTrailing),
        surface: LinearGradient(colors: [Color(hex: "1D0F2A"), Color(hex: "2D1B3D")], startPoint: .top, endPoint: .bottom),
        hero: LinearGradient(colors: [Color(hex: "120A1A"), Color(hex: "6A1B9A"), Color(hex: "3F51B5")], startPoint: .topLeading, endPoint: .bottomTrailing),
        mesh: [Color(hex: "6A1B9A"), Color(hex: "3F51B5"), Color(hex: "FF4081"), Color(hex: "00E676")]
    )
    
    public let effects = EffectPalette(
        glassmorphism: GlassmorphismEffect(blur: 25, opacity: 0.1, borderWidth: 1.5, borderOpacity: 0.25),
        neumorphism: NeumorphismEffect(
            lightShadow: ShadowToken(color: Color(hex: "3D2B4D"), radius: 12, x: -6, y: -6, opacity: 0.4),
            darkShadow: ShadowToken(color: Color(hex: "120A1A"), radius: 12, x: 6, y: 6, opacity: 0.9),
            inset: false
        ),
        blur: BlurEffect(intensity: 28, style: .systemUltraThinMaterialDark),
        vibrancy: VibrancyEffect(intensity: 0.8, blendMode: .screen)
    )
}

// MARK: - 10. High Contrast Theme
public struct HighContrastTheme: Theme {
    public let id = "high_contrast"
    public let name = "High Contrast"
    public let mood = ThemeMood.focused
    public let timeOfDay: TimeOfDay? = nil
    public let season: Season? = nil
    
    public let colors = ColorPalette(
        primary: Color.black, primaryLight: Color(hex: "333333"), primaryDark: Color.black, primaryVariant: Color(hex: "1A1A1A"),
        secondary: Color(hex: "666666"), secondaryLight: Color(hex: "999999"), secondaryDark: Color(hex: "333333"), secondaryVariant: Color(hex: "4D4D4D"),
        background: Color.white, surface: Color.white, surfaceVariant: Color(hex: "F5F5F5"), surfaceElevated: Color(hex: "EEEEEE"),
        onPrimary: Color.white, onSecondary: Color.white, onBackground: Color.black, onSurface: Color.black, onSurfaceVariant: Color.black,
        success: Color(hex: "006600"), warning: Color(hex: "CC6600"), error: Color(hex: "CC0000"), info: Color(hex: "0066CC"),
        accent1: Color(hex: "FF0000"), accent2: Color(hex: "0000FF"), accent3: Color(hex: "00AA00"),
        neutral50: Color(hex: "FFFFFF"), neutral100: Color(hex: "F5F5F5"), neutral200: Color(hex: "EEEEEE"), neutral300: Color(hex: "E0E0E0"), neutral400: Color(hex: "BDBDBD"), neutral500: Color(hex: "9E9E9E"), neutral600: Color(hex: "757575"), neutral700: Color(hex: "616161"), neutral800: Color(hex: "424242"), neutral900: Color(hex: "212121")
    )
    
    public let gradients = GradientPalette(
        primary: LinearGradient(colors: [Color.black, Color(hex: "333333")], startPoint: .topLeading, endPoint: .bottomTrailing),
        secondary: LinearGradient(colors: [Color(hex: "666666"), Color(hex: "999999")], startPoint: .topLeading, endPoint: .bottomTrailing),
        accent: LinearGradient(colors: [Color(hex: "FF0000"), Color(hex: "0000FF")], startPoint: .topLeading, endPoint: .bottomTrailing),
        surface: LinearGradient(colors: [Color.white, Color(hex: "F5F5F5")], startPoint: .top, endPoint: .bottom),
        hero: LinearGradient(colors: [Color.white, Color.black, Color(hex: "666666")], startPoint: .topLeading, endPoint: .bottomTrailing),
        mesh: [Color.black, Color(hex: "666666"), Color(hex: "FF0000"), Color(hex: "0000FF")]
    )
    
    public let effects = EffectPalette(
        glassmorphism: GlassmorphismEffect(blur: 5, opacity: 0.1, borderWidth: 2, borderOpacity: 1.0),
        neumorphism: NeumorphismEffect(
            lightShadow: ShadowToken(color: Color.white, radius: 4, x: -2, y: -2, opacity: 1.0),
            darkShadow: ShadowToken(color: Color(hex: "CCCCCC"), radius: 4, x: 2, y: 2, opacity: 1.0),
            inset: false
        ),
        blur: BlurEffect(intensity: 8, style: .systemThinMaterialLight),
        vibrancy: VibrancyEffect(intensity: 0.2, blendMode: .normal)
    )
}

// MARK: - Color Extension for Hex
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}