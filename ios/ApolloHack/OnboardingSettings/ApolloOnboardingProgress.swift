import Foundation

/// The sole local quiz record. A draft choice is never an authoritative trading profile.
public struct ApolloOnboardingProgress: Codable, Equatable, Sendable {
    public enum Step: Int, Codable, CaseIterable, Sendable { case introduction, riskChoice, review }
    public private(set) var step: Step = .introduction
    public private(set) var draftChoice: ApolloOnboardingRiskChoice?
    public private(set) var completedAt: Date?
    public var isComplete: Bool { completedAt != nil }
    public init() {}
    public mutating func choose(_ choice: ApolloOnboardingRiskChoice) { draftChoice = choice }
    public mutating func next() {
        switch step {
        case .introduction: step = .riskChoice
        case .riskChoice: if draftChoice != nil { step = .review }
        case .review: break
        }
    }
    public mutating func back() {
        switch step { case .introduction: break; case .riskChoice: step = .introduction; case .review: step = .riskChoice }
    }
    /// Caller must first await the injected authoritative save from an explicit Finish action.
    mutating func markComplete(at date: Date = Date()) { completedAt = date; draftChoice = nil; step = .introduction }
    public mutating func resetQuiz() { self = Self() }
}

/// Operates on exactly one storage key. Never clears a domain or touches Game storage.
public struct ApolloOnboardingPersistence {
    public static let defaultKey = "apollo.onboarding.v1"
    private let defaults: UserDefaults
    private let key: String
    public init(defaults: UserDefaults = .standard, storageKey: String = Self.defaultKey) {
        self.defaults = defaults; self.key = storageKey
    }
    public func load() -> ApolloOnboardingProgress {
        guard let data = defaults.data(forKey: key), let progress = try? JSONDecoder().decode(ApolloOnboardingProgress.self, from: data) else { return .init() }
        return progress
    }
    public func save(_ progress: ApolloOnboardingProgress) throws {
        defaults.set(try JSONEncoder().encode(progress), forKey: key)
    }
}
