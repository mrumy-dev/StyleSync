import Foundation
import AppIntents
import SwiftUI

struct MorningRoutineAutomation: AppIntent {
    static var title: LocalizedStringResource = "Morning Routine Automation"
    static var description = IntentDescription("Automate your complete morning style routine with AI assistance")

    static var parameterSummary: some ParameterSummary {
        Summary("Start my morning routine") {
            \.$includeWeatherCheck
            \.$autoGenerateOutfit
            \.$setReminders
            \.$duration
        }
    }

    static var openAppWhenRun: Bool = false

    @Parameter(title: "Include Weather Check", description: "Check weather and adjust recommendations", default: true)
    var includeWeatherCheck: Bool

    @Parameter(title: "Auto Generate Outfit", description: "Automatically create outfit suggestions", default: true)
    var autoGenerateOutfit: Bool

    @Parameter(title: "Set Reminders", description: "Set reminders for each step", default: true)
    var setReminders: Bool

    @Parameter(title: "Routine Duration", description: "How long do you have?", default: .normal)
    var duration: RoutineDuration

    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {

        let routineConfig = MorningRoutineConfig(
            includeWeatherCheck: includeWeatherCheck,
            autoGenerateOutfit: autoGenerateOutfit,
            setReminders: setReminders,
            duration: duration,
            startTime: Date()
        )

        let routine = await MorningRoutineService.shared.createPersonalizedRoutine(config: routineConfig)

        let dialog = generateRoutineDialog(for: routine, config: routineConfig)
        let snippet = MorningRoutineView(routine: routine, config: routineConfig)

        return .result(
            dialog: dialog,
            view: snippet
        )
    }

    private func generateRoutineDialog(for routine: MorningRoutine, config: MorningRoutineConfig) -> IntentDialog {
        var message = "Good morning! I've prepared your \(config.duration.displayName.lowercased()) routine with \(routine.steps.count) steps. "

        if config.includeWeatherCheck, let weather = routine.weatherInfo {
            message += "It's \(Int(weather.temperature))° and \(weather.condition.lowercased()) today, so I've adjusted your recommendations. "
        }

        if config.autoGenerateOutfit, let outfit = routine.outfitSuggestion {
            message += "Your outfit suggestion is ready: \(outfit.summary). "
        }

        if config.setReminders {
            message += "I'll remind you at each step. "
        }

        message += "Ready to start?"

        return IntentDialog(message)
    }
}

enum RoutineDuration: String, CaseIterable, AppEnum {
    case quick = "quick"
    case normal = "normal"
    case leisurely = "leisurely"
    case custom = "custom"

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Routine Duration")

    static var caseDisplayRepresentations: [RoutineDuration: DisplayRepresentation] = [
        .quick: DisplayRepresentation(title: "Quick (15 min)", subtitle: "Essential steps only"),
        .normal: DisplayRepresentation(title: "Normal (30 min)", subtitle: "Complete routine"),
        .leisurely: DisplayRepresentation(title: "Leisurely (45 min)", subtitle: "Full self-care routine"),
        .custom: DisplayRepresentation(title: "Custom", subtitle: "Set your own timing")
    ]

    var displayName: String {
        switch self {
        case .quick: return "Quick"
        case .normal: return "Normal"
        case .leisurely: return "Leisurely"
        case .custom: return "Custom"
        }
    }

    var minutes: Int {
        switch self {
        case .quick: return 15
        case .normal: return 30
        case .leisurely: return 45
        case .custom: return 30
        }
    }

    var stepCount: Int {
        switch self {
        case .quick: return 5
        case .normal: return 8
        case .leisurely: return 12
        case .custom: return 8
        }
    }
}

struct MorningRoutineConfig {
    let includeWeatherCheck: Bool
    let autoGenerateOutfit: Bool
    let setReminders: Bool
    let duration: RoutineDuration
    let startTime: Date
}

struct MorningRoutine {
    let id: String
    let steps: [RoutineStep]
    let estimatedDuration: Int
    let weatherInfo: WeatherInfo?
    let outfitSuggestion: OutfitSuggestion?
    let personalizations: [Personalization]
    let reminders: [RoutineReminder]
}

struct RoutineStep {
    let id: String
    let title: String
    let description: String
    let estimatedMinutes: Int
    let category: StepCategory
    let icon: String
    let isOptional: Bool
    let tips: [String]
    let order: Int
}

enum StepCategory: String, CaseIterable {
    case preparation = "preparation"
    case outfit_selection = "outfit_selection"
    case grooming = "grooming"
    case accessories = "accessories"
    case final_check = "final_check"

    var displayName: String {
        switch self {
        case .preparation: return "Preparation"
        case .outfit_selection: return "Outfit Selection"
        case .grooming: return "Grooming"
        case .accessories: return "Accessories"
        case .final_check: return "Final Check"
        }
    }

    var color: Color {
        switch self {
        case .preparation: return .blue
        case .outfit_selection: return .green
        case .grooming: return .purple
        case .accessories: return .orange
        case .final_check: return .red
        }
    }
}

struct WeatherInfo {
    let temperature: Double
    let condition: String
    let icon: String
    let recommendations: [WeatherRecommendation]
}

struct WeatherRecommendation {
    let type: String
    let suggestion: String
}

struct OutfitSuggestion {
    let summary: String
    let items: [SuggestedItem]
    let reasoning: String
    let alternatives: [String]
}

struct SuggestedItem {
    let name: String
    let category: String
    let color: String
    let priority: ItemPriority
}

enum ItemPriority {
    case essential
    case recommended
    case optional
}

struct Personalization {
    let type: PersonalizationType
    let value: String
    let impact: String
}

enum PersonalizationType {
    case style_preference
    case time_constraint
    case weather_sensitivity
    case occasion_focus
}

struct RoutineReminder {
    let stepId: String
    let time: Date
    let message: String
    let type: ReminderType
}

enum ReminderType {
    case step_start
    case step_complete
    case time_check
    case weather_update
}

class MorningRoutineService {
    static let shared = MorningRoutineService()

    func createPersonalizedRoutine(config: MorningRoutineConfig) async -> MorningRoutine {

        await Task.sleep(nanoseconds: 1_000_000_000)

        let weatherInfo = config.includeWeatherCheck ? await generateWeatherInfo() : nil
        let outfitSuggestion = config.autoGenerateOutfit ? await generateOutfitSuggestion(weather: weatherInfo) : nil
        let steps = generateSteps(for: config, weather: weatherInfo)
        let reminders = config.setReminders ? generateReminders(for: steps, startTime: config.startTime) : []

        return MorningRoutine(
            id: UUID().uuidString,
            steps: steps,
            estimatedDuration: config.duration.minutes,
            weatherInfo: weatherInfo,
            outfitSuggestion: outfitSuggestion,
            personalizations: generatePersonalizations(for: config),
            reminders: reminders
        )
    }

    private func generateWeatherInfo() async -> WeatherInfo {
        return WeatherInfo(
            temperature: 68,
            condition: "Partly Cloudy",
            icon: "cloud.sun.fill",
            recommendations: [
                WeatherRecommendation(type: "layers", suggestion: "Light layering recommended"),
                WeatherRecommendation(type: "accessories", suggestion: "Consider bringing a light jacket"),
                WeatherRecommendation(type: "footwear", suggestion: "Comfortable walking shoes ideal")
            ]
        )
    }

    private func generateOutfitSuggestion(weather: WeatherInfo?) async -> OutfitSuggestion {
        return OutfitSuggestion(
            summary: "Smart casual with navy blazer",
            items: [
                SuggestedItem(name: "Navy Blazer", category: "Outer", color: "Navy", priority: .essential),
                SuggestedItem(name: "White Shirt", category: "Top", color: "White", priority: .essential),
                SuggestedItem(name: "Dark Jeans", category: "Bottom", color: "Dark Blue", priority: .essential),
                SuggestedItem(name: "Brown Loafers", category: "Shoes", color: "Brown", priority: .recommended),
                SuggestedItem(name: "Leather Watch", category: "Accessory", color: "Brown", priority: .optional)
            ],
            reasoning: "Perfect for today's weather and versatile for multiple occasions",
            alternatives: ["Casual Friday look with sweater", "More formal with dress pants"]
        )
    }

    private func generateSteps(for config: MorningRoutineConfig, weather: WeatherInfo?) -> [RoutineStep] {
        var baseSteps: [RoutineStep] = []

        switch config.duration {
        case .quick:
            baseSteps = [
                RoutineStep(id: "1", title: "Quick Weather Check", description: "Check conditions and adjust mindset", estimatedMinutes: 2, category: .preparation, icon: "sun.max.fill", isOptional: false, tips: ["Use widget for quick glance"], order: 1),
                RoutineStep(id: "2", title: "Select Outfit", description: "Choose or confirm today's outfit", estimatedMinutes: 5, category: .outfit_selection, icon: "tshirt.fill", isOptional: false, tips: ["Use AI suggestion", "Lay out night before"], order: 2),
                RoutineStep(id: "3", title: "Essential Grooming", description: "Basic grooming routine", estimatedMinutes: 5, category: .grooming, icon: "face.smiling.fill", isOptional: false, tips: ["Focus on face and hair"], order: 3),
                RoutineStep(id: "4", title: "Key Accessories", description: "Add essential accessories", estimatedMinutes: 2, category: .accessories, icon: "applewatch", isOptional: false, tips: ["Watch, bag, keys"], order: 4),
                RoutineStep(id: "5", title: "Final Check", description: "Mirror check and go", estimatedMinutes: 1, category: .final_check, icon: "checkmark.circle.fill", isOptional: false, tips: ["Overall look assessment"], order: 5)
            ]

        case .normal:
            baseSteps = [
                RoutineStep(id: "1", title: "Morning Preparation", description: "Get ready and check the day ahead", estimatedMinutes: 3, category: .preparation, icon: "sunrise.fill", isOptional: false, tips: ["Review schedule", "Check weather"], order: 1),
                RoutineStep(id: "2", title: "Outfit Selection", description: "Choose and lay out your outfit", estimatedMinutes: 8, category: .outfit_selection, icon: "tshirt.fill", isOptional: false, tips: ["Consider day's activities", "Check fit"], order: 2),
                RoutineStep(id: "3", title: "Personal Grooming", description: "Complete grooming routine", estimatedMinutes: 10, category: .grooming, icon: "face.smiling.fill", isOptional: false, tips: ["Hair, skincare, basic makeup"], order: 3),
                RoutineStep(id: "4", title: "Get Dressed", description: "Put on your selected outfit", estimatedMinutes: 5, category: .outfit_selection, icon: "person.fill", isOptional: false, tips: ["Check fit and comfort"], order: 4),
                RoutineStep(id: "5", title: "Add Accessories", description: "Complete with jewelry and accessories", estimatedMinutes: 3, category: .accessories, icon: "bag.fill", isOptional: false, tips: ["Match metals", "Consider occasion"], order: 5),
                RoutineStep(id: "6", title: "Final Styling", description: "Hair and final touches", estimatedMinutes: 5, category: .grooming, icon: "comb.fill", isOptional: true, tips: ["Style hair", "Perfume/cologne"], order: 6),
                RoutineStep(id: "7", title: "Mirror Check", description: "Full look assessment", estimatedMinutes: 2, category: .final_check, icon: "rectangle.portrait.fill", isOptional: false, tips: ["360-degree check", "Confidence boost"], order: 7),
                RoutineStep(id: "8", title: "Gather Essentials", description: "Collect daily necessities", estimatedMinutes: 2, category: .final_check, icon: "briefcase.fill", isOptional: false, tips: ["Phone, keys, wallet, bag"], order: 8)
            ]

        case .leisurely:
            baseSteps = [
                RoutineStep(id: "1", title: "Mindful Morning", description: "Start with intention and planning", estimatedMinutes: 5, category: .preparation, icon: "heart.fill", isOptional: false, tips: ["Deep breaths", "Set daily intention"], order: 1),
                RoutineStep(id: "2", title: "Style Planning", description: "Thoughtfully plan your look", estimatedMinutes: 10, category: .outfit_selection, icon: "lightbulb.fill", isOptional: false, tips: ["Consider mood and goals", "Try different combinations"], order: 2),
                RoutineStep(id: "3", title: "Skincare Routine", description: "Complete skincare regimen", estimatedMinutes: 8, category: .grooming, icon: "drop.fill", isOptional: false, tips: ["Cleanse, treat, moisturize"], order: 3),
                RoutineStep(id: "4", title: "Hair Care", description: "Style hair with care", estimatedMinutes: 10, category: .grooming, icon: "comb.fill", isOptional: false, tips: ["Use quality products", "Consider weather"], order: 4),
                RoutineStep(id: "5", title: "Makeup/Grooming", description: "Apply makeup or detailed grooming", estimatedMinutes: 12, category: .grooming, icon: "paintbrush.fill", isOptional: true, tips: ["Enhance natural features"], order: 5),
                RoutineStep(id: "6", title: "Dress Mindfully", description: "Put on outfit with attention to fit", estimatedMinutes: 5, category: .outfit_selection, icon: "person.fill", isOptional: false, tips: ["Appreciate fabric and fit"], order: 6),
                RoutineStep(id: "7", title: "Accessory Curation", description: "Carefully select accessories", estimatedMinutes: 5, category: .accessories, icon: "sparkles", isOptional: false, tips: ["Quality over quantity", "Tell your story"], order: 7),
                RoutineStep(id: "8", title: "Fragrance", description: "Select and apply fragrance", estimatedMinutes: 2, category: .accessories, icon: "aqi.medium", isOptional: true, tips: ["Match mood and occasion"], order: 8),
                RoutineStep(id: "9", title: "Style Photography", description: "Document your look", estimatedMinutes: 3, category: .final_check, icon: "camera.fill", isOptional: true, tips: ["Track what works"], order: 9),
                RoutineStep(id: "10", title: "Confidence Check", description: "Full mirror assessment", estimatedMinutes: 3, category: .final_check, icon: "star.fill", isOptional: false, tips: ["Feel confident and ready"], order: 10),
                RoutineStep(id: "11", title: "Bag Organization", description: "Organize bag contents", estimatedMinutes: 3, category: .final_check, icon: "bag.circle.fill", isOptional: false, tips: ["Check essentials", "Clean organization"], order: 11),
                RoutineStep(id: "12", title: "Positive Affirmation", description: "End with positive mindset", estimatedMinutes: 2, category: .final_check, icon: "heart.text.square.fill", isOptional: true, tips: ["You look amazing!"], order: 12)
            ]

        default:
            baseSteps = generateSteps(for: MorningRoutineConfig(includeWeatherCheck: config.includeWeatherCheck, autoGenerateOutfit: config.autoGenerateOutfit, setReminders: config.setReminders, duration: .normal, startTime: config.startTime), weather: weather)
        }

        return baseSteps
    }

    private func generatePersonalizations(for config: MorningRoutineConfig) -> [Personalization] {
        var personalizations: [Personalization] = []

        personalizations.append(Personalization(
            type: .time_constraint,
            value: config.duration.displayName,
            impact: "Routine optimized for \(config.duration.minutes) minutes"
        ))

        if config.includeWeatherCheck {
            personalizations.append(Personalization(
                type: .weather_sensitivity,
                value: "Enabled",
                impact: "Outfit and grooming adjusted for weather"
            ))
        }

        if config.autoGenerateOutfit {
            personalizations.append(Personalization(
                type: .style_preference,
                value: "AI-Assisted",
                impact: "Smart outfit suggestions included"
            ))
        }

        return personalizations
    }

    private func generateReminders(for steps: [RoutineStep], startTime: Date) -> [RoutineReminder] {
        var reminders: [RoutineReminder] = []
        var currentTime = startTime

        for step in steps {
            reminders.append(RoutineReminder(
                stepId: step.id,
                time: currentTime,
                message: "Time to \(step.title.lowercased())",
                type: .step_start
            ))

            currentTime = currentTime.addingTimeInterval(TimeInterval(step.estimatedMinutes * 60))

            reminders.append(RoutineReminder(
                stepId: step.id,
                time: currentTime,
                message: "\(step.title) complete! Moving to next step.",
                type: .step_complete
            ))
        }

        return reminders
    }
}

struct MorningRoutineView: View {
    let routine: MorningRoutine
    let config: MorningRoutineConfig

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Morning Routine")
                        .font(.headline)
                        .fontWeight(.bold)

                    Text("\(routine.estimatedDuration) min • \(routine.steps.count) steps")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if let weather = routine.weatherInfo {
                    VStack(alignment: .trailing, spacing: 2) {
                        HStack(spacing: 4) {
                            Image(systemName: weather.icon)
                                .font(.caption)
                                .foregroundColor(.blue)
                            Text("\(Int(weather.temperature))°")
                                .font(.caption)
                                .fontWeight(.semibold)
                        }

                        Text(weather.condition)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }


            if let outfit = routine.outfitSuggestion {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Today's Outfit")
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    Text(outfit.summary)
                        .font(.body)
                        .foregroundColor(.primary)

                    Text(outfit.reasoning)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .italic()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.green.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }


            VStack(alignment: .leading, spacing: 8) {
                Text("Routine Steps")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                ForEach(routine.steps.prefix(4), id: \.id) { step in
                    HStack(alignment: .center, spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(step.category.color.opacity(0.1))
                                .frame(width: 32, height: 32)

                            Image(systemName: step.icon)
                                .font(.caption)
                                .foregroundColor(step.category.color)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(step.title)
                                .font(.caption)
                                .fontWeight(.semibold)

                            Text(step.description)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 2) {
                            Text("\(step.estimatedMinutes) min")
                                .font(.caption2)
                                .fontWeight(.medium)
                                .foregroundColor(.blue)

                            if step.isOptional {
                                Text("Optional")
                                    .font(.system(size: 8))
                                    .foregroundColor(.orange)
                            }
                        }
                    }
                }

                if routine.steps.count > 4 {
                    Text("+ \(routine.steps.count - 4) more steps")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.leading, 44)
                }
            }
        }
        .padding()
    }
}