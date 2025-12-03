import SwiftUI

struct ImageViewer: View {
    let imageUrl: URL
    @State private var image: NSImage?
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
                                    let idToDelete = cropRect.id
                                    cropState.removeRect(id: idToDelete)
                                    if imageManager.selectedCropId == idToDelete {
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
                        Text("Loading...")
                    }
                    .foregroundColor(.gray)
                }
            }
        }
        // 【解説: 非同期読み込みと状態更新の分離】
        // .task 修飾子を使って画像の読み込みを行います。
        // id: imageUrl を指定することで、URLが変わるたびにタスクが再実行されます。
        .task(id: imageUrl) {
            // 1. 画像の読み込み (Background Thread)
            // Task.detached を使用して、Main Actor とは別のスレッド（バックグラウンド）で重い処理を実行します。
            // NSImage(contentsOf:) は同期処理であり、メインスレッドで行うとUIがフリーズする原因になります。
            let loaded = await Task.detached(priority: .userInitiated) {
                return NSImage(contentsOf: imageUrl)
            }.value

            // 2. キャンセルチェック
            // 読み込み中にユーザーが次の画像へ移動した場合、このタスクはキャンセルされます。
            // 完了後に Task.isCancelled をチェックすることで、古い画像が表示されるのを防ぎます。
            if Task.isCancelled { return }

            if let image = loaded {
                // 3. UI更新 (Main Actor)
                // View のローカル State (self.image) の更新はメインスレッドで行われます（.task 内は MainActor コンテキスト）。
                self.image = image

                // 4. 外部 State の更新 (DispatchQueue.main.async)
                // imageManager.currentImageSize (@Published) を更新すると、親の ContentView も再描画されます。
                // これを同期的に行うと、まだ ImageViewer の描画サイクル中であるため、
                // "Publishing changes from within view updates" エラーが発生する可能性があります。
                // DispatchQueue.main.async でラップすることで、更新を次のランループまで遅延させ、現在の描画サイクルを安全に終了させます。

                // また、無駄な更新を防ぐために、値が実際に変わった場合のみ更新します。
                if imageManager.currentImageSize != image.size {
                    DispatchQueue.main.async {
                        imageManager.currentImageSize = image.size
                    }
                }
            } else {
                self.image = nil
                // 読み込み失敗時も同様に、currentImageSize を安全にリセットします。
                if imageManager.currentImageSize != .zero {
                    DispatchQueue.main.async {
                        imageManager.currentImageSize = .zero
                    }
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
