import SwiftUI

struct ImageViewer: View {
    let image: NSImage?
    @Binding var cropState: PageCropState
    @ObservedObject var imageManager: ImageManager

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.gray.opacity(0.1) // Background
                    .onTapGesture {
                        // Deselect if background clicked
                        imageManager.selectedCropId = nil
                    }

                if let image = image {
                    let imageRect = calculateImageRect(containerSize: geometry.size, imageSize: image.size)

                    // Render Image
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                        .onAppear {
                            imageManager.currentImageSize = image.size
                        }
                        .onChange(of: image) { _, newImage in
                            imageManager.currentImageSize = newImage?.size ?? .zero
                        }

                    // Render Crop Rects relative to the image frame
                    ZStack {
                        ForEach($cropState.cropRects) { $cropRect in
                            CropRectView(
                                normalizedRect: $cropRect.rect,
                                color: cropRect.colorIndex == 0 ? .blue : .red,
                                isSelected: imageManager.selectedCropId == cropRect.id,
                                onSelect: {
                                    imageManager.selectedCropId = cropRect.id
                                },
                                onDelete: {
                                    cropState.removeRect(id: cropRect.id)
                                    if imageManager.selectedCropId == cropRect.id {
                                        imageManager.selectedCropId = nil
                                    }
                                }
                            )
                        }
                    }
                    .frame(width: imageRect.width, height: imageRect.height)
                    .position(x: imageRect.midX, y: imageRect.midY)
                    .clipShape(Rectangle()) // Clip so rects don't fly out too wildly (optional)

                } else {
                    VStack {
                        Image(systemName: "photo")
                            .font(.largeTitle)
                        Text("画像を選択してください")
                    }
                    .foregroundColor(.gray)
                }
            }
        }
    }

    private func calculateImageRect(containerSize: CGSize, imageSize: CGSize) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0 else { return .zero }

        let widthRatio = containerSize.width / imageSize.width
        let heightRatio = containerSize.height / imageSize.height
        let ratio = min(widthRatio, heightRatio)

        let newWidth = imageSize.width * ratio
        let newHeight = imageSize.height * ratio

        let x = (containerSize.width - newWidth) / 2
        let y = (containerSize.height - newHeight) / 2

        return CGRect(x: x, y: y, width: newWidth, height: newHeight)
    }
}
