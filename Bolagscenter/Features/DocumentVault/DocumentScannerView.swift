import SwiftUI
import VisionKit

struct DocumentScannerSession: Identifiable {
    let id = UUID()
}

@MainActor
struct DocumentScannerView: UIViewControllerRepresentable {
    let onComplete: @MainActor ([Data]) -> Void
    let onCancel: @MainActor () -> Void
    let onError: @MainActor (Error) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(
            onComplete: onComplete,
            onCancel: onCancel,
            onError: onError
        )
    }

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let controller = VNDocumentCameraViewController()
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(
        _ uiViewController: VNDocumentCameraViewController,
        context: Context
    ) {}

    @MainActor
    final class Coordinator: NSObject, @preconcurrency VNDocumentCameraViewControllerDelegate {
        private let onComplete: @MainActor ([Data]) -> Void
        private let onCancel: @MainActor () -> Void
        private let onError: @MainActor (Error) -> Void

        init(
            onComplete: @escaping @MainActor ([Data]) -> Void,
            onCancel: @escaping @MainActor () -> Void,
            onError: @escaping @MainActor (Error) -> Void
        ) {
            self.onComplete = onComplete
            self.onCancel = onCancel
            self.onError = onError
        }

        func documentCameraViewController(
            _ controller: VNDocumentCameraViewController,
            didFinishWith scan: VNDocumentCameraScan
        ) {
            let pages = (0..<scan.pageCount).compactMap { index in
                scan.imageOfPage(at: index).jpegData(compressionQuality: 0.94)
            }
            controller.dismiss(animated: true)
            onComplete(pages)
        }

        func documentCameraViewControllerDidCancel(
            _ controller: VNDocumentCameraViewController
        ) {
            controller.dismiss(animated: true)
            onCancel()
        }

        func documentCameraViewController(
            _ controller: VNDocumentCameraViewController,
            didFailWithError error: Error
        ) {
            controller.dismiss(animated: true)
            onError(error)
        }
    }
}
