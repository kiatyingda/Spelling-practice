import SwiftData
import SwiftUI

/// Mock 听写: items in random order, each read twice, she writes on paper.
/// Then a grown-up photographs the page for marking and can override any mark.
struct MockView: View {
    let sheet: Sheet
    let onClose: () -> Void

    private enum Stage: Equatable {
        case intro, reading, finished, marking, review, saved
    }

    @Environment(\.modelContext) private var context
    @AppStorage(SpeechSettings.Key.repeatGap) private var repeatGap = SpeechSettings.defaultRepeatGap
    @AppStorage(SpeechSettings.Key.itemGap) private var itemGap = SpeechSettings.defaultItemGap

    @State private var stage: Stage = .intro
    @State private var order: [Item] = []
    @State private var index = 0
    @State private var paused = false
    @State private var countdown: Double = 0
    @State private var runner: Task<Void, Never>?
    @State private var startedAt = Date()
    @State private var marks: [MockMark] = []
    @State private var markError: String?
    @State private var pages: [UIImage] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack {
                Button(stage == .saved ? "← Home" : "← Stop") {
                    stop()
                    onClose()
                }
                .buttonStyle(.surface)
                Spacer()
                Text("Mock 听写 · \(sheet.title)")
                    .font(.title3)
                    .foregroundStyle(Theme.muted)
            }
            Group {
                switch stage {
                case .intro: intro
                case .reading: reading
                case .finished: finished
                case .marking: marking
                case .review: review
                case .saved: saved
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .screen()
        .onDisappear(perform: stop)
    }

    // MARK: Reading

    private var intro: some View {
        VStack(spacing: 16) {
            Text("Get your paper and pencil.")
                .font(.system(.largeTitle, design: .rounded).weight(.semibold))
            Text("\(sheet.items.count) items. Each is read twice. Write the number, then the answer.")
                .font(.title3)
                .foregroundStyle(Theme.muted)
            Button("Start") {
                order = sheet.items.shuffled()
                startedAt = .now
                index = 0
                stage = .reading
                run()
            }
            .buttonStyle(.prominentSurface)
            .font(.title2)
            .padding(.top, 12)
        }
        .multilineTextAlignment(.center)
    }

    private var reading: some View {
        VStack(spacing: 32) {
            Text("\(index + 1)")
                .font(.system(size: 160, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())
            Text("of \(order.count)").font(.title3).foregroundStyle(Theme.muted)
            ProgressView(value: countdown)
                .tint(Theme.accent)
                .frame(maxWidth: 420)
            HStack(spacing: 12) {
                Button(paused ? "Resume" : "Pause") {
                    if paused { paused = false; run() } else { paused = true; halt() }
                }
                .buttonStyle(.surface)
                Button("Say it again") {
                    guard index < order.count else { return }
                    halt()
                    paused = false
                    run(repeatOnly: true)
                }
                .buttonStyle(.surface)
            }
        }
    }

    /// Reads from `index` onwards. With `repeatOnly`, says the current item once more, then carries on.
    private func run(repeatOnly: Bool = false) {
        runner?.cancel()
        runner = Task { @MainActor in
            var first = true
            while index < order.count {
                let item = order[index]
                countdown = 0
                if !(repeatOnly && first) {
                    await Speech.shared.speak(item.text, lang: sheet.lang)
                    if Task.isCancelled { return }
                    try? await Task.sleep(for: .seconds(repeatGap))
                    if Task.isCancelled { return }
                }
                first = false
                await Speech.shared.speak(item.text, lang: sheet.lang)
                if Task.isCancelled { return }
                let steps = Int(itemGap * 10)
                for s in 0..<max(steps, 1) {
                    try? await Task.sleep(for: .milliseconds(100))
                    if Task.isCancelled { return }
                    countdown = Double(s + 1) / Double(max(steps, 1))
                }
                if index + 1 >= order.count { break }
                withAnimation { index += 1 }
            }
            stage = .finished
        }
    }

    private func halt() {
        runner?.cancel()
        runner = nil
        Speech.shared.stop()
    }

    private func stop() {
        halt()
    }

    // MARK: Marking

    private var finished: some View {
        VStack(spacing: 20) {
            Text("All done!")
                .font(.system(.largeTitle, design: .rounded).weight(.semibold))
            Text("Ask a grown-up to photograph your page.")
                .font(.title3)
                .foregroundStyle(Theme.muted)
            PagePicker(scanLabel: "Scan the answers") { mark($0) }
                .padding(.top, 8)
            Button("Mark by hand instead") {
                marks = blankMarks(correct: true)
                stage = .review
            }
            .buttonStyle(.surface)
            if let markError {
                Text(markError).foregroundStyle(Theme.miss).multilineTextAlignment(.center).frame(maxWidth: 600)
            }
        }
    }

    private var marking: some View {
        VStack(spacing: 16) {
            ProgressView().controlSize(.large)
            Text("Marking…").font(.title3)
        }
    }

    private func blankMarks(correct: Bool) -> [MockMark] {
        order.enumerated().map { i, item in
            MockMark(n: i + 1, itemId: item.id, expected: item.text, written: "", correct: correct, note: "")
        }
    }

    private func mark(_ newPages: [UIImage]) {
        pages = newPages
        markError = nil
        stage = .marking
        Task {
            do {
                let items = order.enumerated().map { VisionClient.MarkItem(n: $0 + 1, text: $1.text) }
                let results = try await VisionClient.mark(pages, lang: sheet.lang, items: items)
                let byN = Dictionary(results.map { ($0.n, $0) }, uniquingKeysWith: { a, _ in a })
                marks = blankMarks(correct: false).map { m in
                    var m = m
                    if let r = byN[m.n] {
                        m.written = r.written
                        m.correct = r.correct
                        m.note = r.note
                    }
                    return m
                }
                stage = .review
            } catch {
                markError = error.localizedDescription
                stage = .finished
            }
        }
    }

    /// Parent review: every mark can be flipped before saving.
    private var review: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("\(marks.filter(\.correct).count) / \(marks.count)")
                    .font(.system(.largeTitle, design: .rounded).weight(.semibold))
                    .monospacedDigit()
                Text("Tap a mark to change it.").foregroundStyle(Theme.muted)
                Spacer()
                Button("Save") {
                    MockOutcome.apply(marks, to: sheet, startedAt: startedAt, context: context)
                    stage = .saved
                }
                .buttonStyle(.prominentSurface)
            }
            ScrollView {
                VStack(spacing: 8) {
                    ForEach($marks) { $mark in
                        MarkRow(mark: $mark)
                    }
                }
            }
        }
    }

    private var saved: some View {
        let missed = marks.filter { !$0.correct }
        return VStack(spacing: 16) {
            Text(missed.isEmpty ? "Full marks. Test-ready!" : "\(marks.count - missed.count) / \(marks.count)")
                .font(.system(.largeTitle, design: .rounded).weight(.semibold))
            if !missed.isEmpty {
                Text("These go back to Drill:").foregroundStyle(Theme.muted)
                Text(missed.map(\.expected).joined(separator: "  ·  ")).font(.title3)
            }
            Button("Back home", action: onClose).buttonStyle(.prominentSurface).padding(.top, 12)
        }
        .multilineTextAlignment(.center)
    }
}

private struct MarkRow: View {
    @Binding var mark: MockMark

    var body: some View {
        Button {
            mark.correct.toggle()
        } label: {
            HStack(spacing: 16) {
                Text("\(mark.n)").monospacedDigit().foregroundStyle(Theme.muted).frame(width: 36, alignment: .trailing)
                VStack(alignment: .leading, spacing: 2) {
                    Text(mark.expected).font(.title3)
                    if !mark.written.isEmpty && mark.written != mark.expected {
                        Text("Wrote: \(mark.written)").font(.subheadline).foregroundStyle(Theme.muted)
                    }
                    if !mark.note.isEmpty {
                        Text(mark.note).font(.subheadline).foregroundStyle(Theme.muted)
                    }
                }
                Spacer()
                Image(systemName: mark.correct ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.title)
                    .foregroundStyle(mark.correct ? Theme.good : Theme.miss)
            }
            .padding(.horizontal, 20)
            .frame(minHeight: 72)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.radius))
            .overlay(RoundedRectangle(cornerRadius: Theme.radius).stroke(Theme.line))
            .contentShape(RoundedRectangle(cornerRadius: Theme.radius))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(mark.n). \(mark.expected), \(mark.correct ? "correct" : "wrong")")
        .accessibilityHint("Double-tap to change")
    }
}
