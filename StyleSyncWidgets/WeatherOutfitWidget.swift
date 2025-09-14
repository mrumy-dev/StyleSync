import SwiftUI
import WidgetKit
import AppIntents
import WeatherKit
import CoreLocation

struct WeatherOutfitWidget: Widget {
    let kind: String = "WeatherOutfitWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: WeatherConfigurationIntent.self, provider: WeatherProvider()) { entry in
            WeatherOutfitWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Weather Outfit")
        .description("Outfit suggestions based on current weather")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

struct WeatherEntry: TimelineEntry {
    let date: Date
    let configuration: WeatherConfigurationIntent
    let weatherOutfit: WeatherOutfitSuggestion
}

struct WeatherOutfitWidgetEntryView: View {
    var entry: WeatherProvider.Entry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Weather Outfit")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)

                    HStack(spacing: 8) {
                        Image(systemName: entry.weatherOutfit.weather.icon)
                            .font(.title2)
                            .foregroundColor(entry.weatherOutfit.weather.color)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(entry.weatherOutfit.weather.temperature)°")
                                .font(.title2)
                                .fontWeight(.bold)

                            Text(entry.weatherOutfit.weather.condition)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("Comfort Level")
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    HStack(spacing: 2) {
                        ForEach(1...5, id: \.self) { index in
                            Circle()
                                .fill(index <= entry.weatherOutfit.comfortLevel ? Color.green : Color.gray.opacity(0.3))
                                .frame(width: 6, height: 6)
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Recommended Items")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 3), spacing: 6) {
                    ForEach(entry.weatherOutfit.recommendations, id: \.id) { item in
                        VStack(spacing: 4) {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color(item.color).gradient)
                                .frame(height: 35)
                                .overlay(
                                    Image(systemName: item.icon)
                                        .font(.caption)
                                        .foregroundColor(.white)
                                )

                            Text(item.name)
                                .font(.system(size: 8))
                                .foregroundColor(.primary)
                                .multilineTextAlignment(.center)
                        }
                    }
                }
            }

            HStack {
                Button(intent: RefreshWeatherOutfitIntent()) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.clockwise")
                            .font(.caption2)
                        Text("Refresh")
                            .font(.caption2)
                    }
                    .foregroundColor(.blue)
                }
                .buttonStyle(.plain)

                Spacer()

                if let advice = entry.weatherOutfit.advice {
                    Text(advice)
                        .font(.caption2)
                        .foregroundColor(.orange)
                        .italic()
                }
            }
        }
        .padding()
    }
}

struct WeatherProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> WeatherEntry {
        WeatherEntry(
            date: Date(),
            configuration: WeatherConfigurationIntent(),
            weatherOutfit: WeatherOutfitSuggestion.placeholder
        )
    }

    func snapshot(for configuration: WeatherConfigurationIntent, in context: Context) async -> WeatherEntry {
        WeatherEntry(
            date: Date(),
            configuration: configuration,
            weatherOutfit: await WeatherOutfitService.shared.getWeatherBasedOutfit()
        )
    }

    func timeline(for configuration: WeatherConfigurationIntent, in context: Context) async -> Timeline<WeatherEntry> {
        let weatherOutfit = await WeatherOutfitService.shared.getWeatherBasedOutfit()
        let entry = WeatherEntry(
            date: Date(),
            configuration: configuration,
            weatherOutfit: weatherOutfit
        )

        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date().addingTimeInterval(3600)
        return Timeline(entries: [entry], policy: .after(nextUpdate))
    }
}

struct WeatherConfigurationIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Weather Configuration"
    static var description = IntentDescription("Configure weather-based outfit suggestions")

    @Parameter(title: "Location", description: "Your location for weather data")
    var useCurrentLocation: Bool

    init(useCurrentLocation: Bool = true) {
        self.useCurrentLocation = useCurrentLocation
    }

    init() {
        self.useCurrentLocation = true
    }
}

struct WeatherOutfitSuggestion {
    let weather: DetailedWeather
    let recommendations: [WeatherClothingItem]
    let comfortLevel: Int
    let advice: String?

    static let placeholder = WeatherOutfitSuggestion(
        weather: DetailedWeather(
            temperature: 68,
            condition: "Partly Cloudy",
            icon: "cloud.sun.fill",
            color: .blue,
            humidity: 65,
            windSpeed: 8
        ),
        recommendations: [
            WeatherClothingItem(id: "1", name: "Light Sweater", icon: "tshirt.fill", color: "mint"),
            WeatherClothingItem(id: "2", name: "Jeans", icon: "rectangle.fill", color: "blue"),
            WeatherClothingItem(id: "3", name: "Sneakers", icon: "shoe.2.fill", color: "gray"),
            WeatherClothingItem(id: "4", name: "Light Jacket", icon: "jacket.fill", color: "brown"),
            WeatherClothingItem(id: "5", name: "Sunglasses", icon: "sunglasses.fill", color: "black"),
            WeatherClothingItem(id: "6", name: "Cap", icon: "hat.fill", color: "red")
        ],
        comfortLevel: 4,
        advice: "Perfect weather for layering!"
    )
}

struct DetailedWeather {
    let temperature: Int
    let condition: String
    let icon: String
    let color: Color
    let humidity: Int
    let windSpeed: Int
}

struct WeatherClothingItem {
    let id: String
    let name: String
    let icon: String
    let color: String
}

class WeatherOutfitService {
    static let shared = WeatherOutfitService()

    func getWeatherBasedOutfit() async -> WeatherOutfitSuggestion {
        return WeatherOutfitSuggestion.placeholder
    }
}

struct RefreshWeatherOutfitIntent: AppIntent {
    static var title: LocalizedStringResource = "Refresh Weather Outfit"
    static var description = IntentDescription("Get updated weather-based outfit suggestions")

    func perform() async throws -> some IntentResult {
        await WeatherOutfitService.shared.getWeatherBasedOutfit()
        return .result()
    }
}