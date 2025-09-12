import SwiftUI

// MARK: - StyleSync App
@main
struct StyleSyncApp: App {
    @StateObject private var themeManager = ThemeManager()
    @StateObject private var hapticManager = HapticFeedbackManager()
    @StateObject private var soundManager = SoundDesignManager()
    @StateObject private var typographyManager = TypographyManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(themeManager)
                .environmentObject(hapticManager)
                .environmentObject(soundManager)
                .environmentObject(typographyManager)
                .environment(\.theme, themeManager.currentTheme)
                .preferredColorScheme(colorScheme(for: themeManager.currentTheme))
        }
    }
    
    private func colorScheme(for theme: Theme) -> ColorScheme? {
        // Determine color scheme based on theme colors
        if theme.colors.background.luminance < 0.5 {
            return .dark
        } else {
            return .light
        }
    }
}

// MARK: - Main Content View
struct ContentView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @State private var selectedTab = 0
    
    var body: some View {
        ZStack {
            // Gradient Mesh Background
            GradientMeshBackground(colors: themeManager.currentTheme.gradients.mesh)
                .ignoresSafeArea()
            
            VStack {
                // Main Content
                TabView(selection: $selectedTab) {
                    HomeView()
                        .tag(0)
                    
                    ComponentsShowcaseView()
                        .tag(1)
                    
                    ThemesView()
                        .tag(2)
                    
                    SettingsView()
                        .tag(3)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                
                // Custom Liquid Tab Bar
                LiquidTabBar(
                    selectedIndex: $selectedTab,
                    items: [
                        TabItem(icon: "house", selectedIcon: "house.fill", title: "Home"),
                        TabItem(icon: "square.grid.2x2", selectedIcon: "square.grid.2x2.fill", title: "Components"),
                        TabItem(icon: "paintbrush", selectedIcon: "paintbrush.fill", title: "Themes"),
                        TabItem(icon: "gear", selectedIcon: "gear.fill", title: "Settings")
                    ]
                )
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
        }
    }
}

// MARK: - Home View
struct HomeView: View {
    @Environment(\.theme) private var theme
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Hero Section
                VStack(spacing: 16) {
                    DynamicTypeText(
                        "StyleSync",
                        style: .display1,
                        fontTheme: .elegant
                    )
                    .animatedText(.glow(color: theme.colors.primary, intensity: 0.8))
                    
                    DynamicTypeText(
                        "Beautiful UI Foundation",
                        style: .heading3,
                        fontTheme: .modern
                    )
                    .foregroundColor(theme.colors.onBackground.opacity(0.7))
                }
                .padding(.top, 40)
                
                // Feature Cards
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 16) {
                    FeatureCard(
                        icon: "wand.and.stars",
                        title: "Glassmorphism",
                        description: "Beautiful glass effects",
                        color: theme.colors.accent1
                    )
                    
                    FeatureCard(
                        icon: "circle.hexagongrid",
                        title: "Neumorphism",
                        description: "Soft UI elements",
                        color: theme.colors.accent2
                    )
                    
                    FeatureCard(
                        icon: "sparkles",
                        title: "Particles",
                        description: "Dynamic effects",
                        color: theme.colors.accent3
                    )
                    
                    FeatureCard(
                        icon: "music.note",
                        title: "Sound Design",
                        description: "Audio feedback",
                        color: theme.colors.primary
                    )
                }
                .padding(.horizontal)
                
                // Interactive Demo Section
                VStack(spacing: 16) {
                    DynamicTypeText(
                        "Interactive Demo",
                        style: .heading2,
                        fontTheme: .modern
                    )
                    
                    ParallaxCard {
                        VStack(spacing: 12) {
                            Image(systemName: "hand.tap.fill")
                                .font(.system(size: 40))
                                .foregroundColor(theme.colors.primary)
                                .motion(.bounce(height: 10, speed: 1.2))
                            
                            Text("Drag me around!")
                                .typography(.body1, theme: .playful)
                                .foregroundColor(theme.colors.onSurface)
                        }
                        .padding(20)
                    }
                    .frame(height: 120)
                    .padding(.horizontal)
                }
                
                Spacer(minLength: 100)
            }
        }
        .background(Color.clear)
    }
}

// MARK: - Feature Card
struct FeatureCard: View {
    let icon: String
    let title: String
    let description: String
    let color: Color
    @Environment(\.theme) private var theme
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 32, weight: .medium))
                .foregroundColor(color)
                .motion(.float(amplitude: 5, speed: 2.0 + Double.random(in: -0.5...0.5)))
            
            Text(title)
                .typography(.heading4, theme: .modern)
                .foregroundColor(theme.colors.onSurface)
            
            Text(description)
                .typography(.body2, theme: .system)
                .foregroundColor(theme.colors.onSurfaceVariant)
                .multilineTextAlignment(.center)
        }
        .padding(20)
        .frame(height: 140)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(theme.colors.surface)
                .glassmorphism(intensity: .light)
        )
        .tapWithHaptic(.light) {
            // Handle tap
        }
        .soundEffect(.pop, trigger: .hover)
    }
}

// MARK: - Components Showcase View
struct ComponentsShowcaseView: View {
    @Environment(\.theme) private var theme
    @State private var isFlipped = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                DynamicTypeText(
                    "Components",
                    style: .display2,
                    fontTheme: .modern
                )
                .padding(.top, 20)
                
                // Buttons Section
                VStack(spacing: 16) {
                    Text("Interactive Buttons")
                        .typography(.heading3, theme: .modern)
                        .foregroundColor(theme.colors.onBackground)
                    
                    HStack(spacing: 16) {
                        FloatingActionButton(icon: "plus") {
                            // Handle action
                        }
                        
                        Button("Glassmorphism") {
                            // Handle action
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(theme.colors.surface)
                                .glassmorphism(intensity: .medium)
                        )
                        .foregroundColor(theme.colors.primary)
                        .tapWithHaptic(.medium)
                        
                        Button("Neumorphic") {
                            // Handle action
                        }
                        .padding()
                        .foregroundColor(theme.colors.onSurface)
                        .neumorphism(style: .raised, intensity: .medium, cornerRadius: 12)
                        .tapWithHaptic(.medium)
                    }
                }
                
                // 3D Card Demo
                VStack(spacing: 16) {
                    Text("3D Card Flip")
                        .typography(.heading3, theme: .modern)
                        .foregroundColor(theme.colors.onBackground)
                    
                    Card3DFlip(
                        front: {
                            CardContent(
                                title: "Front Side",
                                icon: "star.fill",
                                color: theme.colors.primary
                            )
                        },
                        back: {
                            CardContent(
                                title: "Back Side",
                                icon: "heart.fill",
                                color: theme.colors.accent1
                            )
                        }
                    )
                    .frame(width: 200, height: 120)
                }
                
                // Shimmer Loading Demo
                VStack(spacing: 16) {
                    Text("Loading Effects")
                        .typography(.heading3, theme: .modern)
                        .foregroundColor(theme.colors.onBackground)
                    
                    VStack(spacing: 8) {
                        ShimmerView()
                            .frame(height: 20)
                            .cornerRadius(4)
                        
                        ShimmerView()
                            .frame(height: 20)
                            .cornerRadius(4)
                        
                        ShimmerView()
                            .frame(width: 150, height: 20)
                            .cornerRadius(4)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(theme.colors.surface)
                            .glassmorphism(intensity: .light)
                    )
                }
                .padding(.horizontal)
                
                Spacer(minLength: 100)
            }
        }
        .background(Color.clear)
    }
}

// MARK: - Card Content
struct CardContent: View {
    let title: String
    let icon: String
    let color: Color
    @Environment(\.theme) private var theme
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(color)
            
            Text(title)
                .typography(.heading4, theme: .modern)
                .foregroundColor(theme.colors.onSurface)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(theme.colors.surface)
                .glassmorphism(intensity: .medium)
        )
    }
}

// MARK: - Themes View
struct ThemesView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                DynamicTypeText(
                    "Themes",
                    style: .display2,
                    fontTheme: .elegant
                )
                .padding(.top, 20)
                
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 16) {
                    ForEach(themeManager.getAllThemes(), id: \.id) { theme in
                        ThemeCard(theme: theme, isSelected: theme.id == themeManager.currentTheme.id) {
                            themeManager.setTheme(theme)
                        }
                    }
                }
                .padding(.horizontal)
                
                Spacer(minLength: 100)
            }
        }
        .background(Color.clear)
    }
}

// MARK: - Theme Card
struct ThemeCard: View {
    let theme: Theme
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                // Theme Colors Preview
                HStack(spacing: 4) {
                    Circle()
                        .fill(theme.colors.primary)
                        .frame(width: 16, height: 16)
                    Circle()
                        .fill(theme.colors.secondary)
                        .frame(width: 16, height: 16)
                    Circle()
                        .fill(theme.colors.accent1)
                        .frame(width: 16, height: 16)
                    Circle()
                        .fill(theme.colors.accent2)
                        .frame(width: 16, height: 16)
                }
                
                Text(theme.name)
                    .typography(.body1, theme: .modern)
                    .foregroundColor(theme.colors.onSurface)
                
                Text(theme.mood.rawValue.capitalized)
                    .typography(.caption1, theme: .system)
                    .foregroundColor(theme.colors.onSurfaceVariant)
            }
            .padding(16)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(theme.colors.surface)
                    .glassmorphism(intensity: .light)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(theme.colors.primary, lineWidth: isSelected ? 2 : 0)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(.snappySpring, value: isSelected)
        .hapticFeedback(.impact(.light), trigger: .tap)
        .successHaptic()
    }
}

// MARK: - Settings View
struct SettingsView: View {
    @EnvironmentObject private var hapticManager: HapticFeedbackManager
    @EnvironmentObject private var soundManager: SoundDesignManager
    @Environment(\.theme) private var theme
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                DynamicTypeText(
                    "Settings",
                    style: .display2,
                    fontTheme: .modern
                )
                .padding(.top, 20)
                
                // Haptics Settings
                SettingsSection(title: "Haptics") {
                    Toggle("Enable Haptics", isOn: $hapticManager.isHapticsEnabled)
                        .toggleStyle(SwitchToggleStyle(tint: theme.colors.primary))
                }
                
                // Sound Settings
                SettingsSection(title: "Sound") {
                    Toggle("Enable Sound", isOn: $soundManager.isSoundEnabled)
                        .toggleStyle(SwitchToggleStyle(tint: theme.colors.primary))
                    
                    HStack {
                        Text("Volume")
                        Slider(value: $soundManager.masterVolume, in: 0...1)
                            .accentColor(theme.colors.primary)
                    }
                }
                
                Spacer(minLength: 100)
            }
            .padding(.horizontal)
        }
        .background(Color.clear)
    }
}

// MARK: - Settings Section
struct SettingsSection<Content: View>: View {
    let title: String
    let content: Content
    @Environment(\.theme) private var theme
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .typography(.heading3, theme: .modern)
                .foregroundColor(theme.colors.onBackground)
            
            VStack(spacing: 12) {
                content
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(theme.colors.surface)
                    .glassmorphism(intensity: .light)
            )
        }
    }
}

// MARK: - Color Extension for Luminance
extension Color {
    var luminance: Double {
        let uiColor = UIColor(self)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        // Calculate relative luminance
        let r = red <= 0.03928 ? red / 12.92 : pow((red + 0.055) / 1.055, 2.4)
        let g = green <= 0.03928 ? green / 12.92 : pow((green + 0.055) / 1.055, 2.4)
        let b = blue <= 0.03928 ? blue / 12.92 : pow((blue + 0.055) / 1.055, 2.4)
        
        return 0.2126 * Double(r) + 0.7152 * Double(g) + 0.0722 * Double(b)
    }
}