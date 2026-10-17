import SwiftUI
import CoreFoundation

/// Research display only. Paper registry, execution quotes and saved accounts are never changed.
@MainActor struct ApolloChartBridge: View {
    let asset: ApolloAsset
    let detail: [String: Any]?
    var useBundledSnapshots: Bool = false

    var body: some View {
        ApolloChartView(series: series, option: option, theme: .blueOnLight, context: context)
    }
    private var referenceID: String { asset.kind == .stablecoin ? "USDC-USD" : asset.id }
    private var effectiveDetail: [String: Any]? {
        if let detail { return detail }
        guard useBundledSnapshots else { return nil } // No silent connected-mode fallback.
        return ChartDisplayBundles.histories[referenceID]
    }
    private var series: ApolloChartSeries {
        if let source = effectiveDetail { return makeSeries(source, fallbackSymbol: asset.ticker) }
        let points = [.strategy, .bond, .stablecoin, .option].contains(asset.kind) ? [] : asset.chart.map { ApolloChartObservation(close: $0) }
        return .init(symbol: asset.ticker, observations: points, basis: .demoScenario,
                     source: "Illustrative educational scenario only; no market history, strategy record or forecast.")
    }
    private func makeSeries(_ source: [String: Any], fallbackSymbol: String) -> ApolloChartSeries {
        let quote = source["quote"] as? [String: Any] ?? [:]
        let market = source["is_demo"] as? Bool != true && quote["status"] as? String == "cached_daily_close"
        var rows: [ApolloChartObservation] = [], gap = false
        for row in source["chart"] as? [[String: Any]] ?? [] {
            guard let close = nonnegative(row["close"]) else { gap = true; continue }
            let when = market ? date(row["date"] as? String) : nil
            if market && when == nil { gap = true; continue }
            rows.append(.init(date: when, close: close, open: market ? nonnegative(row["open"]) : nil,
                              high: market ? nonnegative(row["high"]) : nil, low: market ? nonnegative(row["low"]) : nil,
                              volume: market ? nonnegative(row["volume"]) : nil, startsNewSegment: gap))
            gap = false
        }
        let symbol = source["asset_id"] as? String ?? source["symbol"] as? String ?? fallbackSymbol
        let referenceNotice = asset.kind == .stablecoin ? " USDC market reference, separate from the fictional demo token; no redemption or reserve guarantee." : ""
        return .init(symbol: symbol, observations: rows, basis: market ? .cachedMarket : .demoScenario,
                     source: (quote["note"] as? String ?? "Chart provenance unavailable.") + referenceNotice + " Separate from paper execution quotes.",
                     sourceURL: publicURL(quote["source_url"]), asOf: quote["as_of"] as? String,
                     fetchedAt: quote["fetched_at"] as? String, isStale: quote["stale"] as? Bool ?? true)
    }
    private var context: ApolloChartContext {
        let category: ApolloChartCategory
        switch asset.kind {
        case .stock: category = .stock
        case .etf: category = .etf
        case .commodity: category = .commodity
        case .crypto: category = .crypto
        case .realEstate: category = .realEstate
        case .option: category = .option
        case .stablecoin: category = .stablecoin
        case .bond: category = .bond
        case .strategy: category = .strategy
        }
        var underlying: ApolloChartSeries?
        if asset.kind == .option, useBundledSnapshots, let id = asset.optionTerms?.underlyingAssetID,
           let source = ChartDisplayBundles.histories[id] {
            let candidate = makeSeries(source, fallbackSymbol: id)
            if candidate.basis == .cachedMarket { underlying = candidate }
        }
        let symbol = underlying?.symbol ?? series.symbol
        let events = (ChartDisplayBundles.events[symbol]?["events"] as? [[String: Any]] ?? []).compactMap { row -> ApolloChartEvent? in
            guard row["symbol"] as? String == symbol, let id = row["id"] as? String,
                  let when = date(row["date"] as? String), let kind = row["kind"] as? String,
                  ["earnings", "contract", "agreement"].contains(kind), let title = row["title"] as? String,
                  let summary = row["summary"] as? String, let url = publicURL(row["sourceURL"]) else { return nil }
            return .init(id: id, symbol: symbol, date: when, kind: kind, title: title, summary: summary, sourceURL: url)
        }
        let financials = ChartDisplayBundles.financials.compactMap { row -> ApolloFinancialComparison? in
            guard row["symbol"] as? String == symbol, let id = row["id"] as? String,
                  let metric = row["metric"] as? String, let unit = row["unit"] as? String,
                  let sourceLabel = row["sourceLabel"] as? String, let url = publicURL(row["sourceURL"]),
                  let note = row["note"] as? String, let rawValues = row["values"] as? [[String: Any]] else { return nil }
            let values = rawValues.compactMap { item -> ApolloFinancialValue? in
                guard let period = item["period"] as? String, let value = numeric(item["value"]) else { return nil }
                return .init(period: period, value: value)
            }
            guard values.count == rawValues.count, !values.isEmpty else { return nil }
            return .init(id: id, symbol: symbol, metric: metric, unit: unit, values: values, sourceLabel: sourceLabel, sourceURL: url, note: note)
        }
        var allocations: [ApolloChartAllocation] = []
        if asset.kind == .strategy,
           let row = (ChartDisplayBundles.registry["strategies"] as? [[String: Any]])?.first(where: { $0["strategy_id"] as? String == asset.id }) {
            allocations = (row["allocations"] as? [[String: Any]] ?? []).compactMap {
                guard let name = $0["asset_id"] as? String, let weight = nonnegative($0["weight"]), weight <= 1 else { return nil }
                return .init(name: name, weight: weight)
            }
        }
        var bond: ApolloBondChartTerms?
        if let terms = asset.bond, let maturity = date(terms.maturesAt), let asOf = date(asset.quoteAsOf) {
            bond = .init(faceValue: double(terms.faceValue), annualCouponRate: double(terms.annualCouponRate),
                         couponFrequency: terms.couponFrequency, maturity: maturity, asOf: asOf)
        }
        return .init(category: category, allocations: allocations,
                     allocationSource: asset.kind == .strategy ? "Canonical fictional allocation; no creator performance record." : nil,
                     targetPeg: asset.stablecoin.map { double($0.targetPeg) }, bond: bond,
                     events: events, financials: financials, underlyingSeries: underlying)
    }
    private var option: ApolloOptionContract? {
        guard asset.kind == .option,
              let spec = (ChartDisplayBundles.registry["assets"] as? [[String: Any]])?.first(where: { $0["asset_id"] as? String == asset.id }),
              spec["kind"] as? String == "option", let terms = spec["option"] as? [String: Any],
              let underlying = terms["underlying_asset_id"] as? String, let rawRight = terms["right"] as? String,
              let right = ApolloOptionRight(rawValue: rawRight), let strikeText = terms["strike"] as? String,
              let strike = Decimal(string: strikeText), let expiry = terms["expires_at"] as? String,
              let multiplier = terms["multiplier"] as? Int, multiplier == asset.multiplier,
              asset.expiry == expiry || asset.expiry == String(expiry.prefix(10)) else { return nil }
        return .init(underlying: underlying, right: right, strike: strike, premiumPerShare: asset.price,
                     multiplier: multiplier, expiry: expiry, isDemo: asset.isDemo)
    }
    private func numeric(_ raw: Any?) -> Double? {
        if let value = raw as? NSNumber {
            guard CFGetTypeID(value) != CFBooleanGetTypeID(), value.doubleValue.isFinite else { return nil }
            return value.doubleValue
        }
        guard let text = raw as? String, let value = Double(text), value.isFinite else { return nil }
        return value
    }
    private func nonnegative(_ raw: Any?) -> Double? { numeric(raw).flatMap { $0 >= 0 ? $0 : nil } }
    private func double(_ value: Decimal) -> Double { NSDecimalNumber(decimal: value).doubleValue }
    private func publicURL(_ raw: Any?) -> URL? {
        guard let text = raw as? String, let url = URL(string: text),
              ["https", "http"].contains(url.scheme?.lowercased() ?? ""), url.host != nil,
              url.user == nil, url.password == nil else { return nil }
        return url
    }
    private func date(_ text: String?) -> Date? {
        guard let text else { return nil }
        let iso = ISO8601DateFormatter()
        if let value = iso.date(from: text) { return value }
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let value = iso.date(from: text) { return value }
        guard text.count == 10 else { return nil }
        let formatter = DateFormatter(); formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX"); formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"; formatter.isLenient = false
        return formatter.date(from: text)
    }
}
/// Immutable public bundle inputs, read once; no service or account fallback.
private enum ChartDisplayBundles {
    static let registry = load("instrument-specs")
    static let histories = load("chart-snapshots")["assets"] as? [String: [String: Any]] ?? [:]
    static let events = load("chart-source-events")["symbols"] as? [String: [String: Any]] ?? [:]
    static let financials = load("chart-financials")["financials"] as? [[String: Any]] ?? []
    private static func load(_ name: String) -> [String: Any] {
        guard let url = Bundle.main.url(forResource: name, withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let value = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [:] }
        return value
    }
}
