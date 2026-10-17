import SwiftUI

/// Root integration owns presentation; authoritative profile and portfolio remain with the active service.
@MainActor struct ApolloAppHost: View {
    let service: any ApolloGameService
    let initialComparison: Bool
    let namespace:String
    let allowsDiagnostics:Bool
    @StateObject private var session: ApolloOnboardingSession
    @State private var showOnboarding: Bool
    init(service:any ApolloGameService,namespace:String,initialComparison:Bool=false,allowsDiagnostics:Bool=true) {
        self.service=service;self.initialComparison=initialComparison;self.namespace=namespace;self.allowsDiagnostics=allowsDiagnostics
        let session=ApolloOnboardingSession(storageKey:namespace+".onboarding.v1")
        _session=StateObject(wrappedValue:session)
        _showOnboarding=State(initialValue:!session.isComplete && !initialComparison)
    }
    private var context:ApolloOnboardingContext {
        ApolloOnboardingContext(mode:service is ApolloHTTPGameService ? .connected : .demo,
            dataFreshness:service is ApolloHTTPGameService ? "Dated cached research and labeled demo execution prices. Check each asset’s source and timestamp." : "Canonical DEMO paper prices, dated reviewed public evidence and separately labeled cached charts. No live market feed. Existing holdings and history are preserved.",
            privacyDescription:service is ApolloHTTPGameService ? "Your paper account and thesis use the explicitly selected local backend. Provider analysis is a separate deliberate action and remains paused." : "Your demo portfolio stays in this app. Source links open in your browser. No real brokerage is connected.",appVersion:"Apollo 1.0 · paper demo")
    }
    var body:some View {
        if showOnboarding {
            ApolloOnboardingView(session:session,context:context,loadProfile:{
                guard let profile=try await service.account().riskProfile else{return nil}
                guard let choice=ApolloOnboardingRiskChoice(rawValue:profile.tolerance.rawValue) else {throw ApolloAPIError.invalidResponse};return choice
            },saveProfile:{choice in
                guard let tolerance=ApolloRiskTolerance(rawValue:choice.rawValue) else {throw ApolloAPIError.invalidResponse}
                _ = try await service.setRiskProfile(tolerance)
            },onFinished:{showOnboarding=false})
        } else {
            ApolloGameRootView(service:service,diagnostics:allowsDiagnostics ? {AnyView(RunView())} : nil,initialRiskComparison:initialComparison,
                chartContent:{asset in AnyView(ApolloChartBridge(asset:asset,detail:(service as? ApolloHTTPGameService)?.researchDetail(for:asset.id),useBundledSnapshots:service is ApolloDemoGameService))},
                settingsContent:{AnyView(ApolloSettingsBridge(service:service,session:session,context:context))},discoveryKey:namespace+".discovery.v1")
        }
    }
}

@MainActor private struct ApolloSettingsBridge:View {
    @EnvironmentObject private var store:ApolloGameStore
    let service:any ApolloGameService
    @ObservedObject var session:ApolloOnboardingSession
    let context:ApolloOnboardingContext
    var body:some View {
        ApolloSettingsView(session:session,context:context,loadProfile:{
            guard let profile=try await service.account().riskProfile else{return nil}
            guard let choice=ApolloOnboardingRiskChoice(rawValue:profile.tolerance.rawValue) else {throw ApolloAPIError.invalidResponse};return choice
        },saveProfile:{choice in
            guard let tolerance=ApolloRiskTolerance(rawValue:choice.rawValue) else {throw ApolloAPIError.invalidResponse}
            store.account=try await service.setRiskProfile(tolerance)
        })
    }
}
