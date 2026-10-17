import Foundation

public struct ApolloOptionTerms: Codable, Hashable {
    public let underlyingAssetID: String
    public let right: String
    public let strike: Decimal
    public let expiresAt: String
    public let multiplier: Int
    public init(underlyingAssetID: String, right: String, strike: Decimal, expiresAt: String, multiplier: Int) { self.underlyingAssetID = underlyingAssetID; self.right = right; self.strike = strike; self.expiresAt = expiresAt; self.multiplier = multiplier }
}
public struct ApolloStablecoinTerms: Codable, Hashable {
    public let pegCurrency: String
    public let targetPeg: Decimal
    public let redemptionGuaranteed: Bool
    public init(pegCurrency: String, targetPeg: Decimal, redemptionGuaranteed: Bool) { self.pegCurrency = pegCurrency; self.targetPeg = targetPeg; self.redemptionGuaranteed = redemptionGuaranteed }
}
public struct ApolloBondTerms: Codable, Hashable {
    public let faceValue: Decimal
    public let annualCouponRate: Decimal
    public let couponFrequency: Int
    public let maturesAt: String
    public let priceConvention: String
    public let cleanPricePer100: Decimal
    public let accruedInterestPerBond: Decimal
    public var isMatured: Bool {
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: maturesAt).map { $0 <= Date() } ?? true
    }
    public var annualCoupon: Decimal { faceValue * annualCouponRate }
    public var dirtyPrice: Decimal { faceValue * cleanPricePer100 / 100 + accruedInterestPerBond }
    public init(faceValue: Decimal, annualCouponRate: Decimal, couponFrequency: Int, maturesAt: String, priceConvention: String, cleanPricePer100: Decimal, accruedInterestPerBond: Decimal) { self.faceValue = faceValue; self.annualCouponRate = annualCouponRate; self.couponFrequency = couponFrequency; self.maturesAt = maturesAt; self.priceConvention = priceConvention; self.cleanPricePer100 = cleanPricePer100; self.accruedInterestPerBond = accruedInterestPerBond }
}

/// Decodes Paper's pure registry export. No second instrument registry or network fallback.
public enum ApolloInstrumentSpecs {
    public static func demoCatalog(data: Data) throws -> [ApolloAsset] {
        guard let registry = try JSONSerialization.jsonObject(with: data) as? [String: Any], registry["schema_version"] as? Int == 2,
              registry["mode"] as? String == "demo_instrument_specs", let rows = registry["assets"] as? [[String: Any]], let strategies = registry["strategies"] as? [[String: Any]] else { throw invalid }
        var result: [ApolloAsset] = []
        for row in rows {
            let id = try string(row, "asset_id"), rawKind = try string(row, "kind")
            let mappedKind = rawKind == "commodity_exposure" ? "commodity" : rawKind == "real_estate_exposure" ? "real_estate" : rawKind
            guard let kind = ApolloAssetKind(rawValue: mappedKind), kind != .strategy,
                  row["currency"] as? String == "USD", let provenance = row["provenance"] as? [String: Any], provenance["is_demo"] as? Bool == true,
                  let multiplier = row["multiplier"] as? Int, multiplier > 0 else { throw invalid }
            let price = try decimal(row, "price"), step = try decimal(row, "quantity_step")
            guard price > 0, step > 0 else { throw invalid }
            var stable: ApolloStablecoinTerms?; var bond: ApolloBondTerms?
            if kind == .stablecoin {
                guard let terms = row["stablecoin"] as? [String: Any], let guaranteed = terms["redemption_guaranteed"] as? Bool, !guaranteed, multiplier == 1 else { throw invalid }
                stable = .init(pegCurrency: try string(terms, "peg_currency"), targetPeg: try decimal(terms, "target_peg"), redemptionGuaranteed: guaranteed)
            }
            if kind == .bond {
                guard let terms = row["bond"] as? [String: Any], let frequency = terms["coupon_frequency"] as? Int, frequency > 0, step == 1, multiplier == 1 else { throw invalid }
                bond = .init(faceValue: try decimal(terms, "face_value"), annualCouponRate: try decimal(terms, "annual_coupon_rate"), couponFrequency: frequency, maturesAt: try string(terms, "matures_at"), priceConvention: try string(terms, "price_convention"), cleanPricePer100: try decimal(row, "bond_clean_price_per_100"), accruedInterestPerBond: try decimal(row, "bond_accrued_interest_per_bond"))
                guard let bond, bond.faceValue > 0, bond.annualCouponRate >= 0, bond.priceConvention == "clean_per_100_face", bond.dirtyPrice == price else { throw invalid }
            }
            let old = ApolloDemoCatalog.assets.first { $0.id == id }
            let headline = kind == .stablecoin ? "A target peg.\nA different risk." : kind == .bond ? "A promise to pay.\nTerms to inspect." : old?.headline ?? "Read the business.\nQuestion the price."
            let summary = kind == .stablecoin ? "DEMO token exposure targeting a dollar peg. It is not cash or guaranteed redemption." : kind == .bond ? "Fictional direct bond, held in whole bonds. The clean quote is per $100 face; the paper cost is per whole bond." : old?.summary ?? "Reviewed catalog identity with a labeled demo execution snapshot. Open its source before forming a thesis."
            let bear = kind == .stablecoin ? "Depeg, reserves, issuer and custody failures can cause losses. A $1 target is not a guarantee." : kind == .bond ? "Credit default, rising rates and illiquidity can reduce value. Coupon and maturity settlement are not simulated." : old?.bearCase ?? "Single-company exposure can lose value; no performance inference is made from this catalog entry."
            var item = ApolloAsset(id: id, ticker: try string(row, "symbol"), name: try string(row, "name"), kind: kind, headline: headline, summary: summary, price: price, priceLabel: "DEMO USD per \(try string(row, "quantity_unit")) · not live", changeLabel: "Demo execution snapshot · no historical return", chart: old?.chart ?? [], bullCase: old?.bullCase ?? (kind == .stablecoin ? "Scenario: a maintained peg supports token transfers; no yield or redemption is promised." : kind == .bond ? "Scenario: the fictional issuer meets its obligations. Actual creditworthiness has not been established." : "No reviewed investment argument is asserted for this demo identity."), bearCase: bear, catalyst: "Inspect terms, source dates and unknowns before any paper decision.", lesson: kind == .stablecoin ? "Stablecoin exposure is a holding with depeg risk; it never becomes your virtual cash balance." : kind == .bond ? "Clean quote × face value /100 + accrued interest gives the whole-bond cost. Contractual coupon terms do not imply simulated income." : old?.lesson ?? "A catalog identity and a price fixture do not establish an investment thesis.", risk: kind == .stablecoin ? "Depeg, issuer & custody risk" : kind == .bond ? "Credit, rates & liquidity risk" : old?.risk ?? "Single-company risk", sources: [.init(title: "Registry exposure / educational source · does not validate price", url: try string(provenance, "source_url"))], multiplier: multiplier)
            item.quantityUnit = try string(row, "quantity_unit"); item.quantityStep = step; item.stablecoin = stable; item.bond = bond
            item.quoteProvenance = try string(provenance, "label"); item.quoteAsOf = try string(provenance, "as_of")
            if kind == .option {
                guard let terms = row["option"] as? [String: Any], terms["multiplier"] as? Int == multiplier, step == 1 else { throw invalid }
                item.optionTerms = .init(underlyingAssetID: try string(terms, "underlying_asset_id"), right: try string(terms, "right"), strike: try decimal(terms, "strike"), expiresAt: try string(terms, "expires_at"), multiplier: multiplier)
                guard let option = item.optionTerms, ["call", "put"].contains(option.right), option.strike > 0, ISO8601DateFormatter().date(from: option.expiresAt) != nil else { throw invalid }
                item.expiry = item.optionTerms?.expiresAt
            }
            result.append(item)
        }
        for strategy in strategies {
            let id = try string(strategy, "strategy_id")
            guard var item = ApolloDemoCatalog.assets.first(where: { $0.id == id && $0.kind == .strategy }), let allocations = strategy["allocations"] as? [[String: Any]] else { throw invalid }
            item.allocations = try allocations.map { .init(assetID: try string($0, "asset_id"), weight: try decimal($0, "weight")) }
            guard item.allocations.reduce(Decimal.zero, { $0 + $1.weight }) == 1, item.allocations.allSatisfy({ allocation in allocation.weight > 0 && result.contains(where: { $0.id == allocation.assetID }) }) else { throw invalid }
            result.append(item)
        }
        guard Set(result.map(\.id)).count == result.count else { throw invalid }
        return result
    }
    private static var invalid: ApolloGameError { .service("The canonical demo instrument registry is invalid or unsupported. No fallback price or order was created.") }
    private static func string(_ row: [String: Any], _ key: String) throws -> String { guard let value = row[key] as? String, !value.isEmpty else { throw invalid }; return value }
    private static func decimal(_ row: [String: Any], _ key: String) throws -> Decimal { guard let string = row[key] as? String, let value = Decimal(string: string, locale: Locale(identifier: "en_US_POSIX")), value.isFinite else { throw invalid }; return value }
}
