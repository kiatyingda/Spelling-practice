import SwiftUI

/// Parent: photograph the teacher's list → /api/vision → editable confirm screen → save.
struct CaptureView: View {
    let onClose: () -> Void

    private enum Stage {
        case pick
        case reading
        case confirm(SheetDraft)
        case failed(String)
    }

    @State private var stage: Stage = .pick
    @State private var pages: [UIImage] = []

    var body: some View {
        switch stage {
        case .confirm(let draft):
            SheetEditorView(draft: draft, sheet: nil, title: "Check the list", onClose: onClose)
        default:
            VStack(alignment: .leading, spacing: 24) {
                ScreenHeader(title: "Scan a sheet") {
                    Button("← Cancel", action: onClose).buttonStyle(.surface)
                } trailing: {
                    EmptyView()
                }
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .screen()
        }
    }

    @ViewBuilder private var content: some View {
        switch stage {
        case .pick:
            VStack(spacing: 20) {
                Text("Photograph this week's 听写 or spelling list.")
                    .font(.title3)
                Text("You'll check every item before it's saved.")
                    .foregroundStyle(Theme.muted)
                PagePicker(scanLabel: "Scan the list", onPages: read)
                    .padding(.top, 8)
            }
        case .reading:
            VStack(spacing: 16) {
                ProgressView().controlSize(.large)
                Text("Reading the sheet…").font(.title3)
            }
        case .failed(let message):
            VStack(spacing: 16) {
                Text(message)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Theme.miss)
                HStack(spacing: 12) {
                    Button("Try again") { read(pages) }.buttonStyle(.prominentSurface)
                    Button("Type it in instead") { stage = .confirm(SheetDraft(lang: .zh)) }.buttonStyle(.surface)
                }
            }
            .frame(maxWidth: 600)
        case .confirm:
            EmptyView()
        }
    }

    private func read(_ newPages: [UIImage]) {
        pages = newPages
        stage = .reading
        Task {
            do {
                let result = try await VisionClient.extract(pages)
                let lang = Lang(rawValue: result.lang) ?? .zh
                let lines = result.items.map { item in
                    SheetDraft.Line(text: item.text, type: ItemType(rawValue: item.type) ?? ItemTyping.guess(item.text, lang: lang))
                }
                guard !lines.isEmpty else {
                    stage = .failed("No items found on that page. Try a clearer, flatter photo.")
                    return
                }
                stage = .confirm(SheetDraft(lang: lang, title: result.title, lines: lines))
            } catch {
                stage = .failed(error.localizedDescription)
            }
        }
    }
}
