import SwiftUI

@MainActor public final class ApolloOnboardingSession: ObservableObject {
    @Published public private(set) var progress: ApolloOnboardingProgress
    @Published public private(set) var storageError: String?
    @Published public private(set) var isSaving = false
    private let persistence: ApolloOnboardingPersistence
    public var isComplete: Bool { progress.isComplete }
    public init(defaults: UserDefaults = .standard, storageKey: String = ApolloOnboardingPersistence.defaultKey) {
        persistence = .init(defaults: defaults, storageKey: storageKey)
        progress = persistence.load()
    }
    public func choose(_ choice: ApolloOnboardingRiskChoice) { guard !isSaving else { return }; mutate { $0.choose(choice) } }
    public func next() { guard !isSaving else { return }; mutate { $0.next() } }
    public func back() { guard !isSaving else { return }; mutate { $0.back() } }
    public func resetQuiz() { guard !isSaving else { return }; mutate { $0.resetQuiz() } }
    /// An explicit Finish action must reach authoritative persistence before local completion.
    public func finish(saveProfile: ApolloOnboardingSaveProfile) async throws {
        guard !isSaving, progress.step == .review, let choice = progress.draftChoice else {
            throw CompletionError.notReady
        }
        isSaving = true; defer { isSaving = false }
        try await saveProfile(choice)
        guard mutate({ $0.markComplete() }) else { throw CompletionError.persistence }
    }
    private enum CompletionError: Error { case notReady, persistence }
    @discardableResult private func mutate(_ action: (inout ApolloOnboardingProgress) -> Void) -> Bool {
        var updated = progress
        action(&updated)
        do { try persistence.save(updated); progress = updated; storageError = nil; return true }
        catch { storageError = "Quiz progress couldn’t be saved. Please try again."; return false }
    }
}
