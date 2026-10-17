import SwiftUI

struct ApolloWatchlistView: View {
    @ObservedObject var store: ApolloGameStore
    @State private var detail: ApolloAsset?
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                ApolloEyebrow(text: "Curiosity, saved")
                Text("Worth another look.").font(.system(.largeTitle, design: .serif))
                Text("A place for ideas that need more evidence. Saving an asset never creates an order.").font(.subheadline).foregroundStyle(ApolloStyle.muted)
                if store.watched.isEmpty { ApolloEmptyState(title: "Keep your curiosity.", message: "Swipe up on a card or tap Watch. Your research queue will be here when you return.", symbol: "bookmark") }
                ForEach(store.watched) { asset in
                    ApolloPanel { VStack(alignment: .leading, spacing: 14) {
                        Button { detail = asset } label: { ApolloAssetRow(asset: asset) }.buttonStyle(.plain)
                        Text(asset.lesson).font(.caption).foregroundStyle(ApolloStyle.muted)
                        HStack { Button("Open research") { detail = asset }; Spacer(); Button("Remove") { Task { await store.decide(asset, .removeWatchlist) } }.disabled(store.busy).foregroundStyle(ApolloStyle.muted) }.font(.subheadline).frame(minHeight: 44)
                    } }
                }
            }.padding(24).frame(maxWidth: 620).frame(maxWidth: .infinity)
        }.background(ApolloStyle.ink).foregroundStyle(ApolloStyle.cream).navigationTitle("Watchlist").navigationBarTitleDisplayMode(.inline)
            .sheet(item: $detail) { ApolloAssetDetailView(asset: $0, store: store) }
            .refreshable { await store.load() }.accessibilityIdentifier("watchlist-screen")
    }
}
struct ApolloAssetRow: View {
    let asset: ApolloAsset
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: asset.kind.symbol).font(.title3).foregroundStyle(ApolloStyle.lime).frame(width: 44, height: 44).background(ApolloStyle.raised, in: RoundedRectangle(cornerRadius: 14))
            VStack(alignment: .leading, spacing: 5) { Text(asset.ticker).font(.headline); Text(asset.name).font(.caption).foregroundStyle(ApolloStyle.muted) }
            Spacer(minLength: 6)
            VStack(alignment: .trailing, spacing: 5) { Text(asset.kind == .strategy ? "Strategy" : asset.price.apolloMoney).font(.subheadline).monospacedDigit(); Text(asset.isDemo ? "DEMO" : "SOURCED").font(.caption2.bold()).foregroundStyle(ApolloStyle.muted) }
        }.frame(minHeight: 52)
    }
}
struct ApolloPortfolioView: View {
    @ObservedObject var store: ApolloGameStore
    var showComparisonInitially = false
    @State private var comparison = false
    @State private var initialComparisonApplied = false
    @State private var detail: ApolloAsset?
    @State private var resetConfirmation = false
    @State private var changeProfile = false
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                ApolloEyebrow(text: "A safe place to practice")
                Text("Your paper portfolio.").font(.system(.largeTitle, design: .serif))
                ApolloPanel { VStack(alignment: .leading, spacing: 18) {
                    Text("Total simulated value").font(.caption).foregroundStyle(ApolloStyle.muted)
                    Text(store.totalValue.apolloMoney).font(.system(.largeTitle, design: .rounded).weight(.medium)).monospacedDigit().accessibilityIdentifier("portfolio-total")
                    HStack { VStack(alignment: .leading, spacing: 5) { Text("Available cash").font(.caption).foregroundStyle(ApolloStyle.muted); Text(store.account.cash.apolloMoney).font(.headline).monospacedDigit().accessibilityIdentifier("portfolio-cash") }; Spacer(); VStack(alignment: .trailing, spacing: 5) { Text("Holdings value").font(.caption).foregroundStyle(ApolloStyle.muted); Text(store.portfolioValue.apolloMoney).font(.headline).monospacedDigit() } }
                    Divider()
                    Text("\(store.service.modeLabel). Marks use paper-engine values when supplied. Local demo uses fixture marks; unavailable server marks use cost. This total is not a live market valuation.").font(.caption).foregroundStyle(ApolloStyle.amber)
                } }
                ApolloPanel { VStack(alignment: .leading, spacing: 12) {
                    ApolloEyebrow(text: "Your risk profile")
                    if let profile = store.account.riskProfile { Text("\(profile.tolerance.label) · ceiling \(profile.ceiling)/5").font(.headline); Text(profile.label).font(.caption).foregroundStyle(ApolloStyle.muted) }
                    else { Text("Choose a profile before your first investment.").font(.subheadline).foregroundStyle(ApolloStyle.muted) }
                    Button(store.account.riskProfile == nil ? "Choose paper risk profile" : "Change paper risk profile") { changeProfile = true }.font(.subheadline.weight(.semibold)).frame(minHeight: 44).accessibilityIdentifier("portfolio-risk-profile")
                } }
                ApolloPrimaryButton(title: "Compare all three risk profiles", symbol: "square.split.2x2") { comparison = true }.accessibilityIdentifier("portfolio-compare")
                if let analytics = store.account.analytics { ApolloPortfolioInsightsView(analytics: analytics) }
                if store.account.positions.isEmpty { ApolloEmptyState(title: "Your first thesis starts it.", message: "Explore a card, make your case, then confirm a paper order. A right swipe alone never buys anything.", symbol: "chart.pie") }
                else {
                    ApolloEyebrow(text: "Holdings · \(store.account.positions.count)")
                    ForEach(store.account.positions) { position in
                        ApolloPanel { VStack(alignment: .leading, spacing: 14) {
                            if let asset = store.asset(position.assetID) { Button { detail = asset } label: { ApolloAssetRow(asset: asset) }.buttonStyle(.plain) }
                            else { Text(position.assetID).font(.headline) }
                            HStack { Text("\(position.quantity.apolloQuantity) \(store.asset(position.assetID)?.unit ?? "units")\(position.multiplier == 1 ? "" : " × \(position.multiplier)")"); Spacer(); Text("Value \(store.value(of: position).apolloMoney)") }.font(.caption).foregroundStyle(ApolloStyle.muted)
                            Text("Cost \(position.cost.apolloMoney) · \(store.provenance(of: position))").font(.caption).foregroundStyle(ApolloStyle.amber)
                        } }
                    }
                }
                if !store.account.fills.isEmpty {
                    ApolloEyebrow(text: "Decisions you can revisit")
                    ForEach(store.account.fills.reversed()) { fill in
                        ApolloPanel { VStack(alignment: .leading, spacing: 10) { HStack { Text(fill.assetID).font(.headline); Spacer(); Text(fill.cost.apolloMoney).monospacedDigit() }; Text(fill.date, style: .date).font(.caption).foregroundStyle(ApolloStyle.muted); Text(ApolloThesis.display(fill.thesis)).font(.subheadline); Label("Simulated fill", systemImage: "checkmark.circle").font(.caption).foregroundStyle(ApolloStyle.lime) } }
                    }
                }
                Button(role: .destructive) { resetConfirmation = true } label: { Label("Reset paper portfolio", systemImage: "arrow.counterclockwise").font(.subheadline).frame(maxWidth: .infinity, minHeight: 48) }.disabled(store.busy).accessibilityIdentifier("portfolio-reset")
            }.padding(24).frame(maxWidth: 620).frame(maxWidth: .infinity)
        }.background(ApolloStyle.ink).foregroundStyle(ApolloStyle.cream).navigationTitle("Portfolio").navigationBarTitleDisplayMode(.inline)
            .refreshable { await store.load() }
            .onChange(of: store.assets.map(\.id), initial: true) { _, _ in
                if showComparisonInitially && !initialComparisonApplied && !store.assets.isEmpty { initialComparisonApplied = true; comparison = true }
            }
            .sheet(isPresented: $comparison) { ApolloPaperComparisonView(store: store) }
            .sheet(item: $detail) { ApolloAssetDetailView(asset: $0, store: store) }
            .sheet(isPresented: $changeProfile) { NavigationStack { ScrollView { ApolloRiskProfileView(store: store) { changeProfile = false }.padding(24) }.background(ApolloStyle.ink).navigationTitle("Paper risk profile").navigationBarTitleDisplayMode(.inline).toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { changeProfile = false } } } } }
            .confirmationDialog("Reset your paper portfolio?", isPresented: $resetConfirmation, titleVisibility: .visible) { Button("Reset simulated cash and history", role: .destructive) { Task { await store.reset() } }; Button("Keep my portfolio", role: .cancel) {} } message: { Text("This clears paper holdings, watchlist, decisions and saved theses for this account and restores $10,000 simulated cash. It cannot be undone.") }.accessibilityIdentifier("portfolio-screen")
    }
}
struct ApolloLearnView: View {
    @ObservedObject var store: ApolloGameStore
    @State private var selected: ApolloAsset?
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                ApolloEyebrow(text: "Better questions. Better decisions.")
                Text("Build conviction.\nKeep perspective.").font(.system(.largeTitle, design: .serif))
                ApolloPanel { HStack(alignment: .top) { VStack(alignment: .leading, spacing: 8) { Text("\(store.decisionsCount)").font(.largeTitle.weight(.medium)).foregroundStyle(ApolloStyle.lime); Text("research decisions saved").font(.caption).foregroundStyle(ApolloStyle.muted) }; Spacer(); Image(systemName: "lightbulb").font(.largeTitle).foregroundStyle(ApolloStyle.lime) } }
                ApolloKnowledgeCheck()
                ApolloEyebrow(text: "Explore \(Set(store.assets.map(\.kind)).count) asset types")
                ForEach(store.assets) { asset in Button { selected = asset } label: { ApolloPanel { VStack(alignment: .leading, spacing: 12) { HStack { Image(systemName: asset.kind.symbol).foregroundStyle(ApolloStyle.lime); Text(asset.kind.label).font(.headline); Spacer(); Image(systemName: "arrow.up.right").foregroundStyle(ApolloStyle.muted) }; Text(asset.lesson).font(.subheadline).foregroundStyle(ApolloStyle.muted).multilineTextAlignment(.leading) } } }.buttonStyle(.plain).accessibilityIdentifier("learn-asset-\(asset.id)") }
                if !store.account.decisions.isEmpty {
                    ApolloEyebrow(text: "Your research trail")
                    ForEach(store.account.decisions.reversed().prefix(20)) { decision in HStack(alignment: .top, spacing: 12) { Image(systemName: decision.action == .watchlist ? "bookmark" : decision.action == .pass ? "xmark" : "arrow.up.right").foregroundStyle(ApolloStyle.lime).frame(width: 24); VStack(alignment: .leading, spacing: 5) { Text("\(decision.assetID) · \(decision.action.rawValue.capitalized)").font(.subheadline.weight(.semibold)); Text(decision.date, style: .date).font(.caption).foregroundStyle(ApolloStyle.muted); if !decision.thesis.isEmpty { Text(ApolloThesis.display(decision.thesis)).font(.caption).foregroundStyle(ApolloStyle.muted) } }; Spacer() }.padding(.vertical, 8) }
                }
            }.padding(24).frame(maxWidth: 620).frame(maxWidth: .infinity)
        }.background(ApolloStyle.ink).foregroundStyle(ApolloStyle.cream).navigationTitle("Learn").navigationBarTitleDisplayMode(.inline)
            .sheet(item: $selected) { ApolloAssetDetailView(asset: $0, store: store) }.accessibilityIdentifier("learn-screen")
    }
}
private struct ApolloKnowledgeCheck: View {
    @State private var choice: Int?
    var body: some View {
        ApolloPanel { VStack(alignment: .leading, spacing: 16) {
            ApolloEyebrow(text: "Quick check · options")
            Text("A long call is quoted at $5 with a 100-unit multiplier. What does one contract cost?").font(.headline)
            ForEach(Array(["$5", "$100", "$500"].enumerated()), id: \.offset) { index, title in Button { choice = index } label: { HStack { Text(title); Spacer(); if choice == index { Image(systemName: index == 2 ? "checkmark.circle.fill" : "arrow.counterclockwise") } }.font(.subheadline.weight(.semibold)).padding(16).frame(maxWidth: .infinity).background(choice == index ? ApolloStyle.raised : ApolloStyle.ink, in: RoundedRectangle(cornerRadius: 14)).foregroundStyle(choice == index ? ApolloStyle.lime : ApolloStyle.cream) }.buttonStyle(.plain).accessibilityIdentifier("quiz-\(index)") }
            if let choice { Text(choice == 2 ? "Exactly: $5 × 100 = $500, before any fees. The whole premium can be lost." : "Try the multiplier: quoted premium × 100 units. A $5 quote is not a $5 contract.").font(.subheadline).foregroundStyle(ApolloStyle.lime).accessibilityIdentifier("quiz-feedback") }
        } }
    }
}
