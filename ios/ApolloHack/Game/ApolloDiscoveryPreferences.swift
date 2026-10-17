import Foundation

/// Local discovery history and type preferences; separate from financial profile and holdings.
public struct ApolloDiscoveryPreferences: Codable {
    public var selectedTypes: Set<ApolloAssetKind>
    public var seenAssetIDs: Set<String>
    public init(selectedTypes: Set<ApolloAssetKind> = Set(ApolloAssetKind.allCases), seenAssetIDs: Set<String> = []) { self.selectedTypes = selectedTypes; self.seenAssetIDs = seenAssetIDs }
    public static func load(defaults: UserDefaults, key: String) -> Self {
        guard let data = defaults.data(forKey: key), let value = try? JSONDecoder().decode(Self.self, from: data) else { return .init() }
        return value
    }
    public func save(defaults: UserDefaults, key: String) throws { defaults.set(try JSONEncoder().encode(self), forKey: key) }
    public func includes(_ asset: ApolloAsset) -> Bool { selectedTypes.contains(asset.kind) }
}

public enum ApolloLibrarySection: String, CaseIterable, Identifiable {
    case available, seen, passed, watched
    public var id: String { rawValue }
    public var label: String { rawValue.capitalized }
}
