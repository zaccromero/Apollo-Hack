import Foundation

public struct ApolloEvidenceReasoning: Codable, Hashable {
    public var factLabel: String
    public var facts: [ApolloEvidenceStatement]
    public var interpretations: [ApolloEvidenceStatement]
    public var counterevidence: [ApolloEvidenceStatement]
    public var counterevidenceStatus: String
    public var unknowns: [String]
    public var method: String
    public init(factLabel: String, facts: [ApolloEvidenceStatement], interpretations: [ApolloEvidenceStatement], counterevidence: [ApolloEvidenceStatement], counterevidenceStatus: String, unknowns: [String], method: String) { self.factLabel = factLabel; self.facts = facts; self.interpretations = interpretations; self.counterevidence = counterevidence; self.counterevidenceStatus = counterevidenceStatus; self.unknowns = unknowns; self.method = method }
}
public struct ApolloEvidenceStatement: Codable, Hashable {
    public let text: String
    public let sourceIDs: [String]
    public var kind: String
    public var source: ApolloEvidenceSourceLocator?
    public init(text: String, sourceIDs: [String], kind: String, source: ApolloEvidenceSourceLocator? = nil) { self.text = text; self.sourceIDs = sourceIDs; self.kind = kind; self.source = source }
}
public struct ApolloEvidenceSourceLocator: Codable, Hashable {
    public let id: String
    public let title: String
    public let url: String
    public let date: String?
    public let dateKind: String?
    public let kind: String?
    public init(id: String, title: String, url: String, date: String?, dateKind: String?, kind: String?) { self.id = id; self.title = title; self.url = url; self.date = date; self.dateKind = dateKind; self.kind = kind }
}
