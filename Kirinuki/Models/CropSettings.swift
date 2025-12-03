import Foundation
import CoreGraphics

// 【解説】 CropMode
// クロップ処理のモード定義です。
// Single: 1枚の画像から1つの領域を切り抜く
// Split: 1枚の画像（例：見開きページ）から2つの領域（左右）を切り抜く
enum CropMode: String, CaseIterable, Identifiable {
    case single = "Single"
    case split = "Split"

    var id: String { self.rawValue }
}

// 【解説】 CropRect
// 個別のクロップ枠を表すデータモデルです。
// rect: 画像に対する正規化座標 (0.0 - 1.0) で位置とサイズを保持します。
// colorIndex: 枠の色や役割（1枚目、2枚目）を識別します。
struct CropRect: Identifiable, Equatable {
    let id = UUID()
    var rect: CGRect // Normalized coordinates (0.0 - 1.0)
    var colorIndex: Int // 0 for primary (first), 1 for secondary (second)
}

// 【解説】 PageCropState
// 1ページあたりのクロップ設定全体を管理する構造体です。
// モードと、そのモードに含まれるクロップ枠のリストを持ちます。
// Equatable に準拠することで、SwiftUI が変更を検知して効率的にビューを更新できるようにしています。
struct PageCropState: Equatable {
    var mode: CropMode = .single
    var cropRects: [CropRect] = [
        CropRect(rect: CGRect(x: 0.1, y: 0.1, width: 0.8, height: 0.8), colorIndex: 0)
    ]

    // モード変更時のロジックです。
    // Single <-> Split 切り替え時に、適切なデフォルト枠を生成または削減します。
    // mutating キーワードが付いているのは、構造体自身のプロパティを変更するためです。
    // UI から呼び出される際（CropInspectorView）は、DispatchQueue.main.async 内で行われることが多いです。
    mutating func updateMode(_ newMode: CropMode) {
        mode = newMode
        // When switching modes, we try to preserve existing rects if valid, or reset.
        // However, we now allow 0 rects, so we shouldn't force creation unless it's a fresh init or user request.
        // Actually, the user experience usually expects default rects when switching modes if none exist.

        if mode == .single {
            // Ensure at most 1 rect (Primary).
            // If we have a primary, keep it. If not, but we have others, convert one.
            // If we have none, we might want to add one default?
            // Let's stick to: Ensure Primary exists if we want "default" behavior, but allow deletion.
            // For mode switching, let's reset to a good state.

            let primary = cropRects.first(where: { $0.colorIndex == 0 })
            if let p = primary {
                cropRects = [p]
            } else {
                 // If no primary, create default
                 cropRects = [CropRect(rect: CGRect(x: 0.1, y: 0.1, width: 0.8, height: 0.8), colorIndex: 0)]
            }
        } else {
            // Split mode
            // Ensure Primary and Secondary exist.
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
                let sRect = CGRect(x: 0.55, y: 0.1, width: 0.4, height: 0.8)
                newRects.append(CropRect(rect: sRect, colorIndex: 1))
            }

            cropRects = newRects
        }
    }

    mutating func addRect(colorIndex: Int) {
        // Prevent duplicate colorIndex
        if cropRects.contains(where: { $0.colorIndex == colorIndex }) { return }

        let defaultRect: CGRect
        if colorIndex == 0 {
             defaultRect = CGRect(x: 0.05, y: 0.1, width: 0.4, height: 0.8)
        } else {
             defaultRect = CGRect(x: 0.55, y: 0.1, width: 0.4, height: 0.8)
        }

        cropRects.append(CropRect(rect: defaultRect, colorIndex: colorIndex))
    }

    mutating func removeRect(id: UUID) {
        cropRects.removeAll { $0.id == id }
    }

    // Splitモードにおいて、2つの枠を左右に整列させる便利機能です。
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
