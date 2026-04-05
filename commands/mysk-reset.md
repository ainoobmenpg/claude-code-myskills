---
description: 残存する監視ジョブとサブペインを片付ける
argument-hint: "[--force]"
user-invocable: true
---

# mysk-reset

mysk の公開フローが途中で止まったときに、残存する監視ジョブとサブペインを片付ける。

## 実行ルール

1. CronList で全ジョブを取得し、次のキーワードを含む prompt を mysk 関連 monitor とみなす
   - `spec-monitor`
   - `spec-review-monitor`
   - `review-check-monitor`
   - `review-verify-monitor`
   - 互換 cleanup 用に `spec-draft-monitor` / `fixed-spec-draft-monitor` / `fixed-spec-review-monitor` も対象に含めてよい
2. 該当ジョブが 0 件なら、その旨を表示して終了する
3. `--force` がなければ、削除件数を表示して確認を取る
4. 各ジョブを CronDelete で削除する
5. 各ジョブの prompt から `--workspace` と `--surface` の値を抽出できる場合は、該当サブペインに `/exit` を送り、`cmux close-surface` で閉じる
6. 完了後の案内は次の公開コマンドだけを使う
   - `/mysk-spec`
   - `/mysk-review`

## 完了時の返却

- 削除した監視ジョブ数
- クローズしたサブペイン数
- まだ手動対応が必要なもの
- 次に再開する公開コマンド
