import SwiftUI

struct ApolloLibraryView: View {
    @ObservedObject var store: ApolloGameStore
    @State private var section: ApolloLibrarySection = .available
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text("Your swipe library").font(.system(.largeTitle, design: .serif))
                Text("You choose the types. Apollo selects individual cards from the reviewed catalog in its recorded order. This deck is not a personalized recommendation.").font(.subheadline).foregroundStyle(ApolloStyle.muted)
                NavigationLink { ApolloTypePreferencesView(store: store) } label: {
                    HStack { Label("Choose asset types", systemImage: "slider.horizontal.3"); Spacer(); Text("\(store.discovery.selectedTypes.count) selected").font(.caption); Image(systemName: "chevron.right") }.frame(minHeight: 48)
                }.accessibilityIdentifier("library-type-preferences")
                NavigationLink { ApolloSocialResearchView(store: store) } label: { Label("Research an Instagram post", systemImage: "link").frame(minHeight: 48) }.accessibilityIdentifier("library-social-research")
                Picker("Library status", selection: $section) { ForEach(ApolloLibrarySection.allCases) { Text($0.label).tag($0) } }.pickerStyle(.segmented)
                Text(sectionNotice).font(.caption).foregroundStyle(ApolloStyle.muted)
                let items = store.libraryAssets(section)
                if items.isEmpty { ApolloEmptyState(title: "No \(section.rawValue) cards", message: "Your financial profile and holdings are unchanged by browsing this library.", symbol: "books.vertical") }
                ForEach(items) { asset in
                    ApolloPanel {
                        DisclosureGroup {
                            VStack(alignment: .leading, spacing: 10) {
                                Text(asset.summary)
                                Text(asset.quoteProvenance).font(.caption).foregroundStyle(ApolloStyle.muted)
                                Text("\(asset.isDemo ? "DEMO" : "SOURCED") · \(asset.priceLabel)").font(.caption).foregroundStyle(ApolloStyle.amber)
                                if let asOf = asset.quoteAsOf { Text("Quote as of \(asOf)").font(.caption).foregroundStyle(ApolloStyle.muted) }
                                ForEach(asset.sources) { source in
                                    if let url = URL(string: source.url), ["https", "http"].contains(url.scheme?.lowercased() ?? "") { Link(source.title, destination: url).frame(minHeight: 44) }
                                }
                            }.padding(.top, 12)
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(asset.name).font(.headline)
                                Text("\(asset.ticker) · \(asset.kind.label)").font(.caption).foregroundStyle(ApolloStyle.muted)
                                Text(store.account.watchlistIDs.contains(asset.id) ? "Watched" : store.discovery.seenAssetIDs.contains(asset.id) ? "Seen" : "Not yet seen").font(.caption2).foregroundStyle(ApolloStyle.lime)
                            }
                        }
                    }.accessibilityIdentifier("library-asset-\(asset.id)")
                }
            }.padding(20).frame(maxWidth: 620).frame(maxWidth: .infinity)
        }.background(ApolloStyle.ink).foregroundStyle(ApolloStyle.cream).navigationTitle("Library").navigationBarTitleDisplayMode(.inline)
    }
    private var sectionNotice: String {
        switch section {
        case .available: return "Eligible for the current practice round within your selected types. Expanding a library record does not put that investment at the front of the deck."
        case .seen: return "Cards shown in Discover, including cards you have not acted on. Saved on this device."
        case .passed: return "Your latest pass/watch decision for these cards was Pass. Passing does not sell a holding or remove a saved watch."
        case .watched: return "Your current watchlist. Research items, not commitments or holdings."
        }
    }
}

struct ApolloTypePreferencesView: View {
    @ObservedObject var store: ApolloGameStore
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("What would you like to explore?").font(.system(.largeTitle, design: .serif))
                Text("Choose categories, and Apollo will choose individual cards from the reviewed catalog. These preferences affect discovery only; they do not change your risk profile or portfolio.").foregroundStyle(ApolloStyle.muted)
                ForEach(ApolloAssetKind.allCases) { kind in
                    Toggle(isOn: Binding(get: { store.discovery.selectedTypes.contains(kind) }, set: { store.setType(kind, enabled: $0) })) {
                        Label(kind.label, systemImage: kind.symbol).frame(minHeight: 44)
                    }.accessibilityIdentifier("type-preference-\(kind.rawValue)")
                }
                if store.discovery.selectedTypes.isEmpty { Text("No cards will appear until you select at least one type.").font(.caption).foregroundStyle(ApolloStyle.amber) }
                Text("Individual investments are never selected for your deck here. You can revisit your own holdings and watchlist in their tabs.").font(.caption).foregroundStyle(ApolloStyle.muted)
            }.padding(20).frame(maxWidth: 620).frame(maxWidth: .infinity)
        }.background(ApolloStyle.ink).foregroundStyle(ApolloStyle.cream).navigationTitle("Asset types").navigationBarTitleDisplayMode(.inline)
    }
}
