import Foundation
import AppKit
internal import Combine

class ImageManager: ObservableObject {
    @Published var sourceFolder: URL?
    @Published var imageFiles: [URL] = []
    @Published var previewImage: NSImage?
    @Published var isProcessing: Bool = false
    @Published var processingProgress: Double = 0.0
    @Published var statusMessage: String = "フォルダを選択してください"

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
            self.imageFiles = fileURLs.filter { url in
                imageExtensions.contains(url.pathExtension.lowercased())
            }.sorted { $0.lastPathComponent < $1.lastPathComponent }

            if let firstImage = imageFiles.first {
                self.previewImage = NSImage(contentsOf: firstImage)
                self.statusMessage = "\(imageFiles.count)枚の画像を読み込みました"
            } else {
                self.previewImage = nil
                self.statusMessage = "画像ファイルが見つかりませんでした"
            }
        } catch {
            self.statusMessage = "エラー: \(error.localizedDescription)"
        }
    }
}
