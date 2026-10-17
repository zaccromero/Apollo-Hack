import Foundation

public struct ApolloBondCashFlow: Identifiable, Equatable, Sendable {
    public let date: Date
    public let coupon: Double
    public let principal: Double
    public var id: Date { date }
}
public enum ApolloAdvancedChartMath {
    private static var calendar: Calendar {
        var calendar = Calendar(identifier: .iso8601); calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }
    public static func series(_ series: ApolloChartSeries, interval: ApolloChartInterval) -> ApolloChartSeries {
        guard interval == .weekly, series.basis == .cachedMarket else { return series }
        let points = ApolloChartMath.points(in: series)
        var groups: [[ApolloChartPoint]] = []
        for point in points {
            guard let date = point.observation.date else { continue }
            let week = calendar.dateInterval(of: .weekOfYear, for: date)?.start
            if let last = groups.last?.last, last.segment == point.segment,
               let lastDate = last.observation.date,
               calendar.dateInterval(of: .weekOfYear, for: lastDate)?.start == week {
                groups[groups.count - 1].append(point)
            } else { groups.append([point]) }
        }
        let rows = groups.enumerated().compactMap { index, group -> ApolloChartObservation? in
            guard let first = group.first, let last = group.last else { return nil }
            let complete = group.allSatisfy { $0.observation.hasCandle }
            let volumeComplete = group.allSatisfy { $0.observation.volume.map { $0.isFinite && $0 >= 0 } ?? false }
            return .init(date: first.observation.date, endDate: last.observation.date, close: last.observation.close,
                         open: complete ? first.observation.open : nil,
                         high: complete ? group.compactMap { $0.observation.high }.max() : nil,
                         low: complete ? group.compactMap { $0.observation.low }.min() : nil,
                         volume: volumeComplete ? group.reduce(0) { $0 + ($1.observation.volume ?? 0) } : nil,
                         startsNewSegment: first.observation.startsNewSegment || (index > 0 && groups[index - 1].last?.segment != first.segment))
        }
        return .init(symbol: series.symbol, currency: series.currency, observations: rows, basis: series.basis,
                     source: series.source, sourceURL: series.sourceURL, asOf: series.asOf, fetchedAt: series.fetchedAt, isStale: series.isStale)
    }
    /// Wilder RSI: fourteen changes require fifteen closes; restart after every known gap.
    public static func rsi(_ points: [ApolloChartPoint], period: Int = 14) -> [Int: Double] {
        guard period > 0 else { return [:] }
        var output: [Int: Double] = [:], previous: Double?, segment: Int?
        var gain = 0.0, loss = 0.0, count = 0
        for point in points {
            if segment != point.segment { previous = nil; gain = 0; loss = 0; count = 0 }
            segment = point.segment
            let close = point.observation.close
            defer { previous = close }
            guard let previous else { continue }
            let delta = close - previous; count += 1
            if count <= period {
                gain += max(delta, 0) / Double(period); loss += max(-delta, 0) / Double(period)
            } else {
                gain = (gain * Double(period - 1) + max(delta, 0)) / Double(period)
                loss = (loss * Double(period - 1) + max(-delta, 0)) / Double(period)
            }
            guard gain.isFinite, loss.isFinite else { gain = 0; loss = 0; count = 0; continue }
            guard count >= period else { continue }
            output[point.id] = loss == 0 ? (gain == 0 ? 50 : 100) : 100 - 100 / (1 + gain / loss)
        }
        return output
    }
    public static func eventSession(_ event: ApolloChartEvent, series: ApolloChartSeries, interval: ApolloChartInterval) -> Date? {
        guard event.symbol == series.symbol, ["http", "https"].contains(event.sourceURL.scheme?.lowercased() ?? ""),
              ["earnings", "contract", "agreement"].contains(event.kind.lowercased()) else { return nil }
        let points = ApolloChartMath.points(in: series)
        let day = calendar.startOfDay(for: event.date)
        guard let first = points.first?.observation.date, let last = points.last?.observation.date,
              day >= calendar.startOfDay(for: first), day <= calendar.startOfDay(for: last),
              let session = points.first(where: { ($0.observation.date ?? .distantPast) >= day })?.observation.date else { return nil }
        if interval == .daily { return session }
        let weekly = self.series(series, interval: .weekly).observations
        return weekly.last(where: { ($0.date ?? .distantFuture) <= session })?.date
    }
    /// Assumes regular coupon dates backward from maturity; no stubs, holidays, default or settlement.
    public static func cashFlows(_ terms: ApolloBondChartTerms) -> [ApolloBondCashFlow] {
        guard terms.faceValue.isFinite, terms.faceValue > 0, terms.annualCouponRate.isFinite,
              terms.annualCouponRate >= 0, [1, 2, 4, 12].contains(terms.couponFrequency),
              terms.maturity > terms.asOf else { return [] }
        let coupon = terms.faceValue * terms.annualCouponRate / Double(terms.couponFrequency)
        guard coupon.isFinite else { return [] }
        var date = terms.maturity, rows: [ApolloBondCashFlow] = []
        for _ in 0..<600 {
            guard date > terms.asOf else { return rows.sorted { $0.date < $1.date } }
            rows.append(.init(date: date, coupon: coupon, principal: date == terms.maturity ? terms.faceValue : 0))
            guard let next = calendar.date(byAdding: .month, value: -12 / terms.couponFrequency, to: date) else { return [] }
            date = next
        }
        return [] // Reject unbounded or unsupported schedules rather than presenting a truncated maturity.
    }
    public static func bondPresentValue(_ terms: ApolloBondChartTerms, annualYield: Double) -> Double? {
        guard annualYield.isFinite, annualYield >= 0 else { return nil }
        let flows = cashFlows(terms); guard !flows.isEmpty else { return nil }
        let value = flows.reduce(0.0) { total, flow in
            let years = flow.date.timeIntervalSince(terms.asOf) / (365.25 * 86_400)
            return total + (flow.coupon + flow.principal) / pow(1 + annualYield / Double(terms.couponFrequency), years * Double(terms.couponFrequency))
        }
        return value.isFinite ? value : nil
    }
}
