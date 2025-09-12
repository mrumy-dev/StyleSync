import SwiftUI

struct MessageBubbleView: View {
    let message: ChatMessage
    let onReaction: (String) -> Void
    let onReply: (UUID) -> Void
    
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var hapticManager: HapticFeedbackManager
    @State private var showingReactions = false
    @State private var showingContextMenu = false
    @State private var isPressed = false
    
    private var isFromUser: Bool {
        !message.sender.isAI
    }
    
    private var bubbleAlignment: HorizontalAlignment {
        isFromUser ? .trailing : .leading
    }
    
    private var bubbleGradient: LinearGradient {
        if isFromUser {
            return LinearGradient(
                colors: [
                    themeManager.currentTheme.colors.accent,
                    themeManager.currentTheme.colors.accent.opacity(0.8)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            return LinearGradient(
                colors: [
                    themeManager.currentTheme.colors.surface,
                    themeManager.currentTheme.colors.surface.opacity(0.9)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
    
    var body: some View {
        VStack(alignment: bubbleAlignment, spacing: 4) {
            // Reply indicator
            if let replyTo = message.replyTo {
                replyIndicator
                    .transition(.opacity.combined(with: .slide))
            }
            
            HStack {
                if isFromUser { Spacer(minLength: 50) }
                
                VStack(alignment: bubbleAlignment, spacing: 2) {
                    // Message content
                    messageBubble
                    
                    // Message metadata
                    messageMetadata
                        .transition(.opacity)
                }
                
                if !isFromUser { Spacer(minLength: 50) }
            }
            
            // Reactions
            if !message.reactions.isEmpty {
                reactionsView
                    .transition(.asymmetric(
                        insertion: .scale.combined(with: .opacity),
                        removal: .scale.combined(with: .opacity)
                    ))
            }
        }
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.spring(response: 0.2, dampingFraction: 0.8), value: isPressed)
        .onLongPressGesture(
            minimumDuration: 0.5,
            maximumDistance: 10
        ) {
            showContextMenu()
        } onPressingChanged: { pressing in
            withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                isPressed = pressing
            }
        }
        .contextMenu {
            contextMenuItems
        }
        .overlay(
            reactionOverlay
        )
    }
    
    // MARK: - Message Bubble
    private var messageBubble: some View {
        VStack(alignment: .leading, spacing: 8) {
            // AI persona indicator (for AI messages)
            if !isFromUser {
                HStack(spacing: 6) {
                    Image(systemName: message.sender.avatar)
                        .font(.caption2)
                        .foregroundColor(themeManager.currentTheme.colors.accent)
                    
                    Text(message.sender.displayName)
                        .typography(.caption1, theme: .modern)
                        .foregroundColor(themeManager.currentTheme.colors.secondary)
                }
            }
            
            // Message content based on type
            Group {
                switch message.content {
                case .text(let text):
                    textContent(text)
                case .voice(let voice):
                    voiceContent(voice)
                case .image(let image):
                    imageContent(image)
                case .outfit(let outfit):
                    outfitContent(outfit)
                case .sketch(let sketch):
                    sketchContent(sketch)
                case .color(let color):
                    colorContent(color)
                case .suggestion(let suggestion):
                    suggestionContent(suggestion)
                case .analysis(let analysis):
                    analysisContent(analysis)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(bubbleGradient)
                .glassmorphism(intensity: isFromUser ? .medium : .light)
                .shadow(
                    color: themeManager.currentTheme.colors.accent.opacity(0.2),
                    radius: 8,
                    x: isFromUser ? -2 : 2,
                    y: 2
                )
        )
        .overlay(
            // Shimmer effect for sending messages
            Group {
                if message.status == .sending {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.3),
                                    Color.clear,
                                    Color.white.opacity(0.3)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                        .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: false), value: message.status)
                }
            }
        )
    }
    
    // MARK: - Content Views
    private func textContent(_ text: String) -> some View {
        Text(text)
            .typography(.body1, theme: .modern)
            .foregroundColor(isFromUser ? .white : themeManager.currentTheme.colors.primary)
            .multilineTextAlignment(isFromUser ? .trailing : .leading)
    }
    
    private func voiceContent(_ voice: VoiceMessage) -> some View {
        HStack(spacing: 12) {
            Button(action: { /* Play voice */ }) {
                Image(systemName: "play.circle.fill")
                    .font(.title2)
                    .foregroundColor(isFromUser ? .white : themeManager.currentTheme.colors.accent)
            }
            
            // Waveform visualization
            HStack(spacing: 2) {
                ForEach(Array(voice.waveform.prefix(20).enumerated()), id: \.offset) { index, amplitude in
                    RoundedRectangle(cornerRadius: 1)
                        .fill(isFromUser ? Color.white.opacity(0.7) : themeManager.currentTheme.colors.accent)
                        .frame(width: 3, height: CGFloat(amplitude * 30 + 5))
                }
            }
            
            Text(formatDuration(voice.duration))
                .typography(.caption1, theme: .modern)
                .foregroundColor(isFromUser ? .white.opacity(0.7) : themeManager.currentTheme.colors.secondary)
        }
    }
    
    private func imageContent(_ image: ImageMessage) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Image preview
            AsyncImage(url: URL(string: "data:image/jpeg;base64,\(image.imageData.base64EncodedString())")) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(maxWidth: 200, maxHeight: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                case .failure(_):
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 200, height: 200)
                        .overlay(
                            Image(systemName: "photo")
                                .foregroundColor(.gray)
                        )
                case .empty:
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 200, height: 200)
                        .overlay(ProgressView())
                @unknown default:
                    EmptyView()
                }
            }
            
            if let caption = image.caption {
                Text(caption)
                    .typography(.body2, theme: .modern)
                    .foregroundColor(isFromUser ? .white : themeManager.currentTheme.colors.primary)
            }
            
            if image.isOutfit, let analysis = image.analysisResults {
                analysisPreview(analysis)
            }
        }
    }
    
    private func outfitContent(_ outfit: OutfitMessage) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "tshirt.fill")
                    .foregroundColor(isFromUser ? .white : themeManager.currentTheme.colors.accent)
                
                Text("Outfit Suggestion")
                    .typography(.body1, theme: .modern)
                    .foregroundColor(isFromUser ? .white : themeManager.currentTheme.colors.primary)
                    .fontWeight(.semibold)
            }
            
            Text("\(outfit.style) for \(outfit.occasion)")
                .typography(.body2, theme: .modern)
                .foregroundColor(isFromUser ? .white.opacity(0.8) : themeManager.currentTheme.colors.secondary)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(outfit.items.prefix(4)) { item in
                    outfitItemView(item)
                }
            }
            
            ConfidenceBar(confidence: outfit.confidence, color: isFromUser ? .white : themeManager.currentTheme.colors.accent)
        }
    }
    
    private func sketchContent(_ sketch: SketchMessage) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "pencil.tip")
                    .foregroundColor(isFromUser ? .white : themeManager.currentTheme.colors.accent)
                
                Text("Sketch")
                    .typography(.body1, theme: .modern)
                    .foregroundColor(isFromUser ? .white : themeManager.currentTheme.colors.primary)
                    .fontWeight(.semibold)
            }
            
            // Sketch preview (simplified)
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white)
                .frame(width: 200, height: 150)
                .overlay(
                    Image(systemName: "scribble")
                        .font(.largeTitle)
                        .foregroundColor(themeManager.currentTheme.colors.accent)
                )
            
            if let description = sketch.description {
                Text(description)
                    .typography(.body2, theme: .modern)
                    .foregroundColor(isFromUser ? .white.opacity(0.8) : themeManager.currentTheme.colors.secondary)
            }
        }
    }
    
    private func colorContent(_ color: ColorMessage) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(color.color.color)
                .frame(width: 40, height: 40)
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.3), lineWidth: 2)
                )
            
            VStack(alignment: .leading, spacing: 2) {
                Text(color.colorName)
                    .typography(.body1, theme: .modern)
                    .foregroundColor(isFromUser ? .white : themeManager.currentTheme.colors.primary)
                    .fontWeight(.medium)
                
                if let season = color.season {
                    Text("\(season.rawValue.capitalized) Season")
                        .typography(.caption1, theme: .modern)
                        .foregroundColor(isFromUser ? .white.opacity(0.7) : themeManager.currentTheme.colors.secondary)
                }
            }
        }
    }
    
    private func suggestionContent(_ suggestion: SuggestionMessage) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(isFromUser ? .white : themeManager.currentTheme.colors.accent)
                
                Text(suggestion.title)
                    .typography(.body1, theme: .modern)
                    .foregroundColor(isFromUser ? .white : themeManager.currentTheme.colors.primary)
                    .fontWeight(.semibold)
            }
            
            Text(suggestion.description)
                .typography(.body2, theme: .modern)
                .foregroundColor(isFromUser ? .white.opacity(0.8) : themeManager.currentTheme.colors.secondary)
            
            ConfidenceBar(confidence: suggestion.confidence, color: isFromUser ? .white : themeManager.currentTheme.colors.accent)
            
            Button(action: { /* Handle suggestion action */ }) {
                Text("Try this")
                    .typography(.caption1, theme: .modern)
                    .foregroundColor(isFromUser ? themeManager.currentTheme.colors.accent : .white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(isFromUser ? .white : themeManager.currentTheme.colors.accent)
                    )
            }
            .tapWithHaptic(.light)
        }
    }
    
    private func analysisContent(_ analysis: AnalysisMessage) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(isFromUser ? .white : themeManager.currentTheme.colors.accent)
                
                Text("\(analysis.analysisType.rawValue.capitalized) Analysis")
                    .typography(.body1, theme: .modern)
                    .foregroundColor(isFromUser ? .white : themeManager.currentTheme.colors.primary)
                    .fontWeight(.semibold)
            }
            
            ForEach(analysis.results.prefix(3), id: \.category) { result in
                analysisResultView(result)
            }
            
            ConfidenceBar(confidence: analysis.confidence, color: isFromUser ? .white : themeManager.currentTheme.colors.accent)
        }
    }
    
    // MARK: - Helper Views
    private func outfitItemView(_ item: OutfitItem) -> some View {
        VStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 8)
                .fill(item.color.color)
                .frame(height: 30)
            
            Text(item.name)
                .typography(.caption2, theme: .modern)
                .foregroundColor(isFromUser ? .white.opacity(0.8) : themeManager.currentTheme.colors.secondary)
                .lineLimit(1)
        }
    }
    
    private func analysisPreview(_ analysis: VisualAnalysisResult) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if let bodyShape = analysis.bodyShape {
                Label(bodyShape, systemImage: "person.fill")
                    .typography(.caption1, theme: .modern)
                    .foregroundColor(isFromUser ? .white.opacity(0.8) : themeManager.currentTheme.colors.secondary)
            }
            
            if let colorSeason = analysis.colorSeason {
                Label(colorSeason, systemImage: "leaf.fill")
                    .typography(.caption1, theme: .modern)
                    .foregroundColor(isFromUser ? .white.opacity(0.8) : themeManager.currentTheme.colors.secondary)
            }
        }
    }
    
    private func analysisResultView(_ result: AnalysisResult) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(result.category)
                    .typography(.caption1, theme: .modern)
                    .foregroundColor(isFromUser ? .white : themeManager.currentTheme.colors.primary)
                    .fontWeight(.medium)
                
                Text(result.description)
                    .typography(.caption2, theme: .modern)
                    .foregroundColor(isFromUser ? .white.opacity(0.7) : themeManager.currentTheme.colors.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
            
            CircularProgressView(progress: result.score, color: isFromUser ? .white : themeManager.currentTheme.colors.accent)
                .frame(width: 24, height: 24)
        }
    }
    
    // MARK: - Message Metadata
    private var messageMetadata: some View {
        HStack(spacing: 4) {
            Text(formatTime(message.timestamp))
                .typography(.caption2, theme: .modern)
                .foregroundColor(themeManager.currentTheme.colors.secondary.opacity(0.7))
            
            if isFromUser {
                Image(systemName: message.status.icon)
                    .font(.caption2)
                    .foregroundColor(messageStatusColor)
            }
        }
    }
    
    private var messageStatusColor: Color {
        switch message.status {
        case .sending: return .gray
        case .sent: return .gray
        case .delivered: return .blue
        case .read: return .blue
        case .failed: return .red
        }
    }
    
    // MARK: - Reply Indicator
    private var replyIndicator: some View {
        HStack(spacing: 8) {
            if !isFromUser { Spacer() }
            
            Rectangle()
                .fill(themeManager.currentTheme.colors.accent)
                .frame(width: 3, height: 20)
            
            Text("Reply to message")
                .typography(.caption2, theme: .modern)
                .foregroundColor(themeManager.currentTheme.colors.secondary)
            
            if isFromUser { Spacer() }
        }
        .padding(.horizontal, 16)
    }
    
    // MARK: - Reactions
    private var reactionsView: some View {
        HStack {
            if isFromUser { Spacer() }
            
            HStack(spacing: 4) {
                ForEach(groupedReactions, id: \.emoji) { reaction in
                    reactionBubble(reaction)
                }
            }
            
            if !isFromUser { Spacer() }
        }
        .padding(.horizontal, 16)
    }
    
    private func reactionBubble(_ reaction: GroupedReaction) -> some View {
        HStack(spacing: 2) {
            Text(reaction.emoji)
                .font(.caption)
            
            if reaction.count > 1 {
                Text("\(reaction.count)")
                    .typography(.caption2, theme: .modern)
                    .foregroundColor(themeManager.currentTheme.colors.secondary)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(
            Capsule()
                .fill(themeManager.currentTheme.colors.surface.opacity(0.8))
                .overlay(
                    Capsule()
                        .stroke(themeManager.currentTheme.colors.accent.opacity(0.3), lineWidth: 1)
                )
        )
        .onTapGesture {
            onReaction(reaction.emoji)
        }
        .tapWithHaptic(.light)
    }
    
    private var groupedReactions: [GroupedReaction] {
        Dictionary(grouping: message.reactions, by: \.emoji)
            .map { GroupedReaction(emoji: $0.key, count: $0.value.count) }
            .sorted { $0.emoji < $1.emoji }
    }
    
    // MARK: - Reaction Overlay
    private var reactionOverlay: some View {
        Group {
            if showingReactions {
                HStack(spacing: 8) {
                    ForEach(MessageReaction.available, id: \.self) { emoji in
                        Button(emoji) {
                            onReaction(emoji)
                            withAnimation(.spring()) {
                                showingReactions = false
                            }
                        }
                        .font(.title2)
                        .scaleEffect(1.2)
                        .background(
                            Circle()
                                .fill(themeManager.currentTheme.colors.surface)
                                .frame(width: 44, height: 44)
                                .shadow(radius: 8)
                        )
                        .tapWithHaptic(.medium)
                    }
                }
                .padding()
                .background(
                    Capsule()
                        .fill(themeManager.currentTheme.colors.surface.opacity(0.95))
                        .glassmorphism(intensity: .medium)
                        .shadow(radius: 20)
                )
                .transition(.asymmetric(
                    insertion: .scale.combined(with: .opacity),
                    removal: .scale.combined(with: .opacity)
                ))
                .zIndex(1)
            }
        }
    }
    
    // MARK: - Context Menu
    private var contextMenuItems: some View {
        Group {
            Button("Reply", action: { onReply(message.id) })
            Button("Add Reaction", action: { 
                withAnimation(.spring()) {
                    showingReactions.toggle()
                }
            })
            Button("Copy", action: { copyMessage() })
            if message.sender.isAI {
                Button("Regenerate", action: { /* Regenerate response */ })
            }
            Button("Delete", role: .destructive, action: { /* Delete message */ })
        }
    }
    
    // MARK: - Helper Methods
    private func showContextMenu() {
        hapticManager.playHaptic(.medium)
        showingContextMenu = true
    }
    
    private func copyMessage() {
        UIPasteboard.general.string = message.content.displayText
        hapticManager.playHaptic(.light)
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Supporting Views
struct ConfidenceBar: View {
    let confidence: Float
    let color: Color
    
    var body: some View {
        HStack(spacing: 6) {
            Text("Confidence")
                .typography(.caption2, theme: .modern)
                .foregroundColor(color.opacity(0.7))
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(color.opacity(0.2))
                        .frame(height: 4)
                    
                    RoundedRectangle(cornerRadius: 2)
                        .fill(color)
                        .frame(width: geometry.size.width * CGFloat(confidence), height: 4)
                }
            }
            .frame(height: 4)
            
            Text("\(Int(confidence * 100))%")
                .typography(.caption2, theme: .modern)
                .foregroundColor(color.opacity(0.7))
        }
    }
}

struct CircularProgressView: View {
    let progress: Float
    let color: Color
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.2), lineWidth: 2)
            
            Circle()
                .trim(from: 0, to: CGFloat(progress))
                .stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
    }
}

struct GroupedReaction {
    let emoji: String
    let count: Int
}