import SwiftUI
import SwiftData

// MARK: - Example of Premium Integration in Main App
struct PremiumIntegratedContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var styleItems: [StyleItem]
    @State private var appState = AppState()

    // Premium system integration
    @StateObject private var premiumManager = PremiumManager()
    @StateObject private var usageTracker: UsageTracker
    @State private var showingPaywall = false
    @State private var showingPremiumOnboarding = false
    @State private var paywallFeature: PremiumFeature?

    init() {
        let manager = PremiumManager()
        _usageTracker = StateObject(wrappedValue: UsageTracker(premiumManager: manager))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Premium status bar for free users
                PremiumStatusBar(
                    premiumManager: premiumManager,
                    usageTracker: usageTracker
                )

                VStack(spacing: 24) {
                    PremiumAwareHeaderView(
                        premiumManager: premiumManager,
                        onPremiumAction: { feature in
                            paywallFeature = feature
                            showingPaywall = true
                        }
                    )

                    if styleItems.isEmpty {
                        PremiumAwareEmptyStateView(
                            premiumManager: premiumManager,
                            onGetStarted: {
                                if premiumManager.canAddItem() {
                                    // Add item logic
                                } else {
                                    paywallFeature = .unlimitedItems
                                    showingPaywall = true
                                }
                            }
                        )
                    } else {
                        PremiumAwareStyleGridView(
                            items: styleItems,
                            premiumManager: premiumManager,
                            onPremiumRequired: { feature in
                                paywallFeature = feature
                                showingPaywall = true
                            }
                        )
                    }

                    Spacer()
                }
                .padding()
                .background(DesignSystem.Colors.background)
            }
        }
        .environment(appState)
        .sheet(isPresented: $showingPaywall) {
            PaywallView(feature: paywallFeature)
        }
        .sheet(isPresented: $showingPremiumOnboarding) {
            PremiumOnboardingView()
        }
        .onAppear {
            // Show onboarding for new users
            if !UserDefaults.standard.bool(forKey: "hasSeenPremiumOnboarding") {
                showingPremiumOnboarding = true
                UserDefaults.standard.set(true, forKey: "hasSeenPremiumOnboarding")
            }
        }
    }
}

// MARK: - Premium-Aware Header
struct PremiumAwareHeaderView: View {
    @ObservedObject var premiumManager: PremiumManager
    let onPremiumAction: (PremiumFeature) -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("StyleSync")
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(DesignSystem.Colors.primary)

                    if premiumManager.isPremium {
                        premiumBadge
                    }
                }

                Text(premiumManager.isPremium ? "Premium Member" : "Curate your style")
                    .font(.subheadline)
                    .foregroundStyle(DesignSystem.Colors.secondary)
            }

            Spacer()

            HStack(spacing: 12) {
                // AI Stylist Chat - Premium Feature
                Button(action: {
                    if premiumManager.hasFeatureAccess(.aiStylistChat) {
                        // Navigate to AI Stylist
                    } else {
                        onPremiumAction(.aiStylistChat)
                    }
                }) {
                    Image(systemName: "message.circle.fill")
                        .font(.title2)
                        .foregroundStyle(premiumManager.hasFeatureAccess(.aiStylistChat) ?
                                       DesignSystem.Colors.accent : DesignSystem.Colors.secondary)
                }
                .premiumBadge(feature: .aiStylistChat, premiumManager: premiumManager)

                // Add Item Button
                Button(action: {
                    if premiumManager.canAddItem() {
                        // Add item logic
                        premiumManager.incrementItemCount()
                    } else {
                        onPremiumAction(.unlimitedItems)
                    }
                }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(premiumManager.canAddItem() ?
                                       DesignSystem.Colors.accent : DesignSystem.Colors.secondary)
                }
                .premiumBadge(feature: .unlimitedItems, premiumManager: premiumManager)
            }
        }
    }

    private var premiumBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "crown.fill")
                .font(.caption2)
            Text("PRO")
                .font(.caption2)
                .fontWeight(.bold)
        }
        .foregroundColor(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [.purple, .pink]),
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .clipShape(Capsule())
    }
}

// MARK: - Premium-Aware Empty State
struct PremiumAwareEmptyStateView: View {
    @ObservedObject var premiumManager: PremiumManager
    let onGetStarted: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "sparkles")
                .font(.system(size: 60))
                .foregroundStyle(DesignSystem.Colors.accent.gradient)

            VStack(spacing: 12) {
                Text("Start Your Style Journey")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(DesignSystem.Colors.primary)

                if premiumManager.isPremium {
                    Text("Add unlimited items and get AI-powered style recommendations")
                        .font(.body)
                        .foregroundStyle(DesignSystem.Colors.secondary)
                        .multilineTextAlignment(.center)
                } else {
                    VStack(spacing: 8) {
                        Text("Add up to 50 items and get 5 daily outfit suggestions")
                            .font(.body)
                            .foregroundStyle(DesignSystem.Colors.secondary)
                            .multilineTextAlignment(.center)

                        Text("Upgrade to Premium for unlimited everything")
                            .font(.caption)
                            .foregroundStyle(.purple)
                            .fontWeight(.medium)
                    }
                }
            }
            .padding(.horizontal)

            Button(action: onGetStarted) {
                HStack {
                    Image(systemName: "plus")
                    Text("Add Your First Item")
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(DesignSystem.Colors.accent)
                .clipShape(Capsule())
            }

            if !premiumManager.isPremium {
                usageLimitsView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DesignSystem.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var usageLimitsView: some View {
        VStack(spacing: 12) {
            Text("Free Tier Limits")
                .font(.headline)
                .foregroundStyle(DesignSystem.Colors.primary)

            HStack(spacing: 20) {
                limitIndicator(
                    icon: "tshirt.fill",
                    title: "Items",
                    current: premiumManager.currentItemCount,
                    limit: PremiumManager.FreeTierLimits.maxItems
                )

                limitIndicator(
                    icon: "sparkles",
                    title: "Outfits",
                    current: premiumManager.dailyOutfitSuggestionsUsed,
                    limit: PremiumManager.FreeTierLimits.dailyOutfitSuggestions
                )

                limitIndicator(
                    icon: "camera.fill",
                    title: "Ratings",
                    current: premiumManager.weeklySelfieeRatingsUsed,
                    limit: PremiumManager.FreeTierLimits.weeklySelfieeRatings
                )
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func limitIndicator(icon: String, title: String, current: Int, limit: Int) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(current >= limit ? .red : DesignSystem.Colors.accent)

            Text(title)
                .font(.caption)
                .foregroundStyle(DesignSystem.Colors.secondary)

            Text("\(current)/\(limit)")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(current >= limit ? .red : DesignSystem.Colors.primary)

            ProgressView(value: Double(current), total: Double(limit))
                .progressViewStyle(LinearProgressViewStyle())
                .frame(width: 40, height: 4)
        }
    }
}

// MARK: - Premium-Aware Style Grid
struct PremiumAwareStyleGridView: View {
    let items: [StyleItem]
    @ObservedObject var premiumManager: PremiumManager
    let onPremiumRequired: (PremiumFeature) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Quick Actions Row
            quickActionsRow

            // Style Grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                ForEach(items) { item in
                    PremiumAwareStyleItemCard(
                        item: item,
                        premiumManager: premiumManager,
                        onPremiumRequired: onPremiumRequired
                    )
                }
            }
        }
    }

    private var quickActionsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                quickActionButton(
                    icon: "sparkles",
                    title: "Outfit Suggestions",
                    subtitle: premiumManager.isPremium ? "Unlimited" :
                             "\(PremiumManager.FreeTierLimits.dailyOutfitSuggestions - premiumManager.dailyOutfitSuggestionsUsed) left",
                    feature: .unlimitedItems,
                    action: {
                        if premiumManager.canGenerateOutfitSuggestion() {
                            premiumManager.incrementOutfitSuggestion()
                            // Generate outfit
                        } else {
                            onPremiumRequired(.unlimitedItems)
                        }
                    }
                )

                quickActionButton(
                    icon: "brain.head.profile",
                    title: "Outfit Genius",
                    subtitle: "AI Mode",
                    feature: .outfitGeniusMode,
                    action: {
                        if premiumManager.hasFeatureAccess(.outfitGeniusMode) {
                            // Navigate to Genius mode
                        } else {
                            onPremiumRequired(.outfitGeniusMode)
                        }
                    }
                )

                quickActionButton(
                    icon: "camera.fill",
                    title: "Selfie Rating",
                    subtitle: premiumManager.isPremium ? "Unlimited" :
                             "\(PremiumManager.FreeTierLimits.weeklySelfieeRatings - premiumManager.weeklySelfieeRatingsUsed) left",
                    feature: .unlimitedSelfieRatings,
                    action: {
                        if premiumManager.canRateSelfie() {
                            premiumManager.incrementSelfieeRating()
                            // Navigate to selfie rating
                        } else {
                            onPremiumRequired(.unlimitedSelfieRatings)
                        }
                    }
                )

                quickActionButton(
                    icon: "bag.fill",
                    title: "Shopping",
                    subtitle: "AI Assistant",
                    feature: .shoppingCompanion,
                    action: {
                        if premiumManager.hasFeatureAccess(.shoppingCompanion) {
                            // Navigate to shopping
                        } else {
                            onPremiumRequired(.shoppingCompanion)
                        }
                    }
                )
            }
            .padding(.horizontal, 20)
        }
        .padding(.horizontal, -20)
    }

    private func quickActionButton(
        icon: String,
        title: String,
        subtitle: String,
        feature: PremiumFeature,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(premiumManager.hasFeatureAccess(feature) ?
                                   DesignSystem.Colors.accent : DesignSystem.Colors.secondary)

                VStack(spacing: 2) {
                    Text(title)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(DesignSystem.Colors.primary)

                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(DesignSystem.Colors.secondary)
                }
            }
            .frame(width: 100, height: 80)
            .background(DesignSystem.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: DesignSystem.Colors.shadow.opacity(0.3), radius: 4, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
        .premiumBadge(feature: feature, premiumManager: premiumManager)
    }
}

// MARK: - Premium-Aware Style Item Card
struct PremiumAwareStyleItemCard: View {
    let item: StyleItem
    @ObservedObject var premiumManager: PremiumManager
    let onPremiumRequired: (PremiumFeature) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            RoundedRectangle(cornerRadius: 12)
                .fill(DesignSystem.Colors.accent.opacity(0.3))
                .aspectRatio(4/3, contentMode: .fit)
                .overlay(
                    Image(systemName: "photo")
                        .font(.title)
                        .foregroundStyle(DesignSystem.Colors.accent)
                )

            VStack(alignment: .leading, spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(.headline)
                        .foregroundStyle(DesignSystem.Colors.primary)
                        .lineLimit(1)

                    Text(item.category)
                        .font(.caption)
                        .foregroundStyle(DesignSystem.Colors.secondary)
                }

                // Premium actions
                HStack {
                    Button(action: {
                        if premiumManager.hasFeatureAccess(.advancedAnalytics) {
                            // Show analytics
                        } else {
                            onPremiumRequired(.advancedAnalytics)
                        }
                    }) {
                        Image(systemName: "chart.bar.fill")
                            .font(.caption)
                            .foregroundStyle(premiumManager.hasFeatureAccess(.advancedAnalytics) ?
                                           .blue : DesignSystem.Colors.secondary)
                    }
                    .premiumBadge(feature: .advancedAnalytics, premiumManager: premiumManager)

                    Spacer()

                    Button(action: {
                        if premiumManager.hasFeatureAccess(.magazineStyleExports) {
                            // Export
                        } else {
                            onPremiumRequired(.magazineStyleExports)
                        }
                    }) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.caption)
                            .foregroundStyle(premiumManager.hasFeatureAccess(.magazineStyleExports) ?
                                           .green : DesignSystem.Colors.secondary)
                    }
                    .premiumBadge(feature: .magazineStyleExports, premiumManager: premiumManager)
                }
            }
        }
        .padding(12)
        .background(DesignSystem.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: DesignSystem.Colors.shadow, radius: 8, y: 4)
    }
}

// MARK: - Settings Integration Example
struct PremiumSettingsView: View {
    @StateObject private var premiumManager = PremiumManager()
    @State private var showingPaywall = false

    var body: some View {
        NavigationView {
            List {
                Section {
                    if premiumManager.isPremium {
                        premiumStatusRow
                    } else {
                        upgradePromptRow
                    }
                }

                Section("Premium Features") {
                    featureRow(
                        icon: "infinity",
                        title: "Unlimited Items",
                        description: "Add unlimited wardrobe items",
                        feature: .unlimitedItems
                    )

                    featureRow(
                        icon: "message.circle.fill",
                        title: "AI Stylist Chat",
                        description: "Chat with your personal AI stylist",
                        feature: .aiStylistChat
                    )

                    featureRow(
                        icon: "sparkles",
                        title: "Outfit Genius Mode",
                        description: "Advanced AI outfit combinations",
                        feature: .outfitGeniusMode
                    )

                    featureRow(
                        icon: "bag.fill",
                        title: "Smart Shopping",
                        description: "AI-powered shopping assistant",
                        feature: .shoppingCompanion
                    )

                    featureRow(
                        icon: "icloud.fill",
                        title: "Cloud Sync",
                        description: "Sync across all your devices",
                        feature: .cloudSync
                    )
                }

                if premiumManager.isPremium {
                    Section("Subscription Management") {
                        if let product = premiumManager.currentProduct {
                            Text("Current Plan: \(product.displayName)")
                            Text("Price: \(product.displayPrice)")
                        }

                        Button("Manage Subscription") {
                            if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                                UIApplication.shared.open(url)
                            }
                        }
                    }
                } else {
                    Section("Free Plan Usage") {
                        usageRow(
                            title: "Items",
                            current: premiumManager.currentItemCount,
                            limit: PremiumManager.FreeTierLimits.maxItems
                        )

                        usageRow(
                            title: "Daily Outfit Suggestions",
                            current: premiumManager.dailyOutfitSuggestionsUsed,
                            limit: PremiumManager.FreeTierLimits.dailyOutfitSuggestions
                        )

                        usageRow(
                            title: "Weekly Selfie Ratings",
                            current: premiumManager.weeklySelfieeRatingsUsed,
                            limit: PremiumManager.FreeTierLimits.weeklySelfieeRatings
                        )
                    }
                }
            }
            .navigationTitle("Premium")
        }
        .sheet(isPresented: $showingPaywall) {
            PaywallView()
        }
    }

    private var premiumStatusRow: some View {
        HStack {
            Image(systemName: "crown.fill")
                .foregroundColor(.yellow)
                .font(.title2)

            VStack(alignment: .leading) {
                Text("StyleSync Premium")
                    .font(.headline)
                    .fontWeight(.bold)

                Text("You have access to all premium features")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text("ACTIVE")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.green)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.green.opacity(0.1))
                .clipShape(Capsule())
        }
        .padding(.vertical, 4)
    }

    private var upgradePromptRow: some View {
        Button(action: { showingPaywall = true }) {
            HStack {
                LinearGradient(
                    gradient: Gradient(colors: [.purple, .pink]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .mask(
                    Image(systemName: "crown.fill")
                        .font(.title2)
                )
                .frame(width: 28, height: 24)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Upgrade to Premium")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)

                    Text("Unlock unlimited access and AI features")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Text("Upgrade")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [.purple, .pink]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(Capsule())
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func featureRow(icon: String, title: String, description: String, feature: PremiumFeature) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(premiumManager.hasFeatureAccess(feature) ? .blue : .secondary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if premiumManager.hasFeatureAccess(feature) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            } else {
                Image(systemName: "lock.circle.fill")
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 2)
    }

    private func usageRow(title: String, current: Int, limit: Int) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)

                ProgressView(value: Double(current), total: Double(limit))
                    .progressViewStyle(LinearProgressViewStyle())
            }

            Spacer()

            Text("\(current)/\(limit)")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(current >= limit ? .red : .primary)
        }
        .padding(.vertical, 4)
    }
}

#Preview("Premium Integrated Content") {
    PremiumIntegratedContentView()
        .modelContainer(for: [StyleItem.self, Collection.self], inMemory: true)
}

#Preview("Premium Settings") {
    PremiumSettingsView()
}