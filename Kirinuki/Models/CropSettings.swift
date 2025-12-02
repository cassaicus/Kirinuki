import Foundation
import CoreGraphics
internal import Combine

enum CropMode: String, CaseIterable, Identifiable {
    case single = "通常モード"
    case split = "見開きモード"

    var id: String { self.rawValue }
}

struct CropRect: Identifiable, Equatable {
    let id = UUID()
    var rect: CGRect // Normalized coordinates (0.0 - 1.0)
    var colorIndex: Int // 0 for primary (first), 1 for secondary (second)
}

class CropConfiguration: ObservableObject {
    @Published var mode: CropMode = .single

    // Rectangles for crop.
    // In single mode, use the first one.
    // In split mode, use both.
    @Published var cropRects: [CropRect] = [
        CropRect(rect: CGRect(x: 0.1, y: 0.1, width: 0.8, height: 0.8), colorIndex: 0)
    ]

    func updateMode(_ newMode: CropMode) {
        mode = newMode
        if mode == .single {
            if cropRects.isEmpty {
                 cropRects = [CropRect(rect: CGRect(x: 0.1, y: 0.1, width: 0.8, height: 0.8), colorIndex: 0)]
            } else {
                // Keep only the first one or reset if needed
                cropRects = [cropRects[0]]
            }
        } else {
            // Split mode
            if cropRects.count < 2 {
                // Add a second rect if missing
                let first = cropRects.first?.rect ?? CGRect(x: 0.05, y: 0.1, width: 0.4, height: 0.8)
                cropRects = [
                    CropRect(rect: first, colorIndex: 0), // Primary (e.g. Blue)
                    CropRect(rect: CGRect(x: 0.55, y: 0.1, width: 0.4, height: 0.8), colorIndex: 1) // Secondary (e.g. Red)
                ]
            }
        }
    }

    func alignCropRects() {
        guard mode == .split, cropRects.count >= 2 else { return }

        let rect1 = cropRects[0].rect

        // 1枠目の右隣に配置し、サイズとY座標を合わせる
        let newRect2 = CGRect(
            x: rect1.maxX,
            y: rect1.minY,
            width: rect1.width,
            height: rect1.height
        )

        // Update the second rect
        var secondCropRect = cropRects[1]
        secondCropRect.rect = newRect2
        cropRects[1] = secondCropRect
    }
}
