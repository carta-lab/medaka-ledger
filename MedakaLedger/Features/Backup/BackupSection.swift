import SwiftData
import SwiftUI

// 設定のバックアップと書き出し（SCREENS.md 12、PRD.md F12）。
// 書き出し（写真を含める、含めない）、読み込み（置き換え、追記。写真を含まないバックアップは追記だけ）、群CSV、最終バックアップ日時、データ容量。

struct BackupSection: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppSettings.self) private var settings
    @Environment(Router.self) private var router
    @Query(sort: \Cohort.createdAt) private var cohorts: [Cohort]
    @State private var model = BackupModel()
    @State private var usage: Int64?

    var body: some View {
        Section {
            LabeledContent("最終バックアップ") {
                Text(verbatim: settings.lastBackupAt.map { $0.formatted(.dateTime.year().month().day().hour().minute()) } ?? String(localized: "まだありません"))
            }
            LabeledContent("データの容量") {
                Text(verbatim: usage.map(StorageUsage.text) ?? "…")
            }
            Button("バックアップを書き出す（写真を含める）") {
                model.export(includesPhotos: true, container: modelContext.container)
            }
            .accessibilityIdentifier("exportBackupWithPhotos")
            Button("バックアップを書き出す（写真を含めない）") {
                model.export(includesPhotos: false, container: modelContext.container)
            }
            Button("バックアップを読み込む") {
                model.isPickingFile = true
            }
            .accessibilityIdentifier("importBackup")
            Button("群の一覧をCSVで書き出す") {
                model.exportCohortsCSV(cohorts)
            }
            .disabled(cohorts.isEmpty)
        } header: {
            Text("バックアップと書き出し")
        } footer: {
            Text("バックアップはこの端末の外に保存してください。写真を含めないバックアップは小さくなりますが、追記でしか読み込めません。購入者メモもバックアップに入ります。")
        }
        .disabled(model.isWorking)
        .overlay { progressOverlay }
        .task { await refreshUsage() }
        .fileExporter(isPresented: $model.isExporting, document: model.exportDocument, contentType: .medakaBackup, defaultFilename: BackupExporter.fileName()) { result in
            model.exportFinished(result, settings: settings)
            Task { await refreshUsage() }
        }
        .fileExporter(isPresented: $model.isExportingCSV, document: model.csvDocument, contentType: .commaSeparatedText, defaultFilename: String(localized: "群の一覧")) { result in
            model.csvFinished(result)
        }
        .fileImporter(isPresented: $model.isPickingFile, allowedContentTypes: [.medakaBackup, .data]) { result in
            model.pick(result.map { [$0] }, container: modelContext.container)
        }
        .confirmationDialog("バックアップを読み込みますか", isPresented: $model.isChoosingMode, titleVisibility: .visible) {
            if model.pendingManifest?.includesPhotos == true {
                Button("置き換える", role: .destructive) { model.isConfirmingReplace = true }
            }
            Button("追記する") {
                model.restore(mode: .append, container: modelContext.container)
            }
            Button("キャンセル", role: .cancel) { model.discardPending() }
        } message: {
            Text(verbatim: chooseMessage)
        }
        .alert("今のデータを置き換えますか", isPresented: $model.isConfirmingReplace) {
            Button("置き換える", role: .destructive) {
                model.restore(mode: .replace, container: modelContext.container)
            }
            Button("キャンセル", role: .cancel) { model.discardPending() }
        } message: {
            Text("今のデータをすべて消して、バックアップの内容にします。元に戻せません。")
        }
        .alert("読み込みました", isPresented: $model.isShowingResult) {
            Button("OK") { router.dataEpoch += 1 }
        } message: {
            Text(verbatim: model.resultMessage ?? "")
        }
        .errorAlert($model.error)
    }

    private var chooseMessage: String {
        guard let manifest = model.pendingManifest else { return "" }
        let counts = manifest.counts
        let date = manifest.exportedAt.formatted(.dateTime.year().month().day())
        var message = String(localized: "\(date)に書き出したバックアップです。容器\(counts.tanks.formatted())、系統\(counts.strains.formatted())、群\(counts.cohorts.formatted())、販売\(counts.sales.formatted())、写真\(counts.photos.formatted())。")
        if !manifest.includesPhotos {
            message += String(localized: "写真は含まれていないので、追記だけできます。")
        } else {
            message += String(localized: "追記は、同じものを上書きして、無いものを足します。")
        }
        return message
    }

    @ViewBuilder
    private var progressOverlay: some View {
        if let progress = model.progress {
            ProgressView(value: progress) {
                Text("処理しています")
            }
            .padding()
            .background(.regularMaterial, in: .rect(cornerRadius: Theme.cornerRadius))
            .padding(.horizontal, Theme.screenPadding)
        }
    }

    private func refreshUsage() async {
        usage = await Task.detached { StorageUsage.bytes() }.value
    }
}
