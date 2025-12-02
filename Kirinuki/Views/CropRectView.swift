import SwiftUI

// Rewriting ResizableRectView to be more robust with DragGesture
struct CropRectView: View {
    @Binding var normalizedRect: CGRect
    let color: Color
    let onDelete: () -> Void

    @State private var dragStartRect: CGRect? = nil

    var body: some View {
        GeometryReader { geometry in
            let parentSize = geometry.size
            let viewRect = denormalize(normalizedRect, parentSize: parentSize)

            ZStack {
                // Main Area (Move)
                Rectangle()
                    .strokeBorder(color, lineWidth: 2)
                    .background(color.opacity(0.2))
                    .frame(width: viewRect.width, height: viewRect.height)
                    .position(x: viewRect.midX, y: viewRect.midY)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                if dragStartRect == nil { dragStartRect = normalizedRect }
                                guard let start = dragStartRect else { return }

                                let dx = value.translation.width / parentSize.width
                                let dy = value.translation.height / parentSize.height

                                var newX = start.origin.x + dx
                                var newY = start.origin.y + dy

                                // Clamp to bounds (0...1) - width
                                newX = max(0, min(newX, 1.0 - start.width))
                                newY = max(0, min(newY, 1.0 - start.height))

                                normalizedRect.origin = CGPoint(x: newX, y: newY)
                            }
                            .onEnded { _ in dragStartRect = nil }
                    )

                // Handles
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

    func resizeGesture(corner: Corner, parentSize: CGSize) -> some Gesture {
        DragGesture()
            .onChanged { value in
                if dragStartRect == nil { dragStartRect = normalizedRect }
                guard let start = dragStartRect else { return }

                let dx = value.translation.width / parentSize.width
                let dy = value.translation.height / parentSize.height

                var newRect = start

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

                // Min size check (e.g. 1% of screen)
                if newRect.width < 0.01 { newRect.size.width = 0.01 }
                if newRect.height < 0.01 { newRect.size.height = 0.01 }

                // Normalize rect might need to adjust origin if width becomes negative (flip)
                // But for now let's just clamp width/height to be positive
                if newRect.width < 0 { newRect.size.width = 0.01 } // prevent flip for simplicity
                if newRect.height < 0 { newRect.size.height = 0.01 }

                normalizedRect = newRect
            }
            .onEnded { _ in dragStartRect = nil }
    }

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
