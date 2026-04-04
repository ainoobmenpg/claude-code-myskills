---
description: レビューを開始または再開して完了まで進める
argument-hint: "[run_id]"
user-invocable: true
---

# mysk-review

初心者向けの単一 review 入口。公開面ではこの 1 コマンドだけを使う。

内部では `~/.claude/templates/mysk/legacy-commands/` に退避した review 手順を使うが、ユーザーには旧コマンド名を見せないこと。

## 目的

- Opus でレビューを実施する
- 必要なら修正と再確認を進める
- review gate を閉じて完了または要再対応を明確にする

## internal playbook

次の internal playbook を必要に応じて読む。

- `~/.claude/templates/mysk/legacy-commands/review-check.md`
- `~/.claude/templates/mysk/legacy-commands/review-fix.md`
- `~/.claude/templates/mysk/legacy-commands/review-diffcheck.md`
- `~/.claude/templates/mysk/legacy-commands/review-verify.md`

## 実行ルーティング

1. run_id を解決する
2. `RUN_DIR=~/.local/share/claude-mysk/{run_id}` を見る
3. `review.json` がなければ `review-check.md` を読んで初回レビューを開始する
4. `review.json` があり、`verify-rerun.json` または `verify.json` が存在し、最新の `verification_result` が `passed` なら完了として扱う
5. `review.json` があり、最新 verify が `failed` なら `review-fix.md` を実行し、その後 `review-diffcheck.md` を実行する
6. `diffcheck.json` があり、`summary.high_remaining > 0` または `summary.medium_remaining > 0` または `summary.low_remaining > 0` なら `review-fix.md` を実行し、その後 `review-diffcheck.md` を実行する
7. `diffcheck.json` があり、remaining がすべて 0 なら、ユーザーに最終確認へ進むか確認し、承認時だけ `review-verify.md` を実行する
8. `review.json` はあるが `diffcheck.json` がない場合は `review-fix.md` を実行し、その後 `review-diffcheck.md` を実行する

## 公開面での置き換えルール

legacy 手順が次の旧コマンドを案内しても、ユーザー向けにはすべて `/mysk-review` に置き換えること。

- `/mysk-review-check`
- `/mysk-review-fix`
- `/mysk-review-diffcheck`
- `/mysk-review-verify`

例:

- `レビューを開始しました`
- `修正を進めています`
- `差分を再確認しました`
- `最終確認を開始しました`
- `未解決の指摘があります。/mysk-review {run_id} を再実行してください`
- `レビュー完了。指摘は解消されています`

## 返却方針

- 初回レビュー開始時: `run_id`、対象、状態 `started`
- 修正フェーズ再開時: `run_id`、残件要約、状態 `in_progress`
- verify 開始時: `run_id`、状態 `verifying`
- 完了時: `run_id`、結果 `passed`

