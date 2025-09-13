import SwiftUI
import Combine
import Foundation

@MainActor
class ShoppingAssistantViewModel: ObservableObject {
    @Published var searchResults: [Product] = []
    @Published var recommendedProducts: [Product] = []
    @Published var comparisonProducts: [Product] = []
    @Published var isLoading = false
    @Published var searchText = ""
    @Published var selectedCategory: String?
    @Published var filters = ShoppingFilters()
    
    private var cancellables = Set<AnyCancellable>()
    private let shoppingService: ShoppingService
    
    let quickSearchCategories = [
        "Dresses", "Tops", "Bottoms", "Outerwear", "Shoes", 
        "Accessories", "Activewear", "Formal", "Casual", "Sustainable"
    ]
    
    init(shoppingService: ShoppingService = ShoppingService.shared) {
        self.shoppingService = shoppingService
        setupBindings()
    }
    
    private func setupBindings() {
        // Auto-search when text changes (with debounce)
        $searchText
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] searchText in
                if !searchText.isEmpty {
                    Task {
                        await self?.search(query: searchText)
                    }
                }
            }
            .store(in: &cancellables)
        
        // Update results when filters change
        $filters
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                if !self?.searchText.isEmpty ?? true {
                    Task {
                        await self?.search(query: self?.searchText ?? "")
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    func search(query: String) async {
        guard !query.isEmpty else { return }
        
        isLoading = true
        
        do {
            let results = try await shoppingService.searchProducts(
                query: query,
                filters: filters,
                stores: ["zalando", "asos", "nordstrom", "shein", "zara"]
            )
            
            await MainActor.run {
                self.searchResults = results
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.isLoading = false
                print("Search failed: \(error)")
            }
        }
    }
    
    func selectCategory(_ category: String) {
        if selectedCategory == category {
            selectedCategory = nil
            filters.category = nil
        } else {
            selectedCategory = category
            filters.category = category
        }
        
        Task {
            await search(query: searchText.isEmpty ? category : searchText)
        }
    }
    
    func loadRecommendations() {
        Task {
            do {
                let recommendations = try await shoppingService.getRecommendations(
                    userId: "current_user", // This would come from user session
                    limit: 10
                )
                
                await MainActor.run {
                    self.recommendedProducts = recommendations
                }
            } catch {
                print("Failed to load recommendations: \(error)")
            }
        }
    }
    
    func addToComparison(_ product: Product) {
        guard comparisonProducts.count < 4 else {
            // Show alert that maximum comparison limit reached
            return
        }
        
        if !comparisonProducts.contains(where: { $0.id == product.id }) {
            comparisonProducts.append(product)
            
            // Haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
        }
    }
    
    func removeFromComparison(_ product: Product) {
        comparisonProducts.removeAll { $0.id == product.id }
    }
    
    func clearComparison() {
        comparisonProducts.removeAll()
    }
    
    func trackPrice(for product: Product) {
        Task {
            do {
                try await shoppingService.createPriceAlert(
                    productId: product.id,
                    targetPrice: product.currentPrice * 0.9, // Alert when 10% cheaper
                    userId: "current_user"
                )
                
                // Show success notification
                NotificationCenter.default.post(
                    name: .priceAlertCreated,
                    object: product
                )
            } catch {
                print("Failed to create price alert: \(error)")
            }
        }
    }
    
    func findSimilar(to product: Product) {
        Task {
            do {
                isLoading = true
                
                let similarProducts = try await shoppingService.findSimilarProducts(
                    productId: product.id,
                    limit: 20
                )
                
                await MainActor.run {
                    self.searchResults = similarProducts
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    print("Failed to find similar products: \(error)")
                }
            }
        }
    }
    
    func startVisualSearch() {
        // This would trigger the camera/photo picker for visual search
        NotificationCenter.default.post(name: .startVisualSearch, object: nil)
    }
    
    func showPriceTracking() {
        // Navigate to price tracking view
        NotificationCenter.default.post(name: .showPriceTracking, object: nil)
    }
    
    func showSustainableOptions() {
        filters.sustainableOnly = true
        Task {
            await search(query: searchText.isEmpty ? "sustainable fashion" : searchText)
        }
    }
    
    func findStyleMatches() {
        // This would use the style matching algorithm
        Task {
            do {
                isLoading = true
                
                let styleMatches = try await shoppingService.getStyleMatches(
                    userId: "current_user",
                    limit: 20
                )
                
                await MainActor.run {
                    self.searchResults = styleMatches
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    print("Failed to get style matches: \(error)")
                }
            }
        }
    }
}

// Shopping filters model
struct ShoppingFilters {
    var category: String?
    var brands: [String] = []
    var priceRange: ClosedRange<Double> = 0...1000
    var colors: [String] = []
    var sizes: [String] = []
    var inStockOnly = true
    var onSaleOnly = false
    var sustainableOnly = false
    var stores: [String] = []
    
    var isActive: Bool {
        return category != nil || 
               !brands.isEmpty || 
               priceRange != 0...1000 ||
               !colors.isEmpty ||
               !sizes.isEmpty ||
               onSaleOnly ||
               sustainableOnly ||
               !stores.isEmpty
    }
}

// Shopping service interface
class ShoppingService {
    static let shared = ShoppingService()
    
    private let baseURL = "http://localhost:3000" // Your shopping service URL
    
    func searchProducts(
        query: String,
        filters: ShoppingFilters,
        stores: [String]
    ) async throws -> [Product] {
        // Implementation would call your shopping service API
        // For now, returning mock data
        return mockProducts
    }
    
    func getRecommendations(userId: String, limit: Int) async throws -> [Product] {
        // Implementation would call your recommendation service
        return mockProducts.prefix(limit).map { $0 }
    }
    
    func findSimilarProducts(productId: String, limit: Int) async throws -> [Product] {
        // Implementation would call your similarity matching service
        return mockProducts.prefix(limit).map { $0 }
    }
    
    func createPriceAlert(
        productId: String,
        targetPrice: Double,
        userId: String
    ) async throws {
        // Implementation would call your price tracking service
        print("Price alert created for product \(productId) at $\(targetPrice)")
    }
    
    func getStyleMatches(userId: String, limit: Int) async throws -> [Product] {
        // Implementation would call your style matching service
        return mockProducts.prefix(limit).map { $0 }
    }
}

// Mock data for preview/development
private let mockProducts: [Product] = [
    Product(
        id: "1",
        name: "Elegant Summer Dress",
        brand: "Zara",
        currentPrice: 79.99,
        originalPrice: 99.99,
        imageUrl: "https://via.placeholder.com/300x400/FF6B6B/FFFFFF?text=Dress",
        store: "Zara",
        inStock: true,
        colors: ["#FF6B6B", "#4ECDC4", "#45B7D1"],
        onSale: true,
        salePercentage: 20,
        sustainabilityScore: 8,
        rating: 4.5
    ),
    Product(
        id: "2",
        name: "Classic Denim Jacket",
        brand: "H&M",
        currentPrice: 59.99,
        originalPrice: nil,
        imageUrl: "https://via.placeholder.com/300x400/4ECDC4/FFFFFF?text=Jacket",
        store: "H&M",
        inStock: true,
        colors: ["#2C3E50", "#3498DB"],
        onSale: false,
        salePercentage: nil,
        sustainabilityScore: 6,
        rating: 4.2
    ),
    Product(
        id: "3",
        name: "Sustainable Sneakers",
        brand: "Adidas",
        currentPrice: 129.99,
        originalPrice: 149.99,
        imageUrl: "https://via.placeholder.com/300x400/45B7D1/FFFFFF?text=Sneakers",
        store: "Adidas",
        inStock: false,
        colors: ["#FFFFFF", "#2ECC71", "#E74C3C"],
        onSale: true,
        salePercentage: 15,
        sustainabilityScore: 9,
        rating: 4.8
    )
]

// Notification names
extension Notification.Name {
    static let priceAlertCreated = Notification.Name("priceAlertCreated")
    static let startVisualSearch = Notification.Name("startVisualSearch")
    static let showPriceTracking = Notification.Name("showPriceTracking")
}