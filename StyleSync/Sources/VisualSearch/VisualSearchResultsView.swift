import SwiftUI

struct VisualSearchResultsView: View {
    let results: [VisualSearchResult]
    @State private var selectedTab: ResultsTab = .products
    @State private var selectedProduct: Product?
    @State private var showingProductDetail = false
    @State private var searchFilters = SearchFilters()
    @State private var showingFilters = false
    @State private var sortOption: SortOption = .relevance

    enum ResultsTab: CaseIterable {
        case products, similar, history

        var title: String {
            switch self {
            case .products: return "Products"
            case .similar: return "Similar"
            case .history: return "History"
            }
        }

        var icon: String {
            switch self {
            case .products: return "bag.fill"
            case .similar: return "eye.fill"
            case .history: return "clock.fill"
            }
        }
    }

    enum SortOption: CaseIterable {
        case relevance, price, brand, newest

        var title: String {
            switch self {
            case .relevance: return "Relevance"
            case .price: return "Price"
            case .brand: return "Brand"
            case .newest: return "Newest"
            }
        }
    }

    var filteredAndSortedResults: [VisualSearchResult] {
        var filtered = results.filter { result in
            searchFilters.matches(result)
        }

        switch sortOption {
        case .relevance:
            filtered.sort { $0.confidence > $1.confidence }
        case .price:
            filtered.sort { $0.averagePrice < $1.averagePrice }
        case .brand:
            filtered.sort { $0.topBrand < $1.topBrand }
        case .newest:
            filtered.sort { $0.id > $1.id }
        }

        return filtered
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                SearchResultsHeaderView(
                    resultCount: filteredAndSortedResults.count,
                    sortOption: $sortOption,
                    onFilterTapped: { showingFilters = true }
                )

                TabSelectorView(selectedTab: $selectedTab)

                switch selectedTab {
                case .products:
                    ProductResultsView(
                        results: filteredAndSortedResults,
                        onProductSelected: { product in
                            selectedProduct = product
                            showingProductDetail = true
                        }
                    )
                case .similar:
                    SimilarResultsView(results: filteredAndSortedResults)
                case .history:
                    SearchHistoryView()
                }
            }
            .navigationTitle("Search Results")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    ShareButton(results: filteredAndSortedResults)
                }
            }
        }
        .sheet(isPresented: $showingProductDetail) {
            if let product = selectedProduct {
                ProductDetailView(product: product)
            }
        }
        .sheet(isPresented: $showingFilters) {
            SearchFiltersView(filters: $searchFilters)
        }
    }
}

struct SearchResultsHeaderView: View {
    let resultCount: Int
    @Binding var sortOption: VisualSearchResultsView.SortOption
    let onFilterTapped: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(resultCount) Results")
                    .font(.headline)
                    .foregroundColor(.primary)

                HStack(spacing: 4) {
                    Image(systemName: "shield.checkered")
                        .font(.caption)
                        .foregroundColor(.green)
                    Text("Privacy Protected")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            HStack(spacing: 12) {
                Menu {
                    ForEach(VisualSearchResultsView.SortOption.allCases, id: \.self) { option in
                        Button(option.title) {
                            sortOption = option
                        }
                    }
                } label: {
                    HStack {
                        Text("Sort")
                            .font(.subheadline)
                        Image(systemName: "chevron.down")
                            .font(.caption)
                    }
                    .foregroundColor(.primary)
                }

                Button(action: onFilterTapped) {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .font(.title3)
                        .foregroundColor(.primary)
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
    }
}

struct TabSelectorView: View {
    @Binding var selectedTab: VisualSearchResultsView.ResultsTab

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 20) {
                ForEach(VisualSearchResultsView.ResultsTab.allCases, id: \.self) { tab in
                    Button(action: { selectedTab = tab }) {
                        VStack(spacing: 6) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 16, weight: .medium))
                            Text(tab.title)
                                .font(.caption)
                        }
                        .foregroundColor(selectedTab == tab ? .primary : .secondary)
                        .padding(.vertical, 8)
                    }
                }
            }
            .padding(.horizontal)
        }
        .background(Color(.systemGray6))
    }
}

struct ProductResultsView: View {
    let results: [VisualSearchResult]
    let onProductSelected: (Product) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 2)

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(allProducts, id: \.id) { product in
                    ProductCardView(
                        product: product,
                        confidence: confidenceFor(product: product)
                    ) {
                        onProductSelected(product)
                    }
                }
            }
            .padding()
        }
    }

    private var allProducts: [Product] {
        results.flatMap { $0.products }
    }

    private func confidenceFor(product: Product) -> Double {
        results.first(where: { $0.products.contains(where: { $0.id == product.id }) })?.confidence ?? 0.0
    }
}

struct ProductCardView: View {
    let product: Product
    let confidence: Double
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                AsyncImage(url: product.imageURL) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .overlay(
                            ProgressView()
                                .scaleEffect(0.8)
                        )
                }
                .frame(height: 200)
                .clipped()
                .cornerRadius(12)
                .overlay(
                    ConfidenceBadgeView(confidence: confidence)
                        .padding(8),
                    alignment: .topTrailing
                )

                VStack(alignment: .leading, spacing: 4) {
                    Text(product.brand)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)

                    Text(product.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .lineLimit(2)

                    Text("$\(product.price, specifier: "%.2f")")
                        .font(.headline)
                        .foregroundColor(.primary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
    }
}

struct ConfidenceBadgeView: View {
    let confidence: Double

    var badgeColor: Color {
        if confidence > 0.8 { return .green }
        else if confidence > 0.6 { return .orange }
        else { return .red }
    }

    var body: some View {
        Text("\(Int(confidence * 100))%")
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(badgeColor)
            .cornerRadius(12)
    }
}

struct SimilarResultsView: View {
    let results: [VisualSearchResult]

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(results, id: \.id) { result in
                    SimilarResultCardView(result: result)
                }
            }
            .padding()
        }
    }
}

struct SimilarResultCardView: View {
    let result: VisualSearchResult

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Similar \(result.searchType.capitalized)")
                    .font(.headline)
                    .foregroundColor(.primary)

                Spacer()

                Text("\(Int(result.confidence * 100))% Match")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(.systemGray5))
                    .cornerRadius(8)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(result.products.prefix(5), id: \.id) { product in
                        MiniProductCardView(product: product)
                    }
                }
                .padding(.horizontal, 4)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

struct MiniProductCardView: View {
    let product: Product

    var body: some View {
        VStack(spacing: 6) {
            AsyncImage(url: product.imageURL) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(Color(.systemGray5))
            }
            .frame(width: 80, height: 80)
            .cornerRadius(8)

            Text(product.name)
                .font(.caption2)
                .lineLimit(1)
                .foregroundColor(.primary)

            Text("$\(product.price, specifier: "%.0f")")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
        }
        .frame(width: 90)
    }
}

struct SearchHistoryView: View {
    @State private var searchHistory: [VisualSearchHistoryItem] = []

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if searchHistory.isEmpty {
                    EmptyHistoryView()
                } else {
                    ForEach(searchHistory, id: \.id) { item in
                        HistoryItemView(item: item)
                    }
                }
            }
            .padding()
        }
        .onAppear {
            loadSearchHistory()
        }
    }

    private func loadSearchHistory() {
        // Load from local storage
    }
}

struct EmptyHistoryView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock")
                .font(.system(size: 50))
                .foregroundColor(.secondary)

            Text("No Search History")
                .font(.headline)
                .foregroundColor(.primary)

            Text("Your privacy-protected search history will appear here")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 100)
    }
}

struct HistoryItemView: View {
    let item: VisualSearchHistoryItem

    var body: some View {
        HStack(spacing: 12) {
            if let image = UIImage(data: item.imageData) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 60, height: 60)
                    .cornerRadius(8)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(item.searchType.capitalized)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)

                Text("\(item.results.count) results found")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(item.timestamp.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if item.privacyCompliant {
                Image(systemName: "shield.checkered")
                    .font(.caption)
                    .foregroundColor(.green)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct ShareButton: View {
    let results: [VisualSearchResult]

    var body: some View {
        Button(action: shareResults) {
            Image(systemName: "square.and.arrow.up")
                .font(.title3)
        }
    }

    private func shareResults() {
        let shareText = "Found \(results.reduce(0) { $0 + $1.products.count }) products through visual search!"

        let activityController = UIActivityViewController(
            activityItems: [shareText],
            applicationActivities: nil
        )

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController?.present(activityController, animated: true)
        }
    }
}

struct SearchFilters {
    var priceRange: ClosedRange<Double> = 0...1000
    var brands: Set<String> = []
    var categories: Set<String> = []
    var minConfidence: Double = 0.3

    func matches(_ result: VisualSearchResult) -> Bool {
        return result.confidence >= minConfidence
    }
}

struct SearchFiltersView: View {
    @Binding var filters: SearchFilters
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            Form {
                Section("Confidence") {
                    VStack {
                        HStack {
                            Text("Minimum: \(Int(filters.minConfidence * 100))%")
                            Spacer()
                        }
                        Slider(value: $filters.minConfidence, in: 0...1, step: 0.1)
                    }
                }

                Section("Price Range") {
                    VStack {
                        HStack {
                            Text("$\(Int(filters.priceRange.lowerBound))")
                            Spacer()
                            Text("$\(Int(filters.priceRange.upperBound))")
                        }
                        .font(.caption)
                    }
                }
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Reset") {
                        filters = SearchFilters()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

extension VisualSearchResult {
    var averagePrice: Double {
        products.isEmpty ? 0 : products.reduce(0) { $0 + $1.price } / Double(products.count)
    }

    var topBrand: String {
        products.first?.brand ?? ""
    }
}