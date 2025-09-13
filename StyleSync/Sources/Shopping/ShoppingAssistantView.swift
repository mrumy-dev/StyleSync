import SwiftUI
import Combine

struct ShoppingAssistantView: View {
    @StateObject private var viewModel = ShoppingAssistantViewModel()
    @EnvironmentObject private var themeManager: ThemeManager
    @State private var searchText = ""
    @State private var showFilters = false
    @State private var selectedProduct: Product?
    @State private var showComparison = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background with gradient mesh
                GradientMeshBackground(colors: themeManager.currentTheme.gradients.mesh)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        headerSection
                        searchSection
                        featuresSection
                        
                        if viewModel.isLoading {
                            loadingSection
                        } else if !viewModel.searchResults.isEmpty {
                            searchResultsSection
                        } else if !viewModel.recommendedProducts.isEmpty {
                            recommendationsSection
                        }
                    }
                    .padding()
                }
            }
        }
        .sheet(item: $selectedProduct) { product in
            ProductDetailView(product: product)
        }
        .sheet(isPresented: $showComparison) {
            ProductComparisonView(products: viewModel.comparisonProducts)
        }
        .sheet(isPresented: $showFilters) {
            ShoppingFiltersView(filters: $viewModel.filters)
        }
        .onAppear {
            viewModel.loadRecommendations()
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Shopping Assistant")
                    .typography(.display1, theme: .elegant)
                    .foregroundColor(themeManager.currentTheme.colors.primary)
                
                Spacer()
                
                Button(action: { showComparison = true }) {
                    Image(systemName: "rectangle.stack.badge.plus")
                        .font(.title2)
                        .foregroundColor(themeManager.currentTheme.colors.accent)
                }
                .opacity(viewModel.comparisonProducts.isEmpty ? 0.5 : 1.0)
                .disabled(viewModel.comparisonProducts.isEmpty)
            }
            
            Text("Find the perfect style match with AI-powered visual search")
                .typography(.body2, theme: .minimal)
                .foregroundColor(themeManager.currentTheme.colors.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    private var searchSection: some View {
        VStack(spacing: 16) {
            HStack {
                TextField("Search for fashion items...", text: $searchText)
                    .textFieldStyle(GlassmorphicTextFieldStyle())
                    .onSubmit {
                        viewModel.search(query: searchText)
                    }
                
                Button(action: { showFilters = true }) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.title3)
                        .foregroundColor(themeManager.currentTheme.colors.accent)
                }
                .glassmorphism(intensity: .medium)
                .padding(12)
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(viewModel.quickSearchCategories, id: \.self) { category in
                        QuickSearchChip(
                            title: category,
                            isSelected: viewModel.selectedCategory == category
                        ) {
                            viewModel.selectCategory(category)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    
    private var featuresSection: some View {
        VStack(spacing: 16) {
            Text("Smart Features")
                .typography(.heading3, theme: .modern)
                .foregroundColor(themeManager.currentTheme.colors.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                FeatureCard(
                    icon: "camera.fill",
                    title: "Visual Search",
                    description: "Upload an image to find similar items",
                    color: .blue
                ) {
                    viewModel.startVisualSearch()
                }
                
                FeatureCard(
                    icon: "chart.line.uptrend.xyaxis",
                    title: "Price Tracking",
                    description: "Track prices and get alerts",
                    color: .green
                ) {
                    viewModel.showPriceTracking()
                }
                
                FeatureCard(
                    icon: "leaf.fill",
                    title: "Sustainable Options",
                    description: "Find eco-friendly alternatives",
                    color: .mint
                ) {
                    viewModel.showSustainableOptions()
                }
                
                FeatureCard(
                    icon: "sparkles",
                    title: "Style Match",
                    description: "AI-powered style recommendations",
                    color: .purple
                ) {
                    viewModel.findStyleMatches()
                }
            }
        }
    }
    
    private var loadingSection: some View {
        VStack(spacing: 20) {
            ShimmerLoadingView(style: .card)
                .frame(height: 200)
            
            HStack(spacing: 12) {
                ForEach(0..<3, id: \.self) { _ in
                    ShimmerLoadingView(style: .card)
                        .aspectRatio(0.75, contentMode: .fit)
                }
            }
        }
        .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: viewModel.isLoading)
    }
    
    private var searchResultsSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Search Results")
                    .typography(.heading3, theme: .modern)
                    .foregroundColor(themeManager.currentTheme.colors.primary)
                
                Spacer()
                
                Text("\(viewModel.searchResults.count) items")
                    .typography(.caption1, theme: .minimal)
                    .foregroundColor(themeManager.currentTheme.colors.secondary)
            }
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                ForEach(viewModel.searchResults) { product in
                    ProductCard(product: product) {
                        selectedProduct = product
                    } onAddToComparison: {
                        viewModel.addToComparison(product)
                    }
                    .contextMenu {
                        Button("Add to Comparison") {
                            viewModel.addToComparison(product)
                        }
                        
                        Button("Track Price") {
                            viewModel.trackPrice(for: product)
                        }
                        
                        Button("Find Similar") {
                            viewModel.findSimilar(to: product)
                        }
                    }
                }
            }
        }
    }
    
    private var recommendationsSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Recommended for You")
                    .typography(.heading3, theme: .modern)
                    .foregroundColor(themeManager.currentTheme.colors.primary)
                
                Spacer()
                
                Button("Refresh") {
                    viewModel.loadRecommendations()
                }
                .typography(.caption1, theme: .minimal)
                .foregroundColor(themeManager.currentTheme.colors.accent)
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(viewModel.recommendedProducts) { product in
                        ProductCard(product: product, style: .compact) {
                            selectedProduct = product
                        } onAddToComparison: {
                            viewModel.addToComparison(product)
                        }
                        .frame(width: 200)
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

struct FeatureCard: View {
    let icon: String
    let title: String
    let description: String
    let color: Color
    let action: () -> Void
    
    @EnvironmentObject private var themeManager: ThemeManager
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title)
                    .foregroundColor(color)
                    .frame(width: 50, height: 50)
                    .background(color.opacity(0.1))
                    .clipShape(Circle())
                
                VStack(spacing: 4) {
                    Text(title)
                        .typography(.body1, theme: .modern)
                        .foregroundColor(themeManager.currentTheme.colors.primary)
                        .fontWeight(.semibold)
                    
                    Text(description)
                        .typography(.caption2, theme: .minimal)
                        .foregroundColor(themeManager.currentTheme.colors.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, minHeight: 120)
            .glassmorphism(intensity: .medium)
            .scaleEffect(1.0)
        }
        .buttonStyle(InteractiveScaleButtonStyle())
        .tapWithHaptic(.medium)
    }
}

struct QuickSearchChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    @EnvironmentObject private var themeManager: ThemeManager
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .typography(.caption1, theme: .minimal)
                .foregroundColor(isSelected ? .white : themeManager.currentTheme.colors.primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    isSelected ? 
                    themeManager.currentTheme.colors.accent :
                    Color.clear
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(themeManager.currentTheme.colors.accent, lineWidth: 1)
                        .opacity(isSelected ? 0 : 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 20))
        }
        .tapWithHaptic(.light)
        .animation(.spring(response: 0.3), value: isSelected)
    }
}

struct GlassmorphicTextFieldStyle: TextFieldStyle {
    @EnvironmentObject private var themeManager: ThemeManager
    
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.1))
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
                    .backdrop(BlurView(style: .systemThinMaterial))
            )
            .foregroundColor(themeManager.currentTheme.colors.primary)
    }
}

#Preview {
    ShoppingAssistantView()
        .environmentObject(ThemeManager())
}