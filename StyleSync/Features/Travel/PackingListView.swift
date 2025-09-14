import SwiftUI

struct PackingListView: View {
    @ObservedObject var travelManager: TravelProManager
    @State private var selectedCategory: PackingCategory.Priority?
    @State private var showingPackingTips = false
    @State private var searchText = ""

    var body: some View {
        NavigationStack {
            VStack {
                if let trip = travelManager.currentTrip,
                   let packingList = trip.packingList {

                    // Header with stats
                    packingStatsHeader(packingList)

                    // Category filter
                    categoryFilterView

                    // Search bar
                    SearchBar(text: $searchText, placeholder: "Search items...")

                    // Packing list
                    List {
                        ForEach(filteredCategories(packingList.categories), id: \.id) { category in
                            Section {
                                ForEach(filteredItems(category.items), id: \.id) { item in
                                    PackingItemRow(
                                        item: item,
                                        onToggle: { toggleItemPacked(item) }
                                    )
                                }
                            } header: {
                                HStack {
                                    Text(category.name)
                                        .font(.headline)
                                        .fontWeight(.medium)

                                    Spacer()

                                    priorityBadge(category.priority)
                                }
                            }
                        }

                        // Space optimization section
                        Section("Packing Optimization") {
                            SpaceOptimizationView(optimization: packingList.spaceOptimization)
                        }

                        // Laundry plan
                        if let laundryPlan = packingList.laundryPlan {
                            Section("Laundry Plan") {
                                LaundryPlanView(plan: laundryPlan)
                            }
                        }
                    }
                    .searchable(text: $searchText)

                } else {
                    emptyStateView
                }
            }
            .navigationTitle("Packing List")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Packing Tips") {
                            showingPackingTips = true
                        }
                        Button("Reset All Items") {
                            resetAllItems()
                        }
                        Button("Export Checklist") {
                            exportChecklist()
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showingPackingTips) {
                PackingTipsView()
            }
        }
    }

    private func packingStatsHeader(_ packingList: PackingList) -> some View {
        VStack(spacing: 16) {
            // Progress ring
            HStack(spacing: 20) {
                CircularProgressView(
                    progress: Double(packedItemsCount(packingList)) / Double(totalItemsCount(packingList)),
                    title: "Packed",
                    subtitle: "\(packedItemsCount(packingList))/\(totalItemsCount(packingList))"
                )

                CircularProgressView(
                    progress: packingList.spaceOptimization.spaceUtilization,
                    title: "Optimized",
                    subtitle: "\(Int(packingList.spaceOptimization.spaceUtilization * 100))%"
                )

                CircularProgressView(
                    progress: min(1.0, packingList.totalWeight / 23.0), // 23kg typical limit
                    title: "Weight",
                    subtitle: "\(String(format: "%.1f", packingList.totalWeight))kg"
                )
            }

            // Weight distribution
            if !packingList.spaceOptimization.weightDistribution.isOptimal {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)

                    Text("Weight distribution needs adjustment")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.orange.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }

    private var categoryFilterView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                FilterChip(
                    title: "All",
                    isSelected: selectedCategory == nil
                ) {
                    selectedCategory = nil
                }

                ForEach(PackingCategory.Priority.allCases, id: \.self) { priority in
                    FilterChip(
                        title: priority.rawValue,
                        isSelected: selectedCategory == priority
                    ) {
                        selectedCategory = selectedCategory == priority ? nil : priority
                    }
                }
            }
            .padding(.horizontal)
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "checklist")
                .font(.system(size: 60))
                .foregroundColor(.gray)

            Text("No Trip Selected")
                .font(.title2)
                .fontWeight(.medium)

            Text("Create a trip to generate your personalized packing list")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    private func filteredCategories(_ categories: [PackingCategory]) -> [PackingCategory] {
        if let selectedCategory = selectedCategory {
            return categories.filter { $0.priority == selectedCategory }
        }
        return categories
    }

    private func filteredItems(_ items: [PackingItem]) -> [PackingItem] {
        if searchText.isEmpty {
            return items
        }
        return items.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    private func packedItemsCount(_ packingList: PackingList) -> Int {
        packingList.categories.flatMap(\.items).filter(\.isPacked).count
    }

    private func totalItemsCount(_ packingList: PackingList) -> Int {
        packingList.categories.flatMap(\.items).count
    }

    private func toggleItemPacked(_ item: PackingItem) {
        // Implementation would update the item's packed status
        // This would typically be handled by the travel manager
    }

    private func resetAllItems() {
        // Reset all items to unpacked state
    }

    private func exportChecklist() {
        // Export packing list as PDF or share
    }

    private func priorityBadge(_ priority: PackingCategory.Priority) -> some View {
        Text(priority.rawValue.uppercased())
            .font(.caption2)
            .fontWeight(.bold)
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(priorityColor(priority))
            .clipShape(Capsule())
    }

    private func priorityColor(_ priority: PackingCategory.Priority) -> Color {
        switch priority {
        case .essential: return .red
        case .recommended: return .orange
        case .optional: return .blue
        }
    }
}

struct PackingItemRow: View {
    let item: PackingItem
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onToggle) {
                Image(systemName: item.isPacked ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundColor(item.isPacked ? .green : .secondary)
            }
            .buttonStyle(PlainButtonStyle())

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(item.name)
                        .font(.body)
                        .fontWeight(.medium)
                        .strikethrough(item.isPacked)
                        .foregroundColor(item.isPacked ? .secondary : .primary)

                    if item.quantity > 1 {
                        Text("×\(item.quantity)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(.systemGray5))
                            .clipShape(Capsule())
                    }
                }

                HStack {
                    Text("\(String(format: "%.1f", item.weight))kg")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if item.weatherSpecific {
                        Image(systemName: "cloud.sun")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }

                    if !item.activitySpecific.isEmpty {
                        Image(systemName: "figure.walk")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("Versatility")
                    .font(.caption2)
                    .foregroundColor(.secondary)

                Text("\(Int(item.versatilityScore * 100))%")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(versatilityColor(item.versatilityScore))
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            onToggle()
        }
    }

    private func versatilityColor(_ score: Double) -> Color {
        if score >= 0.8 { return .green }
        if score >= 0.6 { return .orange }
        return .red
    }
}

struct CircularProgressView: View {
    let progress: Double
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(Color(.systemGray5), lineWidth: 4)
                    .frame(width: 60, height: 60)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(progressColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 60, height: 60)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 1.0), value: progress)

                Text("\(Int(progress * 100))")
                    .font(.caption)
                    .fontWeight(.bold)
            }

            VStack(spacing: 2) {
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)

                Text(subtitle)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var progressColor: Color {
        if progress >= 0.8 { return .green }
        if progress >= 0.6 { return .orange }
        return .red
    }
}

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color.blue : Color(.systemGray5))
                .foregroundColor(isSelected ? .white : .primary)
                .clipShape(Capsule())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct SpaceOptimizationView: View {
    let optimization: SpaceOptimization

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "cube.box")
                    .foregroundColor(.blue)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Space Utilization")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Text("\(Int(optimization.spaceUtilization * 100))% of available space")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }

            // Weight distribution
            VStack(alignment: .leading, spacing: 8) {
                Text("Weight Distribution")
                    .font(.caption)
                    .fontWeight(.medium)

                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Carry-on")
                            .font(.caption2)
                        Text("\(String(format: "%.1f", optimization.weightDistribution.carryOnWeight))kg")
                            .font(.caption)
                            .fontWeight(.medium)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Checked")
                            .font(.caption2)
                        Text("\(String(format: "%.1f", optimization.weightDistribution.checkedBagWeight))kg")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                }
            }

            // Folding techniques
            if !optimization.foldingTechniques.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Recommended Techniques")
                        .font(.caption)
                        .fontWeight(.medium)

                    ForEach(optimization.foldingTechniques, id: \.itemType) { technique in
                        HStack {
                            Text(technique.itemType)
                                .font(.caption2)

                            Spacer()

                            Text(technique.technique)
                                .font(.caption2)
                                .foregroundColor(.blue)

                            Text("(\(Int(technique.spaceSavings * 100))% savings)")
                                .font(.caption2)
                                .foregroundColor(.green)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 8)
    }
}

struct LaundryPlanView: View {
    let plan: LaundryPlan

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !plan.recommendedWashDays.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "washer")
                            .foregroundColor(.blue)

                        Text("Recommended Wash Days")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }

                    ForEach(plan.recommendedWashDays, id: \.self) { date in
                        Text(DateFormatter.mediumStyle.string(from: date))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            if !plan.essentialsToPackMultiple.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Pack Multiple")
                        .font(.caption)
                        .fontWeight(.medium)

                    Text(plan.essentialsToPackMultiple.joined(separator: ", "))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 8)
    }
}

struct PackingTipsView: View {
    @Environment(\.dismiss) private var dismiss

    private let tips = [
        PackingTip(
            title: "Roll, Don't Fold",
            description: "Rolling clothes saves up to 40% more space than folding",
            icon: "arrow.clockwise"
        ),
        PackingTip(
            title: "Use Packing Cubes",
            description: "Organize items by category and compress for maximum efficiency",
            icon: "cube.box"
        ),
        PackingTip(
            title: "Heaviest Items First",
            description: "Place heavy items at the bottom and against the back wall",
            icon: "arrow.down.to.line.compact"
        ),
        PackingTip(
            title: "Wear Heavy Items",
            description: "Wear your heaviest shoes and jacket on the plane to save luggage space",
            icon: "figure.walk"
        ),
        PackingTip(
            title: "Multi-Purpose Items",
            description: "Choose items that work for multiple occasions and activities",
            icon: "arrow.triangle.branch"
        )
    ]

    var body: some View {
        NavigationStack {
            List {
                ForEach(tips, id: \.title) { tip in
                    HStack(spacing: 16) {
                        Image(systemName: tip.icon)
                            .font(.title2)
                            .foregroundColor(.blue)
                            .frame(width: 30)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(tip.title)
                                .font(.headline)
                                .fontWeight(.medium)

                            Text(tip.description)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle("Packing Tips")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct PackingTip {
    let title: String
    let description: String
    let icon: String
}

extension DateFormatter {
    static let mediumStyle: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }()
}

#Preview {
    PackingListView(travelManager: TravelProManager())
}