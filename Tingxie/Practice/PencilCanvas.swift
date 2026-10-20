import PencilKit
import SwiftUI
import UIKit
import UIKit.UIGestureRecognizerSubclass

/// Once an Apple Pencil touches any writing surface, fingers and palms stop drawing.
enum PencilState {
    static var seen = false
}

@MainActor
final class CanvasController: ObservableObject {
    weak var canvas: PKCanvasView?
    @Published var isEmpty = true

    func clear() {
        canvas?.drawing = PKDrawing()
        isEmpty = true
    }
}

/// Spots Pencil touches without interfering with PencilKit's own recognisers.
final class PencilDetector: UIGestureRecognizer {
    private let onPencil: () -> Void

    init(onPencil: @escaping () -> Void) {
        self.onPencil = onPencil
        super.init(target: nil, action: nil)
        cancelsTouchesInView = false
        delaysTouchesBegan = false
        delaysTouchesEnded = false
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        if touches.contains(where: { $0.type == .pencil }) { onPencil() }
        state = .failed
    }
}

struct PencilCanvas: UIViewRepresentable {
    let controller: CanvasController

    func makeCoordinator() -> Coordinator { Coordinator(controller: controller) }

    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = PKCanvasView()
        canvas.backgroundColor = .clear
        canvas.isOpaque = false
        canvas.isScrollEnabled = false
        canvas.drawingPolicy = PencilState.seen ? .pencilOnly : .anyInput
        // PencilKit adapts black ink for dark mode automatically.
        canvas.tool = PKInkingTool(.pen, color: .black, width: 6)
        canvas.delegate = context.coordinator
        let detector = PencilDetector { [weak canvas] in
            PencilState.seen = true
            canvas?.drawingPolicy = .pencilOnly
        }
        detector.delegate = context.coordinator
        canvas.addGestureRecognizer(detector)
        controller.canvas = canvas
        return canvas
    }

    func updateUIView(_ canvas: PKCanvasView, context: Context) {}

    @MainActor
    final class Coordinator: NSObject, PKCanvasViewDelegate, UIGestureRecognizerDelegate {
        let controller: CanvasController

        init(controller: CanvasController) {
            self.controller = controller
        }

        func canvasViewDrawingDidChange(_ canvas: PKCanvasView) {
            controller.isEmpty = canvas.drawing.strokes.isEmpty
        }

        func gestureRecognizer(_ g: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
            true
        }
    }
}
