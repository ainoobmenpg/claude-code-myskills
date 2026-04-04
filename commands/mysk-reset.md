---
description: 残存する監視ジョブとサブペインを片付ける
argument-hint: "[--force]"
user-invocable: true
---

# mysk-reset

mysk の公開フローが途中で止まったときに、残存する監視ジョブとサブペインを片付ける。

内部では `~/.claude/templates/mysk/legacy-commands/cleanup.md` を使う。手順自体は legacy のままでよいが、ユーザー向けには旧コマンド名を出さないこと。

## 実行ルール

1. `~/.claude/templates/mysk/legacy-commands/cleanup.md` の存在を確認する
2. その手順を実行する
3. 完了後の案内は次の公開コマンドだけを使う
   - `/mysk-spec`
   - `/mysk-review`

## 完了時の返却

- 削除した監視ジョブ数
- クローズしたサブペイン数
- まだ手動対応が必要なもの
- 次に再開する公開コマンド

