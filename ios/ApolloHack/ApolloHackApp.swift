import SwiftUI

struct Run: Decodable {
    let run_id: String
    let started_at: String
    let status: String
    let trace_id: String
    let steps: [Step]
    struct Step: Decodable, Identifiable {
        var id: String { provider }
        let provider: String
        let status: String
        let summary: String
    }
}

@main
@MainActor
struct ApolloHackApp: App {
    private let service: (any ApolloGameService)?
    private let configuration: ApolloRuntimeConfiguration?
    private let configurationError: String?
    init() {
        #if DEBUG
        let isDebug = true
        #else
        let isDebug = false
        #endif
        do {
            let config = try ApolloRuntimeConfiguration.resolve(
                declaredEnvironment: Bundle.main.object(forInfoDictionaryKey: "ApolloEnvironment") as? String,
                isDebugBuild: isDebug, arguments: ProcessInfo.processInfo.arguments)
            if config.environment == .staging {
                try ApolloStagingCarryover.prepare(validateSupplement: { key, data in
                    if key == "apollo.demo.onboarding.v1" { _ = try JSONDecoder().decode(ApolloOnboardingProgress.self, from: data) }
                    else if key == "apollo.demo.discovery.v1" { _ = try JSONDecoder().decode(ApolloDiscoveryPreferences.self, from: data) }
                }, validateAccount: { data in
                    _ = try JSONDecoder().decode(ApolloAccount.self, from: data)
                })
            }
            let resolvedService: any ApolloGameService
            if let url = config.backendURL { resolvedService = ApolloHTTPGameService(baseURL: url) }
            else { resolvedService = ApolloDemoGameService(storageKey: config.paperStorageKey, catalog: try ApolloBundledInstruments.reviewedDemoCatalog()) }
            service = resolvedService
            configuration = config
            configurationError = nil
        } catch {
            configuration = nil; service = nil
            configurationError = error.localizedDescription
        }
    }
    var body: some Scene {
        WindowGroup {
            if let configurationError {
                ContentUnavailableView("Practice unavailable", systemImage: "lock.shield", description: Text(configurationError))
            } else if let config = configuration, let service {
                if config.diagnosticsEnabled { RunView() }
                else {
                    ApolloAppHost(service: service, namespace: config.stateNamespace, initialComparison: config.initialComparison, allowsDiagnostics: config.environment == .dev)
                        .safeAreaInset(edge: .top, spacing: 0) {
                            if config.environment == .staging {
                                Text("TestFlight practice · your saved paper portfolio")
                                    .font(.caption2).foregroundStyle(.secondary).frame(maxWidth: .infinity).padding(.vertical, 3)
                                    .background(.thinMaterial)
                            }
                        }
                }
            }
        }
    }
}

struct RunView: View {
    @State private var evidence = ""
    @State private var run: Run?
    @State private var error: String?

    var body: some View {
        NavigationStack {
            List {
                if let run {
                    Section {
                        VStack(alignment: .leading, spacing: 12) {
                            Label(run.status == "PASS" ? "All four connected" : "Run needs attention",
                                  systemImage: run.status == "PASS" ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                                .font(.title2.bold())
                                .foregroundStyle(run.status == "PASS" ? .green : .orange)
                                .accessibilityIdentifier("run-status")
                            Text("One page. Four providers. A verified round trip.")
                                .font(.headline)
                            Text("Captured run · \(run.started_at)")
                                .font(.caption).foregroundStyle(.secondary)
                        }.padding(.vertical, 12)
                    }
                    Section("The journey") {
                        ForEach(run.steps) { step in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(step.provider).font(.headline)
                                    Spacer()
                                    Label(step.status, systemImage: "checkmark.circle.fill")
                                        .font(.caption.bold()).foregroundStyle(.green)
                                }
                                Text(step.summary).font(.subheadline).foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 8)
                            .accessibilityIdentifier("provider-\(step.provider)")
                        }
                    }
                    Section {
                        NavigationLink("View run evidence") {
                            ScrollView {
                                Text(evidence).font(.system(.caption, design: .monospaced))
                                    .textSelection(.enabled).padding()
                            }.navigationTitle("Run evidence")
                                .accessibilityIdentifier("evidence-content")
                        }.accessibilityIdentifier("view-evidence")
                        Text("Run ID: \(run.run_id)").font(.caption).foregroundStyle(.secondary)
                        Text("Trace: \(run.trace_id)").font(.caption.monospaced()).foregroundStyle(.secondary)
                    }
                    Section {
                        Text("This app displays the latest bundled test result. Run the Mac test and rebuild to refresh. Provider credentials stay on your Mac.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                } else {
                    ContentUnavailableView("No run available", systemImage: "tray", description: Text(error ?? "Run the provider test on your Mac, then rebuild the app."))
                }
            }
            .navigationTitle("Apollo Hack")
            .task { load() }
        }
    }

    private func load() {
        do {
            guard let url = Bundle.main.url(forResource: "run", withExtension: "json") else {
                error = "The bundled run file is missing."
                return
            }
            let data = try Data(contentsOf: url)
            evidence = String(decoding: data, as: UTF8.self)
            run = try JSONDecoder().decode(Run.self, from: data)
        } catch {
            self.error = "The bundled run could not be read."
        }
    }
}
