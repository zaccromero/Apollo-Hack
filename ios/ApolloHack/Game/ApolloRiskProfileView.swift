import SwiftUI

struct ApolloRiskProfileView: View {
    @ObservedObject var store: ApolloGameStore
    var onSaved: (() -> Void)? = nil
    @State private var selected: ApolloRiskTolerance?
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            ApolloEyebrow(text: "Your paper-game comfort zone")
            Text("Choose your risk profile.").font(.system(.title, design: .serif))
            Text("This game uses a transparent DEMO 1–5 risk rubric. It is an educational rule, not a measured chance of loss or personal financial advice.").font(.subheadline).foregroundStyle(ApolloStyle.muted)
            ForEach(ApolloRiskTolerance.allCases) { tolerance in
                Button { selected = tolerance } label: {
                    HStack(alignment: .top, spacing: 14) {
                        Image(systemName: selected == tolerance ? "largecircle.fill.circle" : "circle").foregroundStyle(ApolloStyle.lime)
                        VStack(alignment: .leading, spacing: 6) { Text(tolerance.label).font(.headline); Text("Educational asset-risk ceiling: \(tolerance.ceiling) of 5").font(.caption).foregroundStyle(ApolloStyle.muted) }
                        Spacer()
                    }.padding(18).frame(maxWidth: .infinity, alignment: .leading).background(ApolloStyle.surface, in: RoundedRectangle(cornerRadius: 18))
                }.buttonStyle(.plain).accessibilityIdentifier("risk-profile-\(tolerance.rawValue)").accessibilityAddTraits(selected == tolerance ? .isSelected : [])
            }
            Text("If an asset exceeds your ceiling, unknown sentiment keeps it on the watchlist. A known mixed bullish/bearish assessment may permit a separately acknowledged paper-only exception. Mixed sentiment does not make an asset safer.").font(.caption).foregroundStyle(ApolloStyle.amber)
            if let error = store.error { Text(error).font(.caption).foregroundStyle(ApolloStyle.amber) }
            ApolloPrimaryButton(title: store.busy ? "Saving…" : "Confirm paper risk profile", symbol: "checkmark", disabled: selected == nil || store.busy) { guard let selected else { return }; Task { if await store.setRiskProfile(selected) { onSaved?() } } }.accessibilityIdentifier("risk-profile-confirm")
        }.onAppear { selected = store.account.riskProfile?.tolerance }.foregroundStyle(ApolloStyle.cream)
    }
}
