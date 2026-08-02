#if DEBUG
import Foundation
import SwiftData

enum UITestLaunchConfiguration {
    static var isReset: Bool {
        CommandLine.arguments.contains("-ui-testing-reset")
    }

    static var isSeeded: Bool {
        CommandLine.arguments.contains("-ui-testing-seeded")
    }

    static var isOffline: Bool {
        CommandLine.arguments.contains("-ui-testing-offline")
    }

    static var isExpired: Bool {
        CommandLine.arguments.contains("-ui-testing-expired")
    }

    static var importsFixtureDocument: Bool {
        CommandLine.arguments.contains("-ui-testing-document-import")
    }

    static var capturesOnboardingLiquidSwipeFrame: Bool {
        CommandLine.arguments.contains("-ui-testing-liquid-swipe-frame")
    }

    static var requestedAppearance: NorthBridgeAppearance? {
        if CommandLine.arguments.contains("-ui-testing-appearance-dark") {
            return .dark
        }
        if CommandLine.arguments.contains("-ui-testing-appearance-light") {
            return .light
        }
        return nil
    }

    static var usesInMemoryStore: Bool {
        isReset || isSeeded
    }

    static let accountID = UUID(
        uuidString: "11111111-1111-1111-1111-111111111111"
    ) ?? UUID()
    static let primaryCompanyID = UUID(
        uuidString: "22222222-2222-2222-2222-222222222222"
    ) ?? UUID()
    static let secondaryCompanyID = UUID(
        uuidString: "33333333-3333-3333-3333-333333333333"
    ) ?? UUID()

    static var requestedRoute: String? {
        guard let index = CommandLine.arguments.firstIndex(
            of: "-ui-testing-route"
        ) else {
            return nil
        }
        let valueIndex = CommandLine.arguments.index(after: index)
        guard CommandLine.arguments.indices.contains(valueIndex) else {
            return nil
        }
        return CommandLine.arguments[valueIndex]
    }
}

@MainActor
enum UITestFixtureSeeder {
    static func seedIfNeeded(in context: ModelContext) throws {
        guard UITestLaunchConfiguration.isSeeded else { return }
        let accounts = try context.fetch(
            FetchDescriptor<UserAccountRecord>()
        )
        guard accounts.isEmpty else { return }

        let account = UserAccountRecord(
            id: UITestLaunchConfiguration.accountID,
            email: "ui-test@northbridge.invalid",
            displayName: "UI Test"
        )
        let primaryCompany = CompanyRecord(
            id: UITestLaunchConfiguration.primaryCompanyID,
            organisationNumber: "5560160680",
            registeredName: "Nordisk Test AB",
            status: .active,
            sourceName: "Deterministisk UI-testfixture",
            sourceUpdatedAt: .now,
            lastSynchronizedAt: .now,
            isStale: false
        )
        let secondaryCompany = CompanyRecord(
            id: UITestLaunchConfiguration.secondaryCompanyID,
            organisationNumber: "5590000856",
            registeredName: "Sydlig Test AB",
            status: .active,
            sourceName: "Deterministisk UI-testfixture",
            sourceUpdatedAt: .now,
            lastSynchronizedAt: .now,
            isStale: false
        )
        context.insert(account)
        context.insert(primaryCompany)
        context.insert(secondaryCompany)
        context.insert(
            CompanyMembershipRecord(
                accountID: account.id,
                companyID: primaryCompany.id,
                role: .owner
            )
        )
        context.insert(
            CompanyMembershipRecord(
                accountID: account.id,
                companyID: secondaryCompany.id,
                role: .administrator
            )
        )

        context.insert(
            DeadlineRecord(
                companyID: primaryCompany.id,
                title: "UI-testdeadline",
                dueAt: .now.addingTimeInterval(14 * 86_400),
                details: "Deterministisk deadline för UI-test.",
                responsibleName: "UI Test",
                priority: .high,
                sourceName: "UI-testfixture"
            )
        )
        context.insert(
            ActionItemRecord(
                companyID: primaryCompany.id,
                title: "Följ upp UI-test",
                details: "Deterministisk åtgärd.",
                assignedTo: "UI Test",
                dueAt: .now.addingTimeInterval(5 * 86_400)
            )
        )
        context.insert(
            FinancialMetricRecord(
                companyID: primaryCompany.id,
                kind: .availableLiquidity,
                amount: 275_000,
                periodStart: .now.addingTimeInterval(-30 * 86_400),
                periodEnd: .now,
                sourceName: "UI-testfixture",
                valueState: .manuallyEntered
            )
        )
        context.insert(
            DocumentRecord(
                id: UUID(
                    uuidString: "99999999-9999-9999-9999-999999999981"
                ) ?? UUID(),
                companyID: primaryCompany.id,
                title: "Årsredovisning 2025",
                category: .annualReports,
                originalFilename: "arsredovisning-2025.pdf",
                uniformTypeIdentifier: "com.adobe.pdf",
                extractedText: "Deterministiskt dokumentunderlag för visuell verifiering.",
                tags: "årsredovisning,2025",
                pageCount: 24,
                importedAt: .now.addingTimeInterval(-3 * 86_400),
                sourceName: "UI-testfixture",
                isFavorite: true,
                isAvailableOffline: false
            )
        )
        context.insert(
            DocumentRecord(
                id: UUID(
                    uuidString: "99999999-9999-9999-9999-999999999982"
                ) ?? UUID(),
                companyID: primaryCompany.id,
                title: "Styrelseprotokoll 2026-01",
                category: .boardMinutes,
                originalFilename: "styrelseprotokoll-2026-01.pdf",
                uniformTypeIdentifier: "com.adobe.pdf",
                extractedText: "Protokoll från UI-testmötet.",
                tags: "styrelse,protokoll",
                pageCount: 6,
                importedAt: .now.addingTimeInterval(-86_400),
                sourceName: "UI-testfixture",
                isAvailableOffline: true
            )
        )
        context.insert(
            DocumentRecord(
                id: UUID(
                    uuidString: "99999999-9999-9999-9999-999999999983"
                ) ?? UUID(),
                companyID: primaryCompany.id,
                title: "Registreringsbevis",
                category: .registrationCertificate,
                originalFilename: "registreringsbevis.pdf",
                uniformTypeIdentifier: "com.adobe.pdf",
                extractedText: "Registreringsbevis för Nordisk Test AB.",
                detectedOrganisationNumbers: "556016-0680",
                tags: "bolagsverket,registrering",
                pageCount: 2,
                importedAt: .now.addingTimeInterval(-7 * 86_400),
                sourceName: "UI-testfixture",
                isAvailableOffline: true
            )
        )
        context.insert(
            IntegrationRecord(
                companyID: primaryCompany.id,
                providerIdentifier: "ui-test-provider",
                displayName: "UI-testintegration",
                state: .failed,
                lastAttemptedAt: .now,
                lastErrorMessage: "Deterministiskt testfel"
            )
        )
        context.insert(
            BoardMeetingRecord(
                companyID: primaryCompany.id,
                title: "UI-testmöte",
                meetingNumber: "2026-01",
                scheduledAt: .now.addingTimeInterval(7 * 86_400),
                location: "Styrelserummet",
                status: .scheduled
            )
        )
        let shareClass = ShareClassRecord(
            id: UUID(
                uuidString: "99999999-9999-9999-9999-999999999991"
            ) ?? UUID(),
            companyID: primaryCompany.id,
            name: "A",
            votesPerShare: 1
        )
        let shareholder = ShareholderRecord(
            id: UUID(
                uuidString: "99999999-9999-9999-9999-999999999992"
            ) ?? UUID(),
            companyID: primaryCompany.id,
            displayName: "UI Testägare",
            shareholderKind: .person,
            identityReference: "UI-TEST-1"
        )
        context.insert(shareClass)
        context.insert(shareholder)
        context.insert(
            ShareTransactionRecord(
                id: UUID(
                    uuidString: "99999999-9999-9999-9999-999999999993"
                ) ?? UUID(),
                companyID: primaryCompany.id,
                shareClassID: shareClass.id,
                toShareholderID: shareholder.id,
                quantity: 1_000,
                kind: .issuance,
                transactionDate: .now,
                reference: "UI-test ingående innehav"
            )
        )
        for category in NotificationCategory.allCases {
            context.insert(
                NotificationPreferenceRecord(
                    accountID: account.id,
                    companyID: primaryCompany.id,
                    category: category,
                    isEnabled: false,
                    showsSensitiveDetails: false
                )
            )
        }
        context.insert(
            AuditEventRecord(
                companyID: primaryCompany.id,
                accountID: account.id,
                action: "ui.fixture.created",
                entityType: "testFixture",
                summary: "Deterministisk UI-testfixture skapades."
            )
        )
        try context.save()
    }
}
#endif
