import SwiftUI

struct ApolloAssetDetailView: View {
    let asset: ApolloAsset
    @ObservedObject var store: ApolloGameStore
    @Environment(\.dismiss) private var dismiss
    @State private var order = false
    @State private var section = 0
    @State private var challenge = false
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    HStack { ApolloEyebrow(text: asset.kind.label); Spacer(); Text(asset.isDemo ? "DEMO FIXTURE" : "SOURCED · CHECK AS OF").font(.caption2.bold()).foregroundStyle(ApolloStyle.lime) }
                    Text(asset.name).font(.system(.largeTitle, design: .serif)).accessibilityIdentifier("asset-detail-title")
                    Text(asset.summary).foregroundStyle(ApolloStyle.muted)
                    ApolloPanel {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack { Text(asset.kind == .strategy ? "Sample allocation" : asset.price.apolloMoney).font(.largeTitle.weight(.medium)).monospacedDigit(); Spacer(); Image(systemName: asset.kind.symbol).font(.title).foregroundStyle(ApolloStyle.lime) }
                            Text(asset.priceLabel).font(.caption).foregroundStyle(ApolloStyle.muted)
                            if let chartContent = store.chartContent {
                                chartContent(asset)
                            } else {
                                ApolloSparkline(values: asset.chart).frame(height: 120)
                                Text(asset.isDemo ? "Illustrative normalized scenario · not price history or a return forecast" : asset.changeLabel).font(.caption).foregroundStyle(ApolloStyle.muted)
                            }
                            Divider()
                            Label(asset.isDemo ? "Paper execution quote · demo" : (asset.quoteStale ? "Not a live quote" : "Source timestamp available"), systemImage: "clock").font(.caption.weight(.semibold)).foregroundStyle(ApolloStyle.amber)
                            Text(asset.quoteProvenance).font(.caption).foregroundStyle(ApolloStyle.muted)
                            if let asOf = asset.quoteAsOf { Text("As of \(asOf)").font(.caption).foregroundStyle(ApolloStyle.muted) }
                        }
                    }
                    Picker("Research section", selection: $section) { Text("The thesis").tag(0); Text("Evidence").tag(1); Text("Learn").tag(2) }.pickerStyle(.segmented)
                    if section == 0 { thesisContent }
                    else if section == 1 { evidenceContent }
                    else { lessonContent }
                    sourceContent
                    Button { challenge = true } label: { Label("Challenge my thesis", systemImage: "text.magnifyingglass").font(.headline).frame(maxWidth: .infinity, minHeight: 48) }.accessibilityIdentifier("detail-challenge-thesis")
                    ApolloPrimaryButton(title: asset.kind == .strategy ? "Review paper copy" : "Review paper investment", disabled: store.busy) { Task { if await store.decide(asset, .interest) { order = true } } }.accessibilityIdentifier("detail-invest")
                    Button { Task { if await store.decide(asset, .watchlist) { dismiss() } } } label: { Label("Save to watchlist", systemImage: "bookmark").font(.headline).frame(maxWidth: .infinity).frame(minHeight: 48) }.disabled(store.busy).accessibilityIdentifier("detail-watch")
                    Text("Educational scenarios and research are not personal investment advice. All orders in Apollo use simulated money.").font(.caption).foregroundStyle(ApolloStyle.muted)
                }.padding(24).frame(maxWidth: 620).frame(maxWidth: .infinity)
            }.background(ApolloStyle.ink).foregroundStyle(ApolloStyle.cream)
                .navigationTitle(asset.ticker).navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() }.accessibilityIdentifier("detail-done") } }
                .sheet(isPresented: $challenge) { ApolloThesisChallengeView(asset: asset, store: store) }
                .sheet(isPresented: $order) { ApolloOrderView(asset: asset, store: store) }
        }.tint(ApolloStyle.lime)
    }
    private var thesisContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            ApolloPanel { VStack(alignment: .leading, spacing: 10) { Label("The case for", systemImage: "arrow.up.right").font(.headline).foregroundStyle(ApolloStyle.lime); Text(asset.bullCase).font(.subheadline) } }
            ApolloPanel { VStack(alignment: .leading, spacing: 10) { Label("What could go wrong", systemImage: "arrow.down.right").font(.headline).foregroundStyle(ApolloStyle.amber); Text(asset.bearCase).font(.subheadline) } }
            VStack(alignment: .leading, spacing: 10) { ApolloEyebrow(text: "Before you decide"); Text(asset.catalyst).font(.subheadline); Label(asset.risk, systemImage: "exclamationmark.shield").font(.caption.bold()).foregroundStyle(ApolloStyle.amber) }
            if asset.kind == .option { ApolloPanel { VStack(alignment: .leading, spacing: 10) { ApolloEyebrow(text: "Long premium only"); Text("Expiry: \(asset.expiry ?? "Unknown") · Multiplier: \(asset.multiplier)").font(.headline); Text("Each contract costs premium × multiplier. This paper lesson does not model exercise, assignment, margin or short options.").font(.subheadline).foregroundStyle(ApolloStyle.muted) } } }
            if asset.bond != nil || asset.stablecoin != nil { ApolloInstrumentTermsView(asset: asset) }
            if !asset.allocations.isEmpty { ApolloPanel { VStack(alignment: .leading, spacing: 12) { ApolloEyebrow(text: "Copy the allocation · not the person"); ForEach(asset.allocations, id: \.assetID) { allocation in HStack { Text(allocation.assetID); Spacer(); Text("\(Int(allocation.weight.apolloDouble * 100))%").monospacedDigit() } }; Text("Fictional learning profile. No verified creator performance or endorsement.").font(.caption).foregroundStyle(ApolloStyle.muted) } } }
        }
    }
    private var evidenceContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Separate the signals.").font(.title2.weight(.medium))
            Text("A price move alone cannot tell you whether a thesis is sound. Review each evidence track and its source.").font(.subheadline).foregroundStyle(ApolloStyle.muted)
            ForEach(tracks) { track in
                ApolloPanel { VStack(alignment: .leading, spacing: 12) { HStack(alignment: .top) { Text(track.topic).font(.headline); Spacer(); Text(track.status.uppercased()).font(.caption2.bold()).foregroundStyle(ApolloStyle.amber) }; Text(track.summary).font(.subheadline).foregroundStyle(ApolloStyle.muted); ApolloEvidenceReasoningView(reasoning: track.reasoning); ForEach(track.sources) { source in sourceLink(source) } } }
            }
        }.accessibilityIdentifier("evidence-tracks")
    }
    private var tracks: [ApolloEvidenceTrack] { ApolloEvidenceTracks.canonical(asset.evidenceTracks, isDemo: asset.isDemo) }
    private var lessonContent: some View { ApolloPanel { VStack(alignment: .leading, spacing: 14) { Label("One idea to take with you", systemImage: "lightbulb").font(.headline).foregroundStyle(ApolloStyle.lime); Text(asset.lesson).font(.title3); Text("Try saying your reason out loud. Then name the evidence that would change your mind.").font(.subheadline).foregroundStyle(ApolloStyle.muted) } } }
    private var sourceContent: some View { VStack(alignment: .leading, spacing: 10) { ApolloEyebrow(text: "Go to the source"); ForEach(asset.sources) { source in sourceLink(source) }; if asset.sources.isEmpty { Text("No linked source is available for this asset.").font(.caption).foregroundStyle(ApolloStyle.amber) } } }
    @ViewBuilder private func sourceLink(_ source: ApolloSource) -> some View { if let url = URL(string: source.url), ["https", "http"].contains(url.scheme?.lowercased() ?? "") { Link(destination: url) { HStack { Text(source.title).multilineTextAlignment(.leading); Spacer(); Image(systemName: "arrow.up.right") }.font(.subheadline).frame(minHeight: 44) }.foregroundStyle(ApolloStyle.lime) } }
}
