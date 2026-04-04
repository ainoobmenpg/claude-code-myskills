---
description: 対話で仕様を固めて実装前のrunを確定
argument-hint: "[topic_or_run_id]"
user-invocable: true
---

# mysk-spec

初心者向けの仕様策定入口。公開面ではこの 1 コマンドだけを使う。

内部では `~/.claude/templates/mysk/legacy-commands/` に退避した legacy 手順を段階的に使うが、ユーザーには旧コマンド名や lane 概念を見せないこと。

## 目的

- Opus を使って対話的に要件を固める
- `spec.md` を `/mysk-implement` に渡せる状態まで持っていく
- 実装前の曖昧さを review で減らす

## run の扱い

- 引数が既存 run_id と一致する場合はその run を再開する
- それ以外は新しい topic として扱う
- 成果物は `~/.local/share/claude-mysk/{run_id}/` に保存される

## 実行ルーティング

1. まず `RUN_ID` を決める
   - 引数が既存 run_id なら再開
   - そうでなければ新規 topic として draft を開始
2. 次の internal playbook の存在を確認する
   - `~/.claude/templates/mysk/legacy-commands/spec-draft.md`
   - `~/.claude/templates/mysk/legacy-commands/spec-review.md`
3. 既存 run に `spec-review.json` があり、`summary.finding_count.high == 0` かつ `summary.finding_count.medium == 0` なら、仕様策定は完了として扱う
4. 既存 run に `spec.md` があり、まだ review 完了扱いでなければ、`spec-review.md` を読んでその手順を実行する
5. それ以外は `spec-draft.md` を読んでその手順を実行する

## 公開面での置き換えルール

legacy 手順の中に旧コマンド名が出てきても、ユーザー向けの説明では次の表現に置き換えること。

- draft 開始後: `仕様策定を開始しました`
- review 開始後: `仕様レビューを開始しました`
- spec 修正が必要: `spec.md を更新して /mysk-spec {run_id} を再実行してください`
- 完了時: `次は /mysk-implement {run_id}`

ユーザーに以下を説明してはいけない。

- `/mysk-spec-draft`
- `/mysk-spec-review`
- `/mysk-fixed-spec-*`
- discovery lane / default lane

## 返却形式

- 新規開始時: `run_id`、保存先、状態 `started`
- review 開始時: `run_id`、保存先、状態 `reviewing`
- 完了時: `run_id`、確定した `spec.md`、次ステップ `/mysk-implement {run_id}`

