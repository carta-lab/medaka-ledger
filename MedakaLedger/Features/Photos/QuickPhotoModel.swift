import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class QuickPhotoModel {
    enum TargetKind: Hashable { case cohort, tank }

    var photos: [ProcessedPhoto] = []
    var targetKind: TargetKind = .cohort
    var cohort: Cohort?
    var tank: Tank?
    var error: UserFacingError?

    var owner: PhotoOwner? {
        switch targetKind {
        case .cohort: cohort.map { PhotoOwner.cohort($0) }
        case .tank: tank.map { PhotoOwner.tank($0) }
        }
    }

    var canSave: Bool { !photos.isEmpty && owner != nil }

    /// 保存できたら true。
    func save(in context: ModelContext) -> Bool {
        guard let owner else { return false }
        for photo in photos {
            PhotoOperations.add(photo, to: owner, in: context)
        }
        do {
            try context.save()
            return true
        } catch {
            context.rollback()
            self.error = UserFacingError(error)
            return false
        }
    }
}
