import Foundation
import AppKit
import CoreGraphics
import ImageIO

class BatchProcessor {
    // Old method for backward compatibility if needed, but we can just remove it or ignore it.
    // New method:
    func processPages(pages: [ImagePage], sourceFolder: URL, progressHandler: @escaping (Double) -> Void) -> String {
        let outputFolder = sourceFolder.appendingPathComponent("Output")

        // Create Output directory
        do {
            try FileManager.default.createDirectory(at: outputFolder, withIntermediateDirectories: true, attributes: nil)
        } catch {
            return "出力フォルダの作成に失敗しました: \(error.localizedDescription)"
        }

        var successCount = 0
        var failCount = 0
        var globalCounter = 1

        for (index, page) in pages.enumerated() {
            let fileURL = page.url
            let cropState = page.cropState
            let rects = cropState.cropRects

            // Sort rects: Primary (0/Blue) first, then Secondary (1/Red)
            let sortedRects = rects.sorted { $0.colorIndex < $1.colorIndex }

            autoreleasepool {
                if let imageSource = CGImageSourceCreateWithURL(fileURL as CFURL, nil),
                   let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) {

                    let imageWidth = CGFloat(cgImage.width)
                    let imageHeight = CGFloat(cgImage.height)

                    for rectInfo in sortedRects {
                        let x = rectInfo.rect.origin.x * imageWidth
                        let y = rectInfo.rect.origin.y * imageHeight
                        let w = rectInfo.rect.width * imageWidth
                        let h = rectInfo.rect.height * imageHeight

                        let cropRect = CGRect(x: x, y: y, width: w, height: h)

                        if let croppedCGImage = cgImage.cropping(to: cropRect) {
                            // Save
                            let fileName = String(format: "%03d.jpg", globalCounter)
                            let destinationURL = outputFolder.appendingPathComponent(fileName)

                            if saveImage(croppedCGImage, to: destinationURL) {
                                globalCounter += 1
                            } else {
                                failCount += 1
                            }
                        } else {
                            failCount += 1
                        }
                    }
                    successCount += 1
                } else {
                    failCount += 1
                }
            }

            progressHandler(Double(index + 1) / Double(pages.count))
        }

        return "完了: \(globalCounter - 1)枚の画像を保存しました (失敗: \(failCount))"
    }

    // Legacy support to match old signature if needed by tests, but we are replacing usage.
    func processImages(files: [URL], sourceFolder: URL, rects: [CropRect], progressHandler: @escaping (Double) -> Void) -> String {
        // This logic is now flawed because we want per-page settings.
        // However, we can keep it for single-setting batch if ever needed, but for now we won't use it.
        return "Deprecated"
    }

    private func saveImage(_ cgImage: CGImage, to url: URL) -> Bool {
        let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
        guard let data = bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: 0.9]) else {
            return false
        }

        do {
            try data.write(to: url)
            return true
        } catch {
            print("Failed to save image: \(error)")
            return false
        }
    }
}
