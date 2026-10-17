import Foundation

public enum ApolloSocialResearchStatus: String, Codable {
    case unavailable, needsReview = "needs_review", noInvestment = "no_identifiable_investment", candidates
}
public enum ApolloSocialCandidateStatus: String, Codable { case needsReview = "needs_review", eligible, rejected }
public struct ApolloSocialEvidenceSegment: Codable, Identifiable {
    public let id: String
    public let text: String
    public let locator: String
    public var mediaTimestamp: String? = nil
    public init(id: String, text: String, locator: String, mediaTimestamp: String? = nil) { self.id = id; self.text = text; self.locator = locator; self.mediaTimestamp = mediaTimestamp }
}
public struct ApolloSocialClaim: Codable, Identifiable {
    public let id: String
    public let text: String
    public let evidenceSegmentIDs: [String]
    public let verification: String
    public var finding: String? = nil
    public var sources: [ApolloSource]? = nil
    public init(id: String, text: String, evidenceSegmentIDs: [String], verification: String, finding: String? = nil, sources: [ApolloSource]? = nil) { self.id = id; self.text = text; self.evidenceSegmentIDs = evidenceSegmentIDs; self.verification = verification; self.finding = finding; self.sources = sources }
}
public struct ApolloSocialCandidate: Codable, Identifiable {
    public let id: String
    public let literalMention: String
    public let resolvedAssetID: String?
    public let status: ApolloSocialCandidateStatus
    public let reasoning: String
    public let independentSources: [ApolloSource]
    public let limitations: [String]
    public init(id: String, literalMention: String, resolvedAssetID: String?, status: ApolloSocialCandidateStatus, reasoning: String, independentSources: [ApolloSource], limitations: [String]) { self.id = id; self.literalMention = literalMention; self.resolvedAssetID = resolvedAssetID; self.status = status; self.reasoning = reasoning; self.independentSources = independentSources; self.limitations = limitations }
    public func canRequestAdmission(catalog: [ApolloAsset]) -> Bool {
        status == .eligible && independentSources.contains { source in
            guard let url = URL(string: source.url) else { return false }; return url.scheme?.lowercased() == "https" && url.host != nil
        } && resolvedAssetID.map { id in catalog.contains { $0.id == id } } == true
    }
}
public struct ApolloSocialResearchReceipt: Codable {
    public let id: String
    public let originURL: String
    public let status: ApolloSocialResearchStatus
    public let accessScope: String
    public let retrievedAt: String?
    public let publishedAt: String?
    public let notice: String
    public let evidenceSegments: [ApolloSocialEvidenceSegment]
    public let claims: [ApolloSocialClaim]
    public let candidates: [ApolloSocialCandidate]
    public let limitations: [String]
    public let networkAttempted: Bool
    public let providerCalls: Int
    public var mode: String? = nil
    public var freshFetch: Bool? = nil
    public var publishedDateKind: String? = nil
    public init(id: String, originURL: String, status: ApolloSocialResearchStatus, accessScope: String, retrievedAt: String?, publishedAt: String?, notice: String, evidenceSegments: [ApolloSocialEvidenceSegment], claims: [ApolloSocialClaim], candidates: [ApolloSocialCandidate], limitations: [String], networkAttempted: Bool, providerCalls: Int) { self.id = id; self.originURL = originURL; self.status = status; self.accessScope = accessScope; self.retrievedAt = retrievedAt; self.publishedAt = publishedAt; self.notice = notice; self.evidenceSegments = evidenceSegments; self.claims = claims; self.candidates = candidates; self.limitations = limitations; self.networkAttempted = networkAttempted; self.providerCalls = providerCalls }
    public static func unavailable(url: String) -> Self {
        .init(id: UUID().uuidString, originURL: url, status: .unavailable, accessScope: "unavailable", retrievedAt: nil, publishedAt: nil, notice: "Instagram research intake is not connected in this build. No post was fetched, no transcript was created and no investment was admitted.", evidenceSegments: [], claims: [], candidates: [], limitations: ["Public captions, comments and video are different evidence scopes. Unavailable video cannot be treated as analyzed."], networkAttempted: false, providerCalls: 0)
    }
}
public struct ApolloSocialAdmission: Codable {
    public let candidateID: String
    public let assetID: String?
    public let admitted: Bool
    public let mutatesAccount: Bool
    public let createsOrder: Bool
    public let notice: String
    public init(candidateID: String, assetID: String?, admitted: Bool, mutatesAccount: Bool, createsOrder: Bool, notice: String) { self.candidateID = candidateID; self.assetID = assetID; self.admitted = admitted; self.mutatesAccount = mutatesAccount; self.createsOrder = createsOrder; self.notice = notice }
}
public enum ApolloSocialResearchInput {
    public static func canonicalURL(_ input: String) -> String? {
        guard var components = URLComponents(string: input.trimmingCharacters(in: .whitespacesAndNewlines)), components.scheme?.lowercased() == "https", let host = components.host?.lowercased(), ["instagram.com", "www.instagram.com"].contains(host), components.user == nil, components.password == nil, components.port == nil else { return nil }
        let pieces = components.path.split(separator: "/")
        guard pieces.count == 2, ["p", "reel"].contains(String(pieces[0])), !pieces[1].isEmpty else { return nil }
        guard (5...40).contains(pieces[1].count), pieces[1].unicodeScalars.allSatisfy({ CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-").contains($0) }) else { return nil }
        components.scheme = "https"; components.host = "www.instagram.com"; components.path = "/p/\(pieces[1])/"; components.query = nil; components.fragment = nil
        return components.url?.absoluteString
    }
}
