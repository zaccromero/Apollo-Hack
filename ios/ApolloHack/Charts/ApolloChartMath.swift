import Foundation

public struct ApolloChartPoint: Identifiable, Equatable, Sendable {
    public let id: Int
    public let observation: ApolloChartObservation
    public let segment: Int
}
public enum ApolloChartMath {
    /// Sort/deduplicate actual market dates. No calendar interpolation.
    public static func points(in series: ApolloChartSeries) -> [ApolloChartPoint] {
        var observations = series.observations
        if series.basis == .cachedMarket {
            var byDate: [Date: ApolloChartObservation] = [:]
            for row in observations { if let date = row.date, date.timeIntervalSince1970.isFinite { byDate[date] = row } }
            observations = byDate.keys.sorted().compactMap { byDate[$0] }
        }
        var segment = 0
        var result: [ApolloChartPoint] = []
        for row in observations {
            guard row.close.isFinite, row.close >= 0 else { segment += 1; continue }
            if row.startsNewSegment { segment += 1 }
            result.append(.init(id: result.count, observation: row, segment: segment))
        }
        return result
    }
    /// Calendar range anchored at latest observation, never today's date.
    public static func visible(_ points: [ApolloChartPoint], range: ApolloChartRange,
                               basis: ApolloChartBasis) -> [ApolloChartPoint] {
        guard basis == .cachedMarket, let days = range.days,
              let latest = points.last?.observation.endDate ?? points.last?.observation.date else { return points }
        let cutoff = latest.addingTimeInterval(-Double(days) * 86_400)
        return points.filter { ($0.observation.date ?? .distantPast) > cutoff }
    }
    /// Full observed-bar warm-up after first point or a known gap. No zero padding.
    public static func indicator(_ indicator: ApolloChartIndicator,
                                 points: [ApolloChartPoint]) -> [Int: Double] {
        if indicator == .rsi14 { return ApolloAdvancedChartMath.rsi(points) }
        let period = indicator.period
        var window: [Double] = []; var ema: Double?; var previousSegment: Int?
        var result: [Int: Double] = [:]
        for point in points {
            if previousSegment != point.segment { window = []; ema = nil }
            previousSegment = point.segment
            window.append(point.observation.close)
            if window.count > period { window.removeFirst() }
            guard window.count == period else { continue }
            let mean = window.reduce(0) { $0 + $1 / Double(period) }
            let value: Double
            if indicator == .ema20 {
                value = ema.map { $0 + (point.observation.close - $0) * (2 / Double(period + 1)) } ?? mean
                ema = value
            } else { value = mean }
            if value.isFinite { result[point.id] = value }
        }
        return result
    }
}
