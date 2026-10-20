import SwiftUI

/// Parent gate: hold for 1.5s to trigger. A child tapping won't get through.
struct LongPressGate: View {
    static let duration: Double = 1.5

    var label = "Hold for parent"
    let action: () -> Void

    @State private var holding = false

    var body: some View {
        Text(label)
            .font(.footnote)
            .foregroundStyle(Theme.muted)
            .padding(.horizontal, 20)
            .frame(minWidth: Theme.touch, minHeight: Theme.touch)
            .background(Theme.surface)
            .overlay(alignment: .bottomLeading) {
                GeometryReader { geo in
                    Rectangle()
                        .fill(Theme.accent)
                        .frame(width: holding ? geo.size.width : 0, height: 4)
                        .frame(maxHeight: .infinity, alignment: .bottom)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: Theme.radius))
            .overlay(RoundedRectangle(cornerRadius: Theme.radius).stroke(Theme.line))
            .contentShape(RoundedRectangle(cornerRadius: Theme.radius))
            .onLongPressGesture(minimumDuration: Self.duration, maximumDistance: 40) {
                holding = false
                action()
            } onPressingChanged: { pressing in
                withAnimation(pressing ? .linear(duration: Self.duration) : .easeOut(duration: 0.15)) {
                    holding = pressing
                }
            }
            .accessibilityAddTraits(.isButton)
            .accessibilityHint("Press and hold for one and a half seconds")
    }
}
