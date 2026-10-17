import SwiftUI
import Charts

public struct ApolloOptionPayoffView: View {
    public let contract: ApolloOptionContract
    public let theme: ApolloChartTheme
    @State private var underlying: Double = 0
    public init(contract: ApolloOptionContract, theme: ApolloChartTheme = .init()) {
        self.contract = contract; self.theme = theme
        _underlying = State(initialValue: NSDecimalNumber(decimal: contract.strike).doubleValue)
    }
    private var strike: Double { NSDecimalNumber(decimal: contract.strike).doubleValue }
    private var upperBound: Double {
        let premium = NSDecimalNumber(decimal: contract.premiumPerShare).doubleValue
        return max(strike * 1.5, strike + premium * 2)
    }
    private var valid: Bool { contract.isValid && upperBound.isFinite && upperBound > 0 }
    private var scenarioPrice: Decimal { Decimal(string: String(format: "%.2f", locale: Locale(identifier: "en_US_POSIX"), underlying)) ?? contract.strike }
    private var samples: [PayoffPoint] {
        guard valid else { return [] }
        var values = (0...60).map { upperBound * Double($0) / 60 }
        values.append(strike)
        let breakEven = NSDecimalNumber(decimal: contract.breakEven).doubleValue
        if breakEven >= 0 && breakEven <= upperBound { values.append(breakEven) }
        return Array(Set(values)).sorted().compactMap { price in
            guard let result = contract.profit(atExpiryUnderlying: Decimal(price)) else { return nil }
            let profit = NSDecimalNumber(decimal: result).doubleValue
            guard profit.isFinite else { return nil }
            return PayoffPoint(underlying: price, profit: profit)
        }
    }
    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Divider().overlay(theme.muted.opacity(0.3))
            Text("AT EXPIRY · LONG \(contract.right.rawValue.uppercased())").font(.caption.weight(.semibold)).tracking(1).foregroundStyle(theme.muted)
            if valid {
                Text(contract.isDemo ? "Fictional contract scenario" : "Expiry payoff scenario").font(.headline)
                Text("\(contract.underlying) · strike \(money(contract.strike)) · expiry \(contract.expiry)")
                    .font(.caption).foregroundStyle(theme.muted)
                Text("\(contract.contracts) contract\(contract.contracts == 1 ? "" : "s") × \(contract.multiplier) multiplier · \(money(contract.premiumPerShare)) premium per share")
                    .font(.caption).foregroundStyle(theme.muted).fixedSize(horizontal: false, vertical: true)
                VStack(alignment: .leading, spacing: 6) {
                    LabeledContent("Maximum premium loss", value: money(contract.maximumLoss)).foregroundStyle(theme.caution)
                    LabeledContent("Break-even at expiry", value: contract.breakEven >= 0 ? money(contract.breakEven) : "Unreachable at a non-negative price")
                    Text(contract.right == .call ? "Upside is theoretically unbounded; the diagram shows a limited price range." : "Maximum profit at an underlying price of zero: \(money(contract.profit(atExpiryUnderlying: 0) ?? 0)).")
                        .font(.caption).foregroundStyle(theme.muted)
                }.font(.caption.weight(.medium)).monospacedDigit()
                Chart {
                    RuleMark(y: .value("Zero profit", 0)).foregroundStyle(theme.muted.opacity(0.5)).lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    RuleMark(x: .value("Strike", strike)).foregroundStyle(theme.muted.opacity(0.3)).lineStyle(StrokeStyle(lineWidth: 1, dash: [2, 3]))
                    ForEach(samples) { point in
                        LineMark(x: .value("Underlying at expiry", point.underlying), y: .value("Profit or loss", point.profit))
                            .foregroundStyle(theme.accent).lineStyle(StrokeStyle(lineWidth: 2)).interpolationMethod(.linear)
                    }
                    if let profit = contract.profit(atExpiryUnderlying: scenarioPrice) {
                        RuleMark(x: .value("Assumed underlying", underlying)).foregroundStyle(theme.text.opacity(0.5))
                        PointMark(x: .value("Assumed underlying", underlying), y: .value("Scenario P/L", NSDecimalNumber(decimal: profit).doubleValue))
                            .foregroundStyle(theme.text).symbolSize(45)
                    }
                }.chartXScale(domain: 0...upperBound)
                    .chartXAxis { AxisMarks(values: .automatic(desiredCount: 3)) { item in
                        AxisValueLabel { if let value = item.as(Double.self) { Text(value.formatted(.currency(code: "USD").precision(.fractionLength(0)))).font(.caption2).foregroundStyle(theme.muted) } }
                    } }
                    .chartYAxis { AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { item in
                        AxisGridLine().foregroundStyle(theme.muted.opacity(0.14))
                        AxisValueLabel { if let value = item.as(Double.self) { Text(value.formatted(.number.notation(.compactName))).font(.caption2).foregroundStyle(theme.muted) } }
                    } }.frame(height: 180)
                    .accessibilityLabel("Long \(contract.right.rawValue) expiry profit and loss diagram, US dollars")
                    .accessibilityIdentifier("option-payoff-plot")
                Text("X: underlying price at expiry · Y: total contract P/L (USD)").font(.caption2).foregroundStyle(theme.muted)
                VStack(alignment: .leading, spacing: 6) {
                    Text("Assume \(contract.underlying) at \(money(scenarioPrice)) at expiry").font(.subheadline.weight(.medium)).monospacedDigit()
                    Slider(value: $underlying, in: 0...upperBound, step: 0.01)
                        .tint(theme.accent).accessibilityLabel("Assumed underlying price at expiry")
                        .accessibilityValue(money(scenarioPrice)).accessibilityIdentifier("option-underlying-scenario")
                    if let profit = contract.profit(atExpiryUnderlying: scenarioPrice) {
                        Text("Scenario P/L: \(money(profit))").font(.title3.weight(.semibold)).monospacedDigit()
                            .foregroundStyle(profit >= 0 ? theme.accent : theme.caution).accessibilityIdentifier("option-scenario-pnl")
                    }
                }
                Text("Expiry sensitivity, not a price forecast. Entire premium can be lost. Excludes fees, taxes, exercise, assignment and early-sale pricing; no IV, Greeks or probability model.")
                    .font(.caption).foregroundStyle(theme.caution).fixedSize(horizontal: false, vertical: true)
            } else {
                Label("Payoff unavailable: supply a valid strike, premium, expiry, multiplier and whole contract count.", systemImage: "exclamationmark.triangle")
                    .font(.caption).foregroundStyle(theme.caution)
            }
        }.foregroundStyle(theme.text)
            .onChange(of: contract) { _, _ in underlying = strike }
            .accessibilityIdentifier("option-expiry-scenario")
    }
    private func money(_ amount: Decimal) -> String {
        let formatter = NumberFormatter(); formatter.numberStyle = .currency; formatter.currencyCode = "USD"
        return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "Unavailable"
    }
}
private struct PayoffPoint: Identifiable {
    let underlying: Double
    let profit: Double
    var id: Double { underlying }
}
