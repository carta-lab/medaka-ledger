import SwiftData
import SwiftUI
import UIKit

// ホームのクイック操作「写真」（SCREENS.md 2）。カメラかライブラリを選び、撮影後に付け先（群か容器）を選ぶ。

struct QuickPhotoSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(ProStore.self) private var pro
    @State private var gate = LimitGate()
    @Query(filter: Cohort.activePredicate, sort: \Cohort.createdAt) private var cohorts: [Cohort]
    @Query(filter: Tank.unarchivedPredicate, sort: Tank.listSort) private var tanks: [Tank]
    @State private var model = QuickPhotoModel()

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ForEach(model.photos) { photo in
                        HStack {
                            if let image = UIImage(data: photo.thumbnailData) {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 56, height: 56)
                                    .clipShape(.rect(cornerRadius: 8))
                            }
                            Spacer()
                            Button(role: .destructive) {
                                model.photos.removeAll { $0.id == photo.id }
                            } label: {
                                Label("外す", systemImage: "minus.circle")
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                    PhotoAdder { model.photos.append(contentsOf: $0) }
                } header: {
                    Text("写真")
                }

                Section {
                    Picker("付け先", selection: $model.targetKind) {
                        Text("群").tag(QuickPhotoModel.TargetKind.cohort)
                        Text("容器").tag(QuickPhotoModel.TargetKind.tank)
                    }
                    .pickerStyle(.segmented)
                    switch model.targetKind {
                    case .cohort:
                        Picker("群", selection: $model.cohort) {
                            Text("選んでください").tag(Cohort?.none)
                            ForEach(cohorts) { cohort in
                                Text(verbatim: "\(cohort.strainName) \(cohort.generationLabel)・\(cohort.tankName)")
                                    .tag(Optional(cohort))
                            }
                        }
                    case .tank:
                        Picker("容器", selection: $model.tank) {
                            Text("選んでください").tag(Tank?.none)
                            ForEach(tanks) { tank in
                                Text(verbatim: tank.name).tag(Optional(tank))
                            }
                        }
                    }
                } header: {
                    Text("付け先")
                } footer: {
                    Text("写真を選んで、付け先を選ぶと保存できます。")
                }
            }
            .themedBackground()
            .navigationTitle("写真を追加")
            .navigationBarTitleDisplayMode(.inline)
            .bottomSaveBar(isEnabled: model.canSave, identifier: "saveQuickPhotoButton") {
                gate.attempt(
                    .photosPerOwner, adding: model.photos.count, pro: pro,
                    count: { model.owner.map(LimitCounter.photos(of:)) ?? 0 }
                ) {
                    if model.save(in: modelContext) { dismiss() }
                }
            }
            .paywall(gate)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
            }
            .errorAlert($model.error)
        }
    }
}
