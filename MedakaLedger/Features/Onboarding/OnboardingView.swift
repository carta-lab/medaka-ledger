import SwiftData
import SwiftUI

// 初回の案内（SCREENS.md 1）。3ページ。3分で最初の容器と系統を作り、ホームに価値を見せる。
// 各ページに「あとで」を置く。最終ページに「サンプルデータを入れて試す」を置く。

struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppSettings.self) private var settings
    @Environment(Router.self) private var router
    @Environment(ProStore.self) private var pro
    @Query(filter: Tank.unarchivedPredicate, sort: Tank.listSort) private var tanks: [Tank]
    @State private var model: OnboardingModel
    @State private var gate = LimitGate()
    @State private var isSeeding = false

    init(existingTankNames: [String]) {
        _model = State(initialValue: OnboardingModel(existingTankNames: existingTankNames))
    }

    var body: some View {
        @Bindable var model = model
        NavigationStack {
            VStack(spacing: 0) {
                pageIndicator
                Group {
                    switch model.page {
                    case .intro: introPage
                    case .tanks: tanksPage
                    case .strain: strainPage
                    }
                }
                .frame(maxHeight: .infinity)
                actionBar
            }
            .themedBackground()
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .paywall(gate)
            .errorAlert($model.error)
        }
        .interactiveDismissDisabled()
    }

    private var title: LocalizedStringKey {
        switch model.page {
        case .intro: "めだか台帳へようこそ"
        case .tanks: "容器を登録"
        case .strain: "系統を登録"
        }
    }

    private var pageIndicator: some View {
        HStack(spacing: 8) {
            ForEach(OnboardingModel.Page.allCases, id: \.rawValue) { page in
                Capsule()
                    .fill(page == model.page ? Theme.accent : Color.secondary.opacity(0.3))
                    .frame(width: page == model.page ? 24 : 8, height: 8)
            }
        }
        .padding(.top, 12)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: String(localized: "\(OnboardingModel.Page.allCases.count.formatted())ページ中\((model.page.rawValue + 1).formatted())ページ")))
    }

    // MARK: - ページ

    private var introPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("容器、系統、世代、採卵、販売を、つなげて記録します。")
                    .font(.title3.bold())
                VStack(alignment: .leading, spacing: 12) {
                    flowRow("square.grid.2x2", "容器", "どこで飼っているか")
                    flowRow("list.bullet.rectangle", "系統と群", "何の、何世代目が、何匹いるか")
                    flowRow("arrow.triangle.branch", "親魚セットと採卵", "いつ採卵して、いつ孵るか")
                    flowRow("line.3.horizontal.decrease.circle", "選別", "どう選んで、何匹残したか")
                    flowRow("yensign.circle", "販売", "いくらで売れたか")
                }
                Text("記録はこの端末の中だけに保存します。アカウントは要りません。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(Theme.screenPadding)
        }
    }

    private func flowRow(_ symbol: String, _ title: LocalizedStringKey, _ detail: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.title2)
                .foregroundStyle(Theme.accent)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(detail).font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var tanksPage: some View {
        @Bindable var model = model
        return Form {
            Section {
                ForEach(model.tankNames.indices, id: \.self) { index in
                    TextField("名前", text: $model.tankNames[index])
                        .accessibilityIdentifier("onboardingTankName\(index)")
                }
            } header: {
                Text("容器の名前")
            } footer: {
                Text("名前は後から変えられます。空欄の容器は作りません。")
            }
            Section {
                Picker("種類", selection: $model.kind) {
                    ForEach(TankKind.allCases, id: \.self) { kind in
                        Label(kind.label, systemImage: kind.symbolName).tag(kind)
                    }
                }
                Picker("置き場所", selection: $model.placement) {
                    ForEach(Placement.allCases, id: \.self) { placement in
                        Text(verbatim: placement.label).tag(placement)
                    }
                }
                .pickerStyle(.segmented)
            } header: {
                Text("3個に共通")
            }
        }
    }

    private var strainPage: some View {
        @Bindable var model = model
        return Form {
            Section {
                TextField("品種名（例 楊貴妃）", text: $model.breedName)
                    .accessibilityIdentifier("onboardingBreedName")
                TextField("入手元・作出者", text: $model.source)
            } header: {
                Text("系統")
            } footer: {
                Text("品種名を入れると、系統を作れます。")
            }
            Section {
                IntField("匹数", value: $model.count)
                Picker("容器", selection: $model.tank) {
                    Text("容器未設定").tag(Tank?.none)
                    ForEach(tanks) { tank in
                        Text(verbatim: tank.name).tag(Optional(tank))
                    }
                }
            } header: {
                Text("入手した個体")
            } footer: {
                Text("匹数を入れると、この系統の最初の群（入手個体）も作ります。匹数は概数で構いません。")
            }
            Section {
                Button {
                    seedSamples()
                } label: {
                    Label("サンプルデータを入れて試す", systemImage: "wand.and.stars")
                }
                .disabled(isSeeding)
                .accessibilityIdentifier("onboardingSeedSamples")
            } footer: {
                Text("使い方を試すためのデータです。あとから設定で全削除できます。")
            }
        }
    }

    // MARK: - 下のボタン

    private var actionBar: some View {
        VStack(spacing: 4) {
            Button(primaryTitle) { primaryAction() }
                .buttonStyle(LargeButtonStyle())
                .disabled(!canProceed)
                .accessibilityIdentifier("onboardingNext")
            Button("あとで") { skip() }
                .frame(minHeight: Theme.minButtonHeight)
                .accessibilityIdentifier("onboardingLater")
        }
        .padding(.horizontal, Theme.screenPadding)
        .padding(.vertical, 8)
        .background(.bar)
    }

    private var primaryTitle: LocalizedStringKey {
        switch model.page {
        case .intro: "はじめる"
        case .tanks: "容器を登録して次へ"
        case .strain: "系統を登録して始める"
        }
    }

    private var canProceed: Bool {
        switch model.page {
        case .intro: true
        case .tanks: model.canSaveTanks
        case .strain: model.canSaveStrain
        }
    }

    private func primaryAction() {
        switch model.page {
        case .intro:
            model.next()
        case .tanks:
            gate.attempt(.tanks, adding: model.trimmedTankNames.count, pro: pro, count: { LimitCounter.tanks(in: modelContext) }) {
                if model.saveTanks(in: modelContext) { model.next() }
            }
        case .strain:
            gate.attempt(.strains, pro: pro, count: { LimitCounter.strains(in: modelContext) }) {
                if model.saveStrain(in: modelContext) { finish() }
            }
        }
    }

    private func skip() {
        if model.isLastPage {
            finish()
        } else {
            model.next()
        }
    }

    private func finish() {
        settings.hasCompletedOnboarding = true
        router.showsOnboarding = false
    }

    private func seedSamples() {
        let container = modelContext.container
        isSeeding = true
        Task {
            do {
                try await Task.detached {
                    let worker = SampleDataActor(modelContainer: container)
                    try await worker.seed()
                }.value
                finish()
                router.dataEpoch += 1
            } catch {
                model.error = UserFacingError(error, title: String(localized: "できませんでした"))
            }
            isSeeding = false
        }
    }
}
