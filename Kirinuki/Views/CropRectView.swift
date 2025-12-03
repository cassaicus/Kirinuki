import SwiftUI

// 【解説】 CropRectView
// 個別のクロップ枠を表示・操作するためのViewです。
// normalizedRect は 0.0-1.0 の正規化座標で管理されており、
// 表示時に GeometryReader で取得した親サイズ（parentSize）を使ってピクセル座標に変換（denormalize）します。
struct CropRectView: View {
    @Binding var normalizedRect: CGRect
    let color: Color
    let isSelected: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void

    // ドラッグ操作中の開始状態を保持します。
    @State private var dragStartRect: CGRect? = nil

    var body: some View {
        GeometryReader { geometry in
            let parentSize = geometry.size
            let viewRect = denormalize(normalizedRect, parentSize: parentSize)

            ZStack {
                // Main Area (Move)
                // 枠自体をドラッグして移動させます。
                Rectangle()
                    .strokeBorder(color, lineWidth: isSelected ? 4 : 2)
                    .background(color.opacity(0.2))
                    .frame(width: viewRect.width, height: viewRect.height)
                    .position(x: viewRect.midX, y: viewRect.midY)
                    .onTapGesture {
                        onSelect()
                    }
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                if dragStartRect == nil { dragStartRect = normalizedRect }
                                guard let start = dragStartRect else { return }

                                // 移動量を正規化座標に変換
                                let dx = value.translation.width / parentSize.width
                                let dy = value.translation.height / parentSize.height

                                var newX = start.origin.x + dx
                                var newY = start.origin.y + dy

                                // 画面外にはみ出さないようにクランプ (0...1)
                                newX = max(0, min(newX, 1.0 - start.width))
                                newY = max(0, min(newY, 1.0 - start.height))

                                normalizedRect.origin = CGPoint(x: newX, y: newY)
                            }
                            .onEnded { _ in dragStartRect = nil }
                    )

                // Handles (Resize)
                // 四隅にリサイズ用のハンドル（白い円）を配置します。

                // Top-Left
                HandleView()
                    .position(x: viewRect.minX, y: viewRect.minY)
                    .gesture(resizeGesture(corner: .topLeft, parentSize: parentSize))

                // Top-Right
                HandleView()
                    .position(x: viewRect.maxX, y: viewRect.minY)
                    .gesture(resizeGesture(corner: .topRight, parentSize: parentSize))

                // Bottom-Left
                HandleView()
                    .position(x: viewRect.minX, y: viewRect.maxY)
                    .gesture(resizeGesture(corner: .bottomLeft, parentSize: parentSize))

                // Bottom-Right
                HandleView()
                    .position(x: viewRect.maxX, y: viewRect.maxY)
                    .gesture(resizeGesture(corner: .bottomRight, parentSize: parentSize))

                // Delete Button (X) - Top Right Corner of the rect
                Button(action: onDelete) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.white)
                        .background(Circle().fill(Color.black.opacity(0.6)))
                }
                .position(x: viewRect.maxX, y: viewRect.minY)
                .offset(x: 10, y: -10) // Slight offset outside
            }
        }
    }

    enum Corner { case topLeft, topRight, bottomLeft, bottomRight }

    // リサイズ用のジェスチャーロジック
    // ドラッグ量に応じて正規化座標を更新します。
    func resizeGesture(corner: Corner, parentSize: CGSize) -> some Gesture {
        DragGesture()
            .onChanged { value in
                if dragStartRect == nil { dragStartRect = normalizedRect }
                guard let start = dragStartRect else { return }

                let dx = value.translation.width / parentSize.width
                let dy = value.translation.height / parentSize.height

                var newRect = start

                // コーナーに応じて origin と size を同時に調整
                switch corner {
                case .topLeft:
                    newRect.origin.x += dx
                    newRect.origin.y += dy
                    newRect.size.width -= dx
                    newRect.size.height -= dy
                case .topRight:
                    newRect.origin.y += dy
                    newRect.size.width += dx
                    newRect.size.height -= dy
                case .bottomLeft:
                    newRect.origin.x += dx
                    newRect.size.width -= dx
                    newRect.size.height += dy
                case .bottomRight:
                    newRect.size.width += dx
                    newRect.size.height += dy
                }

                // 最小サイズの制限 (画面の1%)
                if newRect.width < 0.01 { newRect.size.width = 0.01 }
                if newRect.height < 0.01 { newRect.size.height = 0.01 }

                // 負のサイズにならないようにクランプ
                if newRect.width < 0 { newRect.size.width = 0.01 }
                if newRect.height < 0 { newRect.size.height = 0.01 }

                normalizedRect = newRect
            }
            .onEnded { _ in dragStartRect = nil }
    }

    // 正規化座標(0-1)をピクセル座標に変換するヘルパー関数
    func denormalize(_ rect: CGRect, parentSize: CGSize) -> CGRect {
        return CGRect(
            x: rect.origin.x * parentSize.width,
            y: rect.origin.y * parentSize.height,
            width: rect.width * parentSize.width,
            height: rect.height * parentSize.height
        )
    }
}

struct HandleView: View {
    var body: some View {
        Circle()
            .fill(Color.white)
            .frame(width: 12, height: 12)
            .shadow(radius: 2)
    }
}
