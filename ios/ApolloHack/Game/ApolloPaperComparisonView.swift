import SwiftUI

struct ApolloPaperComparisonView: View {
    @ObservedObject var store: ApolloGameStore
    @Environment(\.dismiss) private var dismiss
    @State private var assetID: String
    @State private var quantity: String
    private let strategyBudget: Decimal?
    @State private var result: ApolloPaperComparison?
    @State private var loading = false
    @State private var failure: String?
    @State private var shockIndex = 1
    @State private var selectedTolerance: ApolloRiskTolerance = .conservative
    @State private var submittedRequest: ApolloComparisonRequest?
    private var amount: Decimal? { Decimal(string: quantity.replacingOccurrences(of: ",", with: "."), locale: Locale(identifier: "en_US_POSIX")) }
    init(store: ApolloGameStore, initialAssetID: String = "AAPL", initialQuantity: Decimal = 1, initialStrategyBudget: Decimal? = nil) {
        self.store = store; _assetID = State(initialValue: initialAssetID); _quantity = State(initialValue: initialQuantity.apolloQuantity); strategyBudget = initialStrategyBudget
    }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ApolloEyebrow(text: "Read-only · before you decide")
                    Text("See what changes.").font(.system(.title, design: .serif))
                    Text("Your portfolio, a hypothetical investment and a fictional strategy—under all three risk profiles. Viewing an example never saves a profile or confirms an order.").font(.subheadline).foregroundStyle(ApolloStyle.muted)
                    DisclosureGroup {
                        VStack(alignment: .leading, spacing: 14) {
                            Picker("Hypothetical investment", selection: $assetID) { ForEach(store.assets.filter { $0.kind != .strategy }) { asset in Text(asset.ticker).tag(asset.id) } }.tint(ApolloStyle.lime).accessibilityIdentifier("compare-asset")
                            HStack { Text("Number of \(store.asset(assetID)?.unit ?? "units")").font(.subheadline); Spacer(); TextField("1", text: $quantity).keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(maxWidth: 100).accessibilityIdentifier("compare-quantity") }
                            Text(strategyBudget.map { "Strategy comparison budget: \($0.apolloMoney), from your paper-copy preview." } ?? "The fictional strategy gets the same hypothetical budget as the selected investment.").font(.caption).foregroundStyle(ApolloStyle.muted)
                            ApolloPrimaryButton(title: loading ? "Comparing…" : "Update comparison", symbol: "square.split.2x2", disabled: loading || amount == nil || (amount ?? 0) <= 0) { Task { await compare() } }.accessibilityIdentifier("compare-update")
                        }.padding(.top, 12)
                    } label: { Label("\(store.asset(assetID)?.ticker ?? assetID) · \(quantity) \(store.asset(assetID)?.unit ?? "units")", systemImage: "slider.horizontal.3").font(.subheadline) }.accessibilityIdentifier("compare-inputs").disabled(loading)
                    if loading && result == nil { ProgressView("Preparing read-only comparison…") }
                    if let failure { Label(failure, systemImage: "exclamationmark.triangle").foregroundStyle(ApolloStyle.amber).font(.subheadline).accessibilityIdentifier("compare-error") }
                    if let result {
                        if submittedRequest?.matches(assetID: assetID, quantityText: quantity) != true { Text("Inputs changed. Update the comparison; the results below still use the last submitted amounts.").font(.caption).foregroundStyle(ApolloStyle.amber) }
                        comparisonContent(result)
                    }
                }.padding(20).frame(maxWidth: 620).frame(maxWidth: .infinity)
            }.background(ApolloStyle.ink).foregroundStyle(ApolloStyle.cream).navigationTitle("Compare paper portfolios").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() }.accessibilityIdentifier("compare-close") } }
                .task { await compare() }
        }.tint(ApolloStyle.lime)
    }
    private func comparisonContent(_ value: ApolloPaperComparison) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Compare all three profiles").font(.headline).accessibilityAddTraits(.isHeader).accessibilityIdentifier("paper-comparison-results")
            ApolloPanel { VStack(alignment: .leading, spacing: 10) {
                ApolloEyebrow(text: value.modeLabel)
                Text("Your paper equity: \(value.baseline.equity.apolloMoney)").font(.headline).monospacedDigit()
                Text("Investment \(value.investmentTotal.apolloMoney) · fictional strategy \(value.strategyTotal.apolloMoney)").font(.subheadline).monospacedDigit()
                Text(value.strategyName).font(.caption).foregroundStyle(ApolloStyle.muted)
                Text("Demo marks / paper assumptions · no live execution or verified strategy track record.").font(.caption).foregroundStyle(ApolloStyle.amber)
            } }.accessibilityElement(children: .contain).accessibilityIdentifier("compare-baseline")
            Text("View a profile example").font(.subheadline.weight(.semibold))
            ForEach(value.profiles) { profile in
                Button { selectedTolerance = profile.tolerance } label: {
                    VStack(alignment: .leading, spacing: 7) {
                        HStack { Text(profile.tolerance.label).font(.headline); Spacer(); Text("Ceiling \(profile.ceiling)/5").font(.caption); if selectedTolerance == profile.tolerance { Image(systemName: "checkmark.circle.fill") } }
                        Text("Investment: \(shortStatus(profile.investment.riskCheck)) · Strategy: \(shortStatus(profile.strategy.riskCheck))").font(.caption).multilineTextAlignment(.leading)
                    }.padding(14).frame(maxWidth: .infinity, alignment: .leading).frame(minHeight: 62).background(selectedTolerance == profile.tolerance ? ApolloStyle.raised : ApolloStyle.surface, in: RoundedRectangle(cornerRadius: 16)).overlay(RoundedRectangle(cornerRadius: 16).stroke(selectedTolerance == profile.tolerance ? ApolloStyle.lime : .clear, lineWidth: 1.5)).foregroundStyle(ApolloStyle.cream)
                }.buttonStyle(.plain).accessibilityIdentifier("compare-profile-\(profile.tolerance.rawValue)").accessibilityAddTraits(selectedTolerance == profile.tolerance ? .isSelected : []).accessibilityHint("Shows this hypothetical example. Does not save your risk profile.")
            }
            if let profile = value.profiles.first(where: { $0.tolerance == selectedTolerance }) {
                ApolloPanel { VStack(alignment: .leading, spacing: 16) {
                    Text("\(profile.tolerance.label) example").font(.title2).accessibilityAddTraits(.isHeader).accessibilityIdentifier("compare-selected-profile-title")
                    metric("Your current portfolio", analytics: profile.current, baseline: nil, status: profile.current.outsideToleranceAssetIDs.isEmpty ? "No known holding above this ceiling; review coverage below." : "Above ceiling: " + profile.current.outsideToleranceAssetIDs.joined(separator: ", "))
                    Divider()
                    metric("With selected investment", analytics: profile.investment.portfolioAfter, baseline: profile.current, status: status(profile.investment.riskCheck))
                    Text(profile.investment.riskCheck.notice).font(.caption).foregroundStyle(ApolloStyle.muted)
                    Divider()
                    metric("With fictional strategy", analytics: profile.strategy.portfolioAfter, baseline: profile.current, status: status(profile.strategy.riskCheck))
                    Text(profile.strategy.riskCheck.notice).font(.caption).foregroundStyle(ApolloStyle.muted)
                    Text("Blocked cases remain visible for learning. Sentiment shares describe covered holdings, not a probability of profit. Unknown is not neutral or 50/50.").font(.caption).foregroundStyle(ApolloStyle.amber)
                } }.accessibilityElement(children: .contain).accessibilityIdentifier("compare-selected-profile")
                DisclosureGroup("Allocations and scenario outcomes") {
                    VStack(alignment: .leading, spacing: 20) {
                        allocation("Your current portfolio", summary: profile.current)
                        allocation("With selected investment", summary: profile.investment.portfolioAfter)
                        allocation("With fictional strategy", summary: profile.strategy.portfolioAfter)
                        Text("Hypothetical sensitivity · not a forecast").font(.headline)
                        Picker("Hypothetical mark shock", selection: $shockIndex) { Text("−20%").tag(0); Text("Flat").tag(1); Text("+20%").tag(2) }.pickerStyle(.segmented).accessibilityIdentifier("compare-shock")
                        outcome("Current paper mix", items: value.outcomes.current)
                        outcome("With investment", items: value.outcomes.investment)
                        outcome("With fictional strategy", items: value.outcomes.strategy)
                        Text(value.outcomeAssumptions).font(.caption).foregroundStyle(ApolloStyle.amber)
                    }.padding(.top, 14)
                }.accessibilityIdentifier("compare-outcomes")
            }
            DisclosureGroup("Sources, assumptions and full notices") {
                VStack(alignment: .leading, spacing: 12) {
                    Text(value.strategyProvenance); Text(value.comparisonNotice)
                    Text("Strategy budget \(value.strategyBudget.apolloMoney) · uninvested remainder \(value.uninvestedBudget.apolloMoney)")
                    if let pnl = value.recordedPaperPnL { Text("Recorded paper result: \(pnl.apolloMoney)"); Text(value.recordedPaperPnLLabel) }
                }.font(.caption).foregroundStyle(ApolloStyle.muted).padding(.top, 12)
            }
            Text(store.account.riskProfile.map { "Your saved \($0.tolerance.label) profile is unchanged. Close this comparison to return to your separate paper order." } ?? "No profile was selected for you. A separate paper order requires an explicit profile, thesis, preview and confirmation.").font(.caption).foregroundStyle(ApolloStyle.muted)
        }
    }
    private func metric(_ title: String, analytics: ApolloPortfolioAnalytics, baseline: ApolloPortfolioAnalytics?, status: String) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(title).font(.headline); Text(status).font(.caption).foregroundStyle(ApolloStyle.amber)
            Text("Invested risk: \(ApolloComparisonPresentation.risk(analytics)) · coverage \(percent(analytics.riskCoverage))").font(.subheadline)
            Text(ApolloComparisonPresentation.sentiment(analytics)).font(.subheadline)
            Text("Evidence sentiment: \(analytics.sentimentStatus.replacingOccurrences(of: "_", with: " ")) · coverage \(percent(analytics.sentimentCoverage))").font(.caption).foregroundStyle(ApolloStyle.muted)
            if analytics.hasDemoSentiment { Text("Includes DEMO sentiment scores").font(.caption).foregroundStyle(ApolloStyle.amber) }
            if let baseline {
                Text(ApolloComparisonPresentation.riskChange(before: baseline, after: analytics)).font(.caption).foregroundStyle(ApolloStyle.muted)
                Text(ApolloComparisonPresentation.sentimentChange(before: baseline, after: analytics)).font(.caption).foregroundStyle(ApolloStyle.muted)
                Text("Cash \((baseline.equity * baseline.cashWeight).apolloMoney) → \((analytics.equity * analytics.cashWeight).apolloMoney) · risk coverage \(percent(baseline.riskCoverage)) → \(percent(analytics.riskCoverage)) · sentiment coverage \(percent(baseline.sentimentCoverage)) → \(percent(analytics.sentimentCoverage))").font(.caption).foregroundStyle(ApolloStyle.muted)
            }
            Text(analytics.riskLabel).font(.caption2).foregroundStyle(ApolloStyle.muted)
            Text(analytics.sentimentLabel).font(.caption2).foregroundStyle(ApolloStyle.muted)
            if !analytics.sentimentProvenance.isEmpty { DisclosureGroup("Sentiment sources") { ForEach(Array(analytics.sentimentProvenance.enumerated()), id: \.offset) { _, text in Text(text).font(.caption2).foregroundStyle(ApolloStyle.muted) } } }
        }
    }
    private func allocation(_ title: String, summary: ApolloPortfolioAnalytics) -> some View {
        VStack(alignment: .leading, spacing: 10) { Text(title).font(.subheadline.weight(.semibold)); weight("Cash", amount: summary.cashWeight); ForEach(summary.assetClasses) { slice in weight(slice.label.replacingOccurrences(of: "_", with: " ").capitalized, amount: slice.weight) } }.accessibilityIdentifier("compare-allocations")
    }
    private func weight(_ title: String, amount: Decimal) -> some View { VStack(spacing: 6) { HStack { Text(title); Spacer(); Text(percent(amount)).monospacedDigit() }.font(.caption); ProgressView(value: min(max(amount.apolloDouble, 0), 1)).tint(ApolloStyle.lime) } }
    private func outcome(_ title: String, items: [ApolloComparisonOutcome]) -> some View {
        VStack(alignment: .leading, spacing: 8) { Text(title).font(.subheadline.weight(.semibold)); if items.indices.contains(shockIndex) { let item = items[shockIndex]; HStack { Text(item.equity.apolloMoney).font(.title3).monospacedDigit(); Spacer(); Text("Change \(item.changeFromSnapshot.apolloMoney)").font(.caption).monospacedDigit() }; Text(item.label).font(.caption2).foregroundStyle(ApolloStyle.muted) } else { Text("Scenario unavailable.").font(.caption).foregroundStyle(ApolloStyle.muted) } }
    }
    private func percent(_ value: Decimal) -> String { ApolloComparisonPresentation.percent(value) }
    private func shortStatus(_ check: ApolloRiskCheck) -> String { switch check.status { case "within_tolerance": return "Within ceiling"; case "mixed_exception": return "Exception required"; case "blocked": return "Blocked"; default: return "Unknown" } }
    private func status(_ check: ApolloRiskCheck) -> String { switch check.status { case "within_tolerance": return "Within this educational ceiling"; case "mixed_exception": return "Above ceiling · explicit paper exception required"; case "blocked": return "Blocked · hypothetical comparison only"; default: return check.status.replacingOccurrences(of: "_", with: " ").capitalized } }
    private func compare() async {
        guard !loading, let amount, amount > 0 else { return }
        loading = true; failure = nil; defer { loading = false }
        let request = ApolloComparisonRequest(assetID: assetID, quantityText: quantity, quantity: amount, strategyBudget: strategyBudget)
        do { let response = try await request.fetch(using: store.service); result = response.comparison; submittedRequest = response.request }
        catch { failure = error.localizedDescription }
    }
}
