import SwiftUI

public enum ApolloGameDestination: Int { case discover = 0, watchlist = 1, portfolio = 2, learn = 3 }

/// Native game entry. Defaults to persistent, labeled device-local demo paper investing.
/// Supply an ApolloGameService to connect research and paper APIs. Diagnostics preserves the provider viewer.
@MainActor public struct ApolloGameRootView: View {
    @StateObject private var store: ApolloGameStore
    private let diagnostics: (() -> AnyView)?
    private let initialOrderAssetID: String?
    private let initialRiskComparison: Bool
    private let appearance: ColorScheme?
    @State private var selection = 0
    public init(service: (any ApolloGameService)? = nil, diagnostics: (() -> AnyView)? = nil, initialDestination: ApolloGameDestination = .discover, initialOrderAssetID: String? = nil, initialRiskComparison: Bool = false, chartContent: ((ApolloAsset) -> AnyView)? = nil, settingsContent: (() -> AnyView)? = nil, appearance: ColorScheme? = .light, discoveryDefaults: UserDefaults = .standard, discoveryKey: String = "apollo.game.discovery.v1") {
        _store = StateObject(wrappedValue: ApolloGameStore(service: service ?? ApolloDemoGameService(), chartContent: chartContent, settingsContent: settingsContent, discoveryDefaults: discoveryDefaults, discoveryKey: discoveryKey))
        self.diagnostics = diagnostics
        self.initialOrderAssetID = initialOrderAssetID
        self.initialRiskComparison = initialRiskComparison
        self.appearance = appearance
        _selection = State(initialValue: initialRiskComparison ? ApolloGameDestination.portfolio.rawValue : initialOrderAssetID == nil ? initialDestination.rawValue : ApolloGameDestination.discover.rawValue)
    }
    public var body: some View {
        TabView(selection: $selection) {
            NavigationStack { ApolloDiscoverView(store: store, diagnostics: diagnostics, initialOrderAssetID: initialRiskComparison ? nil : initialOrderAssetID) }
                .tabItem { Label("Discover", systemImage: "rectangle.on.rectangle.angled") }.tag(0)
            NavigationStack { ApolloWatchlistView(store: store) }
                .tabItem { Label("Watchlist", systemImage: "bookmark") }.tag(1)
            NavigationStack { ApolloPortfolioView(store: store, showComparisonInitially: initialRiskComparison) }
                .tabItem { Label("Portfolio", systemImage: "chart.pie") }.tag(2)
            NavigationStack { ApolloLearnView(store: store) }
                .tabItem { Label("Learn", systemImage: "sparkles") }.tag(3)
        }
        .tint(ApolloStyle.lime).preferredColorScheme(appearance)
        .toolbarBackground(ApolloStyle.ink, for: .tabBar)
        .environmentObject(store)
        .onChange(of: store.portfolioRequest) { _, _ in selection = ApolloGameDestination.portfolio.rawValue }
        .task { await store.load() }
        .alert("Couldn’t complete that action", isPresented: Binding(get: { store.error != nil }, set: { if !$0 { store.error = nil } })) {
            Button("OK") { store.error = nil }
        } message: { Text(store.error ?? "Please try again.") }
    }
}

private struct ApolloDiscoverView: View {
    @ObservedObject var store: ApolloGameStore
    let diagnostics: (() -> AnyView)?
    let initialOrderAssetID: String?
    @State private var initialPresentationApplied = false
    @State private var detail: ApolloAsset?
    @State private var order: ApolloAsset?
    @State private var drag: CGSize = .zero
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                HStack(alignment: .firstTextBaseline) {
                    if store.isReturningUser {
                        VStack(alignment: .leading, spacing: 6) { ApolloEyebrow(text: "Your next decision"); Text("Keep exploring.").font(.system(.title2, design: .serif).weight(.medium)) }.accessibilityIdentifier("returning-discovery-header")
                    } else {
                        VStack(alignment: .leading, spacing: 6) { ApolloEyebrow(text: "Build your investing instinct"); Text("Find your next\n“tell me more.”").font(.system(.largeTitle, design: .serif).weight(.medium)) }
                    }
                    Spacer(minLength: 0)
                }
                filters
                if store.loading && store.assets.isEmpty { ProgressView("Preparing your deck…").frame(maxWidth: .infinity).padding(50) }
                else if let asset = store.deck.first {
                    VStack(spacing: 18) {
                        ApolloAssetCard(asset: asset)
                            .accessibilityElement(children: .ignore)
                            .accessibilityAddTraits(.isButton)
                            .accessibilityIdentifier("asset-card")
                            .accessibilityLabel("\(asset.ticker), \(asset.name). \(asset.kind.label). \(asset.isDemo ? "Demo fixture" : "Sourced data"). Open research")
                            .accessibilityAction { detail = asset }
                            .accessibilityAction(named: "Pass") { Task { await store.decide(asset, .pass) } }
                            .accessibilityAction(named: "Watch") { Task { await store.decide(asset, .watchlist) } }
                            .accessibilityAction(named: "Review paper order") { beginOrder(asset) }
                            .offset(x: reduceMotion ? 0 : drag.width * 0.35, y: reduceMotion ? 0 : min(drag.height, 0) * 0.25)
                            .rotationEffect(.degrees(reduceMotion ? 0 : Double(drag.width / 40)))
                            .contentShape(RoundedRectangle(cornerRadius: 30))
                            .highPriorityGesture(cardGesture(asset))
                    }
                } else {
                    ApolloEmptyState(title: store.assets.isEmpty ? "Your deck is unavailable" : "A little wiser already.", message: store.assets.isEmpty ? "Refresh to try loading research again." : store.discovery.selectedTypes.isEmpty ? "Choose at least one asset type in your library to receive cards." : "You’ve explored the available cards in these types. You can review your library or start another practice round.", symbol: "sparkles")
                    ApolloPrimaryButton(title: store.assets.isEmpty ? "Try again" : "Explore again") { if store.assets.isEmpty { Task { await store.load() } } else { store.reviewed = [] } }
                }
                if let feedback = store.feedback {
                    HStack(alignment: .top, spacing: 12) { Image(systemName: "lightbulb").foregroundStyle(ApolloStyle.lime); Text(feedback).font(.subheadline); Button { store.feedback = nil } label: { Image(systemName: "xmark").padding(12) }.accessibilityLabel("Dismiss feedback") }
                        .padding(16).background(ApolloStyle.raised, in: RoundedRectangle(cornerRadius: 18)).accessibilityIdentifier("decision-feedback")
                }
                HStack(alignment: .top, spacing: 10) { Image(systemName: "shield.lefthalf.filled"); Text("Practice with paper money. Demo prices and scenario charts are labeled. Research helps you ask better questions; it cannot promise returns or the right time to buy.") }.font(.caption).foregroundStyle(ApolloStyle.muted)
            }.padding(20).frame(maxWidth: 620)
                .frame(maxWidth: .infinity)
        }.background(ApolloStyle.ink).foregroundStyle(ApolloStyle.cream)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if let asset = store.deck.first {
                    VStack(spacing: 6) {
                        HStack(spacing: 12) {
                            actionButton("Pass", symbol: "xmark", id: "pass-button") { Task { await store.decide(asset, .pass) } }
                            actionButton("Watch", symbol: "bookmark", id: "watch-button") { Task { await store.decide(asset, .watchlist) } }
                            actionButton("Invest", symbol: "arrow.up.right", id: "invest-button", primary: true) { beginOrder(asset) }
                        }
                        Text("← Pass   ·   ↑ Watch   ·   → Review paper order").font(.caption2).foregroundStyle(ApolloStyle.muted)
                    }.padding(.horizontal, 20).padding(.top, 10).padding(.bottom, 6).background(ApolloStyle.ink)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .refreshable { await store.load() }
            .onChange(of: store.portfolioRequest) { _, _ in order = nil; detail = nil }
            .onChange(of: store.deck.first?.id, initial: true) { _, id in store.markSeen(id) }
            .onChange(of: store.assets.map(\.id), initial: true) { _, _ in
                guard !initialPresentationApplied, let initialOrderAssetID, !store.assets.isEmpty else { return }
                initialPresentationApplied = true
                guard let asset = store.asset(initialOrderAssetID) else { store.error = "The requested asset is unavailable. No order or preview was created."; return }
                // Presentation only: no decision, profile selection, thesis, preview, or confirmation is generated.
                order = asset
            }
            .sheet(item: $detail) { asset in ApolloAssetDetailView(asset: asset, store: store) }
            .sheet(item: $order) { asset in ApolloOrderView(asset: asset, store: store) }
    }
    private var header: some View {
        HStack {
            HStack(spacing: 8) { ApolloAscendingMark().fill(ApolloStyle.lime).frame(width: 28, height: 28).accessibilityHidden(true); Text("apollo").font(.system(.title2, design: .rounded).weight(.bold)) }
            Spacer()
            if let settingsContent = store.settingsContent { NavigationLink { settingsContent() } label: { Image(systemName: "gearshape").frame(width: 44, height: 44) }.accessibilityLabel("Settings").accessibilityIdentifier("game-settings") }
            if let diagnostics { NavigationLink { diagnostics() } label: { Image(systemName: "waveform.path.ecg").frame(width: 44, height: 44) }.accessibilityLabel("Provider diagnostics").accessibilityIdentifier("provider-diagnostics") }
            Text("PAPER").font(.caption2.bold()).tracking(1).padding(.horizontal, 12).padding(.vertical, 8).background(ApolloStyle.raised, in: Capsule()).foregroundStyle(ApolloStyle.lime)
        }
    }
    private var filters: some View {
        HStack {
            Menu {
                Button("All selected types") { store.filter = nil }.accessibilityIdentifier("filter-all")
                ForEach(ApolloAssetKind.allCases.filter { store.discovery.selectedTypes.contains($0) }) { kind in
                    Button { store.filter = kind } label: { Label(kind.label, systemImage: kind.symbol) }.accessibilityIdentifier("filter-\(kind.rawValue)")
                }
            } label: { Label(store.filter?.label ?? "All selected types", systemImage: "line.3.horizontal.decrease").font(.subheadline.weight(.semibold)).frame(minHeight: 44) }.accessibilityIdentifier("asset-type-menu")
            Spacer()
            NavigationLink { ApolloLibraryView(store: store) } label: { Label("Library", systemImage: "books.vertical").font(.subheadline).frame(minHeight: 44) }.accessibilityIdentifier("game-library")
        }.accessibilityElement(children: .contain).accessibilityIdentifier("asset-filters")
    }
    private func filterButton(_ title: String, kind: ApolloAssetKind?) -> some View {
        Button { store.filter = kind } label: { Text(title).font(.subheadline.weight(.medium)).padding(.horizontal, 16).frame(minHeight: 44).background(store.filter == kind ? ApolloStyle.cream : ApolloStyle.surface, in: Capsule()).foregroundStyle(store.filter == kind ? ApolloStyle.ink : ApolloStyle.cream) }.buttonStyle(.plain).accessibilityAddTraits(store.filter == kind ? .isSelected : []).accessibilityIdentifier("filter-\(kind?.rawValue ?? "all")")
    }
    private func actionButton(_ title: String, symbol: String, id: String, primary: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) { VStack(spacing: 8) { Image(systemName: symbol).font(.title3.weight(.semibold)); Text(title).font(.caption.weight(.semibold)) }.frame(maxWidth: .infinity).frame(minHeight: 72).background(primary ? ApolloStyle.lime : ApolloStyle.surface, in: RoundedRectangle(cornerRadius: 22)).foregroundStyle(primary ? ApolloStyle.ink : ApolloStyle.cream) }.buttonStyle(.plain).disabled(store.busy).accessibilityIdentifier(id)
    }
    private func cardGesture(_ asset: ApolloAsset) -> some Gesture {
        DragGesture(minimumDistance: 24)
            .onChanged { if !store.busy { drag = $0.translation } }
            .onEnded { value in
                defer { withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) { drag = .zero } }
                guard !store.busy else { return }
                if value.translation.height < -65 && abs(value.translation.height) > abs(value.translation.width) { Task { await store.decide(asset, .watchlist) } }
                else if value.translation.width > 65 { beginOrder(asset) }
                else if value.translation.width < -65 { Task { await store.decide(asset, .pass) } }
            }
            .exclusively(before: TapGesture().onEnded { if !store.busy { detail = asset } })
    }
    private func beginOrder(_ asset: ApolloAsset) { Task { if await store.decide(asset, .interest) { order = asset } } }
}

struct ApolloAssetCard: View {
    let asset: ApolloAsset
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(alignment: .top) {
                Image(systemName: asset.kind.symbol).font(.title2).frame(width: 52, height: 52).background(ApolloStyle.raised, in: RoundedRectangle(cornerRadius: 16))
                VStack(alignment: .leading, spacing: 5) { Text(asset.ticker).font(.headline); Text(asset.name).font(.caption).foregroundStyle(ApolloStyle.muted) }
                Spacer(minLength: 4)
                Image(systemName: "arrow.up.right").foregroundStyle(ApolloStyle.muted)
            }
            HStack { ApolloEyebrow(text: asset.kind.label); Spacer(); Text(asset.isDemo ? "DEMO" : "SOURCED").font(.caption2.bold()).foregroundStyle(ApolloStyle.lime) }
            Text(asset.headline).font(.system(.largeTitle, design: .serif).weight(.medium)).multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
            Text(asset.summary).font(.subheadline).foregroundStyle(ApolloStyle.muted).multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
            ApolloSparkline(values: asset.chart).frame(height: 82).accessibilityLabel(asset.isDemo ? "Illustrative scenario chart, not historical performance" : "Price chart; open research for provenance")
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 5) { Text(asset.kind == .strategy ? "Allocation study" : asset.price.apolloMoney).font(.title2.weight(.semibold)).monospacedDigit(); Text(asset.priceLabel).font(.caption2).foregroundStyle(ApolloStyle.muted) }
                Spacer()
                Label("Research", systemImage: "plus.circle").font(.caption.weight(.semibold)).foregroundStyle(ApolloStyle.lime)
            }
            Text(asset.isDemo ? "Illustrative chart · not historical returns" : asset.changeLabel).font(.caption2).foregroundStyle(ApolloStyle.muted)
        }.padding(24).frame(maxWidth: .infinity, alignment: .leading).background(ApolloStyle.surface, in: RoundedRectangle(cornerRadius: 30)).overlay(RoundedRectangle(cornerRadius: 30).stroke(ApolloStyle.muted.opacity(0.12), lineWidth: 1))
    }
}
struct ApolloSparkline: View {
    let values: [Double]
    var body: some View {
        GeometryReader { geo in
            let low = values.min() ?? 0; let high = values.max() ?? 1; let span = max(high - low, 1)
            ZStack {
                ForEach(0..<3) { row in Path { path in let y = geo.size.height * CGFloat(row) / 2; path.move(to: CGPoint(x: 0, y: y)); path.addLine(to: CGPoint(x: geo.size.width, y: y)) }.stroke(ApolloStyle.muted.opacity(0.12), style: StrokeStyle(lineWidth: 1, dash: [3, 5])) }
                if values.count > 1 {
                    Path { path in for (i, value) in values.enumerated() { let p = CGPoint(x: geo.size.width * CGFloat(i) / CGFloat(values.count - 1), y: geo.size.height * (1 - CGFloat((value - low) / span)) * 0.84 + geo.size.height * 0.08); if i == 0 { path.move(to: p) } else { path.addLine(to: p) } } }.stroke(ApolloStyle.lime, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                } else { Text("No chart data").font(.caption).foregroundStyle(ApolloStyle.muted).frame(maxWidth: .infinity, maxHeight: .infinity) }
            }
        }
    }
}
