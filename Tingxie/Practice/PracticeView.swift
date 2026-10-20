import SwiftData
import SwiftUI

/// One practice session.
/// Learn: hear it, see it once, hide, write from memory.
/// Drill: hear it, write it. Misses come back once at the end; capped at ~5 minutes.
struct PracticeView: View {
    enum Mode {
        case learn, drill

        var log: SessionMode { self == .learn ? .learn : .drill }
    }

    private enum Phase {
        case ready, show, write, result, done
    }

    let sheet: Sheet
    let mode: Mode
    let onClose: () -> Void

    @Environment(\.modelContext) private var context
    @State private var sessionId = UUID()
    @State private var startedAt = Date()
    @State private var queue: [Item] = []
    @State private var index = 0
    @State private var phase: Phase = .ready
    @State private var lastClean = false
    /// First result per item this session (retries don't overwrite it).
    @State private var results: [UUID: Bool] = [:]
    @State private var logged = false
    @State private var requeued: Set<UUID> = []
    @State private var timeUp = false

    private var current: Item? { queue.indices.contains(index) ? queue[index] : nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            header
            switch phase {
            case .ready: ready
            case .show: show
            case .write: write
            case .result: result
            case .done: done
            }
        }
        .screen()
        .onAppear {
            if queue.isEmpty { queue = mode == .learn ? Mastery.learnPool(sheet) : Mastery.drillPool(sheet) }
        }
        .task(id: "\(index)-\(phase)") {
            let speaks = phase == .show || (phase == .write && mode == .drill)
            if speaks, let item = current { await say(item) }
        }
        .onDisappear { Speech.shared.stop() }
    }

    // MARK: Phases

    private var header: some View {
        HStack(spacing: 16) {
            Button(phase == .done ? "← Home" : "← Stop") {
                logSession()
                onClose()
            }
            .buttonStyle(.surface)
            Spacer()
            if phase != .ready && phase != .done {
                Text("\(min(index + 1, queue.count)) / \(queue.count)")
                    .font(.title3.monospacedDigit())
                    .foregroundStyle(Theme.muted)
                Button {
                    if let item = current { Task { await say(item) } }
                } label: {
                    Label("Listen", systemImage: "speaker.wave.2.fill")
                }
                .buttonStyle(.surface)
            }
        }
    }

    private var ready: some View {
        VStack(spacing: 16) {
            Text(sheet.title).font(.system(.largeTitle, design: .rounded).weight(.semibold))
            Text(readyText)
                .font(.title3)
                .foregroundStyle(Theme.muted)
            if !queue.isEmpty {
                Button("Start") { phase = firstPhase }
                    .buttonStyle(.prominentSurface)
                    .font(.title2)
                    .padding(.top, 16)
            }
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var show: some View {
        VStack(spacing: 40) {
            if let item = current {
                Text(item.text)
                    .font(.system(size: item.type == .word ? 120 : 56, weight: .medium, design: .rounded))
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.4)
            }
            Button("Hide & write") { phase = .write }
                .buttonStyle(.prominentSurface)
                .font(.title2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder private var write: some View {
        if let item = current {
            Group {
                if sheet.lang == .zh {
                    ZhWriterView(text: item.text, type: item.type, onDone: record)
                } else {
                    EnWriterView(text: item.text, type: item.type, onDone: record)
                }
            }
            .id("\(index)-\(item.id)")
            Spacer(minLength: 0)
        }
    }

    private var result: some View {
        VStack(spacing: 28) {
            if let item = current {
                Text(item.text)
                    .font(.system(size: item.type == .word ? 96 : 48, weight: .medium, design: .rounded))
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.4)
            }
            Text(lastClean ? "✓ Clean" : "We'll practise this one again")
                .font(.title2.weight(.semibold))
                .foregroundStyle(lastClean ? Theme.good : Theme.miss)
            Button(index + 1 < queue.count ? "Next" : "Finish", action: advance)
                .buttonStyle(.prominentSurface)
                .font(.title2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var done: some View {
        let clean = results.values.filter { $0 }.count
        return VStack(spacing: 20) {
            Text(timeUp ? "That's enough for today" : "Done for now")
                .font(.system(.largeTitle, design: .rounded).weight(.semibold))
            if timeUp {
                Text("Short and often works best. Come back later for more.")
                    .font(.title3)
                    .foregroundStyle(Theme.muted)
            }
            Text("\(clean) clean · \(results.count - clean) to practise")
                .font(.title3)
                .foregroundStyle(Theme.muted)
            SheetProgressBar(sheet: sheet).frame(maxWidth: 480)
            SheetProgressLegend(sheet: sheet)
            Button("Back home") { onClose() }
                .buttonStyle(.prominentSurface)
                .padding(.top, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var firstPhase: Phase { mode == .learn ? .show : .write }

    private var readyText: String {
        switch (mode, queue.isEmpty) {
        case (.learn, true): "Everything here is mastered."
        case (.drill, true): "Nothing to drill right now."
        case (.learn, false): "\(queue.count) to learn. Listen, look, then write it from memory."
        case (.drill, false): "\(queue.count) to practise. Listen, then write it."
        }
    }

    // MARK: Actions

    private func say(_ item: Item) async {
        await Speech.shared.speak(item.text, lang: sheet.lang)
    }

    private func record(_ clean: Bool) {
        guard let item = current else { return }
        Mastery.apply(clean: clean, to: item, session: sessionId)
        if results[item.id] == nil { results[item.id] = clean }
        // Drill: one more go at a miss before the session ends.
        if mode == .drill, !clean, !requeued.contains(item.id) {
            requeued.insert(item.id)
            queue.append(item)
        }
        try? context.save()
        lastClean = clean
        phase = .result
    }

    private func advance() {
        index += 1
        timeUp = mode == .drill && index < queue.count && Date().timeIntervalSince(startedAt) >= Mastery.sessionCap
        if index >= queue.count || timeUp {
            logSession()
            phase = .done
        } else {
            phase = firstPhase
        }
    }

    private func logSession() {
        guard !logged, !results.isEmpty else { return }
        logged = true
        context.insert(SessionLog(
            sheetId: sheet.id, mode: mode.log, startedAt: startedAt, endedAt: .now,
            masteredCount: sheet.count(.mastered)))
        try? context.save()
    }
}
