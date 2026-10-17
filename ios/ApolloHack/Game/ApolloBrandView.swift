import SwiftUI

/// Native path from the owner-selected Ascending A mark, original viewBox 0 0 240 240.
/// Matches marketing's ascending-blue/mark-light.svg; no alternate logo or raster asset is invented.
struct ApolloAscendingMark: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: .init(x: 122, y: 16)); p.addLines([.init(x: 143, y: 56), .init(x: 63, y: 214), .init(x: 21, y: 214)]); p.closeSubpath()
        p.move(to: .init(x: 154, y: 90)); p.addLines([.init(x: 219, y: 214), .init(x: 178, y: 214), .init(x: 133, y: 129)]); p.closeSubpath()
        p.move(to: .init(x: 88, y: 164)); p.addLines([.init(x: 152, y: 148), .init(x: 166, y: 174), .init(x: 74, y: 190)]); p.closeSubpath()
        return p.applying(.init(scaleX: rect.width / 240, y: rect.height / 240))
    }
}
