import SwiftUI
import WidgetKit

@main
struct StyleSyncWidgets: WidgetBundle {
    var body: some Widget {
        TodaysOutfitWidget()
        WeatherOutfitWidget()
        OutfitCountdownWidget()
        StyleTipWidget()
        InteractiveOutfitWidget()
    }
}

struct InteractiveOutfitWidget: Widget {
    let kind: String = "InteractiveOutfitWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: InteractiveConfigurationIntent.self, provider: InteractiveProvider()) { entry in
            InteractiveOutfitWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Interactive Outfit")
        .description("Interactive outfit rating and suggestions with iOS 17 features")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

struct InteractiveEntry: TimelineEntry {
    let date: Date
    let configuration: InteractiveConfigurationIntent
    let outfitState: InteractiveOutfitState
}

struct InteractiveOutfitWidgetEntryView: View {
    var entry: InteractiveProvider.Entry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Rate & Refine")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)

                Spacer()

                if entry.outfitState.isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "sparkles")
                        .font(.title3)
                        .foregroundColor(.purple)
                }
            }

            if let currentOutfit = entry.outfitState.currentOutfit {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(currentOutfit.name)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)

                        Spacer()

                        HStack(spacing: 2) {
                            ForEach(1...5, id: \.self) { star in
                                Button(intent: QuickRateIntent(rating: star)) {
                                    Image(systemName: star <= currentOutfit.currentRating ? "star.fill" : "star")
                                        .font(.caption)
                                        .foregroundColor(star <= currentOutfit.currentRating ? .yellow : .gray)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 4), spacing: 4) {
                        ForEach(currentOutfit.items, id: \.id) { item in
                            Button(intent: ToggleItemIntent(itemId: item.id)) {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(item.isSelected ? Color(item.color).gradient : Color.gray.opacity(0.3))
                                    .frame(height: 35)
                                    .overlay(
                                        VStack(spacing: 2) {
                                            Image(systemName: item.icon)
                                                .font(.caption2)
                                                .foregroundColor(item.isSelected ? .white : .gray)

                                            if item.isSelected {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .font(.system(size: 8))
                                                    .foregroundColor(.white)
                                            }
                                        }
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    HStack(spacing: 8) {
                        Button(intent: GenerateAlternativeIntent()) {
                            HStack(spacing: 4) {
                                Image(systemName: "wand.and.rays")
                                    .font(.caption2)
                                Text("New Look")
                                    .font(.caption2)
                            }
                            .foregroundColor(.blue)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.blue.opacity(0.1))
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)

                        Button(intent: SaveOutfitIntent(outfitId: currentOutfit.id)) {
                            HStack(spacing: 4) {
                                Image(systemName: currentOutfit.isSaved ? "heart.fill" : "heart")
                                    .font(.caption2)
                                Text("Save")
                                    .font(.caption2)
                            }
                            .foregroundColor(currentOutfit.isSaved ? .pink : .secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(currentOutfit.isSaved ? .pink.opacity(0.1) : .gray.opacity(0.1))
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)

                        Spacer()

                        Toggle(intent: ToggleNotificationsIntent()) {
                            Image(systemName: entry.outfitState.notificationsEnabled ? "bell.fill" : "bell.slash")
                                .font(.caption2)
                                .foregroundColor(entry.outfitState.notificationsEnabled ? .blue : .gray)
                        }
                        .toggleStyle(.button)
                        .buttonStyle(.plain)
                    }
                }
            } else {
                VStack(spacing: 6) {
                    Text("No outfit selected")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Button(intent: GenerateNewOutfitIntent()) {
                        Text("Generate Outfit")
                            .font(.caption2)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(.blue.opacity(0.2))
                            .foregroundColor(.blue)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding()
    }
}

struct InteractiveProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> InteractiveEntry {
        InteractiveEntry(
            date: Date(),
            configuration: InteractiveConfigurationIntent(),
            outfitState: InteractiveOutfitState.placeholder
        )
    }

    func snapshot(for configuration: InteractiveConfigurationIntent, in context: Context) async -> InteractiveEntry {
        InteractiveEntry(
            date: Date(),
            configuration: configuration,
            outfitState: await InteractiveService.shared.getCurrentState()
        )
    }

    func timeline(for configuration: InteractiveConfigurationIntent, in context: Context) async -> Timeline<InteractiveEntry> {
        let state = await InteractiveService.shared.getCurrentState()
        let entry = InteractiveEntry(date: Date(), configuration: configuration, outfitState: state)

        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date().addingTimeInterval(900)
        return Timeline(entries: [entry], policy: .after(nextUpdate))
    }
}

struct InteractiveConfigurationIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Interactive Configuration"
    static var description = IntentDescription("Configure interactive outfit features")

    @Parameter(title: "Auto-generate", description: "Automatically generate new outfits")
    var autoGenerate: Bool

    init(autoGenerate: Bool = false) {
        self.autoGenerate = autoGenerate
    }

    init() {
        self.autoGenerate = false
    }
}

struct InteractiveOutfitState {
    let currentOutfit: InteractiveOutfit?
    let isLoading: Bool
    let notificationsEnabled: Bool

    static let placeholder = InteractiveOutfitState(
        currentOutfit: InteractiveOutfit(
            id: "1",
            name: "Smart Casual",
            items: [
                InteractiveOutfitItem(id: "1", icon: "tshirt.fill", color: "blue", isSelected: true),
                InteractiveOutfitItem(id: "2", icon: "rectangle.fill", color: "indigo", isSelected: true),
                InteractiveOutfitItem(id: "3", icon: "shoe.2.fill", color: "brown", isSelected: false),
                InteractiveOutfitItem(id: "4", icon: "jacket.fill", color: "gray", isSelected: true)
            ],
            currentRating: 4,
            isSaved: false
        ),
        isLoading: false,
        notificationsEnabled: true
    )
}

struct InteractiveOutfit {
    let id: String
    let name: String
    let items: [InteractiveOutfitItem]
    let currentRating: Int
    let isSaved: Bool
}

struct InteractiveOutfitItem {
    let id: String
    let icon: String
    let color: String
    let isSelected: Bool
}

class InteractiveService {
    static let shared = InteractiveService()

    func getCurrentState() async -> InteractiveOutfitState {
        return InteractiveOutfitState.placeholder
    }
}

struct QuickRateIntent: AppIntent {
    static var title: LocalizedStringResource = "Quick Rate"
    static var description = IntentDescription("Quickly rate the current outfit")

    @Parameter(title: "Rating")
    var rating: Int

    func perform() async throws -> some IntentResult {
        return .result()
    }
}

struct ToggleItemIntent: AppIntent {
    static var title: LocalizedStringResource = "Toggle Item"
    static var description = IntentDescription("Toggle outfit item selection")

    @Parameter(title: "Item ID")
    var itemId: String

    func perform() async throws -> some IntentResult {
        return .result()
    }
}

struct GenerateAlternativeIntent: AppIntent {
    static var title: LocalizedStringResource = "Generate Alternative"
    static var description = IntentDescription("Generate an alternative outfit")

    func perform() async throws -> some IntentResult {
        return .result()
    }
}

struct SaveOutfitIntent: AppIntent {
    static var title: LocalizedStringResource = "Save Outfit"
    static var description = IntentDescription("Save the current outfit")

    @Parameter(title: "Outfit ID")
    var outfitId: String

    func perform() async throws -> some IntentResult {
        return .result()
    }
}

struct ToggleNotificationsIntent: AppIntent {
    static var title: LocalizedStringResource = "Toggle Notifications"
    static var description = IntentDescription("Toggle outfit notifications")

    func perform() async throws -> some IntentResult {
        return .result()
    }
}

struct GenerateNewOutfitIntent: AppIntent {
    static var title: LocalizedStringResource = "Generate New Outfit"
    static var description = IntentDescription("Generate a completely new outfit")

    func perform() async throws -> some IntentResult {
        return .result()
    }
}