import Foundation

/// One-time, owner-authorized app-local carryover. Original development bytes are never edited.
/// A flushed journal permits completing an interrupted copy before any account service is opened.
enum ApolloStagingCarryover {
    static let sourcePaper = "apollo.game.demo.v1"
    static let destinationPaper = "apollo.stage.fixture.v1"
    static let journalKey = "apollo.stage.owner-carryover.v1"
    static let keys = [
        sourcePaper: destinationPaper,
        "apollo.demo.onboarding.v1": "apollo.stage.fixture.v1.onboarding.v1",
        "apollo.demo.discovery.v1": "apollo.stage.fixture.v1.discovery.v1"
    ]
    enum Failure: LocalizedError {
        case unsafe(String)
        var errorDescription: String? { switch self { case .unsafe(let message): return message } }
    }
    static func prepare(defaults: UserDefaults = .standard, validateSupplement: (String, Data) throws -> Void = { _, data in _ = try JSONSerialization.jsonObject(with: data) }, validateAccount: (Data) throws -> Void) throws {
        if let journal = defaults.dictionary(forKey: journalKey) {
            guard journal["version"] as? Int == 1 else { throw Failure.unsafe("The saved portfolio carryover record is unsupported. Both accounts remain saved.") }
            if journal["complete"] as? Bool == true {
                guard let backup = journal["snapshots"] as? [String: Data], backup[sourcePaper] != nil else { throw Failure.unsafe("The completed carryover backup is unreadable. No account was opened.") }
                guard let current = defaults.data(forKey: destinationPaper) else {
                    throw Failure.unsafe("The saved release portfolio is missing or unreadable. Your original account and backup remain saved.")
                }
                try validateAccount(current)
                for (source, target) in keys where source != sourcePaper {
                    if backup[source] != nil && defaults.object(forKey: target) == nil { throw Failure.unsafe("Saved release onboarding or preferences are missing. Your backup remains saved.") }
                    if let object = defaults.object(forKey: target) {
                        guard let data = object as? Data else { throw Failure.unsafe("Saved release onboarding or preferences are unreadable.") }
                        try validateSupplement(source, data)
                    }
                }
                return
            }
            guard let snapshots = journal["snapshots"] as? [String: Data], let paper = snapshots[sourcePaper] else {
                throw Failure.unsafe("The portfolio carryover record could not be read. No account was opened.")
            }
            try validateAccount(paper)
            for (source, data) in snapshots where source != sourcePaper { try validateSupplement(source, data) }
            try finish(snapshots, defaults: defaults)
            return
        }
        guard let paper = defaults.data(forKey: sourcePaper) else {
            guard defaults.object(forKey: sourcePaper) == nil else { throw Failure.unsafe("The original saved portfolio has an unsupported format. It was not replaced.") }
            return
        }
        try validateAccount(paper)
        var snapshots: [String: Data] = [sourcePaper: paper]
        for source in keys.keys where source != sourcePaper {
            if let object = defaults.object(forKey: source) {
                guard let data = object as? Data else { throw Failure.unsafe("Saved onboarding or preferences have an unsupported format. They were not replaced.") }
                try validateSupplement(source, data)
                snapshots[source] = data
            }
        }
        guard keys.values.allSatisfy({ defaults.object(forKey: $0) == nil }) else {
            throw Failure.unsafe("Two saved practice accounts exist. Neither was overwritten. Portfolio carryover needs a deliberate account choice.")
        }
        defaults.set(["version": 1, "complete": false, "snapshots": snapshots] as [String: Any], forKey: journalKey)
        guard defaults.synchronize() else { throw Failure.unsafe("The portfolio backup could not be saved. Your original account is unchanged.") }
        try finish(snapshots, defaults: defaults)
    }
    private static func finish(_ snapshots: [String: Data], defaults: UserDefaults) throws {
        guard snapshots.keys.allSatisfy({ keys[$0] != nil }) else { throw Failure.unsafe("The portfolio carryover contains unknown storage keys.") }
        for (source, target) in keys {
            if let existing = defaults.object(forKey: target) {
                guard let expected = snapshots[source], let data = existing as? Data, data == expected else {
                    throw Failure.unsafe("A saved release account differs from the pending carryover. Neither account was replaced.")
                }
            }
        }
        for (source, data) in snapshots { defaults.set(data, forKey: keys[source]!) }
        guard defaults.synchronize(), snapshots.allSatisfy({ defaults.data(forKey: keys[$0.key]!) == $0.value }) else {
            throw Failure.unsafe("Portfolio carryover is incomplete. The preserved backup will be checked on reopening.")
        }
        defaults.set(["version": 1, "complete": true, "snapshots": snapshots] as [String: Any], forKey: journalKey)
        guard defaults.synchronize() else { throw Failure.unsafe("Portfolio carryover could not be finalized. Your original account remains saved.") }
    }
}
