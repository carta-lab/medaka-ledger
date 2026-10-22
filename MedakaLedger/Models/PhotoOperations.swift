import Foundation
import SwiftData

// 写真（PRD.md F9）。保存は縮小したJPEGとサムネイル。端末の写真ライブラリには書き込まない。

/// 縮小済みの写真。メインスレッドの外で作り、Sendableで渡す。
struct ProcessedPhoto: Sendable, Identifiable {
    let id = UUID()
    var jpegData: Data
    var thumbnailData: Data
    var capturedAt: Date
}

/// 写真の付け先（群、容器、系統、選別）。
enum PhotoOwner {
    case cohort(Cohort)
    case tank(Tank)
    case strain(Strain)
    case selection(SelectionEvent)

    /// 撮影日の古い順。
    var photos: [Photo] {
        let all: [Photo]
        switch self {
        case let .cohort(cohort): all = cohort.photos ?? []
        case let .tank(tank): all = tank.photos ?? []
        case let .strain(strain): all = strain.photos ?? []
        case let .selection(selection): all = selection.photos ?? []
        }
        return all.sorted { $0.capturedAt < $1.capturedAt }
    }

    var isSample: Bool {
        switch self {
        case let .cohort(cohort): cohort.isSample
        case let .tank(tank): tank.isSample
        case let .strain(strain): strain.isSample
        case let .selection(selection): selection.isSample
        }
    }
}

enum PhotoOperations {
    @discardableResult
    static func add(_ processed: ProcessedPhoto, to owner: PhotoOwner, in context: ModelContext) -> Photo {
        let photo = Photo()
        photo.capturedAt = processed.capturedAt
        photo.jpegData = processed.jpegData
        photo.thumbnailData = processed.thumbnailData
        photo.isSample = owner.isSample
        context.insert(photo)
        switch owner {
        case let .cohort(cohort): photo.cohort = cohort
        case let .tank(tank): photo.tank = tank
        case let .strain(strain): photo.strain = strain
        case let .selection(selection): photo.selection = selection
        }
        return photo
    }

    /// 写真の付け先にある写真（自分を含む）。付け先が無ければ自分だけ。
    static func siblings(of photo: Photo) -> [Photo] {
        let owner: PhotoOwner?
        if let cohort = photo.cohort {
            owner = .cohort(cohort)
        } else if let tank = photo.tank {
            owner = .tank(tank)
        } else if let strain = photo.strain {
            owner = .strain(strain)
        } else if let selection = photo.selection {
            owner = .selection(selection)
        } else {
            owner = nil
        }
        guard let owner else { return [photo] }
        return owner.photos
    }

    /// 代表にする。同じ付け先のほかの写真の代表は外す。別の付け先の写真には触れない。
    static func setCover(_ photo: Photo) {
        for other in siblings(of: photo) {
            other.isCover = other.id == photo.id
        }
        photo.isCover = true
    }

    static func delete(_ photo: Photo, in context: ModelContext) {
        context.delete(photo)
    }

    /// 代表写真：代表に設定した写真、なければ最も古い写真（PhotoRules）。
    static func cover(of photos: [Photo]) -> Photo? {
        guard let id = PhotoRules.coverID(of: photos.map { (id: $0.id, capturedAt: $0.capturedAt, isCover: $0.isCover) }) else { return nil }
        return photos.first { $0.id == id }
    }
}
