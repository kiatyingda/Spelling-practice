import SwiftUI
import UIKit
import WebKit

enum HanziEvent {
    case ready(height: CGFloat)
    case mistake(mistakesOnStroke: Int)
    case correctStroke
    case charComplete(totalMistakes: Int)
    case complete
    case missingData
}

/// Lets SwiftUI poke the web view ("Stuck" → highlight the next stroke).
@MainActor
final class HanziController: ObservableObject {
    weak var webView: WKWebView?

    func hint() {
        webView?.evaluateJavaScript("TX.hint()")
    }
}

/// hanzi-writer quiz (bundled JS, offline) for one item: one 田字格 box per character, written in order.
struct HanziWriterView: UIViewRepresentable {
    let chars: [String]
    let data: [String: Data]
    let size: CGFloat
    let controller: HanziController
    let onEvent: (HanziEvent) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.userContentController.add(context.coordinator, name: "tx")
        let web = WKWebView(frame: .zero, configuration: config)
        web.isOpaque = false
        web.backgroundColor = .clear
        web.scrollView.backgroundColor = .clear
        web.scrollView.isScrollEnabled = false
        web.scrollView.contentInsetAdjustmentBehavior = .never
        web.navigationDelegate = context.coordinator
        controller.webView = web
        if let dir = Bundle.main.url(forResource: "HanziWeb", withExtension: nil) {
            web.loadFileURL(dir.appendingPathComponent("index.html"), allowingReadAccessTo: dir)
        }
        return web
    }

    func updateUIView(_ web: WKWebView, context: Context) {
        context.coordinator.parent = self
    }

    static func dismantleUIView(_ web: WKWebView, coordinator: Coordinator) {
        web.configuration.userContentController.removeScriptMessageHandler(forName: "tx")
    }

    fileprivate func loadScript(traits: UITraitCollection) -> String {
        func hex(_ name: String) -> String {
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            (UIColor(named: name) ?? .label).resolvedColor(with: traits).getRed(&r, &g, &b, &a)
            return String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
        }
        var strokeData: [String: Any] = [:]
        for (ch, json) in data {
            if let obj = try? JSONSerialization.jsonObject(with: json) { strokeData[ch] = obj }
        }
        let cfg: [String: Any] = [
            "chars": chars,
            "data": strokeData,
            "size": Int(size),
            "pen": PencilState.seen,
            "colors": [
                "ink": hex("TxInk"), "accent": hex("AccentColor"), "line": hex("TxLine"),
                "surface": hex("TxSurface"), "muted": hex("TxMuted"), "hint": hex("TxLearning"),
            ],
        ]
        let json = (try? JSONSerialization.data(withJSONObject: cfg)).flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
        return "TX.load(\(json))"
    }

    @MainActor
    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var parent: HanziWriterView

        init(_ parent: HanziWriterView) {
            self.parent = parent
        }

        func webView(_ web: WKWebView, didFinish navigation: WKNavigation!) {
            web.evaluateJavaScript(parent.loadScript(traits: web.traitCollection))
        }

        func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
            guard let body = message.body as? [String: Any], let type = body["type"] as? String else { return }
            let int = { (key: String) in (body[key] as? NSNumber)?.intValue ?? 0 }
            switch type {
            case "ready": parent.onEvent(.ready(height: CGFloat((body["height"] as? NSNumber)?.doubleValue ?? 0)))
            case "mistake": parent.onEvent(.mistake(mistakesOnStroke: int("mistakesOnStroke")))
            case "correctStroke": parent.onEvent(.correctStroke)
            case "charComplete": parent.onEvent(.charComplete(totalMistakes: int("totalMistakes")))
            case "complete": parent.onEvent(.complete)
            case "missingData": parent.onEvent(.missingData)
            case "pen": PencilState.seen = true
            default: break
            }
        }
    }
}
