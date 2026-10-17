import Foundation

public enum ApolloAssetKind: String, Codable, CaseIterable, Identifiable {
    case stock, etf, commodity, crypto, stablecoin, bond, realEstate = "real_estate", option, strategy
    public var id: String { rawValue }
    public var label: String {
        switch self { case .stock: return "Stocks"; case .etf: return "ETFs"; case .commodity: return "Commodities"; case .crypto: return "Crypto"; case .stablecoin: return "Stablecoins"; case .bond: return "Bonds"; case .realEstate: return "Real estate"; case .option: return "Options"; case .strategy: return "People & strategies" }
    }
    public var symbol: String {
        switch self { case .stock: return "building.2"; case .etf: return "square.stack.3d.up"; case .commodity: return "circle.hexagongrid"; case .crypto: return "bitcoinsign.circle"; case .stablecoin: return "dollarsign.circle"; case .bond: return "doc.text"; case .realEstate: return "house"; case .option: return "function"; case .strategy: return "person.crop.circle" }
    }
}
public struct ApolloSource: Codable, Identifiable, Hashable {
    public var id: String { if let sourceID, !sourceID.isEmpty { return sourceID }; return url + "|" + title }
    public let title: String
    public let url: String
    public var sourceID: String? = nil
    public init(title: String, url: String, sourceID: String? = nil) { self.title = title; self.url = url; self.sourceID = sourceID }
}
public struct ApolloAllocation: Codable, Hashable {
    public let assetID: String
    public let weight: Decimal
    public init(assetID: String, weight: Decimal) { self.assetID = assetID; self.weight = weight }
}
public struct ApolloEvidenceTrack: Codable, Identifiable, Hashable {
    public var id: String { topic }
    public let topic: String
    public let status: String
    public let summary: String
    public let sources: [ApolloSource]
    public var reasoning: ApolloEvidenceReasoning? = nil
    public init(topic: String, status: String, summary: String, sources: [ApolloSource] = [], reasoning: ApolloEvidenceReasoning? = nil) { self.topic = topic; self.status = status; self.summary = summary; self.sources = sources; self.reasoning = reasoning }
}
public struct ApolloThesis: Codable {
    public var reason: String
    public var risk: String
    public var invalidation: String
    public init(reason: String, risk: String, invalidation: String) { self.reason = reason; self.risk = risk; self.invalidation = invalidation }
    public var wireValue: String { String(data: (try? JSONEncoder().encode(self)) ?? Data(), encoding: .utf8) ?? "" }
    public var isComplete: Bool { [reason, risk, invalidation].allSatisfy { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } }
    public static func display(_ value: String) -> String {
        guard let data = value.data(using: .utf8), let thesis = try? JSONDecoder().decode(Self.self, from: data) else { return value }
        return "Reason: \(thesis.reason)\nRisk: \(thesis.risk)\nRevisit if: \(thesis.invalidation)"
    }
}
public struct ApolloAsset: Codable, Identifiable, Hashable {
    public let id: String
    public let ticker: String
    public let name: String
    public let kind: ApolloAssetKind
    public let headline: String
    public let summary: String
    public let price: Decimal
    public let priceLabel: String
    public let changeLabel: String
    public let chart: [Double]
    public let bullCase: String
    public let bearCase: String
    public let catalyst: String
    public let lesson: String
    public let risk: String
    public let sources: [ApolloSource]
    public var isDemo: Bool = true
    public var multiplier: Int = 1
    public var expiry: String? = nil
    public var allocations: [ApolloAllocation] = []
    public var quoteAsOf: String? = nil
    public var quoteStale: Bool = true
    public var quoteProvenance: String = "Educational demo fixture; no live market quote"
    public var evidenceTracks: [ApolloEvidenceTrack] = []
    public var researchCorpusHash: String? = nil
    public var researchEvidenceCutoff: String? = nil
    public var quantityUnit: String? = nil
    public var quantityStep: Decimal? = nil
    public var companyProfile: ApolloCompanyProfile? = nil
    public var optionTerms: ApolloOptionTerms? = nil
    public var stablecoin: ApolloStablecoinTerms? = nil
    public var bond: ApolloBondTerms? = nil
    public var unit: String { quantityUnit ?? (kind == .option ? "contracts" : kind == .bond ? "bonds" : kind == .stablecoin ? "tokens" : "units") }
}
public enum ApolloDecision: String, Codable { case pass, watchlist, interest, removeWatchlist = "remove_watchlist" }
public struct ApolloDecisionRecord: Codable, Identifiable {
    public let id: UUID
    public let assetID: String
    public let action: ApolloDecision
    public let thesis: String
    public let date: Date
}
public struct ApolloPosition: Codable, Identifiable {
    public var id: String { assetID }
    public let assetID: String
    public var quantity: Decimal
    public var cost: Decimal
    public let multiplier: Int
    public var marketValue: Decimal? = nil
    public var valuationPrice: Decimal? = nil
    public var valuationProvenance: String? = nil
}
public struct ApolloFill: Codable, Identifiable {
    public let id: String
    public let assetID: String
    public let quantity: Decimal
    public let cost: Decimal
    public let thesis: String
    public let date: Date
}
public struct ApolloAccount: Codable {
    public var cash: Decimal
    public var positions: [ApolloPosition]
    public var decisions: [ApolloDecisionRecord]
    public var fills: [ApolloFill]
    public var riskProfile: ApolloRiskProfile? = nil
    public var analytics: ApolloPortfolioAnalytics? = nil
    public static let empty = ApolloAccount(cash: 10_000, positions: [], decisions: [], fills: [])
    public var watchlistIDs: Set<String> {
        var result: Set<String> = []
        for decision in decisions { if decision.action == .watchlist { result.insert(decision.assetID) }; if decision.action == .removeWatchlist { result.remove(decision.assetID) } }
        return result
    }
}
public struct ApolloOrderLine: Codable, Identifiable {
    public var id: String { assetID }
    public let assetID: String
    public let quantity: Decimal
    public let price: Decimal
    public let multiplier: Int
    public var cost: Decimal { quantity * price * Decimal(multiplier) }
}
public struct ApolloOrderPreview: Codable, Identifiable {
    public let id: String
    public let assetID: String
    public let lines: [ApolloOrderLine]
    public let total: Decimal
    public let thesis: String
    public let expiresAt: Date
    public var quoteProvenance: String = "Demo fixture execution; no live quote"
    public var warnings: [String] = ["Simulated money only. No real broker order is placed."]
    public var riskCheck: ApolloRiskCheck? = nil
    public var mixedExceptionAcknowledged: Bool = false
    public var portfolioBefore: ApolloPortfolioAnalytics? = nil
    public var portfolioAfter: ApolloPortfolioAnalytics? = nil
    public var projectionNotice: String = "Estimate only. Actual portfolio analytics are recomputed at confirmation and may change with other trades, quotes, profile or assessments."
}
public enum ApolloGameError: LocalizedError {
    case invalidAmount, insufficientFunds, expired, unknownAsset, persistence(String), service(String)
    public var errorDescription: String? {
        switch self {
        case .invalidAmount: return "Enter a positive amount. Options and direct bonds require whole trade units. Respect the displayed quantity step."
        case .insufficientFunds: return "Your paper cash does not cover this order. Choose a smaller amount."
        case .expired: return "This preview expired. Review a new order before confirming."
        case .unknownAsset: return "This asset is unavailable. Refresh your deck and try again."
        case .persistence(let text), .service(let text): return text
        }
    }
}
@MainActor public protocol ApolloGameService {
    var modeLabel: String { get }
    func catalog() async throws -> [ApolloAsset]
    func account() async throws -> ApolloAccount
    func record(assetID: String, action: ApolloDecision, thesis: String) async throws -> ApolloAccount
    func preview(assetID: String, quantity: Decimal, thesis: String) async throws -> ApolloOrderPreview
    func previewCopy(strategyID: String, budget: Decimal, thesis: String) async throws -> ApolloOrderPreview
    func confirm(_ preview: ApolloOrderPreview) async throws -> ApolloAccount
    func reset() async throws -> ApolloAccount
    func setRiskProfile(_ tolerance: ApolloRiskTolerance) async throws -> ApolloAccount
    func challengeThesis(assetID: String, thesis: ApolloThesis) async throws -> ApolloThesisChallenge
    func researchSocial(url: String) async throws -> ApolloSocialResearchReceipt
    func admitSocialCandidate(candidateID: String) async throws -> ApolloSocialAdmission
    func comparePaper(assetID: String, quantity: Decimal, strategyBudget: Decimal?) async throws -> ApolloPaperComparison
}
public extension ApolloGameService {
    func researchSocial(url: String) async throws -> ApolloSocialResearchReceipt {
        guard let canonical = ApolloSocialResearchInput.canonicalURL(url) else { throw ApolloGameError.service("Enter a public HTTPS Instagram post or reel link.") }
        return .unavailable(url: canonical)
    }
    func admitSocialCandidate(candidateID: String) async throws -> ApolloSocialAdmission {
        throw ApolloGameError.service("Reviewed candidate admission is unavailable from this adapter. No card, holding or order was added.")
    }

    func comparePaper(assetID: String, quantity: Decimal, strategyBudget: Decimal?) async throws -> ApolloPaperComparison {
        throw ApolloGameError.service("Read-only comparison is unavailable from this adapter. Your profile, holdings and orders are unchanged.")
    }

    func challengeThesis(assetID: String, thesis: ApolloThesis) async throws -> ApolloThesisChallenge {
        ApolloThesisChallenge(requestID: UUID().uuidString, assetID: assetID, status: .unavailable, reason: "adapter_unavailable", notice: "No provider adapter is connected for this action. No model request was made; current research and your paper portfolio are unchanged.", context: .assignedHistorical)
    }

    func setRiskProfile(_ tolerance: ApolloRiskTolerance) async throws -> ApolloAccount {
        throw ApolloGameError.service("This adapter does not support risk profiles yet. Save this asset to your watchlist while the connection is updated.")
    }
}
public extension Decimal {
    var apolloMoney: String { NSDecimalNumber(decimal: self).doubleValue.formatted(.currency(code: "USD")) }
    var apolloQuantity: String { NSDecimalNumber(decimal: self).stringValue }
    var apolloDouble: Double { NSDecimalNumber(decimal: self).doubleValue }
}

public enum ApolloRiskTolerance: String, Codable, CaseIterable, Identifiable {
    case conservative, balanced, adventurous
    public var id: String { rawValue }
    public var ceiling: Int { switch self { case .conservative: return 2; case .balanced: return 3; case .adventurous: return 5 } }
    public var label: String { rawValue.capitalized }
}
public struct ApolloRiskProfile: Codable {
    public let tolerance: ApolloRiskTolerance
    public let ceiling: Int
    public var label: String = "DEMO educational 1–5 rubric; not loss probability"
}
public struct ApolloRiskCheck: Codable {
    public var status: String
    public var requiresMixedException: Bool
    public var notice: String
    public var outsideAssetIDs: [String] = []
}
public struct ApolloPortfolioSlice: Codable, Identifiable {
    public var id: String { label }
    public let label: String
    public let value: Decimal
    public let weight: Decimal
}
public struct ApolloPortfolioAnalytics: Codable {
    public let equity: Decimal
    public var cashWeight: Decimal
    public var assetClasses: [ApolloPortfolioSlice]
    public var weightedRisk: Decimal? = nil
    public var riskCoverage: Decimal = 0
    public var outsideToleranceAssetIDs: [String] = []
    public var riskLabel: String = "Educational rubric weighted by holdings; not loss probability"
    public var sentimentStatus: String = "unknown"
    public var bullishShare: Decimal? = nil
    public var bearishShare: Decimal? = nil
    public var sentimentCoverage: Decimal = 0
    public var hasDemoSentiment: Bool = false
    public var sentimentLabel: String = "Value-weighted evidence sentiment; not probability of profit. Unknown is not 50/50."
    public var sentimentProvenance: [String] = []
}
