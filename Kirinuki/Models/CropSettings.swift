import Foundation
import CoreGraphics

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

struct PageCropState: Equatable {
    var mode: CropMode = .single
    var cropRects: [CropRect] = [
        CropRect(rect: CGRect(x: 0.1, y: 0.1, width: 0.8, height: 0.8), colorIndex: 0)
    ]

    mutating func updateMode(_ newMode: CropMode) {
        mode = newMode
        if mode == .single {
            if cropRects.isEmpty {
                 cropRects = [CropRect(rect: CGRect(x: 0.1, y: 0.1, width: 0.8, height: 0.8), colorIndex: 0)]
            } else {
                // Keep only the first one or reset if needed
                // If we have existing rects, keep the first one (colorIndex 0)
                if let first = cropRects.first(where: { $0.colorIndex == 0 }) {
                    cropRects = [first]
                } else if let firstAny = cropRects.first {
                    var newFirst = firstAny
                    newFirst.colorIndex = 0
                    cropRects = [newFirst]
                } else {
                    cropRects = [CropRect(rect: CGRect(x: 0.1, y: 0.1, width: 0.8, height: 0.8), colorIndex: 0)]
                }
            }
        } else {
            // Split mode
            // Ensure we have at least two rects
            let primary = cropRects.first(where: { $0.colorIndex == 0 })
            let secondary = cropRects.first(where: { $0.colorIndex == 1 })

            var newRects: [CropRect] = []

            // Primary
            if let p = primary {
                newRects.append(p)
            } else {
                newRects.append(CropRect(rect: CGRect(x: 0.05, y: 0.1, width: 0.4, height: 0.8), colorIndex: 0))
            }

            // Secondary
            if let s = secondary {
                newRects.append(s)
            } else {
                // Default secondary relative to primary or default position
                let pRect = newRects[0].rect
                // Avoid overlapping perfectly if creating from scratch, place it to the right if space allows
                let sRect = CGRect(x: 0.55, y: 0.1, width: 0.4, height: 0.8)
                newRects.append(CropRect(rect: sRect, colorIndex: 1))
            }

            cropRects = newRects
        }
    }

    mutating func alignCropRects(toRight: Bool) {
        guard mode == .split else { return }

        // Find primary and secondary
        guard let pIndex = cropRects.firstIndex(where: { $0.colorIndex == 0 }),
              let sIndex = cropRects.firstIndex(where: { $0.colorIndex == 1 }) else {
            return
        }

        let rect1 = cropRects[pIndex].rect

        // 1枠目の隣（右または左）に配置し、サイズとY座標を合わせる
        let newX = toRight ? rect1.maxX : (rect1.minX - rect1.width)

        var newRect2 = cropRects[sIndex]
        newRect2.rect = CGRect(
            x: newX,
            y: rect1.minY,
            width: rect1.width,
            height: rect1.height
        )

        cropRects[sIndex] = newRect2
    }
}
