# TestFlight配信の準備

版：v1.2（2026-10-22）
`.github/workflows/testflight.yml` を手動実行して、のりさんのiPhoneにTestFlightで配信する（DECISIONS.md A）。
この文書の準備が済むまで、ワークフローは「Secretsが無い」と表示して止まる。

## 1. Apple Developer Program

- Apple Developer Program（個人、年額）に登録する。登録が済むと、App Store ConnectとCertificates, IDsが使える。
- 個人の開発者アカウントではApp Storeに本名が表示される（LAUNCH.md 6章）。

## 2. App Store Connectでアプリを作る

1. App Store Connect → 「マイApp」→「＋」→「新規App」。
2. プラットフォームはiOS、名前は「めだか台帳」（仮。後から変えられる）、プライマリ言語は日本語。
3. バンドルIDは `com.meldcarta.medakaledger`。無ければ、先に Certificates, Identifiers & Profiles の Identifiers で登録する。
4. App Groupは `group.com.meldcarta.medakaledger` を Identifiers の App Groups に登録し、バンドルIDの Capabilities で App Groups を有効にして紐付ける。
   クラウド管理の署名（`-allowProvisioningUpdates`）で自動でも作られるが、うまくいかないときは手で登録する。

## 3. APIキー

1. App Store Connect → ユーザとアクセス → 統合 → App Store Connect API → チームキー → 「＋」。
2. アクセス権は「App管理」（クラウド管理の署名には「Admin」が要る場合がある）。
3. 作成すると、キーID、Issuer ID、`AuthKey_XXXX.p8` が得られる。`.p8` は一度しかダウンロードできない。

## 4. GitHubのSecrets

リポジトリの Settings → Secrets and variables → Actions に、次の4つを登録する。

| 名前 | 値 |
|---|---|
| `ASC_KEY_ID` | APIキーのキーID |
| `ASC_ISSUER_ID` | Issuer ID |
| `ASC_KEY_P8_BASE64` | `.p8` をBase64にした文字列（Macなら `base64 -i AuthKey_XXXX.p8 \| pbcopy`） |
| `APPLE_TEAM_ID` | チームID（Developerサイトの Membership に出る10文字） |

## 5. 配信する

1. GitHubの Actions → TestFlight → Run workflow。
2. 成功すると、数分から数十分後にTestFlightにビルドが現れる（Appleの処理待ち）。
3. TestFlightアプリで自分のApple IDを内部テスターに追加し、iPhoneに入れる。

ビルド番号はワークフローの実行番号（`github.run_number`）になるので、実行のたびに増える。

## 困ったとき

- 「No profiles found」「App Groupが無い」：2章の4を手で行う。
- 「Invalid API key」：Secretsの値とBase64の改行を確かめる。
- 暗号化に関する質問が出る：`ITSAppUsesNonExemptEncryption` を `NO` にしてある。
