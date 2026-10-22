# アーキテクチャ：めだか台帳（仮称）

版：v1.0（2026-10-22）
`PRD.md` の機能要件を満たすための技術方針、データモデル、計算ロジック、出力形式を定める。
用語は `DOMAIN.md` に従う。

## 1. 技術スタック

| 項目 | 採用 | 理由 |
|---|---|---|
| 対象OS | iOS 18.0以上、iPhoneのみ | SwiftDataの安定版が使え、2026年秋時点の現役端末をほぼ全て含む |
| 言語 | Swift 6、strict concurrency有効、Default Actor Isolationは `nonisolated` | 並行処理の誤りをコンパイル時に潰す。モデルをModelActorから扱えるようにし、UI層だけ `@MainActor` を明示する |
| UI | SwiftUI、NavigationStack | 画面数が多く、宣言的に書くほうが速い |
| 永続化 | SwiftData | Apple純正。CloudKit同期へ後から移行できる |
| 課金 | StoreKit 2、非消耗型1点 | 買い切りPro。サーバー検証は不要 |
| 写真 | PhotosUI、UIImageのJPEG縮小 | ライブラリ依存なし |
| グラフ | Swift Charts | 月別売上の棒グラフだけに使う |
| テスト | Swift Testing | 計算ロジックとエクスポートを対象にする |
| 外部依存 | なし | 審査とメンテナンスの手間を減らす |
| 開発環境 | Xcode 26以上 | |

サーバー、アカウント、計測SDK、広告SDKは持たない。
通信するのはStoreKitだけである。

## 2. 設計上の決まり

- **群が中心**。画面もモデルも群（Cohort）を軸にたどれるようにする。容器と系統は群を束ねる二つの軸で、採卵ロットと親魚セットは群を生む経路である。
- **CloudKit互換を最初から守る**。全てのリレーションはOptionalで逆方向も定義する、全ての属性に既定値、`@Attribute(.unique)` は使わない。識別子は自前の `UUID` 属性で持つ。これを守れば第2段階で `ModelConfiguration(cloudKitDatabase:)` を足すだけで同期に移れる。
- **列挙型はrawValueの文字列で保存する**。CloudKitとの互換とスキーマ移行の単純さのため。型として扱うcomputed propertyを各モデルに置く。
- **削除ではなくアーカイブ**。容器と系統はアーカイブで一覧から消し、記録からはたどれるようにする。群の削除は履歴ごと消えるため確認を出す。
- **出来事は時系列に残す**。移動、分割、統合、増減、段階変更は `CohortEvent` として残し、群詳細のタイムラインに出す。
- **表示用の名前はスナップショットも持つ**。出来事に関係する容器名や系統名は、参照先が後で改名やアーカイブされても読めるよう、文字列でも保存する。
- **重い処理はModelActorで行う**。バックアップの書き出しと読み込み、写真の縮小はメインスレッドから外す。
- **設定はUserDefaults**。積算温度や既定水温のような単一値はSwiftDataに入れない。

## 3. データモデル

SwiftDataの `@Model` を列挙する。
型名と属性名はこのまま使う。
下の定義に加えて、全てのモデルに `var isSample: Bool = false` を持たせる（サンプルデータの目印。`DECISIONS.md` E）。
スキーマは `SchemaV1: VersionedSchema` として定義し、`SchemaMigrationPlan` を最初から用意する。
ストアはApp Group `group.com.meldcarta.medakaledger` のコンテナに置く。

### 3.1 列挙型

```swift
enum TankKind: String, CaseIterable { case nvBox, toroBune, styrofoam, plaBune, waterLilyPot, aquarium, cup, other }
enum Placement: String, CaseIterable { case outdoor, indoor }
enum GrowthStage: String, CaseIterable { case hatchling, fry, young, adult }   // 針子、稚魚、若魚、成魚
enum CohortStatus: String { case active, soldOut, merged, lost, archived }
enum CohortEventKind: String { case created, move, split, merge, countChange, stageChange, statusChange, note }
enum CountChangeReason: String { case death, jumpedOut, givenAway, recount, other }
enum EggBatchStatus: String { case incubating, hatched, discarded }
enum CullDestination: String { case feed, cheapSale, separateTank, dispose }   // 放流は用意しない
enum SaleUnit: String { case fish, pair, trio, eggs, fryBundle }
enum SaleChannel: String { case yahooAuction, ownShop, event, consignment, direct, other }
enum SaleStatus: String { case listed, sold, shipped, cancelled }
enum MaintenanceKind: String { case waterChange, topUp, cleaning, medication, temperature, other }
```

各列挙型に日本語表示名を返す `label` を持たせる。
表示名は `DOMAIN.md` の用語に合わせる（例：`hatchling` は「針子」）。

### 3.2 モデル

```swift
@Model final class Tank {
    var id: UUID = UUID()
    var name: String = ""                 // 例 "A-1"
    var kindRaw: String = TankKind.other.rawValue
    var capacityLiters: Double?
    var placementRaw: String = Placement.outdoor.rawValue
    var location: String = ""             // 棚、列、場所の自由記述
    var sortOrder: Int = 0
    var note: String = ""
    var isArchived: Bool = false
    var createdAt: Date = Date()

    @Relationship(deleteRule: .nullify, inverse: \Cohort.tank) var cohorts: [Cohort]?
    @Relationship(deleteRule: .cascade, inverse: \MaintenanceLog.tank) var logs: [MaintenanceLog]?
    @Relationship(deleteRule: .cascade, inverse: \Photo.tank) var photos: [Photo]?
    @Relationship(deleteRule: .nullify, inverse: \BreedingSet.tank) var breedingSets: [BreedingSet]?
    @Relationship(deleteRule: .nullify, inverse: \EggBatch.container) var eggBatches: [EggBatch]?
}

@Model final class Strain {
    var id: UUID = UUID()
    var breedName: String = ""            // 品種名
    var lineName: String = ""             // 系統名、呼び名（空でもよい）
    var source: String = ""               // 入手元、作出者
    var acquiredAt: Date?
    var traitTags: [String] = []
    var note: String = ""
    var sortOrder: Int = 0
    var isArchived: Bool = false
    var createdAt: Date = Date()

    @Relationship(deleteRule: .nullify, inverse: \Cohort.strain) var cohorts: [Cohort]?
    @Relationship(deleteRule: .cascade, inverse: \Photo.strain) var photos: [Photo]?
    @Relationship(deleteRule: .nullify, inverse: \BreedingSet.offspringStrain) var offspringBreedingSets: [BreedingSet]?
    @Relationship(deleteRule: .nullify, inverse: \Sale.strain) var sales: [Sale]?

    var displayName: String { lineName.isEmpty ? breedName : "\(breedName)（\(lineName)）" }
}

@Model final class Cohort {
    var id: UUID = UUID()
    var label: String = ""                // 任意の呼び名。例 "2027春 1番"
    var generation: Int = 0               // 0 は入手個体。表示は "入手"、1以降は "F1"
    var count: Int?                       // 概数。nil は未計数、0 は0匹
    var maleCount: Int?
    var femaleCount: Int?
    var stageRaw: String = GrowthStage.adult.rawValue
    var statusRaw: String = CohortStatus.active.rawValue
    var hatchedAt: Date?                  // アプリ内で孵化した群は必須
    var acquiredAt: Date?                 // 入手個体の入手日
    var sizeText: String = ""             // 例 "1.5〜2cm"。出品文の {サイズ}
    var note: String = ""
    var createdAt: Date = Date()

    var strain: Strain?
    var tank: Tank?
    var originBatch: EggBatch?            // この群を生んだ採卵ロット。入手個体は nil

    @Relationship(deleteRule: .cascade, inverse: \CohortEvent.cohort) var events: [CohortEvent]?
    @Relationship(deleteRule: .cascade, inverse: \SelectionEvent.cohort) var selections: [SelectionEvent]?
    @Relationship(deleteRule: .nullify, inverse: \Sale.cohort) var sales: [Sale]?
    @Relationship(deleteRule: .cascade, inverse: \Photo.cohort) var photos: [Photo]?
    @Relationship(deleteRule: .nullify, inverse: \BreedingSet.sireCohort) var asSire: [BreedingSet]?
    @Relationship(deleteRule: .nullify, inverse: \BreedingSet.damCohort) var asDam: [BreedingSet]?
}

@Model final class CohortEvent {
    var id: UUID = UUID()
    var date: Date = Date()
    var kindRaw: String = CohortEventKind.note.rawValue
    var countDelta: Int = 0               // 増減。分割元はマイナス
    var reasonRaw: String = ""            // CountChangeReason
    var fromTankID: UUID?
    var fromTankName: String = ""
    var toTankID: UUID?
    var toTankName: String = ""
    var relatedCohortID: UUID?            // 分割先、統合元
    var stageRaw: String = ""             // stageChange のとき、変更後の段階
    var previousCount: Int?               // 削除で元に戻すための値
    var previousStageRaw: String = ""
    var previousStatusRaw: String = ""
    var statusRaw: String = ""            // statusChange のとき、変更後の状態（DECISIONS H）
    var createdAt: Date = Date()          // 保存日時。「最新の出来事」の判定に使う（DECISIONS H）
    var note: String = ""
    var cohort: Cohort?
}

@Model final class BreedingSet {
    var id: UUID = UUID()
    var name: String = ""                 // 空なら "雄の系統 × 雌の系統 開始年月" を表示
    var maleCount: Int = 1
    var femaleCount: Int = 2
    var startedAt: Date = Date()
    var endedAt: Date?
    var note: String = ""

    var sireCohort: Cohort?               // 雄側の群
    var damCohort: Cohort?                // 雌側の群。sire と同じ群でもよい
    var tank: Tank?
    var offspringStrain: Strain?          // 子の系統。同系統なら親と同じ、交配なら新規

    @Relationship(deleteRule: .cascade, inverse: \EggBatch.breedingSet) var eggBatches: [EggBatch]?

    var isActive: Bool { endedAt == nil }
}

@Model final class EggBatch {
    var id: UUID = UUID()
    var collectedAt: Date = Date()        // 採卵日
    var eggCount: Int?
    var containerName: String = ""        // 採卵カップ名など。容器登録がなくてもよい
    var waterTempC: Double?
    var statusRaw: String = EggBatchStatus.incubating.rawValue
    var hatchedAt: Date?
    var hatchedCount: Int?
    var note: String = ""

    var breedingSet: BreedingSet?
    var container: Tank?                  // 登録済み容器で育卵する場合

    @Relationship(deleteRule: .nullify, inverse: \Cohort.originBatch) var resultCohorts: [Cohort]?
}

@Model final class SelectionEvent {
    var id: UUID = UUID()
    var date: Date = Date()
    var round: Int = 1                    // 1、2、3。その他は0
    var criteria: [String] = []           // "体型" "色" "ラメ" "体外光" "ヒレ" ほか自由入力
    var keptCount: Int = 0
    var culledCount: Int = 0
    var cullDestinationRaw: String = CullDestination.feed.rawValue
    var culledCohortID: UUID?             // 別容器へ分割したときの群
    var note: String = ""

    var cohort: Cohort?
    @Relationship(deleteRule: .cascade, inverse: \Photo.selection) var photos: [Photo]?
}

@Model final class Sale {
    var id: UUID = UUID()
    var date: Date = Date()
    var unitRaw: String = SaleUnit.fish.rawValue
    var quantity: Int = 1
    var unitPrice: Int = 0                // 円
    var totalPrice: Int = 0               // 円。既定は quantity × unitPrice、上書き可
    var fee: Int = 0                      // 販売手数料
    var shippingCost: Int = 0
    var channelRaw: String = SaleChannel.yahooAuction.rawValue
    var statusRaw: String = SaleStatus.sold.rawValue
    var shippedAt: Date?
    var buyerMemo: String = ""            // 端末内にだけ保存される
    var note: String = ""
    var breedNameSnapshot: String = ""    // 集計とCSV用のスナップショット
    var lineNameSnapshot: String = ""
    var generation: Int = 0

    var cohort: Cohort?
    var strain: Strain?

    var net: Int { totalPrice - fee - shippingCost }
}

@Model final class MaintenanceLog {
    var id: UUID = UUID()
    var date: Date = Date()
    var kindRaw: String = MaintenanceKind.waterChange.rawValue
    var percent: Int?                     // 水換えの割合
    var waterTempC: Double?
    var note: String = ""
    var tank: Tank?
}

@Model final class Photo {
    var id: UUID = UUID()
    var capturedAt: Date = Date()
    var caption: String = ""
    var isCover: Bool = false             // 代表写真。未設定なら最も古い写真を使う
    @Attribute(.externalStorage) var jpegData: Data = Data()       // 長辺1600px、品質0.8
    @Attribute(.externalStorage) var thumbnailData: Data = Data()  // 長辺320px

    var cohort: Cohort?
    var tank: Tank?
    var strain: Strain?
    var selection: SelectionEvent?
}
```

一覧画面では `thumbnailData` だけを読み、`jpegData` は詳細表示で読む。

### 3.3 設定（UserDefaults）

| キー | 型 | 初期値 | 用途 |
|---|---|---|---|
| `degreeDaysToHatch` | Double | 250 | 孵化に必要な積算温度 |
| `defaultWaterTempC` | Double | 25 | 水温未入力時の既定値 |
| `waterChangeWarningDays` | Int | 14 | 産卵期の水換え警告 |
| `winterWaterChangeWarningDays` | Int | 45 | 産卵期外の水換え警告 |
| `breedingSeasonMonths` | [Int] | [4,5,6,7,8,9] | 産卵期の月 |
| `listingTemplate` | String | 既定の雛形 | 出品文テンプレ |
| `hasCompletedOnboarding` | Bool | false | |
| `lastBackupAt` | Date? | nil | バックアップ案内の判定 |

Proの状態はStoreKitの `Transaction.currentEntitlements` を正とし、UserDefaultsにはキャッシュしない。

## 4. 計算ロジック

### 4.1 孵化予定日（HatchPredictor）

入力：採卵日、ロットの水温（任意）、ロットの容器に記録された日別水温（任意）、設定値。
出力：予定日と、前後1日の幅。

```
accumulated = 0
day = 採卵日の0時
while accumulated < degreeDaysToHatch:
    temp = その日の容器の水温記録 ?? ロットの水温 ?? defaultWaterTempC
    accumulated += max(temp, 0)
    day += 1日
return day
```

容器の水温記録は `MaintenanceLog` の `kind == temperature` を日付で引く。
同じ日に複数あれば平均する。
予定日の表示は「5月12日ごろ（±1日）」とし、残り日数はホームと採卵ロット一覧で使う。
設定値を変えたら即時に再計算する（保存せず都度計算する）。

### 4.2 血統（LineageResolver）

群の `originBatch?.breedingSet` から `sireCohort` と `damCohort` をたどる。
木の各ノードは群、世代、系統名、孵化日、代表写真を持つ。
循環の判定は、いまたどっている経路（根から現在のノードまで）の上だけで行い、経路上に同じ群が現れたら打ち切る。
雄側と雌側に同じ群が出るのは同系統の累代では普通のことなので、両方に表示する。
深さの上限はFreeで2、Proで無制限（実装上は20で打ち切る）。

### 4.3 匹数の整合（CountLedger）

群の匹数を変える操作は全て `CohortEvent` を作る。

- 分割：元の群に `split`（countDelta = −n、relatedCohortID = 新群）、新群に `split`（countDelta = +n、relatedCohortID = 元群）。
- 統合：吸収される群は `statusRaw = merged`、匹数0、`merge` イベント。吸収する群に `merge`（countDelta = +n）。
- 販売：群を指定した販売を保存するとき、匹数を減らすか確認し、減らすなら `countChange`（reason = other、note = "販売"）。匹は数量、ペアは2×数量、トリオは3×数量を減らす。稚魚まとめは減らす匹数を入力させる。卵は減らさない。
- 選別：`keptCount` を群の新しい匹数にし、差分を `countChange`（reason = other、note = "選別"）として記録する。別容器へ弾く場合は分割に委ねる。

匹数は概数であり、イベントの合計と一致しなくてもエラーにしない。
`recount` で修正できる。

誤った記録は出来事を削除して戻す。
削除できるのは各群の最新の出来事だけで、`previousCount`、`previousStageRaw`、`previousStatusRaw` と `fromTankID` で元に戻す。
分割と統合は、相手側の対応する出来事も相手の最新である場合に限り、両方まとめて削除する。
結果が負になる操作は保存前に止める（匹数が `nil` の群は検査しない）。
詳細は `DECISIONS.md` C。

`CountLedger` は値型を受け取って変更内容を返す純粋な関数として書き、SwiftDataへの適用は別の層で行う。
適用部分のテストはインメモリの `ModelContainer` で行う。

### 4.4 Freeの上限（FreeLimits）

| 対象 | 数え方 | 上限 |
|---|---|---|
| 容器 | `isArchived == false` | 6 |
| 系統 | `isArchived == false` | 2 |
| 親魚セット | `endedAt == nil` | 2 |
| 写真 | 同じ所有者（群、容器、系統、選別）に紐づく枚数 | 3 |

全ての数え方で `isSample == true` を除く。
交配の子の系統は、孵化で作られるまで存在しないので数えない。
| 血統図 | 深さ | 2 |

上限に達したときは作成画面の保存時に止め、Proの案内（Paywall）へ誘導する。
既存データの閲覧と編集は上限を超えていても制限しない（Proを解約する手段はないが、バックアップの読み込みで上限超えが起きうるため）。

### 4.5 季節（Season）

今日の月が `breedingSeasonMonths` に含まれれば産卵期。
ホームの並び、水換え警告の日数、通知の文面を切り替える。

### 4.6 出品文（ListingTextBuilder）

雛形の中の差し込み語を群の情報で置き換える。

```
{品種} {系統} {世代} {匹数} {雌雄} {サイズ} {孵化時期} {親の表現} {飼育環境} {死着保証} {注意事項}
```

未入力の差し込み語はその行ごと省く。
`{親の表現}` は `originBatch.breedingSet` の雄と雌の系統の `traitTags` を結合する。
`{飼育環境}` は群の容器の `placementRaw` から「屋外飼育」または「室内飼育」。

## 5. 出力形式

### 5.1 販売CSV（Pro）

UTF-8、BOM付き、CRLF改行、Excelで開ける形にする。
値にカンマ、引用符、改行を含むときは二重引用符で囲む。

```
日付,状態,販路,品種,系統,世代,単位,数量,単価,合計,手数料,送料,純額,発送日,購入者メモ,メモ
2027-05-20,売約,ヤフオク,楊貴妃,〇〇めだか,F1,ペア,1,8000,8000,800,1200,6000,2027-05-22,,
```

### 5.2 群CSV

```
系統,品種,世代,容器,匹数,段階,孵化日,日齢,状態,メモ
```

### 5.3 バックアップ（Freeでも可）

`manifest.json` と `photos/` をApple Archive（`AppleArchive` フレームワーク、LZFSE圧縮）で1ファイルにまとめ、`名前.medakabackup` として `fileExporter` で書き出す。
UTTypeは `com.meldcarta.medakaledger.backup` とし、`public.data` に適合させる。
フォルダ形式（パッケージ）にしないのは、メールやクラウド経由で壊れやすいため。

```
名前.medakabackup/
  manifest.json      // schemaVersion、exportedAt、appVersion、各モデルの配列
  photos/<photoID>.jpg
```

`manifest.json` のモデルはSwiftDataの属性をそのままキーにし、リレーションはIDで表す。
読み込みは `schemaVersion` を見て変換し、未知のバージョンは拒否する。
読み込みモードは「置き換え」（全削除してから入れる）と「追記」（IDが同じものは上書き、なければ追加）。
写真を含めない軽量版（manifest.jsonだけ）も選べる。軽量版は「追記」でだけ読み込める。

バックアップの書き出しと読み込みは `ModelActor` で行い、進捗を表示する。
`ModelActor` は `Task.detached` の中で生成し、メインスレッドで動かないようにする。

## 6. 課金（ProStore）

- 商品：非消耗型1点。Product IDは `LAUNCH.md` の未確定事項で決める。
- `Product.products(for:)` で価格を取得し、Paywallに表示する。
- `purchase()` の結果を検証し、`Transaction.currentEntitlements` を監視して `isPro` を更新する。
- 復元は `AppStore.sync()`。
- 開発中はXcodeのStoreKit Configuration（`MedakaLedger.storekit`）で試す。
- `isPro` は `@Observable` の `ProStore` が持ち、Environmentで配る。

## 7. プロジェクト構成

```
MedakaLedger/
  App/            MedakaLedgerApp.swift, Router.swift, Theme.swift
  Models/         上記の@Modelと列挙型, Settings.swift
  Domain/         HatchPredictor, LineageResolver, CountLedger, FreeLimits, Season, ListingTextBuilder, SampleDataSeeder, Aggregations
  Features/
    Home/  Tanks/  Strains/  Cohorts/  Breeding/  Selection/  Sales/
    Maintenance/  Photos/  Lineage/  Settings/  Paywall/  Onboarding/  Backup/
  Export/         CSVExporter, BackupExporter, BackupImporter
  Store/          ProStore
  Resources/      Localizable.xcstrings, Assets.xcassets
project.yml                  XcodeGenの定義（.xcodeprojはコミットしない）
MedakaLedgerUITests/         画面のスクリーンショット撮影用のUIテスト
.github/workflows/ci.yml     macOSランナーで生成、ビルド、テスト、スクリーンショット
.github/workflows/testflight.yml  手動実行でTestFlightへ配信
MedakaLedgerTests/   Swift Testing
MedakaLedger.storekit
```

各Featureは画面（View）と、その画面の状態と操作を持つ `@Observable` の型を一つ置く。
データ取得は原則として `@Query` で行い、複雑な集計だけ `Domain/` の純粋関数に逃がす。

## 8. テスト方針

Swift Testingで次を必ず書く。

- `HatchPredictor`：既定水温だけ、ロット水温あり、容器の日別水温あり、設定変更の反映、水温0以下の扱い。
- `LineageResolver`：同系統の累代、交配、同じ群を雄雌に使う、循環データ、深さ上限。
- `CountLedger`：分割、統合、販売による減少、選別による更新、負数の拒否。
- `CSVExporter`：引用符とカンマと改行のエスケープ、BOM、空値。
- `BackupExporter/Importer`：書き出しと読み込みの往復で全モデルが一致する、置き換えと追記の違い、未知バージョンの拒否。
- `FreeLimits`：境界値。

画面の動作を検証する自動テストは書かない。
UIテストは、サンプルデータを入れた状態で主要画面を開いてスクリーンショットを撮るためだけに使う（起動引数 `-uiTestSampleData` でサンプルを投入する）。
画面の操作の確認はTestFlightで行う。

## 9. 性能と容量の目安

- 容器100個、群300個、採卵ロット500件、販売1,000件、写真2,000枚で、一覧の表示が1秒以内。
- 写真2,000枚で約1GB（1枚500KB）。設定で現在の容量を表示する。
- `@Query` にはソートと述語を必ず付ける。SwiftDataの述語で表せない集計（最終水換え日、系統ごとの件数と匹数、品種名の重複除去、選別の累計、売上集計）と関係をまたぐ検索は、述語で絞れるところまで絞って取得し、`Domain/Aggregations` でアプリ内で計算する。

## 10. 第2段階で足すもの

- CloudKit同期：`ModelConfiguration(cloudKitDatabase: .automatic)`。モデルは互換の制約で作ってあるため、スキーマ変更は不要の見込み。
- ウィジェット：孵化カウントダウンと水換え期限。ストアは第1週からApp Groupに置いてあるため、データの移行は要らない。
- Apple Intelligence（FoundationModels、iOS 26以上）：出品文の言い換え。`#available` で分岐する。
