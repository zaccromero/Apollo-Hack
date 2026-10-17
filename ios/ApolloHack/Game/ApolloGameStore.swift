import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

@MainActor final class ApolloGameStore: ObservableObject {
    @Published var assets: [ApolloAsset] = []
    @Published var account: ApolloAccount = .empty
    @Published var loading = false
    @Published var busy = false
    @Published var error: String?
    @Published var feedback: String?
    @Published var reviewed: Set<String> = []
    @Published private(set) var discovery: ApolloDiscoveryPreferences
    private let discoveryDefaults: UserDefaults
    private let discoveryKey: String
    @Published var filter: ApolloAssetKind?
    @Published private(set) var isReturningUser: Bool = false
    private var sessionClassified = false
    @Published var portfolioRequest: UUID?
    @Published var challengeDrafts: [String: ApolloThesis] = [:]
    let service: any ApolloGameService
    let chartContent: ((ApolloAsset) -> AnyView)?
    let settingsContent: (() -> AnyView)?
    init(service: any ApolloGameService, chartContent: ((ApolloAsset) -> AnyView)? = nil, settingsContent: (() -> AnyView)? = nil, discoveryDefaults: UserDefaults = .standard, discoveryKey: String = "apollo.game.discovery.v1") {
        self.service = service; self.chartContent = chartContent; self.settingsContent = settingsContent
        self.discoveryDefaults = discoveryDefaults; self.discoveryKey = discoveryKey
        self.discovery = ApolloDiscoveryPreferences.load(defaults: discoveryDefaults, key: discoveryKey)
        self.isReturningUser = !self.discovery.seenAssetIDs.isEmpty
    }
    var deck: [ApolloAsset] { assets.filter { discovery.includes($0) && (filter == nil || $0.kind == filter) && !reviewed.contains($0.id) } }
    var watched: [ApolloAsset] { assets.filter { account.watchlistIDs.contains($0.id) } }
    var portfolioValue: Decimal {
        account.positions.reduce(Decimal.zero) { value, position in
            value + self.value(of: position)
        }
    }
    func value(of position: ApolloPosition) -> Decimal {
        if let marked = position.marketValue { return marked }
        if let price = position.valuationPrice { return price * position.quantity * Decimal(position.multiplier) }
        if service is ApolloDemoGameService, let item = asset(position.assetID) { return item.price * position.quantity * Decimal(position.multiplier) }
        return position.cost
    }
    func provenance(of position: ApolloPosition) -> String {
        if let provenance = position.valuationProvenance { return provenance }
        return service is ApolloDemoGameService ? "Demo fixture mark · not a live valuation" : "Cost fallback · paper mark unavailable"
    }
    var totalValue: Decimal { account.analytics?.equity ?? account.cash + portfolioValue }
    var decisionsCount: Int { account.decisions.count }
    func asset(_ id: String) -> ApolloAsset? { assets.first { $0.id == id } }
    func load() async {
        guard !loading else { return }; loading = true; defer { loading = false }
        do { let catalog = try await service.catalog(); let state = try await service.account(); assets = catalog; account = state
            if !sessionClassified { isReturningUser = isReturningUser || !state.decisions.isEmpty || !state.fills.isEmpty; sessionClassified = true }
            reviewed.formUnion(state.decisions.filter { $0.action == .pass || $0.action == .watchlist }.map(\.assetID)); reviewed.formUnion(state.fills.map(\.assetID)) }
        catch { self.error = error.localizedDescription }
    }
    func setType(_ kind: ApolloAssetKind, enabled: Bool) {
        var next = discovery
        if enabled { next.selectedTypes.insert(kind) } else { next.selectedTypes.remove(kind) }
        do { try next.save(defaults: discoveryDefaults, key: discoveryKey); discovery = next; if filter == kind && !enabled { filter = nil } }
        catch { self.error = "Your type preferences could not be saved. Try again." }
    }
    func markSeen(_ id: String?) {
        guard let id, !discovery.seenAssetIDs.contains(id) else { return }
        var next = discovery; next.seenAssetIDs.insert(id)
        do { try next.save(defaults: discoveryDefaults, key: discoveryKey); discovery = next }
        catch { self.error = "Your discovery history could not be saved. Try again." }
    }
    func libraryAssets(_ section: ApolloLibrarySection) -> [ApolloAsset] {
        switch section {
        case .available: return assets.filter { discovery.includes($0) && !reviewed.contains($0.id) }
        case .seen: return assets.filter { discovery.seenAssetIDs.contains($0.id) }
        case .passed:
            let last = Dictionary(grouping: account.decisions.filter { $0.action != .interest && $0.action != .removeWatchlist }, by: \.assetID)
            return assets.filter { last[$0.id]?.last?.action == .pass }
        case .watched: return watched
        }
    }
    @discardableResult func decide(_ asset: ApolloAsset, _ action: ApolloDecision, thesis: String = "") async -> Bool {
        guard !busy else { return false }; busy = true; defer { busy = false }
        do {
            account = try await service.record(assetID: asset.id, action: action, thesis: thesis)
            if action != .interest { reviewed.insert(asset.id) }
            feedback = action == .removeWatchlist ? "Removed \(asset.ticker) from your watchlist." : action == .watchlist ? "Saved \(asset.ticker). A watchlist is a research queue, not a commitment." : action == .pass ? "Passed \(asset.ticker). Waiting is a decision too. \(asset.lesson)" : nil
            return true
        } catch { self.error = error.localizedDescription; return false }
    }
    func confirm(_ preview: ApolloOrderPreview) async -> Bool {
        guard !busy else { return false }
        guard let check = preview.riskCheck else { error = "Risk assessment is unavailable. Review this asset before proceeding."; return false }
        guard !check.requiresMixedException || preview.mixedExceptionAcknowledged else { error = "Explicitly acknowledge the above-tolerance paper exception."; return false }
        busy = true; defer { busy = false }
        do {
            account = try await service.confirm(preview); reviewed.insert(preview.assetID)
            feedback = "Paper order filled. Check your holdings and revisit the thesis. No real money moved."
            return true
        } catch { self.error = error.localizedDescription; return false }
    }
    func setRiskProfile(_ tolerance: ApolloRiskTolerance) async -> Bool {
        guard !busy else { return false }; busy = true; defer { busy = false }
        do { account = try await service.setRiskProfile(tolerance); return true }
        catch { self.error = error.localizedDescription; return false }
    }
    func reset() async {
        guard !busy else { return }; busy = true; defer { busy = false }
        do { account = try await service.reset(); reviewed = []; feedback = "Paper portfolio reset. Your next decision starts fresh." }
        catch { self.error = error.localizedDescription }
    }
}

enum ApolloStyle {
    static let ink = themed(0xF4F7FF, 0x0B1428)
    static let surface = themed(0xFFFFFF, 0x121F36)
    static let raised = themed(0xE4ECFF, 0x1C2D4B)
    static let cream = themed(0x0B1428, 0xF4F7FF)
    static let lime = themed(0x3268DF, 0x6495FF)
    static let muted = themed(0x4A5A73, 0xA9B9D5)
    static let amber = themed(0x945000, 0xF5B94A)
    private static func themed(_ light: UInt32, _ dark: UInt32) -> Color {
        #if canImport(UIKit)
        return Color(uiColor: UIColor { traits in
            let value = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: CGFloat((value >> 16) & 255) / 255, green: CGFloat((value >> 8) & 255) / 255, blue: CGFloat(value & 255) / 255, alpha: 1)
        })
        #else
        return Color(red: Double((light >> 16) & 255) / 255, green: Double((light >> 8) & 255) / 255, blue: Double(light & 255) / 255)
        #endif
    }
}
struct ApolloPanel<Content: View>: View {
    @ViewBuilder let content: Content
    var body: some View { content.padding(20).frame(maxWidth: .infinity, alignment: .leading).background(ApolloStyle.surface, in: RoundedRectangle(cornerRadius: 24)) }
}
struct ApolloEyebrow: View {
    let text: String
    var body: some View { Text(text.uppercased()).font(.caption.weight(.semibold)).tracking(1.5).foregroundStyle(ApolloStyle.muted) }
}
struct ApolloPrimaryButton: View {
    let title: String
    var symbol: String = "arrow.right"
    var disabled = false
    let action: () -> Void
    var body: some View {
        Button(action: action) { HStack { Text(title); Spacer(); Image(systemName: symbol) }.font(.headline).padding(18).frame(maxWidth: .infinity).background(disabled ? ApolloStyle.raised : ApolloStyle.lime, in: RoundedRectangle(cornerRadius: 18)).foregroundStyle(disabled ? ApolloStyle.muted : ApolloStyle.ink) }
            .buttonStyle(.plain).disabled(disabled)
    }
}
struct ApolloEmptyState: View {
    let title: String; let message: String; let symbol: String
    var body: some View { VStack(spacing: 16) { Image(systemName: symbol).font(.system(size: 40)).foregroundStyle(ApolloStyle.lime); Text(title).font(.title2.bold()); Text(message).foregroundStyle(ApolloStyle.muted).multilineTextAlignment(.center) }.frame(maxWidth: .infinity).padding(.vertical, 48).padding(.horizontal, 24) }
}
