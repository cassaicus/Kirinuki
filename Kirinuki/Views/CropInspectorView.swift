import SwiftUI

struct CropInspectorView: View {
    @Binding var cropState: PageCropState
    @ObservedObject var imageManager: ImageManager
    let selectedPageId: UUID?
    let onExport: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Group {
                Text("Settings")
                    .font(.headline)

                // 【解説: Custom Binding の活用】
                // Picker 選択時に直接 cropState.mode を更新するのではなく、カスタム Binding を介して制御しています。
                // これにより、更新処理（cropState.updateMode）を非同期（DispatchQueue.main.async）で行うことができ、
                // ビューの描画サイクル中の状態変更エラーを回避しています。
                Picker("Mode", selection: Binding(
                    get: { cropState.mode },
                    set: { newMode in
                        DispatchQueue.main.async {
                            cropState.updateMode(newMode)
                        }
                    }
                )) {
                    ForEach(CropMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())

                if cropState.mode == .split {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Circle().fill(Color.blue).frame(width: 10, height: 10)
                            Text("1st Frame (Earlier)")
                            Spacer()
                            if !cropState.cropRects.contains(where: { $0.colorIndex == 0 }) {
                                Button("Add") {
                                    cropState.addRect(colorIndex: 0)
                                }
                                .font(.caption)
                            }
                        }
                        HStack {
                            Circle().fill(Color.red).frame(width: 10, height: 10)
                            Text("2nd Frame (Later)")
                            Spacer()
                            if !cropState.cropRects.contains(where: { $0.colorIndex == 1 }) {
                                Button("Add") {
                                    cropState.addRect(colorIndex: 1)
                                }
                                .font(.caption)
                            }
                        }
                    }
                    .font(.caption)

                    HStack {
                        Button(action: {
                            cropState.alignCropRects(toRight: false)
                        }) {
                            Text("Align Left")
                        }
                        .disabled(cropState.cropRects.count < 2)

                        Button(action: {
                            cropState.alignCropRects(toRight: true)
                        }) {
                            Text("Align Right")
                        }
                        .disabled(cropState.cropRects.count < 2)
                    }
                } else {
                    // Single mode add button if missing
                    if cropState.cropRects.isEmpty {
                        Button("Add Frame") {
                            cropState.addRect(colorIndex: 0)
                        }
                    }
                }
            }

            Divider()

            if let selectedId = imageManager.selectedCropId,
               let index = cropState.cropRects.firstIndex(where: { $0.id == selectedId }),
               imageManager.currentImageSize.width > 0,
               imageManager.currentImageSize.height > 0 {

                Group {
                    Text("Crop Geometry")
                        .font(.headline)

                    let rect = cropState.cropRects[index].rect
                    let size = imageManager.currentImageSize

                    // X
                    HStack {
                        Text("X:")
                        // 【解説】 TextField への入力も Custom Binding でラップ
                        // get: 正規化された座標 (0.0-1.0) をピクセル単位に変換して表示
                        // set: 入力されたピクセル値を再び正規化座標に変換してモデルに保存
                        TextField("X", value: Binding(
                            get: { Int(rect.origin.x * size.width) },
                            set: { newVal in
                                var newRect = rect
                                newRect.origin.x = CGFloat(newVal) / size.width
                                cropState.cropRects[index].rect = newRect
                            }
                        ), formatter: NumberFormatter())
                    }

                    // Y
                    HStack {
                        Text("Y:")
                        TextField("Y", value: Binding(
                            get: { Int(rect.origin.y * size.height) },
                            set: { newVal in
                                var newRect = rect
                                newRect.origin.y = CGFloat(newVal) / size.height
                                cropState.cropRects[index].rect = newRect
                            }
                        ), formatter: NumberFormatter())
                    }

                    // W
                    HStack {
                        Text("W:")
                        TextField("W", value: Binding(
                            get: { Int(rect.width * size.width) },
                            set: { newVal in
                                var newRect = rect
                                newRect.size.width = CGFloat(newVal) / size.width
                                cropState.cropRects[index].rect = newRect
                            }
                        ), formatter: NumberFormatter())
                    }

                    // H
                    HStack {
                        Text("H:")
                        TextField("H", value: Binding(
                            get: { Int(rect.height * size.height) },
                            set: { newVal in
                                var newRect = rect
                                newRect.size.height = CGFloat(newVal) / size.height
                                cropState.cropRects[index].rect = newRect
                            }
                        ), formatter: NumberFormatter())
                    }
                }

                Divider()
            }

            Group {
                Text("Export Settings")
                    .font(.headline)

                Picker("Format", selection: $imageManager.exportOptions.format) {
                    ForEach(ExportOptions.Format.allCases) { format in
                        Text(format.rawValue).tag(format)
                    }
                }

                Picker("Filename", selection: $imageManager.exportOptions.filenameMode) {
                    ForEach(ExportOptions.FilenameMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }

                if imageManager.exportOptions.filenameMode == .custom ||
                   imageManager.exportOptions.filenameMode == .originalAndCustom {
                    TextField("Custom Text", text: $imageManager.exportOptions.customPrefix)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }

                HStack {
                    Text("Output:")
                    if let folder = imageManager.exportOptions.outputFolder {
                        Text(folder.lastPathComponent)
                            .truncationMode(.middle)
                            .lineLimit(1)
                            .help(folder.path)
                    } else {
                        Text("Default (Output/)")
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Button("Choose...") {
                        selectOutputFolder()
                    }
                }
            }

            Divider()

            Group {
                Button(action: {
                    if let id = selectedPageId {
                        imageManager.applySettingsToAll(from: id)
                    }
                }) {
                    Text("Apply Settings to All")
                        .frame(maxWidth: .infinity)
                }
                .disabled(selectedPageId == nil)
            }

            Divider()

            Group {
                Text("Actions")
                    .font(.headline)
                Button(action: {
                    onExport()
                }) {
                    Label("Export", systemImage: "scissors")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(imageManager.pages.isEmpty || imageManager.isProcessing)

                if imageManager.isProcessing {
                    ProgressView(value: imageManager.processingProgress)
                    Text("Processing... \(Int(imageManager.processingProgress * 100))%")
                        .font(.caption)
                }
            }

            Spacer()
        }
        .padding()
        .frame(minWidth: 200, maxWidth: 300)
    }

    func selectOutputFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.message = "Select Output Folder"

        if panel.runModal() == .OK {
            imageManager.exportOptions.outputFolder = panel.url
        }
    }
}
