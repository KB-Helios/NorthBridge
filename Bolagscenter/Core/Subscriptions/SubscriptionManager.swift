import Foundation
import Observation
import StoreKit

enum SubscriptionTier: Int, Codable, CaseIterable, Comparable, Sendable {
    case none = 0
    case bolagscenter = 1
    case pro = 2
    case team = 3

    static func < (lhs: SubscriptionTier, rhs: SubscriptionTier) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var localizedName: String {
        switch self {
        case .none: "Ingen aktiv plan"
        case .bolagscenter: "NorthBridge"
        case .pro: "NorthBridge Pro"
        case .team: "NorthBridge Team"
        }
    }

    var productID: String? {
        switch self {
        case .none: nil
        case .bolagscenter: "com.kbhelios.northbridge.subscription.basic"
        case .pro: "com.kbhelios.northbridge.subscription.pro"
        case .team: "com.kbhelios.northbridge.subscription.team"
        }
    }

    static func tier(for productID: String) -> SubscriptionTier? {
        allCases.first { $0.productID == productID }
    }
}

enum SubscriptionEntitlementState: String, Codable, Sendable {
    case none
    case active
    case gracePeriod
    case billingRetry
    case expired
    case revoked
    case cached

    var localizedName: String {
        switch self {
        case .none: "Ingen prenumeration"
        case .active: "Aktiv"
        case .gracePeriod: "Respitperiod"
        case .billingRetry: "Betalning behöver åtgärdas"
        case .expired: "Utgången"
        case .revoked: "Återkallad"
        case .cached: "Senast verifierad"
        }
    }
}

struct SubscriptionEntitlement: Codable, Equatable, Sendable {
    let tier: SubscriptionTier
    let state: SubscriptionEntitlementState
    let productID: String?
    let expirationDate: Date?
    let verifiedAt: Date

    static let none = SubscriptionEntitlement(
        tier: .none,
        state: .none,
        productID: nil,
        expirationDate: nil,
        verifiedAt: .now
    )

    var grantsPaidAccess: Bool {
        grantsPaidAccess(at: .now)
    }

    func grantsPaidAccess(at now: Date) -> Bool {
        if let expirationDate, expirationDate <= now {
            return false
        }
        switch state {
        case .active, .gracePeriod:
            return true
        case .cached:
            guard expirationDate != nil else { return false }
            return now.timeIntervalSince(verifiedAt) <= 24 * 60 * 60
        case .none, .billingRetry, .expired, .revoked:
            return false
        }
    }
}

enum SubscriptionCapability: Sendable {
    case oneCompany
    case multipleCompanies
    case advancedInsights
    case teamCollaboration
    case exportOwnData
    case deleteAccount
}

struct SubscriptionAccessPolicy: Sendable {
    func allows(
        _ capability: SubscriptionCapability,
        entitlement: SubscriptionEntitlement,
        now: Date = .now
    ) -> Bool {
        switch capability {
        case .exportOwnData, .deleteAccount:
            true
        case .oneCompany:
            entitlement.grantsPaidAccess(at: now)
                && entitlement.tier >= .bolagscenter
        case .multipleCompanies, .advancedInsights:
            entitlement.grantsPaidAccess(at: now)
                && entitlement.tier >= .pro
        case .teamCollaboration:
            entitlement.grantsPaidAccess(at: now)
                && entitlement.tier >= .team
        }
    }
}

enum SubscriptionError: LocalizedError {
    case unverifiedTransaction
    case productsUnavailable

    var errorDescription: String? {
        switch self {
        case .unverifiedTransaction:
            "Köpet kunde inte verifieras av App Store och ger därför ingen åtkomst."
        case .productsUnavailable:
            "Prenumerationsprodukterna kunde inte hämtas från App Store."
        }
    }
}

@MainActor
@Observable
final class SubscriptionManager {
    private static let cacheKey = "subscription.entitlement.v1"

    private(set) var products: [Product] = []
    private(set) var entitlement: SubscriptionEntitlement = .none
    private(set) var isLoading = false
    private(set) var purchasingProductID: String?
    private(set) var errorMessage: String?

    private let keychain: KeychainStore
    private var updatesTask: Task<Void, Never>?

    init(keychain: KeychainStore) {
        self.keychain = keychain
    }

    func prepare() async {
        startTransactionListener()
        await loadCachedEntitlement()
        await loadProducts()
        await refreshEntitlements()
    }

    func loadProducts() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let identifiers = SubscriptionTier.allCases.compactMap(\.productID)
            products = try await Product.products(for: identifiers)
                .sorted {
                    (SubscriptionTier.tier(for: $0.id) ?? .none)
                        < (SubscriptionTier.tier(for: $1.id) ?? .none)
                }
            if products.isEmpty {
                errorMessage = SubscriptionError.productsUnavailable.localizedDescription
            }
        } catch {
            errorMessage = SubscriptionError.productsUnavailable.localizedDescription
            SecureLogger.app.error(
                "StoreKit product load failed: \(error.localizedDescription, privacy: .private(mask: .hash))"
            )
        }
    }

    func purchase(_ product: Product) async {
        purchasingProductID = product.id
        errorMessage = nil
        defer { purchasingProductID = nil }

        do {
            switch try await product.purchase() {
            case .success(let result):
                let transaction = try verified(result)
                await transaction.finish()
                await refreshEntitlements()
            case .pending:
                errorMessage = String(localized: "Köpet väntar på godkännande.")
            case .userCancelled:
                break
            @unknown default:
                errorMessage = String(localized: "App Store returnerade ett okänt köpresultat.")
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func restorePurchases() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            try await AppStore.sync()
            await refreshEntitlements()
        } catch {
            errorMessage = String(localized: "Köpen kunde inte återställas.")
        }
    }

    func refreshEntitlements() async {
        var candidates: [SubscriptionEntitlement] = []

        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result,
                  let tier = SubscriptionTier.tier(for: transaction.productID) else {
                continue
            }
            let state = await state(for: transaction)
            guard state == .active || state == .gracePeriod else { continue }
            candidates.append(
                SubscriptionEntitlement(
                    tier: tier,
                    state: state,
                    productID: transaction.productID,
                    expirationDate: transaction.expirationDate,
                    verifiedAt: .now
                )
            )
        }

        if candidates.isEmpty {
            candidates += await inactiveSubscriptionCandidates()
        }

        let best = candidates.max {
            if $0.grantsPaidAccess != $1.grantsPaidAccess {
                return !$0.grantsPaidAccess && $1.grantsPaidAccess
            }
            return $0.tier < $1.tier
        } ?? .none
        entitlement = best
        await persist(best)
    }

    func product(for tier: SubscriptionTier) -> Product? {
        guard let productID = tier.productID else { return nil }
        return products.first { $0.id == productID }
    }

    #if DEBUG
    func installUITestEntitlement(_ tier: SubscriptionTier) {
        entitlement = SubscriptionEntitlement(
            tier: tier,
            state: .active,
            productID: tier.productID,
            expirationDate: .now.addingTimeInterval(86_400),
            verifiedAt: .now
        )
    }
    #endif

    func clearLocalState() async {
        entitlement = .none
        errorMessage = nil
        do {
            try await keychain.delete(Self.cacheKey)
        } catch {
            SecureLogger.security.error(
                "Entitlement cache cleanup failed: \(error.localizedDescription, privacy: .private(mask: .hash))"
            )
        }
    }

    private func startTransactionListener() {
        guard updatesTask == nil else { return }
        updatesTask = Task { [weak self] in
            for await result in Transaction.updates {
                guard !Task.isCancelled, let self else { return }
                do {
                    let transaction = try self.verified(result)
                    await transaction.finish()
                    await self.refreshEntitlements()
                } catch {
                    self.errorMessage = SubscriptionError
                        .unverifiedTransaction
                        .localizedDescription
                }
            }
        }
    }

    private func inactiveSubscriptionCandidates() async -> [SubscriptionEntitlement] {
        var candidates: [SubscriptionEntitlement] = []
        for product in products {
            guard let subscription = product.subscription,
                  let tier = SubscriptionTier.tier(for: product.id) else {
                continue
            }
            do {
                for status in try await subscription.status {
                    guard case .verified(let transaction) = status.transaction else {
                        continue
                    }
                    let state = map(status.state)
                    candidates.append(
                        SubscriptionEntitlement(
                            tier: tier,
                            state: state,
                            productID: product.id,
                            expirationDate: transaction.expirationDate,
                            verifiedAt: .now
                        )
                    )
                }
            } catch {
                SecureLogger.app.error(
                    "Subscription status load failed: \(error.localizedDescription, privacy: .private(mask: .hash))"
                )
            }
        }
        return candidates
    }

    private func state(
        for transaction: Transaction
    ) async -> SubscriptionEntitlementState {
        if transaction.revocationDate != nil {
            return .revoked
        }
        if let status = await transaction.subscriptionStatus {
            return map(status.state)
        }
        if let expirationDate = transaction.expirationDate,
           expirationDate <= .now {
            return .expired
        }
        return .active
    }

    private func map(
        _ state: Product.SubscriptionInfo.RenewalState
    ) -> SubscriptionEntitlementState {
        switch state {
        case .subscribed: .active
        case .inGracePeriod: .gracePeriod
        case .inBillingRetryPeriod: .billingRetry
        case .expired: .expired
        case .revoked: .revoked
        default: .none
        }
    }

    private func verified<Value>(
        _ result: VerificationResult<Value>
    ) throws -> Value {
        switch result {
        case .verified(let value):
            value
        case .unverified:
            throw SubscriptionError.unverifiedTransaction
        }
    }

    private func loadCachedEntitlement() async {
        do {
            guard let data = try await keychain.data(for: Self.cacheKey) else {
                return
            }
            var cached = try JSONDecoder().decode(
                SubscriptionEntitlement.self,
                from: data
            )
            if let expirationDate = cached.expirationDate,
               expirationDate <= .now {
                cached = SubscriptionEntitlement(
                    tier: cached.tier,
                    state: .expired,
                    productID: cached.productID,
                    expirationDate: expirationDate,
                    verifiedAt: cached.verifiedAt
                )
            } else if cached.grantsPaidAccess {
                cached = SubscriptionEntitlement(
                    tier: cached.tier,
                    state: .cached,
                    productID: cached.productID,
                    expirationDate: cached.expirationDate,
                    verifiedAt: cached.verifiedAt
                )
            }
            entitlement = cached
        } catch {
            SecureLogger.security.error(
                "Cached entitlement rejected: \(error.localizedDescription, privacy: .private(mask: .hash))"
            )
        }
    }

    private func persist(_ entitlement: SubscriptionEntitlement) async {
        do {
            let data = try JSONEncoder().encode(entitlement)
            try await keychain.store(data, for: Self.cacheKey)
        } catch {
            SecureLogger.security.error(
                "Entitlement cache failed: \(error.localizedDescription, privacy: .private(mask: .hash))"
            )
        }
    }
}
