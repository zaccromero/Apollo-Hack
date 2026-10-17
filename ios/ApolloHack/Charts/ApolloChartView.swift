import SwiftUI
import Charts

public struct ApolloChartTheme {
    public var accent: Color
    public var text: Color
    public var muted: Color
    public var caution: Color
    public var surface: Color
    public init(accent: Color = Color(red: 50.0 / 255, green: 104.0 / 255, blue: 223.0 / 255),
                text: Color = Color(red: 11.0 / 255, green: 20.0 / 255, blue: 40.0 / 255),
                muted: Color = Color(red: 82.0 / 255, green: 96.0 / 255, blue: 122.0 / 255),
                caution: Color = Color(red: 145.0 / 255, green: 73.0 / 255, blue: 0),
                surface: Color = Color.white) {
        self.accent = accent; self.text = text; self.muted = muted
        self.caution = caution; self.surface = surface
    }
}

/// Embed inside the existing detail panel. No parent layout, network or account effects.
public struct ApolloChartView: View {
    public let series: ApolloChartSeries
    public let option: ApolloOptionContract?
    public let theme: ApolloChartTheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var range: ApolloChartRange = .all
    @State private var candles = false
    @State private var indicators: Set<ApolloChartIndicator> = []
    @State private var selectedX: Double?
    @State private var showMethods = false

    public init(series: ApolloChartSeries, option: ApolloOptionContract? = nil,
                theme: ApolloChartTheme = .init()) {
        self.series = series; self.option = option; self.theme = theme
    }
    private var points: [ApolloChartPoint] { ApolloChartMath.points(in: series) }
    private var visible: [ApolloChartPoint] { ApolloChartMath.visible(points, range: range, basis: series.basis) }
    private var selected: ApolloChartPoint? {
        guard let selectedX else { return visible.last }
        return visible.min { abs(x($0) - selectedX) < abs(x($1) - selectedX) }
    }
    private var market: Bool { series.basis == .cachedMarket }
    private var hasCandles: Bool { market && visible.contains { $0.observation.hasCandle } }
    private var volumes: [ApolloChartPoint] { market ? visible.filter { validVolume($0) != nil } : [] }
    private var domain: ClosedRange<Double> {
        let first = visible.first.map(x) ?? 0, last = visible.last.map(x) ?? 1
        let pad = first == last ? (market ? 43_200.0 : 0.5) : (last - first) * 0.015
        return (first - pad)...(last + pad)
    }
    private var yDomain: ClosedRange<Double> {
        let prices = visible.flatMap { p -> [Double] in
            if candles && p.observation.hasCandle { return [p.observation.low!, p.observation.high!] }
            return [p.observation.close]
        }
        let lines = activeLines.flatMap { $0.values.values }
        let all = prices + lines
        let low = all.min() ?? 0, high = all.max() ?? 1
        let pad = max((high - low) * 0.12, max(abs(high) * 0.002, 0.01))
        return max(0, low - pad)...(high + pad)
    }
    private var activeLines: [IndicatorLine] {
        ApolloChartIndicator.allCases.filter { market && indicators.contains($0) }.map { item in
            let all = ApolloChartMath.indicator(item, points: points)
            let ids = Set(visible.map(\.id))
            return IndicatorLine(indicator: item, values: all.filter { ids.contains($0.key) })
        }
    }
    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            if visible.isEmpty {
                Label("No chart observations available", systemImage: "chart.xyaxis.line")
                    .font(.subheadline).foregroundStyle(theme.muted).frame(maxWidth: .infinity, minHeight: 120)
                Text("This asset has no verified price history here. Review its allocation or source evidence below.")
                    .font(.caption).foregroundStyle(theme.muted)
            } else {
                controls
                pricePlot
                if !volumes.isEmpty { volumePlot }
                if candles && visible.contains(where: { !$0.observation.hasCandle }) {
                    Text("OHLC missing for some observations; those candles are omitted.").font(.caption).foregroundStyle(theme.caution)
                }
                if market && volumes.count < visible.count {
                    Text(volumes.isEmpty ? "Volume unavailable in this source." : "Volume omitted where unavailable.")
                        .font(.caption).foregroundStyle(theme.muted)
                }
                if market { indicatorControls }
                else { Text("Illustrative scenario · not price history or a return forecast. Dates, candles and historical indicators are unavailable.").font(.caption).foregroundStyle(theme.caution) }
            }
            provenance
            if let option { ApolloOptionPayoffView(contract: option, theme: theme) }
        }
        .foregroundStyle(theme.text)
        .accessibilityIdentifier("apollo-chart")
        .onChange(of: range) { _, _ in selectedX = nil }
        .onChange(of: series) { _, _ in selectedX = nil; range = .all; indicators = []; candles = false }
    }
    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(market ? "PRICE HISTORY" : "DEMO SCENARIO").font(.caption.weight(.semibold)).tracking(1)
                Spacer()
                Text(series.symbol).font(.caption.weight(.semibold)).lineLimit(1)
            }.foregroundStyle(theme.muted)
            if let selected {
                Text(value(selected.observation.close)).font(.title.weight(.semibold)).monospacedDigit()
                    .accessibilityIdentifier("chart-selected-value")
                Text(pointLabel(selected) + (selectedX == nil ? " · latest observation" : " · selected observation"))
                    .font(.caption).foregroundStyle(theme.muted)
                if candles && selected.observation.hasCandle {
                    Text("O \(number(selected.observation.open!))  H \(number(selected.observation.high!))  L \(number(selected.observation.low!))  C \(number(selected.observation.close))")
                        .font(.caption2).monospacedDigit().foregroundStyle(theme.muted).fixedSize(horizontal: false, vertical: true)
                }
                if let volume = validVolume(selected) {
                    Text("Volume \(volume.formatted(.number.notation(.compactName)))").font(.caption2).foregroundStyle(theme.muted)
                }
            }
        }.accessibilityElement(children: .combine)
    }
    private var controls: some View {
        VStack(alignment: .leading, spacing: 8) {
            if market {
                HStack(spacing: 0) {
                    ForEach(ApolloChartRange.allCases, id: \.self) { item in
                        Button { range = item } label: {
                            Text(item.rawValue).font(.caption.weight(.semibold)).frame(maxWidth: .infinity, minHeight: 44)
                                .background(range == item ? theme.surface : .clear, in: RoundedRectangle(cornerRadius: 10))
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(range == item ? theme.accent : .clear, lineWidth: 1))
                        }.buttonStyle(.plain).foregroundStyle(range == item ? theme.accent : theme.muted)
                            .accessibilityLabel("\(item.rawValue) chart range")
                            .accessibilityAddTraits(range == item ? .isSelected : [])
                            .accessibilityIdentifier("chart-range-\(item.rawValue)")
                    }
                }
                HStack {
                    Text("\(visible.count) observed sessions").font(.caption).foregroundStyle(theme.muted)
                    Spacer()
                    Menu {
                        Button("Close line") { candles = false }
                        Button("Candles") { candles = true }.disabled(!hasCandles)
                    } label: {
                        Label(candles ? "Candles" : "Close line", systemImage: "slider.horizontal.3")
                            .font(.caption.weight(.semibold)).frame(minHeight: 44)
                    }.foregroundStyle(theme.accent).accessibilityIdentifier("chart-style")
                }
            }
        }
    }
    private var pricePlot: some View {
        Chart {
            ForEach(visible) { point in
                if candles && hasCandles {
                    if point.observation.hasCandle {
                        RuleMark(x: .value("Session", x(point)), yStart: .value("Low", point.observation.low!), yEnd: .value("High", point.observation.high!))
                            .foregroundStyle(candleColor(point)).lineStyle(StrokeStyle(lineWidth: 1))
                        BarMark(x: .value("Session", x(point)), yStart: .value("Open or close", min(point.observation.open!, point.observation.close)), yEnd: .value("Close or open", max(point.observation.open!, point.observation.close)), width: .fixed(6))
                            .foregroundStyle(candleColor(point))
                    }
                } else {
                    LineMark(x: .value("Observation", x(point)), y: .value("Close", point.observation.close), series: .value("Segment", point.segment))
                        .foregroundStyle(theme.accent).lineStyle(StrokeStyle(lineWidth: 2))
                        .interpolationMethod(.linear)
                    if visible.count == 1 { PointMark(x: .value("Observation", x(point)), y: .value("Close", point.observation.close)).foregroundStyle(theme.accent) }
                }
            }
            ForEach(activeLines) { line in
                ForEach(visible.filter { line.values[$0.id] != nil }) { point in
                    LineMark(x: .value("Observation", x(point)), y: .value(line.indicator.rawValue, line.values[point.id]!), series: .value("Indicator", line.indicator.rawValue + "-\(point.segment)"))
                        .foregroundStyle(indicatorColor(line.indicator))
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: line.indicator == .ema20 ? [2, 3] : [6, 3]))
                        .interpolationMethod(.linear)
                }
            }
            if let selected, selectedX != nil {
                RuleMark(x: .value("Selected", x(selected))).foregroundStyle(theme.muted.opacity(0.6))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                PointMark(x: .value("Selected", x(selected)), y: .value("Close", selected.observation.close))
                    .foregroundStyle(theme.text).symbolSize(35)
            }
        }
        .chartXScale(domain: domain).chartYScale(domain: yDomain)
        .chartXAxis { AxisMarks(values: .automatic(desiredCount: 3)) { item in
            AxisGridLine().foregroundStyle(theme.muted.opacity(0.1))
            AxisValueLabel { if let value = item.as(Double.self) { Text(axisLabel(value)).foregroundStyle(theme.muted).font(.caption2) } }
        } }
        .chartYAxis { AxisMarks(position: .trailing, values: .automatic(desiredCount: 4)) { item in
            AxisGridLine().foregroundStyle(theme.muted.opacity(0.16))
            AxisValueLabel { if let value = item.as(Double.self) { Text(value.formatted(.number.notation(.compactName))).foregroundStyle(theme.muted).font(.caption2) } }
        } }
        .chartXSelection(value: $selectedX)
        .frame(height: 210)
        .accessibilityLabel("\(series.symbol) \(market ? "historical price" : "demo scenario") chart")
        .accessibilityValue(selected.map { pointLabel($0) + ", " + value($0.observation.close) } ?? "No observations")
        .accessibilityAdjustableAction { direction in
            let current = selected?.id ?? visible.last?.id ?? 0
            let index = visible.firstIndex { $0.id == current } ?? 0
            switch direction {
            case .increment: selectedX = x(visible[min(index + 1, visible.count - 1)])
            case .decrement: selectedX = x(visible[max(index - 1, 0)])
            @unknown default: break
            }
        }
        .accessibilityIdentifier("chart-price-plot")
        .overlay(alignment: .bottomLeading) {
            // Selection feedback lives above the plot, avoiding tooltip clipping on narrow phones.
            EmptyView()
        }
    }
    private var volumePlot: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("VOLUME").font(.caption2.weight(.semibold)).tracking(1).foregroundStyle(theme.muted)
            Chart(volumes) { point in
                BarMark(x: .value("Session", x(point)), y: .value("Volume", validVolume(point)!), width: .fixed(5))
                    .foregroundStyle(theme.muted.opacity(0.55))
            }.chartXScale(domain: domain).chartXAxis(.hidden)
                .chartYAxis { AxisMarks(position: .trailing, values: .automatic(desiredCount: 2)) { item in
                    AxisValueLabel { if let value = item.as(Double.self) { Text(value.formatted(.number.notation(.compactName))).font(.caption2).foregroundStyle(theme.muted) } }
                } }.frame(height: 48).accessibilityLabel("Supplied session volume")
        }
    }
    private var indicatorControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) { indicatorButtons }
                VStack(alignment: .leading, spacing: 4) { indicatorButtons }
            }
            ForEach(activeLines) { line in
                HStack(alignment: .top, spacing: 8) {
                    Circle().fill(indicatorColor(line.indicator)).frame(width: 6, height: 6).padding(.top, 5)
                    Text(line.values.isEmpty ? "\(line.indicator.rawValue): unavailable — needs \(line.indicator.period) consecutive observed closes in this segment." : line.indicator.explanation)
                        .font(.caption).foregroundStyle(theme.muted)
                }
            }
            Button { withAnimation(reduceMotion ? nil : .easeOut(duration: 0.15)) { showMethods.toggle() } } label: {
                Label(showMethods ? "Hide chart methods" : "How to read this chart", systemImage: "info.circle")
                    .font(.caption).frame(minHeight: 44)
            }.foregroundStyle(theme.accent)
            if showMethods {
                Text("Press and drag to inspect an observation. VoiceOver: swipe up or down on the chart. Ranges end at the last cached session, not today. A session is one supplied observation; missing market days are not filled. Indicators use the full available history and restart after a known data gap. \(points.count) valid observations available. Candles need open, high, low and close; bars need supplied volume. These summaries do not predict prices or tell you when to buy.")
                    .font(.caption).foregroundStyle(theme.muted).transition(.opacity)
            }
        }
    }
    @ViewBuilder private var indicatorButtons: some View {
        ForEach(ApolloChartIndicator.allCases, id: \.self) { item in
            Button {
                if indicators.contains(item) { indicators.remove(item) } else { indicators.insert(item) }
            } label: {
                Text(item.rawValue).font(.caption.weight(.semibold)).padding(.horizontal, 12).frame(minHeight: 44)
                    .background(indicators.contains(item) ? theme.surface : .clear, in: Capsule())
                    .overlay(Capsule().stroke(theme.muted.opacity(0.25), lineWidth: 1))
            }.buttonStyle(.plain).foregroundStyle(indicators.contains(item) ? indicatorColor(item) : theme.muted)
                .accessibilityLabel("\(item.rawValue) indicator")
                .accessibilityValue(indicators.contains(item) ? "On" : "Off")
                .accessibilityIdentifier("chart-indicator-\(item.rawValue)")
        }
    }
    private var provenance: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(market ? (series.isStale ? "Stale cached data · not live" : "Cached daily data · not live") : "Demo data · no market quote", systemImage: "clock")
                .font(.caption.weight(.semibold)).foregroundStyle(theme.caution)
            Text(series.source).font(.caption).foregroundStyle(theme.muted)
            Text("As of: \(series.asOf ?? "unknown")").font(.caption2).foregroundStyle(theme.muted)
            if let fetched = series.fetchedAt { Text("Retrieved: \(fetched)").font(.caption2).foregroundStyle(theme.muted) }
            if market, let url = series.sourceURL, ["http", "https"].contains(url.scheme?.lowercased() ?? "") {
                Link(destination: url) { Label("Open price source", systemImage: "arrow.up.right").font(.caption.weight(.semibold)).frame(minHeight: 44) }
                    .foregroundStyle(theme.accent)
            }
        }.accessibilityIdentifier("chart-provenance")
    }
    private func x(_ point: ApolloChartPoint) -> Double { market ? point.observation.date!.timeIntervalSince1970 : Double(point.id) }
    private func number(_ value: Double) -> String { value.formatted(.number.precision(.fractionLength(2))) }
    private func value(_ value: Double) -> String { market ? value.formatted(.currency(code: series.currency)) : number(value) }
    private func candleColor(_ point: ApolloChartPoint) -> Color { point.observation.close >= (point.observation.open ?? point.observation.close) ? theme.accent : theme.caution }
    private func indicatorColor(_ indicator: ApolloChartIndicator) -> Color { indicator == .sma20 ? theme.text : indicator == .sma50 ? theme.caution : theme.accent }
    private func validVolume(_ point: ApolloChartPoint) -> Double? {
        guard market, let volume = point.observation.volume, volume.isFinite, volume >= 0 else { return nil }; return volume
    }
    private func pointLabel(_ point: ApolloChartPoint) -> String {
        market ? day(point.observation.date!) : "Scenario observation \(point.id + 1)"
    }
    private func axisLabel(_ value: Double) -> String {
        market ? day(Date(timeIntervalSince1970: value), short: true) : "\(Int(value.rounded()) + 1)"
    }
    private func day(_ date: Date, short: Bool = false) -> String {
        let formatter = DateFormatter(); formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0); formatter.dateFormat = short ? "MMM d" : "MMM d, yyyy"
        return formatter.string(from: date)
    }
}

private struct IndicatorLine: Identifiable {
    let indicator: ApolloChartIndicator
    let values: [Int: Double]
    var id: String { indicator.rawValue }
}
