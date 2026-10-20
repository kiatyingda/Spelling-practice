import SwiftUI

/// Calm, paper-like palette (light + dark variants live in the asset catalog).
enum Theme {
    static let background = Color("TxBackground")
    static let surface = Color("TxSurface")
    static let ink = Color("TxInk")
    static let muted = Color("TxMuted")
    static let line = Color("TxLine")
    static let accent = Color("AccentColor")
    static let good = Color("TxGood")
    static let miss = Color("TxMiss")
    static let new = Color("TxNew")
    static let learning = Color("TxLearning")
    static let mastered = Color("TxMastered")

    /// Minimum touch target for a child's finger.
    static let touch: CGFloat = 56
    static let radius: CGFloat = 16
    static let gutter: CGFloat = 32
}

extension View {
    /// Standard full-screen page: paper background, generous landscape gutters.
    func screen() -> some View {
        frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(.horizontal, Theme.gutter)
            .padding(.vertical, 24)
            .background(Theme.background.ignoresSafeArea())
            .foregroundStyle(Theme.ink)
    }
}

/// Bordered surface button sized for kids.
struct SurfaceButtonStyle: ButtonStyle {
    var prominent = false
    /// Square icon buttons drop the horizontal padding.
    var compact = false

    func makeBody(configuration: Configuration) -> some View {
        StyledLabel(configuration: configuration, prominent: prominent, compact: compact)
    }

    private struct StyledLabel: View {
        let configuration: Configuration
        let prominent: Bool
        let compact: Bool
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            configuration.label
                .font(.body.weight(.medium))
                .padding(.horizontal, compact ? 0 : 24)
                .frame(minWidth: Theme.touch, minHeight: Theme.touch)
                .foregroundStyle(prominent ? Theme.background : Theme.ink)
                .background(prominent ? Theme.accent : Theme.surface, in: RoundedRectangle(cornerRadius: Theme.radius))
                .overlay(RoundedRectangle(cornerRadius: Theme.radius).stroke(prominent ? .clear : Theme.line))
                .opacity(isEnabled ? (configuration.isPressed ? 0.7 : 1) : 0.4)
                .contentShape(RoundedRectangle(cornerRadius: Theme.radius))
        }
    }
}

extension ButtonStyle where Self == SurfaceButtonStyle {
    static var surface: SurfaceButtonStyle { SurfaceButtonStyle() }
    static var prominentSurface: SurfaceButtonStyle { SurfaceButtonStyle(prominent: true) }
}
