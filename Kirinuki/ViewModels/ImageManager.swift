import Foundation
import AppKit
internal import Combine

struct ImagePage: Identifiable, Equatable {
    let id = UUID()
    let url: URL
    var cropState: PageCropState

    // Equatable conformance
    static func == (lhs: ImagePage, rhs: ImagePage) -> Bool {
        return lhs.id == rhs.id && lhs.cropState == rhs.cropState
    }
}

class ImageManager: ObservableObject {
    @Published var sourceFolder: URL?
    @Published var pages: [ImagePage] = []
    @Published var selectedPageId: UUID?

    // Cached preview for the *selected* image to avoid loading everything at once?
    // Or we can let the View load async. For the thumbnails, we might want a lightweight solution.
    // For now, we will rely on AsyncImage in the view.

    @Published var previewImage: NSImage? // Kept for backward compatibility or main viewer optimization if needed

    @Published var isProcessing: Bool = false
    @Published var processingProgress: Double = 0.0
    @Published var statusMessage: String = "Please select a folder"
    @Published var exportOptions = ExportOptions()

    // Selection state for crop frames
    @Published var selectedCropId: UUID?
    @Published var currentImageSize: CGSize = .zero

    func selectFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false

        if panel.runModal() == .OK {
            if let url = panel.url {
                self.sourceFolder = url
                loadImages(from: url)
            }
        }
    }

    func loadImages(from folder: URL) {
        let fileManager = FileManager.default
        do {
            let fileURLs = try fileManager.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)

            // Filter for image files (JPG, PNG for now)
            let imageExtensions = ["jpg", "jpeg", "png", "webp"]
            let sortedURLs = fileURLs.filter { url in
                imageExtensions.contains(url.pathExtension.lowercased())
            }.sorted { $0.lastPathComponent < $1.lastPathComponent }

            // Create default crop state
            let defaultState = PageCropState()

            self.pages = sortedURLs.map { url in
                ImagePage(url: url, cropState: defaultState)
            }

            if let firstPage = pages.first {
                self.selectedPageId = firstPage.id
                self.statusMessage = "\(pages.count) images loaded"
            } else {
                self.selectedPageId = nil
                self.statusMessage = "No image files found"
            }
        } catch {
            self.statusMessage = "Error: \(error.localizedDescription)"
        }
    }

    func applySettingsToAll(from sourcePageId: UUID) {
        guard let sourceIndex = pages.firstIndex(where: { $0.id == sourcePageId }) else { return }
        let sourceState = pages[sourceIndex].cropState

        for i in 0..<pages.count {
            pages[i].cropState = sourceState
        }
    }

    func selectNext() {
        guard let current = selectedPageId, let index = pages.firstIndex(where: { $0.id == current }) else { return }
        if index < pages.count - 1 {
            selectedPageId = pages[index + 1].id
        }
    }

    func selectPrevious() {
        guard let current = selectedPageId, let index = pages.firstIndex(where: { $0.id == current }) else { return }
        if index > 0 {
            selectedPageId = pages[index - 1].id
        }
    }
}
