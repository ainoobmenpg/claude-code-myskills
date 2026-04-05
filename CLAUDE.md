# CLAUDE.md

This file provides guidance to Claude Code when working in this repository.

## プロジェクト概要

mysk は、初心者向けに公開フローを `仕様策定 -> 実装 -> レビュー` の 3 段階へ絞ったスキル集です。公開コマンドは 5 個だけで、runtime は `commands/` と `templates/mysk/*.md` で完結します。旧コマンド定義は `templates/mysk/legacy-commands/` に archive されています。

`/mysk-help` も公開コマンドだが、表示内容は実運用の 4 コマンド (`/mysk-spec`、`/mysk-implement`、`/mysk-review`、`/mysk-reset`) を中心に要約する。

## ディレクトリ構成

```text
claude-code-myskills(cc-mysk)/
├── commands/                        # 公開コマンドのみ
│   ├── mysk-spec.md
│   ├── mysk-implement.md
│   ├── mysk-review.md
│   ├── mysk-help.md
│   └── mysk-reset.md
├── templates/mysk/
│   ├── legacy-commands/             # 旧コマンド手順の退避先
│   ├── cmux-launch-procedure.md
│   ├── *-prompt.md
│   ├── *-monitor.md
│   └── verify-schema.json
├── docs/
├── tests/
├── experiments/
├── README.md
├── CONTRIBUTING.md
└── CLAUDE.md
```

## 公開コマンド

| コマンド | 役割 | 引数 |
|---------|------|------|
| `/mysk-spec` | 仕様策定の開始または再開 | `[topic_or_run_id]` |
| `/mysk-implement` | `spec.md` を主入力に実装 | `[run_id]` |
| `/mysk-review` | review の開始または再開 | `[run_id]` |
| `/mysk-help` | 公開フローの表示 | なし |
| `/mysk-reset` | 残存 monitor / サブペインのクリーンアップ | `[--force]` |

## 開発時の前提

- `commands/` は公開面だけを持つ
- 実体の複雑な state machine は `commands/` と `templates/mysk/*.md` にある
- `spec.md` が現行フローの source of truth で、`spec-vN.md` は spec review 反映時のバックアップ
- 旧コマンド名は slash command として復活させない
- 利用者向けドキュメントでは old command names を列挙しない

## テスト方針

- `tests/unit/frontmatter.bats` は公開コマンド面を検証する
- `tests/unit/template-vars.bats` と `tests/unit/cross-reference.bats` は public command と template の整合を見る
- review / verify の JSON 契約は `verify-schema.json` と統合テストで守る

```bash
bats tests/unit/*.bats
bats tests/integration/*.bats
```

## ドキュメント同期

変更したら最低限ここを見直すこと。

| 変更内容 | 更新対象 |
|----------|----------|
| 公開コマンドの変更 | `README.md`, `docs/workflow.md`, `FAQ.md`, `CLAUDE.md`, `CONTRIBUTING.md` |
| public template や archive の変更 | `docs/implementation-survey.md`, `docs/testing.md`, 必要なら `docs/MIGRATION.md` |
| review / verify 契約の変更 | `templates/mysk/verify-schema.json`, `docs/implementation-survey.md`, `docs/testing.md`, 統合テスト |

## コミット前チェック

1. 公開コマンド面が 5 個のままか
2. `commands/` と `templates/mysk/*.md` の参照が壊れていないか
3. template 変数と verify schema が壊れていないか
4. README と workflow が初心者向けの公開面に一致しているか

## コミットメッセージ

Conventional Commits を使う。

```text
<type>: <description>
```

例:

```text
feat: simplify public command surface
fix: repair review router resume logic
docs: rewrite beginner workflow docs
```
