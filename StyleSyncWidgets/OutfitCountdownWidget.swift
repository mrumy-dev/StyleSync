import SwiftUI
import WidgetKit
import AppIntents

struct OutfitCountdownWidget: Widget {
    let kind: String = "OutfitCountdownWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: CountdownConfigurationIntent.self, provider: CountdownProvider()) { entry in
            OutfitCountdownWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Outfit Countdown")
        .description("Countdown to your next planned outfit or event")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct CountdownEntry: TimelineEntry {
    let date: Date
    let configuration: CountdownConfigurationIntent
    let countdown: OutfitCountdown
}

struct OutfitCountdownWidgetEntryView: View {
    var entry: CountdownProvider.Entry

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Next Outfit")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)

                    Text(entry.countdown.eventName)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: entry.countdown.icon)
                    .font(.title3)
                    .foregroundColor(entry.countdown.color)
            }

            if entry.countdown.timeRemaining > 0 {
                VStack(spacing: 6) {
                    HStack(spacing: 4) {
                        TimeUnit(value: entry.countdown.days, unit: "d", color: .blue)
                        TimeUnit(value: entry.countdown.hours, unit: "h", color: .green)
                        TimeUnit(value: entry.countdown.minutes, unit: "m", color: .orange)
                        TimeUnit(value: entry.countdown.seconds, unit: "s", color: .red)
                    }

                    ProgressView(value: entry.countdown.progress)
                        .progressViewStyle(LinearProgressViewStyle(tint: entry.countdown.color))
                        .frame(height: 4)
                }
            } else {
                VStack(spacing: 6) {
                    Text("Time to get ready!")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.red)

                    Button(intent: ViewOutfitIntent(eventId: entry.countdown.eventId)) {
                        Text("View Outfit")
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

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Preparation")
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    Text("\(entry.countdown.preparationTime) min needed")
                        .font(.system(size: 9))
                        .foregroundColor(.blue)
                }

                Spacer()

                Button(intent: SetReminderIntent(eventId: entry.countdown.eventId)) {
                    Image(systemName: entry.countdown.hasReminder ? "bell.fill" : "bell")
                        .font(.caption)
                        .foregroundColor(entry.countdown.hasReminder ? .blue : .secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
    }
}

struct TimeUnit: View {
    let value: Int
    let unit: String
    let color: Color

    var body: some View {
        VStack(spacing: 1) {
            Text("\(value)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(color)

            Text(unit)
                .font(.system(size: 8))
                .foregroundColor(.secondary)
        }
        .frame(minWidth: 20)
    }
}

struct CountdownProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> CountdownEntry {
        CountdownEntry(
            date: Date(),
            configuration: CountdownConfigurationIntent(),
            countdown: OutfitCountdown.placeholder
        )
    }

    func snapshot(for configuration: CountdownConfigurationIntent, in context: Context) async -> CountdownEntry {
        CountdownEntry(
            date: Date(),
            configuration: configuration,
            countdown: await CountdownService.shared.getNextOutfitCountdown()
        )
    }

    func timeline(for configuration: CountdownConfigurationIntent, in context: Context) async -> Timeline<CountdownEntry> {
        var entries: [CountdownEntry] = []
        let currentDate = Date()

        for minuteOffset in 0..<60 {
            let entryDate = Calendar.current.date(byAdding: .minute, value: minuteOffset, to: currentDate)!
            let countdown = await CountdownService.shared.getNextOutfitCountdown(at: entryDate)
            let entry = CountdownEntry(date: entryDate, configuration: configuration, countdown: countdown)
            entries.append(entry)
        }

        return Timeline(entries: entries, policy: .atEnd)
    }
}

struct CountdownConfigurationIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Countdown Configuration"
    static var description = IntentDescription("Configure outfit countdown settings")

    @Parameter(title: "Show Preparation Time", description: "Include preparation time in countdown")
    var showPreparationTime: Bool

    init(showPreparationTime: Bool = true) {
        self.showPreparationTime = showPreparationTime
    }

    init() {
        self.showPreparationTime = true
    }
}

struct OutfitCountdown {
    let eventId: String
    let eventName: String
    let eventDate: Date
    let icon: String
    let color: Color
    let preparationTime: Int
    let hasReminder: Bool

    var timeRemaining: TimeInterval {
        eventDate.timeIntervalSince(Date())
    }

    var days: Int {
        Int(timeRemaining / 86400)
    }

    var hours: Int {
        Int((timeRemaining.truncatingRemainder(dividingBy: 86400)) / 3600)
    }

    var minutes: Int {
        Int((timeRemaining.truncatingRemainder(dividingBy: 3600)) / 60)
    }

    var seconds: Int {
        Int(timeRemaining.truncatingRemainder(dividingBy: 60))
    }

    var progress: Double {
        let totalTime: TimeInterval = 86400
        let elapsed = totalTime - timeRemaining
        return max(0, min(1, elapsed / totalTime))
    }

    static let placeholder = OutfitCountdown(
        eventId: "1",
        eventName: "Work Meeting",
        eventDate: Date().addingTimeInterval(3600),
        icon: "briefcase.fill",
        color: .blue,
        preparationTime: 30,
        hasReminder: true
    )
}

class CountdownService {
    static let shared = CountdownService()

    func getNextOutfitCountdown(at date: Date = Date()) async -> OutfitCountdown {
        return OutfitCountdown.placeholder
    }
}

struct ViewOutfitIntent: AppIntent {
    static var title: LocalizedStringResource = "View Outfit"
    static var description = IntentDescription("View the planned outfit details")

    @Parameter(title: "Event ID")
    var eventId: String

    func perform() async throws -> some IntentResult {
        return .result()
    }
}

struct SetReminderIntent: AppIntent {
    static var title: LocalizedStringResource = "Set Reminder"
    static var description = IntentDescription("Toggle reminder for outfit preparation")

    @Parameter(title: "Event ID")
    var eventId: String

    func perform() async throws -> some IntentResult {
        return .result()
    }
}