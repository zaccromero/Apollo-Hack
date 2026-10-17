import Foundation

/// Decode the explicit provider action without converting paused/error envelopes into fixture answers.
enum ApolloChallengeMapper {
    static func map(_ value:[String:Any], expectedAssetID:String) throws -> ApolloThesisChallenge {
        guard let requestID=value["request_id"] as? String,
              let assetID=value["asset_id"] as? String,assetID==expectedAssetID,
              let rawStatus=value["status"] as? String,let status=ApolloChallengeStatus(rawValue:rawStatus),
              let reason=value["reason"] as? String,let notice=value["notice"] as? String,
              let rawContext=value["context"] as? [String:Any],let mode=rawContext["mode"] as? String,
              let label=rawContext["label"] as? String else { throw ApolloAPIError.invalidResponse }
        let context=ApolloChallengeContext(mode:mode,corpusHash:rawContext["corpus_hash"] as? String,cutoff:rawContext["cutoff"] as? String,label:label)
        let rawProviders=value["providers"] as? [String:[String:Any]] ?? [:]
        let providers=["prism","nicrron","telemetry"].compactMap { name -> ApolloChallengeProvider? in
            guard let row=rawProviders[name],let status=row["status"] as? String else { return nil }
            return ApolloChallengeProvider(name:name,status:status,proofKind:row["proof_kind"] as? String,requestedModel:row["requested_model"] as? String,actualModel:row["actual_model"] as? String,networkAttempted:row["network_attempted"] as? Bool,liveVerified:row["live_verified"] as? Bool,localCorrelationID:name == "prism" ? row["trace_id"] as? String : nil,publishedTraceID:name == "telemetry" && status == "sent" ? row["trace_id"] as? String : nil)
        }
        var groups:[ApolloChallengeGroup]=[]
        var sources:[ApolloChallengeSource]=[]
        if status == .success {
            guard let answer=value["answer"] as? [String:Any],let tracks=answer["tracks"] as? [String:[String:Any]],let rawSources=value["sources"] as? [[String:Any]] else { throw ApolloAPIError.invalidResponse }
            sources=try rawSources.map { row in
                guard let id=row["source_id"] as? String,let sourceAsset=row["asset_id"] as? String,sourceAsset==assetID,
                      let title=row["title"] as? String,let url=row["url"] as? String,let parsed=URL(string:url),parsed.scheme=="https",parsed.host != nil,parsed.user==nil,parsed.password==nil,
                      let date=row["date"] as? String,let kind=row["date_kind"] as? String else { throw ApolloAPIError.invalidResponse }
                return ApolloChallengeSource(sourceID:id,assetID:sourceAsset,title:title,url:url,date:date,dateKind:kind,text:row["text"] as? String ?? "")
            }
            guard Set(sources.map(\.sourceID)).count==sources.count else { throw ApolloAPIError.invalidResponse }
            for key in ["leadership","promises_results","public_sentiment","supporting_evidence","opposing_evidence"] {
                guard let group=tracks[key] ?? answer[key] as? [String:Any],let groupStatus=group["status"] as? String,let entries=group["items"] as? [[String:Any]], ["quoted_evidence","unknown"].contains(groupStatus), (groupStatus=="unknown") == entries.isEmpty else { throw ApolloAPIError.invalidResponse }
                let items=try entries.map { entry -> ApolloChallengeEvidence in
                    guard let id=entry["source_id"] as? String,let source=sources.first(where:{$0.sourceID==id}),let quote=entry["quote"] as? String,!quote.isEmpty,source.text.contains(quote),let interpretation=entry["interpretation"] as? String,!interpretation.isEmpty else { throw ApolloAPIError.invalidResponse }
                    return ApolloChallengeEvidence(sourceID:id,quote:quote,interpretation:interpretation)
                }
                groups.append(ApolloChallengeGroup(id:key,status:groupStatus,items:items))
            }
        } else if value["answer"] != nil && !(value["answer"] is NSNull) { throw ApolloAPIError.invalidResponse }
        var result = ApolloThesisChallenge(requestID:requestID,assetID:assetID,status:status,reason:reason,notice:notice,context:context,providers:providers,groups:groups,sources:sources,generatedAnalysis:true,semanticGroundingVerified:false,sponsorAcceptance:false)
        result.processSteps=try (value["process_steps"] as? [[String:Any]] ?? []).map { row in
            guard let id=row["id"] as? String,let title=row["title"] as? String,let state=row["status"] as? String else { throw ApolloAPIError.invalidResponse }
            return ApolloChallengeProcessStep(id:id,title:title,status:state,detail:row["detail"] as? String ?? "",inputSummary:row["input_summary"] as? String,outputSummary:row["output_summary"] as? String,sourceIDs:row["source_ids"] as? [String] ?? [],timestamp:row["timestamp"] as? String,durationMilliseconds:(row["duration_milliseconds"] as? NSNumber)?.doubleValue)
        }
        result.savedEvidenceNotice=value["saved_evidence_notice"] as? String
        return result
    }
}
