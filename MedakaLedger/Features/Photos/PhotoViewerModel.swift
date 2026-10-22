import Foundation
import Observation
import SwiftData
import UIKit

@MainActor
@Observable
final class PhotoViewerModel {
    var selectedID: UUID
    var isConfirmingDelete = false
    var error: UserFacingError?
    var notice = ""
    var isShowingNotice = false
    private let saver = PhotoSaver()

    init(startID: UUID) {
        selectedID = startID
    }

    /// 代表にする。同じ付け先のほかの写真の代表は外す。
    func setCover(_ photo: Photo, among photos: [Photo], in context: ModelContext) {
        PhotoOperations.setCover(photo, among: photos)
        save(context)
    }

    /// 削除して、次に見せる写真のID。残りが無ければ nil。
    func delete(_ photo: Photo, among photos: [Photo], in context: ModelContext) -> UUID? {
        let remaining = photos.filter { $0.id != photo.id }
        let next: UUID?
        if let index = photos.firstIndex(where: { $0.id == photo.id }) {
            next = remaining.indices.contains(index) ? remaining[index].id : remaining.last?.id
        } else {
            next = remaining.first?.id
        }
        PhotoOperations.delete(photo, in: context)
        save(context)
        return next
    }

    func saveChanges(in context: ModelContext) {
        save(context)
    }

    /// 端末の写真ライブラリへ書き出す。利用者が書き出したときだけ書き込む（PRD.md F9）。
    func export(_ photo: Photo) {
        guard let image = UIImage(data: photo.jpegData) else {
            error = UserFacingError(title: String(localized: "書き出せませんでした"), message: String(localized: "写真を読み込めませんでした。"))
            return
        }
        saver.save(image) { [weak self] failure in
            if let failure {
                self?.error = UserFacingError(failure, title: String(localized: "書き出せませんでした"))
            } else {
                self?.notice = String(localized: "端末の写真ライブラリに保存しました。")
                self?.isShowingNotice = true
            }
        }
    }

    private func save(_ context: ModelContext) {
        do {
            try context.save()
        } catch {
            context.rollback()
            self.error = UserFacingError(error)
        }
    }
}

/// UIImageWriteToSavedPhotosAlbum の結果を受け取る。
@MainActor
final class PhotoSaver: NSObject {
    private var completion: ((Error?) -> Void)?

    func save(_ image: UIImage, completion: @escaping (Error?) -> Void) {
        self.completion = completion
        UIImageWriteToSavedPhotosAlbum(image, self, #selector(didFinish(_:error:context:)), nil)
    }

    @objc private func didFinish(_ image: UIImage, error: Error?, context: UnsafeRawPointer?) {
        completion?(error)
        completion = nil
    }
}
