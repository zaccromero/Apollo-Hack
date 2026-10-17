import Foundation

public enum ApolloAppEnvironment: String { case dev, staging, prod }

/// Resolves build metadata before service/storage construction. No IO or network effects.
public struct ApolloRuntimeConfiguration {
    public let environment: ApolloAppEnvironment
    public let paperStorageKey: String
    public let stateNamespace: String
    public let backendURL: URL?
    public let initialComparison: Bool
    public let diagnosticsEnabled: Bool

    public enum ConfigurationError: Error, LocalizedError {
        case blocked(String)
        public var errorDescription: String? {switch self {case .blocked(let text): return text}}
    }

    /// Caller supplies compiled #if DEBUG and built Info.plist metadata, never runtime substitutes.
    public static func resolve(declaredEnvironment: String?, isDebugBuild: Bool, arguments: [String]) throws -> ApolloRuntimeConfiguration {
        func block(_ message: String) throws -> Never {throw ConfigurationError.blocked(message)}
        let environment: ApolloAppEnvironment
        if let declaredEnvironment {
            guard let value=ApolloAppEnvironment(rawValue: declaredEnvironment) else {
                try block("This build has an unknown environment. No account or service was opened.")
            }
            environment=value
        } else if isDebugBuild {environment = .dev}
        else {try block("This Release build has no environment configuration. No account or service was opened.")}
        guard environment != .prod else {try block("Production is disabled. No account or service was opened.")}
        guard isDebugBuild || environment == .staging else {try block("Release builds must explicitly select staging. Development data was not opened.")}
        guard !arguments.contains(where: {$0.hasPrefix("--apollo-env") || $0.hasPrefix("--environment")}) else {
            try block("Runtime environment overrides are disabled.")
        }
        if environment == .staging {
            guard !arguments.contains(where: {$0.hasPrefix("--apollo-") || $0.hasPrefix("--provider-diagnostics")}) else {
                try block("Staging uses isolated fixtures. Backend, storage, comparison and diagnostics overrides are disabled.")
            }
            return .init(environment: .staging,paperStorageKey: "apollo.stage.fixture.v1",stateNamespace: "apollo.stage.fixture.v1",backendURL: nil,initialComparison: false,diagnosticsEnabled: false)
        }
        let backendOptions=arguments.filter {$0.hasPrefix("--apollo-backend-url")}
        let storageOptions=arguments.filter {$0.hasPrefix("--apollo-test-storage")}
        guard backendOptions.count <= 1 && storageOptions.count <= 1 else {try block("Duplicate backend or storage overrides are invalid.")}
        var backend: URL?
        if let option=backendOptions.first {
            let prefix="--apollo-backend-url="
            guard option.hasPrefix(prefix) else {try block("The development backend override is malformed.")}
            let raw=String(option.dropFirst(prefix.count))
            guard let parts=URLComponents(string: raw),["http","https"].contains(parts.scheme ?? ""),let host=parts.host,
                  ["127.0.0.1","localhost","::1","[::1]"].contains(host),let port=parts.port,[8767,8769].contains(port),
                  parts.user == nil,parts.password == nil,parts.query == nil,parts.fragment == nil,(parts.percentEncodedPath.isEmpty || parts.percentEncodedPath == "/"),
                  let url=parts.url else {
                try block("The development backend must be an explicitly allowed loopback service. No demo account was substituted.")
            }
            backend=url
        }
        var paperKey="apollo.game.demo.v1"
        var namespace=backend == nil ? "apollo.demo" : "apollo.connected"
        if let option=storageOptions.first {
            let prefix="--apollo-test-storage="
            guard option.hasPrefix(prefix) else {try block("The test storage override is malformed.")}
            let key=String(option.dropFirst(prefix.count))
            guard !key.isEmpty,key.utf8.count <= 100,key.utf8.allSatisfy({(48...57).contains($0) || (65...90).contains($0) || (97...122).contains($0) || [45,46,95].contains($0)}) else {
                try block("The test storage identifier is invalid.")
            }
            paperKey="apollo.game.test."+key
            // Preserve the previous root's raw test namespace; never migrate a saved account.
            namespace=option
        }
        return .init(environment: .dev,paperStorageKey: paperKey,stateNamespace: namespace,backendURL: backend,
                     initialComparison: arguments.contains("--apollo-owner-comparison"),diagnosticsEnabled: arguments.contains("--provider-diagnostics"))
    }
}
