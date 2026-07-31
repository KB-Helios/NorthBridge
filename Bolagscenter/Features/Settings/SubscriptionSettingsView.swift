import StoreKit
import SwiftUI

@MainActor
struct SubscriptionSettingsView: View {
    @Environment(AppEnvironment.self) private var environment

    var body: some View {
        let manager = environment.subscriptionManager

        Form {
            Section {
                LabeledContent(
                    "Status",
                    value: manager.entitlement.state.localizedName
                )
                LabeledContent(
                    "Plan",
                    value: manager.entitlement.tier.localizedName
                )
                if let expirationDate = manager.entitlement.expirationDate {
                    LabeledContent(
                        "Gäller till",
                        value: expirationDate.formatted(
                            date: .long,
                            time: .omitted
                        )
                    )
                }
            } header: {
                Text("Din prenumeration")
            } footer: {
                Text(statusExplanation(manager.entitlement))
            }

            ForEach(
                [SubscriptionTier.bolagscenter, .pro, .team],
                id: \.self
            ) { tier in
                Section {
                    subscriptionPlan(tier, manager: manager)
                } header: {
                    Text(tier.localizedName)
                } footer: {
                    Text(features(for: tier))
                }
            }

            Section {
                Button {
                    Task { await manager.restorePurchases() }
                } label: {
                    if manager.isLoading {
                        ProgressView()
                    } else {
                        Label(
                            "Återställ köp",
                            systemImage: "arrow.clockwise.circle"
                        )
                    }
                }
                .disabled(manager.isLoading || manager.purchasingProductID != nil)
            } footer: {
                Text("Köp och uppsägning hanteras av App Store. Att radera ditt lokala konto avslutar inte en aktiv App Store-prenumeration.")
            }

            if let errorMessage = manager.errorMessage {
                Section {
                    Label(
                        errorMessage,
                        systemImage: "exclamationmark.circle.fill"
                    )
                    .foregroundStyle(.red)
                }
            }

            Section {
                Label(
                    "Du kan alltid exportera dina egna data och radera kontot, även efter att prenumerationen har löpt ut.",
                    systemImage: "lock.open.display"
                )
                .font(.footnote)
            }
        }
        .navigationTitle("Prenumeration")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            await manager.loadProducts()
            await manager.refreshEntitlements()
        }
        .task {
            if manager.products.isEmpty {
                await manager.loadProducts()
            }
        }
    }

    @ViewBuilder
    private func subscriptionPlan(
        _ tier: SubscriptionTier,
        manager: SubscriptionManager
    ) -> some View {
        if let product = manager.product(for: tier) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Text(product.displayName)
                        .font(.headline)
                    Spacer()
                    Text(product.displayPrice)
                        .font(.headline)
                }
                Text(product.description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if manager.entitlement.tier == tier
                    && manager.entitlement.grantsPaidAccess {
                    Label("Nuvarande plan", systemImage: "checkmark.seal.fill")
                        .foregroundStyle(.green)
                } else {
                    Button {
                        Task { await manager.purchase(product) }
                    } label: {
                        if manager.purchasingProductID == product.id {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Välj \(tier.localizedName)")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(
                        manager.purchasingProductID != nil
                            || manager.isLoading
                    )
                }
            }
            .padding(.vertical, 4)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Text(tier.localizedName)
                    .font(.headline)
                Text("Produkten är ännu inte tillgänglig från App Store.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if let productID = tier.productID {
                    Text(productID)
                        .font(.caption.monospaced())
                        .foregroundStyle(.tertiary)
                        .textSelection(.enabled)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private func features(for tier: SubscriptionTier) -> String {
        switch tier {
        case .none:
            ""
        case .bolagscenter:
            "Administration för ett bolag."
        case .pro:
            "Flera bolag och avancerade insikter."
        case .team:
            "Delad bolagsadministration och styrelsesamarbete."
        }
    }

    private func statusExplanation(
        _ entitlement: SubscriptionEntitlement
    ) -> String {
        switch entitlement.state {
        case .none:
            "Ingen verifierad StoreKit-prenumeration hittades."
        case .active:
            "Prenumerationen är verifierad av App Store."
        case .gracePeriod:
            "Åtkomsten fortsätter under App Stores respitperiod."
        case .billingRetry:
            "App Store försöker lösa ett betalningsproblem. Betalda funktioner är pausade tills en giltig rättighet verifieras."
        case .expired:
            "Betalda funktioner är pausade. Export och kontoradering är fortfarande tillgängliga."
        case .revoked:
            "App Store har återkallat rättigheten. Export och kontoradering är fortfarande tillgängliga."
        case .cached:
            "Detta är senast lokalt verifierade status. Appen uppdaterar den mot App Store."
        }
    }
}
