import SwiftUI

struct ApolloPortfolioInsightsView: View {
    let analytics: ApolloPortfolioAnalytics
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            ApolloPanel { VStack(alignment: .leading, spacing: 18) {
                ApolloEyebrow(text: "Where your paper money sits")
                Text("Allocation").font(.title2.weight(.medium))
                weightRow("Cash", weight: analytics.cashWeight, value: nil)
                ForEach(analytics.assetClasses) { slice in weightRow(className(slice.label), weight: slice.weight, value: slice.value) }
                Text("Weights include cash and use paper-engine marks. Allocation describes exposure; it is separate from bullish/bearish sentiment.").font(.caption).foregroundStyle(ApolloStyle.muted)
            } }.accessibilityIdentifier("portfolio-allocation")
            ApolloPanel { VStack(alignment: .leading, spacing: 16) {
                ApolloEyebrow(text: "Know the exposure")
                Text("Educational risk").font(.title2.weight(.medium))
                if let score = analytics.weightedRisk {
                    HStack(alignment: .firstTextBaseline) { Text(score.apolloDouble.formatted(.number.precision(.fractionLength(1)))).font(.largeTitle).monospacedDigit(); Text("/ 5 invested risk score").font(.caption).foregroundStyle(ApolloStyle.muted) }
                    ProgressView(value: min(max(score.apolloDouble / 5, 0), 1)).tint(ApolloStyle.amber)
                    Text("Assessment covers \(percent(analytics.riskCoverage)) of holdings value.").font(.caption).foregroundStyle(ApolloStyle.muted)
                } else { Text("No scored holdings yet.").font(.subheadline).foregroundStyle(ApolloStyle.muted) }
                if !analytics.outsideToleranceAssetIDs.isEmpty { Label("Above your current tolerance: " + analytics.outsideToleranceAssetIDs.joined(separator: ", "), systemImage: "exclamationmark.shield").font(.subheadline).foregroundStyle(ApolloStyle.amber) }
                Text(analytics.riskLabel).font(.caption).foregroundStyle(ApolloStyle.muted)
            } }.accessibilityIdentifier("portfolio-risk")
            ApolloPanel { VStack(alignment: .leading, spacing: 16) {
                ApolloEyebrow(text: "What the covered evidence says")
                Text("Sentiment · \(analytics.sentimentStatus.capitalized)").font(.title2.weight(.medium))
                if let bullish = analytics.bullishShare, let bearish = analytics.bearishShare, analytics.sentimentStatus != "unknown" {
                    HStack { Label("\(percent(bullish)) bullish", systemImage: "arrow.up.right").foregroundStyle(ApolloStyle.lime); Spacer(); Label("\(percent(bearish)) bearish", systemImage: "arrow.down.right").foregroundStyle(ApolloStyle.amber) }.font(.subheadline.weight(.semibold))
                    GeometryReader { geo in HStack(spacing: 3) { Capsule().fill(ApolloStyle.lime).frame(width: max(0, (geo.size.width - 3) * CGFloat(min(max(bullish.apolloDouble, 0), 1)))); Capsule().fill(ApolloStyle.amber) } }.frame(height: 10)
                    Text("Coverage: \(percent(analytics.sentimentCoverage)) of holdings value. The split describes only covered holdings; missing evidence stays unknown.").font(.caption).foregroundStyle(ApolloStyle.muted)
                    if analytics.hasDemoSentiment { Text("Includes DEMO sentiment inputs.").font(.caption.bold()).foregroundStyle(ApolloStyle.amber) }
                } else { Label("Sentiment unknown", systemImage: "questionmark.circle").foregroundStyle(ApolloStyle.muted); Text("No scored evidence is available. Unknown does not mean 50/50, neutral, or safe.").font(.subheadline).foregroundStyle(ApolloStyle.muted) }
                Text(analytics.sentimentLabel).font(.caption).foregroundStyle(ApolloStyle.muted)
                ForEach(Array(analytics.sentimentProvenance.enumerated()), id: \.offset) { _, item in Text(item).font(.caption2).foregroundStyle(ApolloStyle.muted) }
            } }.accessibilityIdentifier("portfolio-sentiment")
        }
    }
    private func percent(_ value: Decimal) -> String { value.apolloDouble.formatted(.percent.precision(.fractionLength(0))) }
    private func className(_ raw: String) -> String { switch raw { case "commodity_exposure", "commodity": return "Commodities"; case "real_estate_exposure", "real_estate": return "Real estate"; case "stock": return "Stocks"; case "etf": return "ETFs"; case "crypto": return "Crypto"; case "option": return "Options"; default: return raw } }
    private func weightRow(_ title: String, weight: Decimal, value: Decimal?) -> some View {
        VStack(alignment: .leading, spacing: 8) { HStack { Text(title).font(.subheadline); Spacer(); if let value { Text(value.apolloMoney).font(.caption).foregroundStyle(ApolloStyle.muted).monospacedDigit() }; Text(percent(weight)).font(.subheadline.weight(.semibold)).monospacedDigit() }; ProgressView(value: min(max(weight.apolloDouble, 0), 1)).tint(ApolloStyle.lime) }.accessibilityElement(children: .combine)
    }
}
