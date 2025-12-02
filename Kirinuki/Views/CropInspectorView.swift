import SwiftUI

struct CropInspectorView: View {
    @Binding var cropState: PageCropState
    @ObservedObject var imageManager: ImageManager
    let selectedPageId: UUID?
    let onExport: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Group {
                Text("設定")
                    .font(.headline)

                Picker("モード", selection: $cropState.mode) {
                    ForEach(CropMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .onChange(of: cropState.mode) { oldValue, newValue in
                    cropState.updateMode(newValue)
                }

                if cropState.mode == .split {
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

                    HStack {
                        Button(action: {
                            cropState.alignCropRects(toRight: false)
                        }) {
                            Text("左へ揃える")
                        }

                        Button(action: {
                            cropState.alignCropRects(toRight: true)
                        }) {
                            Text("右へ揃える")
                        }
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
                    Text("現在の設定を全てに適用")
                        .frame(maxWidth: .infinity)
                }
                .disabled(selectedPageId == nil)
            }

            Divider()

            Group {
                Text("実行")
                    .font(.headline)
                Button(action: {
                    onExport()
                }) {
                    Label("切り出し実行", systemImage: "scissors")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(imageManager.pages.isEmpty || imageManager.isProcessing)

                if imageManager.isProcessing {
                    ProgressView(value: imageManager.processingProgress)
                    Text("処理中... \(Int(imageManager.processingProgress * 100))%")
                        .font(.caption)
                }
            }

            Spacer()
        }
        .padding()
        .frame(minWidth: 200, maxWidth: 300)
    }
}
