import SwiftUI

struct ApolloSocialResearchView: View {
    @ObservedObject var store: ApolloGameStore
    @State private var input = ""
    @State private var receipt: ApolloSocialResearchReceipt?
    @State private var submittedURL: String?
    @State private var busy = false
    @State private var failure: String?
    @State private var admissionNotice: String?
    @State private var admitted: Set<String> = []
    private var canonical: String? { ApolloSocialResearchInput.canonicalURL(input) }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text("A post is a starting point.").font(.system(.largeTitle, design: .serif))
                Text("Check what was accessible, resolve exact investment identities and review independent sources before adding a candidate to Apollo’s library. Educational topics alone do not establish a stock pick.").foregroundStyle(ApolloStyle.muted)
                TextField("https://www.instagram.com/p/…/", text: $input).textInputAutocapitalization(.never).autocorrectionDisabled().keyboardType(.URL).padding(16).background(ApolloStyle.surface, in: RoundedRectangle(cornerRadius: 16)).accessibilityIdentifier("social-url")
                ApolloPrimaryButton(title: busy ? "Checking available research…" : "Review post research", symbol: "text.magnifyingglass", disabled: busy || canonical == nil) { Task { await research() } }.accessibilityIdentifier("social-research")
                Text("Paid calls remain paused. Access to a caption does not mean a video, audio or transcript was analyzed. No holding or order is created here.").font(.caption).foregroundStyle(ApolloStyle.amber)
                if let failure { Text(failure).foregroundStyle(ApolloStyle.amber).accessibilityIdentifier("social-error") }
                if let receipt {
                    if canonical != submittedURL { Text("The link changed. Review it again before requesting any admission.").font(.caption).foregroundStyle(ApolloStyle.amber) }
                    ApolloPanel { VStack(alignment: .leading, spacing: 12) {
                        Text(title(receipt.status)).font(.title2)
                        Text(receipt.notice).font(.subheadline)
                        Text("Access: \(receipt.accessScope.replacingOccurrences(of: "_", with: " "))").font(.caption).foregroundStyle(ApolloStyle.muted)
                        if let retrieved = receipt.retrievedAt { Text("\(receipt.freshFetch == false ? "Inspection recorded at" : "Retrieved"): \(retrieved)").font(.caption).foregroundStyle(ApolloStyle.muted) }
                        if let published = receipt.publishedAt { Text("\(receipt.publishedDateKind ?? "Published"): \(published)").font(.caption).foregroundStyle(ApolloStyle.muted) }
                        if let mode = receipt.mode { Text("Mode: " + mode.replacingOccurrences(of: "_", with: " ")).font(.caption).foregroundStyle(ApolloStyle.muted) }
                        if receipt.freshFetch == false { Text(receipt.mode == "saved_public_inspection" ? "Saved inspection · no fresh post retrieval in this request" : "No post was fetched for this request").font(.caption.weight(.semibold)).foregroundStyle(ApolloStyle.amber) }
                        safeLink("Original post", receipt.originURL)
                        ForEach(Array(receipt.limitations.enumerated()), id: \.offset) { _, limit in Text(limit).font(.caption).foregroundStyle(ApolloStyle.amber) }
                    } }.accessibilityIdentifier("social-receipt")
                    if !receipt.evidenceSegments.isEmpty { ApolloPanel { VStack(alignment: .leading, spacing: 12) {
                        ApolloEyebrow(text: "Accessible source content")
                        ForEach(receipt.evidenceSegments) { segment in VStack(alignment: .leading, spacing: 6) { Text(segment.text).font(.subheadline); Text("\(segment.id) · \(segment.locator)\(segment.mediaTimestamp.map { " · " + $0 } ?? "")").font(.caption2).foregroundStyle(ApolloStyle.muted) } }
                    } } }
                    ForEach(receipt.claims) { claim in ApolloPanel { VStack(alignment: .leading, spacing: 8) { Text(claim.text); Text("Verification: \(claim.verification)").font(.caption).foregroundStyle(ApolloStyle.amber); if let finding = claim.finding { Text(finding).font(.subheadline) }; ForEach(claim.sources ?? []) { safeLink($0.title, $0.url) }; if !claim.evidenceSegmentIDs.isEmpty { Text("Source segments: " + claim.evidenceSegmentIDs.joined(separator: ", ")).font(.caption2).foregroundStyle(ApolloStyle.muted) } } } }
                    ForEach(receipt.candidates) { candidate in
                        ApolloPanel { VStack(alignment: .leading, spacing: 12) {
                            Text(candidate.literalMention).font(.headline)
                            Text(candidate.resolvedAssetID.map { "Resolved identity: " + $0 } ?? "Investment identity unresolved").font(.caption).foregroundStyle(ApolloStyle.amber)
                            Text(candidate.reasoning).font(.subheadline)
                            Text("Review status: \(candidate.status.rawValue.replacingOccurrences(of: "_", with: " "))").font(.caption)
                            ForEach(candidate.independentSources) { safeLink($0.title, $0.url) }
                            ForEach(Array(candidate.limitations.enumerated()), id: \.offset) { _, text in Text(text).font(.caption).foregroundStyle(ApolloStyle.muted) }
                            if candidate.canRequestAdmission(catalog: store.assets) {
                                ApolloPrimaryButton(title: admitted.contains(candidate.id) ? "Admitted to the library" : "Admit reviewed candidate", symbol: "books.vertical", disabled: busy || admitted.contains(candidate.id) || canonical != submittedURL) { Task { await admit(candidate) } }.accessibilityIdentifier("social-admit-\(candidate.id)")
                            } else { Text("This candidate cannot be admitted until its exact catalog identity and independent evidence pass review.").font(.caption).foregroundStyle(ApolloStyle.amber) }
                        } }
                    }
                }
                if let admissionNotice { Text(admissionNotice).font(.subheadline).accessibilityIdentifier("social-admission-result") }
            }.padding(20).frame(maxWidth: 620).frame(maxWidth: .infinity)
        }.background(ApolloStyle.ink).foregroundStyle(ApolloStyle.cream).navigationTitle("Post research").navigationBarTitleDisplayMode(.inline)
    }
    private func title(_ status: ApolloSocialResearchStatus) -> String {
        switch status { case .unavailable: return "Research unavailable"; case .needsReview: return "More evidence needed"; case .noInvestment: return "No identifiable investment found"; case .candidates: return "Review the candidates" }
    }
    @ViewBuilder private func safeLink(_ title: String, _ input: String) -> some View {
        if let url = URL(string: input), ["https", "http"].contains(url.scheme?.lowercased() ?? "") { Link(title, destination: url).frame(minHeight: 44) }
    }
    private func research() async {
        guard !busy, let canonical else { return }; busy = true; failure = nil; admissionNotice = nil; receipt = nil; submittedURL = canonical; admitted = []
        defer { busy = false }
        do {
            let value = try await store.service.researchSocial(url: canonical)
            guard ApolloSocialResearchInput.canonicalURL(value.originURL) == canonical, value.providerCalls == 0 else { throw ApolloGameError.service("The service returned a mismatched source or violated the paid-call pause. Its result was not displayed.") }
            let segmentIDs = Set(value.evidenceSegments.map(\.id))
            guard value.claims.allSatisfy({ Set($0.evidenceSegmentIDs).isSubset(of: segmentIDs) }), value.status != .noInvestment || value.candidates.isEmpty else { throw ApolloGameError.service("Research source references or candidate status were inconsistent. No candidate was admitted.") }
            receipt = value
        }
        catch { failure = error.localizedDescription }
    }
    private func admit(_ candidate: ApolloSocialCandidate) async {
        guard !busy, candidate.canRequestAdmission(catalog: store.assets), canonical == submittedURL else { return }
        busy = true; failure = nil; defer { busy = false }
        do {
            let result = try await store.service.admitSocialCandidate(candidateID: candidate.id)
            guard !result.mutatesAccount, !result.createsOrder, result.candidateID == candidate.id, result.assetID == candidate.resolvedAssetID else { throw ApolloGameError.service("The service did not return a safe library-only admission. No success was displayed.") }
            admissionNotice = result.notice
            if result.admitted { admitted.insert(candidate.id); store.assets = try await store.service.catalog() }
        } catch { failure = error.localizedDescription }
    }
}
