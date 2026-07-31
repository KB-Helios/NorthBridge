import Foundation
import SwiftData

struct CompanyRegistryRefreshResult: Sendable {
    let sourceName: String
    let sourceUpdatedAt: Date
    let synchronizedAt: Date
}

enum CompanyRegistryRefreshError: LocalizedError, Equatable, Sendable {
    case permissionDenied
    case mismatchedOrganisationNumber
    case persistence
    case providerFailure

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            "Din roll saknar behörighet att uppdatera bolagsuppgifter."
        case .mismatchedOrganisationNumber:
            "Datakällan returnerade uppgifter för ett annat organisationsnummer."
        case .persistence:
            "Synkroniseringsresultatet kunde inte sparas säkert."
        case .providerFailure:
            "Bolagsregistret kunde inte slutföra uppdateringen. Försök igen senare."
        }
    }
}

struct IntegrationErrorStatePolicy: Sendable {
    func state(for error: Error) -> IntegrationState {
        if let error = error as? IntegrationAdapterError {
            return switch error {
            case .notConfigured: .disconnected
            case .unauthorized: .unauthorized
            case .unavailable: .unavailable
            case .staleData: .stale
            }
        }
        if let error = error as? APIClientError {
            return switch error {
            case .authenticationRequired, .forbidden: .unauthorized
            case .rateLimited: .rateLimited
            case .offline: .stale
            case .queuedForRetry: .refreshing
            default: .failed
            }
        }
        return .failed
    }
}

@MainActor
struct CompanyRegistryRefreshService {
    let registry: any CompanyRegistryService
    let permissionPolicy: PermissionPolicy
    let errorStatePolicy: IntegrationErrorStatePolicy

    init(
        registry: any CompanyRegistryService,
        permissionPolicy: PermissionPolicy,
        errorStatePolicy: IntegrationErrorStatePolicy =
            IntegrationErrorStatePolicy()
    ) {
        self.registry = registry
        self.permissionPolicy = permissionPolicy
        self.errorStatePolicy = errorStatePolicy
    }

    func refresh(
        company: CompanyRecord,
        accountID: UUID,
        role: CompanyRole?,
        profiles: [CompanyProfileRecord],
        integrations: [IntegrationRecord],
        in context: ModelContext,
        now: Date = .now
    ) async throws -> CompanyRegistryRefreshResult {
        guard let role,
              permissionPolicy.allows(.editCompany, for: role) else {
            throw CompanyRegistryRefreshError.permissionDenied
        }

        let integration = registryIntegration(
            companyID: company.id,
            integrations: integrations,
            context: context
        )
        integration.state = .refreshing
        integration.lastAttemptedAt = now
        integration.lastErrorMessage = nil

        do {
            let organisationNumber = try OrganisationNumber(
                company.organisationNumber
            )
            let value = try await registry.fetchCompanyDetails(
                organisationNumber: organisationNumber
            )
            guard value.organisationNumber == organisationNumber else {
                throw CompanyRegistryRefreshError
                    .mismatchedOrganisationNumber
            }

            company.registeredName = value.registeredName
            company.status = value.status
            company.sourceName = value.sourceName
            company.sourceUpdatedAt = value.sourceUpdatedAt
            company.lastSynchronizedAt = now
            company.isStale = false

            if let registeredOffice = value.registeredOffice {
                let profile = profiles.first {
                    $0.companyID == company.id
                } ?? {
                    let profile = CompanyProfileRecord(
                        companyID: company.id,
                        sourceName: value.sourceName,
                        sourceUpdatedAt: value.sourceUpdatedAt
                    )
                    context.insert(profile)
                    return profile
                }()
                profile.registeredOffice = registeredOffice
                profile.sourceName = value.sourceName
                profile.sourceUpdatedAt = value.sourceUpdatedAt
                profile.updatedAt = now
            }

            integration.state = .connected
            integration.lastSuccessfulAt = now
            integration.lastErrorMessage = nil
            context.insert(
                AuditEventRecord(
                    companyID: company.id,
                    accountID: accountID,
                    action: "company.registry.refreshed",
                    entityType: "company",
                    entityID: company.id,
                    summary: String(
                        localized: "Bolagsuppgifter uppdaterades från \(value.sourceName)."
                    )
                )
            )
            try save(context)
            return CompanyRegistryRefreshResult(
                sourceName: value.sourceName,
                sourceUpdatedAt: value.sourceUpdatedAt,
                synchronizedAt: now
            )
        } catch {
            let presentedError = userFacingError(error)
            integration.state = errorStatePolicy.state(for: error)
            integration.lastErrorMessage =
                presentedError.localizedDescription
            if company.lastSynchronizedAt != nil {
                company.isStale = true
            }
            try save(context)
            throw presentedError
        }
    }

    private func registryIntegration(
        companyID: UUID,
        integrations: [IntegrationRecord],
        context: ModelContext
    ) -> IntegrationRecord {
        if let existing = integrations.first(where: {
            $0.companyID == companyID
                && $0.providerIdentifier == "bolagsverket"
        }) {
            return existing
        }
        let record = IntegrationRecord(
            companyID: companyID,
            providerIdentifier: "bolagsverket",
            displayName: "Bolagsverket",
            state: .disconnected
        )
        context.insert(record)
        return record
    }

    private func save(_ context: ModelContext) throws {
        do {
            try context.save()
        } catch {
            context.rollback()
            throw CompanyRegistryRefreshError.persistence
        }
    }

    private func userFacingError(_ error: Error) -> any Error {
        switch error {
        case is IntegrationAdapterError,
             is APIClientError,
             is CompanyRegistryRefreshError,
             is OrganisationNumber.ValidationError:
            error
        default:
            CompanyRegistryRefreshError.providerFailure
        }
    }
}
