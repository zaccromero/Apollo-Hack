import Foundation

/// UI choices only. Map rawValue to the active Game adapter's risk tolerance.
/// These values do not authorize an order or replace the saved paper profile.
public enum ApolloOnboardingRiskChoice: String, Codable, CaseIterable, Identifiable, Sendable {
    case conservative, balanced, adventurous
    public var id: String { rawValue }
    public var title: String { rawValue.capitalized }
    public var ceiling: Int {
        switch self { case .conservative: return 2; case .balanced: return 3; case .adventurous: return 5 }
    }
    public var explanation: String {
        switch self {
        case .conservative: return "Start with lower-risk practice. Explore diversification and evidence."
        case .balanced: return "Explore a wider mix with a moderate educational risk ceiling."
        case .adventurous: return "Explore complex exposures. Higher risk can mean larger losses."
        }
    }
}

public enum ApolloOnboardingPaperMode: String, Sendable {
    case demo, connected
    public var title: String { self == .demo ? "DEMO · Paper practice" : "CONNECTED · Paper practice" }
}

public enum ApolloOnboardingAppearance: String, Sendable { case light, midnight }

public struct ApolloOnboardingContext: Sendable {
    public let appearance: ApolloOnboardingAppearance
    public let mode: ApolloOnboardingPaperMode
    public let dataFreshness: String
    public let privacyDescription: String
    public let appVersion: String
    public init(mode: ApolloOnboardingPaperMode, dataFreshness: String,
                privacyDescription: String, appVersion: String = "Demo build",
                appearance: ApolloOnboardingAppearance = .light) {
        self.appearance = appearance
        self.mode = mode; self.dataFreshness = dataFreshness
        self.privacyDescription = privacyDescription; self.appVersion = appVersion
    }
}

public typealias ApolloOnboardingLoadProfile = @MainActor () async throws -> ApolloOnboardingRiskChoice?
/// Return only after the active Game/Paper authority has confirmed and persisted the choice.
public typealias ApolloOnboardingSaveProfile = @MainActor (ApolloOnboardingRiskChoice) async throws -> Void
