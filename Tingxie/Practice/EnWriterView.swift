import SwiftUI

/// English: write on a blank ruled canvas, then Check reveals the answer and she marks herself.
/// "Stuck" reveals the next letter (word) or next word (sentence); any hint makes it a miss.
struct EnWriterView: View {
    let text: String
    let type: ItemType
    let onDone: (_ clean: Bool) -> Void

    @StateObject private var canvas = CanvasController()
    @State private var revealed = 0
    @State private var hinted = false
    @State private var clears = 0
    @State private var checked = false

    private var rows: Int { type == .sentence ? 2 : 1 }
    private var offerStuck: Bool { clears >= 2 && !checked }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            ZStack {
                RuledLines(rows: rows)
                PencilCanvas(controller: canvas)
            }
            .frame(height: CGFloat(rows) * 200)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Theme.line))
            .clipShape(RoundedRectangle(cornerRadius: 20))

            if hinted && !checked {
                Text(hintText)
                    .font(.system(size: 40, weight: .medium, design: .monospaced))
                    .tracking(6)
                    .foregroundStyle(Theme.muted)
                    .accessibilityLabel("Hint")
            }

            if checked {
                Text(text)
                    .font(.system(size: type == .word ? 64 : 40, weight: .semibold, design: .rounded))
                    .frame(maxWidth: .infinity, alignment: .center)
                HStack(spacing: 16) {
                    Spacer()
                    if hinted {
                        Text("You used a hint, so we'll practise this again.").foregroundStyle(Theme.muted)
                        Button("Next") { onDone(false) }.buttonStyle(.prominentSurface)
                    } else {
                        Button("✗ Not quite") { onDone(false) }.buttonStyle(.surface)
                        Button("✓ I got it") { onDone(true) }.buttonStyle(.prominentSurface)
                    }
                }
            } else {
                HStack(spacing: 12) {
                    Button("Clear") {
                        canvas.clear()
                        clears += 1
                    }
                    .buttonStyle(.surface)
                    Button(offerStuck ? "Stuck? Show a letter" : "Stuck") { revealNext() }
                        .buttonStyle(SurfaceButtonStyle(prominent: offerStuck))
                        .disabled(revealed >= text.count)
                    Spacer()
                    Button("Check") { checked = true }.buttonStyle(.prominentSurface)
                }
            }
        }
    }

    private var hintText: String {
        String(text.enumerated().map { i, c in i < revealed || !c.isLetter ? c : "_" })
    }

    private func revealNext() {
        hinted = true
        let chars = Array(text)
        var i = revealed
        if type == .sentence {
            while i < chars.count, chars[i].isWhitespace { i += 1 }
            while i < chars.count, !chars[i].isWhitespace { i += 1 }
        } else {
            while i < chars.count, !chars[i].isLetter { i += 1 }
            i += 1
        }
        revealed = min(i, chars.count)
    }
}

/// Handwriting guide: a solid baseline and a dashed midline per row.
struct RuledLines: View {
    let rows: Int

    var body: some View {
        Canvas { ctx, size in
            let rowHeight = size.height / CGFloat(rows)
            for r in 0..<rows {
                let top = CGFloat(r) * rowHeight
                var base = Path()
                base.move(to: CGPoint(x: 24, y: top + rowHeight * 0.75))
                base.addLine(to: CGPoint(x: size.width - 24, y: top + rowHeight * 0.75))
                ctx.stroke(base, with: .color(Theme.line), lineWidth: 2)
                var mid = Path()
                mid.move(to: CGPoint(x: 24, y: top + rowHeight * 0.45))
                mid.addLine(to: CGPoint(x: size.width - 24, y: top + rowHeight * 0.45))
                ctx.stroke(mid, with: .color(Theme.line), style: StrokeStyle(lineWidth: 1, dash: [8, 8]))
            }
        }
        .allowsHitTesting(false)
    }
}
