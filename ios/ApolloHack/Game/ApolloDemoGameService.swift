import Foundation

/// Local educational adapter. Persistence is device-local; fixture prices never imply a market fill.
@MainActor public final class ApolloDemoGameService: ApolloGameService {
    public let modeLabel = "DEMO · PAPER ONLY"
    private let catalogAssets: [ApolloAsset]
    private let defaults: UserDefaults
    private let storageKey: String
    private var state: ApolloAccount
    private var pending: [String: ApolloOrderPreview] = [:]
    private var confirmed: Set<String> = []
    public init(defaults: UserDefaults = .standard, storageKey: String = "apollo.game.demo.v1", catalog: [ApolloAsset] = ApolloDemoCatalog.assets) {
        self.catalogAssets = catalog
        self.defaults = defaults; self.storageKey = storageKey
        if let data = defaults.data(forKey: storageKey), let saved = try? JSONDecoder().decode(ApolloAccount.self, from: data) { state = saved }
        else { state = .empty }
    }
    public func catalog() async throws -> [ApolloAsset] { catalogAssets }
    public func account() async throws -> ApolloAccount { snapshot() }
    public func record(assetID: String, action: ApolloDecision, thesis: String) async throws -> ApolloAccount {
        _ = try asset(assetID)
        var next = state
        next.decisions.append(.init(id: UUID(), assetID: assetID, action: action, thesis: thesis, date: Date()))
        try save(next); return snapshot()
    }
    public func preview(assetID: String, quantity: Decimal, thesis: String) async throws -> ApolloOrderPreview {
        let line = try comparisonLine(assetID: assetID, quantity: quantity)
        return try makePreview(assetID: assetID, lines: [line], thesis: thesis)
    }
    public func previewCopy(strategyID: String, budget: Decimal, thesis: String) async throws -> ApolloOrderPreview {
        let lines = try comparisonCopyLines(strategyID: strategyID, budget: budget)
        return try makePreview(assetID: strategyID, lines: lines, thesis: thesis)
    }
    public func confirm(_ preview: ApolloOrderPreview) async throws -> ApolloAccount {
        if confirmed.contains(preview.id) { return snapshot() }
        guard let stored = pending[preview.id], stored.expiresAt > Date() else { throw ApolloGameError.expired }
        guard stored.total <= state.cash else { throw ApolloGameError.insufficientFunds }
        for line in stored.lines { _ = try comparisonLine(assetID: line.assetID, quantity: line.quantity) }
        _ = try riskCheck(stored.lines)
        var next = state
        next.cash -= stored.total
        for line in stored.lines {
            if let index = next.positions.firstIndex(where: { $0.assetID == line.assetID }) {
                next.positions[index].quantity += line.quantity; next.positions[index].cost += line.cost
            } else { next.positions.append(.init(assetID: line.assetID, quantity: line.quantity, cost: line.cost, multiplier: line.multiplier)) }
            next.fills.append(.init(id: stored.id + ":" + line.assetID, assetID: line.assetID, quantity: line.quantity, cost: line.cost, thesis: stored.thesis, date: Date()))
        }
        try save(next); confirmed.insert(stored.id); pending.removeValue(forKey: stored.id)
        return snapshot()
    }
    public func reset() async throws -> ApolloAccount {
        try save(.empty); pending = [:]; confirmed = []; return snapshot()
    }
    private func makePreview(assetID: String, lines: [ApolloOrderLine], thesis: String) throws -> ApolloOrderPreview {
        let total = lines.reduce(Decimal.zero) { $0 + $1.cost }
        guard total > 0 else { throw ApolloGameError.invalidAmount }
        guard total <= state.cash else { throw ApolloGameError.insufficientFunds }
        let risk = try riskCheck(lines)
        var preview = ApolloOrderPreview(id: UUID().uuidString, assetID: assetID, lines: lines, total: total, thesis: thesis, expiresAt: Date().addingTimeInterval(300), riskCheck: risk)
        preview.portfolioBefore = snapshot().analytics
        var projected = state; projected.cash -= total
        for line in lines {
            if let index = projected.positions.firstIndex(where: { $0.assetID == line.assetID }) { projected.positions[index].quantity += line.quantity; projected.positions[index].cost += line.cost }
            else { projected.positions.append(.init(assetID: line.assetID, quantity: line.quantity, cost: line.cost, multiplier: line.multiplier)) }
        }
        preview.portfolioAfter = snapshot(projected).analytics
        pending[preview.id] = preview; return preview
    }
    public func setRiskProfile(_ tolerance: ApolloRiskTolerance) async throws -> ApolloAccount {
        var next = state; next.riskProfile = ApolloRiskProfile(tolerance: tolerance, ceiling: tolerance.ceiling)
        try save(next); return snapshot()
    }
    private let riskLevels: [String: Int] = ["AAPL": 3, "WINA": 4, "USDC-USD_DEMO": 3, "DEMO_USD_BOND_20281115": 2, "SPY": 2, "GLD": 3, "BTC-USD": 5, "VNQ": 3, "AAPL_20261120_C350_DEMO": 5]
    private func riskCheck(_ lines: [ApolloOrderLine]) throws -> ApolloRiskCheck {
        guard let profile = state.riskProfile else { throw ApolloGameError.service("Choose and confirm your paper-game risk profile before reviewing an investment.") }
        for line in lines {
            guard let level = riskLevels[line.assetID] else { throw ApolloGameError.service("Risk assessment unknown. Keep this asset on your watchlist until reviewed.") }
            guard level <= profile.ceiling else { throw ApolloGameError.service("This asset exceeds your chosen educational risk ceiling. Its sentiment is unknown, so no mixed-sentiment exception applies. Save it to your watchlist or explicitly change your profile.") }
        }
        return ApolloRiskCheck(status: "within_tolerance", requiresMixedException: false, notice: "DEMO educational risk rubric, not a probability of loss. Sentiment is unknown; no mixed-sentiment exception is implied.")
    }
    private func snapshot(_ account: ApolloAccount? = nil) -> ApolloAccount {
        let state = account ?? self.state
        var copy = state
        let values = state.positions.map { position -> (ApolloPosition, Decimal) in
            let item = catalogAssets.first { $0.id == position.assetID }
            return (position, item.map { $0.price * position.quantity * Decimal(position.multiplier) } ?? position.cost)
        }
        copy.positions = copy.positions.map { position in
            var marked = position
            if let item = catalogAssets.first(where: { $0.id == position.assetID }), item.bond?.isMatured == true { marked.valuationProvenance = "Matured · unsettled demo snapshot. Coupon payments and maturity settlement are not simulated." }
            return marked
        }
        let holdings = values.reduce(Decimal.zero) { $0 + $1.1 }; let equity = holdings + state.cash
        let denominator = equity > 0 ? equity : 1
        var byKind: [String: Decimal] = [:]; var weighted = Decimal.zero; var covered = Decimal.zero; var outside: [String] = []
        for (position, value) in values {
            let kind = catalogAssets.first { $0.id == position.assetID }?.kind.label ?? "Unknown"
            byKind[kind, default: 0] += value
            if let level = riskLevels[position.assetID] { weighted += value * Decimal(level); covered += value; if let ceiling = state.riskProfile?.ceiling, level > ceiling { outside.append(position.assetID) } }
        }
        copy.analytics = ApolloPortfolioAnalytics(equity: equity, cashWeight: state.cash / denominator, assetClasses: byKind.sorted { $0.key < $1.key }.map { .init(label: $0.key, value: $0.value, weight: $0.value / denominator) }, weightedRisk: covered > 0 ? weighted / covered : nil, riskCoverage: holdings > 0 ? covered / holdings : 0, outsideToleranceAssetIDs: outside)
        return copy
    }
    /// Pure projections: never calls save, makePreview, record or confirmation.
    public func comparePaper(assetID: String, quantity: Decimal, strategyBudget: Decimal?) async throws -> ApolloPaperComparison {
        let line = try comparisonLine(assetID: assetID, quantity: quantity)
        guard line.cost <= state.cash else { throw ApolloGameError.insufficientFunds }
        let budget = strategyBudget ?? line.cost
        let strategyID = "DEMO_PATIENT_BUILDER"
        let strategy = try asset(strategyID)
        let copyLines = try comparisonCopyLines(strategyID: strategyID, budget: budget)
        let copyTotal = copyLines.reduce(Decimal.zero) { $0 + $1.cost }
        let baseline = snapshot().analytics!
        let profiles = ApolloRiskTolerance.allCases.map { tolerance -> ApolloComparisonProfile in
            var current = state; current.riskProfile = .init(tolerance: tolerance, ceiling: tolerance.ceiling)
            let invested = comparisonAccount(current, lines: [line]); let copied = comparisonAccount(current, lines: copyLines)
            return .init(tolerance: tolerance, ceiling: tolerance.ceiling, current: snapshot(current).analytics!, investment: .init(riskCheck: comparisonRisk([line], tolerance: tolerance), portfolioAfter: snapshot(invested).analytics!), strategy: .init(riskCheck: comparisonRisk(copyLines, tolerance: tolerance), portfolioAfter: snapshot(copied).analytics!))
        }
        let invested = snapshot(comparisonAccount(state, lines: [line])).analytics!
        let copied = snapshot(comparisonAccount(state, lines: copyLines)).analytics!
        let outcomes = ApolloComparisonOutcomes(current: comparisonOutcomes(baseline), investment: comparisonOutcomes(invested), strategy: comparisonOutcomes(copied))
        return ApolloPaperComparison(modeLabel: "DEMO · READ-ONLY", mutatesAccount: false, baseline: baseline, recordedPaperPnL: baseline.equity - ApolloAccount.empty.cash, recordedPaperPnLLabel: "Recorded DEMO snapshot against initial paper cash, not real or verified historical investment performance", investmentLines: [line], investmentTotal: line.cost, strategyID: strategyID, strategyName: strategy.name, strategyProvenance: "Fictional DEMO allocation, no verified track record. " + strategy.changeLabel, strategyLines: copyLines, strategyTotal: copyTotal, strategyBudget: budget, uninvestedBudget: budget - copyTotal, profiles: profiles, outcomes: outcomes)
    }
    private func comparisonLine(assetID: String, quantity: Decimal) throws -> ApolloOrderLine {
        let item = try asset(assetID)
        guard item.kind != .strategy, quantity > 0, quantity.isFinite, quantity <= 1_000_000 else { throw ApolloGameError.invalidAmount }
        let step = item.quantityStep ?? ((item.kind == .option || item.kind == .bond) ? 1 : Decimal(string: "0.00000001")!)
        guard step > 0 else { throw ApolloGameError.invalidAmount }
        let ratio = quantity / step
        var raw = ratio; var whole = Decimal.zero
        NSDecimalRound(&whole, &raw, 0, .down)
        guard ratio == whole else { throw ApolloGameError.invalidAmount }
        if let bond = item.bond, bond.isMatured { throw ApolloGameError.service("Matured bond · unsettled demo snapshot. New paper trades are unavailable; maturity settlement and coupon payments are not simulated.") }
        if item.kind == .option {
            if let option = item.optionTerms {
                guard let expires = ISO8601DateFormatter().date(from: option.expiresAt), expires > Date() else { throw ApolloGameError.expired }
            } else if let expiry = item.expiry, expiry < Self.day(Date()) { throw ApolloGameError.expired }
        }
        return .init(assetID: assetID, quantity: quantity, price: item.price, multiplier: item.multiplier)
    }
    private func comparisonCopyLines(strategyID: String, budget: Decimal) throws -> [ApolloOrderLine] {
        let strategy = try asset(strategyID)
        guard strategy.kind == .strategy, budget > 0, budget.isFinite, budget <= state.cash, !strategy.allocations.isEmpty else { throw ApolloGameError.invalidAmount }
        guard strategy.allocations.reduce(Decimal.zero, { $0 + $1.weight }) == 1 else { throw ApolloGameError.invalidAmount }
        return try strategy.allocations.map { allocation in
            let item = try asset(allocation.assetID)
            guard item.kind != .strategy, item.kind != .option, allocation.weight > 0, item.price > 0 else { throw ApolloGameError.invalidAmount }
            var raw = budget * allocation.weight / item.price; var quantity = Decimal.zero
            NSDecimalRound(&quantity, &raw, 8, .down)
            return try comparisonLine(assetID: item.id, quantity: quantity)
        }
    }
    private func comparisonAccount(_ account: ApolloAccount, lines: [ApolloOrderLine]) -> ApolloAccount {
        var next = account; next.cash -= lines.reduce(Decimal.zero) { $0 + $1.cost }
        for line in lines {
            if let i = next.positions.firstIndex(where: { $0.assetID == line.assetID }) { next.positions[i].quantity += line.quantity; next.positions[i].cost += line.cost }
            else { next.positions.append(.init(assetID: line.assetID, quantity: line.quantity, cost: line.cost, multiplier: line.multiplier)) }
        }
        return next
    }
    private func comparisonRisk(_ lines: [ApolloOrderLine], tolerance: ApolloRiskTolerance) -> ApolloRiskCheck {
        let unknown = lines.filter { riskLevels[$0.assetID] == nil }.map(\.assetID)
        let outside = lines.filter { (riskLevels[$0.assetID] ?? 6) > tolerance.ceiling }.map(\.assetID)
        return .init(status: unknown.isEmpty && outside.isEmpty ? "within_tolerance" : "blocked", requiresMixedException: false, notice: unknown.isEmpty && outside.isEmpty ? "Within the DEMO educational ceiling; this comparison does not authorize an order." : "Hypothetical only: risk exceeds this ceiling or is unknown. No scored mixed sentiment is available for a paper exception.", outsideAssetIDs: outside)
    }
    private func comparisonOutcomes(_ analytics: ApolloPortfolioAnalytics) -> [ApolloComparisonOutcome] {
        let cash = analytics.equity * analytics.cashWeight; let holdings = analytics.equity - cash
        return [Decimal(string: "-0.2")!, 0, Decimal(string: "0.2")!].map { shock in
            let shocked = holdings * (1 + shock)
            return .init(shock: shock, holdingMarkValue: shocked, equity: cash + shocked, changeFromSnapshot: shocked - holdings, label: "DEMO uniform holding-mark sensitivity only, not a return forecast, probability, historical result, or option-expiry model. Fees and slippage excluded.")
        }
    }
    private func asset(_ id: String) throws -> ApolloAsset {
        guard let item = catalogAssets.first(where: { $0.id == id }) else { throw ApolloGameError.unknownAsset }; return item
    }
    private func save(_ next: ApolloAccount) throws {
        do { defaults.set(try JSONEncoder().encode(next), forKey: storageKey); state = next }
        catch { throw ApolloGameError.persistence("Your paper state could not be saved. Try again.") }
    }
    private static func day(_ date: Date) -> String {
        let format = DateFormatter(); format.calendar = Calendar(identifier: .gregorian); format.locale = Locale(identifier: "en_US_POSIX"); format.timeZone = TimeZone(secondsFromGMT: 0); format.dateFormat = "yyyy-MM-dd"; return format.string(from: date)
    }
}
