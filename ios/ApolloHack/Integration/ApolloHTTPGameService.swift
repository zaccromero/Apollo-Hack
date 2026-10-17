import Foundation
import CryptoKit

/// Opt-in Mac-local backend mode. Failure stays visible; demo state is never substituted.
@MainActor
final class ApolloHTTPGameService: ApolloGameService {
    let modeLabel = "Local backend · paper simulation · demo execution prices"
    private let api: ApolloAPIClient
    private var researchDetails: [String:[String:Any]] = [:]
    func researchDetail(for assetID:String) -> [String:Any]? { researchDetails[assetID] }
    init(baseURL: URL) { api = ApolloAPIClient(baseURL: baseURL) }

    func catalog() async throws -> [ApolloAsset] {
        let catalog = try await api.request("GET", "/research/catalog")
        guard let rows = catalog["assets"] as? [[String: Any]] else { throw ApolloAPIError.invalidResponse }
        var assets: [ApolloAsset] = []
        for row in rows {
            guard let id = row["asset_id"] as? String,
                  let escaped = id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else { throw ApolloAPIError.invalidResponse }
            let detail = try await api.request("GET", "/research/assets/" + escaped)
            let analysis = try await api.request("POST", "/research/analysis", body: ["asset_id": id, "thesis": ""])
            assets.append(try ApolloResearchMapper.asset(detail: detail, analysis: analysis))
            researchDetails[id] = detail
        }
        return assets
    }
    func researchSocial(url:String) async throws -> ApolloSocialResearchReceipt {
        guard let canonical=ApolloSocialResearchInput.canonicalURL(url) else {throw ApolloAPIError.invalidResponse}
        let raw=try await api.request("POST","/research/social/jobs",body:["url":canonical],acceptedStatuses:[202])
        let receipt=try ApolloSocialIntakeDecoder.receipt(raw)
        guard receipt.originURL==canonical else {throw ApolloAPIError.invalidResponse}
        return receipt
    }
    func admitSocialCandidate(candidateID:String) async throws -> ApolloSocialAdmission {
        throw ApolloGameError.service("No eligible independently verified candidate has been returned by this intake. No admission or order was created.")
    }
    func account() async throws -> ApolloAccount {
        try Self.account(try await api.request("GET", "/paper/state"))
    }
    func record(assetID: String, action: ApolloDecision, thesis: String) async throws -> ApolloAccount {
        _ = try await api.request("POST", "/paper/decisions", body: ["target_id": assetID, "action": action.rawValue, "thesis": Self.thesis(thesis)])
        return try await account()
    }
    func preview(assetID: String, quantity: Decimal, thesis: String) async throws -> ApolloOrderPreview {
        let value = try await api.request("POST", "/paper/orders/preview", body: ["asset_id": assetID, "quantity": quantity.apolloQuantity, "client_request_id": UUID().uuidString, "thesis": Self.thesis(thesis)])
        return try Self.preview(value, assetID: assetID, thesis: thesis)
    }
    func previewCopy(strategyID: String, budget: Decimal, thesis: String) async throws -> ApolloOrderPreview {
        let value = try await api.request("POST", "/paper/copy/preview", body: ["strategy_id": strategyID, "budget": budget.apolloQuantity, "client_request_id": UUID().uuidString, "thesis": Self.thesis(thesis)])
        return try Self.preview(value, assetID: strategyID, thesis: thesis)
    }
    func confirm(_ preview: ApolloOrderPreview) async throws -> ApolloAccount {
        _ = try await api.request("POST", "/paper/orders/\(preview.id)/confirm", body: ["confirmed": true, "mixed_exception_acknowledged": preview.mixedExceptionAcknowledged])
        return try await account()
    }
    func setRiskProfile(_ tolerance: ApolloRiskTolerance) async throws -> ApolloAccount {
        _ = try await api.request("POST", "/paper/profile", body: ["tolerance": tolerance.rawValue, "confirmed": true])
        return try await account()
    }
    func reset() async throws -> ApolloAccount {
        // Game UI owns the explicit reset confirmation before calling this method.
        let preview = try await api.request("POST", "/paper/reset/preview", body: [:])
        let token = try Self.string(preview, "reset_token")
        _ = try await api.request("POST", "/paper/reset/confirm", body: ["reset_token": token, "confirmed": true, "confirmation_phrase": "RESET PAPER PORTFOLIO"])
        return try await account()
    }
    private static func thesis(_ text: String) -> [String: String] {
        if let data = text.data(using: .utf8), let value = try? JSONDecoder().decode(ApolloThesis.self, from: data) {
            return ["reason": value.reason, "risk": value.risk, "invalidation": value.invalidation]
        }
        return ["reason": text, "risk": "", "invalidation": ""]
    }
    private static func account(_ value: [String: Any]) throws -> ApolloAccount {
        guard let rawPositions = value["positions"] as? [[String: Any]],
              let rawDecisions = value["decisions"] as? [[String: Any]],
              let transactions = value["transactions"] as? [[String: Any]] else { throw ApolloAPIError.invalidResponse }
        let positions = try rawPositions.map { row in
            let asset = row["asset"] as? [String: Any] ?? [:]
            let option = asset["option"] as? [String: Any]
            return ApolloPosition(assetID: try string(row,"asset_id"), quantity: try decimal(row,"quantity"), cost: try decimal(row,"cost_basis"), multiplier: option?["multiplier"] as? Int ?? 1, marketValue:try decimal(row,"market_value"), valuationPrice:try decimal(row["valuation"] as? [String:Any] ?? [:],"price"), valuationProvenance:((row["valuation"] as? [String:Any])?["provenance"] as? [String:Any])?["label"] as? String)
        }
        let decisions = try rawDecisions.reversed().compactMap { row -> ApolloDecisionRecord? in
            guard let action = ApolloDecision(rawValue: try string(row,"action")) else { return nil }
            let id = try string(row,"target_id"), dateText = try string(row,"created_at")
            let thesisText = try thesisText(row["thesis"])
            return ApolloDecisionRecord(id: stableID(id + action.rawValue + dateText + thesisText), assetID:id, action:action, thesis:thesisText, date:try date(dateText))
        }
        let fills = try transactions.flatMap { transaction -> [ApolloFill] in
            guard let lines = transaction["lines"] as? [[String: Any]] else { throw ApolloAPIError.invalidResponse }
            let orderID = try string(transaction,"order_id"), when = try date(string(transaction,"confirmed_at"))
            return try lines.map { line in
                let assetID = try string(line,"asset_id")
                return ApolloFill(id:orderID + ":" + assetID, assetID:assetID, quantity:try decimal(line,"quantity"), cost:try decimal(line,"total"), thesis:try thesisText(transaction["thesis"]), date:when)
            }
        }
        return ApolloAccount(cash:try decimal(value,"cash"), positions:positions, decisions:decisions, fills:fills, riskProfile:try profile(value["risk_profile"]), analytics:try analytics(value["portfolio_summary"]))
    }
    private static func preview(_ value: [String: Any], assetID: String, thesis: String) throws -> ApolloOrderPreview {
        guard let rawLines = value["lines"] as? [[String: Any]] else { throw ApolloAPIError.invalidResponse }
        let lines = try rawLines.map { row in
            ApolloOrderLine(assetID:try string(row,"asset_id"), quantity:try decimal(row,"quantity"), price:try decimal(row,"price"), multiplier:row["multiplier"] as? Int ?? 1)
        }
        var result = ApolloOrderPreview(id:try string(value,"order_id"),assetID:assetID,lines:lines,total:try decimal(value,"total"),thesis:thesis,expiresAt:try date(string(value,"expires_at")),quoteProvenance:rawLines.compactMap { ($0["provenance"] as? [String:Any])?["label"] as? String }.joined(separator:"; "),warnings:value["warnings"] as? [String] ?? ["Paper simulation; execution quote provenance unavailable."])
        if let risk = value["risk_check"] as? [String:Any] {
            result.riskCheck = ApolloRiskCheck(status:try string(risk,"status"),requiresMixedException:risk["requires_mixed_exception"] as? Bool ?? false,notice:risk["notice"] as? String ?? "Risk evidence unavailable",outsideAssetIDs:risk["exception_asset_ids"] as? [String] ?? [])
        }
        result.portfolioBefore = try analytics(value["portfolio_before"])
        result.portfolioAfter = try analytics(value["portfolio_after"])
        if let notice = value["projection_notice"] as? String { result.projectionNotice = notice }
        return result
    }
    func challengeThesis(assetID:String,thesis:ApolloThesis) async throws -> ApolloThesisChallenge {
        guard thesis.isChallengeReady else { throw ApolloGameError.service("Complete all thesis fields within the source challenge limits.") }
        let context=ApolloChallengeContext.assignedHistorical
        let result=try await api.request("POST","/providers/challenge",body:["request_id":UUID().uuidString,"asset_id":assetID,"thesis":["reason":thesis.reason,"risk":thesis.risk,"invalidation":thesis.invalidation],"context":["mode":context.mode,"corpus_hash":context.corpusHash ?? ""]],acceptedStatuses:[400,409,422,502,503],timeout:90)
        return try ApolloChallengeMapper.map(result,expectedAssetID:assetID)
    }
    func comparePaper(assetID:String,quantity:Decimal,strategyBudget:Decimal?) async throws -> ApolloPaperComparison {
        var body:[String:Any]=["asset_id":assetID,"quantity":quantity.apolloQuantity]
        if let budget=strategyBudget { body["strategy_budget"]=budget.apolloQuantity }
        let value=try await api.request("POST","/paper/compare",body:body)
        guard value["mutates_account"] as? Bool == false,value["creates_order"] as? Bool == false,
              let baseline=try Self.analytics(value["baseline"]),let investment=value["investment"] as? [String:Any],let strategy=value["strategy"] as? [String:Any],
              let rawProfiles=value["profiles"] as? [[String:Any]],let rawOutcomes=value["outcomes"] as? [String:Any] else { throw ApolloAPIError.invalidResponse }
        func lines(_ row:[String:Any]) throws -> [ApolloOrderLine] {
            guard let rows=row["lines"] as? [[String:Any]] else { throw ApolloAPIError.invalidResponse }
            return try rows.map { ApolloOrderLine(assetID:try Self.string($0,"asset_id"),quantity:try Self.decimal($0,"quantity"),price:try Self.decimal($0,"price"),multiplier:$0["multiplier"] as? Int ?? 1) }
        }
        func projection(_ raw:Any?) throws -> ApolloComparisonProjection {
            guard let row=raw as? [String:Any],let risk=row["risk_check"] as? [String:Any],let after=try Self.analytics(row["portfolio_after"]) else { throw ApolloAPIError.invalidResponse }
            return ApolloComparisonProjection(riskCheck:ApolloRiskCheck(status:try Self.string(risk,"status"),requiresMixedException:risk["requires_mixed_exception"] as? Bool ?? false,notice:risk["notice"] as? String ?? "No risk notice provided",outsideAssetIDs:risk["exception_asset_ids"] as? [String] ?? []),portfolioAfter:after)
        }
        let profiles=try rawProfiles.map { row -> ApolloComparisonProfile in
            guard let tolerance=ApolloRiskTolerance(rawValue:try Self.string(row,"tolerance")),let ceiling=row["asset_risk_ceiling"] as? Int,let current=try Self.analytics(row["current"]) else { throw ApolloAPIError.invalidResponse }
            return ApolloComparisonProfile(tolerance:tolerance,ceiling:ceiling,current:current,investment:try projection(row["investment"]),strategy:try projection(row["strategy"]))
        }
        guard Set(profiles.map { $0.tolerance.rawValue }).count==3 else { throw ApolloAPIError.invalidResponse }
        func outcomes(_ key:String) throws -> [ApolloComparisonOutcome] {
            guard let rows=rawOutcomes[key] as? [[String:Any]] else { throw ApolloAPIError.invalidResponse }
            return try rows.map { ApolloComparisonOutcome(shock:try Self.decimal($0,"shock"),holdingMarkValue:try Self.decimal($0,"holding_mark_value"),equity:try Self.decimal($0,"equity"),changeFromSnapshot:try Self.decimal($0,"change_from_snapshot"),label:try Self.string($0,"label")) }
        }
        let provenance=(strategy["provenance"] as? [String:Any])?["label"] as? String ?? "Fictional demo strategy; no verified track record"
        return ApolloPaperComparison(modeLabel:"Connected paper backend · read-only comparison",mutatesAccount:false,createsOrder:false,comparisonNotice:value["comparison_notice"] as? String ?? "Read-only hypothetical comparison",outcomeAssumptions:value["outcome_assumptions"] as? String ?? "Hypothetical sensitivities, not forecasts",baseline:baseline,recordedPaperPnL:try Self.decimal(value,"recorded_paper_pnl"),recordedPaperPnLLabel:value["recorded_results_notice"] as? String ?? "Recorded paper marks, not forecast returns",investmentLines:try lines(investment),investmentTotal:try Self.decimal(investment,"total"),strategyID:try Self.string(strategy,"strategy_id"),strategyName:try Self.string(strategy,"name"),strategyProvenance:provenance,strategyLines:try lines(strategy),strategyTotal:try Self.decimal(strategy,"total"),strategyBudget:try Self.decimal(strategy,"budget"),uninvestedBudget:try Self.decimal(strategy,"uninvested_budget"),profiles:profiles,outcomes:ApolloComparisonOutcomes(current:try outcomes("current"),investment:try outcomes("investment"),strategy:try outcomes("strategy")))
    }
    private static func profile(_ raw: Any?) throws -> ApolloRiskProfile? {
        guard let row = raw as? [String:Any] else { return nil }
        guard let tolerance = ApolloRiskTolerance(rawValue:try string(row,"tolerance")),let ceiling = row["asset_risk_ceiling"] as? Int else { throw ApolloAPIError.invalidResponse }
        return ApolloRiskProfile(tolerance:tolerance,ceiling:ceiling,label:row["model"] as? String ?? "Educational 1–5 rubric; not loss probability")
    }
    private static func analytics(_ raw: Any?) throws -> ApolloPortfolioAnalytics? {
        guard let row = raw as? [String:Any] else { return nil }
        let risk = row["risk"] as? [String:Any] ?? [:], sentiment = row["sentiment"] as? [String:Any] ?? [:]
        let slices = try (row["asset_class_allocation"] as? [[String:Any]] ?? []).map { ApolloPortfolioSlice(label:try string($0,"kind"),value:try decimal($0,"value"),weight:try decimal($0,"weight")) }
        func optionalDecimal(_ object:[String:Any],_ key:String) throws -> Decimal? { if object[key] == nil || object[key] is NSNull { return nil }; return try decimal(object,key) }
        let provenance = (row["allocations"] as? [[String:Any]] ?? []).compactMap { allocation -> String? in
            guard let assessment = allocation["assessment"] as? [String:Any],let label = assessment["source_label"] as? String else { return nil }
            return label + ((assessment["as_of"] as? String).map { " · " + $0 } ?? "")
        }
        return ApolloPortfolioAnalytics(equity:try decimal(row,"equity"),cashWeight:try decimal(row,"cash_weight"),assetClasses:slices,weightedRisk:try optionalDecimal(risk,"weighted_invested_score"),riskCoverage:try decimal(risk,"coverage"),outsideToleranceAssetIDs:risk["outside_tolerance_asset_ids"] as? [String] ?? [],riskLabel:risk["label"] as? String ?? "Educational rubric; not loss probability",sentimentStatus:sentiment["status"] as? String ?? "unknown",bullishShare:try optionalDecimal(sentiment,"bullish_share_of_covered_holdings"),bearishShare:try optionalDecimal(sentiment,"bearish_share_of_covered_holdings"),sentimentCoverage:try decimal(sentiment,"coverage_of_holdings"),hasDemoSentiment:sentiment["has_demo_inputs"] as? Bool ?? false,sentimentLabel:sentiment["label"] as? String ?? "Unknown sentiment is not 50/50",sentimentProvenance:provenance)
    }
    private static func string(_ value: [String: Any], _ key: String) throws -> String {
        guard let text = value[key] as? String else { throw ApolloAPIError.invalidResponse }; return text
    }
    private static func decimal(_ value: [String: Any], _ key: String) throws -> Decimal {
        guard let text = value[key] as? String, let number = Decimal(string:text,locale:Locale(identifier:"en_US_POSIX")), !number.isNaN else { throw ApolloAPIError.invalidResponse }; return number
    }
    private static func date(_ text: String) throws -> Date {
        let formatter = ISO8601DateFormatter(); formatter.formatOptions=[.withInternetDateTime,.withFractionalSeconds]
        if let value=formatter.date(from:text) { return value }
        formatter.formatOptions=[.withInternetDateTime]
        guard let value=formatter.date(from:text) else { throw ApolloAPIError.invalidResponse }; return value
    }
    private static func thesisText(_ value: Any?) throws -> String {
        if let text=value as? String { return text }
        guard let object=value as? [String: Any] else { return "" }
        return String(decoding:try JSONSerialization.data(withJSONObject:object,options:.sortedKeys),as:UTF8.self)
    }
    private static func stableID(_ text: String) -> UUID {
        let hex=SHA256.hash(data:Data(text.utf8)).prefix(16).map{String(format:"%02x",$0)}.joined()
        let chars=Array(hex)
        let groups=[0..<8,8..<12,12..<16,16..<20,20..<32].map{String(chars[$0])}
        return UUID(uuidString:groups.joined(separator:"-"))!
    }
}
