import SwiftUI

@MainActor public struct ApolloOnboardingView: View {
    @ObservedObject private var session: ApolloOnboardingSession
    private let context: ApolloOnboardingContext
    private let loadProfile: ApolloOnboardingLoadProfile
    private let saveProfile: ApolloOnboardingSaveProfile
    private let onFinished: () -> Void
    @State private var savedProfile: ApolloOnboardingRiskChoice?
    @State private var loaded = false
    @State private var loading = false
    @State private var error: String?
    @AccessibilityFocusState private var headingFocused: Bool

    public init(session: ApolloOnboardingSession, context: ApolloOnboardingContext,
                loadProfile: @escaping ApolloOnboardingLoadProfile,
                saveProfile: @escaping ApolloOnboardingSaveProfile,
                onFinished: @escaping () -> Void) {
        self.session = session; self.context = context; self.loadProfile = loadProfile
        self.saveProfile = saveProfile; self.onFinished = onFinished
    }
    public var body: some View {
        ScrollViewReader { scroll in
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Color.clear.frame(height: 0).id("onboarding-top")
                    HStack {
                        HStack(spacing: 8) {
                            ApolloOnboardingBrandMark().fill(ApolloOnboardingStyle.accent).frame(width: 32, height: 32).accessibilityHidden(true)
                            Text("apollo").font(.title2.bold())
                        }.foregroundStyle(ApolloOnboardingStyle.accent).accessibilityElement(children: .combine).accessibilityLabel("Apollo")
                        Spacer()
                        Text("\(session.progress.step.rawValue + 1) of 3").font(.subheadline.monospacedDigit())
                    }
                    ProgressView(value: Double(session.progress.step.rawValue + 1), total: 3)
                        .tint(ApolloOnboardingStyle.accent).accessibilityLabel("Onboarding progress")
                        .accessibilityValue("Step \(session.progress.step.rawValue + 1) of 3")
                    Text(title).font(.system(.largeTitle, design: .serif).weight(.medium))
                        .accessibilityAddTraits(.isHeader).accessibilityFocused($headingFocused)
                    content
                    if loading { ProgressView("Loading your saved profile…") }
                    if let error { errorView(error) }
                    if let storageError = session.storageError { errorView(storageError) }
                    ApolloOnboardingButton(title: session.isSaving ? "Saving your choice…" : primaryTitle,
                                           disabled: primaryDisabled) { advance() }
                        .accessibilityIdentifier("onboarding-continue")
                    if session.progress.step != .introduction {
                        Button("Back") { session.back() }
                            .frame(maxWidth: .infinity, minHeight: 44).disabled(session.isSaving)
                            .accessibilityIdentifier("onboarding-back")
                    }
                    Text("No real money. No brokerage connection. You can edit your choice in Settings.")
                        .font(.caption).foregroundStyle(ApolloOnboardingStyle.secondaryText)
                }.padding(24).frame(maxWidth: 620).frame(maxWidth: .infinity, alignment: .center)
            }.onChange(of: session.progress.step) { _, _ in
                scroll.scrollTo("onboarding-top", anchor: .top); headingFocused = true
            }
        }.background(ApolloOnboardingStyle.canvas).foregroundStyle(ApolloOnboardingStyle.primaryText)
            .tint(ApolloOnboardingStyle.accent).preferredColorScheme(context.appearance.colorScheme)
            .task { if !loaded { await reloadProfile() } }
            .interactiveDismissDisabled(session.isSaving)
    }
    private var title: String {
        switch session.progress.step {
        case .introduction: return "Build your investing instinct."
        case .riskChoice: return "Choose your comfort zone."
        case .review: return "Your choice. Your practice."
        }
    }
    @ViewBuilder private var content: some View {
        switch session.progress.step {
        case .introduction:
            Text(context.mode.title).font(.caption.bold()).foregroundStyle(ApolloOnboardingStyle.accent)
            Text("Three quick steps. Then your first card.")
                .font(.body).foregroundStyle(ApolloOnboardingStyle.secondaryText)
            ApolloPracticeIntroduction()
        case .riskChoice:
            Text("Choose a practice style. No score or automatic assignment.")
                .font(.subheadline).foregroundStyle(ApolloOnboardingStyle.secondaryText)
            if let savedProfile { Text("Currently saved: \(savedProfile.title). Choosing below creates a draft until you confirm.").font(.caption).foregroundStyle(ApolloOnboardingStyle.secondaryText) }
            ApolloOnboardingChoices(selected: session.progress.draftChoice) { session.choose($0) }
                .disabled(session.isSaving)
            Text("DEMO ceilings are educational rules, not loss probabilities. Comparing profiles in the game never changes your saved choice.")
                .font(.caption).foregroundStyle(ApolloOnboardingStyle.secondaryText)
        case .review:
            if let choice = session.progress.draftChoice {
                VStack(alignment: .leading, spacing: 12) {
                    Text("PAPER RISK PROFILE").font(.caption.weight(.semibold)).foregroundStyle(ApolloOnboardingStyle.secondaryText)
                    Text(choice.title).font(.title.bold())
                    Text(choice.explanation).font(.body).foregroundStyle(ApolloOnboardingStyle.secondaryText)
                    Text("DEMO educational ceiling: \(choice.ceiling) / 5").font(.subheadline.bold()).foregroundStyle(ApolloOnboardingStyle.accent)
                }.padding(24).frame(maxWidth: .infinity, alignment: .leading)
                    .background(ApolloOnboardingStyle.surface, in: RoundedRectangle(cornerRadius: 24))
            }
            Text("Confirming saves this risk choice for the active paper session. It does not place an order or change your cash or holdings.").font(.subheadline)
            Text("A profile may limit paper orders. Unknown evidence stays unknown; mixed sentiment does not make an asset safer.")
                .font(.caption).foregroundStyle(ApolloOnboardingStyle.warning)
        }
    }
    private var primaryTitle: String {
        session.progress.step == .review ? "Confirm choice & start practicing" : "Continue"
    }
    private var primaryDisabled: Bool {
        session.isSaving || (session.progress.step != .introduction && (session.progress.draftChoice == nil || !loaded))
    }
    private func errorView(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(text).foregroundStyle(ApolloOnboardingStyle.warning)
            if !loaded { Button("Retry loading profile") { Task { await reloadProfile() } }.frame(minHeight: 44).disabled(loading) }
        }.font(.subheadline).accessibilityIdentifier("onboarding-error")
    }
    private func reloadProfile() async {
        guard !loading else { return }
        loading = true; defer { loading = false }
        do { savedProfile = try await loadProfile(); loaded = true; error = nil }
        catch { loaded = false; self.error = "Your saved profile couldn’t be loaded. Your quiz draft is safe. Retry before confirming." }
    }
    private func advance() {
        guard !primaryDisabled else { return }
        if session.progress.step != .review { session.next(); return }
        Task {
            do { try await session.finish(saveProfile: saveProfile); onFinished() }
            catch { self.error = "Your choice couldn’t be confirmed. Your quiz is still here. Please try again." }
        }
    }
}
