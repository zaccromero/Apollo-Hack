import Foundation

/// The three research-owned evidence channels. Unknown coverage is a fallback within a channel,
/// never an extra generic channel or a reason to mix one channel's source links into another.
public enum ApolloEvidenceTracks {
    public static func canonical(_ supplied: [ApolloEvidenceTrack], isDemo: Bool) -> [ApolloEvidenceTrack] {
        let channels: [(title: String, keys: [String], missing: String)] = [
            ("Leadership", ["leadership"], "No reviewed leadership evidence is available. A leadership change does not establish a causal effect on results."),
            ("Promises vs results", ["promises vs results", "promises_results"], "No reviewed comparison of stated promises and delivered results is available. A plan is not completed performance."),
            ("Public sentiment", ["public sentiment", "public_sentiment"], "No reviewed public-sentiment evidence is available. Unknown is not a neutral or 50/50 sentiment reading.")
        ]
        return channels.map { channel in
            if let track = supplied.first(where: { channel.keys.contains($0.topic.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()) }) {
                return ApolloEvidenceTrack(topic: channel.title, status: track.status, summary: track.summary, sources: track.sources, reasoning: track.reasoning)
            }
            return ApolloEvidenceTrack(topic: channel.title, status: isDemo ? "Demo · unknown" : "Unknown", summary: channel.missing)
        }
    }
}
