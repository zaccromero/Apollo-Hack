import Foundation

/// Local browsing state has no service, persistence or decision capability.
struct ApolloCompanyNavigation {
    enum Side { case previous, next }
    let assetID: String
    private(set) var panel: ApolloCompanyPanel = .overview
    mutating func show(_ panel: ApolloCompanyPanel) { self.panel = panel }
    mutating func step(_ side: Side) {
        let all = ApolloCompanyPanel.allCases
        let index = all.firstIndex(of: panel) ?? 0
        panel = all[side == .previous ? max(0, index - 1) : min(all.count - 1, index + 1)]
    }
}

enum ApolloCardInteraction {
    /// Ambiguous diagonals, downward scrolling and small finger movements are not decisions.
    static func decision(horizontal x: Double, vertical y: Double) -> ApolloDecision? {
        guard x.isFinite, y.isFinite else { return nil }
        if y < -65 && abs(y) >= abs(x) * 1.25 { return .watchlist }
        if abs(x) > 65 && abs(x) >= abs(y) * 1.25 { return x > 0 ? .interest : .pass }
        return nil
    }
    static func canDecide(gestureAssetID: String, currentAssetID: String?, busy: Bool, modal: Bool, pending: Bool) -> Bool {
        !gestureAssetID.isEmpty && currentAssetID == gestureAssetID && !busy && !modal && !pending
    }
    static func canBrowse(now: TimeInterval, blockedUntil: TimeInterval, busy: Bool, modal: Bool, pending: Bool) -> Bool {
        now.isFinite && blockedUntil.isFinite && now >= blockedUntil && !busy && !modal && !pending
    }
}

/// Presentation intent is distinct from a persisted financial decision.
enum ApolloSwipeAction: String {
    case pass, watch, review, edit
    var title: String { switch self { case .pass: return "Pass"; case .watch: return "Watch"; case .review: return "Review $10"; case .edit: return "Edit amount & pitch" } }
    var symbol: String { switch self { case .pass: return "xmark"; case .watch: return "bookmark.fill"; case .review: return "dollarsign.circle.fill"; case .edit: return "square.and.pencil" } }
}
extension ApolloCardInteraction {
    static func swipeAction(horizontal x: Double, vertical y: Double, threshold: Double = 65) -> ApolloSwipeAction? {
        guard x.isFinite, y.isFinite, threshold.isFinite, threshold > 0 else { return nil }
        if abs(y) > threshold && abs(y) >= abs(x) * 1.25 { return y < 0 ? .watch : .edit }
        if abs(x) > threshold && abs(x) >= abs(y) * 1.25 { return x < 0 ? .pass : .review }
        return nil
    }
    /// Rounds DOWN to the asset step. Never increases the requested cash budget.
    static func quantity(budget: Decimal, asset: ApolloAsset) -> Decimal? {
        guard budget.isFinite, budget > 0 else { return nil }
        if asset.kind == .strategy { return budget }
        let step = asset.quantityStep ?? ((asset.kind == .option || asset.kind == .bond) ? 1 : Decimal(string: "0.00000001")!)
        guard asset.price.isFinite, asset.price > 0, asset.multiplier > 0, step.isFinite, step > 0 else { return nil }
        let unitCost = asset.price * Decimal(asset.multiplier)
        guard unitCost.isFinite, unitCost > 0 else { return nil }
        var steps = budget / unitCost / step; var rounded = Decimal.zero
        NSDecimalRound(&rounded, &steps, 0, .down)
        let quantity = rounded * step
        guard quantity.isFinite, quantity > 0, quantity * unitCost <= budget else { return nil }
        return quantity
    }
}
