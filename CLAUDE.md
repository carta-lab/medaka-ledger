# CLAUDE.md：めだか台帳（仮称）

改良メダカの飼育者向けに、容器、系統、群、採卵、選別、販売をつなげて記録するiPhoneアプリ。
仕様は `docs/` にある。
このファイルは、Claude Codeがこのリポジトリで作業するときの約束事を定める。

## 最初に読む文書

1. `docs/DOMAIN.md`：用語と業務の流れ。画面の文言とモデルの命名の根拠。
2. `docs/PRD.md`：機能要件と受け入れ条件。
3. `docs/ARCHITECTURE.md`：技術方針、データモデル、計算ロジック、出力形式。
4. `docs/SCREENS.md`：画面ごとの構成と操作。
5. `docs/ROADMAP.md`：週ごとの範囲と完了条件。
6. `docs/LAUNCH.md`：未確定事項。
7. `docs/DECISIONS.md`：仕様レビューへの回答。**他の文書と食い違う場合はこちらを優先する。**

## 作業環境

- 作業はLinuxのクラウド環境で行う。Xcodeは無い。企画者はスマホから指示し、結果をGitHubのPRで確認する。
- `.xcodeproj` はXcodeGenの `project.yml` から生成し、コミットしない。ターゲット、ビルド設定（Bundle ID、App Group、Default Actor Isolation、Swift 6）は全て `project.yml` に書く。
- ビルドとテストはGitHub ActionsのmacOSランナーで行う（`.github/workflows/ci.yml`）。pushしたらCIの結果を確認し、失敗していれば直してから報告する。報告には実行のURLと結果を書く。
- 画面を作ったら、その画面のスクリーンショットをCIのUIテストで撮る対象に加える。PRに画像が貼られることを確認してから報告する。
- 報告は企画者がスマホで読む前提で、短く、確認してほしいことを先に書く。
- 作業ブランチにpushし、週ごとにPRを作る。mainへのマージは、のりさんが受け入れ確認の後に行う。タイトルが「第N週: …」のPRがマージされると、`.github/workflows/tag-week.yml` がタグ `wN` を自動で打つ。

## 進め方

- 作業範囲は `docs/ROADMAP.md` の指定された週に限る。次の週の機能に手を出さない。
- 仕様に書かれていない判断が必要になったら、自分で決めずに「要確認」として報告する。仮実装で先に進む場合は、その箇所に `// TODO(要確認): 内容` を残し、報告にも含める。
- 仕様の矛盾を見つけたら、どの文書のどの節が矛盾しているかを示して止まる。
- 週の完了条件を満たしたら、動作確認の手順（どの画面で何をすると何が起きるか）と、テストの実行結果を添えて報告し、止まる。
- コミットは機能単位で小さく。メッセージは日本語で「容器一覧: 置き場所ごとのグリッド表示を追加」の形。

## 技術方針（要点）

- iOS 18.0以上、iPhoneのみ。Swift 6、strict concurrency有効。Default Actor Isolationは `nonisolated` にし、View、Featureのモデル、`ProStore` に `@MainActor` を明示する。
- Bundle IDは `com.meldcarta.medakaledger`、App Groupは `group.com.meldcarta.medakaledger`。ストアはApp Groupのコンテナに置き、`VersionedSchema` で版を管理する。
- SwiftUIとSwiftDataとStoreKit 2。外部ライブラリは入れない。
- 通信はStoreKitだけ。計測、広告、クラッシュ収集のSDKは入れない。
- SwiftDataのモデルはCloudKit互換の制約を守る：全リレーションはOptional、全属性に既定値、`@Attribute(.unique)` を使わない、識別子は自前の `UUID`。
- 列挙型はrawValueの `String` で保存し、型として扱うcomputed propertyを置く。
- 重い処理（バックアップ、写真の縮小、シード生成）は `ModelActor` で行い、`ModelActor` は `Task.detached` の中で生成する。
- 設定値はUserDefaults。Proの状態はStoreKitの権利を正とし、UserDefaultsにキャッシュしない。
- テストはSwift Testing。対象は `Domain/` と `Export/` の純粋なロジック。画面のテストは書かない。

## 構成と命名

- フォルダ構成は `docs/ARCHITECTURE.md` 7章に従う。
- Featureごとに `XxxView.swift` と、状態と操作を持つ `@Observable final class XxxModel`。1画面1ファイルを基本にし、300行を超えたら部品に分ける。
- モデルの型名と属性名は `docs/ARCHITECTURE.md` 3章と同じにする。勝手に増やさない。増やしたいときは要確認。
- 画面に出る文字列は全て `Localizable.xcstrings` に置く。キーは日本語の文言そのものにする。
- 用語は `docs/DOMAIN.md` に従う。「針子」を「稚魚」と書かない。「弾く」を「削除」と書かない。

## コーディングの決まり

- 強制アンラップ（`!`）と `try!` を使わない。失敗は利用者向けの文言で `Alert` に出す。
- 日付は `Calendar.current` を通し、日単位の比較は `startOfDay(for:)` でそろえる。
- 金額は円の `Int`、匹数は `Int`、水温は `Double`。小数の円は扱わない。
- `@Query` には必ずソートを付け、絞り込みは述語で行う。例外として、述語で表せない集計と関係をまたぐ検索は、絞れるところまで絞って取得し、`Domain/Aggregations` でアプリ内で計算してよい（`docs/DECISIONS.md` G）。
- 一覧では `Photo.thumbnailData` だけを読み、`jpegData` は詳細でのみ読む。
- 群の匹数を変える操作は必ず `CountLedger` を通し、`CohortEvent` を残す。
- 削除は確認ダイアログを出す。容器と系統には削除を作らず、アーカイブだけにする。
- 新しい権限（カメラ、写真、通知）を使うときは、使う直前に理由を一行で示してから要求する。

## UIの決まり

- Dynamic Typeに追従する。固定のフォントサイズを使わない。
- 主要なボタンは高さ48pt以上、片手で届く下側に置く。
- 入力の初期値は今日、既定水温、50%のように、仕様で決まったものを入れる。
- 空の状態には次にやることを一文で示す。
- 日本語は自然な言い回しにする。翻訳調（「〜することができます」の連発など）を避け、「〜できます」「〜します」で書く。

## やらないこと

- サーバー、アカウント、ログイン。
- 個体を一匹ずつ登録する機能。
- 固定率や表現の自動判定。
- 弾いた個体の行き先に「放流」を加えること。
- 餌やりの記録。
- Freeの利用者からJSONバックアップの書き出しと読み込みを取り上げること。

## 毎回の確認

作業を終えて報告する前に、次を確かめる。

1. CIのビルドが警告なしで通る。
2. CIで `MedakaLedgerTests` が全て通る。
3. 該当する `docs/PRD.md` の受け入れ条件について、CIのスクリーンショットで見える範囲を確かめ、見えない操作は企画者がTestFlightで確かめる手順を報告に書く。
4. モデルや画面を仕様から変えた場合、該当する文書を先に直してある。
5. 要確認の一覧を更新した。

## よく使うコマンド

```bash
# CIの状況を見る（Linux環境から）
gh run list --limit 5
gh run watch

# Macで開くとき
xcodegen generate && open MedakaLedger.xcodeproj

# StoreKitの動作確認はスキームの StoreKit Configuration に MedakaLedger.storekit を project.yml で設定しておく
```

## 報告の形式

```
## 完了したこと
- 画面や機能の単位で箇条書き

## 動作確認の手順
1. どの画面で、何をすると、何が起きるか

## テスト
- 実行コマンドと結果（件数）

## 要確認
- 仕様に無かった判断と、仮にどうしたか

## 次に着手できること
- 次の週の最初の項目
```
