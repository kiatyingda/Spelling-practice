import Charts
import SwiftData
import SwiftUI

/// Parent: one sheet's mastery over time (one point per session) and per-item status.
struct ProgressDetailView: View {
    let sheet: Sheet
    let onClose: () -> Void

    @Query private var logs: [SessionLog]

    init(sheet: Sheet, onClose: @escaping () -> Void) {
        self.sheet = sheet
        self.onClose = onClose
        let id = sheet.id
        _logs = Query(filter: #Predicate<SessionLog> { $0.sheetId == id }, sort: \.endedAt)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                ScreenHeader(title: "Progress") {
                    Button("← Back", action: onClose).buttonStyle(.surface)
                } trailing: {
                    EmptyView()
                }
                Text(sheet.title).font(.title2.weight(.semibold))
                HStack(spacing: 24) {
                    SheetProgressBar(sheet: sheet).frame(maxWidth: 360)
                    SheetProgressLegend(sheet: sheet)
                }
                Panel {
                    Text("Mastered over time").font(.title3.weight(.semibold))
                    if logs.isEmpty {
                        Text("No sessions yet.").foregroundStyle(Theme.muted)
                    } else {
                        chart.frame(height: 240)
                    }
                }
                Panel {
                    Text("Items").font(.title3.weight(.semibold))
                    ForEach(sheet.orderedItems) { item in
                        ItemStatusRow(item: item, lang: sheet.lang)
                        if item.id != sheet.orderedItems.last?.id { Divider().overlay(Theme.line) }
                    }
                }
            }
        }
        .screen()
    }

    private var chart: some View {
        Chart {
            ForEach(Array(logs.enumerated()), id: \.element.id) { i, log in
                LineMark(x: .value("Session", i + 1), y: .value("Mastered", log.masteredCount))
                    .interpolationMethod(.stepEnd)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    .foregroundStyle(Theme.mastered)
                PointMark(x: .value("Session", i + 1), y: .value("Mastered", log.masteredCount))
                    .symbolSize(64)
                    .foregroundStyle(log.mode == .mock ? Theme.ink : Theme.mastered)
                    .accessibilityLabel("Session \(i + 1), \(log.mode.rawValue)")
                    .accessibilityValue("\(log.masteredCount) mastered")
            }
            RuleMark(y: .value("All items", sheet.items.count))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                .foregroundStyle(Theme.muted)
                .annotation(position: .top, alignment: .leading) {
                    Text("\(sheet.items.count) items").font(.caption).foregroundStyle(Theme.muted)
                }
        }
        .chartYScale(domain: 0...max(sheet.items.count, 1))
        .chartXAxisLabel("Session")
        .chartYAxis {
            AxisMarks(position: .leading) { _ in
                AxisGridLine().foregroundStyle(Theme.line)
                AxisValueLabel().foregroundStyle(Theme.muted)
            }
        }
        .chartXAxis {
            AxisMarks { _ in
                AxisValueLabel().foregroundStyle(Theme.muted)
            }
        }
    }
}

private struct ItemStatusRow: View {
    let item: Item
    let lang: Lang

    var body: some View {
        HStack(spacing: 16) {
            Text(item.text).font(.title3)
            Text(item.type.label(lang)).font(.caption).foregroundStyle(Theme.muted)
            Spacer()
            if item.misses > 0 {
                Text("\(item.misses) miss\(item.misses == 1 ? "" : "es")").font(.subheadline).foregroundStyle(Theme.muted)
            }
            HStack(spacing: 6) {
                Circle().fill(color).frame(width: 10, height: 10)
                Text(item.status.rawValue.capitalized).font(.subheadline)
            }
            .frame(width: 110, alignment: .leading)
        }
        .frame(minHeight: 48)
    }

    private var color: Color {
        switch item.status {
        case .new: Theme.new
        case .learning: Theme.learning
        case .mastered: Theme.mastered
        }
    }
}
