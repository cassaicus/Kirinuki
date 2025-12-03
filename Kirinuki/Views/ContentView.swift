import SwiftUI

struct ContentView: View {
    @StateObject private var imageManager = ImageManager()
    @State private var isExporting = false
    @State private var exportMessage = ""

    // 【解説: Local State Strategy の導入】
    // "Publishing changes from within view updates is not allowed" エラーを回避するための重要な修正です。
    //
    // 問題の原因:
    // SwiftUI の List は selection バインディングを通じて選択状態を管理します。
    // これを直接 `@StateObject` である `imageManager.selectedPageId` にバインドすると、以下のサイクルが発生していました:
    // 1. ユーザーがリストを選択 -> List 内部で selection を更新。
    // 2. バインディング経由で imageManager.selectedPageId が更新される。
    // 3. imageManager は ObservableObject なので objectWillChange を発行。
    // 4. ContentView は imageManager を監視しているため再描画がトリガーされる。
    // 5. しかし、この時点で List はまだ自身の更新処理（View Updates）の最中である可能性がある。
    // 6. 結果、「Viewの更新中に他のViewの状態を書き換えた」と判定され、ランタイムエラーが発生する。
    //
    // 解決策 (Local State Strategy):
    // List の selection を View 内部のローカルな `@State` (localSelectedId) にバインドします。
    // これにより、List の直接的な更新先は軽量なローカル変数となり、`imageManager` への影響を遮断します。
    // その後、`onChange` 修飾子を使って、タイミングをずらして（または監視サイクルを分けて） `imageManager` と同期します。
    @State private var localSelectedId: UUID?

    var body: some View {
        NavigationSplitView {
            // Sidebar: Image List
            VStack {
                if imageManager.pages.isEmpty {
                    Text("Please select a folder")
                        .foregroundColor(.gray)
                        .padding()
                }

                ScrollViewReader { proxy in
                    // 【解説】 List の selection には $imageManager.selectedPageId ではなく $localSelectedId を使用
                    List(imageManager.pages, selection: $localSelectedId) { page in
                        VStack {
                            AsyncImage(url: page.url) { image in
                                image.resizable()
                                     .aspectRatio(contentMode: .fit)
                            } placeholder: {
                                ProgressView()
                                    .frame(width: 50, height: 50)
                            }
                            .frame(width: 100, height: 100)

                            Text(page.url.lastPathComponent)
                                .font(.caption)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity) // Center in list item
                        .tag(page.id)
                        .id(page.id) // Verify if tag is enough or explicit id needed for scrollTo
                    }
                    .navigationSplitViewColumnWidth(min: 180, ideal: 250)
                    // 【解説: 同期処理 1 - ローカルからマネージャーへ】
                    // localSelectedId が変更されたら、それを imageManager に反映させます。
                    // onChange は View の更新がひと段落した後に呼ばれるため、安全に StateObject を更新できます。
                    .onChange(of: localSelectedId) { oldValue, newValue in
                        if imageManager.selectedPageId != newValue {
                            imageManager.selectedPageId = newValue
                        }

                        if let id = newValue {
                             withAnimation {
                                 proxy.scrollTo(id, anchor: .center)
                             }
                        }
                    }
                    // 【解説: 同期処理 2 - マネージャーからローカルへ】
                    // 逆に、プログラム等で imageManager.selectedPageId が変更された場合もローカルに反映させます。
                    // これで双方向の同期が保たれます。無限ループを防ぐため、値が違う場合のみ代入します。
                    .onChange(of: imageManager.selectedPageId) { oldValue, newValue in
                         if localSelectedId != newValue {
                             localSelectedId = newValue
                         }
                    }
                }
            }
            .toolbar {
                 ToolbarItem(placement: .primaryAction) {
                     Button(action: {
                         imageManager.selectFolder()
                     }) {
                         Label("Open Folder", systemImage: "folder")
                     }
                 }
            }
        } detail: {
            // Center: Image Viewer
            if let selectedId = imageManager.selectedPageId,
               let index = imageManager.pages.firstIndex(where: { $0.id == selectedId }) {

                // We access the binding to the specific page in the array
                ImageViewer(
                    imageUrl: imageManager.pages[index].url,
                    cropState: $imageManager.pages[index].cropState,
                    imageManager: imageManager
                )
                .focusable() // Allow focus to receive keyboard events if clicked
                .onMoveCommand { direction in
                    // Support standard move commands (usually Arrow keys in some contexts)
                    // If a crop rect is selected, move it. Otherwise do nothing (let sidebar handle nav if possible,
                    // but sidebar isn't focused here. User requested arrows move rect if selected.)

                    if let selectedId = imageManager.selectedCropId {
                        moveSelectedCropRect(direction: direction, pageIndex: index, cropId: selectedId)
                    } else {
                        // If no crop selected, maybe navigate? User asked "Can we make Previous/Next image only inside the Split View?"
                        // So we do NOTHING here for navigation.
                    }
                }
            } else {
                Text("Please select an image")
                    .font(.largeTitle)
                    .foregroundColor(.gray)
            }
        }
        .inspector(isPresented: .constant(true)) {
            // Right: Inspector
            if let selectedId = imageManager.selectedPageId,
               let index = imageManager.pages.firstIndex(where: { $0.id == selectedId }) {

                CropInspectorView(
                    cropState: $imageManager.pages[index].cropState,
                    imageManager: imageManager,
                    selectedPageId: selectedId,
                    onExport: startExport
                )
            } else {
                // Empty state or folder selection hint
                VStack {
                    Text("Please select a folder and choose an image")
                        .padding()
                    Button("Open Folder") {
                        imageManager.selectFolder()
                    }
                }
            }
        }
        .alert(isPresented: $isExporting) {
            Alert(title: Text("Processing Complete"), message: Text(exportMessage), dismissButton: .default(Text("OK")))
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("OpenFolderCommand"))) { _ in
            imageManager.selectFolder()
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("ExportCommand"))) { _ in
            startExport()
        }
    }

    func moveSelectedCropRect(direction: MoveCommandDirection, pageIndex: Int, cropId: UUID) {
        guard let rectIndex = imageManager.pages[pageIndex].cropState.cropRects.firstIndex(where: { $0.id == cropId }) else { return }

        var rect = imageManager.pages[pageIndex].cropState.cropRects[rectIndex].rect
        let imageSize = imageManager.currentImageSize
        guard imageSize.width > 0, imageSize.height > 0 else { return }

        // Move by 1 pixel (or larger step with modifiers? keeping simple for now)
        let dx = 1.0 / imageSize.width
        let dy = 1.0 / imageSize.height

        switch direction {
        case .up:    rect.origin.y -= dy
        case .down:  rect.origin.y += dy
        case .left:  rect.origin.x -= dx
        case .right: rect.origin.x += dx
        default: break
        }

        imageManager.pages[pageIndex].cropState.cropRects[rectIndex].rect = rect
    }

    func startExport() {
        guard let sourceFolder = imageManager.sourceFolder else { return }

        imageManager.isProcessing = true
        imageManager.processingProgress = 0.0

        let pagesToProcess = imageManager.pages
        let options = imageManager.exportOptions

        DispatchQueue.global(qos: .userInitiated).async {
            let processor = BatchProcessor()
            let result = processor.processPages(
                pages: pagesToProcess,
                sourceFolder: sourceFolder,
                options: options,
                progressHandler: { progress in
                    DispatchQueue.main.async {
                        imageManager.processingProgress = progress
                    }
                }
            )

            DispatchQueue.main.async {
                imageManager.isProcessing = false
                exportMessage = result
                isExporting = true
            }
        }
    }
}
