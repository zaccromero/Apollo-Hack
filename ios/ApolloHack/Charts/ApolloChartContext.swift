import Foundation

public enum ApolloChartCategory: String, Sendable {
    case generic, stock, etf, commodity, crypto, realEstate, option, stablecoin, bond, strategy
}
public enum ApolloChartInterval: String, CaseIterable, Sendable { case daily = "1D", weekly = "1W" }
public struct ApolloChartAllocation: Identifiable, Equatable, Sendable {
    public let name: String
    public let weight: Double
    public var id: String { name }
    public init(name: String, weight: Double) { self.name = name; self.weight = weight }
}
public struct ApolloChartEvent: Identifiable, Equatable, Sendable {
    public let id: String
    public let symbol: String
    public let date: Date
    public let kind: String
    public let title: String
    public let summary: String
    public let sourceURL: URL
    public init(id: String, symbol: String, date: Date, kind: String, title: String, summary: String, sourceURL: URL) {
        self.id = id; self.symbol = symbol; self.date = date; self.kind = kind
        self.title = title; self.summary = summary; self.sourceURL = sourceURL
    }
}
public struct ApolloFinancialValue: Identifiable, Equatable, Sendable {
    public let period: String
    public let value: Double
    public var id: String { period }
    public init(period: String, value: Double) { self.period = period; self.value = value }
}
public struct ApolloFinancialComparison: Identifiable, Equatable, Sendable {
    public let id: String
    public let symbol: String
    public let metric: String
    public let unit: String
    public let values: [ApolloFinancialValue]
    public let sourceLabel: String
    public let sourceURL: URL
    public let note: String
    public init(id: String, symbol: String, metric: String, unit: String, values: [ApolloFinancialValue], sourceLabel: String, sourceURL: URL, note: String) {
        self.id = id; self.symbol = symbol; self.metric = metric; self.unit = unit; self.values = values
        self.sourceLabel = sourceLabel; self.sourceURL = sourceURL; self.note = note
    }
}
public struct ApolloBondChartTerms: Equatable, Sendable {
    public let faceValue: Double
    public let annualCouponRate: Double
    public let couponFrequency: Int
    public let maturity: Date
    public let asOf: Date
    public init(faceValue: Double, annualCouponRate: Double, couponFrequency: Int, maturity: Date, asOf: Date) {
        self.faceValue = faceValue; self.annualCouponRate = annualCouponRate
        self.couponFrequency = couponFrequency; self.maturity = maturity; self.asOf = asOf
    }
}
/// Inject display data only. This module never fetches, changes a portfolio or executes an order.
public struct ApolloChartContext: Equatable, Sendable {
    public var category: ApolloChartCategory
    public var allocations: [ApolloChartAllocation]
    public var allocationSource: String?
    public var allocationSourceURL: URL?
    public var targetPeg: Double?
    public var bond: ApolloBondChartTerms?
    public var events: [ApolloChartEvent]
    public var financials: [ApolloFinancialComparison]
    public var underlyingSeries: ApolloChartSeries?
    public init(category: ApolloChartCategory = .generic, allocations: [ApolloChartAllocation] = [],
                allocationSource: String? = nil, allocationSourceURL: URL? = nil,
                targetPeg: Double? = nil, bond: ApolloBondChartTerms? = nil,
                events: [ApolloChartEvent] = [], financials: [ApolloFinancialComparison] = [],
                underlyingSeries: ApolloChartSeries? = nil) {
        self.category = category; self.allocations = allocations
        self.allocationSource = allocationSource; self.allocationSourceURL = allocationSourceURL
        self.targetPeg = targetPeg; self.bond = bond; self.events = events
        self.financials = financials; self.underlyingSeries = underlyingSeries
    }
}
