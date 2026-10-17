import SwiftUI

// Scoped projection of the owner-approved Ascending A blue/light and midnight reverse.
// Dynamic colors follow the explicit appearance supplied in the presentation context.
import UIKit

enum ApolloOnboardingStyle {
    static let canvas = color(light: 0xF4F7FF, dark: 0x0B1428)
    static let surface = color(light: 0xFFFFFF, dark: 0x15223B)
    static let raised = color(light: 0xE7EDF9, dark: 0x20304D)
    static let primaryText = color(light: 0x0B1428, dark: 0xF4F7FF)
    static let accent = color(light: 0x3268DF, dark: 0x6495FF)
    static let secondaryText = color(light: 0x4F5E78, dark: 0xB3C2DC)
    static let warning = color(light: 0x805000, dark: 0xFFCC80)
    static let onAccent = color(light: 0xFFFFFF, dark: 0x0B1428)
    private static func color(light: UInt32, dark: UInt32) -> Color {
        Color(uiColor: UIColor { traits in
            let value = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: CGFloat((value >> 16) & 255) / 255,
                           green: CGFloat((value >> 8) & 255) / 255,
                           blue: CGFloat(value & 255) / 255, alpha: 1)
        })
    }
}

extension ApolloOnboardingAppearance {
    var colorScheme: ColorScheme { self == .light ? .light : .dark }
}

/// Exact polygon projection from the selected mark-light.svg (240×240 viewBox).
/// Shared app icon/catalog remains owned by Integration.
struct ApolloOnboardingBrandMark: Shape {
    func path(in rect: CGRect) -> Path {
        let points: [[CGPoint]] = [
            [.init(x:122,y:16),.init(x:143,y:56),.init(x:63,y:214),.init(x:21,y:214)],
            [.init(x:154,y:90),.init(x:219,y:214),.init(x:178,y:214),.init(x:133,y:129)],
            [.init(x:88,y:164),.init(x:152,y:148),.init(x:166,y:174),.init(x:74,y:190)]
        ]
        let scale = min(rect.width, rect.height) / 240
        let dx = rect.midX - 120 * scale; let dy = rect.midY - 120 * scale
        var path = Path()
        for polygon in points {
            path.move(to: CGPoint(x: polygon[0].x * scale + dx, y: polygon[0].y * scale + dy))
            for point in polygon.dropFirst() { path.addLine(to: CGPoint(x: point.x * scale + dx, y: point.y * scale + dy)) }
            path.closeSubpath()
        }
        return path
    }
}

struct ApolloOnboardingButton: View {
    let title: String
    var disabled = false
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack { Text(title); Spacer(); Image(systemName: "arrow.right") }
                .font(.headline).padding(20).frame(maxWidth: .infinity, minHeight: 52)
                .background(disabled ? ApolloOnboardingStyle.raised : ApolloOnboardingStyle.accent, in: RoundedRectangle(cornerRadius: 20))
                .foregroundStyle(disabled ? ApolloOnboardingStyle.secondaryText : ApolloOnboardingStyle.onAccent)
        }.buttonStyle(.plain).disabled(disabled)
    }
}

struct ApolloOnboardingChoices: View {
    let selected: ApolloOnboardingRiskChoice?
    let choose: (ApolloOnboardingRiskChoice) -> Void
    var body: some View {
        VStack(spacing: 12) {
            ForEach(ApolloOnboardingRiskChoice.allCases) { choice in
                Button { choose(choice) } label: {
                    HStack(alignment: .top, spacing: 16) {
                        Image(systemName: selected == choice ? "checkmark.circle.fill" : "circle")
                            .font(.title3).foregroundStyle(ApolloOnboardingStyle.accent)
                        VStack(alignment: .leading, spacing: 8) {
                            Text(choice.title).font(.headline).foregroundStyle(ApolloOnboardingStyle.primaryText)
                            Text(choice.explanation).font(.subheadline).foregroundStyle(ApolloOnboardingStyle.secondaryText)
                            Text("DEMO ceiling \(choice.ceiling) / 5").font(.caption.weight(.semibold)).foregroundStyle(ApolloOnboardingStyle.accent)
                        }
                        Spacer(minLength: 0)
                    }.padding(20).frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        .background(ApolloOnboardingStyle.surface, in: RoundedRectangle(cornerRadius: 24))
                        .overlay(RoundedRectangle(cornerRadius: 24).stroke(selected == choice ? ApolloOnboardingStyle.accent : .clear, lineWidth: 1))
                }.buttonStyle(.plain)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(choice.title). \(choice.explanation) Educational risk ceiling \(choice.ceiling) out of 5.")
                    .accessibilityAddTraits(selected == choice ? .isSelected : [])
                    .accessibilityIdentifier("onboarding-risk-\(choice.rawValue)")
            }
        }
    }
}

struct ApolloPracticeIntroduction: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            instruction("Look closer", symbol: "doc.text.magnifyingglass", text: "Tap a card. Check sources, dates and unknowns.")
            instruction("Make a call", symbol: "hand.draw", text: "Swipe left to pass, up to watch, right to review. Or use the buttons.")
            instruction("Practice, then reflect", symbol: "lightbulb", text: "Review your thesis, risk and paper cost. Confirm separately to invest.")
        }
    }
    private func instruction(_ title: String, symbol: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: symbol).font(.title2).foregroundStyle(ApolloOnboardingStyle.accent).frame(width: 32)
            VStack(alignment: .leading, spacing: 8) {
                Text(title).font(.headline)
                Text(text).font(.subheadline).foregroundStyle(ApolloOnboardingStyle.secondaryText)
            }
        }.accessibilityElement(children: .combine)
    }
}
