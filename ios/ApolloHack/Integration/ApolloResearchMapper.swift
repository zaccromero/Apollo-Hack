import Foundation

/// Preserves source labels and missing evidence. Display conversion never changes paper execution prices.
enum ApolloResearchMapper {
    static func asset(detail: [String: Any], analysis: [String: Any]) throws -> ApolloAsset {
        guard let id=detail["asset_id"] as? String, let ticker=detail["symbol"] as? String,
              let name=detail["name"] as? String, let kindText=detail["kind"] as? String,
              let kind=ApolloAssetKind(rawValue:kindText), let quote=detail["quote"] as? [String: Any] else { throw ApolloAPIError.invalidResponse }
        let isDemo=(detail["demo_asset"] as? Bool == true) || quote["status"] as? String == "demo_fixture"
        let price: Decimal
        if kind == .strategy { price=0 }
        else { guard let text=quote["price"] as? String, let value=Decimal(string:text,locale:Locale(identifier:"en_US_POSIX")), !value.isNaN, value>0 else { throw ApolloAPIError.invalidResponse }; price=value }
        let rawSources=detail["sources"] as? [[String: Any]] ?? []
        let sources=rawSources.compactMap(source)
        let sourcesByID=Dictionary(rawSources.compactMap { item -> (String,ApolloSource)? in
            guard let id=item["id"] as? String, let source=source(item) else { return nil }; return (id,source)
        },uniquingKeysWith:{first,_ in first})
        let tracks=(detail["evidence_tracks"] as? [[String: Any]] ?? []).map { track in
            let linked=(track["sources"] as? [String] ?? []).compactMap{sourcesByID[$0]}
            let summary=[track["headline"],track["body"],track["caveat"]].compactMap{$0 as? String}.joined(separator:"\n\n")
            return ApolloEvidenceTrack(topic:track["title"] as? String ?? "Evidence",status:track["status"] as? String ?? "Unknown",summary:summary,sources:linked,reasoning:typedReasoning(track["reasoning"] as? [String:Any]))
        }
        let opposing=analysis["opposing_evidence"] as? [String: Any] ?? [:]
        let caution=(opposing["supports_caution"] as? [String: Any])?["text"] as? String ?? "Unknown: not enough reviewed evidence to support a directional caution thesis."
        let counter=(opposing["counterevidence"] as? [String: Any])?["text"] as? String ?? "Unknown: not enough reviewed evidence to support a directional counter-thesis."
        let limits=opposing["limits"] as? String ?? "No verified entry signal or return guarantee."
        let chart=(detail["chart"] as? [[String: Any]] ?? []).compactMap { item -> Double? in
            guard let text=item["close"] as? String, let value=Double(text),value.isFinite else{return nil};return value
        }
        let allocations=try (detail["allocations"] as? [[String: Any]] ?? []).map { row in
            guard let id=row["asset_id"] as? String,let weight=row["weight"] as? String,let value=Decimal(string:weight),!value.isNaN else{throw ApolloAPIError.invalidResponse}
            return ApolloAllocation(assetID:id,weight:value)
        }
        let option=detail["option"] as? [String: Any]
        let riskTags=(detail["risk_tags"] as? [String] ?? []).map{$0.replacingOccurrences(of:"_",with:" ")}.joined(separator:" · ")
        let priceLabel: String
        if kind == .strategy { priceLabel="Fictional allocation · no track record" }
        else if isDemo { priceLabel="DEMO research quote · not executable" }
        else { priceLabel="Cached daily close · not executable" }
        var asset = ApolloAsset(id:id,ticker:ticker,name:name,kind:kind,headline:name + "\nWhat would change your view?",summary:detail["description"] as? String ?? "Read dated source evidence and risks before a paper decision.",price:price,priceLabel:priceLabel,changeLabel:quote["stale"] as? Bool == true ? "Stale snapshot · no live return" : "Cached snapshot · no live return",chart:chart,bullCase:counter,bearCase:caution,catalyst:limits,lesson:analysis["learning_prompt"] as? String ?? "Which source would change your view?",risk:riskTags,sources:sources,isDemo:isDemo,multiplier:option?["contract_multiplier"] as? Int ?? 1,expiry:option?["expiry"] as? String,allocations:allocations,quoteAsOf:quote["as_of"] as? String,quoteStale:quote["stale"] as? Bool ?? true,quoteProvenance:quote["note"] as? String ?? "Unknown quote provenance",evidenceTracks:tracks)
        if let terms=try ApolloBundledInstruments.catalog().first(where:{$0.id==id}) {
            asset.quantityUnit=terms.quantityUnit;asset.quantityStep=terms.quantityStep
            asset.optionTerms=terms.optionTerms;asset.stablecoin=terms.stablecoin;asset.bond=terms.bond
        }
        asset.researchCorpusHash=detail["corpus_hash"] as? String
        asset.researchEvidenceCutoff=detail["evidence_cutoff"] as? String
        return asset
    }
    private static func typedReasoning(_ row:[String:Any]?)->ApolloEvidenceReasoning? {
        guard let row else{return nil}
        func statements(_ key:String)->[ApolloEvidenceStatement] {
            (row[key] as? [[String:Any]] ?? []).compactMap { item in
                guard let text=item["text"] as? String,!text.isEmpty else{return nil}
                var locator:ApolloEvidenceSourceLocator?
                if let raw=item["source"] as? [String:Any],let id=raw["id"] as? String,let title=raw["title"] as? String,let url=raw["url"] as? String {
                    locator = .init(id:id,title:title,url:url,date:raw["date"] as? String,dateKind:raw["date_kind"] as? String,kind:raw["kind"] as? String)
                }
                return .init(text:text,sourceIDs:item["source_ids"] as? [String] ?? [],kind:item["kind"] as? String ?? "reviewed_paraphrase",source:locator)
            }
        }
        return .init(factLabel:row["fact_label"] as? String ?? "Facts · reviewed source summaries",facts:statements("facts"),interpretations:statements("interpretations"),counterevidence:statements("counterevidence"),counterevidenceStatus:row["counterevidence_status"] as? String ?? "No separate reviewed counterevidence available.",unknowns:row["unknowns"] as? [String] ?? ["Coverage is incomplete."],method:row["method"] as? String ?? "Reviewed paraphrases, not source quotations.")
    }
    private static func source(_ row:[String:Any])->ApolloSource? {
        guard let title=row["title"] as? String,let url=row["url"] as? String,
              let parsed=URL(string:url),["https","http"].contains(parsed.scheme ?? "") else{return nil}
        let id=row["id"] as? String ?? "Source"
        let date=row["date"] as? String
        let observed=row["date_kind"] as? String == "reviewed_at"
        let dateLabel=date.map { observed ? "Reviewed/observed " + $0 + " · publication date unknown" : "Published " + $0 } ?? "Publication date unknown"
        return ApolloSource(title:id + " · " + title + " · " + dateLabel,url:url,sourceID:row["id"] as? String)
    }
}
