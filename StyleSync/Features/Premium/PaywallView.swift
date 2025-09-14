import SwiftUI
import StoreKit

struct PaywallView: View {
    @StateObject private var premiumManager = PremiumManager()
    @Environment(\.dismiss) private var dismiss
    @State private var selectedProduct: Product?
    @State private var showingPurchaseSuccess = false
    @State private var animateFeatures = false
    @State private var pulseAnimation = false

    let presentingFeature: PremiumFeature?

    init(feature: PremiumFeature? = nil) {
        self.presentingFeature = feature
    }

    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(.systemBackground),
                        Color(.systemBackground).opacity(0.95)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Header Section
                        headerSection

                        // Feature Comparison
                        featureComparisonSection

                        // Pricing Cards
                        pricingSection

                        // Success Stories
                        successStoriesSection

                        // Purchase Button
                        purchaseSection

                        // Restore and Terms
                        footerSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Close") {
                    dismiss()
                }
                .foregroundColor(.secondary)
            }
        }
        .task {
            await premiumManager.loadProducts()
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.2)) {
                animateFeatures = true
            }
        }
        .alert("Purchase Successful!", isPresented: $showingPurchaseSuccess) {
            Button("Continue") {
                dismiss()
            }
        } message: {
            Text("Welcome to StyleSync Premium! Enjoy unlimited access to all features.")
        }
    }

    private var headerSection: some View {
        VStack(spacing: 16) {
            // Premium Icon
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        gradient: Gradient(colors: [.purple, .pink]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 80, height: 80)
                    .scaleEffect(pulseAnimation ? 1.1 : 1.0)
                    .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: pulseAnimation)

                Image(systemName: "crown.fill")
                    .font(.system(size: 40, weight: .medium))
                    .foregroundColor(.white)
            }
            .onAppear {
                pulseAnimation = true
            }

            Text("StyleSync Premium")
                .font(.largeTitle)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)

            Text("Unlock your style potential with AI-powered fashion insights")
                .font(.title3)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            // Free Trial Badge
            if !premiumManager.availableProducts.isEmpty {
                HStack {
                    Image(systemName: "gift.fill")
                    Text("7-Day Free Trial")
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(LinearGradient(
                            gradient: Gradient(colors: [.green, .blue]),
                            startPoint: .leading,
                            endPoint: .trailing
                        ))
                )
            }
        }
        .opacity(animateFeatures ? 1 : 0)
        .offset(y: animateFeatures ? 0 : 20)
    }

    private var featureComparisonSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Compare Plans")
                .font(.title2)
                .fontWeight(.bold)

            VStack(spacing: 0) {
                // Header Row
                HStack {
                    Text("Features")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text("Free")
                        .font(.headline)
                        .frame(width: 60)

                    Text("Premium")
                        .font(.headline)
                        .foregroundColor(.purple)
                        .frame(width: 80)
                }
                .padding(.vertical, 16)
                .background(Color(.secondarySystemBackground))

                // Feature Rows
                ForEach(FeatureRow.allCases, id: \.self) { feature in
                    featureRow(feature)

                    if feature != FeatureRow.allCases.last {
                        Divider()
                    }
                }
            }
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        }
        .opacity(animateFeatures ? 1 : 0)
        .offset(y: animateFeatures ? 0 : 30)
        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.4), value: animateFeatures)
    }

    private func featureRow(_ feature: FeatureRow) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(feature.title)
                    .font(.subheadline)
                    .fontWeight(.medium)

                if let subtitle = feature.subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Free tier
            Group {
                if let freeValue = feature.freeValue {
                    if freeValue.contains("✓") {
                        Image(systemName: "checkmark")
                            .foregroundColor(.green)
                    } else {
                        Text(freeValue)
                            .font(.caption)
                    }
                } else {
                    Image(systemName: "xmark")
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 60)

            // Premium tier
            Group {
                if feature.premiumValue.contains("✓") || feature.premiumValue.contains("Unlimited") {
                    Image(systemName: "checkmark")
                        .foregroundColor(.purple)
                } else {
                    Text(feature.premiumValue)
                        .font(.caption)
                        .foregroundColor(.purple)
                }
            }
            .frame(width: 80)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
    }

    private var pricingSection: some View {
        VStack(spacing: 16) {
            Text("Choose Your Plan")
                .font(.title2)
                .fontWeight(.bold)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                ForEach(premiumManager.availableProducts, id: \.id) { product in
                    PricingCard(
                        product: product,
                        isSelected: selectedProduct?.id == product.id,
                        monthlyEquivalent: premiumManager.getMonthlyEquivalentPrice(for: product)
                    ) {
                        selectedProduct = product
                    }
                }
            }
        }
        .opacity(animateFeatures ? 1 : 0)
        .offset(y: animateFeatures ? 0 : 40)
        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.6), value: animateFeatures)
    }

    private var successStoriesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Success Stories")
                .font(.title2)
                .fontWeight(.bold)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(SuccessStory.examples, id: \.name) { story in
                        SuccessStoryCard(story: story)
                    }
                }
                .padding(.horizontal, 20)
            }
            .padding(.horizontal, -20)
        }
        .opacity(animateFeatures ? 1 : 0)
        .offset(y: animateFeatures ? 0 : 50)
        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.8), value: animateFeatures)
    }

    private var purchaseSection: some View {
        VStack(spacing: 12) {
            Button(action: handlePurchase) {
                HStack {
                    if premiumManager.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    } else {
                        Text("Start Free Trial")
                            .fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [.purple, .pink]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .disabled(premiumManager.isLoading || selectedProduct == nil)
            .opacity(premiumManager.isLoading || selectedProduct == nil ? 0.6 : 1.0)

            if let error = premiumManager.purchaseError {
                Text(error.localizedDescription)
                    .font(.caption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
            }
        }
        .opacity(animateFeatures ? 1 : 0)
        .offset(y: animateFeatures ? 0 : 20)
        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(1.0), value: animateFeatures)
    }

    private var footerSection: some View {
        VStack(spacing: 12) {
            Button("Restore Purchases") {
                Task {
                    try? await premiumManager.restorePurchases()
                }
            }
            .foregroundColor(.secondary)

            HStack {
                Link("Terms of Service", destination: URL(string: "https://yourdomain.com/terms")!)
                Text("•")
                Link("Privacy Policy", destination: URL(string: "https://yourdomain.com/privacy")!)
            }
            .font(.caption)
            .foregroundColor(.secondary)

            Text("Subscription automatically renews unless auto-renew is turned off at least 24 hours before the end of the current period.")
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.top, 8)
        }
        .opacity(animateFeatures ? 1 : 0)
        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(1.2), value: animateFeatures)
    }

    private func handlePurchase() {
        guard let product = selectedProduct else { return }

        Task {
            do {
                let transaction = try await premiumManager.purchase(product)
                if transaction != nil {
                    showingPurchaseSuccess = true
                }
            } catch {
                // Error handling is managed by PremiumManager
            }
        }
    }
}

// MARK: - Supporting Views
struct PricingCard: View {
    let product: Product
    let isSelected: Bool
    let monthlyEquivalent: String?
    let onSelect: () -> Void

    private var isYearly: Bool {
        product.subscription?.subscriptionPeriod.unit == .year
    }

    private var savingsText: String? {
        guard isYearly else { return nil }
        return "Save 40%"
    }

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(isYearly ? "Yearly" : "Monthly")
                        .font(.headline)
                        .fontWeight(.bold)

                    Spacer()

                    if let savings = savingsText {
                        Text(savings)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.green)
                            .clipShape(Capsule())
                    }
                }

                Text(product.displayPrice)
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)

                if let monthly = monthlyEquivalent, isYearly {
                    Text("\(monthly) per month")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Text(isYearly ? "Billed annually" : "Billed monthly")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(Color(.systemBackground))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        isSelected ? Color.purple : Color(.systemGray4),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct SuccessStoryCard: View {
    let story: SuccessStory

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                AsyncImage(url: URL(string: story.imageURL)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle()
                        .fill(Color(.systemGray5))
                }
                .frame(width: 50, height: 50)
                .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(story.name)
                        .font(.headline)
                        .fontWeight(.medium)

                    HStack(spacing: 2) {
                        ForEach(0..<5) { i in
                            Image(systemName: i < story.rating ? "star.fill" : "star")
                                .font(.caption)
                                .foregroundColor(.yellow)
                        }
                    }
                }

                Spacer()
            }

            Text(story.quote)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.leading)
        }
        .frame(width: 280)
        .padding(16)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Supporting Types
enum FeatureRow: CaseIterable {
    case items, outfitSuggestions, selfieRatings, colorMatching, weather, aiStylist, geniusMode, analytics, shopping, exports, cloudSync

    var title: String {
        switch self {
        case .items: return "Wardrobe Items"
        case .outfitSuggestions: return "Daily Outfit Suggestions"
        case .selfieRatings: return "AI Selfie Ratings"
        case .colorMatching: return "Color Matching"
        case .weather: return "Weather Integration"
        case .aiStylist: return "AI Stylist Chat"
        case .geniusMode: return "Outfit Genius Mode"
        case .analytics: return "Style Analytics"
        case .shopping: return "Shopping Companion"
        case .exports: return "Magazine Exports"
        case .cloudSync: return "Cloud Sync & Family Sharing"
        }
    }

    var subtitle: String? {
        switch self {
        case .items: return "Add clothes to your digital wardrobe"
        case .outfitSuggestions: return "AI-generated outfit recommendations"
        case .selfieRatings: return "Rate your style with AI feedback"
        default: return nil
        }
    }

    var freeValue: String? {
        switch self {
        case .items: return "50 items"
        case .outfitSuggestions: return "5 per day"
        case .selfieRatings: return "1 per week"
        case .colorMatching, .weather: return "✓"
        default: return nil
        }
    }

    var premiumValue: String {
        switch self {
        case .items, .outfitSuggestions, .selfieRatings: return "Unlimited"
        default: return "✓"
        }
    }
}

struct SuccessStory {
    let name: String
    let imageURL: String
    let quote: String
    let rating: Int

    static let examples = [
        SuccessStory(
            name: "Sarah M.",
            imageURL: "https://images.unsplash.com/photo-1494790108755-2616b612b5e5?w=100&h=100&fit=crop&crop=face",
            quote: "StyleSync completely transformed my morning routine. I save 20 minutes every day!",
            rating: 5
        ),
        SuccessStory(
            name: "Emma L.",
            imageURL: "https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=100&h=100&fit=crop&crop=face",
            quote: "The AI stylist gives me confidence to try new combinations I never would have thought of.",
            rating: 5
        ),
        SuccessStory(
            name: "Jessica K.",
            imageURL: "https://images.unsplash.com/photo-1544725176-7c40e5a71c5e?w=100&h=100&fit=crop&crop=face",
            quote: "Shopping is so much easier now. The AI knows exactly what works with my existing wardrobe.",
            rating: 5
        )
    ]
}

#Preview {
    PaywallView()
}