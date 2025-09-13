import SwiftUI

// MARK: - Main Profile View
struct ProfileView: View {
    let profile: UserProfile
    let isCurrentUser: Bool
    @StateObject private var profileManager = ProfileManager.shared
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.theme) private var theme
    @State private var selectedLayout: ProfileLayout = .classic
    @State private var showingEditProfile = false
    @State private var showingSettings = false
    @State private var scrollOffset: CGFloat = 0

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                LazyVStack(spacing: 0) {
                    // Profile Header with animated picture
                    ProfileHeader(
                        profile: profile,
                        isCurrentUser: isCurrentUser,
                        geometry: geometry,
                        scrollOffset: scrollOffset
                    )
                    .onTapGesture {
                        if isCurrentUser {
                            showingEditProfile = true
                        }
                    }

                    // Statistics Dashboard
                    ProfileStatsView(profile: profile)
                        .padding(.horizontal)
                        .padding(.vertical, 16)

                    // Achievement Badges
                    if !profile.achievements.isEmpty {
                        AchievementBadgesView(achievements: profile.achievements)
                            .padding(.horizontal)
                            .padding(.bottom, 16)
                    }

                    // Style Mood Board (if available)
                    if let moodBoard = profile.styleMoodBoard {
                        StyleMoodBoardView(moodBoard: moodBoard)
                            .padding(.horizontal)
                            .padding(.bottom, 16)
                    }

                    // Outfit Calendar Toggle & Layout Selector
                    ProfileControlsView(
                        selectedLayout: $selectedLayout,
                        isCurrentUser: isCurrentUser
                    )
                    .padding(.horizontal)
                    .padding(.bottom, 16)

                    // Main Content Area with customizable layouts
                    ProfileContentView(
                        profile: profile,
                        layout: selectedLayout
                    )
                }
                .background(
                    GeometryReader { proxy in
                        Color.clear.onAppear {
                            scrollOffset = proxy.frame(in: .global).minY
                        }
                        .onChange(of: proxy.frame(in: .global).minY) { newValue in
                            scrollOffset = newValue
                        }
                    }
                )
            }
            .background(
                GradientMeshBackground(colors: theme.gradients.mesh)
                    .ignoresSafeArea()
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if isCurrentUser {
                        Button("Settings") {
                            showingSettings = true
                        }
                        .foregroundColor(theme.colors.primary)
                    } else {
                        ProfileActionButton(profile: profile)
                    }
                }
            }
        }
        .sheet(isPresented: $showingEditProfile) {
            EditProfileView(profile: profile)
        }
        .sheet(isPresented: $showingSettings) {
            ProfileSettingsView()
        }
    }
}

// MARK: - Profile Header with Animated Picture
struct ProfileHeader: View {
    let profile: UserProfile
    let isCurrentUser: Bool
    let geometry: GeometryProxy
    let scrollOffset: CGFloat
    @Environment(\.theme) private var theme
    @State private var isAnimatingAvatar = false
    @State private var showingFullScreenImage = false

    private var headerHeight: CGFloat { 280 }
    private var avatarSize: CGFloat { 120 }

    var body: some View {
        ZStack(alignment: .bottom) {
            // Cover Image with Parallax Effect
            CoverImageView(
                imageData: profile.coverImageData,
                height: headerHeight,
                parallaxOffset: scrollOffset * 0.5
            )

            // Gradient Overlay
            LinearGradient(
                colors: [
                    Color.black.opacity(0.3),
                    Color.black.opacity(0.6)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: headerHeight)

            // Profile Content
            VStack(spacing: 16) {
                // Animated Profile Picture
                AnimatedProfilePicture(
                    imageData: profile.profileImageData,
                    size: avatarSize,
                    verificationStatus: profile.verificationStatus,
                    isAnimating: $isAnimatingAvatar
                )
                .onTapGesture {
                    withAnimation(.bouncy) {
                        isAnimatingAvatar.toggle()
                    }
                    if !isCurrentUser {
                        showingFullScreenImage = true
                    }
                }
                .scaleEffect(isAnimatingAvatar ? 1.1 : 1.0)
                .animation(.bouncy, value: isAnimatingAvatar)

                // Name and Username
                VStack(spacing: 4) {
                    HStack(spacing: 8) {
                        DynamicTypeText(
                            profile.displayName,
                            style: .heading2,
                            fontTheme: .elegant
                        )
                        .foregroundColor(.white)

                        // Verification Badge
                        if profile.verificationStatus != .unverified {
                            Image(systemName: profile.verificationStatus.badgeIcon)
                                .foregroundColor(profile.verificationStatus.badgeColor)
                                .font(.title3)
                                .motion(.bounce(height: 2, speed: 1.0))
                        }
                    }

                    Text("@\(profile.username)")
                        .typography(.body1, theme: .system)
                        .foregroundColor(.white.opacity(0.8))
                }

                // Bio (if not empty)
                if !profile.bio.isEmpty {
                    Text(profile.bio)
                        .typography(.body2, theme: .system)
                        .foregroundColor(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .lineLimit(3)
                }
            }
            .padding(.bottom, 32)
        }
        .frame(height: headerHeight)
        .fullScreenCover(isPresented: $showingFullScreenImage) {
            FullScreenImageView(imageData: profile.profileImageData)
        }
    }
}

// MARK: - Animated Profile Picture
struct AnimatedProfilePicture: View {
    let imageData: Data?
    let size: CGFloat
    let verificationStatus: VerificationStatus
    @Binding var isAnimating: Bool
    @State private var rotationAngle: Double = 0
    @State private var showingHalo = false

    var body: some View {
        ZStack {
            // Animated Halo Effect
            if showingHalo {
                Circle()
                    .stroke(
                        RadialGradient(
                            colors: [
                                verificationStatus.badgeColor.opacity(0.6),
                                verificationStatus.badgeColor.opacity(0.2),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: size * 0.4,
                            endRadius: size * 0.8
                        ),
                        lineWidth: 4
                    )
                    .frame(width: size * 1.2, height: size * 1.2)
                    .rotationEffect(.degrees(rotationAngle))
                    .animation(.linear(duration: 3).repeatForever(autoreverses: false), value: rotationAngle)
            }

            // Profile Picture
            Group {
                if let imageData = imageData,
                   let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    // Default Avatar
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: size * 0.6))
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            .frame(width: size, height: size)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(Color.white, lineWidth: 4)
                    .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
            )

            // Verification Badge
            if verificationStatus != .unverified {
                Image(systemName: verificationStatus.badgeIcon)
                    .font(.system(size: size * 0.25, weight: .bold))
                    .foregroundColor(.white)
                    .background(
                        Circle()
                            .fill(verificationStatus.badgeColor)
                            .frame(width: size * 0.35, height: size * 0.35)
                    )
                    .offset(x: size * 0.3, y: size * 0.3)
            }
        }
        .onAppear {
            if verificationStatus != .unverified {
                showingHalo = true
                rotationAngle = 360
            }
        }
    }
}

// MARK: - Cover Image View
struct CoverImageView: View {
    let imageData: Data?
    let height: CGFloat
    let parallaxOffset: CGFloat
    @Environment(\.theme) private var theme

    var body: some View {
        Group {
            if let imageData = imageData,
               let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                // Default Cover with Gradient
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                theme.colors.primary,
                                theme.colors.secondary,
                                theme.colors.accent1
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
        }
        .frame(height: height)
        .offset(y: parallaxOffset)
        .clipped()
    }
}

// MARK: - Profile Statistics View
struct ProfileStatsView: View {
    let profile: UserProfile
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: 0) {
            StatItemView(
                title: "Posts",
                value: "\(profile.postCount)",
                isLarge: true
            )

            Divider()
                .frame(height: 40)
                .background(theme.colors.outline.opacity(0.3))

            StatItemView(
                title: "Followers",
                value: formatCount(profile.followerCount),
                isLarge: true
            )

            Divider()
                .frame(height: 40)
                .background(theme.colors.outline.opacity(0.3))

            StatItemView(
                title: "Following",
                value: formatCount(profile.followingCount),
                isLarge: true
            )
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(theme.colors.surface)
                .glassmorphism(intensity: .medium)
        )
    }

    private func formatCount(_ count: Int) -> String {
        if count >= 1000000 {
            return String(format: "%.1fM", Double(count) / 1000000.0)
        } else if count >= 1000 {
            return String(format: "%.1fK", Double(count) / 1000.0)
        } else {
            return "\(count)"
        }
    }
}

// MARK: - Stat Item View
struct StatItemView: View {
    let title: String
    let value: String
    let isLarge: Bool
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .typography(isLarge ? .heading2 : .heading3, theme: .modern)
                .foregroundColor(theme.colors.onSurface)
                .motion(.pulse(scale: 1.05, speed: 2.0))

            Text(title)
                .typography(.caption1, theme: .system)
                .foregroundColor(theme.colors.onSurfaceVariant)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Achievement Badges View
struct AchievementBadgesView: View {
    let achievements: [Achievement]
    @Environment(\.theme) private var theme
    @State private var showingAllAchievements = false

    var displayedAchievements: [Achievement] {
        Array(achievements.prefix(6))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Achievements")
                    .typography(.heading3, theme: .modern)
                    .foregroundColor(theme.colors.onBackground)

                Spacer()

                if achievements.count > 6 {
                    Button("View All") {
                        showingAllAchievements = true
                    }
                    .foregroundColor(theme.colors.primary)
                    .typography(.body2, theme: .system)
                }
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6), spacing: 8) {
                ForEach(displayedAchievements) { achievement in
                    AchievementBadge(achievement: achievement)
                }

                if achievements.count > 6 {
                    Button(action: { showingAllAchievements = true }) {
                        VStack(spacing: 4) {
                            Image(systemName: "ellipsis")
                                .font(.title2)
                                .foregroundColor(theme.colors.onSurfaceVariant)

                            Text("+\(achievements.count - 6)")
                                .typography(.caption2, theme: .system)
                                .foregroundColor(theme.colors.onSurfaceVariant)
                        }
                        .frame(width: 44, height: 44)
                        .background(
                            Circle()
                                .fill(theme.colors.surfaceVariant)
                        )
                    }
                }
            }
        }
        .sheet(isPresented: $showingAllAchievements) {
            AllAchievementsView(achievements: achievements)
        }
    }
}

// MARK: - Achievement Badge
struct AchievementBadge: View {
    let achievement: Achievement
    @Environment(\.theme) private var theme
    @State private var isGlowing = false

    var body: some View {
        Button {
            // Show achievement details
        } label: {
            Image(systemName: achievement.iconName)
                .font(.title2)
                .foregroundColor(rarityColor)
                .frame(width: 44, height: 44)
                .background(
                    Circle()
                        .fill(rarityColor.opacity(0.2))
                        .overlay(
                            Circle()
                                .stroke(rarityColor, lineWidth: 2)
                        )
                )
                .scaleEffect(isGlowing ? 1.1 : 1.0)
                .shadow(color: rarityColor.opacity(0.5), radius: isGlowing ? 8 : 0)
        }
        .onAppear {
            if achievement.rarity == .legendary || achievement.rarity == .epic {
                withAnimation(.easeInOut(duration: 1.5).repeatForever()) {
                    isGlowing = true
                }
            }
        }
    }

    private var rarityColor: Color {
        switch achievement.rarity {
        case .common: return theme.colors.onSurfaceVariant
        case .uncommon: return .green
        case .rare: return .blue
        case .epic: return .purple
        case .legendary: return .orange
        }
    }
}

// MARK: - Style Mood Board View
struct StyleMoodBoardView: View {
    let moodBoard: StyleMoodBoard
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Style DNA")
                .typography(.heading3, theme: .modern)
                .foregroundColor(theme.colors.onBackground)

            VStack(spacing: 12) {
                // Color Palette
                if !moodBoard.colors.isEmpty {
                    StyleColorPalette(colors: moodBoard.colors)
                }

                // Style Tags
                if !moodBoard.styles.isEmpty {
                    StyleTagsView(styles: moodBoard.styles)
                }

                // Style Personality & Season
                HStack(spacing: 16) {
                    if let personality = moodBoard.stylePersonality {
                        StyleInfoCard(
                            title: "Style",
                            value: personality.rawValue.capitalized,
                            icon: "person.crop.artframe"
                        )
                    }

                    if let season = moodBoard.colorSeason {
                        StyleInfoCard(
                            title: "Season",
                            value: season.rawValue.capitalized,
                            icon: "leaf.circle"
                        )
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(theme.colors.surface)
                    .glassmorphism(intensity: .light)
            )
        }
    }
}

// MARK: - Full Screen Image View
struct FullScreenImageView: View {
    let imageData: Data?
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let imageData = imageData,
               let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .onTapGesture {
                        presentationMode.wrappedValue.dismiss()
                    }
            }

            VStack {
                HStack {
                    Spacer()
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(.white)
                    .padding()
                }
                Spacer()
            }
        }
    }
}