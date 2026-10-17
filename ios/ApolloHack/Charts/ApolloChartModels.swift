import Foundation

/// Display values only; never executable paper prices. Known bad/missing observations restart indicators.
public struct ApolloChartObservation: Equatable, Sendable {
    public let date: Date?
    public let close: Double
    public let open: Double?
    public let high: Double?
    public let low: Double?
    public let volume: Double?
    public let startsNewSegment: Bool
    public init(date: Date? = nil, close: Double, open: Double? = nil, high: Double? = nil,
                low: Double? = nil, volume: Double? = nil, startsNewSegment: Bool = false) {
        self.date = date; self.close = close; self.open = open; self.high = high
        self.low = low; self.volume = volume; self.startsNewSegment = startsNewSegment
    }
    public var hasCandle: Bool {
        guard let open, let high, let low else { return false }
        return [open, high, low, close].allSatisfy { $0.isFinite && $0 >= 0 }
            && low <= min(open, close) && high >= max(open, close) && low <= high
    }
}
public enum ApolloChartBasis: String, Sendable { case cachedMarket, demoScenario }
public struct ApolloChartSeries: Equatable, Sendable {
    public let symbol: String
    public let currency: String
    public let observations: [ApolloChartObservation]
    public let basis: ApolloChartBasis
    public let source: String
    public let sourceURL: URL?
    public let asOf: String?
    public let fetchedAt: String?
    public let isStale: Bool
    public init(symbol: String, currency: String = "USD", observations: [ApolloChartObservation],
                basis: ApolloChartBasis, source: String, sourceURL: URL? = nil,
                asOf: String? = nil, fetchedAt: String? = nil, isStale: Bool = true) {
        self.symbol = symbol; self.currency = currency; self.observations = observations
        self.basis = basis; self.source = source; self.sourceURL = sourceURL
        self.asOf = asOf; self.fetchedAt = fetchedAt; self.isStale = isStale
    }
}
public enum ApolloChartRange: String, CaseIterable, Sendable {
    case week = "1W", month = "1M", quarter = "3M", year = "1Y", all = "All"
    var days: Int? {
        switch self { case .week: return 7; case .month: return 30; case .quarter: return 90
        case .year: return 365; case .all: return nil }
    }
}
public enum ApolloChartIndicator: String, CaseIterable, Sendable {
    case sma20 = "SMA 20", sma50 = "SMA 50", ema20 = "EMA 20"
    public var period: Int { self == .sma50 ? 50 : 20 }
    public var explanation: String {
        switch self {
        case .sma20: return "SMA 20 averages the last 20 observed closes equally."
        case .sma50: return "SMA 50 averages the last 50 observed closes equally."
        case .ema20: return "EMA 20 starts with a 20-close average, then gives each new close a 2/21 weight."
        }
    }
}
public enum ApolloOptionRight: String, Sendable { case call, put }
/// Fully paid LONG premium only. No exercise, fees, taxes, shorts or live valuation.
public struct ApolloOptionContract: Equatable, Sendable {
    public let underlying: String
    public let right: ApolloOptionRight
    public let strike: Decimal
    public let premiumPerShare: Decimal
    public let multiplier: Int
    public let contracts: Int
    public let expiry: String
    public let isDemo: Bool
    public init(underlying: String, right: ApolloOptionRight, strike: Decimal,
                premiumPerShare: Decimal, multiplier: Int, contracts: Int = 1,
                expiry: String, isDemo: Bool = true) {
        self.underlying = underlying; self.right = right; self.strike = strike
        self.premiumPerShare = premiumPerShare; self.multiplier = multiplier
        self.contracts = contracts; self.expiry = expiry; self.isDemo = isDemo
    }
    public var isValid: Bool {
        !strike.isNaN && !premiumPerShare.isNaN && strike > 0 && premiumPerShare >= 0
            && multiplier > 0 && contracts > 0 && !expiry.isEmpty && !maximumLoss.isNaN
    }
    public var maximumLoss: Decimal { premiumPerShare * Decimal(multiplier) * Decimal(contracts) }
    public var breakEven: Decimal { right == .call ? strike + premiumPerShare : strike - premiumPerShare }
    public func profit(atExpiryUnderlying price: Decimal) -> Decimal? {
        guard isValid, !price.isNaN, price >= 0 else { return nil }
        let intrinsic = max(0, right == .call ? price - strike : strike - price)
        let result = (intrinsic - premiumPerShare) * Decimal(multiplier) * Decimal(contracts)
        return result.isNaN ? nil : result
    }
}
