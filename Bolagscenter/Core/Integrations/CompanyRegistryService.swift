import Foundation

struct RegisteredCompany: Sendable {
    let organisationNumber: OrganisationNumber
    let registeredName: String
    let status: CompanyStatus
    let registeredOffice: String?
    let sourceName: String
    let sourceUpdatedAt: Date
}

protocol CompanyRegistryService: Sendable {
    func searchCompany(
        organisationNumber: OrganisationNumber
    ) async throws -> RegisteredCompany

    func fetchCompanyDetails(
        organisationNumber: OrganisationNumber
    ) async throws -> RegisteredCompany
}

enum IntegrationAdapterError: LocalizedError, Equatable, Sendable {
    case notConfigured(provider: String)
    case unauthorized(provider: String)
    case unavailable(provider: String)
    case staleData(provider: String)

    var errorDescription: String? {
        switch self {
        case .notConfigured(let provider):
            "\(provider) är inte konfigurerad. Lägg till en behörig API-anslutning i rätt miljö."
        case .unauthorized(let provider):
            "Behörigheten till \(provider) saknas eller har gått ut."
        case .unavailable(let provider):
            "\(provider) är tillfälligt otillgänglig."
        case .staleData(let provider):
            "Senast hämtade data från \(provider) är inaktuella."
        }
    }
}

struct UnavailableCompanyRegistryService: CompanyRegistryService {
    let providerName: String

    func searchCompany(
        organisationNumber: OrganisationNumber
    ) async throws -> RegisteredCompany {
        throw IntegrationAdapterError.notConfigured(provider: providerName)
    }

    func fetchCompanyDetails(
        organisationNumber: OrganisationNumber
    ) async throws -> RegisteredCompany {
        throw IntegrationAdapterError.notConfigured(provider: providerName)
    }
}

struct BackendCompanyRegistryService: CompanyRegistryService {
    private let client: HTTPClient

    init(client: HTTPClient) {
        self.client = client
    }

    func searchCompany(
        organisationNumber: OrganisationNumber
    ) async throws -> RegisteredCompany {
        let dto: RegisteredCompanyDTO = try await client.send(
            APIRequest(
                path: "/v1/companies/\(organisationNumber.digits)",
                cachePolicy: .revalidateWithETag,
                requiresAuthentication: false
            )
        )
        return try dto.domainValue()
    }

    func fetchCompanyDetails(
        organisationNumber: OrganisationNumber
    ) async throws -> RegisteredCompany {
        try await searchCompany(organisationNumber: organisationNumber)
    }
}

private struct RegisteredCompanyDTO: Decodable, Sendable {
    let organisationNumber: String
    let registeredName: String
    let status: String
    let registeredOffice: String?
    let sourceName: String
    let sourceUpdatedAt: Date

    func domainValue() throws -> RegisteredCompany {
        RegisteredCompany(
            organisationNumber: try OrganisationNumber(organisationNumber),
            registeredName: registeredName,
            status: CompanyStatus(rawValue: status) ?? .unknown,
            registeredOffice: registeredOffice,
            sourceName: sourceName,
            sourceUpdatedAt: sourceUpdatedAt
        )
    }
}
