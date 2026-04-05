# 移行ガイド

この版では、公開コマンド面を初心者向けに簡素化しました。主な変更は `12` 個の公開コマンドを `5` 個へ整理したことです。

## 何が変わったか

### 公開コマンド

| 旧 | 新 |
|----|----|
| `/mysk-spec-draft`, `/mysk-spec-review` | `/mysk-spec` |
| `/mysk-implement-start`, `/mysk-spec-implement` | `/mysk-implement` |
| `/mysk-review-check`, `/mysk-review-fix`, `/mysk-review-diffcheck`, `/mysk-review-verify` | `/mysk-review` |
| `/mysk-workflow` | `/mysk-help` |
| `/mysk-cleanup` | `/mysk-reset` |

### 内部実装

- 旧コマンド定義は削除ではなく `templates/mysk/legacy-commands/` へ archive
- 公開コマンドは archive を runtime 参照せず、`templates/mysk/*.md` を直接使う
- `spec.md` を公開フローの唯一の仕様入力にした
- review の fix / diffcheck / verify は `/mysk-review` の内部ルーティングに閉じ込めた

## アップグレード手順

```bash
mkdir -p ~/.claude/commands ~/.claude/templates backup
find ~/.claude/commands -maxdepth 1 -type f -name 'mysk-*.md' -exec cp {} backup/ \; 2>/dev/null || true
find ~/.claude/commands -maxdepth 1 -type f -name 'mysk-*.md' -delete

cp commands/*.md ~/.claude/commands/
rm -rf ~/.claude/templates/mysk && ln -sfn "$(pwd)/templates/mysk" ~/.claude/templates/mysk
```

これを行わないと、古い `mysk-*.md` が `~/.claude/commands/` に残り、`/` 補完に old command names が出続けます。

## 互換性

- run directory の JSON 契約は継続利用
- `verify-rerun.json` 優先などの verify state machine は継続
- 旧 run に `spec-draft.md` が残っている場合は、`/mysk-spec` が `spec.md` へ移行してから処理する
- `fixed-spec.md` や `impl-plan.md` は archive 扱いで、現行 `/mysk-implement` の入力には使わない

## 注意点

- `/mysk-spec` と `/mysk-review` は `cmux`、`tmux`、CronCreate / CronDelete が必要
- `review.json.project_root` がない旧 review artifact は現行フローで再利用できないため、`/mysk-review` で作り直す
