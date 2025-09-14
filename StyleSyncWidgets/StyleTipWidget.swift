import SwiftUI
import WidgetKit
import AppIntents

struct StyleTipWidget: Widget {
    let kind: String = "StyleTipWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: StyleTipConfigurationIntent.self, provider: StyleTipProvider()) { entry in
            StyleTipWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Style Tip of the Day")
        .description("Daily style tips and fashion advice")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct StyleTipEntry: TimelineEntry {
    let date: Date
    let configuration: StyleTipConfigurationIntent
    let styleTip: DailyStyleTip
}

struct StyleTipWidgetEntryView: View {
    var entry: StyleTipProvider.Entry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Style Tip")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)

                    Text("#\(entry.styleTip.tipNumber)")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(entry.styleTip.category.color)
                }

                Spacer()

                Image(systemName: entry.styleTip.category.icon)
                    .font(.title2)
                    .foregroundColor(entry.styleTip.category.color)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(entry.styleTip.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .lineLimit(2)

                Text(entry.styleTip.content)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(4)
            }

            if !entry.styleTip.tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(entry.styleTip.tags, id: \.self) { tag in
                            Text(tag)
                                .font(.system(size: 9))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(entry.styleTip.category.color.opacity(0.2))
                                .foregroundColor(entry.styleTip.category.color)
                                .clipShape(Capsule())
                        }
                    }
                    .padding(.horizontal, 1)
                }
            }

            HStack {
                Button(intent: BookmarkTipIntent(tipId: entry.styleTip.id)) {
                    HStack(spacing: 4) {
                        Image(systemName: entry.styleTip.isBookmarked ? "bookmark.fill" : "bookmark")
                            .font(.caption2)
                        Text(entry.styleTip.isBookmarked ? "Saved" : "Save")
                            .font(.caption2)
                    }
                    .foregroundColor(entry.styleTip.isBookmarked ? .blue : .secondary)
                }
                .buttonStyle(.plain)

                Spacer()

                Button(intent: ShareTipIntent(tipId: entry.styleTip.id)) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.caption2)
                        .foregroundColor(.blue)
                }
                .buttonStyle(.plain)

                Button(intent: NextTipIntent()) {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption2)
                        .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
    }
}

struct StyleTipProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> StyleTipEntry {
        StyleTipEntry(
            date: Date(),
            configuration: StyleTipConfigurationIntent(),
            styleTip: DailyStyleTip.placeholder
        )
    }

    func snapshot(for configuration: StyleTipConfigurationIntent, in context: Context) async -> StyleTipEntry {
        StyleTipEntry(
            date: Date(),
            configuration: configuration,
            styleTip: await StyleTipService.shared.getDailyTip(category: configuration.preferredCategory)
        )
    }

    func timeline(for configuration: StyleTipConfigurationIntent, in context: Context) async -> Timeline<StyleTipEntry> {
        let styleTip = await StyleTipService.shared.getDailyTip(category: configuration.preferredCategory)
        let entry = StyleTipEntry(date: Date(), configuration: configuration, styleTip: styleTip)

        let nextMidnight = Calendar.current.startOfDay(for: Date().addingTimeInterval(86400))
        return Timeline(entries: [entry], policy: .after(nextMidnight))
    }
}

struct StyleTipConfigurationIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Style Tip Configuration"
    static var description = IntentDescription("Choose your preferred style tip categories")

    @Parameter(title: "Preferred Category", description: "Select your favorite style category")
    var preferredCategory: StyleCategory

    init(preferredCategory: StyleCategory = .general) {
        self.preferredCategory = preferredCategory
    }

    init() {
        self.preferredCategory = .general
    }
}

enum StyleCategory: String, CaseIterable, AppEnum {
    case general = "general"
    case formal = "formal"
    case casual = "casual"
    case accessories = "accessories"
    case colors = "colors"
    case seasonal = "seasonal"

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Style Category")

    static var caseDisplayRepresentations: [StyleCategory: DisplayRepresentation] = [
        .general: DisplayRepresentation(title: "General"),
        .formal: DisplayRepresentation(title: "Formal"),
        .casual: DisplayRepresentation(title: "Casual"),
        .accessories: DisplayRepresentation(title: "Accessories"),
        .colors: DisplayRepresentation(title: "Colors"),
        .seasonal: DisplayRepresentation(title: "Seasonal")
    ]

    var icon: String {
        switch self {
        case .general: return "sparkles"
        case .formal: return "suit.fill"
        case .casual: return "tshirt.fill"
        case .accessories: return "bag.fill"
        case .colors: return "paintpalette.fill"
        case .seasonal: return "leaf.fill"
        }
    }

    var color: Color {
        switch self {
        case .general: return .purple
        case .formal: return .black
        case .casual: return .blue
        case .accessories: return .brown
        case .colors: return .pink
        case .seasonal: return .green
        }
    }
}

struct DailyStyleTip {
    let id: String
    let tipNumber: Int
    let title: String
    let content: String
    let category: StyleCategory
    let tags: [String]
    let isBookmarked: Bool
    let difficulty: DifficultyLevel

    static let placeholder = DailyStyleTip(
        id: "1",
        tipNumber: 147,
        title: "Mix Textures for Depth",
        content: "Combine different textures like smooth silk with rough denim, or soft cashmere with structured leather. This creates visual interest and adds sophistication to any outfit.",
        category: .general,
        tags: ["Textures", "Layering", "Advanced"],
        isBookmarked: false,
        difficulty: .intermediate
    )
}

enum DifficultyLevel: String, CaseIterable {
    case beginner = "beginner"
    case intermediate = "intermediate"
    case advanced = "advanced"

    var icon: String {
        switch self {
        case .beginner: return "star.fill"
        case .intermediate: return "star.leadinghalf.filled"
        case .advanced: return "star.fill"
        }
    }

    var color: Color {
        switch self {
        case .beginner: return .green
        case .intermediate: return .orange
        case .advanced: return .red
        }
    }
}

class StyleTipService {
    static let shared = StyleTipService()

    func getDailyTip(category: StyleCategory = .general) async -> DailyStyleTip {
        let tips = [
            DailyStyleTip(
                id: "1",
                tipNumber: 147,
                title: "Mix Textures for Depth",
                content: "Combine different textures like smooth silk with rough denim, or soft cashmere with structured leather. This creates visual interest and adds sophistication to any outfit.",
                category: .general,
                tags: ["Textures", "Layering", "Advanced"],
                isBookmarked: false,
                difficulty: .intermediate
            ),
            DailyStyleTip(
                id: "2",
                tipNumber: 148,
                title: "Power of Proper Fit",
                content: "A well-fitted basic piece always looks better than an expensive item that doesn't fit properly. Invest in tailoring for your key pieces.",
                category: .formal,
                tags: ["Tailoring", "Fit", "Basics"],
                isBookmarked: true,
                difficulty: .beginner
            ),
            DailyStyleTip(
                id: "3",
                tipNumber: 149,
                title: "Accessory Focal Point",
                content: "Choose one standout accessory per outfit. Let it be the star while keeping other accessories minimal and complementary.",
                category: .accessories,
                tags: ["Accessories", "Balance", "Statement"],
                isBookmarked: false,
                difficulty: .beginner
            )
        ]

        return tips.randomElement() ?? DailyStyleTip.placeholder
    }
}

struct BookmarkTipIntent: AppIntent {
    static var title: LocalizedStringResource = "Bookmark Tip"
    static var description = IntentDescription("Save this style tip to your bookmarks")

    @Parameter(title: "Tip ID")
    var tipId: String

    func perform() async throws -> some IntentResult {
        return .result()
    }
}

struct ShareTipIntent: AppIntent {
    static var title: LocalizedStringResource = "Share Tip"
    static var description = IntentDescription("Share this style tip")

    @Parameter(title: "Tip ID")
    var tipId: String

    func perform() async throws -> some IntentResult {
        return .result()
    }
}

struct NextTipIntent: AppIntent {
    static var title: LocalizedStringResource = "Next Tip"
    static var description = IntentDescription("Get a new style tip")

    func perform() async throws -> some IntentResult {
        return .result()
    }
}