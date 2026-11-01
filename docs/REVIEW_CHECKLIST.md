# 審査提出の準備チェックリスト

版：v1.0（2026-11-01）
App Storeへ審査に出す前に確かめる項目。`ROADMAP.md` の第6週「審査提出の準備チェックリスト」に当たる。
Appleの要件は変わるので、画面の指定（サイズ、項目名）は、提出時にApp Store Connectの画面で確かめる。この文書には、私が確認できていない仕様の数値を書かない。

凡例：（済）はリポジトリで確認済み。（のりさん）はのりさんの作業。（要確認）は決めるか、調べる必要がある。

## 1. アカウントと識別子

- （のりさん）Apple Developer Program（個人、年額）に登録する。
- （済）Bundle ID `com.meldcarta.medakaledger`、App Group `group.com.meldcarta.medakaledger`（`project.yml`）。
- （のりさん）App Store Connectにアプリを作る。手順は `TESTFLIGHT.md` の2章。
- （のりさん）個人の開発者アカウントでは、App Storeに本名が表示される（`LAUNCH.md` 6章）。表示名を変えたいときは、公開前に屋号か法人の扱いを調べる。

## 2. ビルド

- （のりさん）GitHubのSecrets 4つを入れて、`testflight.yml` を手動実行する（`TESTFLIGHT.md`）。
- （済）CIのビルドが警告なしで通る。`MedakaLedgerTests` が通る。
- （済）`ITSAppUsesNonExemptEncryption` は `NO`（`project.yml`）。独自の暗号を使っていない。
- （のりさん）実機で、購入と復元、写真、CSVの書き出し、バックアップの読み込み、ダークモード、文字の拡大、VoiceOverを確かめる（`PRD.md` の受け入れ条件のうち、CIの画像で見えない操作）。

## 3. アプリ内課金（Pro）

- （済）商品は非消耗型1点、Product ID `com.meldcarta.medakaledger.pro`（`MedakaLedger.storekit`）。
- （要確認）価格。仮に1,200円（`LAUNCH.md` 1章）。
- （のりさん）App Store Connectで同じProduct IDの商品を作り、表示名、説明、価格、審査用のスクリーンショットを入れる。
- （済）Paywallに、価格（StoreKitが返す値）、購入、復元、利用規約（Appleの標準の使用許諾）、プライバシーポリシーがある。

## 4. プライバシー

- （済）`PrivacyInfo.xcprivacy` がある。サーバー、アカウント、計測、広告のSDKは入れていない（`CLAUDE.md`）。
- （済）通信はStoreKitだけ。
- （のりさん）App Privacyの質問に、データを収集しない、と答える。
- （のりさん・要確認）プライバシーポリシーの公開URLとお問い合わせ先を決める。アプリ内の画面には、まだ入っていない（`DECISIONS.md` H 第5週、`TODO(要確認)`）。
- （済）カメラと写真の権限は、使う直前に理由を示してから求める。使用目的の文言は `project.yml` の `NSCameraUsageDescription`、`NSPhotoLibraryAddUsageDescription`。

## 5. ストア掲載

- （のりさん・要確認）アプリ名。「めだか台帳」は仮。App Storeと商標（J-PlatPat）で、同名と類似名を検索する（`LAUNCH.md` 1章）。
- （済）タイトル、サブタイトル、説明、キーワードの下書き（`LAUNCH.md` 3章）。説明の末尾に「記録の道具です。税務や法務の判断はしません」の一行を入れる（`DECISIONS.md` I）。
- （のりさん）スクリーンショット。必要なサイズと枚数はApp Store Connectで確かめる。CIのスクリーンショットはシミュレーターの画面で、ストア用の寸法とは限らない。
- （のりさん）Fireflyで作る画像（`IMAGES.md`）を使うなら、Adobeの利用条件で、アプリとストアでの使用を確かめる。
- （のりさん）サポートURL、カテゴリ（ライフスタイルが仮）、年齢制限の質問への回答。
- （のりさん）サポートの連絡先は、メールアドレス1つ（`LAUNCH.md` 6章）。

## 6. 審査用のメモ

審査員がログインや課金なしで一通り見られる手順を、App Store Connectの「審査に関する情報」に書く。下書き：

```
このアプリは、メダカの飼育者が、容器、系統、採卵、選別、販売を記録する台帳です。
アカウントやログインはありません。データは端末の中だけに保存します。
画面を試すには、アプリを開き、設定（ホーム右上の歯車）の「サンプルデータを入れる」を押してください。
Proの購入は、設定の「Pro」から行えます（買い切り）。
```

- （要確認）上の「サンプルデータを入れる」が、画面の文言と一致しているか、提出時に確かめる（2026-11-01時点では一致している）。

## 7. 提出の直前

- （のりさん）バージョンとビルド番号が、TestFlightで試したものと同じ。
- （のりさん）TestFlightの外部テスターのフィードバックを反映した（`ROADMAP.md` βテスト期間）。
- （のりさん）審査の差し戻しを2回まで見込む（`ROADMAP.md`）。
