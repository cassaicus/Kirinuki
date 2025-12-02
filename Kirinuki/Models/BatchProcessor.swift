import Foundation
import AppKit
import CoreGraphics
import ImageIO

struct ExportOptions: Equatable {
    enum Format: String, CaseIterable, Identifiable {
        case jpg = "JPG"
        case png = "PNG"
        var id: String { rawValue }
    }

    enum FilenameMode: String, CaseIterable, Identifiable {
        case sequence = "Sequence Only (001...)"
        case original = "Original Filename + Sequence"
        case custom = "Custom Text + Sequence"
        case originalAndCustom = "Original + Custom + Sequence"

        var id: String { rawValue }
    }

    var format: Format = .jpg
    var filenameMode: FilenameMode = .sequence
    var customPrefix: String = ""
    var outputFolder: URL? = nil // If nil, use default "Output" subfolder
}

class BatchProcessor {
    func processPages(pages: [ImagePage], sourceFolder: URL, options: ExportOptions, progressHandler: @escaping (Double) -> Void) -> String {
        let outputFolder: URL
        if let customFolder = options.outputFolder {
            outputFolder = customFolder
        } else {
            outputFolder = sourceFolder.appendingPathComponent("Output")
        }

        // Create Output directory
        do {
            try FileManager.default.createDirectory(at: outputFolder, withIntermediateDirectories: true, attributes: nil)
        } catch {
            return "Failed to create output folder: \(error.localizedDescription)"
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
                            // Construct filename
                            let extensionStr = options.format == .jpg ? "jpg" : "png"
                            let sequenceStr = String(format: "%03d", globalCounter)
                            let fileName: String

                            let originalName = fileURL.deletingPathExtension().lastPathComponent

                            switch options.filenameMode {
                            case .sequence:
                                fileName = "\(sequenceStr).\(extensionStr)"
                            case .original:
                                fileName = "\(originalName)_\(sequenceStr).\(extensionStr)"
                            case .custom:
                                let prefix = options.customPrefix.isEmpty ? "Image" : options.customPrefix
                                fileName = "\(prefix)_\(sequenceStr).\(extensionStr)"
                            case .originalAndCustom:
                                let prefix = options.customPrefix.isEmpty ? "" : "_\(options.customPrefix)"
                                fileName = "\(originalName)\(prefix)_\(sequenceStr).\(extensionStr)"
                            }

                            let destinationURL = outputFolder.appendingPathComponent(fileName)

                            if saveImage(croppedCGImage, to: destinationURL, format: options.format) {
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

        return "Completed: \(globalCounter - 1) images saved (Failed: \(failCount))"
    }

    private func saveImage(_ cgImage: CGImage, to url: URL, format: ExportOptions.Format) -> Bool {
        let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
        let fileType: NSBitmapImageRep.FileType = (format == .jpg) ? .jpeg : .png
        let properties: [NSBitmapImageRep.PropertyKey: Any]

        if format == .jpg {
            properties = [.compressionFactor: 0.9]
        } else {
            properties = [:]
        }

        guard let data = bitmapRep.representation(using: fileType, properties: properties) else {
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
