import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class StrainListModel {
    var isCreating = false
    var error: UserFacingError?

    func move(_ strains: [Strain], from source: IndexSet, to destination: Int, in context: ModelContext) {
        for (index, strain) in Aggregations.moved(strains, from: source, to: destination).enumerated() {
            strain.sortOrder = index
        }
        do {
            try context.save()
        } catch {
            self.error = UserFacingError(error)
        }
    }
}
