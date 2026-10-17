import SwiftUI

/// Stock information is presentation-only. Decisions belong to the outer card or explicit decision controls.
struct ApolloCompanyCardView: View {
    let asset: ApolloAsset
    @ObservedObject var store: ApolloGameStore
    let openResearch: () -> Void
    let decisionGesturesEnabled: Bool
    let canBrowse: () -> Bool
    let onBrowsePresentation: (Bool) -> Void
    @State private var navigation: ApolloCompanyNavigation
    private var panel: ApolloCompanyPanel { navigation.panel }
    init(asset: ApolloAsset, store: ApolloGameStore, openResearch: @escaping () -> Void, canBrowse: @escaping () -> Bool, decisionGesturesEnabled: Bool = true, onBrowsePresentation: @escaping (Bool) -> Void) {
        self.asset = asset; self.store = store; self.openResearch = openResearch
        self.canBrowse = canBrowse; self.decisionGesturesEnabled = decisionGesturesEnabled; self.onBrowsePresentation = onBrowsePresentation
        _navigation = State(initialValue: .init(assetID: asset.id))
    }
    @State private var expanded = false
    @State private var chart = false
    private var profile: ApolloCompanyProfile? { guard let value = asset.companyProfile, value.matches(assetID: asset.id, corpusHash: asset.researchCorpusHash) else { return nil }; return value }
    private var index: Int { ApolloCompanyPanel.allCases.firstIndex(of: panel) ?? 0 }
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                browseSurface(id: "company-header-tap") {
                    HStack(spacing: 8) {
                        Image(systemName: "building.2").font(.title3).foregroundStyle(ApolloStyle.lime)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(asset.ticker).font(.headline).accessibilityIdentifier("company-ticker")
                            Text(asset.name).font(.caption).foregroundStyle(ApolloStyle.muted)
                        }
                        Spacer(minLength: 0)
                    }
                }
                Button { move(.previous) } label: { Image(systemName: "chevron.left").frame(width: 44, height: 44) }.disabled(index == 0).accessibilityLabel("Previous company panel").accessibilityIdentifier("company-panel-previous")
                Text("\(index + 1) / 6").font(.caption.monospacedDigit()).accessibilityIdentifier("company-panel-progress")
                Button { move(.next) } label: { Image(systemName: "chevron.right").frame(width: 44, height: 44) }.disabled(index == 5).accessibilityLabel("Next company panel").accessibilityIdentifier("company-panel-next")
            }
            HStack(spacing: 5) {
                ForEach(ApolloCompanyPanel.allCases) { item in
                    Button { show(item) } label: { Capsule().fill(item == panel ? ApolloStyle.lime : ApolloStyle.muted.opacity(0.25)).frame(height: 5).frame(maxWidth: .infinity).frame(height: 44).contentShape(Rectangle()) }
                        .buttonStyle(.plain).accessibilityLabel(item.title).accessibilityIdentifier("company-panel-\(item.rawValue)").accessibilityAddTraits(item == panel ? .isSelected : [])
                }
            }
            if panel == .overview {
                VStack(alignment: .leading, spacing: 0) {
                    ApolloStockDecisionBrief(asset: asset, profile: profile, gistContent: { text in
                        AnyView(browseSurface(id: "company-tap") {
                            Text(text).font(.subheadline).fixedSize(horizontal: false, vertical: true).frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        })
                    })
                }.accessibilityElement(children: .contain).accessibilityIdentifier("company-content-overview")
            } else {
                browseSurface(id: "company-tap") {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(panel.title).font(.headline)
                        ApolloCompanyPanelContent(asset: asset, profile: profile, panel: panel, compact: true)
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            Button { panel == .chart ? presentChart() : presentDetails() } label: {
                Label(panel == .chart ? "Inspect chart" : "Read more & sources", systemImage: panel == .chart ? "chart.xyaxis.line" : "text.alignleft").font(.caption.weight(.semibold)).frame(minHeight: 44)
            }.accessibilityIdentifier(panel == .chart ? "company-inspect-chart" : "company-read-more")
            Divider()
            HStack { VStack(alignment: .leading, spacing: 3) { Text(asset.price.apolloMoney).font(.title3.weight(.semibold)); Text(asset.priceLabel).font(.caption2).foregroundStyle(ApolloStyle.muted) }; Spacer(); Button("Research") { if canBrowse() { openResearch() } }.frame(minHeight: 44).accessibilityIdentifier("company-full-research") }
            Text(decisionGesturesEnabled ? "Tap either side to browse sections. Read more opens a safe reading view. Swipe left to pass, up to watch, or right to review." : "Tap either side to browse sections. Read more and chart inspection keep this investment open.").font(.caption2).foregroundStyle(ApolloStyle.muted)
        }.padding(22).frame(maxWidth: .infinity, alignment: .leading).background(ApolloStyle.surface, in: RoundedRectangle(cornerRadius: 30))
            .accessibilityElement(children: .contain).accessibilityIdentifier("asset-card")
            .sheet(isPresented: $expanded, onDismiss: { onBrowsePresentation(false) }) { ApolloCompanyPanelDetail(asset: asset, profile: profile, panel: panel, store: store) }
            .sheet(isPresented: $chart, onDismiss: { onBrowsePresentation(false) }) { ApolloCompanyChartView(asset: asset, store: store) }
            .onChange(of: asset.id) { _, _ in navigation = .init(assetID: asset.id); expanded = false; chart = false; onBrowsePresentation(false) }
            .onDisappear { onBrowsePresentation(false) }
    }
    private func show(_ panel: ApolloCompanyPanel) { guard canBrowse(), navigation.assetID == asset.id else { return }; navigation.show(panel) }
    private func move(_ side: ApolloCompanyNavigation.Side) { guard canBrowse(), navigation.assetID == asset.id else { return }; navigation.step(side) }
    private func presentDetails() { guard canBrowse() else { return }; onBrowsePresentation(true); expanded = true }
    private func presentChart() { guard canBrowse() else { return }; onBrowsePresentation(true); chart = true }
    private func browseSurface<Content: View>(id: String, @ViewBuilder content: () -> Content) -> some View {
        content().allowsHitTesting(false).overlay {
            HStack(spacing: 0) {
                Button { move(.previous) } label: { Color.clear.contentShape(Rectangle()) }
                    .accessibilityLabel("Previous section for \(asset.ticker)").accessibilityIdentifier(id + "-left")
                Button { move(.next) } label: { Color.clear.contentShape(Rectangle()) }
                    .accessibilityLabel("Next section for \(asset.ticker)").accessibilityIdentifier(id + "-right")
            }.buttonStyle(.plain)
        }
    }
}

private struct ApolloCompanyPanelContent: View {
    let asset: ApolloAsset
    let profile: ApolloCompanyProfile?
    let panel: ApolloCompanyPanel
    let compact: Bool
    private var tracks: [ApolloEvidenceTrack] { ApolloEvidenceTracks.canonical(asset.evidenceTracks, isDemo: asset.isDemo) }
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            switch panel {
            case .overview:
                Text(profile?.businessModel.text ?? asset.summary).font(.subheadline).lineLimit(compact ? 4 : nil)
                if let profile { sourceLinks(profile.businessModel.sourceIDs); Text("Reviewed paraphrase · as of \(profile.reviewCutoff)").font(.caption); Text(profile.imageNotice).font(.caption).foregroundStyle(ApolloStyle.muted) }
                else { unknown("No company profile matching this research version is attached. The card summary remains available.") }
            case .news:
                Text("Dated reviewed sources · latest news is unverified").font(.caption.bold()).foregroundStyle(ApolloStyle.amber)
                if let profile, !profile.updates.isEmpty {
                    ForEach(Array(profile.updates.prefix(compact ? 1 : profile.updates.count))) { item in
                        VStack(alignment: .leading, spacing: 5) { Text(item.title).font(.subheadline.weight(.semibold)).lineLimit(compact ? 3 : nil); Text("\(item.date ?? "Date unknown") · \(item.dateKind ?? "date type unknown")").font(.caption); sourceLinks(item.sourceIDs) }
                    }
                } else { unknown("No reviewed dated updates are attached.") }
            case .chart:
                Image(systemName: "chart.xyaxis.line").font(.system(size: 42)).foregroundStyle(ApolloStyle.lime).frame(maxWidth: .infinity).padding(.vertical, 10)
                Text("Open the focused chart to inspect recorded history, candles and moving averages. Dates and provenance stay with the chart.").font(.subheadline)
                Text("The paper quote is a demo execution price; it is separate from historical chart data.").font(.caption).foregroundStyle(ApolloStyle.muted)
            case .business:
                if let profile, !profile.metrics.isEmpty {
                    ForEach(Array(profile.metrics.prefix(compact ? 1 : profile.metrics.count))) { metric in
                        VStack(alignment: .leading, spacing: 4) { Text(metric.name).font(.subheadline.weight(.semibold)); Text("\(metric.value) \(metric.unit)").font(.subheadline.monospacedDigit()); Text("\(metric.periodType) ended \(metric.periodEnd) · \(metric.status.replacingOccurrences(of: "_", with: " "))").font(.caption); sourceLinks(metric.sourceIDs) }
                    }
                } else { unknown("Sourced fiscal metrics are unavailable for this research version.") }
                unknown("Valuation is unavailable. No ratio is inferred from a demo price.")
            case .people:
                if let profile, !profile.people.isEmpty {
                    ForEach(Array(profile.people.prefix(compact ? 1 : profile.people.count).enumerated()), id: \.offset) { _, fact in
                        VStack(alignment: .leading, spacing: 4) { Text(fact.text).font(.subheadline).lineLimit(compact ? 4 : nil); if let date = fact.effectiveAt { Text("Effective \(date)").font(.caption) }; if let date = fact.observedAt { Text("Observed \(date)").font(.caption) }; sourceLinks(fact.sourceIDs) }
                    }
                } else { unknown("No reviewed leadership record is attached.") }
                Text("Leadership changes do not establish a cause of reported results.").font(.caption).foregroundStyle(ApolloStyle.amber)
                if !compact { ForEach(tracks.prefix(2)) { track in trackContent(track) } }
            case .otherSide:
                VStack(alignment: .leading, spacing: 6) { Text("The case for").font(.caption.bold()).foregroundStyle(ApolloStyle.lime); Text(asset.bullCase).font(.subheadline).lineLimit(compact ? 2 : nil); Text("The case against").font(.caption.bold()).foregroundStyle(ApolloStyle.amber); Text(asset.bearCase).font(.subheadline).lineLimit(compact ? 2 : nil) }
                if !compact { Text(asset.risk).font(.subheadline); ForEach(tracks.suffix(1)) { track in trackContent(track) } }
                Text("Unknown evidence stays unknown; sentiment is not probability of profit.").font(.caption).foregroundStyle(ApolloStyle.muted)
            }
        }.accessibilityElement(children: .contain).accessibilityIdentifier("company-content-\(panel.rawValue)")
    }
    private func unknown(_ text: String) -> some View { Text(text).font(.caption).foregroundStyle(ApolloStyle.amber) }
    @ViewBuilder private func sourceLinks(_ ids: [String]) -> some View {
        if compact { Text("Sources: " + ids.joined(separator: ", ")).font(.caption).foregroundStyle(ApolloStyle.muted) }
        else if let profile { ForEach(profile.sources(for: ids), id: \.id) { source in
            if let url = URL(string: source.url), url.scheme == "https" { Link(destination: url) { Text("\(source.id) · \(source.title)").font(.caption).multilineTextAlignment(.leading).frame(minHeight: 44, alignment: .leading) }.accessibilityIdentifier("company-source-\(source.id)") }
        } }
    }
    private func trackContent(_ track: ApolloEvidenceTrack) -> some View {
        VStack(alignment: .leading, spacing: 8) { Text(track.topic).font(.headline); Text(track.status).font(.caption).foregroundStyle(ApolloStyle.amber); Text(track.summary).font(.subheadline); ApolloEvidenceReasoningView(reasoning: track.reasoning) }
    }
}
private struct ApolloCompanyPanelDetail: View {
    let asset: ApolloAsset
    let profile: ApolloCompanyProfile?
    let panel: ApolloCompanyPanel
    @ObservedObject var store: ApolloGameStore
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack { ScrollView { VStack(alignment: .leading, spacing: 20) {
            Text(panel.question).font(.title2)
            ApolloCompanyPanelContent(asset: asset, profile: profile, panel: panel, compact: false)
            ApolloPanel { VStack(alignment: .leading, spacing: 8) {
                Text("How Apollo checked this").font(.headline)
                Text("Current card research: \(asset.researchCorpusHash ?? "unknown")").font(.caption).textSelection(.enabled)
                Text("Reviewed company profile: \(profile?.corpusHash ?? "missing or mismatched")").font(.caption).textSelection(.enabled)
                Text("These are recorded source summaries. No new provider call runs when you open a panel. Saved historical runs remain separate from current evidence.").font(.caption).foregroundStyle(ApolloStyle.muted)
                NavigationLink("Challenge my thesis") { ApolloThesisChallengeView(asset: asset, store: store) }.frame(minHeight: 44)
            } }
        }.padding(22) }.background(ApolloStyle.ink).foregroundStyle(ApolloStyle.cream).navigationTitle("\(asset.ticker) · \(panel.title)").navigationBarTitleDisplayMode(.inline).toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() }.accessibilityIdentifier("company-details-done") } } }.tint(ApolloStyle.lime)
    }
}
private struct ApolloCompanyChartView: View {
    let asset: ApolloAsset
    @ObservedObject var store: ApolloGameStore
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack { ScrollView { VStack(alignment: .leading, spacing: 16) {
            if let content = store.chartContent { content(asset) } else { Text("Recorded historical chart is unavailable in this build. No demo sparkline is presented as history.").foregroundStyle(ApolloStyle.amber) }
            Text("Inspecting this chart does not pass, watch, review or buy the card.").font(.caption)
        }.padding(20) }.background(ApolloStyle.ink).foregroundStyle(ApolloStyle.cream).navigationTitle("\(asset.ticker) · Chart").navigationBarTitleDisplayMode(.inline).toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() }.accessibilityIdentifier("company-chart-done") } } }.tint(ApolloStyle.lime)
    }
}

/// Existing holdings can browse the same six panels without re-entering or reordering the deck.
struct ApolloCompanyProfileView: View {
    let asset: ApolloAsset
    @ObservedObject var store: ApolloGameStore
    @Environment(\.dismiss) private var dismiss
    @State private var reading = false
    var body: some View {
        NavigationStack {
            ScrollView {
                ApolloCompanyCardView(asset: asset, store: store, openResearch: { dismiss() }, canBrowse: { !store.busy && !reading }, decisionGesturesEnabled: false, onBrowsePresentation: { reading = $0 }).padding(20)
            }.background(ApolloStyle.ink).foregroundStyle(ApolloStyle.cream)
                .navigationTitle("\(asset.ticker) · Company").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() }.accessibilityIdentifier("company-profile-done") } }
        }.tint(ApolloStyle.lime)
    }
}


/// A readable decision summary from the already-reviewed, asset/hash-bound corpus.
/// No new research, quote, model request or inferred sentiment score.
private struct ApolloStockDecisionBrief: View {
    let asset: ApolloAsset
    let profile: ApolloCompanyProfile?
    let gistContent: (String) -> AnyView
    private var reviewed: Bool { profile != nil && ["AAPL", "WINA"].contains(asset.id) }
    private var gist: String {
        guard reviewed else { return "Reviewed research is unavailable for this company. Do not treat a catalog description as an investment case." }
        return asset.id == "AAPL"
            ? "Sales and profits rose. Tariff refunds helped the headline results."
            : "Franchise royalties grew. Headline growth includes advertising-fund receipts."
    }
    private var meaning: String {
        asset.id == "AAPL"
            ? "Check whether earnings hold up without the refund benefit. Growth alone does not establish a fair share price."
            : "Separate royalty growth from advertising receipts that have matching expenses. Revenue growth is not the same as profit growth."
    }
    private var risk: String {
        asset.id == "AAPL"
            ? "Refund benefits may not recur. These results predate the new CEO and do not establish his impact or a cheap valuation."
            : "A marketing pilot is not a systemwide rollout. Debt maturities, dividends and buybacks compete for cash."
    }
    private var sourceIDs: [String] { asset.id == "AAPL" ? ["AAPL-R1", "AAPL-R2"] : ["S3", "S4", "S5"] }
    private var metrics: [ApolloCompanyMetric] {
        guard let profile else { return [] }
        let wanted = asset.id == "AAPL" ? ["Services revenue", "Operating income"] : ["Royalty revenue", "Net income"]
        return wanted.compactMap { name in profile.metrics.first { $0.name == name } }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("The gist").font(.caption.bold()).foregroundStyle(ApolloStyle.muted)
                gistContent(gist)
            }.accessibilityIdentifier("stock-gist")
            if reviewed, let profile {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Key sourced facts").font(.caption.bold()).foregroundStyle(ApolloStyle.muted)
                    ForEach(metrics) { metric in
                        HStack(alignment: .firstTextBaseline) {
                            Text(metric.name).font(.subheadline)
                            Spacer(minLength: 6)
                            Text(formatted(metric)).font(.subheadline.weight(.semibold)).monospacedDigit()
                        }
                    }
                    Text("Quarter ended " + (metrics.first?.periodEnd ?? "date unavailable") + " · reported figures")
                        .font(.caption2).foregroundStyle(ApolloStyle.muted)
                }.accessibilityIdentifier("stock-key-facts")
                section("Why it matters · interpretation", meaning, id: "stock-why-it-matters")
                section("What could go wrong", risk, id: "stock-what-could-go-wrong")
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(profile.sources(for: sourceIDs), id: \.id) { source in
                        if let url = URL(string: source.url), url.scheme == "https" {
                            Link(destination: url) {
                                Label(source.id + " · " + source.title, systemImage: "arrow.up.right")
                                    .font(.caption).multilineTextAlignment(.leading).frame(minHeight: 32, alignment: .leading)
                            }.accessibilityIdentifier("stock-brief-source-" + source.id)
                        }
                    }
                }
                Text("Reviewed " + profile.reviewCutoff + " · not live news or a buy recommendation")
                    .font(.caption2).foregroundStyle(ApolloStyle.muted)
                Divider()
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(ApolloEvidenceTracks.canonical(asset.evidenceTracks, isDemo: asset.isDemo)) { track in
                        HStack(alignment: .top, spacing: 8) {
                            Text(track.topic).font(.caption.weight(.semibold))
                            Spacer(minLength: 4)
                            Text(track.status).font(.caption2).multilineTextAlignment(.trailing).foregroundStyle(ApolloStyle.muted)
                        }
                    }
                }.accessibilityIdentifier("stock-brief-three-tracks")
            } else {
                Text("Leadership: unknown · Promises vs results: unknown · Public sentiment: unknown. Open Research for available sources; no facts or market consensus are invented.")
                    .font(.caption).foregroundStyle(ApolloStyle.amber)
            }
        }.accessibilityElement(children: .contain).accessibilityIdentifier("stock-decision-brief")
    }
    private func section(_ heading: String, _ text: String, id: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(heading).font(.caption.bold()).foregroundStyle(ApolloStyle.muted)
            Text(text).font(.subheadline).fixedSize(horizontal: false, vertical: true)
        }.accessibilityIdentifier(id)
    }
    private func formatted(_ metric: ApolloCompanyMetric) -> String {
        guard let value = Double(metric.value), value.isFinite else { return metric.value + " " + metric.unit }
        if metric.unit == "USD millions" { return "$" + (value * 1_000_000).formatted(.number.notation(.compactName).precision(.fractionLength(2))) }
        if metric.unit == "USD" { return "$" + value.formatted(.number.notation(.compactName).precision(.fractionLength(2))) }
        return metric.value + " " + metric.unit
    }
}
