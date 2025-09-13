import SwiftUI

struct RecommendationFiltersView: View {
    @Binding var filters: RecommendationFilters
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var themeManager: ThemeManager
    @State private var tempFilters: RecommendationFilters

    init(filters: Binding<RecommendationFilters>) {
        self._filters = filters
        self._tempFilters = State(initialValue: filters.wrappedValue)
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    priceRangeSection
                    brandsSection
                    categoriesSection
                    colorsSection
                    sizesSection
                    sustainabilitySection
                    availabilitySection
                }
                .padding()
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Reset") {
                        tempFilters = RecommendationFilters()
                    }
                    .foregroundColor(.red)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Apply") {
                        filters = tempFilters
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private var priceRangeSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Price Range")
                .typography(.title3, theme: .modern)
                .fontWeight(.semibold)

            VStack(spacing: 12) {
                HStack {
                    Text("$\(Int(tempFilters.priceRange.lowerBound))")
                        .typography(.body2, theme: .minimal)
                        .foregroundColor(.secondary)

                    Spacer()

                    Text("$\(Int(tempFilters.priceRange.upperBound))")
                        .typography(.body2, theme: .minimal)
                        .foregroundColor(.secondary)
                }

                RangeSlider(
                    range: $tempFilters.priceRange,
                    bounds: 0...1000,
                    step: 10
                )
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.05))
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
        }
    }

    private var brandsSection: some View {
        FilterSection(
            title: "Brands",
            items: availableBrands,
            selectedItems: $tempFilters.brands
        )
    }

    private var categoriesSection: some View {
        FilterSection(
            title: "Categories",
            items: availableCategories,
            selectedItems: $tempFilters.categories
        )
    }

    private var colorsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Colors")
                .typography(.title3, theme: .modern)
                .fontWeight(.semibold)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
                ForEach(availableColors, id: \.self) { color in
                    ColorFilterButton(
                        color: color,
                        isSelected: tempFilters.colors.contains(color)
                    ) {
                        if tempFilters.colors.contains(color) {
                            tempFilters.colors.remove(color)
                        } else {
                            tempFilters.colors.insert(color)
                        }
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.05))
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
        }
    }

    private var sizesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Sizes")
                .typography(.title3, theme: .modern)
                .fontWeight(.semibold)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 8) {
                ForEach(availableSizes, id: \.self) { size in
                    SizeFilterButton(
                        size: size,
                        isSelected: tempFilters.sizes.contains(size)
                    ) {
                        if tempFilters.sizes.contains(size) {
                            tempFilters.sizes.remove(size)
                        } else {
                            tempFilters.sizes.insert(size)
                        }
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.05))
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
        }
    }

    private var sustainabilitySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Sustainability")
                .typography(.title3, theme: .modern)
                .fontWeight(.semibold)

            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "leaf.fill")
                        .font(.title3)
                        .foregroundColor(.green)

                    Text("Minimum sustainability score")
                        .typography(.body2, theme: .minimal)

                    Spacer()

                    Text("\(Int(tempFilters.sustainabilityScore))/10")
                        .typography(.body2, theme: .minimal)
                        .foregroundColor(.green)
                        .fontWeight(.semibold)
                }

                Slider(
                    value: $tempFilters.sustainabilityScore,
                    in: 0...10,
                    step: 1
                ) {
                    Text("Sustainability Score")
                }
                .tint(.green)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.05))
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
        }
    }

    private var availabilitySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Availability")
                .typography(.title3, theme: .modern)
                .fontWeight(.semibold)

            VStack(spacing: 12) {
                FilterToggle(
                    title: "Only show in-stock items",
                    subtitle: "Hide out-of-stock products",
                    isOn: $tempFilters.onlyInStock
                )

                FilterToggle(
                    title: "Include items on sale",
                    subtitle: "Show discounted products",
                    isOn: $tempFilters.includeOnSale
                )

                FilterToggle(
                    title: "Exclude recently viewed",
                    subtitle: "Hide products you've seen recently",
                    isOn: $tempFilters.excludeRecent
                )
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.05))
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
        }
    }

    // Mock data - in real app would come from API
    private let availableBrands = ["Zara", "H&M", "Uniqlo", "COS", "Arket", "Nike", "Adidas", "Levi's", "Free People"]
    private let availableCategories = ["Dresses", "Tops", "Bottoms", "Shoes", "Accessories", "Outerwear", "Activewear"]
    private let availableColors = ["Red", "Blue", "Green", "Yellow", "Purple", "Orange", "Pink", "Brown", "Black", "White", "Gray", "Navy"]
    private let availableSizes = ["XS", "S", "M", "L", "XL", "XXL"]
}

struct FilterSection: View {
    let title: String
    let items: [String]
    @Binding var selectedItems: Set<String>

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .typography(.title3, theme: .modern)
                .fontWeight(.semibold)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                ForEach(items, id: \.self) { item in
                    FilterChip(
                        text: item,
                        isSelected: selectedItems.contains(item)
                    ) {
                        if selectedItems.contains(item) {
                            selectedItems.remove(item)
                        } else {
                            selectedItems.insert(item)
                        }
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.05))
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
        }
    }
}

struct FilterChip: View {
    let text: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(text)
                .typography(.caption1, theme: .minimal)
                .fontWeight(.medium)
                .foregroundColor(isSelected ? .white : .primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(isSelected ? Color.blue : Color.white.opacity(0.1))
                        .stroke(isSelected ? Color.blue : Color.white.opacity(0.2), lineWidth: 1)
                )
        }
        .tapWithHaptic(.light)
    }
}

struct ColorFilterButton: View {
    let color: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Circle()
                .fill(colorValue)
                .frame(width: 40, height: 40)
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: 2)
                        .opacity(isSelected ? 1 : 0)
                )
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                )
                .overlay(
                    VStack(spacing: 2) {
                        if isSelected {
                            Image(systemName: "checkmark")
                                .font(.caption2)
                                .foregroundColor(.white)
                                .fontWeight(.bold)
                        }
                    }
                )
        }
        .tapWithHaptic(.light)
    }

    private var colorValue: Color {
        switch color.lowercased() {
        case "red": return .red
        case "blue": return .blue
        case "green": return .green
        case "yellow": return .yellow
        case "purple": return .purple
        case "orange": return .orange
        case "pink": return .pink
        case "brown": return .brown
        case "black": return .black
        case "white": return .white
        case "gray": return .gray
        case "navy": return .blue.opacity(0.8)
        default: return .gray
        }
    }
}

struct SizeFilterButton: View {
    let size: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(size)
                .typography(.caption1, theme: .minimal)
                .fontWeight(.semibold)
                .foregroundColor(isSelected ? .white : .primary)
                .frame(width: 50, height: 40)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isSelected ? Color.blue : Color.white.opacity(0.1))
                        .stroke(isSelected ? Color.blue : Color.white.opacity(0.2), lineWidth: 1)
                )
        }
        .tapWithHaptic(.light)
    }
}

struct FilterToggle: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .typography(.body2, theme: .modern)
                    .fontWeight(.medium)

                Text(subtitle)
                    .typography(.caption2, theme: .minimal)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Toggle("", isOn: $isOn)
                .tint(.blue)
        }
    }
}

struct RangeSlider: View {
    @Binding var range: ClosedRange<Double>
    let bounds: ClosedRange<Double>
    let step: Double

    @State private var lowValue: Double = 0
    @State private var highValue: Double = 1000

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Track
                Rectangle()
                    .fill(Color.white.opacity(0.2))
                    .frame(height: 4)
                    .cornerRadius(2)

                // Active range
                Rectangle()
                    .fill(Color.blue)
                    .frame(
                        width: activeRangeWidth(geometry: geometry),
                        height: 4
                    )
                    .cornerRadius(2)
                    .offset(x: lowHandlePosition(geometry: geometry))

                // Low value handle
                Circle()
                    .fill(Color.blue)
                    .frame(width: 20, height: 20)
                    .offset(x: lowHandlePosition(geometry: geometry) - 10)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                updateLowValue(
                                    dragValue: value.location.x,
                                    geometry: geometry
                                )
                            }
                    )

                // High value handle
                Circle()
                    .fill(Color.blue)
                    .frame(width: 20, height: 20)
                    .offset(x: highHandlePosition(geometry: geometry) - 10)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                updateHighValue(
                                    dragValue: value.location.x,
                                    geometry: geometry
                                )
                            }
                    )
            }
        }
        .frame(height: 20)
        .onAppear {
            lowValue = range.lowerBound
            highValue = range.upperBound
        }
        .onChange(of: lowValue) { _, newValue in
            range = newValue...highValue
        }
        .onChange(of: highValue) { _, newValue in
            range = lowValue...newValue
        }
    }

    private func lowHandlePosition(geometry: GeometryProxy) -> CGFloat {
        let percentage = (lowValue - bounds.lowerBound) / (bounds.upperBound - bounds.lowerBound)
        return percentage * geometry.size.width
    }

    private func highHandlePosition(geometry: GeometryProxy) -> CGFloat {
        let percentage = (highValue - bounds.lowerBound) / (bounds.upperBound - bounds.lowerBound)
        return percentage * geometry.size.width
    }

    private func activeRangeWidth(geometry: GeometryProxy) -> CGFloat {
        return highHandlePosition(geometry: geometry) - lowHandlePosition(geometry: geometry)
    }

    private func updateLowValue(dragValue: CGFloat, geometry: GeometryProxy) {
        let percentage = max(0, min(1, dragValue / geometry.size.width))
        let newValue = bounds.lowerBound + percentage * (bounds.upperBound - bounds.lowerBound)
        lowValue = min(newValue, highValue - step)
    }

    private func updateHighValue(dragValue: CGFloat, geometry: GeometryProxy) {
        let percentage = max(0, min(1, dragValue / geometry.size.width))
        let newValue = bounds.lowerBound + percentage * (bounds.upperBound - bounds.lowerBound)
        highValue = max(newValue, lowValue + step)
    }
}

#Preview {
    RecommendationFiltersView(filters: .constant(RecommendationFilters()))
        .environmentObject(ThemeManager())
}