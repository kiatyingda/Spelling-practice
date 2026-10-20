import SwiftUI

/// 中文: stroke-by-stroke recall with hanzi-writer. Any wrong stroke or hint makes it a miss.
struct ZhWriterView: View {
    let text: String
    let type: ItemType
    let onDone: (_ clean: Bool) -> Void

    @StateObject private var controller = HanziController()
    @State private var data: [String: Data]?
    @State private var height: CGFloat = 240
    @State private var mistakes = 0
    @State private var hinted = false
    @State private var offerStuck = false

    private var size: CGFloat { type == .word && text.count <= 5 ? 200 : 112 }

    var body: some View {
        VStack(spacing: 24) {
            if let data {
                HanziWriterView(
                    chars: text.filter { !$0.isWhitespace }.map(String.init),
                    data: data, size: size, controller: controller, onEvent: handle)
                    .frame(height: height)
            } else {
                ProgressView().frame(height: height)
            }
            HStack {
                Spacer()
                Button(offerStuck ? "Stuck? Show the next stroke" : "Stuck") {
                    hinted = true
                    offerStuck = false
                    controller.hint()
                }
                .buttonStyle(SurfaceButtonStyle(prominent: offerStuck))
                .animation(.easeInOut, value: offerStuck)
            }
        }
        .task {
            var loaded: [String: Data] = [:]
            for ch in HanziData.characters(in: text) {
                if let json = await HanziData.shared.json(for: ch) { loaded[ch] = json }
            }
            data = loaded
        }
    }

    private func handle(_ event: HanziEvent) {
        switch event {
        case .ready(let h):
            if h > 0 { height = h }
        case .mistake(let onStroke):
            mistakes += 1
            // hanzi-writer itself flashes the stroke after 2 misses; make "Stuck" obvious too.
            if onStroke >= 2 { offerStuck = true }
        case .correctStroke:
            offerStuck = false
        case .complete:
            onDone(mistakes == 0 && !hinted)
        case .charComplete, .missingData:
            break
        }
    }
}
