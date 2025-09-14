import Foundation
import SwiftUI

class LocalizationManager: ObservableObject {
    static let shared = LocalizationManager()

    @Published var currentLanguage: Language = .english
    @Published var currentRegion: Region = .switzerland
    @Published var measurementSystem: MeasurementSystem = .metric

    private init() {
        detectSystemLocale()
    }

    private func detectSystemLocale() {
        let locale = Locale.current

        // Language detection
        if let languageCode = locale.language.languageCode?.identifier {
            switch languageCode {
            case "de": currentLanguage = .german
            case "fr": currentLanguage = .french
            default: currentLanguage = .english
            }
        }

        // Region detection
        if let regionCode = locale.region?.identifier {
            switch regionCode {
            case "CH": currentRegion = .switzerland
            case "DE": currentRegion = .germany
            case "AT": currentRegion = .austria
            case "FR": currentRegion = .france
            default: currentRegion = .switzerland
            }
        }

        // Measurement system
        measurementSystem = locale.usesMetricSystem ? .metric : .imperial
    }

    func setLanguage(_ language: Language) {
        currentLanguage = language
        UserDefaults.standard.set(language.rawValue, forKey: "selected_language")
    }

    func setRegion(_ region: Region) {
        currentRegion = region
        UserDefaults.standard.set(region.rawValue, forKey: "selected_region")
    }

    func setMeasurementSystem(_ system: MeasurementSystem) {
        measurementSystem = system
        UserDefaults.standard.set(system.rawValue, forKey: "measurement_system")
    }

    // MARK: - Localized Strings

    func localizedString(_ key: String) -> String {
        let bundle = getBundle(for: currentLanguage)
        return NSLocalizedString(key, bundle: bundle, comment: "")
    }

    private func getBundle(for language: Language) -> Bundle {
        guard let path = Bundle.main.path(forResource: language.code, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return Bundle.main
        }
        return bundle
    }

    // MARK: - Currency Formatting

    func formatPrice(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency

        switch currentRegion {
        case .switzerland:
            formatter.currencyCode = "CHF"
            formatter.locale = Locale(identifier: "de_CH")
        case .germany, .austria:
            formatter.currencyCode = "EUR"
            formatter.locale = Locale(identifier: "de_DE")
        case .france:
            formatter.currencyCode = "EUR"
            formatter.locale = Locale(identifier: "fr_FR")
        case .unitedStates:
            formatter.currencyCode = "USD"
            formatter.locale = Locale(identifier: "en_US")
        case .unitedKingdom:
            formatter.currencyCode = "GBP"
            formatter.locale = Locale(identifier: "en_GB")
        }

        return formatter.string(from: NSNumber(value: amount)) ?? "\(amount)"
    }

    // MARK: - Temperature Formatting

    func formatTemperature(_ celsius: Double) -> String {
        switch measurementSystem {
        case .metric:
            return String(format: "%.0f°C", celsius)
        case .imperial:
            let fahrenheit = celsius * 9/5 + 32
            return String(format: "%.0f°F", fahrenheit)
        }
    }

    // MARK: - Size Formatting

    func formatSize(_ size: String, category: ClothingCategory) -> String {
        switch currentRegion {
        case .switzerland:
            if let swissSize = SwissSizeConverter.shared.convertToSwissSize(
                category: category,
                size: size,
                fromCountry: "US"
            ) {
                return "CH \(swissSize)"
            }
        case .germany, .austria:
            return "EU \(size)"
        case .france:
            return "FR \(size)"
        case .unitedStates:
            return "US \(size)"
        case .unitedKingdom:
            return "UK \(size)"
        }

        return size
    }

    // MARK: - Date and Time Formatting

    func formatDate(_ date: Date, style: DateFormatter.Style = .medium) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = style
        formatter.locale = getLocale()
        return formatter.string(from: date)
    }

    func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.locale = getLocale()
        return formatter.string(from: date)
    }

    private func getLocale() -> Locale {
        let languageCode = currentLanguage.code
        let regionCode = currentRegion.code
        return Locale(identifier: "\(languageCode)_\(regionCode)")
    }

    // MARK: - Weather Localization

    func localizedWeatherCondition(_ condition: WeatherCondition) -> String {
        let key = "weather_\(condition.rawValue.lowercased())"
        return localizedString(key)
    }

    func localizedOccasion(_ occasion: Occasion) -> String {
        let key = "occasion_\(occasion.rawValue.lowercased())"
        return localizedString(key)
    }

    // MARK: - Cultural Adaptations

    func getCulturalAdaptations() -> CulturalAdaptations {
        switch currentRegion {
        case .switzerland:
            return CulturalAdaptations(
                workWeek: .mondayToFriday,
                businessHours: "08:00-17:00",
                dressCodes: SwissMarketFeatures.shared.getCulturalGuidelines(),
                colorPreferences: ["Navy", "Black", "White", "Beige", "Forest Green"],
                formalityLevel: .high,
                sustainabilityFocus: .high
            )
        case .germany:
            return CulturalAdaptations(
                workWeek: .mondayToFriday,
                businessHours: "09:00-18:00",
                dressCodes: nil,
                colorPreferences: ["Black", "Gray", "Navy", "White"],
                formalityLevel: .high,
                sustainabilityFocus: .high
            )
        case .france:
            return CulturalAdaptations(
                workWeek: .mondayToFriday,
                businessHours: "09:00-17:00",
                dressCodes: nil,
                colorPreferences: ["Black", "Navy", "Burgundy", "Cream"],
                formalityLevel: .high,
                sustainabilityFocus: .medium
            )
        default:
            return CulturalAdaptations(
                workWeek: .mondayToFriday,
                businessHours: "09:00-17:00",
                dressCodes: nil,
                colorPreferences: ["Black", "White", "Navy", "Gray"],
                formalityLevel: .medium,
                sustainabilityFocus: .medium
            )
        }
    }
}

// MARK: - Enums

enum Language: String, CaseIterable {
    case english = "en"
    case german = "de"
    case french = "fr"

    var code: String { rawValue }

    var displayName: String {
        switch self {
        case .english: return "English"
        case .german: return "Deutsch"
        case .french: return "Français"
        }
    }
}

enum Region: String, CaseIterable {
    case switzerland = "CH"
    case germany = "DE"
    case austria = "AT"
    case france = "FR"
    case unitedStates = "US"
    case unitedKingdom = "GB"

    var code: String { rawValue }

    var displayName: String {
        switch self {
        case .switzerland: return "Switzerland"
        case .germany: return "Germany"
        case .austria: return "Austria"
        case .france: return "France"
        case .unitedStates: return "United States"
        case .unitedKingdom: return "United Kingdom"
        }
    }

    var currency: String {
        switch self {
        case .switzerland: return "CHF"
        case .germany, .austria, .france: return "EUR"
        case .unitedStates: return "USD"
        case .unitedKingdom: return "GBP"
        }
    }
}

enum MeasurementSystem: String, CaseIterable {
    case metric = "metric"
    case imperial = "imperial"

    var displayName: String {
        switch self {
        case .metric: return "Metric"
        case .imperial: return "Imperial"
        }
    }
}

// MARK: - Cultural Adaptations

struct CulturalAdaptations {
    let workWeek: WorkWeek
    let businessHours: String
    let dressCodes: SwissCulturalGuide?
    let colorPreferences: [String]
    let formalityLevel: FormalityLevel
    let sustainabilityFocus: SustainabilityFocus
}

enum WorkWeek {
    case mondayToFriday
    case sundayToThursday
}

enum FormalityLevel {
    case low, medium, high
}

enum SustainabilityFocus {
    case low, medium, high
}

// MARK: - SwiftUI Integration

struct LocalizedText: View {
    let key: String
    let arguments: [CVarArg]

    init(_ key: String, _ arguments: CVarArg...) {
        self.key = key
        self.arguments = arguments
    }

    var body: some View {
        let localizedString = LocalizationManager.shared.localizedString(key)
        Text(String(format: localizedString, arguments: arguments))
    }
}

struct LocalizedButton<Label: View>: View {
    let titleKey: String
    let action: () -> Void
    let label: () -> Label

    init(_ titleKey: String, action: @escaping () -> Void, @ViewBuilder label: @escaping () -> Label) {
        self.titleKey = titleKey
        self.action = action
        self.label = label
    }

    var body: some View {
        Button(action: action) {
            label()
        }
        .accessibilityLabel(LocalizationManager.shared.localizedString(titleKey))
    }
}

// MARK: - Language Selection View

struct LanguageSelectionView: View {
    @StateObject private var localizationManager = LocalizationManager.shared
    @Binding var isPresented: Bool

    var body: some View {
        NavigationView {
            List {
                Section {
                    ForEach(Language.allCases, id: \.self) { language in
                        HStack {
                            Text(language.displayName)
                                .foregroundColor(.primary)

                            Spacer()

                            if localizationManager.currentLanguage == language {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            localizationManager.setLanguage(language)
                        }
                    }
                }

                Section("Region") {
                    ForEach(Region.allCases, id: \.self) { region in
                        HStack {
                            Text(region.displayName)
                                .foregroundColor(.primary)

                            Spacer()

                            Text(region.currency)
                                .font(.caption)
                                .foregroundColor(.secondary)

                            if localizationManager.currentRegion == region {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            localizationManager.setRegion(region)
                        }
                    }
                }

                Section("Measurements") {
                    ForEach(MeasurementSystem.allCases, id: \.self) { system in
                        HStack {
                            Text(system.displayName)
                                .foregroundColor(.primary)

                            Spacer()

                            if localizationManager.measurementSystem == system {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            localizationManager.setMeasurementSystem(system)
                        }
                    }
                }
            }
            .navigationTitle("Language & Region")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        isPresented = false
                    }
                }
            }
        }
    }
}