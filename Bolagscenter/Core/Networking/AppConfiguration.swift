import Foundation

enum DeploymentEnvironment: String, Codable, Sendable {
    case development
    case staging
    case production
}

struct BackendConfiguration: Sendable {
    let environment: DeploymentEnvironment
    let baseURL: URL
}

enum AppConfiguration {
    static func backend(bundle: Bundle = .main) -> BackendConfiguration? {
        guard let environmentValue = bundle.object(
            forInfoDictionaryKey: "BackendEnvironment"
        ) as? String,
              let environment = DeploymentEnvironment(rawValue: environmentValue),
              let baseURLValue = bundle.object(
                forInfoDictionaryKey: "BackendBaseURL"
              ) as? String,
              !baseURLValue.contains("$("),
              let baseURL = URL(string: baseURLValue),
              baseURL.scheme == "https" else {
            return nil
        }
        return BackendConfiguration(environment: environment, baseURL: baseURL)
    }
}
