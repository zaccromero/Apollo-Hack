import Foundation

public enum ApolloChallengeStatus: String, Codable {
    case paused, corpusMismatch = "corpus_mismatch", unavailable, success
}
public struct ApolloChallengeContext: Codable {
    public let mode: String
    public let corpusHash: String?
    public let cutoff: String?
    public let label: String
    public static let assignedHistorical = ApolloChallengeContext(mode: "assigned_historical", corpusHash: "a12ef01ad7a58511db770f0f78ca75417747058d62034c0a931eea5ae984a569", cutoff: "2026-10-17", label: "Assigned Winmark source notes · historical corpus; current research remains separate.")
}
public struct ApolloChallengeProvider: Codable, Identifiable {
    public var id: String { name }
    public let name: String
    public let status: String
    public var proofKind: String? = nil
    public var requestedModel: String? = nil
    public var actualModel: String? = nil
    public var networkAttempted: Bool? = nil
    public var liveVerified: Bool? = nil
    public var localCorrelationID: String? = nil
    public var publishedTraceID: String? = nil
}
public struct ApolloChallengeEvidence: Codable, Identifiable {
    public var id: String { sourceID + "|" + quote + "|" + interpretation }
    public let sourceID: String
    public let quote: String
    public let interpretation: String
}
public struct ApolloChallengeGroup: Codable, Identifiable {
    public let id: String
    public let status: String
    public let items: [ApolloChallengeEvidence]
}
public struct ApolloChallengeSource: Codable, Identifiable {
    public var id: String { sourceID }
    public let sourceID: String
    public let assetID: String
    public let title: String
    public let url: String
    public let date: String
    public let dateKind: String
    public var text: String = ""
}
public struct ApolloChallengeProcessStep: Codable, Identifiable {
    public let id: String
    public let title: String
    public let status: String
    public var detail: String = ""
    public var inputSummary: String? = nil
    public var outputSummary: String? = nil
    public var sourceIDs: [String] = []
    public var timestamp: String? = nil
    public var durationMilliseconds: Double? = nil
}
public struct ApolloThesisChallenge: Codable {
    public let requestID: String
    public let assetID: String
    public let status: ApolloChallengeStatus
    public let reason: String
    public let notice: String
    public let context: ApolloChallengeContext
    public var providers: [ApolloChallengeProvider] = []
    public var processSteps: [ApolloChallengeProcessStep] = []
    public var savedEvidenceNotice: String? = nil
    public var groups: [ApolloChallengeGroup] = []
    public var sources: [ApolloChallengeSource] = []
    public var generatedAnalysis: Bool = true
    public var semanticGroundingVerified: Bool = false
    public var sponsorAcceptance: Bool = false
    public var isOfflineInjected: Bool { providers.contains { $0.proofKind == "offline_injected_transport" } }
    public var canonicalTracks: [ApolloChallengeGroup] {
        ["leadership", "promises_results", "public_sentiment"].map { key in
            groups.first { $0.id == key } ?? ApolloChallengeGroup(id: key, status: "unknown", items: [])
        }
    }
}
public extension ApolloThesis {
    /// Matches the provider contract's sorted compact Unicode JSON query. Server remains hash authority.
    var canonicalWireValue: String? {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return (try? encoder.encode(self)).flatMap { String(data: $0, encoding: .utf8) }
    }
    var isChallengeReady: Bool {
        guard isComplete, [reason, risk, invalidation].allSatisfy({ $0.unicodeScalars.count <= 800 }), let canonicalWireValue else { return false }
        return canonicalWireValue.unicodeScalars.count <= 2400
    }
}
