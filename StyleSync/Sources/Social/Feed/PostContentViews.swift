import SwiftUI
import AVKit

// MARK: - Photo Post Content
struct PhotoPostContentView: View {
    let photoPost: PhotoPost
    @State private var currentImageIndex = 0
    @Environment(\.theme) private var theme

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            // Image Carousel
            TabView(selection: $currentImageIndex) {
                ForEach(0..<photoPost.imageData.count, id: \.self) { index in
                    if let uiImage = UIImage(data: photoPost.imageData[index]) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(photoPost.aspectRatio, contentMode: .fill)
                            .clipped()
                            .tag(index)
                    }
                }
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            .aspectRatio(photoPost.aspectRatio, contentMode: .fit)

            // Page Indicator (if multiple images)
            if photoPost.imageData.count > 1 {
                HStack(spacing: 6) {
                    ForEach(0..<photoPost.imageData.count, id: \.self) { index in
                        Circle()
                            .fill(index == currentImageIndex ? Color.white : Color.white.opacity(0.5))
                            .frame(width: 8, height: 8)
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.black.opacity(0.3))
                )
                .padding(.trailing, 16)
                .padding(.bottom, 16)
            }
        }
    }
}

// MARK: - Video Post Content
struct VideoPostContentView: View {
    let videoPost: VideoPost
    @State private var player: AVPlayer?
    @State private var isPlaying = false
    @Environment(\.theme) private var theme

    var body: some View {
        ZStack {
            // Video Player
            if let player = player {
                VideoPlayer(player: player)
                    .aspectRatio(16/9, contentMode: .fit)
                    .onAppear {
                        player.play()
                        isPlaying = true
                    }
                    .onDisappear {
                        player.pause()
                        isPlaying = false
                    }
            } else {
                // Thumbnail with play button
                ZStack {
                    if let thumbnailImage = UIImage(data: videoPost.thumbnailData) {
                        Image(uiImage: thumbnailImage)
                            .resizable()
                            .aspectRatio(16/9, contentMode: .fill)
                            .clipped()
                    }

                    Button {
                        setupPlayer()
                    } label: {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.white)
                            .background(
                                Circle()
                                    .fill(Color.black.opacity(0.3))
                                    .frame(width: 80, height: 80)
                            )
                    }
                }
                .aspectRatio(16/9, contentMode: .fit)
            }

            // Duration Badge
            VStack {
                HStack {
                    Spacer()
                    Text(formatDuration(videoPost.duration))
                        .typography(.caption2, theme: .system)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.black.opacity(0.6))
                        )
                        .padding(.trailing, 12)
                        .padding(.top, 12)
                }
                Spacer()
            }

            // Video Effects Indicator
            if !videoPost.effects.isEmpty {
                VStack {
                    Spacer()
                    HStack {
                        ForEach(videoPost.effects.prefix(3), id: \.self) { effect in
                            VideoEffectBadge(effect: effect)
                        }
                        Spacer()
                    }
                    .padding(.leading, 12)
                    .padding(.bottom, 12)
                }
            }
        }
    }

    private func setupPlayer() {
        player = AVPlayer(url: videoPost.videoURL)
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Outfit Post Content
struct OutfitPostContentView: View {
    let outfitPost: OutfitPost
    @State private var showingShoppableLinks = false
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: 0) {
            // Main outfit display would go here
            Rectangle()
                .fill(theme.colors.surfaceVariant)
                .aspectRatio(4/5, contentMode: .fit)
                .overlay(
                    VStack(spacing: 16) {
                        Image(systemName: "tshirt.fill")
                            .font(.system(size: 60))
                            .foregroundColor(theme.colors.onSurfaceVariant)

                        VStack(spacing: 4) {
                            Text(outfitPost.style.rawValue.capitalized)
                                .typography(.heading3, theme: .modern)
                                .foregroundColor(theme.colors.onSurface)

                            Text("for \(outfitPost.occasion)")
                                .typography(.body2, theme: .system)
                                .foregroundColor(theme.colors.onSurfaceVariant)
                        }
                    }
                )

            // Outfit Details Bar
            HStack {
                // Season
                OutfitDetailChip(
                    icon: "leaf.circle",
                    text: outfitPost.season.rawValue.capitalized,
                    color: seasonColor(outfitPost.season)
                )

                // Confidence Score
                OutfitDetailChip(
                    icon: "star.fill",
                    text: "\(Int(outfitPost.confidence * 100))%",
                    color: confidenceColor(outfitPost.confidence)
                )

                Spacer()

                // Shoppable Link Button
                if !outfitPost.shoppableLinks.isEmpty {
                    Button {
                        showingShoppableLinks = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "bag.fill")
                                .font(.caption)
                            Text("Shop")
                                .typography(.caption1, theme: .system)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(theme.colors.primary)
                        )
                    }
                }
            }
            .padding(12)
            .background(theme.colors.surface.opacity(0.9))
        }
        .cornerRadius(12)
        .sheet(isPresented: $showingShoppableLinks) {
            ShoppableLinksView(links: outfitPost.shoppableLinks)
        }
    }

    private func seasonColor(_ season: Season) -> Color {
        switch season {
        case .spring: return .green
        case .summer: return .yellow
        case .fall: return .orange
        case .winter: return .blue
        case .allSeason: return .gray
        }
    }

    private func confidenceColor(_ confidence: Float) -> Color {
        if confidence >= 0.8 { return .green }
        else if confidence >= 0.6 { return .yellow }
        else { return .orange }
    }
}

// MARK: - Reel Post Content
struct ReelPostContentView: View {
    let reelPost: ReelPost
    @State private var player: AVPlayer?
    @State private var isPlaying = false
    @Environment(\.theme) private var theme

    var body: some View {
        ZStack {
            // Video Player
            if let player = player {
                VideoPlayer(player: player)
                    .aspectRatio(9/16, contentMode: .fit)
                    .clipped()
            } else {
                Rectangle()
                    .fill(theme.colors.surfaceVariant)
                    .aspectRatio(9/16, contentMode: .fit)
                    .overlay(
                        Button {
                            setupPlayer()
                        } label: {
                            Image(systemName: "play.circle.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.white)
                        }
                    )
            }

            // Reel Overlays
            VStack {
                Spacer()

                // Music Info
                if let music = reelPost.music {
                    HStack {
                        Image(systemName: "music.note")
                            .font(.caption)

                        Text("\(music.artist) - \(music.title)")
                            .typography(.caption2, theme: .system)
                            .lineLimit(1)

                        Spacer()
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.black.opacity(0.6))
                    )
                    .padding(.leading, 12)
                    .padding(.bottom, 12)
                }
            }

            // Trending Badge
            if reelPost.trending {
                VStack {
                    HStack {
                        Spacer()
                        HStack(spacing: 4) {
                            Image(systemName: "flame.fill")
                                .font(.caption)
                            Text("Trending")
                                .typography(.caption2, theme: .system)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.red.opacity(0.8))
                        )
                        .padding(.trailing, 12)
                        .padding(.top, 12)
                    }
                    Spacer()
                }
            }
        }
    }

    private func setupPlayer() {
        player = AVPlayer(url: reelPost.videoURL)
        player?.play()
        isPlaying = true
    }
}

// MARK: - Transformation Post Content
struct TransformationPostContentView: View {
    let transformationPost: TransformationPost
    @State private var showingBefore = true
    @State private var sliderPosition: Double = 0.5
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: 0) {
            // Before/After Comparison
            ZStack {
                // Before Images
                TabView {
                    ForEach(0..<transformationPost.beforeImages.count, id: \.self) { index in
                        if let image = UIImage(data: transformationPost.beforeImages[index]) {
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        }
                    }
                }
                .tabViewStyle(PageTabViewStyle())
                .frame(height: 300)
                .clipped()
                .opacity(showingBefore ? 1.0 : 0.0)

                // After Images
                TabView {
                    ForEach(0..<transformationPost.afterImages.count, id: \.self) { index in
                        if let image = UIImage(data: transformationPost.afterImages[index]) {
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        }
                    }
                }
                .tabViewStyle(PageTabViewStyle())
                .frame(height: 300)
                .clipped()
                .opacity(showingBefore ? 0.0 : 1.0)

                // Comparison Slider
                VStack {
                    Spacer()

                    HStack {
                        Text("BEFORE")
                            .typography(.caption1, theme: .system)
                            .foregroundColor(.white)
                            .opacity(showingBefore ? 1.0 : 0.6)

                        Slider(value: $sliderPosition, in: 0...1)
                            .accentColor(.white)
                            .onChange(of: sliderPosition) { value in
                                showingBefore = value < 0.5
                            }

                        Text("AFTER")
                            .typography(.caption1, theme: .system)
                            .foregroundColor(.white)
                            .opacity(showingBefore ? 0.6 : 1.0)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                    .background(
                        LinearGradient(
                            colors: [Color.clear, Color.black.opacity(0.6)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }
            }

            // Transformation Details
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    TransformationTypeChip(type: transformationPost.transformationType)

                    Spacer()

                    Text(transformationPost.timespan)
                        .typography(.caption1, theme: .system)
                        .foregroundColor(theme.colors.onSurfaceVariant)
                }

                if !transformationPost.tips.isEmpty {
                    Text(transformationPost.tips.first ?? "")
                        .typography(.body2, theme: .system)
                        .foregroundColor(theme.colors.onSurface)
                        .lineLimit(2)
                }
            }
            .padding(12)
            .background(theme.colors.surface.opacity(0.9))
        }
        .cornerRadius(12)
        .animation(.easeInOut(duration: 0.3), value: showingBefore)
    }
}

// MARK: - Challenge Post Content
struct ChallengePostContentView: View {
    let challengePost: ChallengePost
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: 0) {
            // Challenge Header
            VStack(spacing: 12) {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.gold)

                Text(challengePost.challengeName)
                    .typography(.heading3, theme: .modern)
                    .foregroundColor(theme.colors.onSurface)
                    .multilineTextAlignment(.center)

                HStack {
                    ChallengeDifficultyBadge(difficulty: challengePost.participationData.difficulty)

                    Spacer()

                    Text("\(challengePost.participationData.participantCount) participants")
                        .typography(.caption1, theme: .system)
                        .foregroundColor(theme.colors.onSurfaceVariant)
                }
            }
            .padding(16)
            .background(
                LinearGradient(
                    colors: [theme.colors.accent1.opacity(0.2), theme.colors.accent2.opacity(0.2)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )

            // Participation Button
            Button("Join Challenge") {
                // Handle challenge participation
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(theme.colors.primary)
        }
        .cornerRadius(12)
    }
}

// MARK: - Poll Post Content
struct PollPostContentView: View {
    let pollPost: PollPost
    @State private var selectedOptions: Set<UUID> = []
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(pollPost.question)
                .typography(.heading4, theme: .modern)
                .foregroundColor(theme.colors.onSurface)
                .multilineTextAlignment(.leading)

            VStack(spacing: 8) {
                ForEach(pollPost.options) { option in
                    PollOptionView(
                        option: option,
                        totalVotes: pollPost.totalVotes,
                        isSelected: selectedOptions.contains(option.id),
                        allowMultiple: pollPost.allowMultipleChoices
                    ) {
                        toggleOptionSelection(option.id)
                    }
                }
            }

            HStack {
                Text("\(pollPost.totalVotes) votes")
                    .typography(.caption1, theme: .system)
                    .foregroundColor(theme.colors.onSurfaceVariant)

                Spacer()

                if let expiresAt = pollPost.expiresAt {
                    Text("Ends \(formatExpirationDate(expiresAt))")
                        .typography(.caption1, theme: .system)
                        .foregroundColor(theme.colors.onSurfaceVariant)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(theme.colors.surface)
        )
    }

    private func toggleOptionSelection(_ optionId: UUID) {
        if pollPost.allowMultipleChoices {
            if selectedOptions.contains(optionId) {
                selectedOptions.remove(optionId)
            } else {
                selectedOptions.insert(optionId)
            }
        } else {
            selectedOptions = [optionId]
        }
    }

    private func formatExpirationDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Collaboration Post Content
struct CollaborationPostContentView: View {
    let collaborationPost: CollaborationPost
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "person.2.fill")
                    .font(.title2)
                    .foregroundColor(theme.colors.primary)

                Text("Collaboration")
                    .typography(.heading4, theme: .modern)
                    .foregroundColor(theme.colors.onSurface)

                Spacer()

                CollaborationTypeBadge(type: collaborationPost.contributionType)
            }

            HStack {
                Text("with")
                    .typography(.body2, theme: .system)
                    .foregroundColor(theme.colors.onSurfaceVariant)

                Text(collaborationPost.collaborators.prefix(2).joined(separator: ", "))
                    .typography(.body2, theme: .system)
                    .foregroundColor(theme.colors.primary)

                if collaborationPost.collaborators.count > 2 {
                    Text("and \(collaborationPost.collaborators.count - 2) others")
                        .typography(.body2, theme: .system)
                        .foregroundColor(theme.colors.onSurfaceVariant)
                }

                Spacer()
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .stroke(theme.colors.primary.opacity(0.3), lineWidth: 2)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(theme.colors.primary.opacity(0.05))
                )
        )
    }
}

// MARK: - Default Post Content
struct DefaultPostContentView: View {
    let post: SocialPost
    @Environment(\.theme) private var theme

    var body: some View {
        Rectangle()
            .fill(theme.colors.surfaceVariant)
            .aspectRatio(1, contentMode: .fit)
            .overlay(
                VStack {
                    Image(systemName: "photo")
                        .font(.system(size: 40))
                        .foregroundColor(theme.colors.onSurfaceVariant)

                    Text("Content not available")
                        .typography(.body2, theme: .system)
                        .foregroundColor(theme.colors.onSurfaceVariant)
                }
            )
    }
}

// MARK: - Supporting Components
struct OutfitDetailChip: View {
    let icon: String
    let text: String
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
            Text(text)
                .typography(.caption1, theme: .system)
        }
        .foregroundColor(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(color.opacity(0.8))
        )
    }
}

struct VideoEffectBadge: View {
    let effect: VideoEffect

    var body: some View {
        Text(effect.rawValue.replacingOccurrences(of: "_", with: " ").capitalized)
            .typography(.caption2, theme: .system)
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.black.opacity(0.6))
            )
    }
}

struct TransformationTypeChip: View {
    let type: TransformationType

    var body: some View {
        Text(type.rawValue.replacingOccurrences(of: "_", with: " ").capitalized)
            .typography(.caption1, theme: .system)
            .foregroundColor(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(transformationColor)
            )
    }

    private var transformationColor: Color {
        switch type {
        case .weightLoss, .fitImprovement: return .green
        case .styleEvolution, .wardrobeOverhaul: return .purple
        case .confidenceJourney: return .pink
        case .colorExperiment: return .orange
        default: return .blue
        }
    }
}

struct ChallengeDifficultyBadge: View {
    let difficulty: ChallengeDifficulty

    var body: some View {
        Text(difficulty.rawValue.capitalized)
            .typography(.caption1, theme: .system)
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(difficultyColor)
            )
    }

    private var difficultyColor: Color {
        switch difficulty {
        case .beginner: return .green
        case .intermediate: return .orange
        case .advanced: return .red
        case .expert: return .purple
        }
    }
}

struct PollOptionView: View {
    let option: PollOption
    let totalVotes: Int
    let isSelected: Bool
    let allowMultiple: Bool
    let onTap: () -> Void
    @Environment(\.theme) private var theme

    private var percentage: Double {
        guard totalVotes > 0 else { return 0 }
        return Double(option.voteCount) / Double(totalVotes)
    }

    var body: some View {
        Button(action: onTap) {
            HStack {
                if allowMultiple {
                    Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                        .foregroundColor(isSelected ? theme.colors.primary : theme.colors.onSurfaceVariant)
                } else {
                    Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                        .foregroundColor(isSelected ? theme.colors.primary : theme.colors.onSurfaceVariant)
                }

                Text(option.text)
                    .typography(.body2, theme: .system)
                    .foregroundColor(theme.colors.onSurface)

                Spacer()

                Text("\(Int(percentage * 100))%")
                    .typography(.caption1, theme: .system)
                    .foregroundColor(theme.colors.onSurfaceVariant)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(theme.colors.surfaceVariant)

                    RoundedRectangle(cornerRadius: 8)
                        .fill(theme.colors.primary.opacity(0.3))
                        .scaleEffect(x: percentage, y: 1, anchor: .leading)
                        .animation(.easeOut(duration: 0.5), value: percentage)
                }
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct CollaborationTypeBadge: View {
    let type: CollaborationType

    var body: some View {
        Text(type.rawValue.replacingOccurrences(of: "_", with: " ").capitalized)
            .typography(.caption1, theme: .system)
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.purple.opacity(0.8))
            )
    }
}

// MARK: - Sheet Views (Placeholders)
struct ShoppableLinksView: View {
    let links: [ShoppableLink]

    var body: some View {
        NavigationView {
            Text("Shoppable Links")
                .navigationTitle("Shop This Look")
        }
    }
}

// MARK: - Extensions
extension Color {
    static let gold = Color(red: 1.0, green: 0.8, blue: 0.0)
}

// MARK: - Shimmer Effect
extension View {
    func shimmer() -> some View {
        self.modifier(ShimmerModifier())
    }
}

struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .overlay(
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.clear,
                                Color.white.opacity(0.3),
                                Color.clear
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .rotationEffect(.degrees(30))
                    .offset(x: phase)
                    .onAppear {
                        withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                            phase = 400
                        }
                    }
            )
            .clipped()
    }
}