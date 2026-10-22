#if DEBUG
import SwiftData
import SwiftUI

// デバッグメニュー（Debugビルドだけ。DECISIONS.md E、H）。
// サンプルの投入と削除は ModelActor で行い、ModelActor は Task.detached の中で生成する（DECISIONS.md G 3-2）。

struct DebugMenuView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var isWorking = false
    @State private var isConfirmingDeleteAll = false
    @State private var error: UserFacingError? = nil

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button("サンプルデータを入れる") {
                        run { worker in try await worker.seed() }
                    }
                    .accessibilityIdentifier("seedSampleButton")
                    Button("サンプルデータを全削除") {
                        run { worker in try await worker.deleteSamples() }
                    }
                } footer: {
                    Text("サンプルは容器6、系統2、群4です。Freeの上限には数えません。")
                }
                Section {
                    Button("すべてのデータを削除", role: .destructive) {
                        isConfirmingDeleteAll = true
                    }
                }
            }
            .disabled(isWorking)
            .overlay {
                if isWorking {
                    ProgressView()
                }
            }
            .navigationTitle("デバッグ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
            .confirmationDialog("すべてのデータを削除しますか", isPresented: $isConfirmingDeleteAll, titleVisibility: .visible) {
                Button("削除", role: .destructive) {
                    run { worker in try await worker.deleteEverything() }
                }
                Button("キャンセル", role: .cancel) {}
            }
            .errorAlert($error)
        }
    }

    private func run(_ operation: @escaping @Sendable (SampleDataActor) async throws -> Void) {
        let container = modelContext.container
        isWorking = true
        Task {
            do {
                try await Task.detached {
                    let worker = SampleDataActor(modelContainer: container)
                    try await operation(worker)
                }.value
                dismiss()
            } catch {
                self.error = UserFacingError(error, title: String(localized: "できませんでした"))
            }
            isWorking = false
        }
    }
}
#endif
