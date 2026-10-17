import Foundation

public struct ApolloComparisonRequest {
    public let assetID: String
    public let quantityText: String
    public let quantity: Decimal
    public let strategyBudget: Decimal?
    public init(assetID: String, quantityText: String, quantity: Decimal, strategyBudget: Decimal?) { self.assetID = assetID; self.quantityText = quantityText; self.quantity = quantity; self.strategyBudget = strategyBudget }
    public func matches(assetID: String, quantityText: String) -> Bool { self.assetID == assetID && self.quantityText == quantityText }
    @MainActor public func fetch(using service: any ApolloGameService) async throws -> ApolloComparisonResponse {
        let value = try await service.comparePaper(assetID: assetID, quantity: quantity, strategyBudget: strategyBudget)
        guard !value.mutatesAccount, !value.createsOrder, value.profiles.count == ApolloRiskTolerance.allCases.count,
              Set(value.profiles.map(\.tolerance)) == Set(ApolloRiskTolerance.allCases) else { throw ApolloGameError.service("The service did not return a read-only comparison with all three profiles. It was not displayed.") }
        return .init(request: self, comparison: value)
    }
}
public struct ApolloComparisonResponse {
    public let request: ApolloComparisonRequest
    public let comparison: ApolloPaperComparison
}
