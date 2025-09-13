import SwiftUI

struct ProductCard: View {
    let product: Product
    let style: CardStyle
    let onTap: () -> Void
    let onAddToComparison: () -> Void
    
    @EnvironmentObject private var themeManager: ThemeManager
    @State private var isLiked = false
    @State private var showPriceHistory = false
    
    enum CardStyle {
        case standard, compact, featured
    }
    
    init(
        product: Product,
        style: CardStyle = .standard,
        onTap: @escaping () -> Void,
        onAddToComparison: @escaping () -> Void
    ) {
        self.product = product
        self.style = style
        self.onTap = onTap
        self.onAddToComparison = onAddToComparison
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                imageSection
                contentSection
            }
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.1))
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(InteractiveCardButtonStyle())
        .contextMenu {
            contextMenuButtons
        }
        .sheet(isPresented: $showPriceHistory) {
            PriceHistoryView(product: product)
        }
    }
    
    private var imageSection: some View {
        ZStack(alignment: .topTrailing) {
            AsyncImage(url: URL(string: product.imageUrl)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.2))
                    .overlay(
                        Image(systemName: "photo")
                            .font(.title)
                            .foregroundColor(.gray)
                    )
            }
            .frame(height: cardHeight)
            .clipped()
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
            
            VStack {
                HStack {
                    Spacer()
                    
                    actionButtons
                }
                .padding(12)
                
                Spacer()
                
                if product.onSale {
                    HStack {
                        salesBadge
                        Spacer()
                    }
                    .padding(12)
                }
            }
        }
    }
    
    private var actionButtons: some View {
        HStack(spacing: 8) {
            Button(action: { isLiked.toggle() }) {
                Image(systemName: isLiked ? "heart.fill" : "heart")
                    .font(.caption)
                    .foregroundColor(isLiked ? .red : .white)
                    .frame(width: 30, height: 30)
                    .background(Color.black.opacity(0.4))
                    .clipShape(Circle())
                    .backdrop(BlurView(style: .systemThinMaterial))
            }
            .tapWithHaptic(.light)
            
            Button(action: onAddToComparison) {
                Image(systemName: "rectangle.stack.badge.plus")
                    .font(.caption)
                    .foregroundColor(.white)
                    .frame(width: 30, height: 30)
                    .background(Color.black.opacity(0.4))
                    .clipShape(Circle())
                    .backdrop(BlurView(style: .systemThinMaterial))
            }
            .tapWithHaptic(.light)
        }
    }
    
    private var salesBadge: some View {
        Text("\(product.salePercentage ?? 0)% OFF")
            .typography(.caption2, theme: .minimal)
            .fontWeight(.bold)
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.red)
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    private var contentSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                Text(product.brand)
                    .typography(.caption1, theme: .minimal)
                    .foregroundColor(themeManager.currentTheme.colors.secondary)
                    .lineLimit(1)
                
                Text(product.name)
                    .typography(textStyle, theme: .modern)
                    .foregroundColor(themeManager.currentTheme.colors.primary)
                    .fontWeight(.medium)
                    .lineLimit(style == .compact ? 1 : 2)
            }
            
            HStack {
                priceSection
                Spacer()
                storeInfo
            }
            
            if style == .featured {
                featuredExtras
            }
        }
        .padding(12)
    }
    
    private var priceSection: some View {
        HStack(spacing: 4) {
            Text("$\(product.currentPrice, specifier: "%.2f")")
                .typography(.body1, theme: .modern)
                .foregroundColor(themeManager.currentTheme.colors.primary)
                .fontWeight(.semibold)
            
            if let originalPrice = product.originalPrice, originalPrice > product.currentPrice {
                Text("$\(originalPrice, specifier: "%.2f")")
                    .typography(.caption2, theme: .minimal)
                    .foregroundColor(themeManager.currentTheme.colors.secondary)
                    .strikethrough()
            }
        }
    }
    
    private var storeInfo: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(product.store)
                .typography(.caption2, theme: .minimal)
                .foregroundColor(themeManager.currentTheme.colors.secondary)
            
            if product.inStock {
                Text("In Stock")
                    .typography(.caption2, theme: .minimal)
                    .foregroundColor(.green)
            } else {
                Text("Out of Stock")
                    .typography(.caption2, theme: .minimal)
                    .foregroundColor(.red)
            }
        }
    }
    
    private var featuredExtras: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                ForEach(product.colors.prefix(4), id: \.self) { color in
                    Circle()
                        .fill(Color(hex: color) ?? Color.gray)
                        .frame(width: 16, height: 16)
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                        )
                }
                
                if product.colors.count > 4 {
                    Text("+\(product.colors.count - 4)")
                        .typography(.caption2, theme: .minimal)
                        .foregroundColor(themeManager.currentTheme.colors.secondary)
                }
                
                Spacer()
            }
            
            HStack {
                if product.sustainabilityScore > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "leaf.fill")
                            .font(.caption2)
                            .foregroundColor(.green)
                        
                        Text("Eco-Friendly")
                            .typography(.caption2, theme: .minimal)
                            .foregroundColor(.green)
                    }
                }
                
                Spacer()
                
                if product.rating > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundColor(.yellow)
                        
                        Text("\(product.rating, specifier: "%.1f")")
                            .typography(.caption2, theme: .minimal)
                            .foregroundColor(themeManager.currentTheme.colors.secondary)
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private var contextMenuButtons: some View {
        Button("View Details") {
            onTap()
        }
        
        Button("Add to Comparison") {
            onAddToComparison()
        }
        
        Button("Price History") {
            showPriceHistory = true
        }
        
        Button("Find Similar") {
            // Implementation for finding similar products
        }
        
        if !isLiked {
            Button("Add to Wishlist") {
                isLiked = true
            }
        } else {
            Button("Remove from Wishlist") {
                isLiked = false
            }
        }
    }
    
    private var cardHeight: CGFloat {
        switch style {
        case .standard: return 200
        case .compact: return 150
        case .featured: return 250
        }
    }
    
    private var textStyle: TypographyStyle {
        switch style {
        case .standard, .featured: return .body2
        case .compact: return .caption1
        }
    }
}

struct InteractiveCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// Supporting model
struct Product: Identifiable, Codable {
    let id: String
    let name: String
    let brand: String
    let currentPrice: Double
    let originalPrice: Double?
    let imageUrl: String
    let store: String
    let inStock: Bool
    let colors: [String]
    let onSale: Bool
    let salePercentage: Int?
    let sustainabilityScore: Int
    let rating: Double
    
    var priceDisplay: String {
        if let original = originalPrice, original > currentPrice {
            return "$\(currentPrice, specifier: "%.2f") (was $\(original, specifier: "%.2f"))"
        } else {
            return "$\(currentPrice, specifier: "%.2f")"
        }
    }
}

// Color extension for hex support
extension Color {
    init?(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            return nil
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

#Preview {
    ScrollView {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
            ForEach(0..<6, id: \.self) { index in
                ProductCard(
                    product: Product(
                        id: "sample_\(index)",
                        name: "Elegant Summer Dress with Floral Pattern",
                        brand: "Zara",
                        currentPrice: 79.99,
                        originalPrice: index % 2 == 0 ? 99.99 : nil,
                        imageUrl: "https://example.com/image.jpg",
                        store: "Zara",
                        inStock: true,
                        colors: ["#FF0000", "#00FF00", "#0000FF", "#FFFF00"],
                        onSale: index % 2 == 0,
                        salePercentage: index % 2 == 0 ? 20 : nil,
                        sustainabilityScore: index % 3 == 0 ? 8 : 0,
                        rating: 4.5
                    ),
                    style: index == 0 ? .featured : .standard
                ) {
                    // onTap action
                } onAddToComparison: {
                    // onAddToComparison action
                }
            }
        }
        .padding()
    }
    .background(Color.black)
    .environmentObject(ThemeManager())
}