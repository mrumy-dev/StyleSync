import SwiftUI

struct AnimatedTabBar: View {
    @Binding var selectedTab: Int
    let tabs: [TabItem]
    @State private var tabWidth: CGFloat = 0
    @State private var indicatorOffset: CGFloat = 0
    @Namespace private var animation

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(tabs.enumerated()), id: \.offset) { index, tab in
                TabBarButton(
                    tab: tab,
                    isSelected: selectedTab == index,
                    namespace: animation
                ) {
                    withAnimation(.interactiveSpring(response: 0.6, dampingFraction: 0.7)) {
                        selectedTab = index
                        HapticManager.HapticType.selection.trigger()
                        SoundManager.SoundType.tap.play(volume: 0.3)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 12)
        .background(
            GlassCardView(
                cornerRadius: 24,
                blurRadius: 20,
                opacity: 0.2,
                borderWidth: 1,
                shadowRadius: 12
            ) {
                Rectangle()
                    .fill(.clear)
                    .frame(height: 80)
            }
        )
        .overlay(
            // Floating indicator
            RoundedRectangle(cornerRadius: 20)
                .fill(DesignSystem.Colors.accent.gradient)
                .frame(width: tabWidth, height: 4)
                .offset(x: indicatorOffset)
                .animation(
                    .interactiveSpring(response: 0.6, dampingFraction: 0.8),
                    value: indicatorOffset
                ),
            alignment: .bottom
        )
        .onAppear {
            updateIndicator()
        }
        .onChange(of: selectedTab) { _ in
            updateIndicator()
        }
    }

    private func updateIndicator() {
        let totalWidth = UIScreen.main.bounds.width - 32
        tabWidth = totalWidth / CGFloat(tabs.count) - 16
        indicatorOffset = (CGFloat(selectedTab) - CGFloat(tabs.count - 1) / 2) * (tabWidth + 16)
    }
}

struct TabBarButton: View {
    let tab: TabItem
    let isSelected: Bool
    let namespace: Namespace.ID
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    if isSelected {
                        Circle()
                            .fill(DesignSystem.Colors.accent.opacity(0.2))
                            .frame(width: 48, height: 48)
                            .matchedGeometryEffect(id: "background", in: namespace)
                    }

                    Image(systemName: isSelected ? tab.selectedIcon : tab.icon)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundStyle(
                            isSelected
                                ? DesignSystem.Colors.accent
                                : DesignSystem.Colors.secondary
                        )
                        .scaleEffect(isSelected ? 1.1 : 1.0)
                        .animation(
                            .interactiveSpring(response: 0.4, dampingFraction: 0.6),
                            value: isSelected
                        )
                }

                Text(tab.title)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(
                        isSelected
                            ? DesignSystem.Colors.accent
                            : DesignSystem.Colors.secondary
                    )
                    .scaleEffect(isSelected ? 1.0 : 0.9)
                    .opacity(isSelected ? 1.0 : 0.7)
                    .animation(
                        .interactiveSpring(response: 0.5, dampingFraction: 0.7),
                        value: isSelected
                    )
            }
        }
        .buttonStyle(InteractiveButtonStyle())
    }
}

struct InteractiveButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .brightness(configuration.isPressed ? -0.1 : 0)
            .animation(
                .interactiveSpring(response: 0.3, dampingFraction: 0.6),
                value: configuration.isPressed
            )
    }
}

// MARK: - Floating Action Button

struct FloatingTabBarButton: View {
    let icon: String
    let action: () -> Void
    @State private var isPressed = false
    @State private var rotation: Double = 0

    var body: some View {
        Button(action: {
            withAnimation(.interactiveSpring(response: 0.4, dampingFraction: 0.6)) {
                rotation += 180
                HapticManager.HapticType.medium.trigger()
                SoundManager.SoundType.pop.play(volume: 0.5)
                action()
            }
        }) {
            ZStack {
                Circle()
                    .fill(DesignSystem.Colors.accent.gradient)
                    .frame(width: 56, height: 56)
                    .shadow(
                        color: DesignSystem.Colors.accent.opacity(0.3),
                        radius: 12,
                        y: 6
                    )

                Image(systemName: icon)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.white)
                    .rotationEffect(.degrees(rotation))
            }
        }
        .scaleEffect(isPressed ? 0.9 : 1.0)
        .animation(.interactiveSpring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        .onTapGesture {
            isPressed.toggle()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isPressed.toggle()
            }
        }
    }
}

// MARK: - Advanced Tab Bar with Morphing

struct MorphingTabBar: View {
    @Binding var selectedTab: Int
    let tabs: [TabItem]
    @State private var morphOffset: CGFloat = 0
    @State private var backgroundShape = RoundedRectangle(cornerRadius: 24)

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(tabs.enumerated()), id: \.offset) { index, tab in
                MorphingTabButton(
                    tab: tab,
                    isSelected: selectedTab == index,
                    progress: morphingProgress(for: index)
                ) {
                    withAnimation(.interactiveSpring(response: 0.7, dampingFraction: 0.8)) {
                        selectedTab = index
                        updateMorphing(for: index)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 16)
        .background(
            ZStack {
                // Dynamic background that morphs
                backgroundShape
                    .fill(.ultraThinMaterial)
                    .overlay(
                        backgroundShape
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.5),
                                        Color.white.opacity(0.1)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )

                // Morphing accent background
                Capsule()
                    .fill(DesignSystem.Colors.accent.opacity(0.1))
                    .frame(width: 80, height: 40)
                    .offset(x: morphOffset)
                    .animation(
                        .interactiveSpring(response: 0.6, dampingFraction: 0.8),
                        value: morphOffset
                    )
            }
        )
    }

    private func morphingProgress(for index: Int) -> Double {
        let distance = abs(CGFloat(index - selectedTab))
        return max(0, 1.0 - distance * 0.3)
    }

    private func updateMorphing(for index: Int) {
        let totalWidth = UIScreen.main.bounds.width - 48
        let buttonWidth = totalWidth / CGFloat(tabs.count)
        morphOffset = (CGFloat(index) - CGFloat(tabs.count - 1) / 2) * buttonWidth
    }
}

struct MorphingTabButton: View {
    let tab: TabItem
    let isSelected: Bool
    let progress: Double
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: isSelected ? tab.selectedIcon : tab.icon)
                    .font(.system(size: 20 + progress * 4, weight: .medium))
                    .foregroundStyle(
                        Color.primary.opacity(0.6 + progress * 0.4)
                    )
                    .scaleEffect(0.9 + progress * 0.2)

                if isSelected {
                    Text(tab.title)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.primary)
                        .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .animation(.interactiveSpring(response: 0.5, dampingFraction: 0.7), value: progress)
    }
}

// MARK: - Tab Item Model

struct TabItem {
    let title: String
    let icon: String
    let selectedIcon: String
    let tag: Int

    init(title: String, icon: String, selectedIcon: String? = nil, tag: Int) {
        self.title = title
        self.icon = icon
        self.selectedIcon = selectedIcon ?? "\(icon).fill"
        self.tag = tag
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        LinearGradient(
            colors: [Color.blue.opacity(0.2), Color.purple.opacity(0.2)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()

        VStack {
            Spacer()

            AnimatedTabBar(
                selectedTab: .constant(0),
                tabs: [
                    TabItem(title: "Home", icon: "house", tag: 0),
                    TabItem(title: "Style", icon: "sparkles", tag: 1),
                    TabItem(title: "Camera", icon: "camera", tag: 2),
                    TabItem(title: "Profile", icon: "person", tag: 3)
                ]
            )
            .padding()
        }
    }
}