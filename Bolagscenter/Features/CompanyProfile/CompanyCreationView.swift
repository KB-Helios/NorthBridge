import SwiftData
import SwiftUI

@MainActor
struct CompanyCreationView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var companies: [CompanyRecord]
    @Query private var memberships: [CompanyMembershipRecord]

    @State private var organisationNumber = ""
    @State private var registeredName = ""
    @State private var confirmedDetailsFingerprint: String?
    @State private var isSaving = false
    @State private var errorMessage: String?
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case organisationNumber
        case registeredName
    }

    var body: some View {
        Form {
            Section {
                TextField(
                    "Organisationsnummer",
                    text: $organisationNumber
                )
                .keyboardType(.numberPad)
                .focused($focusedField, equals: .organisationNumber)
                .accessibilityIdentifier("company.add.organisationNumber")
                TextField("Registrerat namn", text: $registeredName)
                    .textContentType(.organizationName)
                    .focused($focusedField, equals: .registeredName)
                    .submitLabel(.done)
                    .onSubmit { focusedField = nil }
                    .accessibilityIdentifier("company.add.name")
            } header: {
                Text("Bolagsuppgifter")
            } footer: {
                Text("Utan en konfigurerad registerintegration sparas uppgifterna som manuellt angivna och ej officiellt verifierade.")
            }

            if let parsedOrganisationNumber {
                Section("Kontrollera") {
                    LabeledContent(
                        "Organisationsnummer",
                        value: parsedOrganisationNumber.formatted
                    )
                    LabeledContent(
                        "Registrerat namn",
                        value: registeredName.trimmed
                    )
                    LabeledContent {
                        StatusBadge(
                            text: "Ej officiellt verifierat",
                            kind: .warning
                        )
                    } label: {
                        Text("Datastatus")
                    }
                    Toggle(
                        "Jag har kontrollerat uppgifterna",
                        isOn: detailsConfirmation
                    )
                    .accessibilityIdentifier("company.add.confirm")
                }
            } else if !organisationNumber.isEmpty {
                Section {
                    Label(
                        organisationNumberError
                            ?? String(localized: "Kontrollera organisationsnumret."),
                        systemImage: "exclamationmark.triangle.fill"
                    )
                    .foregroundStyle(.orange)
                }
            }

            if !canAddAnotherCompany {
                Section {
                    Label(
                        "NorthBridge Pro eller Team krävs för flera bolag.",
                        systemImage: "creditcard"
                    )
                    NavigationLink(
                        "Visa prenumerationer",
                        value: AppRoute.subscription
                    )
                }
            }

            if let errorMessage {
                Section {
                    Label(
                        errorMessage,
                        systemImage: "exclamationmark.circle.fill"
                    )
                    .foregroundStyle(.red)
                }
            }

            Section {
                Button {
                    save()
                } label: {
                    if isSaving {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Lägg till bolag")
                            .frame(maxWidth: .infinity)
                    }
                }
                .disabled(!canSave || isSaving)
                .accessibilityIdentifier("company.add.save")
            }
        }
        .navigationTitle("Nytt bolag")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var accountID: UUID? {
        environment.sessionController.activeSession?.accountID
    }

    private var accessibleCompanyCount: Int {
        guard let accountID else { return 0 }
        let companyIDs = Set(
            memberships
                .filter { $0.accountID == accountID && $0.isActive }
                .map(\.companyID)
        )
        return companies.filter { companyIDs.contains($0.id) }.count
    }

    private var canAddAnotherCompany: Bool {
        accessibleCompanyCount == 0
            || SubscriptionAccessPolicy().allows(
                .multipleCompanies,
                entitlement: environment.subscriptionManager.entitlement
            )
    }

    private var parsedOrganisationNumber: OrganisationNumber? {
        try? OrganisationNumber(organisationNumber)
    }

    private var organisationNumberError: String? {
        do {
            _ = try OrganisationNumber(organisationNumber)
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    private var canSave: Bool {
        canAddAnotherCompany
            && parsedOrganisationNumber != nil
            && !registeredName.trimmed.isEmpty
            && confirmedDetailsFingerprint == detailsFingerprint
    }

    private var detailsFingerprint: String {
        "\(parsedOrganisationNumber?.digits ?? organisationNumber.trimmed)|\(registeredName.trimmed)"
    }

    private var detailsConfirmation: Binding<Bool> {
        Binding(
            get: { confirmedDetailsFingerprint == detailsFingerprint },
            set: { isConfirmed in
                confirmedDetailsFingerprint = isConfirmed
                    ? detailsFingerprint
                    : nil
            }
        )
    }

    private func save() {
        guard let accountID,
              let number = parsedOrganisationNumber,
              canSave else {
            errorMessage = String(
                localized: "Kontrollera bolagsuppgifterna och prenumerationen."
            )
            return
        }
        guard !companies.contains(where: {
            $0.organisationNumber == number.digits
        }) else {
            errorMessage = String(
                localized: "Ett bolag med organisationsnumret finns redan på enheten."
            )
            return
        }

        isSaving = true
        defer { isSaving = false }

        let company = CompanyRecord(
            organisationNumber: number.digits,
            registeredName: registeredName.trimmed,
            status: .unknown,
            sourceName: String(localized: "Manuellt angivet"),
            sourceUpdatedAt: .now
        )
        let membership = CompanyMembershipRecord(
            accountID: accountID,
            companyID: company.id,
            role: .owner
        )
        modelContext.insert(company)
        modelContext.insert(membership)
        for category in CompanyResponsibilityCategory.allCases {
            modelContext.insert(
                CompanyResponsibilityRecord(
                    accountID: accountID,
                    companyID: company.id,
                    category: category
                )
            )
        }
        for category in NotificationCategory.allCases {
            modelContext.insert(
                NotificationPreferenceRecord(
                    accountID: accountID,
                    companyID: company.id,
                    category: category,
                    isEnabled: false,
                    showsSensitiveDetails: false
                )
            )
        }
        modelContext.insert(
            AuditEventRecord(
                companyID: company.id,
                accountID: accountID,
                action: "company.created",
                entityType: "company",
                entityID: company.id,
                summary: String(
                    localized: "Bolaget lades till manuellt och väntar på verifiering från en officiell källa."
                )
            )
        )

        do {
            try modelContext.save()
            environment.selectedCompanyID = company.id
            dismiss()
        } catch {
            modelContext.rollback()
            errorMessage = String(localized: "Bolaget kunde inte sparas.")
        }
    }
}

private extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
