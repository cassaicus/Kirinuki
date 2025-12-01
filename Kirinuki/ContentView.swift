import SwiftUI

struct ContentView: View {
    @StateObject private var imageManager = ImageManager()
    @StateObject private var cropConfiguration = CropConfiguration()
    @State private var isExporting = false
    @State private var exportMessage = ""

    var body: some View {
        HSplitView {
            // Sidebar / Control Panel
            VStack(alignment: .leading, spacing: 20) {
                Group {
                    Text("Kirinuki")
                        .font(.largeTitle)
                        .bold()

                    Divider()

                    Text("1. フォルダ選択")
                        .font(.headline)
                    Button(action: {
                        imageManager.selectFolder()
                    }) {
                        Label("フォルダを開く", systemImage: "folder")
                    }
                    Text(imageManager.statusMessage)
                        .font(.caption)
                        .foregroundColor(.gray)
                }

                Divider()

                Group {
                    Text("2. モード選択")
                        .font(.headline)
                    Picker("モード", selection: $cropConfiguration.mode) {
                        ForEach(CropMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .onChange(of: cropConfiguration.mode) { newValue in
                        cropConfiguration.updateMode(newValue)
                    }

                    if cropConfiguration.mode == .split {
                        VStack(alignment: .leading) {
                            HStack {
                                Circle().fill(Color.blue).frame(width: 10, height: 10)
                                Text("1枚目 (若い番号)")
                            }
                            HStack {
                                Circle().fill(Color.red).frame(width: 10, height: 10)
                                Text("2枚目 (次の番号)")
                            }
                        }
                        .font(.caption)
                    }
                }

                Divider()

                Group {
                    Text("3. 実行")
                        .font(.headline)
                    Button(action: {
                        startExport()
                    }) {
                        Label("切り出し実行", systemImage: "scissors")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(imageManager.imageFiles.isEmpty || imageManager.isProcessing)

                    if imageManager.isProcessing {
                        ProgressView(value: imageManager.processingProgress)
                        Text("処理中... \(Int(imageManager.processingProgress * 100))%")
                            .font(.caption)
                    }
                }

                Spacer()
            }
            .padding()
            .frame(minWidth: 250, maxWidth: 300)

            // Main Content
            ImageViewer(image: imageManager.previewImage, cropConfiguration: cropConfiguration)
                .frame(minWidth: 500, minHeight: 400)
        }
        .frame(minWidth: 800, minHeight: 600)
        .alert(isPresented: $isExporting) {
            Alert(title: Text("処理完了"), message: Text(exportMessage), dismissButton: .default(Text("OK")))
        }
    }

    func startExport() {
        guard let sourceFolder = imageManager.sourceFolder else { return }

        imageManager.isProcessing = true
        imageManager.processingProgress = 0.0

        // Background processing
        DispatchQueue.global(qos: .userInitiated).async {
            let processor = BatchProcessor()
            let result = processor.processImages(
                files: imageManager.imageFiles,
                sourceFolder: sourceFolder,
                rects: cropConfiguration.cropRects,
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
