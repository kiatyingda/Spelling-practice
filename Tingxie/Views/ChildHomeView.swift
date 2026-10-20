import SwiftData
import SwiftUI

struct ChildHomeView: View {
    let onParent: () -> Void

    @Query(sort: \Sheet.createdAt, order: .reverse) private var sheets: [Sheet]
    @State private var launch: Launch?

    private struct Launch: Identifiable {
        let id = UUID()
        let sheet: Sheet
        let mode: PracticeView.Mode
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack {
                Text("听写")
                    .font(.system(.largeTitle, design: .rounded).weight(.semibold))
                Spacer()
                LongPressGate(action: onParent)
            }
            if sheets.isEmpty {
                VStack(spacing: 8) {
                    Text("No sheets yet.")
                        .font(.system(.title, design: .rounded))
                    Text("Ask a grown-up to add this week's list.")
                        .font(.title3)
                        .foregroundStyle(Theme.muted)
                }
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 320), spacing: 20)], spacing: 20) {
                        ForEach(sheets) { sheet in
                            SheetCard(sheet: sheet) { launch = Launch(sheet: sheet, mode: $0) }
                        }
                    }
                }
            }
        }
        .screen()
        .fullScreenCover(item: $launch) { l in
            PracticeView(sheet: l.sheet, mode: l.mode) { launch = nil }
        }
    }
}

private struct SheetCard: View {
    let sheet: Sheet
    let onPractice: (PracticeView.Mode) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Tag(text: sheet.lang.label)
                if sheet.testReady { Tag(text: "Test-ready", tone: Theme.mastered) }
            }
            Text(sheet.title)
                .font(.system(.title2, design: .rounded).weight(.semibold))
            SheetProgressBar(sheet: sheet)
            SheetProgressLegend(sheet: sheet)
            let fresh = sheet.count(.new)
            let learning = sheet.count(.learning)
            let mockReady = Mastery.mockReady(sheet)
            HStack(spacing: 12) {
                Button { onPractice(.learn) } label: { Text("Learn").frame(maxWidth: .infinity) }
                    .buttonStyle(SurfaceButtonStyle(prominent: fresh > 0))
                    .disabled(fresh + learning == 0)
                Button { onPractice(.drill) } label: {
                    Text(learning > 0 ? "Drill · \(learning)" : "Drill").frame(maxWidth: .infinity)
                }
                .buttonStyle(SurfaceButtonStyle(prominent: fresh == 0 && learning > 0))
                .disabled(learning == 0)
                Button {} label: {
                    Label("Mock", systemImage: mockReady ? "checkmark.seal" : "lock").frame(maxWidth: .infinity)
                }
                .buttonStyle(.surface)
                .disabled(true)
            }
            if !mockReady {
                Text("Mock 听写 unlocks when everything is mastered.")
                    .font(.footnote)
                    .foregroundStyle(Theme.muted)
            }
        }
        .padding(24)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Theme.line))
    }
}
