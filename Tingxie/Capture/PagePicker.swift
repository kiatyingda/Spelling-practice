import PhotosUI
import SwiftUI
import VisionKit

/// VisionKit document scanner (flattened, cropped pages). Not available on the simulator.
struct DocumentScanner: UIViewControllerRepresentable {
    let onFinish: ([UIImage]) -> Void

    static var isSupported: Bool { VNDocumentCameraViewController.isSupported }

    func makeCoordinator() -> Coordinator { Coordinator(onFinish: onFinish) }

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let vc = VNDocumentCameraViewController()
        vc.delegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ vc: VNDocumentCameraViewController, context: Context) {}

    @MainActor
    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let onFinish: ([UIImage]) -> Void

        init(onFinish: @escaping ([UIImage]) -> Void) {
            self.onFinish = onFinish
        }

        func documentCameraViewController(_ c: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            onFinish((0..<min(scan.pageCount, 4)).map { scan.imageOfPage(at: $0) })
        }

        func documentCameraViewControllerDidCancel(_ c: VNDocumentCameraViewController) {
            onFinish([])
        }

        func documentCameraViewController(_ c: VNDocumentCameraViewController, didFailWithError error: Error) {
            onFinish([])
        }
    }
}

/// "Scan" (camera) plus "Choose photos" (library) — the latter also works on the simulator.
struct PagePicker: View {
    var scanLabel = "Scan with camera"
    let onPages: ([UIImage]) -> Void

    @State private var scanning = false
    @State private var picked: [PhotosPickerItem] = []

    var body: some View {
        HStack(spacing: 12) {
            if DocumentScanner.isSupported {
                Button {
                    scanning = true
                } label: {
                    Label(scanLabel, systemImage: "doc.viewfinder")
                }
                .buttonStyle(.prominentSurface)
            }
            PhotosPicker(selection: $picked, maxSelectionCount: 4, matching: .images) {
                Label("Choose photos", systemImage: "photo.on.rectangle")
            }
            .buttonStyle(SurfaceButtonStyle(prominent: !DocumentScanner.isSupported))
        }
        .fullScreenCover(isPresented: $scanning) {
            DocumentScanner { pages in
                scanning = false
                if !pages.isEmpty { onPages(pages) }
            }
            .ignoresSafeArea()
        }
        .onChange(of: picked) { _, items in
            guard !items.isEmpty else { return }
            Task {
                var pages: [UIImage] = []
                for item in items {
                    if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                        pages.append(image)
                    }
                }
                picked = []
                if !pages.isEmpty { onPages(pages) }
            }
        }
    }
}
