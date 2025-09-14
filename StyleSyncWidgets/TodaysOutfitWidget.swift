import SwiftUI
import WidgetKit
import AppIntents

struct TodaysOutfitWidget: Widget {
    let kind: String = "TodaysOutfitWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: ConfigurationAppIntent.self, provider: Provider()) { entry in
            TodaysOutfitWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Today's Outfit")
        .description("Quick access to today's outfit recommendation")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let configuration: ConfigurationAppIntent
    let outfit: OutfitRecommendation
}

struct TodaysOutfitWidgetEntryView : View {
    var entry: Provider.Entry

    var body: some View {
        VStack {
            if entry.outfit.items.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "tshirt")
                        .font(.title2)
                        .foregroundColor(.secondary)
                    Text("No outfit planned")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Button(intent: GenerateOutfitIntent()) {
                        Text("Get Suggestion")
                            .font(.caption2)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.blue.opacity(0.2))
                            .foregroundColor(.blue)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Today's Look")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                        Spacer()
                        if let weather = entry.outfit.weather {
                            Image(systemName: weather.icon)
                                .font(.caption2)
                                .foregroundColor(.blue)
                        }
                    }

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 2), spacing: 4) {
                        ForEach(entry.outfit.items.prefix(4), id: \.id) { item in
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(item.color).gradient)
                                .frame(height: 40)
                                .overlay(
                                    VStack(spacing: 2) {
                                        Image(systemName: item.icon)
                                            .font(.caption2)
                                            .foregroundColor(.white)
                                        Text(item.type)
                                            .font(.system(size: 8))
                                            .foregroundColor(.white.opacity(0.8))
                                    }
                                )
                        }
                    }

                    HStack {
                        Button(intent: RateOutfitIntent(rating: 5)) {
                            HStack(spacing: 2) {
                                Image(systemName: "heart.fill")
                                    .font(.caption2)
                                Text("Love it")
                                    .font(.caption2)
                            }
                            .foregroundColor(.pink)
                        }
                        .buttonStyle(.plain)

                        Spacer()

                        Button(intent: RefreshOutfitIntent()) {
                            Image(systemName: "arrow.clockwise")
                                .font(.caption2)
                                .foregroundColor(.blue)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding()
    }
}

struct Provider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), configuration: ConfigurationAppIntent(), outfit: OutfitRecommendation.placeholder)
    }

    func snapshot(for configuration: ConfigurationAppIntent, in context: Context) async -> SimpleEntry {
        SimpleEntry(date: Date(), configuration: configuration, outfit: await OutfitService.shared.getTodaysOutfit())
    }

    func timeline(for configuration: ConfigurationAppIntent, in context: Context) async -> Timeline<SimpleEntry> {
        let outfit = await OutfitService.shared.getTodaysOutfit()
        let entry = SimpleEntry(date: Date(), configuration: configuration, outfit: outfit)

        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 2, to: Date()) ?? Date().addingTimeInterval(7200)
        return Timeline(entries: [entry], policy: .after(nextUpdate))
    }
}

struct ConfigurationAppIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Configuration"
    static var description = IntentDescription("This is an example widget.")
}

struct OutfitRecommendation {
    let items: [OutfitItem]
    let weather: WeatherInfo?
    let occasion: String?

    static let placeholder = OutfitRecommendation(
        items: [
            OutfitItem(id: "1", type: "Shirt", color: "blue", icon: "tshirt"),
            OutfitItem(id: "2", type: "Pants", color: "indigo", icon: "rectangle.fill"),
            OutfitItem(id: "3", type: "Shoes", color: "brown", icon: "shoe.fill"),
            OutfitItem(id: "4", type: "Watch", color: "silver", icon: "applewatch")
        ],
        weather: WeatherInfo(temperature: 72, condition: "sunny", icon: "sun.max.fill"),
        occasion: "Work"
    )
}

struct OutfitItem {
    let id: String
    let type: String
    let color: String
    let icon: String
}

struct WeatherInfo {
    let temperature: Int
    let condition: String
    let icon: String
}

class OutfitService {
    static let shared = OutfitService()

    func getTodaysOutfit() async -> OutfitRecommendation {
        return OutfitRecommendation.placeholder
    }
}

struct GenerateOutfitIntent: AppIntent {
    static var title: LocalizedStringResource = "Generate Outfit"
    static var description = IntentDescription("Generate a new outfit recommendation")

    func perform() async throws -> some IntentResult {
        await OutfitService.shared.getTodaysOutfit()
        return .result()
    }
}

struct RateOutfitIntent: AppIntent {
    static var title: LocalizedStringResource = "Rate Outfit"
    static var description = IntentDescription("Rate the current outfit")

    @Parameter(title: "Rating")
    var rating: Int

    func perform() async throws -> some IntentResult {
        return .result()
    }
}

struct RefreshOutfitIntent: AppIntent {
    static var title: LocalizedStringResource = "Refresh Outfit"
    static var description = IntentDescription("Get a new outfit suggestion")

    func perform() async throws -> some IntentResult {
        return .result()
    }
}