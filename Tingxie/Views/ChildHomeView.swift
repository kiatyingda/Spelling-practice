import SwiftData
import SwiftUI

struct ChildHomeView: View {
    let onParent: () -> Void

    @Query(sort: \Sheet.createdAt, order: .reverse) private var sheets: [Sheet]

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
                        ForEach(sheets) { SheetCard(sheet: $0) }
                    }
                }
            }
        }
        .screen()
    }
}

private struct SheetCard: View {
    let sheet: Sheet

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
            Button {} label: { Text("Learn").frame(maxWidth: .infinity) }
                .buttonStyle(.prominentSurface)
                .disabled(true)
                .opacity(0.4)
        }
        .padding(24)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Theme.line))
    }
}
