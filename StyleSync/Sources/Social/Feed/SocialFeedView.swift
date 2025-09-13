import SwiftUI

// MARK: - Main Social Feed View
struct SocialFeedView: View {
    @StateObject private var feedManager = FeedManager.shared
    @StateObject private var storyManager = StoryManager.shared
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.theme) private var theme
    @State private var selectedFeedType: FeedType = .following
    @State private var showingCamera = false
    @State private var showingStoryCreator = false
    @State private var scrollOffset: CGFloat = 0

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                LazyVStack(spacing: 0) {
                    // Stories Bar
                    if !storyManager.stories.isEmpty {
                        StoriesBarView(
                            stories: storyManager.stories,
                            onAddStory: {
                                showingStoryCreator = true
                            }
                        )
                        .padding(.top, 8)
                    }

                    // Feed Type Selector
                    FeedTypeSelectorView(selectedType: $selectedFeedType)
                        .padding(.horizontal)
                        .padding(.vertical, 8)

                    // Main Feed Content
                    FeedContentView(
                        feedType: selectedFeedType,
                        posts: feedManager.currentPosts,
                        isLoading: feedManager.isLoading
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
            .refreshable {
                await feedManager.refreshFeed(type: selectedFeedType)
            }
            .background(
                GradientMeshBackground(colors: theme.gradients.mesh)
                    .ignoresSafeArea()
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Text("StyleSync")
                        .typography(.heading3, theme: .elegant)
                        .foregroundColor(theme.colors.primary)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        Button {
                            showingCamera = true
                        } label: {
                            Image(systemName: "camera")
                                .font(.title2)
                                .foregroundColor(theme.colors.onSurface)
                        }

                        NavigationLink(destination: NotificationsView()) {
                            Image(systemName: "heart")
                                .font(.title2)
                                .foregroundColor(theme.colors.onSurface)
                        }

                        NavigationLink(destination: DirectMessagesView()) {
                            Image(systemName: "paperplane")
                                .font(.title2)
                                .foregroundColor(theme.colors.onSurface)
                        }
                    }
                }
            }
        }
        .onAppear {
            feedManager.loadFeed(type: selectedFeedType)
            storyManager.loadStories()
        }
        .onChange(of: selectedFeedType) { newType in
            feedManager.loadFeed(type: newType)
        }
        .sheet(isPresented: $showingCamera) {
            CameraView()
        }
        .sheet(isPresented: $showingStoryCreator) {
            StoryCreatorView()
        }
    }
}

// MARK: - Feed Type Selector
enum FeedType: String, CaseIterable {
    case following = "following"
    case discover = "discover"
    case trending = "trending"
    case local = "local"

    var displayName: String {
        switch self {
        case .following: return "Following"
        case .discover: return "Discover"
        case .trending: return "Trending"
        case .local: return "Local"
        }
    }

    var icon: String {
        switch self {
        case .following: return "person.2.fill"
        case .discover: return "safari"
        case .trending: return "flame.fill"
        case .local: return "location.fill"
        }
    }
}

struct FeedTypeSelectorView: View {
    @Binding var selectedType: FeedType
    @Environment(\.theme) private var theme

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(FeedType.allCases, id: \.self) { type in
                    FeedTypeButton(
                        type: type,
                        isSelected: selectedType == type
                    ) {
                        withAnimation(.snappySpring) {
                            selectedType = type
                        }
                    }
                }
            }
            .padding(.horizontal, 4)
        }
    }
}

struct FeedTypeButton: View {
    let type: FeedType
    let isSelected: Bool
    let action: () -> Void
    @Environment(\.theme) private var theme

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: type.icon)
                    .font(.system(size: 14, weight: .medium))

                Text(type.displayName)
                    .typography(.body2, theme: .system)
            }
            .foregroundColor(isSelected ? .white : theme.colors.onSurfaceVariant)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(isSelected ? theme.colors.primary : theme.colors.surfaceVariant)
            )
            .scaleEffect(isSelected ? 1.05 : 1.0)
        }
        .animation(.snappySpring, value: isSelected)
    }
}

// MARK: - Stories Bar
struct StoriesBarView: View {
    let stories: [StoryPost]
    let onAddStory: () -> Void
    @Environment(\.theme) private var theme

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                // Add Story Button
                AddStoryButton(onTap: onAddStory)

                // Story Items
                ForEach(stories.prefix(20), id: \.id) { story in
                    StoryItemView(story: story)
                }
            }
            .padding(.horizontal)
        }
    }
}

struct AddStoryButton: View {
    let onTap: () -> Void
    @Environment(\.theme) private var theme
    @StateObject private var profileManager = ProfileManager.shared

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(theme.colors.surfaceVariant)
                        .frame(width: 64, height: 64)

                    if let profile = profileManager.currentProfile,
                       let imageData = profile.profileImageData,
                       let uiImage = UIImage(data: imageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 60, height: 60)
                            .clipShape(Circle())
                    } else {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(theme.colors.onSurfaceVariant)
                    }

                    // Plus Icon
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(theme.colors.primary)
                        .background(Circle().fill(Color.white))
                        .offset(x: 20, y: 20)
                }

                Text("Your Story")
                    .typography(.caption2, theme: .system)
                    .foregroundColor(theme.colors.onSurfaceVariant)
            }
        }
    }
}

struct StoryItemView: View {
    let story: StoryPost
    @State private var showingStory = false
    @Environment(\.theme) private var theme

    var body: some View {
        Button {
            showingStory = true
        } label: {
            VStack(spacing: 6) {
                ZStack {
                    // Gradient Ring
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [theme.colors.primary, theme.colors.accent1],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 3
                        )
                        .frame(width: 68, height: 68)

                    // Story Preview
                    StoryPreviewView(story: story)
                        .frame(width: 64, height: 64)
                        .clipShape(Circle())
                }

                Text("Username") // Would get from story author
                    .typography(.caption2, theme: .system)
                    .foregroundColor(theme.colors.onSurfaceVariant)
                    .lineLimit(1)
            }
        }
        .fullScreenCover(isPresented: $showingStory) {
            StoryViewerView(story: story)
        }
    }
}

struct StoryPreviewView: View {
    let story: StoryPost
    @Environment(\.theme) private var theme

    var body: some View {
        ZStack {
            // Background
            Rectangle()
                .fill(story.backgroundColor.color)

            // Content preview based on story content type
            switch story.content {
            case .photo(let imageData):
                if let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                }

            case .text(let storyText):
                Text(storyText.text)
                    .typography(.caption1, theme: .system)
                    .foregroundColor(storyText.color.color)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)

            case .video(_):
                Image(systemName: "play.circle.fill")
                    .font(.title)
                    .foregroundColor(.white)

            default:
                Image(systemName: "photo")
                    .font(.title2)
                    .foregroundColor(theme.colors.onSurfaceVariant)
            }
        }
    }
}

// MARK: - Feed Content View
struct FeedContentView: View {
    let feedType: FeedType
    let posts: [SocialPost]
    let isLoading: Bool
    @Environment(\.theme) private var theme

    var body: some View {
        if isLoading && posts.isEmpty {
            FeedLoadingView()
        } else if posts.isEmpty {
            EmptyFeedView(feedType: feedType)
        } else {
            LazyVStack(spacing: 16) {
                ForEach(posts) { post in
                    FeedPostView(post: post)
                        .padding(.horizontal)
                }

                if isLoading {
                    FeedLoadingIndicator()
                        .padding()
                }
            }
            .padding(.vertical)
        }
    }
}

// MARK: - Feed Post View
struct FeedPostView: View {
    let post: SocialPost
    @StateObject private var interactionManager = InteractionManager()
    @Environment(\.theme) private var theme
    @State private var showingComments = false
    @State private var showingShareSheet = false
    @State private var isLiked = false
    @State private var isSaved = false
    @State private var likeAnimation = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Post Header
            PostHeaderView(post: post)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

            // Post Content
            PostContentView(post: post)
                .onTapGesture(count: 2) {
                    doubleTapLike()
                }

            // Post Actions
            PostActionsView(
                post: post,
                isLiked: $isLiked,
                isSaved: $isSaved,
                onComment: { showingComments = true },
                onShare: { showingShareSheet = true }
            )
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            // Post Footer (likes, caption, comments preview)
            PostFooterView(post: post)
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(theme.colors.surface)
                .glassmorphism(intensity: .light)
        )
        .overlay(
            // Like animation
            LikeAnimationView(isAnimating: $likeAnimation)
        )
        .sheet(isPresented: $showingComments) {
            CommentsView(post: post)
        }
        .sheet(isPresented: $showingShareSheet) {
            SharePostView(post: post)
        }
    }

    private func doubleTapLike() {
        guard !isLiked else { return }

        withAnimation(.bouncy) {
            isLiked = true
            likeAnimation = true
        }

        interactionManager.likePost(post.id, type: .doubleTabLike)

        // Reset animation after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            likeAnimation = false
        }
    }
}

// MARK: - Post Header
struct PostHeaderView: View {
    let post: SocialPost
    @Environment(\.theme) private var theme
    @State private var showingProfile = false

    var body: some View {
        HStack(spacing: 12) {
            // Profile Picture
            Button {
                showingProfile = true
            } label: {
                Circle()
                    .fill(theme.colors.surfaceVariant)
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: "person.crop.circle.fill")
                            .font(.title2)
                            .foregroundColor(theme.colors.onSurfaceVariant)
                    )
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text("@username") // Would get from post.authorID
                        .typography(.body2, theme: .modern)
                        .foregroundColor(theme.colors.onSurface)

                    // Verification badge if applicable
                    Image(systemName: "checkmark.seal.fill")
                        .font(.caption)
                        .foregroundColor(.blue)
                }

                if let location = post.location {
                    Text(location.name)
                        .typography(.caption1, theme: .system)
                        .foregroundColor(theme.colors.onSurfaceVariant)
                }
            }

            Spacer()

            // Post menu
            Button {
                // Show post options
            } label: {
                Image(systemName: "ellipsis")
                    .font(.title3)
                    .foregroundColor(theme.colors.onSurfaceVariant)
            }
        }
    }
}

// MARK: - Post Content View
struct PostContentView: View {
    let post: SocialPost
    @Environment(\.theme) private var theme

    var body: some View {
        Group {
            switch post.content {
            case .photo(let photoPost):
                PhotoPostContentView(photoPost: photoPost)

            case .video(let videoPost):
                VideoPostContentView(videoPost: videoPost)

            case .outfit(let outfitPost):
                OutfitPostContentView(outfitPost: outfitPost)

            case .reel(let reelPost):
                ReelPostContentView(reelPost: reelPost)

            case .beforeAfter(let transformationPost):
                TransformationPostContentView(transformationPost: transformationPost)

            case .challenge(let challengePost):
                ChallengePostContentView(challengePost: challengePost)

            case .poll(let pollPost):
                PollPostContentView(pollPost: pollPost)

            case .collaboration(let collaborationPost):
                CollaborationPostContentView(collaborationPost: collaborationPost)

            default:
                DefaultPostContentView(post: post)
            }
        }
        .clipped()
    }
}

// MARK: - Post Actions View
struct PostActionsView: View {
    let post: SocialPost
    @Binding var isLiked: Bool
    @Binding var isSaved: Bool
    let onComment: () -> Void
    let onShare: () -> Void
    @StateObject private var interactionManager = InteractionManager()
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: 16) {
            // Like Button
            Button {
                withAnimation(.bouncy) {
                    isLiked.toggle()
                }
                interactionManager.likePost(post.id, type: .like)
            } label: {
                Image(systemName: isLiked ? "heart.fill" : "heart")
                    .font(.title2)
                    .foregroundColor(isLiked ? .red : theme.colors.onSurface)
                    .scaleEffect(isLiked ? 1.2 : 1.0)
            }

            // Comment Button
            Button(action: onComment) {
                Image(systemName: "bubble.right")
                    .font(.title2)
                    .foregroundColor(theme.colors.onSurface)
            }

            // Share Button
            Button(action: onShare) {
                Image(systemName: "paperplane")
                    .font(.title2)
                    .foregroundColor(theme.colors.onSurface)
            }

            Spacer()

            // Save Button
            Button {
                withAnimation(.snappySpring) {
                    isSaved.toggle()
                }
                interactionManager.savePost(post.id)
            } label: {
                Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                    .font(.title2)
                    .foregroundColor(isSaved ? theme.colors.accent1 : theme.colors.onSurface)
            }
        }
    }
}

// MARK: - Post Footer View
struct PostFooterView: View {
    let post: SocialPost
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Like count
            if post.likeCount > 0 {
                Text("\(formatCount(post.likeCount)) likes")
                    .typography(.body2, theme: .system)
                    .foregroundColor(theme.colors.onSurface)
            }

            // Caption
            if !post.caption.isEmpty {
                Text(post.caption)
                    .typography(.body2, theme: .system)
                    .foregroundColor(theme.colors.onSurface)
                    .lineLimit(3)
            }

            // Hashtags
            if !post.hashtags.isEmpty {
                Text(post.hashtags.prefix(3).map { "#\($0)" }.joined(separator: " "))
                    .typography(.body2, theme: .system)
                    .foregroundColor(theme.colors.primary)
            }

            // Comment preview
            if post.commentCount > 0 {
                Text("View all \(post.commentCount) comments")
                    .typography(.caption1, theme: .system)
                    .foregroundColor(theme.colors.onSurfaceVariant)
            }

            // Timestamp
            Text(formatTimestamp(post.createdAt))
                .typography(.caption2, theme: .system)
                .foregroundColor(theme.colors.onSurfaceVariant)
        }
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

    private func formatTimestamp(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Like Animation
struct LikeAnimationView: View {
    @Binding var isAnimating: Bool

    var body: some View {
        if isAnimating {
            Image(systemName: "heart.fill")
                .font(.system(size: 80))
                .foregroundColor(.white)
                .shadow(color: .red, radius: 10)
                .scaleEffect(isAnimating ? 1.2 : 0.5)
                .opacity(isAnimating ? 0.8 : 0)
                .animation(.easeOut(duration: 0.6), value: isAnimating)
        }
    }
}

// MARK: - Loading and Empty States
struct FeedLoadingView: View {
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: 20) {
            ForEach(0..<3, id: \.self) { _ in
                FeedPostSkeleton()
            }
        }
        .padding()
    }
}

struct FeedPostSkeleton: View {
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Circle()
                    .fill(theme.colors.surfaceVariant)
                    .frame(width: 40, height: 40)

                VStack(alignment: .leading, spacing: 4) {
                    Rectangle()
                        .fill(theme.colors.surfaceVariant)
                        .frame(width: 100, height: 12)
                    Rectangle()
                        .fill(theme.colors.surfaceVariant)
                        .frame(width: 60, height: 10)
                }

                Spacer()
            }

            Rectangle()
                .fill(theme.colors.surfaceVariant)
                .frame(height: 200)
                .cornerRadius(8)

            HStack {
                Circle()
                    .fill(theme.colors.surfaceVariant)
                    .frame(width: 24, height: 24)
                Circle()
                    .fill(theme.colors.surfaceVariant)
                    .frame(width: 24, height: 24)
                Circle()
                    .fill(theme.colors.surfaceVariant)
                    .frame(width: 24, height: 24)

                Spacer()

                Circle()
                    .fill(theme.colors.surfaceVariant)
                    .frame(width: 24, height: 24)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(theme.colors.surface)
        )
        .shimmer()
    }
}

struct FeedLoadingIndicator: View {
    var body: some View {
        HStack {
            ProgressView()
            Text("Loading more posts...")
                .typography(.body2, theme: .system)
                .foregroundColor(.secondary)
        }
    }
}

struct EmptyFeedView: View {
    let feedType: FeedType
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 60))
                .foregroundColor(theme.colors.onSurfaceVariant)

            VStack(spacing: 8) {
                Text("No posts yet")
                    .typography(.heading3, theme: .modern)
                    .foregroundColor(theme.colors.onSurface)

                Text(emptyMessage)
                    .typography(.body2, theme: .system)
                    .foregroundColor(theme.colors.onSurfaceVariant)
                    .multilineTextAlignment(.center)
            }

            Button("Create First Post") {
                // Navigate to post creation
            }
            .foregroundColor(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(theme.colors.primary)
            )
        }
        .padding()
    }

    private var emptyMessage: String {
        switch feedType {
        case .following:
            return "Follow some stylists to see their latest outfits!"
        case .discover:
            return "Discover new styles and trends from around the world"
        case .trending:
            return "No trending posts right now"
        case .local:
            return "No local posts in your area"
        }
    }
}