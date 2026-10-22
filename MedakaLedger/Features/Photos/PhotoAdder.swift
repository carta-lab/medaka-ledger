import PhotosUI
import SwiftUI

// 写真を追加する2つの入口（ライブラリから複数選択、カメラ）。
// 縮小はメインスレッドの外で行い、できた写真を onAdd に渡す（PRD.md F9、CLAUDE.md）。

struct PhotoAdder: View {
    let onAdd: ([ProcessedPhoto]) -> Void
    @State private var selection: [PhotosPickerItem] = []
    @State private var isConfirmingCamera = false
    @State private var isShowingCamera = false
    @State private var isProcessing = false
    @State private var error: UserFacingError? = nil

    var body: some View {
        // 1つの行にまとめ、行の中の複数のボタンを別々に押せるよう borderless にする
        VStack(alignment: .leading, spacing: 14) {
            PhotosPicker(selection: $selection, matching: .images) {
                Label("ライブラリから選ぶ", systemImage: "photo.on.rectangle")
            }
            .accessibilityIdentifier("pickPhotosButton")
            if CameraPicker.isAvailable {
                Button {
                    isConfirmingCamera = true
                } label: {
                    Label("カメラで撮る", systemImage: "camera")
                }
                .accessibilityIdentifier("openCameraButton")
            }
            if isProcessing {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("写真を縮小しています")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .buttonStyle(.borderless)
        .onChange(of: selection) { _, items in
            guard !items.isEmpty else { return }
            selection = []
            Task { await importItems(items) }
        }
        // 権限を求める前に、使う理由を一行で示す
        .confirmationDialog("写真を撮るためにカメラを使います", isPresented: $isConfirmingCamera, titleVisibility: .visible) {
            Button("カメラを開く") { isShowingCamera = true }
            Button("キャンセル", role: .cancel) {}
        }
        .fullScreenCover(isPresented: $isShowingCamera) {
            CameraPicker(
                onCapture: { data in
                    isShowingCamera = false
                    Task { await importData([data]) }
                },
                onCancel: { isShowingCamera = false }
            )
            .ignoresSafeArea()
        }
        .errorAlert($error)
    }

    private func importItems(_ items: [PhotosPickerItem]) async {
        isProcessing = true
        defer { isProcessing = false }
        var datas: [Data] = []
        var failed = 0
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self) {
                datas.append(data)
            } else {
                failed += 1
            }
        }
        await finish(datas: datas, alreadyFailed: failed)
    }

    private func importData(_ datas: [Data]) async {
        isProcessing = true
        defer { isProcessing = false }
        await finish(datas: datas, alreadyFailed: 0)
    }

    private func finish(datas: [Data], alreadyFailed: Int) async {
        var processed: [ProcessedPhoto] = []
        var failed = alreadyFailed
        for data in datas {
            let now = Date()
            let photo = await Task.detached { PhotoProcessor.process(data, fallbackDate: now) }.value
            if let photo { processed.append(photo) } else { failed += 1 }
        }
        if !processed.isEmpty { onAdd(processed) }
        if failed > 0 {
            error = UserFacingError(
                title: String(localized: "追加できない写真がありました"),
                message: String(localized: "\(failed.formatted())枚は画像として読めなかったため、追加していません。")
            )
        }
    }
}
