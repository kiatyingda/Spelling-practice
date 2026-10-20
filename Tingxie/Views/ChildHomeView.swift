import SwiftData
import SwiftUI

struct ChildHomeView: View {
    let onParent: () -> Void

    @Query(sort: \Sheet.createdAt, order: .reverse) private var sheets: [Sheet]
    @State private var practising: Sheet?

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
                            SheetCard(sheet: sheet) { practising = sheet }
                        }
                    }
                }
            }
        }
        .screen()
        .fullScreenCover(item: $practising) { sheet in
            PracticeView(sheet: sheet, mode: .learn) { practising = nil }
        }
    }
}

private struct SheetCard: View {
    let sheet: Sheet
    let onLearn: () -> Void

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
            Button(action: onLearn) { Text("Learn").frame(maxWidth: .infinity) }
                .buttonStyle(.prominentSurface)
                .disabled(sheet.items.isEmpty)
        }
        .padding(24)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Theme.line))
    }
}
