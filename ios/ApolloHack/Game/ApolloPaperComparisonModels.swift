import Foundation

public struct ApolloComparisonProjection: Codable {
    public let riskCheck: ApolloRiskCheck
    public let portfolioAfter: ApolloPortfolioAnalytics
}
public struct ApolloComparisonProfile: Codable, Identifiable {
    public var id: String { tolerance.rawValue }
    public let tolerance: ApolloRiskTolerance
    public let ceiling: Int
    public let current: ApolloPortfolioAnalytics
    public let investment: ApolloComparisonProjection
    public let strategy: ApolloComparisonProjection
}
public struct ApolloComparisonOutcome: Codable, Identifiable {
    public var id: String { shock.apolloQuantity }
    public let shock: Decimal
    public let holdingMarkValue: Decimal
    public let equity: Decimal
    public let changeFromSnapshot: Decimal
    public let label: String
}
public struct ApolloComparisonOutcomes: Codable {
    public let current: [ApolloComparisonOutcome]
    public let investment: [ApolloComparisonOutcome]
    public let strategy: [ApolloComparisonOutcome]
}
public struct ApolloPaperComparison: Codable {
    public let modeLabel: String
    public let mutatesAccount: Bool
    public var createsOrder: Bool = false
    public var comparisonNotice: String = "Read-only hypothetical comparison. Risk-ineligible cases are shown for learning only; no profile is selected and no order is created."
    public var outcomeAssumptions: String = "DEMO uniform held-mark sensitivities, not forecasts, probabilities or observed returns. Cash stays unchanged; options shock premium marks, not underlying prices. No correlations, Greeks, expiry, exercise, fees or slippage are modeled."
    public let baseline: ApolloPortfolioAnalytics
    public var recordedPaperPnL: Decimal? = nil
    public var recordedPaperPnLLabel: String = "Paper marks versus recorded cost; not a realized or forecast return"
    public let investmentLines: [ApolloOrderLine]
    public let investmentTotal: Decimal
    public let strategyID: String
    public let strategyName: String
    public let strategyProvenance: String
    public let strategyLines: [ApolloOrderLine]
    public let strategyTotal: Decimal
    public let strategyBudget: Decimal
    public let uninvestedBudget: Decimal
    public let profiles: [ApolloComparisonProfile]
    public let outcomes: ApolloComparisonOutcomes
}
