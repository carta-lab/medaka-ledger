import SwiftData
import SwiftUI
import UIKit

// 写真の全画面表示（SCREENS.md 10）。左右にスワイプ。日付と説明の編集、端末の写真ライブラリへ保存、削除。

struct PhotoViewer: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let photos: [Photo]
    @State private var model: PhotoViewerModel
    @State private var remaining: [Photo]

    init(photos: [Photo], startID: UUID) {
        self.photos = photos
        _model = State(initialValue: PhotoViewerModel(startID: startID))
        _remaining = State(initialValue: photos)
    }

    var body: some View {
        NavigationStack {
            Group {
                if remaining.isEmpty {
                    ContentUnavailableView("写真はありません", systemImage: "photo")
                } else {
                    TabView(selection: $model.selectedID) {
                        ForEach(remaining) { photo in
                            PhotoPage(photo: photo)
                                .tag(photo.id)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: remaining.count > 1 ? .automatic : .never))
                }
            }
            .background(Color.black)
            .navigationTitle(Text(verbatim: current.map { CohortText.date($0.capturedAt) } ?? ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") {
                        model.saveChanges(in: modelContext)
                        dismiss()
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if let photo = current {
                    controls(for: photo)
                }
            }
            .confirmationDialog("この写真を削除しますか", isPresented: $model.isConfirmingDelete, titleVisibility: .visible) {
                Button("削除", role: .destructive) { deleteCurrent() }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("元に戻せません。端末の写真ライブラリにある写真は消えません。")
            }
            .alert("保存しました", isPresented: $model.isShowingNotice) {
                Button("OK") {}
            } message: {
                Text(verbatim: model.notice)
            }
            .errorAlert($model.error)
        }
    }

    private var current: Photo? {
        remaining.first { $0.id == model.selectedID } ?? remaining.first
    }

    private func controls(for photo: Photo) -> some View {
        VStack(spacing: 10) {
            PhotoCaptionField(photo: photo)
            HStack(spacing: 8) {
                Button {
                    model.setCover(photo, among: remaining, in: modelContext)
                } label: {
                    Label(photo.isCover ? "代表" : "代表にする", systemImage: photo.isCover ? "star.fill" : "star")
                }
                .buttonStyle(LargeButtonStyle(prominent: false))
                Button {
                    model.export(photo)
                } label: {
                    Label("書き出す", systemImage: "square.and.arrow.down")
                }
                .buttonStyle(LargeButtonStyle(prominent: false))
                Button(role: .destructive) {
                    model.isConfirmingDelete = true
                } label: {
                    Label("削除", systemImage: "trash")
                }
                .buttonStyle(LargeButtonStyle(prominent: false))
            }
        }
        .padding(.horizontal, Theme.screenPadding)
        .padding(.vertical, 8)
        .background(.bar)
    }

    private func deleteCurrent() {
        guard let photo = current else { return }
        let next = model.delete(photo, among: remaining, in: modelContext)
        remaining.removeAll { $0.id == photo.id }
        if let next {
            model.selectedID = next
        } else {
            dismiss()
        }
    }
}

/// 写真1枚のページ。ここで初めて jpegData を読む。
private struct PhotoPage: View {
    let photo: Photo

    var body: some View {
        if let image = UIImage(data: photo.jpegData) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .accessibilityLabel(Text(verbatim: photo.caption.isEmpty ? CohortText.date(photo.capturedAt) : photo.caption))
        } else {
            ContentUnavailableView("写真を読み込めません", systemImage: "exclamationmark.triangle")
        }
    }
}

/// 説明の編集。
private struct PhotoCaptionField: View {
    @Bindable var photo: Photo

    var body: some View {
        TextField("説明（任意）", text: $photo.caption)
            .textFieldStyle(.roundedBorder)
    }
}
