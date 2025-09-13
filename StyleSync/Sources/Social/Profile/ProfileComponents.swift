import SwiftUI

// MARK: - Profile Layout Types
enum ProfileLayout: String, CaseIterable {
    case classic = "classic"
    case grid = "grid"
    case calendar = "calendar"
    case stories = "stories"
    case collections = "collections"

    var displayName: String {
        switch self {
        case .classic: return "Classic"
        case .grid: return "Grid"
        case .calendar: return "Calendar"
        case .stories: return "Stories"
        case .collections: return "Collections"
        }
    }

    var icon: String {
        switch self {
        case .classic: return "rectangle.grid.1x2"
        case .grid: return "rectangle.grid.3x3"
        case .calendar: return "calendar"
        case .stories: return "circle.grid.3x3"
        case .collections: return "folder"
        }
    }
}

// MARK: - Profile Controls View
struct ProfileControlsView: View {
    @Binding var selectedLayout: ProfileLayout
    let isCurrentUser: Bool
    @Environment(\.theme) private var theme
    @State private var showingOutfitCalendar = false

    var body: some View {
        VStack(spacing: 16) {
            // Layout Selector
            HStack(spacing: 12) {
                Text("View")
                    .typography(.body2, theme: .system)
                    .foregroundColor(theme.colors.onSurfaceVariant)

                Spacer()

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(ProfileLayout.allCases, id: \.self) { layout in
                            LayoutSelector(
                                layout: layout,
                                isSelected: selectedLayout == layout
                            ) {
                                withAnimation(.snappySpring) {
                                    selectedLayout = layout
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 4)
                }
            }

            // Calendar Toggle (for current user)
            if isCurrentUser && selectedLayout == .calendar {
                HStack {
                    Text("Outfit Calendar")
                        .typography(.body1, theme: .modern)
                        .foregroundColor(theme.colors.onSurface)

                    Spacer()

                    Button("View Full Calendar") {
                        showingOutfitCalendar = true
                    }
                    .foregroundColor(theme.colors.primary)
                    .typography(.body2, theme: .system)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(theme.colors.surfaceVariant)
                )
            }
        }
        .sheet(isPresented: $showingOutfitCalendar) {
            OutfitCalendarView()
        }
    }
}

// MARK: - Layout Selector
struct LayoutSelector: View {
    let layout: ProfileLayout
    let isSelected: Bool
    let action: () -> Void
    @Environment(\.theme) private var theme

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: layout.icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(isSelected ? theme.colors.primary : theme.colors.onSurfaceVariant)

                Text(layout.displayName)
                    .typography(.caption1, theme: .system)
                    .foregroundColor(isSelected ? theme.colors.primary : theme.colors.onSurfaceVariant)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? theme.colors.primary.opacity(0.1) : Color.clear)
            )
            .scaleEffect(isSelected ? 1.05 : 1.0)
        }
        .animation(.snappySpring, value: isSelected)
    }
}

// MARK: - Profile Content View
struct ProfileContentView: View {
    let profile: UserProfile
    let layout: ProfileLayout
    @StateObject private var postManager = PostManager()
    @Environment(\.theme) private var theme

    var body: some View {
        Group {
            switch layout {
            case .classic:
                ClassicProfileLayout(profile: profile, posts: postManager.userPosts)
            case .grid:
                GridProfileLayout(profile: profile, posts: postManager.userPosts)
            case .calendar:
                CalendarProfileLayout(profile: profile, posts: postManager.userPosts)
            case .stories:
                StoriesProfileLayout(profile: profile, stories: postManager.userStories)
            case .collections:
                CollectionsProfileLayout(profile: profile, collections: postManager.userCollections)
            }
        }
        .onAppear {
            postManager.loadUserPosts(for: profile.anonymousID)
        }
    }
}

// MARK: - Classic Profile Layout
struct ClassicProfileLayout: View {
    let profile: UserProfile
    let posts: [SocialPost]
    @Environment(\.theme) private var theme

    var body: some View {
        LazyVStack(spacing: 16) {
            ForEach(posts) { post in
                ClassicPostView(post: post)
                    .padding(.horizontal)
            }
        }
        .padding(.top)
    }
}

// MARK: - Grid Profile Layout
struct GridProfileLayout: View {
    let profile: UserProfile
    let posts: [SocialPost]
    @Environment(\.theme) private var theme

    private let gridColumns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 3)

    var body: some View {
        LazyVGrid(columns: gridColumns, spacing: 2) {
            ForEach(posts) { post in
                GridPostView(post: post)
                    .aspectRatio(1, contentMode: .fit)
            }
        }
        .padding(.horizontal, 2)
    }
}

// MARK: - Calendar Profile Layout
struct CalendarProfileLayout: View {
    let profile: UserProfile
    let posts: [SocialPost]
    @State private var selectedDate = Date()
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: 0) {
            // Mini Calendar
            OutfitMiniCalendar(
                selectedDate: $selectedDate,
                posts: posts
            )
            .padding(.horizontal)

            Divider()
                .padding(.vertical, 16)

            // Posts for selected date
            let postsForDate = postsForDate(selectedDate)

            if postsForDate.isEmpty {
                EmptyCalendarDateView(date: selectedDate)
                    .padding()
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(postsForDate) { post in
                        CalendarPostView(post: post)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private func postsForDate(_ date: Date) -> [SocialPost] {
        let calendar = Calendar.current
        return posts.filter { post in
            calendar.isDate(post.createdAt, inSameDayAs: date)
        }
    }
}

// MARK: - Stories Profile Layout
struct StoriesProfileLayout: View {
    let profile: UserProfile
    let stories: [StoryPost]
    @Environment(\.theme) private var theme

    private let storyColumns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 2)

    var body: some View {
        LazyVGrid(columns: storyColumns, spacing: 8) {
            ForEach(stories, id: \.id) { story in
                StoryHighlightView(story: story)
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - Collections Profile Layout
struct CollectionsProfileLayout: View {
    let profile: UserProfile
    let collections: [PostCollection]
    @Environment(\.theme) private var theme

    var body: some View {
        LazyVStack(spacing: 16) {
            ForEach(collections) { collection in
                CollectionView(collection: collection)
                    .padding(.horizontal)
            }
        }
        .padding(.top)
    }
}

// MARK: - Style Color Palette
struct StyleColorPalette: View {
    let colors: [StyleColor]
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Color Palette")
                .typography(.body2, theme: .system)
                .foregroundColor(theme.colors.onSurfaceVariant)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(colors.prefix(10)) { styleColor in
                        ColorSwatch(color: styleColor)
                    }
                }
                .padding(.horizontal, 4)
            }
        }
    }
}

// MARK: - Color Swatch
struct ColorSwatch: View {
    let color: StyleColor
    @State private var showingColorInfo = false

    var body: some View {
        Button {
            showingColorInfo = true
        } label: {
            Circle()
                .fill(color.color)
                .frame(width: 32, height: 32)
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                )
                .shadow(color: color.color.opacity(0.3), radius: 2)
        }
        .popover(isPresented: $showingColorInfo) {
            ColorInfoView(color: color)
        }
    }
}

// MARK: - Color Info View
struct ColorInfoView: View {
    let color: StyleColor
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: 12) {
            Circle()
                .fill(color.color)
                .frame(width: 60, height: 60)

            VStack(spacing: 4) {
                Text(color.name)
                    .typography(.heading4, theme: .modern)
                    .foregroundColor(theme.colors.onSurface)

                Text(color.hexValue.uppercased())
                    .typography(.body2, theme: .system)
                    .foregroundColor(theme.colors.onSurfaceVariant)

                if let season = color.season {
                    Text("\(season.rawValue.capitalized) Color")
                        .typography(.caption1, theme: .system)
                        .foregroundColor(theme.colors.accent1)
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(theme.colors.surface)
        )
    }
}

// MARK: - Style Tags View
struct StyleTagsView: View {
    let styles: [StyleTag]
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Style Categories")
                .typography(.body2, theme: .system)
                .foregroundColor(theme.colors.onSurfaceVariant)

            FlowLayout(spacing: 8) {
                ForEach(styles.prefix(8)) { style in
                    StyleTagChip(tag: style)
                }
            }
        }
    }
}

// MARK: - Style Tag Chip
struct StyleTagChip: View {
    let tag: StyleTag
    @Environment(\.theme) private var theme

    var body: some View {
        Text(tag.name)
            .typography(.caption1, theme: .system)
            .foregroundColor(theme.colors.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(theme.colors.primary.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(theme.colors.primary.opacity(0.3), lineWidth: 1)
                    )
            )
    }
}

// MARK: - Style Info Card
struct StyleInfoCard: View {
    let title: String
    let value: String
    let icon: String
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(theme.colors.primary)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .typography(.caption2, theme: .system)
                    .foregroundColor(theme.colors.onSurfaceVariant)

                Text(value)
                    .typography(.caption1, theme: .system)
                    .foregroundColor(theme.colors.onSurface)
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(theme.colors.surfaceVariant.opacity(0.5))
        )
    }
}

// MARK: - Profile Action Button
struct ProfileActionButton: View {
    let profile: UserProfile
    @StateObject private var socialManager = SocialManager.shared
    @Environment(\.theme) private var theme
    @State private var showingActionSheet = false

    var body: some View {
        Button {
            showingActionSheet = true
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.title2)
                .foregroundColor(theme.colors.onSurface)
        }
        .actionSheet(isPresented: $showingActionSheet) {
            ActionSheet(
                title: Text("Profile Actions"),
                buttons: [
                    .default(Text("Follow")) {
                        socialManager.followUser(profile.anonymousID)
                    },
                    .default(Text("Message")) {
                        socialManager.startConversation(with: profile.anonymousID)
                    },
                    .default(Text("Share Profile")) {
                        socialManager.shareProfile(profile)
                    },
                    .destructive(Text("Block")) {
                        socialManager.blockUser(profile.anonymousID)
                    },
                    .destructive(Text("Report")) {
                        socialManager.reportUser(profile.anonymousID)
                    },
                    .cancel()
                ]
            )
        }
    }
}

// MARK: - Flow Layout (Custom Layout)
struct FlowLayout: Layout {
    let spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let availableWidth = proposal.width ?? .infinity
        var totalHeight: CGFloat = 0
        var currentRowWidth: CGFloat = 0
        var currentRowHeight: CGFloat = 0

        for subview in subviews {
            let subviewSize = subview.sizeThatFits(.unspecified)

            if currentRowWidth + subviewSize.width > availableWidth && currentRowWidth > 0 {
                // Move to next row
                totalHeight += currentRowHeight + spacing
                currentRowWidth = subviewSize.width
                currentRowHeight = subviewSize.height
            } else {
                currentRowWidth += subviewSize.width + (currentRowWidth > 0 ? spacing : 0)
                currentRowHeight = max(currentRowHeight, subviewSize.height)
            }
        }

        totalHeight += currentRowHeight
        return CGSize(width: availableWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var currentPosition = bounds.origin
        var currentRowHeight: CGFloat = 0

        for subview in subviews {
            let subviewSize = subview.sizeThatFits(.unspecified)

            if currentPosition.x + subviewSize.width > bounds.maxX && currentPosition.x > bounds.minX {
                // Move to next row
                currentPosition.x = bounds.minX
                currentPosition.y += currentRowHeight + spacing
                currentRowHeight = 0
            }

            subview.place(at: currentPosition, proposal: ProposedViewSize(subviewSize))
            currentPosition.x += subviewSize.width + spacing
            currentRowHeight = max(currentRowHeight, subviewSize.height)
        }
    }
}

// MARK: - Temporary Mock Classes
class PostManager: ObservableObject {
    @Published var userPosts: [SocialPost] = []
    @Published var userStories: [StoryPost] = []
    @Published var userCollections: [PostCollection] = []

    func loadUserPosts(for userID: String) {
        // Mock implementation - replace with actual data loading
        userPosts = []
        userStories = []
        userCollections = []
    }
}

struct PostCollection: Identifiable {
    let id = UUID()
    let name: String
    let posts: [SocialPost]
    let coverImage: Data?
}

class SocialManager: ObservableObject {
    static let shared = SocialManager()

    func followUser(_ userID: String) {
        // Implementation for following user
    }

    func startConversation(with userID: String) {
        // Implementation for starting conversation
    }

    func shareProfile(_ profile: UserProfile) {
        // Implementation for sharing profile
    }

    func blockUser(_ userID: String) {
        // Implementation for blocking user
    }

    func reportUser(_ userID: String) {
        // Implementation for reporting user
    }
}

// MARK: - Placeholder Views
struct ClassicPostView: View {
    let post: SocialPost

    var body: some View {
        Rectangle()
            .fill(Color.gray.opacity(0.3))
            .frame(height: 200)
            .cornerRadius(12)
    }
}

struct GridPostView: View {
    let post: SocialPost

    var body: some View {
        Rectangle()
            .fill(Color.gray.opacity(0.3))
            .cornerRadius(4)
    }
}

struct CalendarPostView: View {
    let post: SocialPost

    var body: some View {
        Rectangle()
            .fill(Color.gray.opacity(0.3))
            .frame(height: 120)
            .cornerRadius(8)
    }
}

struct StoryHighlightView: View {
    let story: StoryPost

    var body: some View {
        Rectangle()
            .fill(Color.gray.opacity(0.3))
            .aspectRatio(9/16, contentMode: .fit)
            .cornerRadius(12)
    }
}

struct CollectionView: View {
    let collection: PostCollection

    var body: some View {
        Rectangle()
            .fill(Color.gray.opacity(0.3))
            .frame(height: 150)
            .cornerRadius(12)
    }
}

struct OutfitMiniCalendar: View {
    @Binding var selectedDate: Date
    let posts: [SocialPost]

    var body: some View {
        Rectangle()
            .fill(Color.gray.opacity(0.3))
            .frame(height: 200)
            .cornerRadius(12)
    }
}

struct EmptyCalendarDateView: View {
    let date: Date

    var body: some View {
        VStack {
            Text("No outfits for this day")
            Text("Tap + to add one!")
        }
        .foregroundColor(.gray)
    }
}

struct OutfitCalendarView: View {
    var body: some View {
        Text("Full Outfit Calendar")
    }
}

struct AllAchievementsView: View {
    let achievements: [Achievement]

    var body: some View {
        Text("All Achievements")
    }
}

struct EditProfileView: View {
    let profile: UserProfile

    var body: some View {
        Text("Edit Profile")
    }
}

struct ProfileSettingsView: View {
    var body: some View {
        Text("Profile Settings")
    }
}