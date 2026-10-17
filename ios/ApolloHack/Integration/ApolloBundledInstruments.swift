import Foundation
/// Paper-owned public snapshot. Failed decoding never resets or substitutes a session.
enum ApolloBundledInstruments {
    static func catalog() throws -> [ApolloAsset] {
        guard let url=Bundle.main.url(forResource:"instrument-specs",withExtension:"json") else { throw ApolloAPIError.invalidResponse }
        return try ApolloInstrumentSpecs.demoCatalog(data:Data(contentsOf:url))
    }
    static func reviewedDemoCatalog() throws -> [ApolloAsset] {
        let canonical=try catalog()
        guard let url=Bundle.main.url(forResource:"research-snapshots",withExtension:"json"),
              let raw=try JSONSerialization.jsonObject(with:Data(contentsOf:url)) as? [String:Any],
              raw["schema_version"] as? Int==1,let rows=raw["assets"] as? [[String:Any]] else {throw ApolloAPIError.invalidResponse}
        let research=try rows.map { row -> ApolloAsset in
            guard let detail=row["detail"] as? [String:Any],let analysis=row["analysis"] as? [String:Any] else {throw ApolloAPIError.invalidResponse}
            return try ApolloResearchMapper.asset(detail:detail,analysis:analysis)
        }
        guard Set(research.map(\.id))==Set(canonical.map(\.id)) else {throw ApolloAPIError.invalidResponse}
        let merged = canonical.map { item in
            guard let reviewed=research.first(where:{$0.id==item.id}) else{return item}
            var result=ApolloAsset(id:item.id,ticker:item.ticker,name:item.name,kind:item.kind,headline:item.headline,summary:"Dated reviewed research · DEMO paper execution. "+item.summary,price:item.price,priceLabel:item.priceLabel,changeLabel:item.changeLabel,chart:item.chart,bullCase:reviewed.bullCase,bearCase:reviewed.bearCase,catalyst:reviewed.catalyst,lesson:item.lesson,risk:item.risk,sources:reviewed.sources,isDemo:true,multiplier:item.multiplier,expiry:item.expiry,allocations:item.allocations,quoteAsOf:item.quoteAsOf,quoteStale:true,quoteProvenance:item.quoteProvenance,evidenceTracks:reviewed.evidenceTracks)
            result.researchCorpusHash=reviewed.researchCorpusHash;result.researchEvidenceCutoff=reviewed.researchEvidenceCutoff
            result.quantityUnit=item.quantityUnit;result.quantityStep=item.quantityStep;result.optionTerms=item.optionTerms;result.stablecoin=item.stablecoin;result.bond=item.bond
            return result
        }
        guard let profilesURL = Bundle.main.url(forResource: "company-profiles-v1", withExtension: "json") else { throw ApolloAPIError.invalidResponse }
        return ApolloCompanyProfileDecoder.attaching(try ApolloCompanyProfileDecoder.profiles(data: Data(contentsOf: profilesURL)), to: merged)
    }

}
