import SwiftUI

/// Read-only chart projection; execution prices and risk/order rules remain with Paper.
@MainActor struct ApolloChartBridge:View {
    let asset:ApolloAsset
    let detail:[String:Any]?
    var useBundledSnapshots:Bool = false
    private var effectiveDetail:[String:Any]? {
        if let detail{return detail}
        guard useBundledSnapshots,let url=Bundle.main.url(forResource:"chart-snapshots",withExtension:"json"),let data=try? Data(contentsOf:url),let object=try? JSONSerialization.jsonObject(with:data) as? [String:Any] else{return nil}
        return (object["assets"] as? [String:[String:Any]])?[asset.id]
    }
    var body:some View {
        ApolloChartView(series:series,option:option,theme:.blueOnLight)
    }
    private var series:ApolloChartSeries {
        if let detail=effectiveDetail,let quote=detail["quote"] as? [String:Any],let rows=detail["chart"] as? [[String:Any]] {
            let market = detail["is_demo"] as? Bool != true && quote["status"] as? String == "cached_daily_close"
            var observations:[ApolloChartObservation]=[],gap=false
            for row in rows {
                guard let close=number(row["close"]) else {gap=true;continue}
                let when=market ? day(row["date"] as? String) : nil
                if market && when == nil {gap=true;continue}
                observations.append(ApolloChartObservation(date:when,close:close,open:market ? number(row["open"]) : nil,high:market ? number(row["high"]) : nil,low:market ? number(row["low"]) : nil,volume:market ? number(row["volume"]) : nil,startsNewSegment:gap));gap=false
            }
            return ApolloChartSeries(symbol:asset.ticker,observations:observations,basis:market ? .cachedMarket : .demoScenario,source:(quote["note"] as? String ?? "Unknown chart provenance") + (self.detail == nil ? " Bundled public history; separate from DEMO paper execution prices and illustrative theses." : ""),sourceURL:(quote["source_url"] as? String).flatMap(URL.init(string:)),asOf:quote["as_of"] as? String,fetchedAt:quote["fetched_at"] as? String,isStale:quote["stale"] as? Bool ?? true)
        }
        let points=asset.kind == .strategy ? [] : asset.chart.map {ApolloChartObservation(close:$0)}
        return ApolloChartSeries(symbol:asset.ticker,observations:points,basis:.demoScenario,source:"Normalized educational DEMO scenario; not observed price history, a strategy track record or a forecast.")
    }
    private var option:ApolloOptionContract? {
        guard asset.kind == .option,
              let url=Bundle.main.url(forResource:"instrument-specs",withExtension:"json"),let data=try? Data(contentsOf:url),let registry=try? JSONSerialization.jsonObject(with:data) as? [String:Any],
              let assets=registry["assets"] as? [[String:Any]],let spec=assets.first(where:{$0["asset_id"] as? String == asset.id}),spec["kind"] as? String == "option",
              let terms=spec["option"] as? [String:Any],let underlying=terms["underlying_asset_id"] as? String,let rawRight=terms["right"] as? String,let right=ApolloOptionRight(rawValue:rawRight),
              let strikeText=terms["strike"] as? String,let strike=Decimal(string:strikeText),let expiry=terms["expires_at"] as? String,let multiplier=terms["multiplier"] as? Int,multiplier==asset.multiplier,(asset.expiry==expiry || asset.expiry==String(expiry.prefix(10))) else {return nil}
        return ApolloOptionContract(underlying:underlying,right:right,strike:strike,premiumPerShare:asset.price,multiplier:multiplier,expiry:expiry,isDemo:asset.isDemo)
    }
    private func number(_ raw:Any?) -> Double? {
        guard let text=raw as? String,let value=Double(text),value.isFinite,value>=0 else{return nil};return value
    }
    private func day(_ text:String?) -> Date? {
        guard let text else{return nil};let formatter=DateFormatter();formatter.calendar=Calendar(identifier:.gregorian);formatter.locale=Locale(identifier:"en_US_POSIX");formatter.timeZone=TimeZone(secondsFromGMT:0);formatter.dateFormat="yyyy-MM-dd";return formatter.date(from:text)
    }
}
