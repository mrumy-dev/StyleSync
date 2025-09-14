import SwiftUI

struct GlassCardView<Content: View>: View {
    let content: Content
    let cornerRadius: CGFloat
    let blurRadius: CGFloat
    let opacity: Double
    let borderWidth: CGFloat
    let shadowRadius: CGFloat

    init(
        cornerRadius: CGFloat = 20,
        blurRadius: CGFloat = 20,
        opacity: Double = 0.15,
        borderWidth: CGFloat = 1.5,
        shadowRadius: CGFloat = 10,
        @ViewBuilder content: () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.blurRadius = blurRadius
        self.opacity = opacity
        self.borderWidth = borderWidth
        self.shadowRadius = shadowRadius
        self.content = content()
    }

    var body: some View {
        content
            .background(
                ZStack {
                    // Glass background with blur
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(.ultraThinMaterial)
                        .opacity(opacity)

                    // Gradient overlay for depth
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.3),
                                    Color.white.opacity(0.1),
                                    Color.clear,
                                    Color.black.opacity(0.05)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    // Border with subtle gradient
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.6),
                                    Color.white.opacity(0.2),
                                    Color.clear,
                                    Color.black.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: borderWidth
                        )
                }
            )
            .shadow(
                color: Color.black.opacity(0.1),
                radius: shadowRadius,
                x: 0,
                y: shadowRadius / 2
            )
            .shadow(
                color: Color.black.opacity(0.05),
                radius: shadowRadius * 2,
                x: 0,
                y: shadowRadius
            )
    }
}

// MARK: - Glass Card Variants

struct GlassMorphicButton<Label: View>: View {
    let action: () -> Void
    let label: Label
    @State private var isPressed = false

    init(action: @escaping () -> Void, @ViewBuilder label: () -> Label) {
        self.action = action
        self.label = label()
    }

    var body: some View {
        Button(action: action) {
            label
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
        }
        .buttonStyle(GlassMorphicButtonStyle())
    }
}

struct GlassMorphicButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        GlassCardView(
            cornerRadius: 16,
            blurRadius: 15,
            opacity: configuration.isPressed ? 0.25 : 0.15,
            borderWidth: configuration.isPressed ? 2 : 1.5,
            shadowRadius: configuration.isPressed ? 5 : 8
        ) {
            configuration.label
                .font(DesignSystem.Typography.bodyMedium)
                .foregroundStyle(.primary)
        }
        .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
        .brightness(configuration.isPressed ? 0.1 : 0)
        .animation(
            .interactiveSpring(response: 0.4, dampingFraction: 0.6),
            value: configuration.isPressed
        )
        .onTapGesture {
            HapticManager.HapticType.light.trigger()
        }
    }
}

// MARK: - Glass Navigation Bar

struct GlassNavigationBar<Leading: View, Center: View, Trailing: View>: View {
    let leading: Leading
    let center: Center
    let trailing: Trailing

    init(
        @ViewBuilder leading: () -> Leading,
        @ViewBuilder center: () -> Center,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.leading = leading()
        self.center = center()
        self.trailing = trailing()
    }

    var body: some View {
        HStack {
            leading
                .frame(maxWidth: .infinity, alignment: .leading)

            center
                .frame(maxWidth: .infinity, alignment: .center)

            trailing
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            GlassCardView(
                cornerRadius: 0,
                blurRadius: 25,
                opacity: 0.8,
                borderWidth: 0,
                shadowRadius: 0
            ) {
                Rectangle()
                    .fill(.clear)
            }
            .overlay(
                Rectangle()
                    .fill(Color.black.opacity(0.1))
                    .frame(height: 0.5),
                alignment: .bottom
            )
        )
    }
}

// MARK: - Glass Input Field

struct GlassInputField: View {
    @Binding var text: String
    let placeholder: String
    let icon: String?
    @FocusState private var isFocused: Bool

    init(_ placeholder: String, text: Binding<String>, icon: String? = nil) {
        self.placeholder = placeholder
        self._text = text
        self.icon = icon
    }

    var body: some View {
        HStack(spacing: 12) {
            if let icon = icon {
                Image(systemName: icon)
                    .foregroundStyle(.secondary)
                    .font(.system(size: 16, weight: .medium))
            }

            TextField(placeholder, text: $text)
                .font(DesignSystem.Typography.body)
                .focused($isFocused)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            GlassCardView(
                cornerRadius: 14,
                blurRadius: 12,
                opacity: isFocused ? 0.25 : 0.15,
                borderWidth: isFocused ? 2 : 1,
                shadowRadius: isFocused ? 12 : 6
            ) {
                Rectangle()
                    .fill(.clear)
            }
        )
        .animation(
            .interactiveSpring(response: 0.3, dampingFraction: 0.7),
            value: isFocused
        )
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        LinearGradient(
            colors: [Color.blue.opacity(0.3), Color.purple.opacity(0.3)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()

        VStack(spacing: 30) {
            GlassCardView {
                VStack(spacing: 16) {
                    Text("Glassmorphism Card")
                        .font(.title2.weight(.semibold))

                    Text("Beautiful glass effect with blur and transparency")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(24)
            }

            GlassMorphicButton(action: {}) {
                Text("Glass Button")
            }

            GlassInputField("Enter text", text: .constant(""), icon: "magnifyingglass")
        }
        .padding()
    }
}