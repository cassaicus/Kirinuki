import SwiftUI

struct ContentView: View {
    @StateObject private var imageManager = ImageManager()
    @State private var isExporting = false
    @State private var exportMessage = ""

    var body: some View {
        NavigationSplitView {
            // Sidebar: Image List
            VStack {
                if imageManager.pages.isEmpty {
                    Text("フォルダを選択してください")
                        .foregroundColor(.gray)
                        .padding()
                }

                ScrollViewReader { proxy in
                    List(imageManager.pages, selection: $imageManager.selectedPageId) { page in
                        HStack {
                            AsyncImage(url: page.url) { image in
                                image.resizable()
                                     .aspectRatio(contentMode: .fit)
                            } placeholder: {
                                ProgressView()
                                    .frame(width: 50, height: 50)
                            }
                            .frame(width: 80, height: 80)

                            Text(page.url.lastPathComponent)
                                .font(.caption)
                                .lineLimit(1)
                        }
                        .tag(page.id)
                        .id(page.id) // Verify if tag is enough or explicit id needed for scrollTo
                    }
                    .navigationSplitViewColumnWidth(min: 180, ideal: 250)
                    .onChange(of: imageManager.selectedPageId) {oldValue, newValue in
                         if let id = newValue {
                             withAnimation {
                                 proxy.scrollTo(id, anchor: .center)
                             }
                         }
                    }
                }
            }
            .toolbar {
                 ToolbarItem(placement: .primaryAction) {
                     Button(action: {
                         imageManager.selectFolder()
                     }) {
                         Label("フォルダを開く", systemImage: "folder")
                     }
                 }
            }
        } detail: {
            // Center: Image Viewer
            if let selectedId = imageManager.selectedPageId,
               let index = imageManager.pages.firstIndex(where: { $0.id == selectedId }) {

                // We access the binding to the specific page in the array
                ImageViewer(
                    image: NSImage(contentsOf: imageManager.pages[index].url),
                    cropState: $imageManager.pages[index].cropState
                )
                .focusable() // Allow focus to receive keyboard events if clicked
                .onMoveCommand { direction in
                    // Support standard move commands (usually Arrow keys in some contexts)
                    switch direction {
                    case .up: imageManager.selectPrevious()
                    case .down: imageManager.selectNext()
                    default: break
                    }
                }
            } else {
                Text("画像を選択してください")
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
                    Text("フォルダを選択して画像を選んでください")
                        .padding()
                    Button("フォルダを開く") {
                        imageManager.selectFolder()
                    }
                }
            }
        }
        .alert(isPresented: $isExporting) {
            Alert(title: Text("処理完了"), message: Text(exportMessage), dismissButton: .default(Text("OK")))
        }
    }

    func startExport() {
        guard let sourceFolder = imageManager.sourceFolder else { return }

        imageManager.isProcessing = true
        imageManager.processingProgress = 0.0

        let pagesToProcess = imageManager.pages

        DispatchQueue.global(qos: .userInitiated).async {
            let processor = BatchProcessor()
            let result = processor.processPages(
                pages: pagesToProcess,
                sourceFolder: sourceFolder,
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

#Preview {
    ContentView()
}
