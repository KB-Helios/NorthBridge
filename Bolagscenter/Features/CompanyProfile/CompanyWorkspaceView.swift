import SwiftData
import SwiftUI

@MainActor
struct CompanyWorkspaceView: View {
    @Environment(AppEnvironment.self) private var environment
    @Query(sort: \CompanyRecord.registeredName) private var companies: [CompanyRecord]
    @Query private var memberships: [CompanyMembershipRecord]

    var body: some View {
        List {
            if let company {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(company.registeredName)
                            .font(.title3.bold())
                        Text(formattedOrganisationNumber(company.organisationNumber))
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(.secondary)
                        StatusBadge(
                            text: company.status.localizedName,
                            kind: company.status == .active ? .positive : .warning
                        )
                    }
                    .padding(.vertical, 8)
                    .accessibilityElement(children: .combine)
                }

                Section("Bolagsinformation") {
                    NavigationLink(value: AppRoute.companyDetails) {
                        Label("Grunduppgifter", systemImage: "building.2")
                    }
                    NavigationLink(value: AppRoute.boardAndSignatories) {
                        Label("Styrelse och firmateckning", systemImage: "person.3")
                    }
                    NavigationLink(value: AppRoute.boardWorkspace) {
                        Label("Styrelsearbete", systemImage: "person.3.sequence")
                    }
                    NavigationLink(value: AppRoute.ownership) {
                        Label("Ägare och aktiebok", systemImage: "chart.pie")
                    }
                    NavigationLink(value: AppRoute.deadlines) {
                        Label("Deadlines", systemImage: "calendar.badge.clock")
                    }
                    NavigationLink(value: AppRoute.activity) {
                        Label("Aktivitetshistorik", systemImage: "clock.arrow.circlepath")
                    }
                }

                Section {
                    SourceFooter(
                        source: company.sourceName,
                        updatedAt: company.sourceUpdatedAt,
                        stale: company.isStale
                    )
                } header: {
                    Text("Datakälla")
                } footer: {
                    if company.status == .unknown {
                        Text("Bolagsuppgifterna är manuellt angivna och inte verifierade mot Bolagsverket eller annan myndighet.")
                    }
                }
            } else {
                EmptyStateView(
                    systemImage: "building.2",
                    title: "Inget bolag valt",
                    message: "Välj ett bolag för att öppna bolagsarbetsytan."
                )
            }
        }
        .navigationTitle("Bolag")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Lägg till bolag", systemImage: "plus") {
                    if canAddAnotherCompany {
                        environment.router(for: .company)
                            .navigate(to: .addCompany)
                    } else {
                        environment.navigate(
                            to: .subscription,
                            in: .more
                        )
                    }
                }
            }
        }
    }

    private var company: CompanyRecord? {
        companies.first { $0.id == environment.selectedCompanyID }
    }

    private var canAddAnotherCompany: Bool {
        accessibleCompanyCount == 0
            || SubscriptionAccessPolicy().allows(
                .multipleCompanies,
                entitlement: environment.subscriptionManager.entitlement
            )
    }

    private var accessibleCompanyCount: Int {
        guard let accountID = environment.sessionController.activeSession?.accountID else {
            return 0
        }
        let companyIDs = Set(
            memberships
                .filter { $0.accountID == accountID && $0.isActive }
                .map(\.companyID)
        )
        return companies.filter { companyIDs.contains($0.id) }.count
    }

    private func formattedOrganisationNumber(_ digits: String) -> String {
        (try? OrganisationNumber(digits).formatted) ?? digits
    }
}

@MainActor
struct CompanyDetailsView: View {
    @Environment(AppEnvironment.self) private var environment
    @Query private var companies: [CompanyRecord]

    var body: some View {
        Group {
            if let company {
                List {
                    Section("Grunduppgifter") {
                        LabeledContent("Registrerat namn", value: company.registeredName)
                        LabeledContent(
                            "Organisationsnummer",
                            value: (try? OrganisationNumber(company.organisationNumber).formatted) ?? company.organisationNumber
                        )
                        LabeledContent("Status", value: company.status.localizedName)
                    }

                    Section("Datakvalitet") {
                        LabeledContent("Källa", value: company.sourceName)
                        LabeledContent(
                            "Uppdaterad",
                            value: company.sourceUpdatedAt.formatted(date: .long, time: .shortened)
                        )
                        LabeledContent("Verifiering", value: company.status == .unknown ? "Ej verifierad" : "Källmarkerad")
                    }
                }
            } else {
                EmptyStateView(
                    systemImage: "building.2",
                    title: "Bolaget saknas",
                    message: "Bolaget kan ha tagits bort."
                )
            }
        }
        .navigationTitle("Grunduppgifter")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var company: CompanyRecord? {
        companies.first { $0.id == environment.selectedCompanyID }
    }
}

@MainActor
struct ActivityHistoryView: View {
    @Environment(AppEnvironment.self) private var environment
    @Query(sort: \AuditEventRecord.occurredAt, order: .reverse) private var events: [AuditEventRecord]

    var body: some View {
        Group {
            if companyEvents.isEmpty {
                EmptyStateView(
                    systemImage: "clock.arrow.circlepath",
                    title: "Ingen aktivitet",
                    message: "Händelser visas här när uppgifter ändras."
                )
            } else {
                List(companyEvents) { event in
                    VStack(alignment: .leading, spacing: 5) {
                        Text(event.summary)
                            .font(.body)
                        Text(event.occurredAt, format: .dateTime.day().month().year().hour().minute())
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
        .navigationTitle("Aktivitet")
    }

    private var companyEvents: [AuditEventRecord] {
        guard let companyID = environment.selectedCompanyID else { return [] }
        return events.filter { $0.companyID == companyID }
    }
}
