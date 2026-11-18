# v2.0 検証記録

2026-11-19（日本時間）。対象コード: `eaf15099f60630c7ccccf81073ccc93c8f0b1a3f`。PR: [#13](https://github.com/carta-lab/medaka-ledger/pull/13)。

## 実行済み

| 検証 | 結果 | 範囲・限界 |
|---|---|---|
| Swift 構文解析 | 151 ファイル成功 | Swift 6.4.2 Linux、言語モード 6。型検査・Apple SDK とのリンクは含まない |
| ポータブル部分のビルド | 警告をエラーとして扱い成功 | 既存 `scripts/linux-check.sh` と同じファイル選別・LinuxShim。Docker の代わりに公式 Swift ツールチェーンを使用 |
| ポータブル部分の既存テスト | 175 件 / 21 suites 成功 | 匹数、孵化予測、選別、集計、販売、Free 上限、ProStore など。SwiftData・UIKit 等を必要とするテストは対象外 |
| 差分・JSON | 成功 | `git diff --check`、アセットと文字列カタログの JSON 21 ファイル |
| データと課金の差分 | 変更なし | `Models/`、`Domain/`、`Export/`、`Store/`、`MedakaLedger.storekit`、`project.yml` を元の main と比較 |

構文解析はアプリ・単体テスト・UI テストの `.swift` 全ファイルに `swiftc -frontend -parse -swift-version 6` を適用した。

ポータブル検証は既存スクリプトが定める 23 ソース（LinuxShim を含む）・12 テストファイルを一時 Package に集め、次を実行した。アプリに依存ライブラリは追加していない。

```sh
swift build --package-path .linux-check --build-tests -Xswiftc -warnings-as-errors
swift test --package-path .linux-check --skip-build
```

## 未完了: iOS ビルド・UI テスト・実画面

GitHub Actions の macOS CI は実行開始前に失敗し、ジョブのステップとビルドログが生成されなかった。最初の実行を 1 回再実行し、その後の画面修正コミットでも同じ状態だった。

- [最初の実行と再実行](https://github.com/carta-lab/medaka-ledger/actions/runs/44347661091)
- [最新コードの実行](https://github.com/carta-lab/medaka-ledger/actions/runs/44349623735)

最新の `build-test` チェックは `failure`、ステップは 0、artifact は 0、Annotations は 2 件。使用中の GitHub 連携では Annotations 本文を取得できず、ブラウザでは非公開リポジトリのサインインが必要なため、停止理由の本文は未確認。料金・利用枠・ランナー障害など、具体的な原因は断定していない。

**iOS ビルド成功、SwiftUI の型検査完了、SwiftData を含む全テスト成功、実画面の確認完了とは扱わない。スクリーンショットはまだ取得できていない。** PR は Draft のままとする。

## 再開手順

1. 最新実行の Annotations を確認し、開始前のエラーを解消する。
2. PR の最新コミットで既存の macOS CI を再実行する。
3. ビルド・警告検査・全単体テスト・UI テストを確認し、失敗箇所を修正する。
4. CI が PR に添付する実際の Simulator 画像で、全タブ、入力、空状態、ダークモード、拡大文字を確認する。
5. 実機固有のカメラ・通知・共有・StoreKit は PR の受け入れ手順で確認する。
6. main へのマージは依頼者の承認後とする。
