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
    public let context: ApolloChartContext
    private let expanded: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var range: ApolloChartRange = .all
    @State private var candles = false
    @State private var indicators: Set<ApolloChartIndicator> = []
    @State private var selectedX: Double?
    @State private var showMethods = false
    @State private var interval: ApolloChartInterval = .daily
    @State private var zoom = 1.0
    @State private var scrollX = 0.0
    @State private var panning = false
    @State private var showExpanded = false
    @State private var pinchStart: Double?
    @State private var selectedEvent: String?
    @State private var showEarnings = true
    @State private var showAgreements = true

    public init(series: ApolloChartSeries, option: ApolloOptionContract? = nil,
                theme: ApolloChartTheme = .init(), context: ApolloChartContext = .init(), expanded: Bool = false) {
        self.series = series; self.option = option; self.theme = theme; self.context = context; self.expanded = expanded
    }
    private var dataSeries: ApolloChartSeries { context.underlyingSeries ?? series }
    private var displaySeries: ApolloChartSeries { ApolloAdvancedChartMath.series(dataSeries, interval: interval) }
    private var points: [ApolloChartPoint] { ApolloChartMath.points(in: displaySeries) }
    private var showPrice: Bool { ![.bond, .strategy].contains(context.category) && !(context.category == .option && dataSeries.basis == .demoScenario) }
    private var viewportLength: Double { max(market ? 86_400.0 : 1.0, (domain.upperBound - domain.lowerBound) / zoom) }
    private var rsiValues: [Int: Double] { ApolloAdvancedChartMath.rsi(points) }
    private var visibleEvents: [ApolloChartEvent] {
        context.events.filter { event in
            event.symbol == dataSeries.symbol && ["http", "https"].contains(event.sourceURL.scheme?.lowercased() ?? "") && event.sourceURL.host != nil && ((event.kind.lowercased() == "earnings" && showEarnings) || (["contract", "agreement"].contains(event.kind.lowercased()) && showAgreements))
        }.sorted { $0.date < $1.date }
    }
    private var visible: [ApolloChartPoint] { ApolloChartMath.visible(points, range: range, basis: dataSeries.basis) }
    private var selected: ApolloChartPoint? {
        guard let selectedX else { return visible.last }
        return visible.min { abs(x($0) - selectedX) < abs(x($1) - selectedX) }
    }
    private var market: Bool { dataSeries.basis == .cachedMarket }
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
        ApolloChartIndicator.allCases.filter { market && $0 != .rsi14 && indicators.contains($0) }.map { item in
            let all = ApolloChartMath.indicator(item, points: points)
            let ids = Set(visible.map(\.id))
            return IndicatorLine(indicator: item, values: all.filter { ids.contains($0.key) })
        }
    }
    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if showPrice {
            if context.category == .option, context.underlyingSeries != nil {
                Text("Underlying history · separate from option premium and expiry payoff").font(.caption.weight(.semibold)).foregroundStyle(theme.muted)
            }
            header
            if visible.isEmpty {
                Label("No chart observations available", systemImage: "chart.xyaxis.line")
                    .font(.subheadline).foregroundStyle(theme.muted).frame(maxWidth: .infinity, minHeight: 120)
                Text("This asset has no verified price history here. Review its allocation or source evidence below.")
                    .font(.caption).foregroundStyle(theme.muted)
            } else {
                controls
                pricePlot
                observationReadout
                if market && indicators.contains(.rsi14) { rsiPlot }
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
            if market { eventTimeline; exactTable }
            } else if context.category == .option {
                Text("No verified option premium history supplied. The expiry payoff below is a sensitivity calculation, not a market-price chart.").font(.caption).foregroundStyle(theme.muted)
            }
            if let option { ApolloOptionPayoffView(contract: option, theme: theme) }
            else if context.category == .option { Text("Expiry payoff unavailable: valid contract terms are required.").font(.caption).foregroundStyle(theme.caution) }
            ApolloCategoryChartsView(context: context, series: dataSeries, theme: theme)
        }
        .foregroundStyle(theme.text)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("apollo-chart")
        .onAppear { resetViewport() }
        .onChange(of: range) { _, _ in selectedX = nil; resetViewport() }
        .onChange(of: interval) { _, _ in selectedX = nil; resetViewport() }
        .onChange(of: zoom) { _, _ in resetViewport() }
        .onChange(of: dataSeries) { _, _ in selectedX = nil; range = .all; indicators = []; candles = false; selectedEvent = nil; resetViewport() }
        .sheet(isPresented: $showExpanded) {
            NavigationStack {
                ScrollView { expandedChart.padding(20) }
                    .background(theme.surface).navigationTitle(dataSeries.symbol + " chart").navigationBarTitleDisplayMode(.inline)
                    .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { showExpanded = false } } }
            }.tint(theme.accent)
        }
    }
    private var observationReadout: some View {
        VStack(alignment: .leading, spacing: 3) {
            if let selected {
                Text(selectedX == nil ? "Latest observation" : "Selected observation")
                    .font(.caption2.weight(.semibold)).foregroundStyle(theme.muted)
                Text("\(pointLabel(selected)) · \(value(selected.observation.close))")
                    .font(.subheadline.weight(.semibold)).monospacedDigit()
                    .fixedSize(horizontal: false, vertical: true)
                if let volume = validVolume(selected) {
                    Text("Volume \(volume.formatted(.number.notation(.compactName)))")
                        .font(.caption2).foregroundStyle(theme.muted)
                }
            }
        }.accessibilityElement(children: .combine).accessibilityIdentifier("chart-inline-observation")
    }
    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(market ? "PRICE HISTORY" : "DEMO SCENARIO").font(.caption.weight(.semibold)).tracking(1)
                Spacer()
                Text(dataSeries.symbol).font(.caption.weight(.semibold)).lineLimit(1)
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
                advancedControls
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
                    Text("\(visible.count) \(interval == .weekly ? "observed weeks" : "observed sessions")").font(.caption).foregroundStyle(theme.muted)
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
    private var expandedChart: AnyView {
        var view = ApolloChartView(series: series, option: option, theme: theme, context: context, expanded: true)
        view._range = State(initialValue: range)
        view._interval = State(initialValue: interval)
        view._candles = State(initialValue: candles)
        view._indicators = State(initialValue: indicators)
        view._zoom = State(initialValue: zoom)
        view._panning = State(initialValue: panning)
        view._selectedX = State(initialValue: selectedX)
        return AnyView(view)
    }
    private func resetViewport() {
        scrollX = max(domain.lowerBound, domain.upperBound - viewportLength)
    }
    private var advancedControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Picker("Candle interval", selection: $interval) {
                    ForEach(ApolloChartInterval.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }.pickerStyle(.segmented).frame(maxWidth: 180).accessibilityIdentifier("chart-interval")
                Spacer()
                if !expanded {
                    Button { showExpanded = true } label: { Label("Expand", systemImage: "arrow.up.left.and.arrow.down.right").font(.caption.weight(.semibold)).frame(minHeight: 44) }
                        .accessibilityIdentifier("chart-expand")
                }
            }
            HStack(spacing: 12) {
                Button { panning.toggle() } label: {
                    Label(panning ? "Pan" : "Inspect", systemImage: panning ? "hand.draw" : "scope").font(.caption.weight(.semibold)).frame(minHeight: 44)
                }.accessibilityIdentifier("chart-interaction-mode")
                    .accessibilityValue(panning ? "Pan: drag to move history, tap to select" : "Inspect: drag to select an observation")
                Spacer()
                Button { zoom = max(1, zoom / 1.5) } label: { Image(systemName: "minus.magnifyingglass").frame(width: 44, height: 44).contentShape(Rectangle()) }
                    .buttonStyle(.plain)
                    .disabled(zoom <= 1).accessibilityLabel("Zoom out").accessibilityIdentifier("chart-zoom-out")
                Text(zoom.formatted(.number.precision(.fractionLength(1))) + "×").font(.caption).monospacedDigit()
                Button { zoom = min(12, zoom * 1.5) } label: { Image(systemName: "plus.magnifyingglass").frame(width: 44, height: 44).contentShape(Rectangle()) }
                    .buttonStyle(.plain)
                    .disabled(zoom >= 12).accessibilityLabel("Zoom in").accessibilityIdentifier("chart-zoom-in")
            }
            Text("Pinch to zoom · \(panning ? "drag to pan; tap to inspect" : "drag to inspect; switch to Pan to move history")").font(.caption2).foregroundStyle(theme.muted)
            if let first = points.first?.observation.date, let last = points.last?.observation.date {
                Text("Available: \(day(first))–\(day(last)). Ranges use only these observations.").font(.caption2).foregroundStyle(theme.muted)
            }
        }.foregroundStyle(theme.accent)
    }
    private var rsiPlot: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("RSI 14 · selected candle interval").font(.caption.weight(.semibold)).foregroundStyle(theme.muted)
            if rsiValues.isEmpty {
                Text("Needs 15 consecutive observed closes in this interval.").font(.caption).foregroundStyle(theme.muted)
            } else {
                Chart {
                    RuleMark(y: .value("Reference 70", 70)).foregroundStyle(theme.caution.opacity(0.5)).lineStyle(.init(lineWidth: 1, dash: [3, 3]))
                    RuleMark(y: .value("Reference 30", 30)).foregroundStyle(theme.muted.opacity(0.5)).lineStyle(.init(lineWidth: 1, dash: [3, 3]))
                    ForEach(visible.filter { rsiValues[$0.id] != nil }) { point in
                        LineMark(x: .value("Observation", x(point)), y: .value("RSI", rsiValues[point.id]!), series: .value("Segment", point.segment)).foregroundStyle(theme.accent)
                    }
                }.chartXScale(domain: domain).chartYScale(domain: 0...100).chartXAxis(.hidden)
                    .chartScrollableAxes(panning ? .horizontal : []).chartXVisibleDomain(length: viewportLength).chartScrollPosition(x: $scrollX)
                    .frame(height: expanded ? 120 : 90).accessibilityIdentifier("chart-rsi-plot")
                if let selected, let value = rsiValues[selected.id] {
                    Text("RSI: \(value.formatted(.number.precision(.fractionLength(1)))) · \(pointLabel(selected))").font(.caption).monospacedDigit()
                }
            }
            Text("30/70 are reference levels, not buy or sell instructions.").font(.caption2).foregroundStyle(theme.muted)
        }
    }
    private var eventTimeline: some View {
        DisclosureGroup("Earnings and source events") {
            VStack(alignment: .leading, spacing: 10) {
                Toggle("Earnings events", isOn: $showEarnings).font(.caption).accessibilityIdentifier("chart-events-earnings")
                Toggle("Agreement events", isOn: $showAgreements).font(.caption).accessibilityIdentifier("chart-events-agreements")
                if visibleEvents.isEmpty {
                    Text("No matching cached source events supplied. This does not establish that no events occurred.").font(.caption).foregroundStyle(theme.muted)
                }
                ForEach(visibleEvents) { event in
                    VStack(alignment: .leading, spacing: 5) {
                        Button {
                            selectedEvent = event.id
                            if let date = ApolloAdvancedChartMath.eventSession(event, series: dataSeries, interval: interval) {
                                selectedX = date.timeIntervalSince1970
                                scrollX = max(domain.lowerBound, min(domain.upperBound - viewportLength, date.timeIntervalSince1970 - viewportLength / 2))
                            }
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(day(event.date) + " · " + event.kind.capitalized).font(.caption2)
                                Text(event.title).font(.subheadline.weight(.semibold)).multilineTextAlignment(.leading)
                            }.frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        }.accessibilityIdentifier("chart-event-\(event.id)")
                        if selectedEvent == event.id {
                            Text(event.summary).font(.caption).foregroundStyle(theme.muted)
                            if ["http", "https"].contains(event.sourceURL.scheme?.lowercased() ?? "") {
                                Link("Open original source", destination: event.sourceURL).font(.caption).frame(minHeight: 44)
                            }
                            if ApolloAdvancedChartMath.eventSession(event, series: dataSeries, interval: interval) == nil {
                                Text("Outside available chart history; no marker inferred.").font(.caption2).foregroundStyle(theme.muted)
                            }
                        }
                    }
                }
                Text("Publication/filing dates map to the next supplied session. Weekly markers use that session's observed week. Release time and price causation are unknown. Agreement markers do not establish a contract win or loss.").font(.caption).foregroundStyle(theme.muted)
            }.padding(.top, 8)
        }.font(.caption).tint(theme.accent).accessibilityElement(children: .contain).accessibilityIdentifier("chart-events")
    }
    private var exactTable: some View {
        DisclosureGroup("Exact OHLCV · latest 20 observed bars") {
            VStack(alignment: .leading, spacing: 10) {
                Text(interval == .weekly ? "Weekly aggregation; first/last weeks may be partial." : "Saved daily observations; not live.").font(.caption).foregroundStyle(theme.muted)
                ForEach(Array(points.suffix(20).reversed())) { point in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(pointLabel(point)).font(.caption.weight(.semibold))
                        Text("O \(point.observation.open.map(number) ?? "—") · H \(point.observation.high.map(number) ?? "—") · L \(point.observation.low.map(number) ?? "—")")
                        Text("C \(number(point.observation.close)) · Volume \(validVolume(point).map { $0.formatted(.number) } ?? "—")")
                    }.font(.caption2).monospacedDigit().fixedSize(horizontal: false, vertical: true).accessibilityElement(children: .combine)
                }
            }.padding(.top, 8)
        }.font(.caption).tint(theme.accent).accessibilityIdentifier("chart-exact-table")
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
            ForEach(visibleEvents) { event in
                if let date = ApolloAdvancedChartMath.eventSession(event, series: dataSeries, interval: interval),
                   let point = visible.first(where: { $0.observation.date == date }) {
                    PointMark(x: .value("Source event session", x(point)), y: .value("Event anchor close", point.observation.close))
                        .foregroundStyle(event.kind.lowercased() == "earnings" ? theme.accent : theme.caution)
                        .symbolSize(selectedEvent == event.id ? 110 : 55)
                        .annotation(position: .top) { Text(event.kind.lowercased() == "earnings" ? "E" : "A").font(.caption2.bold()).foregroundStyle(theme.text) }
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
        .chartScrollableAxes(panning ? .horizontal : [])
        .chartXVisibleDomain(length: viewportLength)
        .chartScrollPosition(x: $scrollX)
        .chartGesture { proxy -> AnyGesture<Void> in
            if panning {
                return AnyGesture(SpatialTapGesture().onEnded { proxy.selectXValue(at: $0.location.x) }.map { _ in () })
            }
            return AnyGesture(DragGesture(minimumDistance: 0).onChanged { proxy.selectXValue(at: $0.location.x) }.map { _ in () })
        }
        .simultaneousGesture(MagnifyGesture().onChanged { value in
            if pinchStart == nil { pinchStart = zoom }
            zoom = min(12, max(1, (pinchStart ?? 1) * value.magnification))
        }.onEnded { _ in pinchStart = nil })
        .frame(height: expanded ? 340 : 220)
        .accessibilityLabel("\(dataSeries.symbol) \(market ? "historical price" : "demo scenario") chart")
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
    }
    private var volumePlot: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("VOLUME").font(.caption2.weight(.semibold)).tracking(1).foregroundStyle(theme.muted)
            Chart(volumes) { point in
                BarMark(x: .value("Session", x(point)), y: .value("Volume", validVolume(point)!), width: .fixed(5))
                    .foregroundStyle(theme.muted.opacity(0.55))
            }.chartXScale(domain: domain).chartXAxis(.hidden)
                .chartScrollableAxes(panning ? .horizontal : [])
                .chartXVisibleDomain(length: viewportLength).chartScrollPosition(x: $scrollX)
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
                Text("Inspect mode: press and drag to inspect an observation. Pan mode: drag the plot horizontally. Pinch or use zoom buttons to change visible history. VoiceOver: swipe up or down on the chart. Ranges end at the last cached session, not today. A session is one supplied observation; missing market days are not filled. Weekly candles aggregate supplied daily bars; the first and last weeks may be partial. Indicator periods count the selected interval's observed bars. Indicators use the full available history and restart after a known data gap. \(points.count) valid observations available. Candles need open, high, low and close; bars need supplied volume. These summaries do not predict prices or tell you when to buy.")
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
            Label(market ? (dataSeries.isStale ? "Stale cached data · not live" : "Cached daily data · not live") : "Demo data · no market quote", systemImage: "clock")
                .font(.caption.weight(.semibold)).foregroundStyle(theme.caution)
            Text(dataSeries.source).font(.caption).foregroundStyle(theme.muted)
            Text("As of: \(dataSeries.asOf ?? "unknown")").font(.caption2).foregroundStyle(theme.muted)
            if let fetched = dataSeries.fetchedAt { Text("Retrieved: \(fetched)").font(.caption2).foregroundStyle(theme.muted) }
            if market, let url = dataSeries.sourceURL, ["http", "https"].contains(url.scheme?.lowercased() ?? "") {
                Link(destination: url) { Label("Open price source", systemImage: "arrow.up.right").font(.caption.weight(.semibold)).frame(minHeight: 44) }
                    .foregroundStyle(theme.accent)
            }
        }.accessibilityIdentifier("chart-provenance")
    }
    private func x(_ point: ApolloChartPoint) -> Double { market ? point.observation.date!.timeIntervalSince1970 : Double(point.id) }
    private func number(_ value: Double) -> String { value.formatted(.number.precision(.fractionLength(2))) }
    private func value(_ value: Double) -> String { market ? value.formatted(.currency(code: dataSeries.currency)) : number(value) }
    private func candleColor(_ point: ApolloChartPoint) -> Color { point.observation.close >= (point.observation.open ?? point.observation.close) ? theme.accent : theme.caution }
    private func indicatorColor(_ indicator: ApolloChartIndicator) -> Color { indicator == .sma20 ? theme.text : indicator == .sma50 ? theme.caution : theme.accent }
    private func validVolume(_ point: ApolloChartPoint) -> Double? {
        guard market, let volume = point.observation.volume, volume.isFinite, volume >= 0 else { return nil }; return volume
    }
    private func pointLabel(_ point: ApolloChartPoint) -> String {
        market ? (interval == .weekly ? "Week \(day(point.observation.date!))–\(day(point.observation.endDate ?? point.observation.date!))" : day(point.observation.date!)) : "Scenario observation \(point.id + 1)"
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
