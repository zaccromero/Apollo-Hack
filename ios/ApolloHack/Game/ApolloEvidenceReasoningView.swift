import SwiftUI

struct ApolloEvidenceReasoningView: View {
    let reasoning: ApolloEvidenceReasoning?
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let reasoning {
                statements(reasoning.factLabel, items: reasoning.facts, empty: "No reviewed source fact in this track.")
                statements("Interpretations", items: reasoning.interpretations, empty: "No sourced interpretation available.")
                statements("Counterevidence", items: reasoning.counterevidence, empty: reasoning.counterevidenceStatus)
                VStack(alignment: .leading, spacing: 7) { Text("Unknowns & limits").font(.caption.bold()); ForEach(Array(reasoning.unknowns.enumerated()), id: \.offset) { _, text in Text(text).font(.caption).foregroundStyle(ApolloStyle.muted) }; Text(reasoning.method).font(.caption2).foregroundStyle(ApolloStyle.muted) }
            } else {
                Text("Facts, interpretations & counterevidence: detailed source reasoning is unavailable from this adapter. The summary above is not a verbatim source quote. Unknown coverage does not confirm a thesis.").font(.caption).foregroundStyle(ApolloStyle.muted)
            }
        }
    }
    private func statements(_ title: String, items: [ApolloEvidenceStatement], empty: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.caption.bold())
            if items.isEmpty { Text(empty).font(.caption).foregroundStyle(ApolloStyle.muted) }
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                VStack(alignment: .leading, spacing: 5) {
                    Text(item.text).font(.subheadline)
                    Text(item.kind == "observed_opinion_or_sample" ? "Observed opinion/sample · not verified company results" : item.kind == "interpretation_not_source_quote" ? "Interpretation · not a source quotation" : "Reviewed paraphrase · not a verbatim quotation").font(.caption2).foregroundStyle(ApolloStyle.amber)
                    if !item.sourceIDs.isEmpty { Text("Source IDs: " + item.sourceIDs.joined(separator: ", ")).font(.caption2).foregroundStyle(ApolloStyle.muted) }
                    if let source = item.source {
                        if let url = URL(string: source.url), ["https", "http"].contains(url.scheme?.lowercased() ?? "") { Link(source.title, destination: url).font(.caption).frame(minHeight: 44) }
                        if let date = source.date { Text("\(source.dateKind ?? "Date kind unknown"): \(date)").font(.caption2).foregroundStyle(ApolloStyle.muted) }
                    }
                }
            }
        }
    }
}
