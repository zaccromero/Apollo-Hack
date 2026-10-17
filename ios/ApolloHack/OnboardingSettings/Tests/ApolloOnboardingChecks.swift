#if APOLLO_ONBOARDING_CHECKS
import Foundation

@main struct OnboardingChecks {
    @MainActor static func main() async throws {
        if CommandLine.arguments.count == 3 {
            let phase = CommandLine.arguments[1]
            let processDefaults = UserDefaults(suiteName: CommandLine.arguments[2])!
            let session = ApolloOnboardingSession(defaults: processDefaults, storageKey: "quiz")
            if phase == "--process-seed" {
                session.next(); session.choose(.conservative); session.next()
                processDefaults.set("paper-preserved", forKey: "game-state")
                processDefaults.synchronize()
                print("PASS: seeded persisted review draft")
            } else if phase == "--process-verify" {
                precondition(session.progress.step == .review && session.progress.draftChoice == .conservative)
                precondition(!session.isComplete && processDefaults.string(forKey: "game-state") == "paper-preserved")
                session.resetQuiz()
                precondition(processDefaults.string(forKey: "game-state") == "paper-preserved")
                processDefaults.removeObject(forKey: "quiz"); processDefaults.removeObject(forKey: "game-state")
                print("PASS: separate process restored review draft and preserved game state")
            } else { fatalError("unknown test phase") }
            return
        }
        let suite = "apollo.onboarding.tests.\(ProcessInfo.processInfo.processIdentifier)"
        let defaults = UserDefaults(suiteName: suite)!
        let key = "quiz"
        defaults.set("preserved-profile-and-holdings", forKey: "game-state")
        defer { defaults.removeObject(forKey: key); defaults.removeObject(forKey: "game-state") }
        var checks: [String] = []
        func check(_ condition: @autoclosure () -> Bool, _ name: String) {
            guard condition() else { fatalError("FAIL: \(name)") }; checks.append(name)
        }
        let first = ApolloOnboardingSession(defaults: defaults, storageKey: key)
        check(!first.isComplete && first.progress.draftChoice == nil, "fresh session has no assigned risk")
        first.next(); first.next()
        check(first.progress.step == .riskChoice, "cannot advance without explicit choice")
        first.choose(.adventurous); first.next(); first.back()
        check(first.progress.step == .riskChoice && first.progress.draftChoice == .adventurous, "back preserves chosen draft")
        let resumed = ApolloOnboardingSession(defaults: defaults, storageKey: key)
        check(resumed.progress.step == .riskChoice && resumed.progress.draftChoice == .adventurous, "new session restores step and draft")
        enum Failure: Error { case rejected }
        resumed.next()
        do { try await resumed.finish { _ in throw Failure.rejected }; fatalError("expected failure") } catch {}
        check(!resumed.isComplete && resumed.progress.step == .review && !resumed.isSaving, "failed authoritative save never completes quiz")
        check(ApolloOnboardingSession(defaults: defaults, storageKey: key).progress.draftChoice == .adventurous, "save failure preserves durable draft")
        var calls = 0
        let finish = Task { @MainActor in
            try await resumed.finish { choice in
                check(choice == .adventurous, "finish sends explicitly selected value")
                calls += 1
                try await Task.sleep(nanoseconds: 30_000_000)
            }
        }
        await Task.yield()
        check(resumed.isSaving, "saving is observable")
        resumed.choose(.conservative); resumed.back(); resumed.resetQuiz()
        check(resumed.progress.draftChoice == .adventurous && resumed.progress.step == .review, "in-flight finish blocks draft/reset/back mutations")
        do { try await resumed.finish { _ in calls += 1 }; fatalError("duplicate finish allowed") } catch {}
        try await finish.value
        check(calls == 1 && resumed.isComplete, "duplicate finish does not dispatch another save")
        let finished = ApolloOnboardingSession(defaults: defaults, storageKey: key)
        check(finished.isComplete && finished.progress.draftChoice == nil, "reopen skips completed quiz without storing a shadow profile")
        finished.resetQuiz()
        check(!finished.isComplete && finished.progress.step == .introduction && finished.progress.draftChoice == nil, "quiz reset clears quiz only")
        check(defaults.string(forKey: "game-state") == "preserved-profile-and-holdings", "portfolio and profile storage preserved")
        defaults.set(Data("corrupt".utf8), forKey: key)
        check(ApolloOnboardingSession(defaults: defaults, storageKey: key).progress == ApolloOnboardingProgress(), "corrupt quiz recovers without touching game data")
        check(ApolloOnboardingRiskChoice.allCases.map(\.rawValue) == ["conservative", "balanced", "adventurous"], "adapter choice values match existing contract")
        check(ApolloOnboardingRiskChoice.allCases.map(\.ceiling) == [2,3,5], "educational ceilings match existing game rubric")
        let result: [String: Any] = ["status": "PASS", "checks": checks, "count": checks.count, "scope": "isolated session persistence and explicit async save; not native UI or adapter acceptance"]
        print(String(data: try JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys]), encoding: .utf8)!)
    }
}

#endif
