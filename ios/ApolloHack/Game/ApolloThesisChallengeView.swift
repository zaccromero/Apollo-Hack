import SwiftUI

struct ApolloThesisChallengeView: View {
    let asset: ApolloAsset
    @ObservedObject var store: ApolloGameStore
    @Environment(\.dismiss) private var dismiss
    @State private var reason = ""
    @State private var risk = ""
    @State private var invalidation = ""
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    ApolloEyebrow(text: asset.ticker + " · A hypothesis to test")
                    Text("Give your thesis\na second look.").font(.system(.largeTitle, design: .serif))
                    Text("State your case, the risk and what would change your mind. This action does not place or authorize an order.").font(.subheadline).foregroundStyle(ApolloStyle.muted)
                    field("Why this investment?", hint: "My evidence and reasoning…", value: $reason, id: "challenge-reason")
                    field("What could go wrong?", hint: "The main risk…", value: $risk, id: "challenge-risk")
                    field("What would change your mind?", hint: "I would reconsider if…", value: $invalidation, id: "challenge-invalidation")
                    ApolloChallengeAction(assetID: asset.id, thesis: .init(reason: reason, risk: risk, invalidation: invalidation), service: store.service, currentCorpusHash: asset.researchCorpusHash, currentEvidenceCutoff: asset.researchEvidenceCutoff, onReturnToResearch: { dismiss() })
                }.padding(24).frame(maxWidth: 620).frame(maxWidth: .infinity)
            }.background(ApolloStyle.ink).foregroundStyle(ApolloStyle.cream).navigationTitle("Challenge a thesis").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
                .onAppear { if let draft = store.challengeDrafts[asset.id] { reason = draft.reason; risk = draft.risk; invalidation = draft.invalidation } }
                .onDisappear { store.challengeDrafts[asset.id] = .init(reason: reason, risk: risk, invalidation: invalidation) }
        }.tint(ApolloStyle.lime)
    }
    private func field(_ title: String, hint: String, value: Binding<String>, id: String) -> some View {
        VStack(alignment: .leading, spacing: 10) { Text(title).font(.subheadline.weight(.semibold)); TextField(hint, text: value, axis: .vertical).lineLimit(2...5).padding(16).background(ApolloStyle.surface, in: RoundedRectangle(cornerRadius: 16)).accessibilityIdentifier(id) }
    }
}

/// No task/onAppear requests. Only the explicit button invokes the provider-facing protocol.
struct ApolloChallengeAction: View {
    let assetID: String
    let thesis: ApolloThesis
    let service: any ApolloGameService
    var currentCorpusHash: String? = nil
    var currentEvidenceCutoff: String? = nil
    var onReturnToResearch: (() -> Void)? = nil
    @State private var loading = false
    @State private var result: ApolloThesisChallenge?
    @State private var failure: String?
    @State private var submittedThesis: String?
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ApolloPanel { VStack(alignment: .leading, spacing: 12) {
                ApolloEyebrow(text: "Before you request analysis")
                Text(ApolloChallengeContext.assignedHistorical.label).font(.subheadline)
                Text("Evidence cutoff: \(ApolloChallengeContext.assignedHistorical.cutoff ?? "Unknown"). This request uses the assigned historical corpus and does not replace newer research.").font(.caption).foregroundStyle(ApolloStyle.muted)
                Text("Assigned historical version: \(String((ApolloChallengeContext.assignedHistorical.corpusHash ?? "Unknown").prefix(12)))").font(.caption2).foregroundStyle(ApolloStyle.muted)
                if let currentCorpusHash { Text("Current card research: \(String(currentCorpusHash.prefix(12))) · cutoff \(currentEvidenceCutoff ?? "Unknown")").font(.caption2).foregroundStyle(ApolloStyle.muted); if currentCorpusHash != ApolloChallengeContext.assignedHistorical.corpusHash { Text("These evidence versions differ. This request will not replace the card’s research or silently switch versions.").font(.caption).foregroundStyle(ApolloStyle.amber) } }
                else { Text("The current card’s corpus identity was not supplied. Do not assume it matches the historical notes.").font(.caption2).foregroundStyle(ApolloStyle.muted) }
                if assetID != "WINA" { Text("The assigned corpus is Winmark. This asset will not be silently substituted; an unsupported asset or corpus mismatch must be reported.").font(.caption).foregroundStyle(ApolloStyle.amber) }
                Text("Provider calls stay paused unless you explicitly authorize them. This button does not lift that pause. A paused response is not completed analysis.").font(.caption).foregroundStyle(ApolloStyle.amber)
            } }.accessibilityIdentifier("challenge-context-notice")
            if !thesis.isChallengeReady && thesis.isComplete { Text("Use at most 800 characters per prompt and 2,400 characters for the complete serialized thesis, including quotes and escaping.").font(.caption).foregroundStyle(ApolloStyle.amber) }
            ApolloPrimaryButton(title: loading ? "Checking research availability…" : "Challenge my thesis", symbol: "text.magnifyingglass", disabled: loading || !thesis.isChallengeReady) {
                loading = true; failure = nil; result = nil; submittedThesis = thesis.canonicalWireValue
                Task { defer { loading = false }; do {
                    let response = try await service.challengeThesis(assetID: assetID, thesis: thesis)
                    guard response.assetID == assetID else { throw ApolloGameError.service("The provider response belongs to a different asset. It was not displayed.") }
                    if response.status == .success && (response.context.mode != ApolloChallengeContext.assignedHistorical.mode || response.context.corpusHash != ApolloChallengeContext.assignedHistorical.corpusHash) { throw ApolloGameError.service("The response uses a different evidence corpus. Its analysis was not displayed.") }
                    result = response
                } catch { failure = error.localizedDescription } }
            }.accessibilityIdentifier("challenge-thesis")
            if let failure { Label(failure, systemImage: "exclamationmark.triangle").font(.subheadline).foregroundStyle(ApolloStyle.amber).accessibilityIdentifier("challenge-error") }
            if let result {
                if submittedThesis != thesis.canonicalWireValue { Text("Your thesis changed after this response. Request a new challenge to assess the edited thesis.").font(.caption).foregroundStyle(ApolloStyle.amber) }
                ApolloChallengeResultView(result: result, submittedThesis: submittedThesis)
                if result.status == .corpusMismatch, let onReturnToResearch { Button("Return to current research", action: onReturnToResearch).frame(minHeight: 44).accessibilityIdentifier("challenge-return-research") }
            }
        }
    }
}

struct ApolloChallengeResultView: View {
    let result: ApolloThesisChallenge
    var submittedThesis: String? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            ApolloPanel { VStack(alignment: .leading, spacing: 12) {
                Label(statusTitle, systemImage: result.status == .success ? "text.magnifyingglass" : "pause.circle").font(.headline).foregroundStyle(ApolloStyle.lime)
                Text(result.notice).font(.subheadline)
                Text(result.context.label).font(.caption).foregroundStyle(ApolloStyle.muted)
                if let cutoff = result.context.cutoff { Text("Evidence cutoff: \(cutoff)").font(.caption).foregroundStyle(ApolloStyle.muted) }
                if result.isOfflineInjected { Text("OFFLINE TEST RESPONSE · no live provider execution is established.").font(.caption.bold()).foregroundStyle(ApolloStyle.amber) }
                if result.status == .success && !result.semanticGroundingVerified { Text("Generated interpretations have not been independently verified for semantic grounding. Check the quoted passages and original sources.").font(.caption).foregroundStyle(ApolloStyle.amber) }
            } }.accessibilityIdentifier("challenge-status-\(result.status.rawValue)")
            if result.status == .success {
                ForEach(result.canonicalTracks) { group in evidenceGroup(group) }
                ForEach(result.groups.filter { ["supporting_evidence", "opposing_evidence"].contains($0.id) }) { group in evidenceGroup(group) }
                Text("Generated analysis does not change risk tolerance, paper-order eligibility or portfolio scores, and does not supply an entry signal.").font(.caption).foregroundStyle(ApolloStyle.muted)
            }
            DisclosureGroup("See how Apollo checked this") {
                VStack(alignment: .leading, spacing: 16) {
                    if let submittedThesis { Text(ApolloThesis.display(submittedThesis)).font(.caption) }
                    Text("Source version: \(result.context.label)").font(.caption).foregroundStyle(ApolloStyle.muted)
                    if result.processSteps.isEmpty { Text("No recorded process steps were supplied. Provider work is not reported as completed.").font(.caption).foregroundStyle(ApolloStyle.muted) }
                    ForEach(result.processSteps) { step in
                        DisclosureGroup {
                            VStack(alignment: .leading, spacing: 8) {
                                if !step.detail.isEmpty { Text(step.detail) }
                                if let input = step.inputSummary { Text("Recorded input: " + input) }
                                if let output = step.outputSummary { Text("Recorded output: " + output) }
                                if !step.sourceIDs.isEmpty { Text("Source notes: " + step.sourceIDs.joined(separator: ", ")) }
                                if let timestamp = step.timestamp { Text("Recorded at: " + timestamp) }
                                if let duration = step.durationMilliseconds { Text("Recorded duration: \(duration.formatted()) ms") }
                            }.font(.caption).foregroundStyle(ApolloStyle.muted).padding(.vertical, 8)
                        } label: { VStack(alignment: .leading, spacing: 6) { Text(step.title).font(.subheadline); Text(step.status.replacingOccurrences(of: "_", with: " ")).font(.caption).foregroundStyle(ApolloStyle.muted) }.frame(minHeight: 44, alignment: .leading) }
                    }
                    Text("Prepared trace data, a send attempt and a published receipt are separate states. Offline checks do not establish a provider judge evaluation.").font(.caption2).foregroundStyle(ApolloStyle.muted)
                }.padding(.top, 12)
            }.accessibilityIdentifier("challenge-process")
            if let saved = result.savedEvidenceNotice { DisclosureGroup("Saved sponsor evidence") { Text(saved).font(.caption).padding(.top, 10); Text("Historical evidence does not certify the current game path.").font(.caption2).foregroundStyle(ApolloStyle.muted) } }
            DisclosureGroup("Source and provider provenance") {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(result.providers) { provider in
                        VStack(alignment: .leading, spacing: 6) {
                            Text("\(provider.name): \(provider.status)").font(.caption.weight(.semibold))
                            if let actual = provider.actualModel { Text("Reported model: \(actual)").font(.caption2) }
                            else if let requested = provider.requestedModel { Text("Requested model: \(requested). Actual model not reported.").font(.caption2) }
                            if let attempted = provider.networkAttempted { Text(attempted ? "Provider network attempt reported" : "No provider network attempt reported").font(.caption2) }
                            if let local = provider.localCorrelationID { Text("Local retrieval correlation: \(local)").font(.caption2).textSelection(.enabled) }
                            if let published = provider.publishedTraceID { Text("Published telemetry receipt: \(published)").font(.caption2).textSelection(.enabled) }
                        }
                    }
                    Text("Request: \(result.requestID)").font(.caption2).textSelection(.enabled)
                    if let corpus = result.context.corpusHash { Text("Historical corpus: \(corpus)").font(.caption2).textSelection(.enabled) }
                }.foregroundStyle(ApolloStyle.muted).padding(.top, 12)
            }.font(.subheadline).accessibilityIdentifier("challenge-provenance")
        }.accessibilityElement(children: .contain).accessibilityIdentifier("challenge-result")
    }
    private var statusTitle: String {
        switch result.status { case .paused: return "Provider calls are paused"; case .corpusMismatch: return "Evidence corpus does not match"; case .unavailable: return "Thesis challenge unavailable"; case .success: return "Thesis challenge from source notes" }
    }
    private func title(_ key: String) -> String { switch key { case "leadership": return "Leadership"; case "promises_results": return "Promises vs results"; case "public_sentiment": return "Public sentiment"; case "supporting_evidence": return "Evidence supporting your thesis"; case "opposing_evidence": return "Evidence challenging your thesis"; default: return key } }
    private func evidenceGroup(_ group: ApolloChallengeGroup) -> some View {
        ApolloPanel { VStack(alignment: .leading, spacing: 16) {
            Text(title(group.id)).font(.headline)
            if group.items.isEmpty { Text("Unknown · no relevant quoted evidence was supplied for this group.").font(.subheadline).foregroundStyle(ApolloStyle.muted) }
            ForEach(group.items) { item in
                VStack(alignment: .leading, spacing: 10) {
                    ApolloEyebrow(text: "Source note excerpt")
                    Text(item.quote).font(.subheadline).textSelection(.enabled)
                    ApolloEyebrow(text: "Generated interpretation")
                    Text(item.interpretation).font(.subheadline).foregroundStyle(ApolloStyle.muted)
                    if let source = result.sources.first(where: { $0.sourceID == item.sourceID && $0.assetID == result.assetID }), let url = URL(string: source.url), url.scheme == "https" {
                        Link(destination: url) { Label(source.title, systemImage: "arrow.up.right").font(.caption).frame(minHeight: 44) }
                        Text("\(source.dateKind == "published_at" ? "Published" : source.dateKind == "reviewed_at" ? "Reviewed" : "Source date (kind unverified)") \(source.date)").font(.caption2).foregroundStyle(ApolloStyle.muted)
                    } else { Text("Source link unavailable for this passage.").font(.caption).foregroundStyle(ApolloStyle.amber) }
                }
            }
        } }.accessibilityIdentifier("challenge-track-\(group.id)")
    }
}
