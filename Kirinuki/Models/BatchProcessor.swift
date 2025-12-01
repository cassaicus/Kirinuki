import Foundation
import AppKit
import CoreGraphics
import ImageIO

class BatchProcessor {
    func processImages(files: [URL], sourceFolder: URL, rects: [CropRect], progressHandler: @escaping (Double) -> Void) -> String {
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

        // Sort rects: Primary (0/Blue) first, then Secondary (1/Red)
        let sortedRects = rects.sorted { $0.colorIndex < $1.colorIndex }

        for (index, fileURL) in files.enumerated() {
            autoreleasepool {
                if let imageSource = CGImageSourceCreateWithURL(fileURL as CFURL, nil),
                   let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) {

                    let imageWidth = CGFloat(cgImage.width)
                    let imageHeight = CGFloat(cgImage.height)

                    for rectInfo in sortedRects {
                        // Calculate pixel rect
                        // rectInfo.rect is normalized (0-1)
                        // Origin is usually Top-Left in SwiftUI/Mac but CGImage might be different?
                        // CGImage coordinates: (0,0) is usually bottom-left on Mac, top-left on iOS/SwiftUI context.
                        // However, CGImage cropping usually expects top-left origin if we treat it as data.
                        // Actually, let's verify. CGImageCreateWithImageInRect: "The rectangle is specified in the image's coordinate space."
                        // Typically for image files, origin is top-left.

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

            progressHandler(Double(index + 1) / Double(files.count))
        }

        return "完了: \(globalCounter - 1)枚の画像を保存しました (失敗: \(failCount))"
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
