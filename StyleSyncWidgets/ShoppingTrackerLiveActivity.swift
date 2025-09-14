import ActivityKit
import SwiftUI
import WidgetKit

struct ShoppingTrackerAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var foundItems: [String]
        var budget: Double
        var spent: Double
        var currentStore: String
        var deals: [Deal]
        var sessionDuration: TimeInterval
    }

    var shoppingListId: String
    var targetItems: [ShoppingItem]
    var totalBudget: Double
    var startTime: Date
}

struct ShoppingItem: Codable, Hashable {
    let id: String
    let name: String
    let category: String
    let targetPrice: Double?
    let priority: ShoppingPriority
    let isFound: Bool
}

struct Deal: Codable, Hashable {
    let id: String
    let itemName: String
    let originalPrice: Double
    let salePrice: Double
    let discount: Double
    let store: String
}

enum ShoppingPriority: String, Codable, CaseIterable {
    case must_have = "must_have"
    case want = "want"
    case nice_to_have = "nice_to_have"

    var color: Color {
        switch self {
        case .must_have: return .red
        case .want: return .orange
        case .nice_to_have: return .green
        }
    }

    var icon: String {
        switch self {
        case .must_have: return "exclamationmark.triangle.fill"
        case .want: return "star.fill"
        case .nice_to_have: return "heart"
        }
    }
}

struct ShoppingTrackerLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ShoppingTrackerAttributes.self) { context in
            ShoppingTrackerLockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Shopping Trip")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)

                        Text("\(context.state.foundItems.count)/\(context.attributes.targetItems.count) found")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }

                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("$\(String(format: "%.0f", context.state.spent))")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(context.state.spent > context.state.budget ? .red : .primary)

                        Text("of $\(String(format: "%.0f", context.state.budget))")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }

                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 6) {
                        Text("@ \(context.state.currentStore)")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)

                        ProgressView(value: Double(context.state.foundItems.count) / Double(context.attributes.targetItems.count))
                            .progressViewStyle(LinearProgressViewStyle(tint: .green))
                            .frame(height: 4)

                        HStack {
                            Text("\(timeString(from: context.state.sessionDuration))")
                                .font(.caption2)
                                .foregroundColor(.secondary)

                            Spacer()

                            if !context.state.deals.isEmpty {
                                Text("\(context.state.deals.count) deals")
                                    .font(.caption2)
                                    .foregroundColor(.orange)
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
                                Button(intent: AddFoundItemIntent(shoppingId: context.attributes.shoppingListId)) {
                                    Text("Found Item")
                                        .font(.caption2)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(.green.opacity(0.2))
                                        .foregroundColor(.green)
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)

                                Button(intent: LogExpenseIntent(shoppingId: context.attributes.shoppingListId)) {
                                    Text("Log Purchase")
                                        .font(.caption2)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(.blue.opacity(0.2))
                                        .foregroundColor(.blue)
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        Spacer()

                        BudgetProgressView(
                            spent: context.state.spent,
                            budget: context.state.budget,
                            size: 30
                        )
                    }
                }
            } compactLeading: {
                Image(systemName: "bag.fill")
                    .foregroundColor(.blue)
            } compactTrailing: {
                Text("\(context.state.foundItems.count)/\(context.attributes.targetItems.count)")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
            } minimal: {
                BudgetProgressView(
                    spent: context.state.spent,
                    budget: context.state.budget,
                    size: 16
                )
            }
        }
    }
}

struct ShoppingTrackerLockScreenView: View {
    let context: ActivityViewContext<ShoppingTrackerAttributes>

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Shopping Session")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("\(context.state.currentStore)")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    BudgetProgressView(
                        spent: context.state.spent,
                        budget: context.state.budget,
                        size: 50
                    )

                    Text(timeString(from: context.state.sessionDuration))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            VStack(spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Progress")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)

                        Text("\(context.state.foundItems.count) of \(context.attributes.targetItems.count) items found")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Budget")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)

                        Text("$\(String(format: "%.0f", context.state.spent)) / $\(String(format: "%.0f", context.state.budget))")
                            .font(.caption)
                            .foregroundColor(context.state.spent > context.state.budget ? .red : .secondary)
                    }
                }

                VStack(spacing: 6) {
                    ProgressView(value: Double(context.state.foundItems.count) / Double(context.attributes.targetItems.count))
                        .progressViewStyle(LinearProgressViewStyle(tint: .green))
                        .frame(height: 6)

                    ProgressView(value: min(1.0, context.state.spent / context.state.budget))
                        .progressViewStyle(LinearProgressViewStyle(tint: context.state.spent > context.state.budget ? .red : .blue))
                        .frame(height: 4)
                }
            }

            if !context.state.deals.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Active Deals")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)

                        Spacer()

                        Text("$\(String(format: "%.0f", context.state.deals.reduce(0) { $0 + ($1.originalPrice - $1.salePrice) })) saved")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(.green)
                    }

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(context.state.deals.prefix(3), id: \.id) { deal in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(deal.itemName)
                                        .font(.caption2)
                                        .fontWeight(.medium)
                                        .foregroundColor(.primary)
                                        .lineLimit(1)

                                    HStack(spacing: 4) {
                                        Text("$\(String(format: "%.0f", deal.salePrice))")
                                            .font(.caption2)
                                            .fontWeight(.bold)
                                            .foregroundColor(.green)

                                        Text("$\(String(format: "%.0f", deal.originalPrice))")
                                            .font(.caption2)
                                            .strikethrough()
                                            .foregroundColor(.secondary)
                                    }

                                    Text("\(Int(deal.discount))% off")
                                        .font(.system(size: 9))
                                        .foregroundColor(.orange)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 6)
                                .background(.orange.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                        .padding(.horizontal, 1)
                    }
                }
            }

            HStack(spacing: 8) {
                Button(intent: AddFoundItemIntent(shoppingId: context.attributes.shoppingListId)) {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle")
                            .font(.caption)
                        Text("Found Item")
                            .font(.caption)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.green)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                Button(intent: LogExpenseIntent(shoppingId: context.attributes.shoppingListId)) {
                    HStack(spacing: 4) {
                        Image(systemName: "dollarsign.circle")
                            .font(.caption)
                        Text("Log Purchase")
                            .font(.caption)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.blue)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                Spacer()

                Button(intent: ViewShoppingListIntent(shoppingId: context.attributes.shoppingListId)) {
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
        .padding()
        .background(.regularMaterial)
    }
}

struct BudgetProgressView: View {
    let spent: Double
    let budget: Double
    let size: CGFloat

    private var progress: Double {
        guard budget > 0 else { return 0 }
        return min(1.0, spent / budget)
    }

    private var isOverBudget: Bool {
        spent > budget
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.gray.opacity(0.3), lineWidth: size * 0.08)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(isOverBudget ? Color.red : Color.blue, style: StrokeStyle(lineWidth: size * 0.08, lineCap: .round))
                .rotationEffect(.degrees(-90))

            VStack(spacing: size * 0.04) {
                Text("$\(String(format: "%.0f", spent))")
                    .font(.system(size: size * 0.2, weight: .bold))
                    .foregroundColor(isOverBudget ? .red : .primary)

                if size > 30 {
                    Text("of $\(String(format: "%.0f", budget))")
                        .font(.system(size: size * 0.12))
                        .foregroundColor(.secondary)
                }
            }
        }
        .frame(width: size, height: size)
    }
}

struct AddFoundItemIntent: AppIntent {
    static var title: LocalizedStringResource = "Found Item"
    static var description = IntentDescription("Mark an item as found")

    @Parameter(title: "Shopping ID")
    var shoppingId: String

    func perform() async throws -> some IntentResult {
        return .result()
    }
}

struct LogExpenseIntent: AppIntent {
    static var title: LocalizedStringResource = "Log Purchase"
    static var description = IntentDescription("Log a purchase and update budget")

    @Parameter(title: "Shopping ID")
    var shoppingId: String

    func perform() async throws -> some IntentResult {
        return .result()
    }
}

struct ViewShoppingListIntent: AppIntent {
    static var title: LocalizedStringResource = "View Shopping List"
    static var description = IntentDescription("Open the full shopping list")

    @Parameter(title: "Shopping ID")
    var shoppingId: String

    func perform() async throws -> some IntentResult {
        return .result()
    }
}

private func timeString(from timeInterval: TimeInterval) -> String {
    let hours = Int(timeInterval) / 3600
    let minutes = Int(timeInterval % 3600) / 60

    if hours > 0 {
        return "\(hours)h \(minutes)m"
    } else {
        return "\(minutes)m"
    }
}