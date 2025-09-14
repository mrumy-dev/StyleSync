import SwiftUI

struct OutfitPlanningView: View {
    let event: CalendarEvent
    let weather: WeatherForecast?
    let existingOutfit: PlannedOutfit?
    let onOutfitSelected: (PlannedOutfit) -> Void

    @Environment(\.dismiss) private var dismiss
    @StateObject private var outfitPlanner = SmartOutfitPlanner()
    @State private var suggestedOutfits: [PlannedOutfit] = []
    @State private var selectedOutfit: PlannedOutfit?
    @State private var isLoading = true
    @State private var showingCustomization = false

    var body: some View {
        NavigationStack {
            VStack {
                if isLoading {
                    loadingView
                } else {
                    planningContent
                }
            }
            .navigationTitle("Plan Outfit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        if let outfit = selectedOutfit {
                            onOutfitSelected(outfit)
                            dismiss()
                        }
                    }
                    .disabled(selectedOutfit == nil)
                }
            }
            .task {
                await loadOutfitSuggestions()
            }
            .sheet(isPresented: $showingCustomization) {
                if let outfit = selectedOutfit {
                    OutfitCustomizationView(outfit: outfit) { customizedOutfit in
                        selectedOutfit = customizedOutfit
                    }
                }
            }
        }
    }

    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.2)

            Text("Finding the perfect outfit...")
                .font(.headline)
                .foregroundColor(.secondary)

            Text("Considering weather, occasion, and your style preferences")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    private var planningContent: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Event details
                eventDetailsSection

                // Weather considerations
                if let weather = weather {
                    weatherSection(weather)
                }

                // Event-specific tips
                eventTipsSection

                // Suggested outfits
                suggestedOutfitsSection
            }
            .padding()
        }
    }

    private var eventDetailsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Event Details")
                .font(.headline)
                .fontWeight(.medium)

            EventSummaryCard(event: event)
        }
    }

    private func weatherSection(_ weather: WeatherForecast) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Weather Considerations")
                .font(.headline)
                .fontWeight(.medium)

            WeatherConsiderationsCard(weather: weather)
        }
    }

    private var eventTipsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Styling Tips")
                .font(.headline)
                .fontWeight(.medium)

            EventSpecificTipsCard(event: event)
        }
    }

    private var suggestedOutfitsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Suggested Outfits")
                    .font(.headline)
                    .fontWeight(.medium)

                Spacer()

                Text("\(suggestedOutfits.count) options")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            LazyVStack(spacing: 16) {
                ForEach(suggestedOutfits) { outfit in
                    OutfitOptionCard(
                        outfit: outfit,
                        event: event,
                        isSelected: selectedOutfit?.id == outfit.id
                    ) {
                        selectedOutfit = outfit
                    } onCustomize: {
                        selectedOutfit = outfit
                        showingCustomization = true
                    }
                }
            }
        }
    }

    private func loadOutfitSuggestions() async {
        isLoading = true

        // If we have an existing outfit, include it as the first option
        var outfits: [PlannedOutfit] = []
        if let existing = existingOutfit {
            outfits.append(existing)
        }

        // Generate new suggestions
        let newOutfits = await generateMultipleSuggestions()
        outfits.append(contentsOf: newOutfits)

        suggestedOutfits = outfits
        selectedOutfit = outfits.first

        isLoading = false
    }

    private func generateMultipleSuggestions() async -> [PlannedOutfit] {
        var suggestions: [PlannedOutfit] = []

        // Generate multiple outfit variations
        for _ in 0..<3 {
            let outfit = await outfitPlanner.suggestOutfit(
                for: event,
                weather: weather,
                previousOutfits: suggestions
            )
            suggestions.append(outfit)
        }

        return suggestions
    }
}

struct EventSummaryCard: View {
    let event: CalendarEvent

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(event.title)
                        .font(.headline)
                        .fontWeight(.medium)

                    HStack(spacing: 12) {
                        Label(DateFormatter.dateAndTime.string(from: event.startDate), systemImage: "clock")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        if let location = event.location {
                            Label(location, systemImage: "location")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                }

                Spacer()

                VStack(spacing: 4) {
                    eventTypeIcon(event.eventType)
                        .font(.title2)
                        .foregroundColor(eventTypeColor(event.eventType))

                    Text(event.eventType.rawValue)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }

            // Dress code and importance
            HStack {
                DressCodeBadge(dressCode: event.dressCode)
                ImportanceBadge(importance: event.importance)

                Spacer()

                if event.isVideoCall {
                    VideCallBadge()
                }
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
    }

    private func eventTypeIcon(_ type: EventType) -> Image {
        switch type {
        case .workMeeting: return Image(systemName: "briefcase.fill")
        case .videoCall: return Image(systemName: "video.fill")
        case .jobInterview: return Image(systemName: "person.badge.plus.fill")
        case .dateNight: return Image(systemName: "heart.fill")
        case .specialEvent: return Image(systemName: "sparkles")
        case .fitness: return Image(systemName: "figure.walk")
        case .travel: return Image(systemName: "airplane")
        case .casual: return Image(systemName: "person.fill")
        }
    }

    private func eventTypeColor(_ type: EventType) -> Color {
        switch type {
        case .workMeeting: return .blue
        case .videoCall: return .purple
        case .jobInterview: return .green
        case .dateNight: return .pink
        case .specialEvent: return .orange
        case .fitness: return .mint
        case .travel: return .cyan
        case .casual: return .gray
        }
    }
}

struct DressCodeBadge: View {
    let dressCode: DressCode

    var body: some View {
        Text(dressCode.rawValue)
            .font(.caption)
            .fontWeight(.medium)
            .foregroundColor(.blue)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.blue.opacity(0.1))
            .clipShape(Capsule())
    }
}

struct ImportanceBadge: View {
    let importance: EventImportance

    var body: some View {
        Text(importance.rawValue.uppercased())
            .font(.caption2)
            .fontWeight(.bold)
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(importance.color)
            .clipShape(Capsule())
    }
}

struct VideCallBadge: View {
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "video")
                .font(.caption)
            Text("Video Call")
                .font(.caption)
                .fontWeight(.medium)
        }
        .foregroundColor(.purple)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.purple.opacity(0.1))
        .clipShape(Capsule())
    }
}

struct WeatherConsiderationsCard: View {
    let weather: WeatherForecast

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: weatherIcon(weather.condition))
                    .font(.title2)
                    .foregroundColor(.blue)

                VStack(alignment: .leading, spacing: 2) {
                    Text(weather.condition.rawValue)
                        .font(.headline)
                        .fontWeight(.medium)

                    Text("\(Int(weather.temperature))°C")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if weather.precipitationChance > 30 {
                    VStack(alignment: .trailing, spacing: 2) {
                        HStack {
                            Image(systemName: "drop.fill")
                                .foregroundColor(.blue)
                            Text("\(weather.precipitationChance)%")
                                .fontWeight(.medium)
                        }
                        .font(.subheadline)

                        Text("Rain chance")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            // Weather recommendations
            weatherRecommendations
        }
        .padding(16)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
    }

    private var weatherRecommendations: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recommendations:")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 6) {
                ForEach(getWeatherRecommendations(), id: \.self) { recommendation in
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.green)

                        Text(recommendation)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }

    private func weatherIcon(_ condition: WeatherCondition) -> String {
        switch condition {
        case .sunny: return "sun.max.fill"
        case .partlyCloudy: return "cloud.sun.fill"
        case .cloudy: return "cloud.fill"
        case .rainy: return "cloud.rain.fill"
        case .stormy: return "cloud.bolt.fill"
        case .snowy: return "cloud.snow.fill"
        case .foggy: return "cloud.fog.fill"
        }
    }

    private func getWeatherRecommendations() -> [String] {
        var recommendations: [String] = []

        if weather.temperature < 10 {
            recommendations.append("Layer with warm outerwear")
            recommendations.append("Choose closed-toe shoes")
        } else if weather.temperature > 25 {
            recommendations.append("Opt for breathable fabrics")
            recommendations.append("Light colors help stay cool")
        }

        if weather.precipitationChance > 50 {
            recommendations.append("Bring an umbrella")
            recommendations.append("Avoid suede or delicate materials")
        }

        if weather.windSpeed > 20 {
            recommendations.append("Secure accessories and scarves")
        }

        return recommendations
    }
}

struct EventSpecificTipsCard: View {
    let event: CalendarEvent

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(.yellow)

                Text("Pro Tips")
                    .font(.headline)
                    .fontWeight(.medium)
            }

            VStack(alignment: .leading, spacing: 8) {
                ForEach(getEventTips(), id: \.self) { tip in
                    HStack(alignment: .top) {
                        Image(systemName: "arrow.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.top, 2)

                        Text(tip)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
    }

    private func getEventTips() -> [String] {
        switch event.eventType {
        case .videoCall:
            return [
                "Focus on upper body - choose solid colors",
                "Avoid busy patterns that can cause visual distortion",
                "Consider your background and lighting",
                "Test your outfit on camera beforehand"
            ]

        case .jobInterview:
            return [
                "Choose conservative, well-fitted pieces",
                "Stick to neutral colors like navy, charcoal, or black",
                "Ensure shoes are polished and professional",
                "Keep accessories minimal and classic"
            ]

        case .dateNight:
            return [
                "Choose something that makes you feel confident",
                "Consider the venue and activity level",
                "Add a special touch with accessories or shoes",
                "Make sure you're comfortable for the entire evening"
            ]

        case .workMeeting:
            return [
                "Dress for the level you want to be at",
                "Ensure clothes are wrinkle-free and well-fitted",
                "Choose pieces that allow easy movement",
                "Consider the meeting's importance and attendees"
            ]

        case .specialEvent:
            return [
                "Check if there's a specific dress code",
                "Choose something photograph-ready",
                "Consider the event's formality and venue",
                "Add personal touches to stand out appropriately"
            ]

        default:
            return [
                "Choose appropriate attire for the occasion",
                "Ensure comfort for the event duration",
                "Consider weather and venue requirements"
            ]
        }
    }
}

struct OutfitOptionCard: View {
    let outfit: PlannedOutfit
    let event: CalendarEvent
    let isSelected: Bool
    let onSelect: () -> Void
    let onCustomize: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Selection indicator and confidence
            HStack {
                Button(action: onSelect) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.title2)
                        .foregroundColor(isSelected ? .blue : .secondary)
                }
                .buttonStyle(PlainButtonStyle())

                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text("Option \(outfit.items.count > 0 ? "A" : "B")")
                            .font(.headline)
                            .fontWeight(.medium)

                        Spacer()

                        ConfidenceIndicator(confidence: outfit.confidence)
                    }

                    if !outfit.reasoning.isEmpty {
                        Text(outfit.reasoning.first ?? "")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                }
            }

            // Outfit visualization
            OutfitVisualization(items: outfit.items)

            // Outfit details
            outfitDetails

            // Action buttons
            HStack {
                Button("Customize") {
                    onCustomize()
                }
                .buttonStyle(.bordered)

                Spacer()

                if isSelected {
                    Text("Selected")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.blue)
                }
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.blue : Color(.systemGray4), lineWidth: isSelected ? 2 : 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.1), radius: isSelected ? 6 : 2, y: isSelected ? 4 : 1)
        .animation(.spring(response: 0.3), value: isSelected)
    }

    private var outfitDetails: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !outfit.items.isEmpty {
                Text("Items:")
                    .font(.subheadline)
                    .fontWeight(.medium)

                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 4) {
                    ForEach(outfit.items.prefix(4), id: \.id) { item in
                        HStack {
                            Text("•")
                                .foregroundColor(.secondary)
                            Text(item.name)
                                .font(.caption)
                                .lineLimit(1)
                            Spacer()
                        }
                    }

                    if outfit.items.count > 4 {
                        Text("+ \(outfit.items.count - 4) more items")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            if !outfit.weatherConsiderations.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Weather Notes:")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.blue)

                    ForEach(outfit.weatherConsiderations, id: \.self) { note in
                        Text("• \(note)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
}

struct ConfidenceIndicator: View {
    let confidence: Double

    var body: some View {
        HStack(spacing: 4) {
            Text("\(Int(confidence * 100))%")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(confidenceColor)

            Text("match")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(confidenceColor.opacity(0.1))
        .clipShape(Capsule())
    }

    private var confidenceColor: Color {
        if confidence >= 0.8 { return .green }
        if confidence >= 0.6 { return .orange }
        return .red
    }
}

struct OutfitVisualization: View {
    let items: [WardrobeItem]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(items, id: \.id) { item in
                    OutfitItemView(item: item)
                }
            }
            .padding(.horizontal)
        }
        .padding(.horizontal, -16)
    }
}

struct OutfitItemView: View {
    let item: WardrobeItem

    var body: some View {
        VStack(spacing: 6) {
            // Item visualization
            RoundedRectangle(cornerRadius: 8)
                .fill(colorForItem(item))
                .frame(width: 60, height: 60)
                .overlay(
                    Image(systemName: iconForCategory(item.category))
                        .font(.title3)
                        .foregroundColor(.white)
                )

            Text(item.name)
                .font(.caption2)
                .fontWeight(.medium)
                .lineLimit(2)
                .multilineTextAlignment(.center)

            Text(item.color)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(width: 80)
    }

    private func colorForItem(_ item: WardrobeItem) -> Color {
        switch item.color.lowercased() {
        case "black": return .black
        case "white": return .gray.opacity(0.3)
        case "navy": return .blue
        case "red": return .red
        case "green": return .green
        case "blue": return .blue
        case "brown": return .brown
        case "gray", "grey": return .gray
        default: return .purple
        }
    }

    private func iconForCategory(_ category: String) -> String {
        switch category.lowercased() {
        case "tops", "shirts": return "t.shirt"
        case "bottoms", "pants": return "p.circle"
        case "dresses": return "d.circle"
        case "outerwear", "jackets": return "j.circle"
        case "shoes": return "shoe.2"
        case "accessories": return "a.circle"
        default: return "tshirt"
        }
    }
}

struct OutfitCustomizationView: View {
    let outfit: PlannedOutfit
    let onCustomizationComplete: (PlannedOutfit) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var customizedItems: [WardrobeItem]

    init(outfit: PlannedOutfit, onCustomizationComplete: @escaping (PlannedOutfit) -> Void) {
        self.outfit = outfit
        self.onCustomizationComplete = onCustomizationComplete
        self._customizedItems = State(initialValue: outfit.items)
    }

    var body: some View {
        NavigationStack {
            VStack {
                Text("Customize Your Outfit")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding()

                // Outfit customization interface
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(customizedItems, id: \.id) { item in
                            ItemCustomizationRow(item: item) { newItem in
                                if let index = customizedItems.firstIndex(where: { $0.id == item.id }) {
                                    customizedItems[index] = newItem
                                }
                            }
                        }
                    }
                    .padding()
                }

                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        let customizedOutfit = PlannedOutfit(
                            id: outfit.id,
                            eventId: outfit.eventId,
                            eventType: outfit.eventType,
                            dressCode: outfit.dressCode,
                            items: customizedItems,
                            confidence: outfit.confidence,
                            reasoning: outfit.reasoning,
                            weatherConsiderations: outfit.weatherConsiderations,
                            alternatives: outfit.alternatives,
                            createdAt: outfit.createdAt,
                            eventDate: outfit.eventDate
                        )
                        onCustomizationComplete(customizedOutfit)
                        dismiss()
                    }
                }
            }
        }
    }
}

struct ItemCustomizationRow: View {
    let item: WardrobeItem
    let onItemChange: (WardrobeItem) -> Void

    var body: some View {
        HStack {
            OutfitItemView(item: item)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(item.category)
                    .font(.caption)
                    .foregroundColor(.secondary)

                Button("Change") {
                    // Show item picker
                }
                .font(.caption)
                .buttonStyle(.bordered)
            }

            Spacer()
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

extension DateFormatter {
    static let dateAndTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}

#Preview {
    OutfitPlanningView(
        event: CalendarEvent(
            id: "preview",
            title: "Important Client Meeting",
            startDate: Date(),
            endDate: Date().addingTimeInterval(3600),
            location: "Office Conference Room",
            isAllDay: false,
            eventType: .workMeeting,
            dressCode: .businessCasual,
            importance: .high,
            isVideoCall: false,
            attendeeCount: 8,
            notes: "Quarterly review presentation"
        ),
        weather: WeatherForecast(
            condition: .partlyCloudy,
            temperature: 18,
            precipitationChance: 20,
            humidity: 65,
            windSpeed: 12
        ),
        existingOutfit: nil
    ) { _ in
        // Preview action
    }
}