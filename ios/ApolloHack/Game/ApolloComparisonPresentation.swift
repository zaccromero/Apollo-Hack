import Foundation

/// Display-only comparisons. Missing coverage never becomes a zero score or a 50/50 reading.
public enum ApolloComparisonPresentation {
    public static func percent(_ value: Decimal) -> String { value.apolloDouble.formatted(.percent.precision(.fractionLength(0...1))) }
    public static func risk(_ analytics: ApolloPortfolioAnalytics) -> String {
        guard analytics.riskCoverage > 0, analytics.riskCoverage <= 1, let value = analytics.weightedRisk, value.isFinite, value >= 1, value <= 5 else { return "Unknown" }
        return value.apolloDouble.formatted(.number.precision(.fractionLength(1))) + "/5"
    }
    public static func riskChange(before: ApolloPortfolioAnalytics, after: ApolloPortfolioAnalytics) -> String {
        guard risk(before) != "Unknown", risk(after) != "Unknown", let first = before.weightedRisk, let last = after.weightedRisk else { return "Risk change unavailable · a covered score is missing." }
        guard before.riskCoverage == after.riskCoverage else { return "Risk coverage changed · the covered scores are not directly comparable." }
        return "Covered risk change: \(signed(last - first)) points on the 1–5 rubric."
    }
    public static func hasScoredSentiment(_ analytics: ApolloPortfolioAnalytics) -> Bool {
        guard ["known", "bullish", "bearish", "mixed"].contains(analytics.sentimentStatus.lowercased()), analytics.sentimentCoverage > 0, analytics.sentimentCoverage <= 1,
              let bullish = analytics.bullishShare, let bearish = analytics.bearishShare,
              bullish.isFinite, bearish.isFinite, bullish >= 0, bullish <= 1, bearish >= 0, bearish <= 1 else { return false }
        return abs((bullish + bearish - 1).apolloDouble) <= 0.000001
    }
    public static func sentiment(_ analytics: ApolloPortfolioAnalytics) -> String {
        guard hasScoredSentiment(analytics), let bullish = analytics.bullishShare, let bearish = analytics.bearishShare else { return "Bullish / bearish: Unknown" }
        return "Bullish \(percent(bullish)) · bearish \(percent(bearish)) of covered holdings"
    }
    public static func sentimentChange(before: ApolloPortfolioAnalytics, after: ApolloPortfolioAnalytics) -> String {
        guard hasScoredSentiment(before), hasScoredSentiment(after), let first = before.bullishShare, let last = after.bullishShare, let firstBear = before.bearishShare, let lastBear = after.bearishShare else { return "Sentiment change unavailable · unknown is not 50/50." }
        guard before.sentimentCoverage == after.sentimentCoverage else { return "Sentiment coverage changed · share deltas are not directly comparable." }
        return "Covered share change: bullish \(signed((last - first) * 100)) pp · bearish \(signed((lastBear - firstBear) * 100)) pp."
    }
    private static func signed(_ value: Decimal) -> String { (value > 0 ? "+" : "") + value.apolloDouble.formatted(.number.precision(.fractionLength(1))) }
}
