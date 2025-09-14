import ActivityKit
import SwiftUI
import WidgetKit

struct DailyReminderAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var currentStep: ReminderStep
        var completedSteps: [String]
        var timeRemaining: TimeInterval
        var weatherUpdate: WeatherUpdate?
        var motivationalMessage: String
    }

    var morningRoutineId: String
    var targetTime: Date
    var steps: [ReminderStep]
    var personalizedSettings: PersonalizedSettings
}

struct ReminderStep: Codable, Hashable {
    let id: String
    let title: String
    let description: String
    let icon: String
    let estimatedMinutes: Int
    let isCompleted: Bool
    let category: StepCategory
}

struct WeatherUpdate: Codable, Hashable {
    let temperature: Int
    let condition: String
    let recommendation: String
    let icon: String
}

struct PersonalizedSettings: Codable, Hashable {
    let wakeUpTime: Date
    let preparationTime: Int
    let stylePreferences: [String]
    let notifications: Bool
}

enum StepCategory: String, Codable, CaseIterable {
    case outfit = "outfit"
    case grooming = "grooming"
    case accessories = "accessories"
    case final = "final"

    var color: Color {
        switch self {
        case .outfit: return .blue
        case .grooming: return .green
        case .accessories: return .purple
        case .final: return .orange
        }
    }

    var displayName: String {
        switch self {
        case .outfit: return "Outfit"
        case .grooming: return "Grooming"
        case .accessories: return "Accessories"
        case .final: return "Final Check"
        }
    }
}

struct DailyReminderLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: DailyReminderAttributes.self) { context in
            DailyReminderLockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Morning Prep")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)

                        Text(context.state.currentStep.category.displayName)
                            .font(.caption2)
                            .foregroundColor(context.state.currentStep.category.color)
                    }
                }

                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(timeString(from: context.state.timeRemaining))
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(context.state.timeRemaining < 300 ? .red : .primary)

                        Text("remaining")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }

                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 6) {
                        Text(context.state.currentStep.title)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.center)

                        ProgressView(value: Double(context.state.completedSteps.count) / Double(context.attributes.steps.count))
                            .progressViewStyle(LinearProgressViewStyle(tint: context.state.currentStep.category.color))
                            .frame(height: 4)

                        if let weather = context.state.weatherUpdate {
                            HStack(spacing: 4) {
                                Image(systemName: weather.icon)
                                    .font(.caption2)
                                    .foregroundColor(.blue)
                                Text("\(weather.temperature)°")
                                    .font(.caption2)
                                    .foregroundColor(.primary)
                            }
                        }
                    }
                }

                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Quick Actions")
                                .font(.caption2)
                                .foregroundColor(.secondary)

                            HStack(spacing: 8) {
                                Button(intent: CompleteStepIntent(routineId: context.attributes.morningRoutineId, stepId: context.state.currentStep.id)) {
                                    Text("Done")
                                        .font(.caption2)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(.green.opacity(0.2))
                                        .foregroundColor(.green)
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)

                                Button(intent: SkipStepIntent(routineId: context.attributes.morningRoutineId, stepId: context.state.currentStep.id)) {
                                    Text("Skip")
                                        .font(.caption2)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(.gray.opacity(0.2))
                                        .foregroundColor(.secondary)
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        Spacer()

                        CircularStepProgress(
                            completed: context.state.completedSteps.count,
                            total: context.attributes.steps.count,
                            size: 30
                        )
                    }
                }
            } compactLeading: {
                Image(systemName: context.state.currentStep.icon)
                    .foregroundColor(context.state.currentStep.category.color)
            } compactTrailing: {
                Text("\(context.state.completedSteps.count)/\(context.attributes.steps.count)")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
            } minimal: {
                CircularStepProgress(
                    completed: context.state.completedSteps.count,
                    total: context.attributes.steps.count,
                    size: 16
                )
            }
        }
    }
}

struct DailyReminderLockScreenView: View {
    let context: ActivityViewContext<DailyReminderAttributes>

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Morning Routine")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("Get Ready")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    CircularStepProgress(
                        completed: context.state.completedSteps.count,
                        total: context.attributes.steps.count,
                        size: 50
                    )

                    Text(timeString(from: context.state.timeRemaining))
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(context.state.timeRemaining < 300 ? .red : .blue)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: context.state.currentStep.icon)
                        .font(.title2)
                        .foregroundColor(context.state.currentStep.category.color)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(context.state.currentStep.title)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)

                        Text(context.state.currentStep.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(context.state.currentStep.estimatedMinutes) min")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(.blue)

                        Text(context.state.currentStep.category.displayName)
                            .font(.caption2)
                            .foregroundColor(context.state.currentStep.category.color)
                    }
                }

                ProgressView(value: Double(context.state.completedSteps.count) / Double(context.attributes.steps.count))
                    .progressViewStyle(LinearProgressViewStyle(tint: context.state.currentStep.category.color))
                    .frame(height: 6)
            }

            if let weather = context.state.weatherUpdate {
                HStack(spacing: 8) {
                    Image(systemName: weather.icon)
                        .font(.title3)
                        .foregroundColor(.blue)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(weather.temperature)° - \(weather.condition)")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)

                        Text(weather.recommendation)
                            .font(.caption2)
                            .foregroundColor(.blue)
                            .italic()
                    }

                    Spacer()
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(.blue.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            VStack(alignment: .leading, spacing: 6) {
                if !context.state.motivationalMessage.isEmpty {
                    Text(context.state.motivationalMessage)
                        .font(.caption)
                        .fontStyle(.italic)
                        .foregroundColor(.purple)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.purple.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius, 6))
                }

                HStack(spacing: 8) {
                    Button(intent: CompleteStepIntent(routineId: context.attributes.morningRoutineId, stepId: context.state.currentStep.id)) {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle")
                                .font(.caption)
                            Text("Complete Step")
                                .font(.caption)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.green)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)

                    Button(intent: SkipStepIntent(routineId: context.attributes.morningRoutineId, stepId: context.state.currentStep.id)) {
                        HStack(spacing: 4) {
                            Image(systemName: "forward.fill")
                                .font(.caption)
                            Text("Skip")
                                .font(.caption)
                        }
                        .foregroundColor(.primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.gray.opacity(0.2))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    Button(intent: ViewFullRoutineIntent(routineId: context.attributes.morningRoutineId)) {
                        Image(systemName: "list.bullet")
                            .font(.caption)
                            .foregroundColor(.blue)
                            .frame(width: 32, height: 32)
                            .background(.blue.opacity(0.1))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding()
        .background(.regularMaterial)
    }
}

struct CircularStepProgress: View {
    let completed: Int
    let total: Int
    let size: CGFloat

    private var progress: Double {
        guard total > 0 else { return 0 }
        return Double(completed) / Double(total)
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.gray.opacity(0.3), lineWidth: size * 0.08)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(progress >= 1.0 ? Color.green : Color.blue, style: StrokeStyle(lineWidth: size * 0.08, lineCap: .round))
                .rotationEffect(.degrees(-90))

            if progress >= 1.0 {
                Image(systemName: "checkmark")
                    .font(.system(size: size * 0.4, weight: .bold))
                    .foregroundColor(.green)
            } else {
                VStack(spacing: size * 0.02) {
                    Text("\(completed)")
                        .font(.system(size: size * 0.25, weight: .bold))
                        .foregroundColor(.primary)

                    if size > 30 {
                        Text("of \(total)")
                            .font(.system(size: size * 0.15))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .frame(width: size, height: size)
    }
}

struct CompleteStepIntent: AppIntent {
    static var title: LocalizedStringResource = "Complete Step"
    static var description = IntentDescription("Mark the current step as completed")

    @Parameter(title: "Routine ID")
    var routineId: String

    @Parameter(title: "Step ID")
    var stepId: String

    func perform() async throws -> some IntentResult {
        return .result()
    }
}

struct SkipStepIntent: AppIntent {
    static var title: LocalizedStringResource = "Skip Step"
    static var description = IntentDescription("Skip the current step")

    @Parameter(title: "Routine ID")
    var routineId: String

    @Parameter(title: "Step ID")
    var stepId: String

    func perform() async throws -> some IntentResult {
        return .result()
    }
}

struct ViewFullRoutineIntent: AppIntent {
    static var title: LocalizedStringResource = "View Full Routine"
    static var description = IntentDescription("Open the complete morning routine")

    @Parameter(title: "Routine ID")
    var routineId: String

    func perform() async throws -> some IntentResult {
        return .result()
    }
}

private func timeString(from timeInterval: TimeInterval) -> String {
    if timeInterval < 60 {
        return "\(Int(timeInterval))s"
    } else if timeInterval < 3600 {
        let minutes = Int(timeInterval) / 60
        return "\(minutes)m"
    } else {
        let hours = Int(timeInterval) / 3600
        let minutes = Int(timeInterval % 3600) / 60
        return "\(hours)h \(minutes)m"
    }
}