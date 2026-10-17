import SwiftUI

@MainActor public struct ApolloSettingsView: View {
    @ObservedObject private var session: ApolloOnboardingSession
    private let context: ApolloOnboardingContext
    private let loadProfile: ApolloOnboardingLoadProfile
    private let saveProfile: ApolloOnboardingSaveProfile
    @State private var profile: ApolloOnboardingRiskChoice?
    @State private var loaded = false
    @State private var loading = false
    @State private var error: String?
    @State private var sheet: Destination?
    @State private var resetConfirmation = false
    private enum Destination: String, Identifiable {
        case learning, profile, quiz
        var id: String { rawValue }
    }
    public init(session: ApolloOnboardingSession, context: ApolloOnboardingContext,
                loadProfile: @escaping ApolloOnboardingLoadProfile,
                saveProfile: @escaping ApolloOnboardingSaveProfile) {
        self.session = session; self.context = context
        self.loadProfile = loadProfile; self.saveProfile = saveProfile
    }
    public var body: some View {
        List {
            Section("Your paper profile") {
                if loading { ProgressView("Loading saved profile…") }
                else if loaded {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(profile?.title ?? "No profile confirmed yet").font(.headline)
                        Text(profile.map { "DEMO educational ceiling \($0.ceiling) / 5" } ?? "Choose deliberately before reviewing an investment.")
                            .font(.caption).foregroundStyle(ApolloOnboardingStyle.secondaryText)
                    }.accessibilityElement(children: .combine).accessibilityIdentifier("settings-saved-profile")
                    Button(profile == nil ? "Choose risk profile" : "Review or edit risk profile") { sheet = .profile }
                        .frame(minHeight: 44).accessibilityIdentifier("settings-edit-profile")
                }
                if let error {
                    Text(error).foregroundStyle(ApolloOnboardingStyle.warning)
                    Button("Retry loading profile") { Task { await reload() } }.frame(minHeight: 44)
                }
                Text("Comparing all three profiles in the game does not change this saved choice.")
                    .font(.caption).foregroundStyle(ApolloOnboardingStyle.secondaryText)
            }.listRowBackground(ApolloOnboardingStyle.surface)
            Section("Learning") {
                Button { sheet = .learning } label: { Label("Replay the quick introduction", systemImage: "play.circle") }
                    .frame(minHeight: 44).accessibilityIdentifier("settings-replay-learning")
                HStack { Text("Setup"); Spacer(); Text(session.isComplete ? "Completed" : "In progress").foregroundStyle(ApolloOnboardingStyle.secondaryText) }
                Button("Start quiz again") { resetConfirmation = true }
                    .frame(minHeight: 44).accessibilityIdentifier("settings-reset-quiz")
                Text("Only quiz progress restarts. Your saved risk profile, paper cash, holdings and history stay with the game.")
                    .font(.caption).foregroundStyle(ApolloOnboardingStyle.secondaryText)
            }.listRowBackground(ApolloOnboardingStyle.surface)
            Section("Session & data") {
                Label(context.mode.title, systemImage: context.mode == .demo ? "sparkles" : "network")
                    .font(.subheadline.bold()).foregroundStyle(ApolloOnboardingStyle.accent)
                    .accessibilityIdentifier("settings-paper-mode")
                Text(context.mode == .demo ? "A labeled demo session using practice data." : "Connected to a paper-game service. This is still simulated trading.")
                Text(context.dataFreshness).font(.subheadline).accessibilityIdentifier("settings-data-freshness")
                Text("Check each asset’s date and source in research. A connection does not guarantee live quotes.")
                    .font(.caption).foregroundStyle(ApolloOnboardingStyle.secondaryText)
            }.listRowBackground(ApolloOnboardingStyle.surface)
            Section("Privacy") {
                Text("This quiz asks for no income, savings, identity or brokerage details.")
                Text(context.privacyDescription).font(.subheadline).foregroundStyle(ApolloOnboardingStyle.secondaryText)
                Text("Quiz progress is saved on this device. Reinstalling or clearing app data can remove it.")
                    .font(.caption).foregroundStyle(ApolloOnboardingStyle.secondaryText)
            }.listRowBackground(ApolloOnboardingStyle.surface)
            Section("About Apollo") {
                Text("Learn to question the story behind an investment.").font(.system(.title3, design: .serif))
                Text("Educational paper game. No real orders, promised returns or personal financial advice.").font(.caption).foregroundStyle(ApolloOnboardingStyle.secondaryText)
                Text(context.appVersion).font(.caption).foregroundStyle(ApolloOnboardingStyle.secondaryText)
            }.listRowBackground(ApolloOnboardingStyle.surface)
        }.scrollContentBackground(.hidden).background(ApolloOnboardingStyle.canvas)
            .foregroundStyle(ApolloOnboardingStyle.primaryText).tint(ApolloOnboardingStyle.accent)
            .preferredColorScheme(context.appearance.colorScheme).navigationTitle("Settings").navigationBarTitleDisplayMode(.large)
            .task { await reload() }
            .confirmationDialog("Restart only the quiz?", isPresented: $resetConfirmation, titleVisibility: .visible) {
                Button("Restart quiz") { session.resetQuiz(); sheet = .quiz }
                Button("Cancel", role: .cancel) {}
            } message: { Text("Your saved risk profile and paper portfolio are preserved. A different risk choice is saved only if you explicitly confirm it at the end.") }
            .sheet(item: $sheet, onDismiss: { Task { await reload() } }) { destination in
                switch destination {
                case .learning: ApolloLearningReplayView(appearance: context.appearance)
                case .profile:
                    ApolloSettingsProfileEditor(current: profile, appearance: context.appearance, save: saveProfile) { sheet = nil }
                case .quiz:
                    NavigationStack {
                        ApolloOnboardingView(session: session, context: context, loadProfile: loadProfile, saveProfile: saveProfile) { sheet = nil }
                            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Save for later") { sheet = nil }.disabled(session.isSaving) } }
                    }
                }
            }
    }
    private func reload() async {
        guard !loading else { return }
        loading = true; defer { loading = false }
        do { profile = try await loadProfile(); loaded = true; error = nil }
        catch { loaded = false; profile = nil; self.error = "Your saved profile is unavailable. Retry to review or edit it." }
    }
}

@MainActor private struct ApolloSettingsProfileEditor: View {
    let current: ApolloOnboardingRiskChoice?
    let appearance: ApolloOnboardingAppearance
    let save: ApolloOnboardingSaveProfile
    let onSaved: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var selected: ApolloOnboardingRiskChoice?
    @State private var reviewing = false
    @State private var saving = false
    @State private var error: String?
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text(reviewing ? "Confirm your change." : "Your paper comfort zone.")
                        .font(.system(.largeTitle, design: .serif)).accessibilityAddTraits(.isHeader)
                    if reviewing, let selected {
                        Text("\(current?.title ?? "No profile") → \(selected.title)").font(.title2.bold())
                        Text(selected.explanation).foregroundStyle(ApolloOnboardingStyle.secondaryText)
                        Text("DEMO educational ceiling: \(selected.ceiling) / 5. This is not a measured chance of loss.").font(.subheadline)
                        Text("Saving updates only your paper risk profile. Existing holdings stay in place; future paper previews use the confirmed profile.").font(.subheadline).foregroundStyle(ApolloOnboardingStyle.secondaryText)
                    } else {
                        Text("Current: \(current?.title ?? "Not selected"). Tap a choice, then review before saving.").font(.subheadline).foregroundStyle(ApolloOnboardingStyle.secondaryText)
                        ApolloOnboardingChoices(selected: selected) { selected = $0 }
                    }
                    if let error { Text(error).foregroundStyle(ApolloOnboardingStyle.warning).accessibilityIdentifier("settings-profile-error") }
                    ApolloOnboardingButton(title: saving ? "Saving…" : (reviewing ? "Confirm paper risk profile" : "Review choice"), disabled: selected == nil || saving) {
                        if reviewing { Task { await confirm() } } else { reviewing = true }
                    }.accessibilityIdentifier("settings-profile-confirm")
                    if reviewing { Button("Back to choices") { reviewing = false }.frame(minHeight: 44).disabled(saving) }
                }.padding(24).frame(maxWidth: 620).frame(maxWidth: .infinity)
            }.background(ApolloOnboardingStyle.canvas).foregroundStyle(ApolloOnboardingStyle.primaryText)
                .navigationTitle("Risk profile").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Cancel") { dismiss() }.disabled(saving) } }
        }.tint(ApolloOnboardingStyle.accent).preferredColorScheme(appearance.colorScheme).interactiveDismissDisabled(saving)
    }
    private func confirm() async {
        guard !saving, let selected else { return }
        saving = true; defer { saving = false }
        do { try await save(selected); onSaved() }
        catch { self.error = "The save wasn’t confirmed. Close this screen to reload the active profile, or retry." }
    }
}

@MainActor private struct ApolloLearningReplayView: View {
    let appearance: ApolloOnboardingAppearance
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("A little practice.\nBetter questions.").font(.system(.largeTitle, design: .serif)).accessibilityAddTraits(.isHeader)
                    ApolloPracticeIntroduction()
                    Text("Paper money only. Demo charts and hypothetical scenarios are not forecasts.").font(.caption).foregroundStyle(ApolloOnboardingStyle.secondaryText)
                }.padding(24).frame(maxWidth: 620).frame(maxWidth: .infinity)
            }.background(ApolloOnboardingStyle.canvas).foregroundStyle(ApolloOnboardingStyle.primaryText)
                .navigationTitle("Quick introduction").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
        }.preferredColorScheme(appearance.colorScheme).tint(ApolloOnboardingStyle.accent)
    }
}
