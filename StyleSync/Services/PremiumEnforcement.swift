import SwiftUI
import Combine

// MARK: - Premium Enforcement Extension for Views
extension View {
    func premiumGate(
        feature: PremiumFeature,
        premiumManager: PremiumManager,
        presentPaywall: @escaping () -> Void
    ) -> some View {
        self.modifier(PremiumGateModifier(
            feature: feature,
            premiumManager: premiumManager,
            presentPaywall: presentPaywall
        ))
    }

    func premiumBadge(
        feature: PremiumFeature,
        premiumManager: PremiumManager
    ) -> some View {
        self.modifier(PremiumBadgeModifier(
            feature: feature,
            premiumManager: premiumManager
        ))
    }

    func premiumOverlay(
        feature: PremiumFeature,
        premiumManager: PremiumManager,
        presentPaywall: @escaping () -> Void
    ) -> some View {
        self.modifier(PremiumOverlayModifier(
            feature: feature,
            premiumManager: premiumManager,
            presentPaywall: presentPaywall
        ))
    }
}

// MARK: - Premium Gate Modifier
struct PremiumGateModifier: ViewModifier {
    let feature: PremiumFeature
    @ObservedObject var premiumManager: PremiumManager
    let presentPaywall: () -> Void

    func body(content: Content) -> some View {
        if premiumManager.hasFeatureAccess(feature) {
            content
        } else {
            Button(action: presentPaywall) {
                content
                    .overlay(
                        Rectangle()
                            .fill(Color.black.opacity(0.1))
                    )
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
}

// MARK: - Premium Badge Modifier
struct PremiumBadgeModifier: ViewModifier {
    let feature: PremiumFeature
    @ObservedObject var premiumManager: PremiumManager

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .topTrailing) {
                if !premiumManager.hasFeatureAccess(feature) {
                    premiumBadge
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
        .offset(x: 8, y: -8)
    }
}

// MARK: - Premium Overlay Modifier
struct PremiumOverlayModifier: ViewModifier {
    let feature: PremiumFeature
    @ObservedObject var premiumManager: PremiumManager
    let presentPaywall: () -> Void

    func body(content: Content) -> some View {
        content
            .overlay {
                if !premiumManager.hasFeatureAccess(feature) {
                    premiumOverlay
                }
            }
    }

    private var premiumOverlay: some View {
        ZStack {
            Rectangle()
                .fill(Color.black.opacity(0.7))

            VStack(spacing: 16) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.yellow)

                Text("Premium Feature")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)

                Text("Upgrade to StyleSync Premium to unlock this feature")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)

                Button("Upgrade Now") {
                    presentPaywall()
                }
                .buttonStyle(PremiumButtonStyle())
            }
            .padding(32)
        }
    }
}

// MARK: - Premium Button Style
struct PremiumButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [.purple, .pink]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(Capsule())
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Usage Tracking Service
@MainActor
class UsageTracker: ObservableObject {
    @Published var dailyUsage: [String: Int] = [:]
    @Published var weeklyUsage: [String: Int] = [:]
    @Published var monthlyUsage: [String: Int] = [:]

    private let userDefaults = UserDefaults.standard
    private let premiumManager: PremiumManager

    init(premiumManager: PremiumManager) {
        self.premiumManager = premiumManager
        loadUsageData()
        resetCountersIfNeeded()
    }

    // MARK: - Tracking Methods
    func trackUsage(for feature: String, type: UsageType = .daily) {
        guard !premiumManager.isPremium else { return }

        switch type {
        case .daily:
            dailyUsage[feature, default: 0] += 1
        case .weekly:
            weeklyUsage[feature, default: 0] += 1
        case .monthly:
            monthlyUsage[feature, default: 0] += 1
        }

        saveUsageData()
    }

    func getUsage(for feature: String, type: UsageType) -> Int {
        switch type {
        case .daily:
            return dailyUsage[feature, default: 0]
        case .weekly:
            return weeklyUsage[feature, default: 0]
        case .monthly:
            return monthlyUsage[feature, default: 0]
        }
    }

    func canUseFeature(_ feature: String, limit: Int, type: UsageType) -> Bool {
        guard !premiumManager.isPremium else { return true }
        return getUsage(for: feature, type: type) < limit
    }

    // MARK: - Data Persistence
    private func loadUsageData() {
        if let dailyData = userDefaults.object(forKey: "dailyUsage") as? [String: Int] {
            dailyUsage = dailyData
        }
        if let weeklyData = userDefaults.object(forKey: "weeklyUsage") as? [String: Int] {
            weeklyUsage = weeklyData
        }
        if let monthlyData = userDefaults.object(forKey: "monthlyUsage") as? [String: Int] {
            monthlyUsage = monthlyData
        }
    }

    private func saveUsageData() {
        userDefaults.set(dailyUsage, forKey: "dailyUsage")
        userDefaults.set(weeklyUsage, forKey: "weeklyUsage")
        userDefaults.set(monthlyUsage, forKey: "monthlyUsage")
    }

    private func resetCountersIfNeeded() {
        let calendar = Calendar.current
        let now = Date()

        // Check daily reset
        if let lastDailyReset = userDefaults.object(forKey: "lastDailyReset") as? Date {
            if !calendar.isDate(lastDailyReset, inSameDayAs: now) {
                dailyUsage.removeAll()
                userDefaults.set(now, forKey: "lastDailyReset")
            }
        } else {
            userDefaults.set(now, forKey: "lastDailyReset")
        }

        // Check weekly reset
        if let lastWeeklyReset = userDefaults.object(forKey: "lastWeeklyReset") as? Date {
            let weekAgo = calendar.date(byAdding: .weekOfYear, value: -1, to: now) ?? Date()
            if lastWeeklyReset < weekAgo {
                weeklyUsage.removeAll()
                userDefaults.set(now, forKey: "lastWeeklyReset")
            }
        } else {
            userDefaults.set(now, forKey: "lastWeeklyReset")
        }

        // Check monthly reset
        if let lastMonthlyReset = userDefaults.object(forKey: "lastMonthlyReset") as? Date {
            let monthAgo = calendar.date(byAdding: .month, value: -1, to: now) ?? Date()
            if lastMonthlyReset < monthAgo {
                monthlyUsage.removeAll()
                userDefaults.set(now, forKey: "lastMonthlyReset")
            }
        } else {
            userDefaults.set(now, forKey: "lastMonthlyReset")
        }

        saveUsageData()
    }
}

enum UsageType {
    case daily, weekly, monthly
}

// MARK: - Premium Status Bar
struct PremiumStatusBar: View {
    @ObservedObject var premiumManager: PremiumManager
    @ObservedObject var usageTracker: UsageTracker

    var body: some View {
        if !premiumManager.isPremium {
            VStack(spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("StyleSync Free")
                            .font(.caption)
                            .fontWeight(.medium)

                        Text("Upgrade for unlimited access")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Button("Upgrade") {
                        // Present paywall
                    }
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.purple)
                    .clipShape(Capsule())
                }

                // Usage indicators
                HStack(spacing: 16) {
                    usageIndicator(
                        title: "Items",
                        current: premiumManager.currentItemCount,
                        limit: PremiumManager.FreeTierLimits.maxItems
                    )

                    usageIndicator(
                        title: "Outfits",
                        current: premiumManager.dailyOutfitSuggestionsUsed,
                        limit: PremiumManager.FreeTierLimits.dailyOutfitSuggestions
                    )

                    usageIndicator(
                        title: "Ratings",
                        current: premiumManager.weeklySelfieeRatingsUsed,
                        limit: PremiumManager.FreeTierLimits.weeklySelfieeRatings
                    )
                }
            }
            .padding(16)
            .background(Color(.systemBackground))
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .fill(Color(.separator)),
                alignment: .bottom
            )
        }
    }

    private func usageIndicator(title: String, current: Int, limit: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)

            Text("\(current)/\(limit)")
                .font(.caption)
                .fontWeight(.medium)

            ProgressView(value: Double(current), total: Double(limit))
                .progressViewStyle(LinearProgressViewStyle())
                .frame(height: 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Premium Onboarding
struct PremiumOnboardingView: View {
    @StateObject private var premiumManager = PremiumManager()
    @Environment(\.dismiss) private var dismiss
    @State private var currentPage = 0

    private let features = [
        OnboardingFeature(
            icon: "infinity",
            title: "Unlimited Everything",
            description: "Add unlimited items, get unlimited outfit suggestions, and rate as many selfies as you want.",
            color: .purple
        ),
        OnboardingFeature(
            icon: "brain.head.profile",
            title: "AI Stylist Chat",
            description: "Chat with your personal AI stylist for personalized fashion advice and style tips.",
            color: .blue
        ),
        OnboardingFeature(
            icon: "sparkles",
            title: "Outfit Genius Mode",
            description: "Advanced AI creates perfect outfit combinations based on weather, occasion, and your style.",
            color: .pink
        ),
        OnboardingFeature(
            icon: "bag.fill",
            title: "Smart Shopping",
            description: "AI-powered shopping companion helps you find pieces that complete your wardrobe.",
            color: .green
        )
    ]

    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [Color(.systemBackground), Color(.secondarySystemBackground)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack {
                // Close button
                HStack {
                    Spacer()
                    Button("Skip") {
                        dismiss()
                    }
                    .foregroundColor(.secondary)
                    .padding()
                }

                Spacer()

                // Feature content
                TabView(selection: $currentPage) {
                    ForEach(features.indices, id: \.self) { index in
                        featureView(features[index])
                            .tag(index)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .frame(height: 400)

                // Page indicator
                HStack(spacing: 8) {
                    ForEach(features.indices, id: \.self) { index in
                        Circle()
                            .fill(index == currentPage ? Color.purple : Color.secondary.opacity(0.3))
                            .frame(width: 8, height: 8)
                    }
                }
                .padding(.vertical)

                Spacer()

                // Action button
                Button(action: {
                    if currentPage < features.count - 1 {
                        withAnimation {
                            currentPage += 1
                        }
                    } else {
                        // Present paywall
                    }
                }) {
                    Text(currentPage < features.count - 1 ? "Next" : "Get Premium")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [.purple, .pink]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 32)
            }
        }
    }

    private func featureView(_ feature: OnboardingFeature) -> some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(feature.color.opacity(0.1))
                    .frame(width: 120, height: 120)

                Image(systemName: feature.icon)
                    .font(.system(size: 50, weight: .light))
                    .foregroundColor(feature.color)
            }

            VStack(spacing: 16) {
                Text(feature.title)
                    .font(.title)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)

                Text(feature.description)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
        }
    }
}

struct OnboardingFeature {
    let icon: String
    let title: String
    let description: String
    let color: Color
}

#Preview {
    PremiumOnboardingView()
}