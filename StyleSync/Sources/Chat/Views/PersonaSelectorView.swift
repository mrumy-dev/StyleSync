import SwiftUI

struct PersonaSelectorView: View {
    @Binding var selectedPersona: AIPersona
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var hapticManager: HapticFeedbackManager
    
    @State private var searchText = ""
    @State private var selectedPersonaPreview: AIPersona?
    @State private var showingPersonaDetails = false
    
    var filteredPersonas: [AIPersona] {
        if searchText.isEmpty {
            return AIPersona.available
        } else {
            return AIPersona.available.filter { persona in
                persona.name.localizedCaseInsensitiveContains(searchText) ||
                persona.personality.rawValue.localizedCaseInsensitiveContains(searchText) ||
                persona.expertise.contains { $0.rawValue.localizedCaseInsensitiveContains(searchText) }
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                header
                
                // Search bar
                searchBar
                
                // Personas grid
                personasGrid
                
                // Preview section
                if let previewPersona = selectedPersonaPreview {
                    personaPreview(previewPersona)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .background(
                GradientMeshBackground(colors: themeManager.currentTheme.gradients.mesh)
                    .opacity(0.1)
            )
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showingPersonaDetails) {
            if let persona = selectedPersonaPreview {
                PersonaDetailsView(persona: persona, onSelect: selectPersona)
            }
        }
    }
    
    // MARK: - Header
    private var header: some View {
        HStack {
            Button("Cancel") {
                dismiss()
            }
            .foregroundColor(themeManager.currentTheme.colors.secondary)
            
            Spacer()
            
            Text("Choose Your AI Stylist")
                .typography(.heading4, theme: .modern)
                .foregroundColor(themeManager.currentTheme.colors.primary)
            
            Spacer()
            
            Button("Select") {
                if let persona = selectedPersonaPreview {
                    selectPersona(persona)
                }
            }
            .foregroundColor(themeManager.currentTheme.colors.accent)
            .fontWeight(.semibold)
            .disabled(selectedPersonaPreview == nil)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            themeManager.currentTheme.colors.surface
                .opacity(0.95)
                .glassmorphism(intensity: .light)
        )
    }
    
    // MARK: - Search Bar
    private var searchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(themeManager.currentTheme.colors.secondary)
            
            TextField("Search stylists...", text: $searchText)
                .textFieldStyle(.plain)
            
            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(themeManager.currentTheme.colors.secondary)
                }
                .tapWithHaptic(.light)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(themeManager.currentTheme.colors.surface.opacity(0.3))
                .glassmorphism(intensity: .light)
        )
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
    
    // MARK: - Personas Grid
    private var personasGrid: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 16),
                GridItem(.flexible(), spacing: 16)
            ], spacing: 16) {
                ForEach(filteredPersonas) { persona in
                    PersonaCardView(
                        persona: persona,
                        isSelected: selectedPersona.id == persona.id,
                        isPreview: selectedPersonaPreview?.id == persona.id,
                        onTap: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                if selectedPersonaPreview?.id == persona.id {
                                    selectedPersonaPreview = nil
                                } else {
                                    selectedPersonaPreview = persona
                                }
                            }
                            hapticManager.playHaptic(.light)
                        },
                        onDoubleTap: {
                            selectPersona(persona)
                        },
                        onLongPress: {
                            selectedPersonaPreview = persona
                            showingPersonaDetails = true
                            hapticManager.playHaptic(.medium)
                        }
                    )
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, selectedPersonaPreview != nil ? 200 : 20)
        }
    }
    
    // MARK: - Persona Preview
    private func personaPreview(_ persona: AIPersona) -> some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(persona.name)
                        .typography(.heading3, theme: .modern)
                        .foregroundColor(themeManager.currentTheme.colors.primary)
                    
                    Text(persona.personality.rawValue.capitalized)
                        .typography(.body2, theme: .modern)
                        .foregroundColor(themeManager.currentTheme.colors.accent)
                }
                
                Spacer()
                
                Image(systemName: persona.avatar)
                    .font(.largeTitle)
                    .foregroundColor(themeManager.currentTheme.colors.accent)
                    .frame(width: 50, height: 50)
                    .background(
                        Circle()
                            .fill(themeManager.currentTheme.colors.accent.opacity(0.1))
                    )
            }
            
            // Expertise tags
            FlowLayout(data: persona.expertise, spacing: 8) { expertise in
                Text(expertise.rawValue.capitalized)
                    .typography(.caption1, theme: .modern)
                    .foregroundColor(themeManager.currentTheme.colors.accent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(themeManager.currentTheme.colors.accent.opacity(0.1))
                            .overlay(
                                Capsule()
                                    .stroke(themeManager.currentTheme.colors.accent, lineWidth: 1)
                            )
                    )
            }
            
            // Communication style
            HStack {
                Text("Style:")
                    .typography(.caption1, theme: .modern)
                    .foregroundColor(themeManager.currentTheme.colors.secondary)
                
                Text(persona.communicationStyle.rawValue.capitalized)
                    .typography(.caption1, theme: .modern)
                    .foregroundColor(themeManager.currentTheme.colors.primary)
                    .fontWeight(.medium)
                
                Spacer()
                
                Text("Pattern:")
                    .typography(.caption1, theme: .modern)
                    .foregroundColor(themeManager.currentTheme.colors.secondary)
                
                Text(persona.responsePatterns.rawValue.capitalized)
                    .typography(.caption1, theme: .modern)
                    .foregroundColor(themeManager.currentTheme.colors.primary)
                    .fontWeight(.medium)
            }
            
            // Action buttons
            HStack(spacing: 12) {
                Button("More Details") {
                    showingPersonaDetails = true
                }
                .foregroundColor(themeManager.currentTheme.colors.secondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(themeManager.currentTheme.colors.surface.opacity(0.5))
                )
                .tapWithHaptic(.light)
                
                Spacer()
                
                Button("Select \(persona.name)") {
                    selectPersona(persona)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                colors: [
                                    themeManager.currentTheme.colors.accent,
                                    themeManager.currentTheme.colors.accent.opacity(0.8)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .tapWithHaptic(.medium)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(themeManager.currentTheme.colors.surface)
                .glassmorphism(intensity: .medium)
                .shadow(
                    color: themeManager.currentTheme.colors.accent.opacity(0.1),
                    radius: 20,
                    x: 0,
                    y: -10
                )
        )
        .padding(.horizontal, 20)
    }
    
    // MARK: - Actions
    private func selectPersona(_ persona: AIPersona) {
        selectedPersona = persona
        hapticManager.playHaptic(.success)
        dismiss()
    }
}

// MARK: - Persona Card View
struct PersonaCardView: View {
    let persona: AIPersona
    let isSelected: Bool
    let isPreview: Bool
    let onTap: () -> Void
    let onDoubleTap: () -> Void
    let onLongPress: () -> Void
    
    @EnvironmentObject private var themeManager: ThemeManager
    @State private var isPressed = false
    
    var body: some View {
        VStack(spacing: 12) {
            // Avatar
            Image(systemName: persona.avatar)
                .font(.largeTitle)
                .foregroundColor(isSelected ? .white : themeManager.currentTheme.colors.accent)
                .frame(width: 60, height: 60)
                .background(
                    Circle()
                        .fill(
                            isSelected ? themeManager.currentTheme.colors.accent :
                            themeManager.currentTheme.colors.accent.opacity(0.1)
                        )
                )
                .overlay(
                    Circle()
                        .stroke(
                            isSelected ? Color.clear : themeManager.currentTheme.colors.accent.opacity(0.3),
                            lineWidth: 2
                        )
                )
            
            // Name and personality
            VStack(spacing: 4) {
                Text(persona.name)
                    .typography(.body1, theme: .modern)
                    .foregroundColor(themeManager.currentTheme.colors.primary)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)
                
                Text(persona.personality.rawValue.capitalized)
                    .typography(.caption1, theme: .modern)
                    .foregroundColor(
                        isSelected ? themeManager.currentTheme.colors.accent :
                        themeManager.currentTheme.colors.secondary
                    )
            }
            
            // Top expertise
            if let topExpertise = persona.expertise.first {
                Text(topExpertise.rawValue.capitalized)
                    .typography(.caption2, theme: .modern)
                    .foregroundColor(themeManager.currentTheme.colors.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(themeManager.currentTheme.colors.accent.opacity(0.1))
                    )
            }
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    isSelected ? 
                    LinearGradient(
                        colors: [
                            themeManager.currentTheme.colors.accent.opacity(0.1),
                            themeManager.currentTheme.colors.accent.opacity(0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ) :
                    LinearGradient(
                        colors: [
                            themeManager.currentTheme.colors.surface,
                            themeManager.currentTheme.colors.surface.opacity(0.8)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .glassmorphism(intensity: isSelected ? .medium : .light)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(
                            isSelected ? themeManager.currentTheme.colors.accent :
                            (isPreview ? themeManager.currentTheme.colors.accent.opacity(0.5) : Color.clear),
                            lineWidth: isSelected ? 2 : (isPreview ? 1 : 0)
                        )
                )
        )
        .scaleEffect(isPressed ? 0.95 : (isPreview ? 1.02 : 1.0))
        .animation(.spring(response: 0.2, dampingFraction: 0.8), value: isPressed)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPreview)
        .onTapGesture(count: 2) {
            onDoubleTap()
        }
        .onTapGesture {
            onTap()
        }
        .onLongPressGesture(
            minimumDuration: 0.5,
            maximumDistance: 10
        ) {
            onLongPress()
        } onPressingChanged: { pressing in
            withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                isPressed = pressing
            }
        }
    }
}

// MARK: - Persona Details View
struct PersonaDetailsView: View {
    let persona: AIPersona
    let onSelect: (AIPersona) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var hapticManager: HapticFeedbackManager
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header section
                    headerSection
                    
                    // Personality section
                    personalitySection
                    
                    // Expertise section
                    expertiseSection
                    
                    // Communication style section
                    communicationSection
                    
                    // Example conversations
                    exampleConversationsSection
                    
                    // Select button
                    selectButton
                }
                .padding(20)
            }
            .background(
                GradientMeshBackground(colors: themeManager.currentTheme.gradients.mesh)
                    .opacity(0.1)
            )
            .navigationTitle("Stylist Details")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden()
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(themeManager.currentTheme.colors.secondary)
                }
            }
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        HStack(spacing: 20) {
            Image(systemName: persona.avatar)
                .font(.system(size: 60))
                .foregroundColor(themeManager.currentTheme.colors.accent)
                .frame(width: 100, height: 100)
                .background(
                    Circle()
                        .fill(themeManager.currentTheme.colors.accent.opacity(0.1))
                )
            
            VStack(alignment: .leading, spacing: 8) {
                Text(persona.name)
                    .typography(.heading2, theme: .modern)
                    .foregroundColor(themeManager.currentTheme.colors.primary)
                
                Text(persona.personality.rawValue.capitalized)
                    .typography(.body1, theme: .modern)
                    .foregroundColor(themeManager.currentTheme.colors.accent)
                    .fontWeight(.medium)
                
                Text("AI Styling Assistant")
                    .typography(.caption1, theme: .modern)
                    .foregroundColor(themeManager.currentTheme.colors.secondary)
            }
            
            Spacer()
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(themeManager.currentTheme.colors.surface)
                .glassmorphism(intensity: .light)
        )
    }
    
    // MARK: - Personality Section
    private var personalitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Personality")
                .typography(.heading4, theme: .modern)
                .foregroundColor(themeManager.currentTheme.colors.primary)
            
            Text(getPersonalityDescription(persona.personality))
                .typography(.body2, theme: .modern)
                .foregroundColor(themeManager.currentTheme.colors.secondary)
                .lineSpacing(4)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(themeManager.currentTheme.colors.surface.opacity(0.5))
        )
    }
    
    // MARK: - Expertise Section
    private var expertiseSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Expertise")
                .typography(.heading4, theme: .modern)
                .foregroundColor(themeManager.currentTheme.colors.primary)
            
            FlowLayout(data: persona.expertise, spacing: 8) { expertise in
                HStack(spacing: 6) {
                    Image(systemName: getExpertiseIcon(expertise))
                        .font(.caption)
                        .foregroundColor(themeManager.currentTheme.colors.accent)
                    
                    Text(expertise.rawValue.capitalized)
                        .typography(.caption1, theme: .modern)
                        .foregroundColor(themeManager.currentTheme.colors.primary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(themeManager.currentTheme.colors.accent.opacity(0.1))
                        .overlay(
                            Capsule()
                                .stroke(themeManager.currentTheme.colors.accent, lineWidth: 1)
                        )
                )
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(themeManager.currentTheme.colors.surface.opacity(0.5))
        )
    }
    
    // MARK: - Communication Section
    private var communicationSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Communication Style")
                .typography(.heading4, theme: .modern)
                .foregroundColor(themeManager.currentTheme.colors.primary)
            
            VStack(spacing: 12) {
                HStack {
                    Text("Style:")
                        .typography(.body2, theme: .modern)
                        .foregroundColor(themeManager.currentTheme.colors.secondary)
                    
                    Spacer()
                    
                    Text(persona.communicationStyle.rawValue.capitalized)
                        .typography(.body2, theme: .modern)
                        .foregroundColor(themeManager.currentTheme.colors.primary)
                        .fontWeight(.medium)
                }
                
                HStack {
                    Text("Response Pattern:")
                        .typography(.body2, theme: .modern)
                        .foregroundColor(themeManager.currentTheme.colors.secondary)
                    
                    Spacer()
                    
                    Text(persona.responsePatterns.rawValue.capitalized)
                        .typography(.body2, theme: .modern)
                        .foregroundColor(themeManager.currentTheme.colors.primary)
                        .fontWeight(.medium)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(themeManager.currentTheme.colors.surface.opacity(0.5))
        )
    }
    
    // MARK: - Example Conversations
    private var exampleConversationsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Example Conversations")
                .typography(.heading4, theme: .modern)
                .foregroundColor(themeManager.currentTheme.colors.primary)
            
            VStack(spacing: 16) {
                ForEach(getExampleConversations(persona), id: \.question) { example in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "person.circle.fill")
                                .foregroundColor(themeManager.currentTheme.colors.secondary)
                            
                            Text("You:")
                                .typography(.caption1, theme: .modern)
                                .foregroundColor(themeManager.currentTheme.colors.secondary)
                            
                            Spacer()
                        }
                        
                        Text(example.question)
                            .typography(.body2, theme: .modern)
                            .foregroundColor(themeManager.currentTheme.colors.primary)
                            .padding(.leading, 24)
                        
                        HStack {
                            Image(systemName: persona.avatar)
                                .foregroundColor(themeManager.currentTheme.colors.accent)
                            
                            Text("\(persona.name):")
                                .typography(.caption1, theme: .modern)
                                .foregroundColor(themeManager.currentTheme.colors.accent)
                            
                            Spacer()
                        }
                        
                        Text(example.response)
                            .typography(.body2, theme: .modern)
                            .foregroundColor(themeManager.currentTheme.colors.secondary)
                            .padding(.leading, 24)
                            .italic()
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(themeManager.currentTheme.colors.surface.opacity(0.3))
                    )
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(themeManager.currentTheme.colors.surface.opacity(0.5))
        )
    }
    
    // MARK: - Select Button
    private var selectButton: some View {
        Button(action: {
            onSelect(persona)
            hapticManager.playHaptic(.success)
        }) {
            HStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                Text("Choose \(persona.name) as My Stylist")
                    .fontWeight(.semibold)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [
                                themeManager.currentTheme.colors.accent,
                                themeManager.currentTheme.colors.accent.opacity(0.8)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
        }
        .tapWithHaptic(.medium)
    }
    
    // MARK: - Helper Methods
    private func getPersonalityDescription(_ personality: PersonalityType) -> String {
        switch personality {
        case .friendly:
            return "Warm, approachable, and encouraging. I love making fashion fun and accessible while building your confidence."
        case .professional:
            return "Polished, knowledgeable, and detail-oriented. I provide expert advice with a focus on sophisticated styling solutions."
        case .creative:
            return "Innovative, artistic, and bold. I enjoy pushing boundaries and helping you discover unique, expressive looks."
        case .casual:
            return "Relaxed, easy-going, and down-to-earth. I keep things simple while helping you look effortlessly stylish."
        case .expert:
            return "Analytical, precise, and thorough. I provide data-driven recommendations with detailed explanations and technical insights."
        }
    }
    
    private func getExpertiseIcon(_ expertise: ExpertiseArea) -> String {
        switch expertise {
        case .styling: return "paintbrush.pointed.fill"
        case .colors: return "paintpalette.fill"
        case .trends: return "chart.line.uptrend.xyaxis"
        case .formalWear: return "suit.fill"
        case .business: return "briefcase.fill"
        case .luxury: return "crown.fill"
        case .artistic: return "paintbrush.pointed"
        case .experimental: return "flask.fill"
        case .vintage: return "clock.fill"
        case .bodyType: return "figure.arms.open"
        case .seasons: return "leaf.fill"
        }
    }
    
    private func getExampleConversations(_ persona: AIPersona) -> [(question: String, response: String)] {
        switch persona.personality {
        case .friendly:
            return [
                (
                    question: "I have a date tonight and I'm so nervous! What should I wear?",
                    response: "Oh how exciting! 😊 Don't worry, we'll find you the perfect outfit! Tell me about the venue - is it casual or more upscale? I'm thinking something that makes you feel confident and comfortable!"
                ),
                (
                    question: "Does this color look good on me?",
                    response: "That color is absolutely beautiful on you! It really brings out your eyes and complements your skin tone perfectly. You have such great instincts! ✨"
                )
            ]
        case .professional:
            return [
                (
                    question: "I need help with my work wardrobe.",
                    response: "I'd be happy to assist with your professional wardrobe development. Let's assess your current pieces and identify key investment items that will maximize versatility and maintain appropriate business standards."
                ),
                (
                    question: "What's the best way to dress for my body type?",
                    response: "The optimal approach involves understanding your proportions and selecting silhouettes that create visual balance. I recommend focusing on fit quality and strategic color placement to achieve your desired aesthetic."
                )
            ]
        case .creative:
            return [
                (
                    question: "I want to try something completely different!",
                    response: "YES! I absolutely love this energy! ✨ Let's break some fashion rules and create something totally unique. What if we mixed unexpected textures or tried bold color blocking? The possibilities are endless!"
                ),
                (
                    question: "Is this outfit too weird?",
                    response: "\"Weird\" is just another word for wonderfully unique! I see so much creativity in your choices. Let's lean into what makes you different - that's where the magic happens! 🎨"
                )
            ]
        case .casual:
            return [
                (
                    question: "I need something simple for everyday.",
                    response: "Totally get it! Let's keep things easy and comfy. How about a nice pair of jeans with a soft tee and a cardigan? Throw on some sneakers and you're good to go!"
                ),
                (
                    question: "I don't know much about fashion...",
                    response: "No worries at all! Fashion doesn't have to be complicated. Let's start with the basics and build from there. You'll be surprised how great you can look with just a few simple pieces!"
                )
            ]
        case .expert:
            return [
                (
                    question: "Why do certain colors work better on me?",
                    response: "Color harmony depends on your undertones, contrast levels, and chromatic compatibility. Based on seasonal color analysis principles, your optimal palette aligns with specific temperature and saturation parameters."
                ),
                (
                    question: "What makes a good fit?",
                    response: "Proper fit involves precise measurements at key points: shoulder seams, bust/chest, waist, and hem lengths. The garment should follow your natural lines without restriction or excess fabric pooling."
                )
            ]
        }
    }
}

// MARK: - Flow Layout for Tags
struct FlowLayout<Data: RandomAccessCollection, Content: View>: View where Data.Element: Hashable {
    let data: Data
    let spacing: CGFloat
    let content: (Data.Element) -> Content
    
    var body: some View {
        GeometryReader { geometry in
            self.generateContent(in: geometry)
        }
    }
    
    private func generateContent(in geometry: GeometryProxy) -> some View {
        var width: CGFloat = 0
        var height: CGFloat = 0
        
        return ZStack(alignment: .topLeading) {
            ForEach(Array(data.enumerated()), id: \.element) { index, item in
                content(item)
                    .alignmentGuide(.leading, computeValue: { d in
                        if (abs(width - d.width) > geometry.size.width) {
                            width = 0
                            height -= d.height + spacing
                        }
                        let result = width
                        if index == data.count - 1 {
                            width = 0 // last item
                        } else {
                            width -= d.width + spacing
                        }
                        return result
                    })
                    .alignmentGuide(.top, computeValue: { _ in
                        let result = height
                        if index == data.count - 1 {
                            height = 0 // last item
                        }
                        return result
                    })
            }
        }
        .frame(minHeight: 44) // Minimum height for proper display
    }
}