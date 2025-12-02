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
                    Text("Please select a folder")
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
                    image: NSImage(contentsOf: imageManager.pages[index].url),
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

#Preview {
    ContentView()
}
