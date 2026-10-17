import Foundation

/// Current Research SocialIntakeAPI schema1. Saved summaries are never promoted to raw transcripts.
public enum ApolloSocialIntakeDecoder {
    public static func receipt(_ raw: [String: Any]) throws -> ApolloSocialResearchReceipt {
        guard raw["schema_version"] as? Int == 1, let id = raw["job_id"] as? String,
              let input = raw["url"] as? String, let url = ApolloSocialResearchInput.canonicalURL(input),
              let state = raw["state"] as? String, let mode = raw["mode"] as? String,
              raw["fresh_fetch"] as? Bool == false, raw["paid_calls"] as? Int == 0,
              raw["portfolio_changed"] as? Bool == false,
              let candidates = raw["candidates"] as? [Any], candidates.isEmpty,
              let admitted = raw["admitted_candidates"] as? [Any], admitted.isEmpty,
              Set(raw["tracks"] as? [String] ?? []) == Set(["leadership", "promises_results", "public_sentiment"]) else { throw invalid }
        let limitation = raw["limitation"] as? String ?? "Access and evidence completeness are limited."
        let storage = raw["storage"] as? String ?? "Storage lifetime unknown"
        let record = raw["evidence"] as? [String: Any]
        var result: ApolloSocialResearchReceipt
        if state == "reviewed_snapshot", mode == "saved_public_inspection", let record {
            guard let recordURL = record["url"] as? String, ApolloSocialResearchInput.canonicalURL(recordURL) == url,
                  let inspected = raw["inspected_at"] as? String, !inspected.isEmpty else { throw invalid }
            let rawClaims = record["claims"] as? [[String: Any]] ?? []
            let claims = try rawClaims.enumerated().map { index, row -> ApolloSocialClaim in
                guard let text = row["claim"] as? String, !text.isEmpty, let verification = row["verification"] as? String else { throw invalid }
                return ApolloSocialClaim(id: id + ":claim:\(index)", text: text, evidenceSegmentIDs: [], verification: verification, finding: row["finding"] as? String, sources: (row["official_sources"] as? [String] ?? []).map { .init(title: "Official cross-check · " + (URL(string: $0)?.host ?? "source"), url: $0) })
            }
            var limits = [limitation, "Public inspection summaries below are paraphrases. No raw caption quotation or video/audio transcript is supplied by this record.", "Research job storage: " + storage]
            if let extra = record["limits"] as? String { limits.append(extra) }
            if let sentiment = record["sentiment"] as? String { limits.append(sentiment) }
            if let resolution = record["asset_resolution"] as? [String: Any], let reason = resolution["reason"] as? String { limits.append(reason) }
            result = .init(id: id, originURL: url, status: .noInvestment, accessScope: record["access_scope"] as? String ?? "unknown", retrievedAt: inspected, publishedAt: record["displayed_date"] as? String, notice: "Saved public-page inspection summary (paraphrase): " + (record["summary"] as? String ?? "No summary recorded."), evidenceSegments: [], claims: claims, candidates: [], limitations: limits, networkAttempted: false, providerCalls: 0)
        } else if state == "blocked", mode == "runtime_access_unavailable", record == nil {
            result = .init(id: id, originURL: url, status: .unavailable, accessScope: "unavailable", retrievedAt: nil, publishedAt: nil, notice: "BROWSER_RETRIEVAL_REQUIRED · This URL has no saved authorized public inspection.", evidenceSegments: [], claims: [], candidates: [], limitations: [limitation, "Research job storage: " + storage], networkAttempted: false, providerCalls: 0)
        } else { throw invalid }
        if record?["displayed_date"] != nil { result.publishedDateKind = "Post date as displayed · not independently verified" }
        result.mode = mode; result.freshFetch = false
        return result
    }
    private static var invalid: ApolloGameError { .service("Social intake returned an unsupported, inconsistent or unsafe job. No evidence, candidate or admission success was displayed.") }
}
