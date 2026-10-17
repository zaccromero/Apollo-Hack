import SwiftUI

struct ApolloOrderView: View {
    let asset: ApolloAsset
    let swipeBudget: Decimal?
    let editSwipePitch: Bool
    @State private var swipeReviewPrepared = false
    @ObservedObject var store: ApolloGameStore
    @Environment(\.dismiss) private var dismiss
    @State private var amount = ""
    @State private var reason = ""
    @State private var risk = ""
    @State private var invalidation = ""
    @State private var preview: ApolloOrderPreview?
    @State private var preparing = false
    @State private var acknowledged = false
    @State private var localError: String?
    @State private var filled = false
    @State private var editingProfile = false
    @State private var showingComparison = false
    @State private var exceptionAcknowledged = false
    @State private var beforeCash: Decimal?
    @State private var beforeHoldingCount: Int?
    @FocusState private var focused: Field?
    private enum Field { case amount, reason, risk, invalidation }
    private var thesis: ApolloThesis { .init(reason: reason, risk: risk, invalidation: invalidation) }
    private var enteredAmount: Decimal? { Decimal(string: amount.replacingOccurrences(of: ",", with: "."), locale: Locale(identifier: "en_US_POSIX")) }
    private var quantity: Decimal? { guard let enteredAmount else { return nil }; return swipeBudget == nil ? enteredAmount : ApolloCardInteraction.quantity(budget: enteredAmount, asset: asset) }
    init(asset: ApolloAsset, store: ApolloGameStore, swipeBudget: Decimal? = nil, editSwipePitch: Bool = false) {
        self.asset = asset; self.store = store; self.swipeBudget = swipeBudget; self.editSwipePitch = editSwipePitch
        if let swipeBudget {
            _amount = State(initialValue: swipeBudget.apolloQuantity)
            _reason = State(initialValue: "Practice a paper allocation to " + asset.ticker + ".")
            _risk = State(initialValue: asset.risk)
            _invalidation = State(initialValue: "Revisit the pitch if: " + asset.bearCase)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if filled { successContent }
                    else {
                        ApolloEyebrow(text: "Simulated money · deliberate decisions")
                        Text(preview == nil ? "Make your case." : "One last look.").font(.system(.largeTitle, design: .serif))
                        HStack { VStack(alignment: .leading, spacing: 5) { Text(asset.ticker).font(.title2.bold()); Text(asset.name).font(.subheadline).foregroundStyle(ApolloStyle.muted) }; Spacer(); Image(systemName: asset.kind.symbol).font(.title).foregroundStyle(ApolloStyle.lime) }
                        if let preview { confirmationContent(preview) }
                        else if store.account.riskProfile == nil || editingProfile { ApolloRiskProfileView(store: store) { editingProfile = false } }
                        else { formContent }
                        if let localError { Label(localError, systemImage: "exclamationmark.triangle").font(.subheadline).foregroundStyle(ApolloStyle.amber).accessibilityIdentifier("order-error") }
                    }
                }.padding(24).frame(maxWidth: 620).frame(maxWidth: .infinity)
            }.background(ApolloStyle.ink).foregroundStyle(ApolloStyle.cream)
                .navigationTitle(filled ? "Paper order complete" : "Paper order").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .topBarTrailing) { Button(filled ? "Done" : "Cancel") { dismiss() }.disabled(preparing || store.busy).accessibilityIdentifier("order-close") }; ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Done") { focused = nil } } }
        }.sheet(isPresented: $showingComparison) { ApolloPaperComparisonView(store: store, initialAssetID: asset.kind == .strategy ? "AAPL" : asset.id, initialQuantity: asset.kind == .strategy ? 1 : (quantity ?? 1), initialStrategyBudget: asset.kind == .strategy ? quantity : nil) }
        .tint(ApolloStyle.lime).interactiveDismissDisabled(preparing || store.busy)
        .task { if editSwipePitch { focused = .amount }; prepareSwipeReviewIfReady() }
        .onChange(of: store.account.riskProfile?.tolerance) { _, _ in prepareSwipeReviewIfReady() }
    }
    private var formContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            if let profile = store.account.riskProfile { HStack { Label("\(profile.tolerance.label) · ceiling \(profile.ceiling)/5", systemImage: "shield").font(.caption); Spacer(); Button("Change") { editingProfile = true }.font(.caption).frame(minHeight: 44) } }
            ApolloPanel { VStack(alignment: .leading, spacing: 12) {
                Text("Available paper cash").font(.caption).foregroundStyle(ApolloStyle.muted)
                Text(store.account.cash.apolloMoney).font(.title2.weight(.semibold)).monospacedDigit()
                Divider()
                Text(swipeBudget != nil ? "Paper investment budget (USD)" : asset.kind == .strategy ? "Paper copy budget (USD)" : asset.kind == .option ? "Whole contracts" : asset.kind == .bond ? "Whole bonds" : "Number of \(asset.unit)").font(.subheadline.weight(.semibold))
                TextField(swipeBudget != nil ? "10" : asset.kind == .strategy ? "500" : asset.kind == .crypto ? "0.001" : "1", text: $amount).keyboardType(.decimalPad).font(.title).focused($focused, equals: .amount).accessibilityIdentifier("order-quantity")
                if asset.kind == .option { Text("\(asset.price.apolloMoney) × \(asset.multiplier) = \((asset.price * Decimal(asset.multiplier)).apolloMoney) per contract. Entire premium may be lost.").font(.caption).foregroundStyle(ApolloStyle.amber) }
                else if asset.kind == .strategy { Text("Copies the listed holdings using fractional simulated units. Rounding may leave a small cash remainder.").font(.caption).foregroundStyle(ApolloStyle.muted) }
                else { Text("\(asset.price.apolloMoney) per demo \(asset.unit) · step \((asset.quantityStep ?? Decimal(string: "0.00000001")!).apolloQuantity)").font(.caption).foregroundStyle(ApolloStyle.muted) }
            } }
            if swipeBudget != nil {
                Text("Starting DEMO pitch — review or edit these notes before confirming. Nothing fills until you confirm.").font(.caption).foregroundStyle(ApolloStyle.muted).accessibilityIdentifier("swipe-pitch-notice")
                if let budget = enteredAmount, budget > 0, quantity == nil {
                    Label("This budget cannot buy the minimum allowed unit. Edit the amount; Apollo will not increase it automatically.", systemImage: "exclamationmark.triangle").font(.caption).foregroundStyle(ApolloStyle.amber).accessibilityIdentifier("swipe-minimum-notice")
                } else if let quantity, asset.kind != .strategy {
                    Text("Up to \(amount) USD → \(quantity.apolloQuantity) \(asset.unit). The review shows the actual rounded paper cost.").font(.caption).foregroundStyle(ApolloStyle.muted).accessibilityIdentifier("swipe-budget-quantity")
                }
            }
            if asset.bond != nil || asset.stablecoin != nil { ApolloInstrumentTermsView(asset: asset) }
            thesisField("01 · Why this investment?", hint: "The evidence behind my interest…", text: $reason, field: .reason, id: "thesis-reason")
            thesisField("02 · What is the main risk?", hint: "I could lose money if…", text: $risk, field: .risk, id: "thesis-risk")
            thesisField("03 · What would change your mind?", hint: "I’ll revisit my thesis when…", text: $invalidation, field: .invalidation, id: "thesis-invalidation")
            Text("There is no score for being bullish. A clear reason and an honest risk make a better practice decision.").font(.caption).foregroundStyle(ApolloStyle.muted)
            ApolloChallengeAction(assetID: asset.id, thesis: thesis, service: store.service, currentCorpusHash: asset.researchCorpusHash, currentEvidenceCutoff: asset.researchEvidenceCutoff)
            ApolloPrimaryButton(title: preparing ? "Preparing preview…" : "Review paper order", disabled: preparing || !thesis.isComplete || quantity == nil || quantity! <= 0) { prepare() }.accessibilityIdentifier("order-preview")
        }
    }
    private func confirmationContent(_ preview: ApolloOrderPreview) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            if swipeBudget != nil {
                Label("Paper budget: \(enteredAmount?.apolloMoney ?? "Unknown") · edit amount or pitch below", systemImage: "square.and.pencil").font(.caption).foregroundStyle(ApolloStyle.muted).accessibilityIdentifier("swipe-review-notice")
                Text("Starting DEMO pitch: " + ApolloThesis.display(preview.thesis)).font(.caption).foregroundStyle(ApolloStyle.muted)
            }
            ApolloPanel { VStack(alignment: .leading, spacing: 12) {
                ForEach(preview.lines) { line in HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 5) { Text(store.asset(line.assetID)?.ticker ?? line.assetID).font(.headline); Text("\(line.quantity.apolloQuantity) × \(line.price.apolloMoney)\(line.multiplier == 1 ? "" : " × \(line.multiplier)")").font(.caption).foregroundStyle(ApolloStyle.muted) }
                    Spacer(); Text(line.cost.apolloMoney).font(.subheadline).monospacedDigit()
                } }
                HStack { Text("Paper cost"); Spacer(); Text(preview.total.apolloMoney).font(.title2.bold()).monospacedDigit() }.accessibilityIdentifier("order-total")
                Text(preview.quoteProvenance).font(.caption).foregroundStyle(ApolloStyle.amber)
                if asset.kind == .option { Label("The entire option premium can be lost.", systemImage: "exclamationmark.triangle").font(.caption.weight(.semibold)).foregroundStyle(ApolloStyle.amber) }
            } }
            if let before = preview.portfolioBefore, let after = preview.portfolioAfter {
                ApolloPanel { VStack(alignment: .leading, spacing: 12) {
                    ApolloEyebrow(text: "Estimated portfolio impact")
                    impactRow("Paper cash", before: (before.equity * before.cashWeight).apolloMoney, after: (after.equity * after.cashWeight).apolloMoney)
                    impactRow("Invested risk", before: score(before.weightedRisk), after: score(after.weightedRisk))
                    impactRow("Covered bullish / bearish", before: ApolloComparisonPresentation.sentiment(before), after: ApolloComparisonPresentation.sentiment(after))
                    Text(ApolloComparisonPresentation.riskChange(before: before, after: after)).font(.caption).foregroundStyle(ApolloStyle.muted)
                    Text(ApolloComparisonPresentation.sentimentChange(before: before, after: after)).font(.caption).foregroundStyle(ApolloStyle.muted)
                    impactRow("Evidence sentiment", before: before.sentimentStatus.capitalized, after: after.sentimentStatus.capitalized)
                    Text("Sentiment coverage: \(percentage(after.sentimentCoverage)). Unknown remains unknown.").font(.caption).foregroundStyle(ApolloStyle.muted)
                    Text("Estimate only · recomputed at confirmation.").font(.caption.weight(.semibold)).foregroundStyle(ApolloStyle.amber)
                } }.accessibilityIdentifier("order-portfolio-projection")
            } else { Text("Portfolio projection unavailable. Confirmed holdings update only after a paper fill.").font(.caption).foregroundStyle(ApolloStyle.muted) }
            Button { showingComparison = true } label: { Label("Compare all three profiles", systemImage: "square.split.2x2").frame(minHeight: 44) }.accessibilityIdentifier("order-compare-profiles")
            if let check = preview.riskCheck {
                Label(check.requiresMixedException ? "Above your chosen tolerance" : "Within your chosen DEMO ceiling", systemImage: "exclamationmark.shield").font(.subheadline.weight(.semibold)).foregroundStyle(check.requiresMixedException ? ApolloStyle.amber : ApolloStyle.lime)
                if check.requiresMixedException { Text(check.notice).font(.subheadline).foregroundStyle(ApolloStyle.amber); Toggle(isOn: $exceptionAcknowledged) { Text("I explicitly accept this above-tolerance PAPER-only exception. Mixed bullish/bearish sentiment does not reduce risk.").font(.subheadline).foregroundStyle(ApolloStyle.amber) }.accessibilityIdentifier("mixed-exception-acknowledge") }
            } else { Text("Risk assessment unavailable. Save this idea to your watchlist while it is reviewed.").font(.subheadline).foregroundStyle(ApolloStyle.amber) }
            Toggle(isOn: $acknowledged) { Text("I reviewed the risk and understand this uses simulated money.").font(.subheadline) }.tint(ApolloStyle.lime).accessibilityIdentifier("order-acknowledge")
            ApolloPrimaryButton(title: store.busy ? "Confirming…" : "Confirm paper order", symbol: "checkmark", disabled: !acknowledged || store.busy || preview.riskCheck == nil || (preview.riskCheck?.requiresMixedException == true && !exceptionAcknowledged)) {
                Task { var confirmedPreview = preview; confirmedPreview.mixedExceptionAcknowledged = exceptionAcknowledged; beforeCash = store.account.cash; beforeHoldingCount = store.account.positions.count; if await store.confirm(confirmedPreview) { filled = true } else { localError = store.error } }
            }.accessibilityIdentifier("order-confirm")
            DisclosureGroup("Thesis, order terms and full notices") {
                VStack(alignment: .leading, spacing: 14) {
                    Text(ApolloThesis.display(preview.thesis)).font(.subheadline)
                    ForEach(preview.lines) { line in Text("\(line.assetID) · \(line.quantity.apolloQuantity) × \(line.price.apolloMoney) × \(line.multiplier)").font(.caption).textSelection(.enabled) }
                    if asset.kind == .option { Text(asset.summary).font(.caption) }
                    if let check = preview.riskCheck { Text(check.notice).font(.caption); if !check.outsideAssetIDs.isEmpty { Text("Above ceiling: " + check.outsideAssetIDs.joined(separator: ", ")).font(.caption) } }
                    ForEach(preview.warnings, id: \.self) { Text($0).font(.caption) }
                    Text(preview.projectionNotice).font(.caption)
                    if let before = preview.portfolioBefore, let after = preview.portfolioAfter { Text("Estimated paper equity \(before.equity.apolloMoney) → \(after.equity.apolloMoney); cash allocation \(percentage(before.cashWeight)) → \(percentage(after.cashWeight)).").font(.caption) }
                }.foregroundStyle(ApolloStyle.muted).padding(.top, 12)
            }.font(.subheadline).accessibilityIdentifier("order-full-notices")
            Button("Edit amount or thesis") { self.preview = nil; acknowledged = false; exceptionAcknowledged = false }.frame(minHeight: 44).disabled(store.busy).accessibilityIdentifier("order-edit")
        }
    }
    private func impactRow(_ title: String, before: String, after: String) -> some View {
        VStack(alignment: .leading, spacing: 5) { Text(title).font(.caption).foregroundStyle(ApolloStyle.muted); Text("\(before) → \(after)").font(.subheadline.weight(.semibold)).monospacedDigit().fixedSize(horizontal: false, vertical: true) }
    }
    private var successContent: some View {
        VStack(alignment: .leading, spacing: 24) {
            Image(systemName: "checkmark.circle.fill").font(.system(size: 58)).foregroundStyle(ApolloStyle.lime)
            Text("A decision.\nAnd a lesson.").font(.system(.largeTitle, design: .serif))
            Text("Your simulated holdings and paper cash are updated. No real money moved.").foregroundStyle(ApolloStyle.muted).accessibilityIdentifier("paper-order-success")
            ApolloPanel { VStack(alignment: .leading, spacing: 12) { ApolloEyebrow(text: "Keep this in mind"); Text(asset.lesson); Text("Your thesis is saved with this paper transaction. Revisit it when your invalidation condition occurs.").font(.caption).foregroundStyle(ApolloStyle.muted) } }
            if let beforeCash, let beforeHoldingCount {
                ApolloPanel { VStack(alignment: .leading, spacing: 12) {
                    ApolloEyebrow(text: "Your portfolio, updated")
                    Text("Paper cash: \(beforeCash.apolloMoney) → \(store.account.cash.apolloMoney)").font(.subheadline).monospacedDigit()
                    Text("Distinct holdings: \(beforeHoldingCount) → \(store.account.positions.count)").font(.subheadline)
                    Text("Allocation, risk and available sentiment have been recomputed. Open Portfolio to inspect their coverage and provenance.").font(.caption).foregroundStyle(ApolloStyle.muted)
                } }.accessibilityIdentifier("portfolio-before-after")
            }
            ApolloPrimaryButton(title: "View portfolio", symbol: "chart.pie") { store.portfolioRequest = UUID() }.accessibilityIdentifier("order-view-portfolio")
            Button("Keep exploring") { dismiss() }.frame(maxWidth: .infinity, minHeight: 44)
        }.padding(.vertical, 32)
    }
    private func thesisField(_ title: String, hint: String, text: Binding<String>, field: Field, id: String) -> some View {
        VStack(alignment: .leading, spacing: 10) { Text(title).font(.subheadline.weight(.semibold)); TextField(hint, text: text, axis: .vertical).lineLimit(2...4).padding(16).background(ApolloStyle.surface, in: RoundedRectangle(cornerRadius: 16)).focused($focused, equals: field).accessibilityIdentifier(id) }
    }
    private func percentage(_ value: Decimal) -> String { value.apolloDouble.formatted(.percent.precision(.fractionLength(0))) }
    private func score(_ value: Decimal?) -> String { value.map { $0.apolloDouble.formatted(.number.precision(.fractionLength(1))) + "/5" } ?? "Unknown" }
    private func prepareSwipeReviewIfReady() {
        guard swipeBudget != nil, !editSwipePitch, !swipeReviewPrepared, store.account.riskProfile != nil else { return }
        swipeReviewPrepared = true
        guard quantity != nil else { return }
        prepare()
    }
    private func prepare() {
        guard let quantity, thesis.isComplete else { return }
        focused = nil; preparing = true; localError = nil
        Task { defer { preparing = false }; do { preview = try await asset.kind == .strategy ? store.service.previewCopy(strategyID: asset.id, budget: quantity, thesis: thesis.wireValue) : store.service.preview(assetID: asset.id, quantity: quantity, thesis: thesis.wireValue) } catch { localError = error.localizedDescription } }
    }
}
