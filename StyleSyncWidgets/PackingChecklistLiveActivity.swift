import ActivityKit
import SwiftUI
import WidgetKit

struct PackingChecklistAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var checkedItems: [String]
        var totalItems: Int
        var currentCategory: String
        var timeRemaining: TimeInterval?
        var isComplete: Bool
    }

    var tripName: String
    var departureTime: Date
    var categories: [String]
    var items: [PackingItem]
}

struct PackingItem: Codable, Hashable {
    let id: String
    let name: String
    let category: String
    let priority: Priority
    let isChecked: Bool

    enum Priority: String, Codable, CaseIterable {
        case essential = "essential"
        case important = "important"
        case optional = "optional"

        var color: Color {
            switch self {
            case .essential: return .red
            case .important: return .orange
            case .optional: return .green
            }
        }

        var icon: String {
            switch self {
            case .essential: return "exclamationmark.triangle.fill"
            case .important: return "star.fill"
            case .optional: return "checkmark.circle"
            }
        }
    }
}

struct PackingChecklistLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PackingChecklistAttributes.self) { context in
            PackingChecklistLockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(context.attributes.tripName)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)

                        Text("\(context.state.checkedItems.count)/\(context.state.totalItems) packed")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }

                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 4) {
                        if let timeRemaining = context.state.timeRemaining {
                            Text(timeString(from: timeRemaining))
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(timeRemaining < 3600 ? .red : .primary)
                        }

                        Text("until departure")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }

                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 6) {
                        Text("Current: \(context.state.currentCategory)")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)

                        ProgressView(value: Double(context.state.checkedItems.count) / Double(context.state.totalItems))
                            .progressViewStyle(LinearProgressViewStyle(tint: context.state.isComplete ? .green : .blue))
                            .frame(height: 4)

                        if context.state.isComplete {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.caption)
                                    .foregroundColor(.green)
                                Text("All Packed!")
                                    .font(.caption2)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.green)
                            }
                        }
                    }
                }

                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        if !context.state.isComplete {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Quick Actions")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)

                                HStack(spacing: 8) {
                                    Button(intent: CheckNextItemIntent(tripId: context.attributes.tripName)) {
                                        Text("Check Next")
                                            .font(.caption2)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(.blue.opacity(0.2))
                                            .foregroundColor(.blue)
                                            .clipShape(Capsule())
                                    }
                                    .buttonStyle(.plain)

                                    Button(intent: ViewListIntent(tripId: context.attributes.tripName)) {
                                        Text("View All")
                                            .font(.caption2)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(.gray.opacity(0.2))
                                            .foregroundColor(.primary)
                                            .clipShape(Capsule())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }

                        Spacer()

                        CircularProgressView(
                            progress: Double(context.state.checkedItems.count) / Double(context.state.totalItems),
                            lineWidth: 3,
                            size: 30
                        )
                    }
                }
            } compactLeading: {
                Image(systemName: context.state.isComplete ? "checkmark.circle.fill" : "list.bullet.clipboard")
                    .foregroundColor(context.state.isComplete ? .green : .blue)
            } compactTrailing: {
                Text("\(context.state.checkedItems.count)/\(context.state.totalItems)")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
            } minimal: {
                CircularProgressView(
                    progress: Double(context.state.checkedItems.count) / Double(context.state.totalItems),
                    lineWidth: 2,
                    size: 16
                )
            }
        }
    }
}

struct PackingChecklistLockScreenView: View {
    let context: ActivityViewContext<PackingChecklistAttributes>

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Packing Progress")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text(context.attributes.tripName)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                }

                Spacer()

                CircularProgressView(
                    progress: Double(context.state.checkedItems.count) / Double(context.state.totalItems),
                    lineWidth: 4,
                    size: 50
                )
            }

            VStack(spacing: 8) {
                HStack {
                    Text("Progress: \(context.state.checkedItems.count)/\(context.state.totalItems) items")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)

                    Spacer()

                    if let timeRemaining = context.state.timeRemaining {
                        Text(timeString(from: timeRemaining))
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(timeRemaining < 3600 ? .red : .blue)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background((timeRemaining < 3600 ? Color.red : Color.blue).opacity(0.1))
                            .clipShape(Capsule())
                    }
                }

                ProgressView(value: Double(context.state.checkedItems.count) / Double(context.state.totalItems))
                    .progressViewStyle(LinearProgressViewStyle(tint: context.state.isComplete ? .green : .blue))
                    .frame(height: 6)
            }

            if context.state.isComplete {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.green)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("All Packed!")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.green)

                        Text("Ready for your trip to \(context.attributes.tripName)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()
                }
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Current Category: \(context.state.currentCategory)")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)

                    HStack(spacing: 8) {
                        Button(intent: CheckNextItemIntent(tripId: context.attributes.tripName)) {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle")
                                    .font(.caption)
                                Text("Check Next Item")
                                    .font(.caption)
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(.blue)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)

                        Button(intent: ViewListIntent(tripId: context.attributes.tripName)) {
                            HStack(spacing: 4) {
                                Image(systemName: "list.bullet")
                                    .font(.caption)
                                Text("View Full List")
                                    .font(.caption)
                            }
                            .foregroundColor(.blue)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(.blue.opacity(0.1))
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)

                        Spacer()

                        Button(intent: AddItemIntent(tripId: context.attributes.tripName)) {
                            Image(systemName: "plus")
                                .font(.caption)
                                .foregroundColor(.blue)
                                .frame(width: 24, height: 24)
                                .background(.blue.opacity(0.1))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if !context.attributes.categories.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Categories")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(context.attributes.categories, id: \.self) { category in
                                let isActive = category == context.state.currentCategory
                                Text(category)
                                    .font(.caption2)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(isActive ? .blue : .gray.opacity(0.2))
                                    .foregroundColor(isActive ? .white : .primary)
                                    .clipShape(Capsule())
                            }
                        }
                        .padding(.horizontal, 1)
                    }
                }
            }
        }
        .padding()
        .background(.regularMaterial)
    }
}

struct CircularProgressView: View {
    let progress: Double
    let lineWidth: CGFloat
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.gray.opacity(0.3), lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(progress >= 1.0 ? Color.green : Color.blue, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))

            if progress >= 1.0 {
                Image(systemName: "checkmark")
                    .font(.system(size: size * 0.4, weight: .bold))
                    .foregroundColor(.green)
            } else {
                Text("\(Int(progress * 100))%")
                    .font(.system(size: size * 0.25, weight: .semibold))
                    .foregroundColor(.primary)
            }
        }
        .frame(width: size, height: size)
    }
}

struct CheckNextItemIntent: AppIntent {
    static var title: LocalizedStringResource = "Check Next Item"
    static var description = IntentDescription("Mark the next item as packed")

    @Parameter(title: "Trip ID")
    var tripId: String

    func perform() async throws -> some IntentResult {
        return .result()
    }
}

struct ViewListIntent: AppIntent {
    static var title: LocalizedStringResource = "View Full List"
    static var description = IntentDescription("Open the full packing list")

    @Parameter(title: "Trip ID")
    var tripId: String

    func perform() async throws -> some IntentResult {
        return .result()
    }
}

struct AddItemIntent: AppIntent {
    static var title: LocalizedStringResource = "Add Item"
    static var description = IntentDescription("Add a new item to the packing list")

    @Parameter(title: "Trip ID")
    var tripId: String

    func perform() async throws -> some IntentResult {
        return .result()
    }
}

private func timeString(from timeInterval: TimeInterval) -> String {
    if timeInterval < 3600 {
        let minutes = Int(timeInterval) / 60
        return "\(minutes)m"
    } else if timeInterval < 86400 {
        let hours = Int(timeInterval) / 3600
        let minutes = Int(timeInterval % 3600) / 60
        return "\(hours)h \(minutes)m"
    } else {
        let days = Int(timeInterval) / 86400
        let hours = Int(timeInterval % 86400) / 3600
        return "\(days)d \(hours)h"
    }
}