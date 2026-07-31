import Foundation
import Testing
@testable import Bolagscenter

struct SubscriptionAccessPolicyTests {
    private let policy = SubscriptionAccessPolicy()

    @Test
    func expiredSubscriptionStillAllowsExportAndDeletion() {
        let now = Date(timeIntervalSince1970: 10_000)
        let entitlement = SubscriptionEntitlement(
            tier: .team,
            state: .expired,
            productID: SubscriptionTier.team.productID,
            expirationDate: now.addingTimeInterval(-1),
            verifiedAt: now.addingTimeInterval(-100)
        )

        #expect(
            policy.allows(
                .exportOwnData,
                entitlement: entitlement,
                now: now
            )
        )
        #expect(
            policy.allows(
                .deleteAccount,
                entitlement: entitlement,
                now: now
            )
        )
        #expect(
            !policy.allows(
                .teamCollaboration,
                entitlement: entitlement,
                now: now
            )
        )
    }

    @Test
    func proGracePeriodAllowsMultipleCompaniesButNotTeam() {
        let now = Date(timeIntervalSince1970: 10_000)
        let entitlement = SubscriptionEntitlement(
            tier: .pro,
            state: .gracePeriod,
            productID: SubscriptionTier.pro.productID,
            expirationDate: now.addingTimeInterval(3_600),
            verifiedAt: now
        )

        #expect(
            policy.allows(
                .multipleCompanies,
                entitlement: entitlement,
                now: now
            )
        )
        #expect(
            !policy.allows(
                .teamCollaboration,
                entitlement: entitlement,
                now: now
            )
        )
    }

    @Test
    func staleCachedEntitlementDoesNotGrantPaidAccess() {
        let now = Date(timeIntervalSince1970: 100_000)
        let entitlement = SubscriptionEntitlement(
            tier: .team,
            state: .cached,
            productID: SubscriptionTier.team.productID,
            expirationDate: now.addingTimeInterval(86_400),
            verifiedAt: now.addingTimeInterval(-(24 * 60 * 60 + 1))
        )

        #expect(
            !policy.allows(
                .teamCollaboration,
                entitlement: entitlement,
                now: now
            )
        )
    }
}
