import Foundation

public enum ApolloCompanyPanel: String, CaseIterable, Identifiable, Codable {
    case overview, news, chart, business, people, otherSide = "other_side"
    public var id: String { rawValue }
    public var title: String { switch self { case .overview: return "Overview"; case .news: return "What’s new"; case .chart: return "Chart"; case .business: return "Business"; case .people: return "People & execution"; case .otherSide: return "The other side" } }
    public var question: String { switch self { case .overview: return "How does this company earn its money?"; case .news: return "What changed in the reviewed record?"; case .chart: return "What does the recorded price history show?"; case .business: return "What did the business actually report?"; case .people: return "Who changed—and what was delivered?"; case .otherSide: return "What could make this thesis wrong?" } }
}
public struct ApolloCompanyFact: Codable, Hashable {
    public let text: String
    public let sourceIDs: [String]
    public let status: String
    public let effectiveAt: String?
    public let observedAt: String?
}
public struct ApolloCompanyUpdate: Codable, Hashable, Identifiable {
    public var id: String { sourceIDs.joined(separator: "|") + "|" + title }
    public let title: String
    public let sourceIDs: [String]
    public let url: String
    public let date: String?
    public let dateKind: String?
    public let scope: String
}
public struct ApolloCompanyMetric: Codable, Hashable, Identifiable {
    public var id: String { name + "|" + periodEnd + "|" + sourceIDs.joined(separator: "|") }
    public let name: String
    public let value: String
    public let unit: String
    public let periodEnd: String
    public let periodType: String
    public let sourceIDs: [String]
    public let status: String
}
public struct ApolloCompanyProfile: Codable, Hashable {
    public let assetID: String
    public let companyName: String
    public let corpusHash: String
    public let reviewCutoff: String
    public let businessModel: ApolloCompanyFact
    public let updates: [ApolloCompanyUpdate]
    public let metrics: [ApolloCompanyMetric]
    public let people: [ApolloCompanyFact]
    public let sources: [ApolloEvidenceSourceLocator]
    public let imageNotice: String
    public var productImageAssetName: String? = nil
    public func matches(assetID: String, corpusHash: String?) -> Bool { self.assetID == assetID && corpusHash == self.corpusHash }
    public func sources(for ids: [String]) -> [ApolloEvidenceSourceLocator] { ids.compactMap { id in sources.first { $0.id == id } } }
}
public enum ApolloCompanyProfileDecoder {
    /// Attach only a current, asset-bound reviewed snapshot. Existing asset economics remain unchanged.
    public static func attaching(_ profiles: [String: ApolloCompanyProfile], to assets: [ApolloAsset]) -> [ApolloAsset] {
        assets.map { asset in
            var copy = asset
            if asset.kind == .stock, let profile = profiles[asset.id], profile.matches(assetID: asset.id, corpusHash: asset.researchCorpusHash) { copy.companyProfile = profile }
            else { copy.companyProfile = nil }
            return copy
        }
    }
    public static func profiles(data: Data) throws -> [String: ApolloCompanyProfile] {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any], root["schema_version"] as? Int == 1, root["mode"] as? String == "reviewed_source_profile", root["paid_calls"] as? Int == 0, let rows = root["profiles"] as? [[String: Any]] else { throw invalid }
        var result: [String: ApolloCompanyProfile] = [:]
        for row in rows {
            guard let panels = row["panels"] as? [String: Any], let rawSources = panels["sources"] as? [[String: Any]], let business = panels["business_model"] as? [String: Any], row["latest_updates_verified"] as? Bool == false, row["leadership_causality_established"] as? Bool == false else { throw invalid }
            let sources = try rawSources.map { source -> ApolloEvidenceSourceLocator in
                let url = try string(source, "url"); guard URL(string: url)?.scheme == "https" else { throw invalid }
                return .init(id: try string(source, "id"), title: try string(source, "title"), url: url, date: source["date"] as? String, dateKind: source["date_kind"] as? String, kind: source["kind"] as? String)
            }
            let ids = Set(sources.map(\.id)); guard ids.count == sources.count else { throw invalid }
            func references(_ item: [String: Any]) throws -> [String] { guard let values = item["source_ids"] as? [String], !values.isEmpty, Set(values).isSubset(of: ids) else { throw invalid }; return values }
            func fact(_ item: [String: Any]) throws -> ApolloCompanyFact { guard item["verbatim_quote"] as? Bool == false else { throw invalid }; return .init(text: try string(item, "text"), sourceIDs: try references(item), status: try string(item, "status"), effectiveAt: item["effective_at"] as? String, observedAt: item["observed_at"] as? String) }
            let updates = try (panels["dated_news"] as? [[String: Any]] ?? []).map { update -> ApolloCompanyUpdate in
                guard update["fresh"] as? Bool == false else { throw invalid }
                let refs = try references(update), url = try string(update, "url")
                guard sources.contains(where: { refs.contains($0.id) && $0.url == url }) else { throw invalid }
                return .init(title: try string(update, "title"), sourceIDs: refs, url: url, date: update["date"] as? String, dateKind: update["date_kind"] as? String, scope: try string(update, "scope"))
            }
            let metrics = try (panels["fiscal_metrics"] as? [[String: Any]] ?? []).map { metric -> ApolloCompanyMetric in
                let value = try string(metric, "value"); guard let number = Decimal(string: value), number.isFinite else { throw invalid }
                return .init(name: try string(metric, "name"), value: value, unit: try string(metric, "unit"), periodEnd: try string(metric, "fiscal_period_end"), periodType: try string(metric, "period_type"), sourceIDs: try references(metric), status: try string(metric, "status"))
            }
            let id = try string(row, "asset_id"), hash = try string(row, "corpus_hash")
            guard hash.count == 64, hash.allSatisfy({ $0.isHexDigit }), result[id] == nil else { throw invalid }
            let profile = ApolloCompanyProfile(assetID: id, companyName: try string(row, "company_name"), corpusHash: hash, reviewCutoff: try string(row, "review_cutoff"), businessModel: try fact(business), updates: updates, metrics: metrics, people: try (panels["people"] as? [[String: Any]] ?? []).map(fact), sources: sources, imageNotice: (panels["existing_image"] as? [String: Any])?["reason"] as? String ?? "No reviewed product image available.")
            result[id] = profile
        }
        return result
    }
    private static func string(_ row: [String: Any], _ key: String) throws -> String { guard let value = row[key] as? String, !value.isEmpty else { throw invalid }; return value }
    private static var invalid: ApolloGameError { .service("The reviewed company profile is missing, mismatched or unsupported. No news, metrics, image or provider result was invented.") }
}
