# Contributing to mysk

このリポジトリは、初心者向けの公開フローを保ちながら、内部の legacy 手順を安全に維持することを重視しています。変更前に [README.md](README.md)、[docs/workflow.md](docs/workflow.md)、[CLAUDE.md](CLAUDE.md) を確認してください。

## 変更方針

- 公開面は `mysk-spec`、`mysk-implement`、`mysk-review`、`mysk-help`、`mysk-reset` に限定する
- 旧コマンドは `templates/mysk/legacy-commands/` にのみ置く
- 利用者向け docs では old command names を slash command として見せない

## 開発環境セットアップ

```bash
git clone https://github.com/ainoobmenpg/claude-code-myskills.git
cd claude-code-myskills

mkdir -p ~/.claude/commands ~/.claude/templates backup
find ~/.claude/commands -maxdepth 1 -type f -name 'mysk-*.md' -exec cp {} backup/ \; 2>/dev/null || true
find ~/.claude/commands -maxdepth 1 -type f -name 'mysk-*.md' -delete

cp commands/*.md ~/.claude/commands/
rm -rf ~/.claude/templates/mysk && ln -sfn "$(pwd)/templates/mysk" ~/.claude/templates/mysk

# Claude Code で /mysk-help を実行
```

## PR の観点

- なぜ公開面を変える必要があるのか
- 初心者向けの使い方が簡単になっているか
- legacy archive の整合性が壊れていないか
- docs と tests が同時に更新されているか

## テスト

```bash
bats tests/unit/*.bats
bats tests/integration/*.bats
bats tests/unit/*.bats tests/integration/*.bats
```

## ドキュメント更新

次の変更では docs 更新が必須です。

| 変更 | 更新対象 |
|------|----------|
| 公開コマンド | `README.md`, `docs/workflow.md`, `FAQ.md`, `CLAUDE.md` |
| legacy 手順 / template | `docs/implementation-survey.md`, `docs/testing.md` |
| インストール / 移行 | `README.md`, `docs/MIGRATION.md`, `CONTRIBUTING.md` |

## コミットメッセージ

Conventional Commits を使用してください。

```text
feat: simplify public command surface
fix: preserve verify rerun precedence
docs: update migration guide for archived commands
```
