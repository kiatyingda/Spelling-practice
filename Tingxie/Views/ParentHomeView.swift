import SwiftData
import SwiftUI

enum ParentRoute: Hashable {
    case newSheet(Lang)
    case edit(Sheet)
    case settings
}

struct ParentHomeView: View {
    let onDone: () -> Void

    @Query(sort: \Sheet.createdAt, order: .reverse) private var sheets: [Sheet]
    @State private var path: [ParentRoute] = []

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    ScreenHeader(title: "Parent") {
                        Button("← Done", action: onDone).buttonStyle(.surface)
                    } trailing: {
                        Button("Voices & pace") { path.append(.settings) }.buttonStyle(.surface)
                    }
                    HStack(spacing: 12) {
                        Button("+ 中文 听写 sheet") { path.append(.newSheet(.zh)) }.buttonStyle(.prominentSurface)
                        Button("+ English spelling sheet") { path.append(.newSheet(.en)) }.buttonStyle(.prominentSurface)
                    }
                    if sheets.isEmpty {
                        Text("No sheets yet. Add this week's list.").foregroundStyle(Theme.muted)
                    }
                    VStack(spacing: 8) {
                        ForEach(sheets) { sheet in
                            Button { path.append(.edit(sheet)) } label: { SheetRow(sheet: sheet) }
                                .buttonStyle(.plain)
                        }
                    }
                }
            }
            .screen()
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: ParentRoute.self) { route in
                Group {
                    switch route {
                    case .newSheet(let lang):
                        SheetEditorView(draft: SheetDraft(lang: lang), sheet: nil) { path.removeLast() }
                    case .edit(let sheet):
                        SheetEditorView(draft: SheetDraft(sheet: sheet), sheet: sheet) { path.removeLast() }
                    case .settings:
                        SettingsView { path.removeLast() }
                    }
                }
                .toolbar(.hidden, for: .navigationBar)
            }
        }
    }
}

private struct SheetRow: View {
    let sheet: Sheet

    var body: some View {
        HStack(spacing: 16) {
            Tag(text: sheet.lang == .zh ? "中文" : "EN")
            VStack(alignment: .leading, spacing: 2) {
                Text(sheet.title).font(.headline)
                Text("\(sheet.items.count) items · \(sheet.createdAt.formatted(date: .abbreviated, time: .omitted))")
                    .font(.subheadline)
                    .foregroundStyle(Theme.muted)
            }
            Spacer()
            SheetProgressBar(sheet: sheet).frame(width: 120)
            Image(systemName: "chevron.right").foregroundStyle(Theme.muted)
        }
        .padding(.horizontal, 20)
        .frame(minHeight: 72)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.radius))
        .overlay(RoundedRectangle(cornerRadius: Theme.radius).stroke(Theme.line))
        .contentShape(RoundedRectangle(cornerRadius: Theme.radius))
    }
}
