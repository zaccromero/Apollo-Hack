import SwiftUI
import Charts

public struct ApolloCategoryChartsView: View {
    public let context: ApolloChartContext
    public let series: ApolloChartSeries
    public let theme: ApolloChartTheme
    @State private var selectedMetric = 0
    @State private var pegScenario = 1.0
    public init(context: ApolloChartContext, series: ApolloChartSeries, theme: ApolloChartTheme = .init()) {
        self.context = context; self.series = series; self.theme = theme
    }
    private var allocations: [ApolloChartAllocation] {
        let rows = context.allocations
        guard Set(rows.map(\.name)).count == rows.count,
              rows.allSatisfy({ !$0.name.isEmpty && $0.weight.isFinite && $0.weight >= 0 && $0.weight <= 1 }),
              rows.reduce(0, { $0 + $1.weight }) <= 1.000001 else { return [] }
        guard rows.count > 12 else { return rows }
        let ranked = rows.sorted { $0.weight > $1.weight }
        return Array(ranked.prefix(10)) + [.init(name: "Other supplied exposures", weight: ranked.dropFirst(10).reduce(0) { $0 + $1.weight })]
    }
    private var financials: [ApolloFinancialComparison] {
        context.financials.filter {
            !$0.values.isEmpty && $0.symbol == series.symbol && Set($0.values.map(\.period)).count == $0.values.count
            && $0.values.allSatisfy { $0.value.isFinite && abs($0.value) <= 1e18 }
            && ["http", "https"].contains($0.sourceURL.scheme?.lowercased() ?? "")
        }
    }
    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if [.strategy, .etf, .realEstate].contains(context.category) { allocationView }
            if context.category == .stablecoin { stablecoinView }
            if context.category == .bond {
                if let bond = context.bond { bondView(bond) }
                else { Text("Bond terms unavailable; no schedule or price is inferred.").font(.caption).foregroundStyle(theme.muted) }
            }
            if !financials.isEmpty { financialView }
            if context.category == .commodity {
                Text("Fund-share exposure is separate from physical possession. The chart follows the supplied instrument, not an independently verified spot commodity price.").font(.caption).foregroundStyle(theme.muted)
            }
            if context.category == .crypto {
                Text("Calendar dates retain supplied observations, including weekends. Gaps are not filled; exchange, custody and liquidity risks remain.").font(.caption).foregroundStyle(theme.muted)
            }
        }.foregroundStyle(theme.text).accessibilityElement(children: .contain).accessibilityIdentifier("category-charts-\(context.category.rawValue)")
    }
    private var allocationView: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(context.category == .strategy ? "Fictional strategy allocation" : "Sourced exposure breakdown").font(.headline)
            if allocations.isEmpty {
                Text("No sourced holdings breakdown supplied. A price line cannot establish diversification or concentration.").font(.caption).foregroundStyle(theme.muted)
            } else {
                Chart(allocations) { item in
                    BarMark(x: .value("Weight", item.weight), y: .value("Exposure", item.name)).foregroundStyle(theme.accent)
                        .annotation(position: .trailing) { Text(item.weight.formatted(.percent.precision(.fractionLength(1)))).font(.caption2).foregroundStyle(theme.text) }
                }.chartXScale(domain: 0...1).chartXAxis { AxisMarks(values: [0.0, 0.5, 1.0]) { value in
                    AxisValueLabel { if let value = value.as(Double.self) { Text(value.formatted(.percent.precision(.fractionLength(0)))).font(.caption2) } }
                } }.frame(height: CGFloat(max(120, min(400, allocations.count * 34))))
                    .accessibilityLabel("Allocation weights, not a performance history").accessibilityIdentifier("category-allocation-plot")
                Text("Shown coverage: \(allocations.reduce(0) { $0 + $1.weight }.formatted(.percent.precision(.fractionLength(1)))). \(context.allocationSource ?? "Source description unavailable.")").font(.caption).foregroundStyle(theme.muted)
                if let url = context.allocationSourceURL, ["https", "http"].contains(url.scheme?.lowercased() ?? "") {
                    Link("Open allocation source", destination: url).font(.caption).frame(minHeight: 44).foregroundStyle(theme.accent)
                }
                Text(context.category == .strategy ? "Illustrative weights, no verified creator track record. Portfolio comparison contains explicitly labelled shock scenarios; these bars do not show returns." : "Weights are a dated snapshot and may be incomplete. No current yield, fee or benchmark return is inferred.")
                    .font(.caption).foregroundStyle(theme.caution)
            }
        }
    }
    private var stablecoinView: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Peg sensitivity").font(.headline)
            if let peg = context.targetPeg, peg.isFinite, peg > 0, peg < 1e12 {
                if series.basis == .cachedMarket, !series.observations.isEmpty {
                    Chart {
                        RuleMark(y: .value("Target peg deviation", 0)).foregroundStyle(theme.muted).lineStyle(.init(lineWidth: 1, dash: [3, 3]))
                        ForEach(ApolloChartMath.points(in: series)) { point in
                            if let date = point.observation.date {
                                LineMark(x: .value("Observation", date), y: .value("Deviation percent", (point.observation.close / peg - 1) * 100), series: .value("Segment", point.segment)).foregroundStyle(theme.accent)
                            }
                        }
                    }.chartXAxis { AxisMarks(values: .automatic(desiredCount: 3)) { item in AxisValueLabel { if let date = item.as(Date.self) { Text(dateLabel(date)).font(.caption2) } } } }.frame(height: 160).accessibilityIdentifier("stablecoin-deviation-plot")
                    Text("Deviation from the supplied target peg (%). Reference market observations do not verify this demo token's redemption or reserves.").font(.caption).foregroundStyle(theme.muted)
                }
                Text("Illustrative depeg scenario · 100 tokens").font(.subheadline.weight(.semibold))
                pegScenarioPlot(peg)
                Slider(value: $pegScenario, in: 0.5...1.5, step: 0.01).tint(theme.accent).accessibilityLabel("Illustrative peg ratio").accessibilityIdentifier("stablecoin-scenario")
                Text("At \((peg * pegScenario).formatted(.currency(code: "USD"))) per token: \((100 * peg * pegScenario).formatted(.currency(code: "USD")))").font(.subheadline).monospacedDigit()
                Text("Difference from target: \((100 * peg * (pegScenario - 1)).formatted(.currency(code: "USD")))").font(.caption).monospacedDigit().foregroundStyle(theme.caution)
                Text("Sensitivity, not historical prices, a forecast, cash, or guaranteed redemption. Issuer, reserve and custody risks remain.").font(.caption).foregroundStyle(theme.caution)
            } else { Text("Target peg unavailable; no peg chart is inferred.").font(.caption).foregroundStyle(theme.muted) }
        }
    }
    private func pegScenarioPlot(_ peg: Double) -> some View {
        Chart {
            ForEach(0..<11, id: \.self) { index in
                let price = peg * (0.5 + Double(index) * 0.1)
                LineMark(x: .value("Assumed token price USD", price), y: .value("100 token value USD", 100 * price)).foregroundStyle(theme.accent)
            }
            RuleMark(x: .value("Target peg", peg)).foregroundStyle(theme.muted).lineStyle(.init(lineWidth: 1, dash: [3, 3]))
            PointMark(x: .value("Assumed token price USD", peg * pegScenario), y: .value("100 token value USD", 100 * peg * pegScenario)).foregroundStyle(theme.text)
        }.frame(height: 140).accessibilityLabel("Illustrative value of100tokens against assumed token price, both USD; not historical data").accessibilityIdentifier("stablecoin-sensitivity-plot")
    }
    @ViewBuilder private func bondView(_ terms: ApolloBondChartTerms) -> some View {
        let flows = ApolloAdvancedChartMath.cashFlows(terms)
        VStack(alignment: .leading, spacing: 10) {
            Text("Illustrative coupon and principal schedule").font(.headline)
            if flows.isEmpty {
                Text("No future schedule can be derived from the supplied terms. No payment or maturity settlement is assumed.").font(.caption).foregroundStyle(theme.muted)
            } else {
                Chart(flows) { flow in
                    BarMark(x: .value("Scheduled date", flow.date), y: .value("Coupon USD", flow.coupon)).foregroundStyle(theme.accent)
                    BarMark(x: .value("Scheduled date", flow.date), y: .value("Principal USD", flow.principal)).foregroundStyle(theme.muted)
                }.chartXAxis { AxisMarks(values: .automatic(desiredCount: 3)) { item in AxisValueLabel { if let date = item.as(Date.self) { Text(dateLabel(date)).font(.caption2) } } } }.frame(height: 160).accessibilityIdentifier("bond-cashflow-plot")
                Text("Blue: coupon amount. Muted: principal. Fictional terms; regular coupon dates are assumed backward from maturity. Actual coupon dates, stub periods and holiday adjustments are not supplied. No payments or settlement are simulated.").font(.caption).foregroundStyle(theme.caution)
                Text("Hypothetical rate sensitivity").font(.subheadline.weight(.semibold))
                Chart {
                    ForEach(0..<13, id: \.self) { index in
                        let yield = max(0, terms.annualCouponRate - 0.02) + Double(index) * 0.005
                        if let value = ApolloAdvancedChartMath.bondPresentValue(terms, annualYield: yield) {
                            LineMark(x: .value("Assumed annual yield percent", yield * 100), y: .value("Illustrative present value USD", value)).foregroundStyle(theme.accent)
                        }
                    }
                }.frame(height: 150).accessibilityIdentifier("bond-sensitivity-plot")
                Text("X: assumed annual yield (%). Y: discounted contractual payments (USD), assuming every payment is made. Uses the assumed regular schedule and supplied coupon frequency; not a market quote or credit-risk model.").font(.caption).foregroundStyle(theme.muted)
                DisclosureGroup("Scheduled amounts") {
                    ForEach(flows) { flow in LabeledContent(dateLabel(flow.date), value: (flow.coupon + flow.principal).formatted(.currency(code: "USD"))).font(.caption).monospacedDigit() }
                }.font(.caption).tint(theme.accent)
            }
        }
    }
    private var financialView: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Reported financial record").font(.headline)
            let metric = financials[min(selectedMetric, financials.count - 1)]
            Picker("Financial metric", selection: $selectedMetric) {
                ForEach(Array(financials.enumerated()), id: \.element.id) { index, item in Text(item.metric).tag(index) }
            }.pickerStyle(.menu).tint(theme.accent).accessibilityIdentifier("financial-metric")
            Chart(metric.values) { item in
                BarMark(x: .value("Reported period", item.period), y: .value(metric.unit, item.value)).foregroundStyle(theme.accent)
                    .annotation(position: .top) { Text(item.value.formatted(.number.notation(.compactName))).font(.caption2).foregroundStyle(theme.text) }
            }.chartYScale(domain: min(0, metric.values.map(\.value).min() ?? 0)...max(1, (metric.values.map(\.value).max() ?? 1) * 1.15))
                .frame(height: 180).accessibilityIdentifier("financial-comparison-plot")
            Text("\(metric.metric) · \(metric.unit). \(metric.note)").font(.caption).foregroundStyle(theme.muted)
            Link(metric.sourceLabel, destination: metric.sourceURL).font(.caption).frame(minHeight: 44).foregroundStyle(theme.accent)
            DisclosureGroup("Exact figures and reported periods") {
                ForEach(metric.values) { item in LabeledContent(item.period, value: item.value.formatted(.number.precision(.fractionLength(2)))).font(.caption).monospacedDigit() }
            }.font(.caption).tint(theme.accent)
            Text("Reported periods are not price history or proof that leadership caused a change. Different metrics and units are never combined.").font(.caption).foregroundStyle(theme.caution)
        }.onChange(of: context.financials) { _, _ in selectedMetric = 0 }
    }
    private func dateLabel(_ date: Date) -> String {
        let formatter = DateFormatter(); formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0); formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
    }

}
