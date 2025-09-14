import Foundation
import StoreKit
import Combine

@MainActor
class PremiumManager: ObservableObject {

    // MARK: - Published Properties
    @Published var isPremium: Bool = false
    @Published var subscriptionStatus: Product.SubscriptionInfo.Status?
    @Published var currentProduct: Product?
    @Published var isLoading: Bool = false
    @Published var purchaseError: Error?

    // MARK: - Product Identifiers
    private let premiumMonthlyID = "com.stylesync.premium.monthly"
    private let premiumYearlyID = "com.stylesync.premium.yearly"

    // MARK: - Available Products
    @Published var availableProducts: [Product] = []

    // MARK: - Subscription Limits for Free Tier
    struct FreeTierLimits {
        static let maxItems = 50
        static let dailyOutfitSuggestions = 5
        static let weeklySelfieeRatings = 1
    }

    // MARK: - Usage Tracking
    @Published var currentItemCount: Int = 0
    @Published var dailyOutfitSuggestionsUsed: Int = 0
    @Published var weeklySelfieeRatingsUsed: Int = 0
    @Published var lastResetDate: Date = Date()

    // MARK: - Task Handle
    private var listenForTransactionsTask: Task<Void, Error>?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Server Validation
    private let serverValidationURL = "https://your-server.com/validate-receipt"

    init() {
        setupObservers()
        Task {
            await loadProducts()
            await updateSubscriptionStatus()
            startListeningForTransactions()
        }
    }

    deinit {
        listenForTransactionsTask?.cancel()
    }

    // MARK: - Setup
    private func setupObservers() {
        // Reset daily counters at midnight
        Timer.publish(every: 3600, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.checkAndResetCounters()
            }
            .store(in: &cancellables)
    }

    // MARK: - Product Loading
    func loadProducts() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let products = try await Product.products(for: [premiumMonthlyID, premiumYearlyID])
            availableProducts = products.sorted { $0.price < $1.price }
        } catch {
            print("Failed to load products: \(error)")
            purchaseError = error
        }
    }

    // MARK: - Subscription Status
    func updateSubscriptionStatus() async {
        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)

                // Validate with server
                if await validateTransactionWithServer(transaction) {
                    await updateSubscriptionInfo(for: transaction)
                }
            } catch {
                print("Transaction verification failed: \(error)")
            }
        }
    }

    private func updateSubscriptionInfo(for transaction: Transaction) async {
        guard let product = availableProducts.first(where: { $0.id == transaction.productID }) else {
            return
        }

        currentProduct = product

        // Check subscription status
        if let subscription = product.subscription {
            subscriptionStatus = try? await subscription.status.first?.state

            switch subscriptionStatus {
            case .subscribed, .inGracePeriod, .inBillingRetryPeriod:
                isPremium = true
            case .expired, .revoked, .none:
                isPremium = false
            @unknown default:
                isPremium = false
            }
        }
    }

    // MARK: - Purchase Flow
    func purchase(_ product: Product) async throws -> Transaction? {
        isLoading = true
        purchaseError = nil

        defer { isLoading = false }

        let result = try await product.purchase()

        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)

            // Validate with server
            if await validateTransactionWithServer(transaction) {
                await updateSubscriptionStatus()
                await transaction.finish()
                return transaction
            } else {
                throw PremiumError.serverValidationFailed
            }

        case .userCancelled, .pending:
            return nil

        @unknown default:
            return nil
        }
    }

    // MARK: - Restore Purchases
    func restorePurchases() async throws {
        isLoading = true
        defer { isLoading = false }

        try await AppStore.sync()
        await updateSubscriptionStatus()
    }

    // MARK: - Transaction Listening
    private func startListeningForTransactions() {
        listenForTransactionsTask = Task.detached {
            for await result in Transaction.updates {
                do {
                    let transaction = try self.checkVerified(result)

                    await self.updateSubscriptionStatus()
                    await transaction.finish()
                } catch {
                    print("Transaction update failed: \(error)")
                }
            }
        }
    }

    // MARK: - Transaction Verification
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw PremiumError.failedVerification
        case .verified(let safe):
            return safe
        }
    }

    // MARK: - Server Validation
    private func validateTransactionWithServer(_ transaction: Transaction) async -> Bool {
        guard let receiptData = try? await getReceiptData() else {
            return false
        }

        var request = URLRequest(url: URL(string: serverValidationURL)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload = [
            "receipt": receiptData.base64EncodedString(),
            "productId": transaction.productID,
            "transactionId": String(transaction.id)
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
            let (data, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse,
               httpResponse.statusCode == 200,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let isValid = json["valid"] as? Bool {
                return isValid
            }
        } catch {
            print("Server validation error: \(error)")
        }

        return false
    }

    private func getReceiptData() async throws -> Data {
        if let appStoreReceiptURL = Bundle.main.appStoreReceiptURL,
           FileManager.default.fileExists(atPath: appStoreReceiptURL.path) {
            return try Data(contentsOf: appStoreReceiptURL)
        }

        // Refresh receipt if not available
        let request = SKReceiptRefreshRequest()
        return try await withCheckedThrowingContinuation { continuation in
            request.delegate = ReceiptRefreshDelegate { result in
                continuation.resume(with: result)
            }
            request.start()
        }
    }

    // MARK: - Family Sharing Support
    func checkFamilySharing() async -> Bool {
        guard let product = currentProduct,
              let subscription = product.subscription else {
            return false
        }

        return subscription.familyShareable
    }

    // MARK: - Promotional Offers
    func checkEligibilityForIntroductoryOffer(product: Product) async -> Bool {
        guard let subscription = product.subscription else { return false }

        do {
            return await subscription.isEligibleForIntroOffer
        } catch {
            print("Failed to check intro offer eligibility: \(error)")
            return false
        }
    }

    func checkEligibilityForPromotionalOffer(product: Product, offerID: String) async -> Product.PurchaseOption? {
        guard let subscription = product.subscription else { return nil }

        let offers = subscription.promotionalOffers
        if let offer = offers.first(where: { $0.id == offerID }) {
            return .promotionalOffer(offer)
        }

        return nil
    }

    // MARK: - Win-back Offers
    func checkWinBackOffers() async -> [Product.SubscriptionOffer] {
        var winBackOffers: [Product.SubscriptionOffer] = []

        for product in availableProducts {
            if let subscription = product.subscription {
                let offers = subscription.winBackOffers
                winBackOffers.append(contentsOf: offers)
            }
        }

        return winBackOffers
    }

    // MARK: - Usage Tracking and Limits
    func canAddItem() -> Bool {
        return isPremium || currentItemCount < FreeTierLimits.maxItems
    }

    func canGenerateOutfitSuggestion() -> Bool {
        return isPremium || dailyOutfitSuggestionsUsed < FreeTierLimits.dailyOutfitSuggestions
    }

    func canRateSelfie() -> Bool {
        return isPremium || weeklySelfieeRatingsUsed < FreeTierLimits.weeklySelfieeRatings
    }

    func incrementItemCount() {
        if !isPremium {
            currentItemCount += 1
        }
    }

    func decrementItemCount() {
        if !isPremium && currentItemCount > 0 {
            currentItemCount -= 1
        }
    }

    func incrementOutfitSuggestion() {
        if !isPremium {
            dailyOutfitSuggestionsUsed += 1
        }
    }

    func incrementSelfieeRating() {
        if !isPremium {
            weeklySelfieeRatingsUsed += 1
        }
    }

    private func checkAndResetCounters() {
        let calendar = Calendar.current
        let now = Date()

        // Reset daily counters
        if !calendar.isDate(lastResetDate, inSameDayAs: now) {
            dailyOutfitSuggestionsUsed = 0
            lastResetDate = now
        }

        // Reset weekly counters
        let weekAgo = calendar.date(byAdding: .weekOfYear, value: -1, to: now) ?? Date()
        if lastResetDate < weekAgo {
            weeklySelfieeRatingsUsed = 0
        }
    }

    // MARK: - Feature Access
    func hasFeatureAccess(_ feature: PremiumFeature) -> Bool {
        switch feature {
        case .unlimitedItems:
            return isPremium || currentItemCount < FreeTierLimits.maxItems
        case .aiStylistChat:
            return isPremium
        case .unlimitedSelfieRatings:
            return isPremium || weeklySelfieeRatingsUsed < FreeTierLimits.weeklySelfieeRatings
        case .outfitGeniusMode:
            return isPremium
        case .advancedAnalytics:
            return isPremium
        case .shoppingCompanion:
            return isPremium
        case .priorityAIProcessing:
            return isPremium
        case .magazineStyleExports:
            return isPremium
        case .cloudSync:
            return isPremium
        case .weatherIntegration:
            return true // Available for all users
        case .basicColorMatching:
            return true // Available for all users
        case .manualOrganization:
            return true // Available for all users
        }
    }

    // MARK: - Pricing Information
    func getDisplayPrice(for product: Product) -> String {
        return product.displayPrice
    }

    func getMonthlyEquivalentPrice(for product: Product) -> String? {
        guard let subscription = product.subscription else { return nil }

        let period = subscription.subscriptionPeriod
        let monthlyPrice: Decimal

        switch period.unit {
        case .month:
            if period.value == 1 {
                monthlyPrice = product.price
            } else {
                monthlyPrice = product.price / Decimal(period.value)
            }
        case .year:
            monthlyPrice = product.price / 12
        default:
            return nil
        }

        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = product.priceFormatStyle.locale

        return formatter.string(from: monthlyPrice as NSDecimalNumber)
    }
}

// MARK: - Supporting Types
enum PremiumError: LocalizedError {
    case failedVerification
    case serverValidationFailed
    case receiptNotFound

    var errorDescription: String? {
        switch self {
        case .failedVerification:
            return "Transaction verification failed"
        case .serverValidationFailed:
            return "Server validation failed"
        case .receiptNotFound:
            return "Receipt not found"
        }
    }
}

enum PremiumFeature {
    case unlimitedItems
    case aiStylistChat
    case unlimitedSelfieRatings
    case outfitGeniusMode
    case advancedAnalytics
    case shoppingCompanion
    case priorityAIProcessing
    case magazineStyleExports
    case cloudSync
    case weatherIntegration
    case basicColorMatching
    case manualOrganization
}

// MARK: - Receipt Refresh Delegate
private class ReceiptRefreshDelegate: NSObject, SKRequestDelegate {
    private let completion: (Result<Data, Error>) -> Void

    init(completion: @escaping (Result<Data, Error>) -> Void) {
        self.completion = completion
    }

    func requestDidFinish(_ request: SKRequest) {
        if let appStoreReceiptURL = Bundle.main.appStoreReceiptURL,
           FileManager.default.fileExists(atPath: appStoreReceiptURL.path) {
            do {
                let receiptData = try Data(contentsOf: appStoreReceiptURL)
                completion(.success(receiptData))
            } catch {
                completion(.failure(error))
            }
        } else {
            completion(.failure(PremiumError.receiptNotFound))
        }
    }

    func request(_ request: SKRequest, didFailWithError error: Error) {
        completion(.failure(error))
    }
}