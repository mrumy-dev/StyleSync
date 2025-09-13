import SwiftUI

// MARK: - Comments View
struct CommentsView: View {
    let post: SocialPost
    @StateObject private var interactionManager = InteractionManager.shared
    @StateObject private var commentsManager = CommentsManager()
    @Environment(\.theme) private var theme
    @Environment(\.presentationMode) var presentationMode
    @State private var newCommentText = ""
    @State private var replyingToComment: Comment?
    @State private var keyboardHeight: CGFloat = 0
    @FocusState private var isCommentFieldFocused: Bool

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Comments List
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            // Post Summary
                            PostSummaryView(post: post)
                                .padding(.horizontal)
                                .padding(.bottom, 16)

                            // Comments
                            ForEach(commentsManager.comments) { comment in
                                CommentRowView(
                                    comment: comment,
                                    onReply: { replyToComment(comment) },
                                    onLike: { likeComment(comment) }
                                )
                                .id(comment.id)
                            }

                            // Loading indicator
                            if commentsManager.isLoading {
                                CommentsLoadingView()
                                    .padding()
                            }

                            // Empty state
                            if commentsManager.comments.isEmpty && !commentsManager.isLoading {
                                EmptyCommentsView()
                                    .padding()
                            }
                        }
                    }
                    .onAppear {
                        commentsManager.loadComments(for: post.id)
                    }
                    .onChange(of: commentsManager.comments.count) { _ in
                        // Scroll to bottom when new comment is added
                        if let lastComment = commentsManager.comments.last {
                            withAnimation {
                                proxy.scrollTo(lastComment.id, anchor: .bottom)
                            }
                        }
                    }
                }

                Divider()

                // Comment Input Area
                CommentInputView(
                    newCommentText: $newCommentText,
                    replyingToComment: $replyingToComment,
                    isCommentFieldFocused: $isCommentFieldFocused,
                    onSubmit: submitComment,
                    onCancelReply: { replyingToComment = nil }
                )
                .padding(.bottom, keyboardHeight)
            }
            .background(
                GradientMeshBackground(colors: theme.gradients.mesh)
                    .ignoresSafeArea()
            )
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle("Comments")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(theme.colors.primary)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Sort by Newest") {
                            commentsManager.sortComments(by: .newest)
                        }
                        Button("Sort by Top") {
                            commentsManager.sortComments(by: .top)
                        }
                        Button("Sort by Oldest") {
                            commentsManager.sortComments(by: .oldest)
                        }
                    } label: {
                        Image(systemName: "arrow.up.arrow.down")
                            .foregroundColor(theme.colors.onSurface)
                    }
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { notification in
            withAnimation(.easeOut(duration: 0.25)) {
                keyboardHeight = getKeyboardHeight(notification)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            withAnimation(.easeOut(duration: 0.25)) {
                keyboardHeight = 0
            }
        }
    }

    private func submitComment() {
        guard !newCommentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        Task {
            do {
                let comment = try await interactionManager.addComment(
                    to: post.id,
                    content: newCommentText,
                    mentions: extractMentions(from: newCommentText)
                )

                if let replyingTo = replyingToComment {
                    commentsManager.addReply(comment, to: replyingTo.id)
                } else {
                    commentsManager.addComment(comment)
                }

                newCommentText = ""
                replyingToComment = nil
                isCommentFieldFocused = false

            } catch {
                // Handle error
                print("Failed to add comment: \(error)")
            }
        }
    }

    private func replyToComment(_ comment: Comment) {
        replyingToComment = comment
        isCommentFieldFocused = true
    }

    private func likeComment(_ comment: Comment) {
        Task {
            await interactionManager.likeComment(comment.id)
            commentsManager.updateCommentLike(comment.id)
        }
    }

    private func extractMentions(from text: String) -> [String] {
        let mentionPattern = "@([a-zA-Z0-9_]+)"
        let regex = try? NSRegularExpression(pattern: mentionPattern, options: [])
        let range = NSRange(location: 0, length: text.utf16.count)
        let matches = regex?.matches(in: text, options: [], range: range) ?? []

        return matches.compactMap { match in
            if let range = Range(match.range(at: 1), in: text) {
                return String(text[range])
            }
            return nil
        }
    }

    private func getKeyboardHeight(_ notification: Notification) -> CGFloat {
        guard let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else {
            return 0
        }
        return keyboardFrame.height
    }
}

// MARK: - Post Summary View
struct PostSummaryView: View {
    let post: SocialPost
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Author Profile Picture
            Circle()
                .fill(theme.colors.surfaceVariant)
                .frame(width: 32, height: 32)
                .overlay(
                    Image(systemName: "person.crop.circle.fill")
                        .font(.title3)
                        .foregroundColor(theme.colors.onSurfaceVariant)
                )

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("@username") // Would get from post.authorID
                        .typography(.body2, theme: .modern)
                        .foregroundColor(theme.colors.onSurface)

                    Spacer()

                    Text(formatTimestamp(post.createdAt))
                        .typography(.caption2, theme: .system)
                        .foregroundColor(theme.colors.onSurfaceVariant)
                }

                if !post.caption.isEmpty {
                    Text(post.caption)
                        .typography(.body2, theme: .system)
                        .foregroundColor(theme.colors.onSurface)
                        .lineLimit(3)
                }

                // Engagement Stats
                HStack(spacing: 16) {
                    Text("\(post.likeCount) likes")
                        .typography(.caption1, theme: .system)
                        .foregroundColor(theme.colors.onSurfaceVariant)

                    Text("\(post.commentCount) comments")
                        .typography(.caption1, theme: .system)
                        .foregroundColor(theme.colors.onSurfaceVariant)
                }
                .padding(.top, 4)
            }
        }
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(theme.colors.surface)
                .glassmorphism(intensity: .light)
        )
    }

    private func formatTimestamp(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Comment Row View
struct CommentRowView: View {
    let comment: Comment
    let onReply: () -> Void
    let onLike: () -> Void
    @Environment(\.theme) private var theme
    @State private var showingReplies = false
    @State private var isLiked = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                // Profile Picture
                Circle()
                    .fill(theme.colors.surfaceVariant)
                    .frame(width: 28, height: 28)
                    .overlay(
                        Image(systemName: "person.crop.circle.fill")
                            .font(.caption)
                            .foregroundColor(theme.colors.onSurfaceVariant)
                    )

                VStack(alignment: .leading, spacing: 6) {
                    // Comment Header
                    HStack {
                        Text("@username") // Would get from comment.authorID
                            .typography(.caption1, theme: .system)
                            .foregroundColor(theme.colors.onSurface)

                        if comment.isPinned {
                            Image(systemName: "pin.fill")
                                .font(.caption2)
                                .foregroundColor(theme.colors.accent1)
                        }

                        Spacer()

                        Text(formatTimestamp(comment.createdAt))
                            .typography(.caption2, theme: .system)
                            .foregroundColor(theme.colors.onSurfaceVariant)
                    }

                    // Comment Content
                    CommentContentView(content: comment.content)

                    // Outfit Suggestions (if any)
                    if !comment.suggestions.isEmpty {
                        OutfitSuggestionsView(suggestions: comment.suggestions)
                            .padding(.top, 4)
                    }

                    // Comment Actions
                    HStack(spacing: 16) {
                        Button(action: onLike) {
                            HStack(spacing: 4) {
                                Image(systemName: isLiked ? "heart.fill" : "heart")
                                    .font(.caption)
                                    .foregroundColor(isLiked ? .red : theme.colors.onSurfaceVariant)

                                if comment.likeCount > 0 {
                                    Text("\(comment.likeCount)")
                                        .typography(.caption2, theme: .system)
                                        .foregroundColor(theme.colors.onSurfaceVariant)
                                }
                            }
                        }
                        .scaleEffect(isLiked ? 1.1 : 1.0)
                        .animation(.bouncy, value: isLiked)

                        Button("Reply", action: onReply)
                            .typography(.caption1, theme: .system)
                            .foregroundColor(theme.colors.onSurfaceVariant)

                        if comment.replyCount > 0 {
                            Button("\(comment.replyCount) replies") {
                                showingReplies.toggle()
                            }
                            .typography(.caption1, theme: .system)
                            .foregroundColor(theme.colors.primary)
                        }

                        Spacer()

                        Menu {
                            Button("Report", role: .destructive) {
                                // Handle report
                            }
                            Button("Block User", role: .destructive) {
                                // Handle block
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(.caption)
                                .foregroundColor(theme.colors.onSurfaceVariant)
                        }
                    }
                    .padding(.top, 4)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            // Replies
            if showingReplies && !comment.replies.isEmpty {
                ForEach(comment.replies) { reply in
                    CommentReplyView(reply: reply)
                }
            }

            Divider()
                .padding(.leading, 52)
        }
    }

    private func formatTimestamp(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Comment Content View
struct CommentContentView: View {
    let content: String
    @Environment(\.theme) private var theme

    var body: some View {
        Text(processedContent)
            .typography(.body2, theme: .system)
            .foregroundColor(theme.colors.onSurface)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var processedContent: AttributedString {
        var attributedString = AttributedString(content)

        // Process mentions
        let mentionPattern = "@([a-zA-Z0-9_]+)"
        if let regex = try? NSRegularExpression(pattern: mentionPattern, options: []) {
            let range = NSRange(location: 0, length: content.utf16.count)
            let matches = regex.matches(in: content, options: [], range: range)

            for match in matches.reversed() {
                if let range = Range(match.range, in: content) {
                    let mention = String(content[range])
                    // In SwiftUI, you'd need to handle mentions differently
                    // This is a simplified version
                }
            }
        }

        return attributedString
    }
}

// MARK: - Comment Reply View
struct CommentReplyView: View {
    let reply: Comment
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            // Connecting line
            Rectangle()
                .fill(theme.colors.outline.opacity(0.3))
                .frame(width: 2, height: 20)
                .padding(.leading, 28)

            Circle()
                .fill(theme.colors.surfaceVariant)
                .frame(width: 20, height: 20)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("@username")
                        .typography(.caption2, theme: .system)
                        .foregroundColor(theme.colors.onSurface)

                    Spacer()

                    Text(formatTimestamp(reply.createdAt))
                        .typography(.caption2, theme: .system)
                        .foregroundColor(theme.colors.onSurfaceVariant)
                }

                Text(reply.content)
                    .typography(.caption1, theme: .system)
                    .foregroundColor(theme.colors.onSurface)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 4)
    }

    private func formatTimestamp(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Outfit Suggestions View
struct OutfitSuggestionsView: View {
    let suggestions: [OutfitSuggestion]
    @Environment(\.theme) private var theme

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(suggestions.prefix(3)) { suggestion in
                    OutfitSuggestionCard(suggestion: suggestion)
                }
            }
            .padding(.horizontal, 4)
        }
    }
}

struct OutfitSuggestionCard: View {
    let suggestion: OutfitSuggestion
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: "lightbulb.fill")
                    .font(.caption2)
                    .foregroundColor(.yellow)

                Text("Suggestion")
                    .typography(.caption2, theme: .system)
                    .foregroundColor(theme.colors.onSurfaceVariant)
            }

            Text(suggestion.reasoning)
                .typography(.caption1, theme: .system)
                .foregroundColor(theme.colors.onSurface)
                .lineLimit(2)

            HStack(spacing: 4) {
                Image(systemName: "heart")
                    .font(.caption2)
                    .foregroundColor(theme.colors.onSurfaceVariant)

                Text("\(suggestion.likeCount)")
                    .typography(.caption2, theme: .system)
                    .foregroundColor(theme.colors.onSurfaceVariant)
            }
        }
        .padding(8)
        .frame(width: 120)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(theme.colors.surfaceVariant.opacity(0.5))
        )
    }
}

// MARK: - Comment Input View
struct CommentInputView: View {
    @Binding var newCommentText: String
    @Binding var replyingToComment: Comment?
    var isCommentFieldFocused: FocusState<Bool>.Binding
    let onSubmit: () -> Void
    let onCancelReply: () -> Void
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: 0) {
            // Reply indicator
            if let replyingComment = replyingToComment {
                HStack {
                    Text("Replying to @username") // Would get from comment author
                        .typography(.caption1, theme: .system)
                        .foregroundColor(theme.colors.onSurfaceVariant)

                    Spacer()

                    Button("Cancel", action: onCancelReply)
                        .typography(.caption1, theme: .system)
                        .foregroundColor(theme.colors.primary)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(theme.colors.surfaceVariant.opacity(0.5))
            }

            HStack(spacing: 12) {
                // Profile Picture
                Circle()
                    .fill(theme.colors.surfaceVariant)
                    .frame(width: 32, height: 32)
                    .overlay(
                        Image(systemName: "person.crop.circle.fill")
                            .font(.title3)
                            .foregroundColor(theme.colors.onSurfaceVariant)
                    )

                // Text Input
                HStack {
                    TextField("Add a comment...", text: $newCommentText, axis: .vertical)
                        .focused(isCommentFieldFocused)
                        .typography(.body2, theme: .system)
                        .foregroundColor(theme.colors.onSurface)
                        .lineLimit(1...4)

                    Button(action: onSubmit) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title2)
                            .foregroundColor(
                                newCommentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                ? theme.colors.onSurfaceVariant
                                : theme.colors.primary
                            )
                    }
                    .disabled(newCommentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(theme.colors.surfaceVariant)
                )
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(theme.colors.surface)
        }
    }
}

// MARK: - Loading and Empty States
struct CommentsLoadingView: View {
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: 16) {
            ForEach(0..<3, id: \.self) { _ in
                CommentSkeleton()
            }
        }
    }
}

struct CommentSkeleton: View {
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(theme.colors.surfaceVariant)
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 6) {
                Rectangle()
                    .fill(theme.colors.surfaceVariant)
                    .frame(width: 80, height: 12)

                Rectangle()
                    .fill(theme.colors.surfaceVariant)
                    .frame(height: 16)

                HStack {
                    Rectangle()
                        .fill(theme.colors.surfaceVariant)
                        .frame(width: 40, height: 10)

                    Rectangle()
                        .fill(theme.colors.surfaceVariant)
                        .frame(width: 30, height: 10)

                    Spacer()
                }
            }

            Spacer()
        }
        .padding(.horizontal)
        .shimmer()
    }
}

struct EmptyCommentsView: View {
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "bubble.left")
                .font(.system(size: 40))
                .foregroundColor(theme.colors.onSurfaceVariant)

            VStack(spacing: 4) {
                Text("No comments yet")
                    .typography(.heading4, theme: .modern)
                    .foregroundColor(theme.colors.onSurface)

                Text("Be the first to share your thoughts!")
                    .typography(.body2, theme: .system)
                    .foregroundColor(theme.colors.onSurfaceVariant)
            }
        }
        .padding()
    }
}

// MARK: - Comments Manager
@MainActor
class CommentsManager: ObservableObject {
    @Published var comments: [Comment] = []
    @Published var isLoading = false
    @Published var sortOrder: CommentSortOrder = .newest

    enum CommentSortOrder {
        case newest, oldest, top
    }

    func loadComments(for postId: UUID) {
        isLoading = true

        // Simulate loading
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.comments = self.generateMockComments()
            self.isLoading = false
        }
    }

    func addComment(_ comment: Comment) {
        comments.insert(comment, at: 0)
    }

    func addReply(_ reply: Comment, to commentId: UUID) {
        if let index = comments.firstIndex(where: { $0.id == commentId }) {
            comments[index].replies.append(reply)
            comments[index].replyCount += 1
        }
    }

    func updateCommentLike(_ commentId: UUID) {
        if let index = comments.firstIndex(where: { $0.id == commentId }) {
            comments[index].likeCount += 1
        }
    }

    func sortComments(by order: CommentSortOrder) {
        sortOrder = order

        switch order {
        case .newest:
            comments.sort { $0.createdAt > $1.createdAt }
        case .oldest:
            comments.sort { $0.createdAt < $1.createdAt }
        case .top:
            comments.sort { $0.likeCount > $1.likeCount }
        }
    }

    private func generateMockComments() -> [Comment] {
        var mockComments: [Comment] = []

        for i in 0..<8 {
            let comment = Comment(
                postID: UUID(),
                authorID: "user_\(i)",
                content: generateMockCommentContent(index: i),
                likeCount: Int.random(in: 0...50),
                replyCount: Int.random(in: 0...5),
                createdAt: Date().addingTimeInterval(-Double.random(in: 0...86400))
            )

            mockComments.append(comment)
        }

        return mockComments
    }

    private func generateMockCommentContent(index: Int) -> String {
        let comments = [
            "Love this outfit! 😍",
            "Where did you get that jacket?",
            "Such great style inspiration!",
            "The colors work so well together",
            "This is giving me major style goals ✨",
            "Perfect for the season!",
            "You always nail the accessories",
            "This look is everything! 🔥"
        ]

        return comments[index % comments.count]
    }
}