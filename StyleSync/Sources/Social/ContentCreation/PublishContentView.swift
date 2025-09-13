import SwiftUI

// MARK: - Publish Content View
struct PublishContentView: View {
    let editedMedia: EditedMedia
    let creationType: CreationType
    @StateObject private var publishManager = PublishManager.shared
    @Environment(\.theme) private var theme
    @Environment(\.presentationMode) var presentationMode
    @State private var caption = ""
    @State private var hashtags: [String] = []
    @State private var mentions: [String] = []
    @State private var selectedLocation: PostLocation?
    @State private var visibility: PostVisibility = .public
    @State private var isCloseFriendsOnly = false
    @State private var allowComments = true
    @State private var allowRemix = true
    @State private var allowSaving = true
    @State private var showingLocationPicker = false
    @State private var showingAdvancedOptions = false
    @State private var scheduledDate: Date?
    @State private var isPublishing = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Content Preview
                    ContentPreviewCard(editedMedia: editedMedia, creationType: creationType)

                    // Caption Input
                    CaptionInputSection(
                        caption: $caption,
                        hashtags: $hashtags,
                        mentions: $mentions
                    )

                    // Location and Tagging
                    LocationTaggingSection(
                        selectedLocation: $selectedLocation,
                        showingLocationPicker: $showingLocationPicker
                    )

                    // Outfit Details (for outfit posts)
                    if creationType == .outfit {
                        OutfitDetailsSection()
                    }

                    // Privacy and Sharing Options
                    SharingOptionsSection(
                        visibility: $visibility,
                        isCloseFriendsOnly: $isCloseFriendsOnly,
                        allowComments: $allowComments,
                        allowRemix: $allowRemix,
                        allowSaving: $allowSaving
                    )

                    // Advanced Options
                    AdvancedOptionsSection(
                        showingAdvancedOptions: $showingAdvancedOptions,
                        scheduledDate: $scheduledDate
                    )

                    // Publish Button
                    PublishButton(isPublishing: $isPublishing) {
                        publishContent()
                    }
                }
                .padding()
            }
            .background(
                GradientMeshBackground(colors: theme.gradients.mesh)
                    .ignoresSafeArea()
            )
            .navigationTitle("Share")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(theme.colors.onSurface)
                }
            }
        }
        .sheet(isPresented: $showingLocationPicker) {
            LocationPickerView(selectedLocation: $selectedLocation)
        }
    }

    private func publishContent() {
        isPublishing = true

        Task {
            do {
                let post = try await createSocialPost()
                try await publishManager.publishPost(post)

                DispatchQueue.main.async {
                    self.isPublishing = false
                    self.presentationMode.wrappedValue.dismiss()
                }

            } catch {
                DispatchQueue.main.async {
                    self.isPublishing = false
                    // Show error
                }
            }
        }
    }

    private func createSocialPost() async throws -> SocialPost {
        let postContent = createPostContent()

        return SocialPost(
            authorID: await getCurrentUserId(),
            content: postContent,
            caption: caption,
            hashtags: hashtags,
            mentions: mentions,
            location: selectedLocation,
            visibility: visibility,
            isCloseFriendsOnly: isCloseFriendsOnly,
            allowComments: allowComments,
            allowRemix: allowRemix,
            allowSaving: allowSaving
        )
    }

    private func createPostContent() -> PostContent {
        switch creationType {
        case .photo, .outfit:
            return .photo(PhotoPost(
                imageData: [editedMedia.processedImage?.jpegData(compressionQuality: 0.9) ?? Data()],
                filters: editedMedia.editingMetadata.filtersApplied,
                layout: nil,
                aspectRatio: 1.0,
                editingData: editedMedia.editingMetadata
            ))

        case .video, .reel:
            return .video(VideoPost(
                videoURL: editedMedia.videoURL ?? URL(string: "about:blank")!,
                thumbnailData: editedMedia.processedImage?.jpegData(compressionQuality: 0.8) ?? Data(),
                duration: 30, // Would get actual duration
                effects: [],
                musicTrack: editedMedia.musicTrack,
                transitions: [],
                isBoomerang: creationType == .boomerang,
                isTimelapse: creationType == .timelapse
            ))

        default:
            return .photo(PhotoPost(
                imageData: [editedMedia.processedImage?.jpegData(compressionQuality: 0.9) ?? Data()],
                filters: [],
                layout: nil,
                aspectRatio: 1.0,
                editingData: nil
            ))
        }
    }

    private func getCurrentUserId() async -> String {
        return "current_user" // Would get from ProfileManager
    }
}

// MARK: - Content Preview Card
struct ContentPreviewCard: View {
    let editedMedia: EditedMedia
    let creationType: CreationType
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: 12) {
            // Content Thumbnail
            Group {
                if let image = editedMedia.processedImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Rectangle()
                        .fill(theme.colors.surfaceVariant)
                        .overlay(
                            Image(systemName: "photo")
                                .foregroundColor(theme.colors.onSurfaceVariant)
                        )
                }
            }
            .frame(width: 80, height: 80)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 4) {
                Text(creationType.displayName)
                    .typography(.heading4, theme: .modern)
                    .foregroundColor(theme.colors.onSurface)

                if !editedMedia.overlayElements.isEmpty {
                    Text("\(editedMedia.overlayElements.count) elements added")
                        .typography(.caption1, theme: .system)
                        .foregroundColor(theme.colors.onSurfaceVariant)
                }

                if editedMedia.musicTrack != nil {
                    HStack(spacing: 4) {
                        Image(systemName: "music.note")
                            .font(.caption)
                        Text("Music added")
                            .typography(.caption1, theme: .system)
                    }
                    .foregroundColor(theme.colors.accent1)
                }
            }

            Spacer()

            // Edit Button
            Button("Edit") {
                // Go back to editor
            }
            .foregroundColor(theme.colors.primary)
            .typography(.body2, theme: .system)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(theme.colors.surface)
                .glassmorphism(intensity: .light)
        )
    }
}

// MARK: - Caption Input Section
struct CaptionInputSection: View {
    @Binding var caption: String
    @Binding var hashtags: [String]
    @Binding var mentions: [String]
    @Environment(\.theme) private var theme
    @State private var showingSuggestions = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Write a caption...")
                .typography(.heading4, theme: .modern)
                .foregroundColor(theme.colors.onSurface)

            // Caption Text Field
            TextEditor(text: $caption)
                .frame(minHeight: 100)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(theme.colors.surfaceVariant)
                )
                .overlay(
                    VStack {
                        HStack {
                            Spacer()
                            Text("\(caption.count)/500")
                                .typography(.caption2, theme: .system)
                                .foregroundColor(theme.colors.onSurfaceVariant)
                                .padding(.trailing, 8)
                                .padding(.top, 8)
                        }
                        Spacer()
                    }
                )

            // Hashtag and Mention Suggestions
            if showingSuggestions {
                HashtagSuggestionsView(hashtags: $hashtags)
            }

            // Quick Actions
            HStack(spacing: 16) {
                Button {
                    showingSuggestions.toggle()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "number")
                            .font(.caption)
                        Text("Add hashtags")
                            .typography(.caption1, theme: .system)
                    }
                    .foregroundColor(theme.colors.primary)
                }

                Button {
                    // Add mention
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "at")
                            .font(.caption)
                        Text("Tag someone")
                            .typography(.caption1, theme: .system)
                    }
                    .foregroundColor(theme.colors.primary)
                }

                Spacer()
            }

            // Current Hashtags
            if !hashtags.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(hashtags, id: \.self) { hashtag in
                        HashtagChip(hashtag: hashtag) {
                            hashtags.removeAll { $0 == hashtag }
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(theme.colors.surface)
                .glassmorphism(intensity: .light)
        )
    }
}

// MARK: - Hashtag Suggestions View
struct HashtagSuggestionsView: View {
    @Binding var hashtags: [String]
    @Environment(\.theme) private var theme

    private let suggestedHashtags = [
        "ootd", "style", "fashion", "outfit", "trending",
        "stylesync", "look", "outfitpost", "fashionista",
        "styleinspo", "ootdshare", "fashionblogger"
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Suggested hashtags")
                .typography(.caption1, theme: .system)
                .foregroundColor(theme.colors.onSurfaceVariant)

            FlowLayout(spacing: 6) {
                ForEach(suggestedHashtags, id: \.self) { hashtag in
                    if !hashtags.contains(hashtag) {
                        Button("#\(hashtag)") {
                            hashtags.append(hashtag)
                        }
                        .typography(.caption1, theme: .system)
                        .foregroundColor(theme.colors.primary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(theme.colors.primary.opacity(0.5), lineWidth: 1)
                        )
                    }
                }
            }
        }
        .padding(.top, 8)
    }
}

// MARK: - Hashtag Chip
struct HashtagChip: View {
    let hashtag: String
    let onRemove: () -> Void
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: 4) {
            Text("#\(hashtag)")
                .typography(.caption1, theme: .system)
                .foregroundColor(.white)

            Button {
                onRemove()
            } label: {
                Image(systemName: "xmark")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.8))
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(theme.colors.primary)
        )
    }
}

// MARK: - Location Tagging Section
struct LocationTaggingSection: View {
    @Binding var selectedLocation: PostLocation?
    @Binding var showingLocationPicker: Bool
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Location")
                .typography(.heading4, theme: .modern)
                .foregroundColor(theme.colors.onSurface)

            Button {
                showingLocationPicker = true
            } label: {
                HStack {
                    Image(systemName: "location")
                        .foregroundColor(theme.colors.onSurfaceVariant)

                    Text(selectedLocation?.name ?? "Add location")
                        .typography(.body2, theme: .system)
                        .foregroundColor(selectedLocation != nil ? theme.colors.onSurface : theme.colors.onSurfaceVariant)

                    Spacer()

                    if selectedLocation != nil {
                        Button {
                            selectedLocation = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(theme.colors.onSurfaceVariant)
                        }
                    } else {
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(theme.colors.onSurfaceVariant)
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(theme.colors.surfaceVariant)
                )
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(theme.colors.surface)
                .glassmorphism(intensity: .light)
        )
    }
}

// MARK: - Outfit Details Section
struct OutfitDetailsSection: View {
    @State private var selectedOccasion = "Casual"
    @State private var selectedSeason = Season.spring
    @State private var outfitItems: [OutfitItem] = []
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Outfit Details")
                .typography(.heading4, theme: .modern)
                .foregroundColor(theme.colors.onSurface)

            VStack(spacing: 12) {
                // Occasion Picker
                HStack {
                    Text("Occasion")
                        .typography(.body2, theme: .system)
                        .foregroundColor(theme.colors.onSurfaceVariant)

                    Spacer()

                    Menu(selectedOccasion) {
                        ForEach(["Casual", "Work", "Date Night", "Party", "Special Event"], id: \.self) { occasion in
                            Button(occasion) {
                                selectedOccasion = occasion
                            }
                        }
                    }
                    .foregroundColor(theme.colors.onSurface)
                }

                Divider()

                // Season Picker
                HStack {
                    Text("Season")
                        .typography(.body2, theme: .system)
                        .foregroundColor(theme.colors.onSurfaceVariant)

                    Spacer()

                    Menu(selectedSeason.rawValue.capitalized) {
                        ForEach(Season.allCases, id: \.self) { season in
                            Button(season.rawValue.capitalized) {
                                selectedSeason = season
                            }
                        }
                    }
                    .foregroundColor(theme.colors.onSurface)
                }

                Divider()

                // Add Items Button
                Button("Add outfit items") {
                    // Show item picker
                }
                .foregroundColor(theme.colors.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(theme.colors.surface)
                .glassmorphism(intensity: .light)
        )
    }
}

// MARK: - Sharing Options Section
struct SharingOptionsSection: View {
    @Binding var visibility: PostVisibility
    @Binding var isCloseFriendsOnly: Bool
    @Binding var allowComments: Bool
    @Binding var allowRemix: Bool
    @Binding var allowSaving: Bool
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sharing & Privacy")
                .typography(.heading4, theme: .modern)
                .foregroundColor(theme.colors.onSurface)

            VStack(spacing: 12) {
                // Visibility
                HStack {
                    Text("Visibility")
                        .typography(.body2, theme: .system)
                        .foregroundColor(theme.colors.onSurfaceVariant)

                    Spacer()

                    Menu(visibility.rawValue.capitalized) {
                        ForEach(PostVisibility.allCases, id: \.self) { vis in
                            Button(vis.rawValue.capitalized) {
                                visibility = vis
                            }
                        }
                    }
                    .foregroundColor(theme.colors.onSurface)
                }

                if visibility == .followers {
                    Toggle("Close friends only", isOn: $isCloseFriendsOnly)
                        .typography(.body2, theme: .system)
                        .foregroundColor(theme.colors.onSurfaceVariant)
                        .toggleStyle(SwitchToggleStyle(tint: theme.colors.primary))
                }

                Divider()

                // Interaction Settings
                Toggle("Allow comments", isOn: $allowComments)
                    .typography(.body2, theme: .system)
                    .foregroundColor(theme.colors.onSurfaceVariant)
                    .toggleStyle(SwitchToggleStyle(tint: theme.colors.primary))

                Toggle("Allow remixing", isOn: $allowRemix)
                    .typography(.body2, theme: .system)
                    .foregroundColor(theme.colors.onSurfaceVariant)
                    .toggleStyle(SwitchToggleStyle(tint: theme.colors.primary))

                Toggle("Allow saving", isOn: $allowSaving)
                    .typography(.body2, theme: .system)
                    .foregroundColor(theme.colors.onSurfaceVariant)
                    .toggleStyle(SwitchToggleStyle(tint: theme.colors.primary))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(theme.colors.surface)
                .glassmorphism(intensity: .light)
        )
    }
}

// MARK: - Advanced Options Section
struct AdvancedOptionsSection: View {
    @Binding var showingAdvancedOptions: Bool
    @Binding var scheduledDate: Date?
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                showingAdvancedOptions.toggle()
            } label: {
                HStack {
                    Text("Advanced Options")
                        .typography(.heading4, theme: .modern)
                        .foregroundColor(theme.colors.onSurface)

                    Spacer()

                    Image(systemName: showingAdvancedOptions ? "chevron.up" : "chevron.down")
                        .foregroundColor(theme.colors.onSurfaceVariant)
                }
            }

            if showingAdvancedOptions {
                VStack(spacing: 12) {
                    // Schedule Post
                    Toggle("Schedule post", isOn: Binding(
                        get: { scheduledDate != nil },
                        set: { if !$0 { scheduledDate = nil } else { scheduledDate = Date().addingTimeInterval(3600) } }
                    ))
                    .typography(.body2, theme: .system)
                    .foregroundColor(theme.colors.onSurfaceVariant)
                    .toggleStyle(SwitchToggleStyle(tint: theme.colors.primary))

                    if scheduledDate != nil {
                        DatePicker(
                            "Schedule for",
                            selection: Binding($scheduledDate)!,
                            in: Date()...,
                            displayedComponents: [.date, .hourAndMinute]
                        )
                        .typography(.body2, theme: .system)
                        .foregroundColor(theme.colors.onSurfaceVariant)
                    }

                    Divider()

                    // Cross-posting options would go here
                    Text("Cross-post to other platforms")
                        .typography(.body2, theme: .system)
                        .foregroundColor(theme.colors.onSurfaceVariant)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(theme.colors.surface)
                .glassmorphism(intensity: .light)
        )
    }
}

// MARK: - Publish Button
struct PublishButton: View {
    @Binding var isPublishing: Bool
    let onPublish: () -> Void
    @Environment(\.theme) private var theme

    var body: some View {
        Button(action: onPublish) {
            HStack {
                if isPublishing {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)

                    Text("Publishing...")
                        .typography(.body1, theme: .modern)
                        .foregroundColor(.white)
                } else {
                    Text("Share")
                        .typography(.body1, theme: .modern)
                        .foregroundColor(.white)
                        .fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(theme.colors.primary)
                    .shadow(color: theme.colors.primary.opacity(0.3), radius: 8, x: 0, y: 4)
            )
        }
        .disabled(isPublishing)
        .scaleEffect(isPublishing ? 0.98 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isPublishing)
    }
}

// MARK: - Location Picker View
struct LocationPickerView: View {
    @Binding var selectedLocation: PostLocation?
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        NavigationView {
            Text("Location Picker")
                .navigationTitle("Choose Location")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            presentationMode.wrappedValue.dismiss()
                        }
                    }
                }
        }
    }
}

// MARK: - Publish Manager
@MainActor
final class PublishManager: ObservableObject {
    static let shared = PublishManager()

    @Published var isPublishing = false
    @Published var publishProgress: Double = 0

    private init() {}

    func publishPost(_ post: SocialPost) async throws {
        isPublishing = true
        publishProgress = 0

        // Simulate publishing process
        for i in 1...10 {
            try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
            publishProgress = Double(i) / 10.0
        }

        // Would actually upload to server here
        print("Publishing post: \(post.caption)")

        isPublishing = false
        publishProgress = 0
    }
}