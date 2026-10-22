import Foundation
import Observation

@MainActor
@Observable
final class BreedingListModel {
    var isCreating = false
    var hatchingBatch: EggBatch?
}
