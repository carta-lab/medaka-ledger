import SwiftData
import SwiftUI

// 設定の各項目（SCREENS.md 12）。出品文の雛形、サンプルデータ、Pro、用語の説明、プライバシーポリシー、バージョン。

/// 出品文の雛形（Pro）。FreeはPaywallを開く。
struct ListingSettingsSection: View {
    @Environment(ProStore.self) private var pro
    let gate: LimitGate

    var body: some View {
        Section {
            if pro.isPro {
                NavigationLink("出品文の雛形") {
                    ListingTemplateView()
                }
                .accessibilityIdentifier("listingTemplateLink")
            } else if pro.status == .free {
                Button {
                    gate.present(reason: .feature(.listingText))
                } label: {
                    Label("出品文の雛形はProの機能です", systemImage: "lock")
                }
            }
        } header: {
            if pro.status != .checking {
                Text("出品文")
            }
        }
    }
}

/// 雛形と、死着保証と注意事項の文を直す。
struct ListingTemplateView: View {
    @Environment(AppSettings.self) private var settings

    var body: some View {
        @Bindable var settings = settings
        Form {
            Section {
                TextEditor(text: $settings.listingTemplate)
                    .frame(minHeight: 240)
                    .font(.body.monospaced())
                    .accessibilityIdentifier("listingTemplateEditor")
                Button("既定の雛形に戻す") {
                    settings.listingTemplate = ListingTextBuilder.defaultTemplate
                }
            } header: {
                Text("雛形")
            } footer: {
                Text("{品種} のように波括弧で囲んだ語が、群の情報に置き換わります。情報が入っていない語を含む行は、行ごと省きます。1行に語を1つずつ置くと、項目ごとに省けます。")
            }
            Section {
                Text(verbatim: ListingTextBuilder.placeholders.map { "{\($0)}" }.joined(separator: "　"))
                    .font(.subheadline)
            } header: {
                Text("使える語")
            }
            Section {
                TextField("死着保証の文", text: $settings.listingGuaranteeText, axis: .vertical)
                    .lineLimit(2...6)
            } header: {
                Text("死着保証")
            } footer: {
                Text("{死着保証} に入る文です。空なら、その行は出しません。")
            }
            Section {
                TextField("注意事項の文", text: $settings.listingNoticeText, axis: .vertical)
                    .lineLimit(2...6)
            } header: {
                Text("注意事項")
            } footer: {
                Text("{注意事項} に入る文です。空なら、その行は出しません。")
            }
        }
        .navigationTitle("出品文の雛形")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // 空のままだと編集できないので、既定の雛形を入れておく
            if settings.listingTemplate.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                settings.listingTemplate = ListingTextBuilder.defaultTemplate
            }
        }
    }
}

/// サンプルデータの読み込みと全削除（PRD.md F14）。サンプルはFreeの上限に数えない。
struct SampleDataSection: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(Router.self) private var router
    @Query(filter: #Predicate<Tank> { $0.isSample == true }) private var sampleTanks: [Tank]
    @State private var isWorking = false
    @State private var isConfirmingDelete = false
    @State private var error: UserFacingError?

    var body: some View {
        Section {
            Button("サンプルデータを入れる") {
                run { worker in try await worker.seed() }
            }
            .disabled(isWorking || !sampleTanks.isEmpty)
            .accessibilityIdentifier("seedSampleDataButton")
            Button("サンプルデータを全削除", role: .destructive) {
                isConfirmingDelete = true
            }
            .disabled(isWorking || sampleTanks.isEmpty)
            .accessibilityIdentifier("deleteSampleDataButton")
        } header: {
            Text("サンプルデータ")
        } footer: {
            Text("使い方を試すためのデータです。Freeの上限には数えません。自分の記録は消えません。")
        }
        .confirmationDialog("サンプルデータを全削除しますか", isPresented: $isConfirmingDelete, titleVisibility: .visible) {
            Button("削除", role: .destructive) {
                run { worker in try await worker.deleteSamples() }
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("サンプルの容器、系統、群、記録、写真が消えます。元に戻せません。")
        }
        .errorAlert($error)
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
                // 消えたデータを開いたままの画面を残さないよう、全ての画面を作り直す
                router.dataEpoch += 1
            } catch {
                self.error = UserFacingError(error, title: String(localized: "できませんでした"))
            }
            isWorking = false
        }
    }
}

/// Proの状態（SCREENS.md 12）。購入と復元はPaywallで行う。
struct ProSection: View {
    @Environment(ProStore.self) private var pro
    let gate: LimitGate

    var body: some View {
        Section {
            switch pro.status {
            case .checking:
                HStack {
                    ProgressView()
                    Text("確認しています")
                        .foregroundStyle(.secondary)
                }
            case .pro:
                Label("Proを使っています", systemImage: "checkmark.seal.fill")
                    .foregroundStyle(Theme.accent)
                    .accessibilityIdentifier("proActiveLabel")
            case .free:
                Button {
                    gate.present()
                } label: {
                    Label("Proを見る（購入と復元）", systemImage: "sparkles")
                }
                .accessibilityIdentifier("showPaywallButton")
            }
        } header: {
            Text("Pro")
        } footer: {
            if pro.status == .free {
                Text("Proは買い切りです。容器と系統の上限がなくなり、血統図の全世代、年別の集計、販売CSV、出品文が使えます。")
            }
        }
    }
}

/// 用語の説明、プライバシーポリシー、バージョン。
struct AboutSection: View {
    private var version: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""
        return build.isEmpty ? short : "\(short)（\(build)）"
    }

    var body: some View {
        Section {
            NavigationLink("用語の説明") { GlossaryView() }
            NavigationLink("プライバシーポリシー") { PrivacyPolicyView() }
            LabeledContent("バージョン") {
                Text(verbatim: version)
            }
        }
    }
}
