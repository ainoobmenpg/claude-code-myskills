# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## プロジェクト概要

mysk は Claude Code のスキル集。仕様策定、レビュー、実装計画のワークフローを 9 つのスラッシュコマンドと対応するテンプレートで半自動化する。cmux（tmux ラッパー）と連携し、サブペインで Opus モデルのサブエージェントを起動する。

## ディレクトリ構成

```
claude-code-myskills(cc-mysk)/
+-- commands/                       # スラッシュコマンド定義（.md）
|   +-- mysk-spec-draft.md          # 仕様書下書き（別ペイン Opus）
|   +-- mysk-spec-review.md         # 仕様レビュー（別ペイン Opus）
|   +-- mysk-spec-revise.md         # レビュー指摘の差分更新
|   +-- mysk-spec-implement.md      # 実装計画作成（計画のみ）
|   +-- mysk-implement-start.md     # impl-plan.mdを読み込み実装を実行
|   +-- mysk-review-check.md        # コードレビュー（別ペイン Opus）
|   +-- mysk-review-fix.md          # 修正計画 + 修正
|   +-- mysk-review-diffcheck.md    # 差分確認（軽量）
|   +-- mysk-review-verify.md       # 最終確認（別ペイン Opus）
|   +-- mysk-workflow.md            # 全体ワークフロー参照
|   +-- mysk-cleanup.md             # 残存監視ジョブ・サブペインのクリーンアップ
+-- templates/mysk/                 # cmux 用プロンプト・モニターテンプレート
|   +-- cmux-launch-procedure.md    # サブペイン起動手順
|   +-- spec-draft-prompt.md        # 仕様策定プロンプト
|   +-- spec-draft-monitor.md       # 仕様策定監視
|   +-- spec-review-prompt.md       # 仕様レビュープロンプト
|   +-- spec-review-monitor.md      # 仕様レビュー監視
|   +-- review-check-prompt.md      # コードレビュープロンプト
|   +-- review-check-monitor.md     # コードレビュー監視
|   +-- review-verify-prompt.md     # 最終検証プロンプト
|   +-- review-verify-monitor.md    # 最終検証監視
+-- README.md                       # 利用者向けドキュメント
+-- CLAUDE.md                       # このファイル
+-- LICENSE                         # MIT License
```

## スキル一覧

| コマンド | 説明 | 実行場所 | 引数 |
|---------|------|---------|------|
| `/mysk-spec-draft` | 仕様書下書き作成 | 別ペイン(Opus) | `[topic]` |
| `/mysk-spec-review` | 仕様レビュー | 別ペイン(Opus) | `[run_id]` |
| `/mysk-spec-revise` | 仕様書に指摘を反映 | メイン | `[run_id]` |
| `/mysk-spec-implement` | 実装計画作成（計画のみ） | メイン | `[run_id]` |
| `/mysk-implement-start` | impl-plan.mdを読み込み実装を実行 | メイン | `[run_id]` |
| `/mysk-review-check` | コードレビュー | 別ペイン(Opus) | `[run_id] [path]` |
| `/mysk-review-fix` | 修正計画 + 修正 | メイン | `[run_id]` |
| `/mysk-review-diffcheck` | 差分確認（軽量） | メイン | `[run_id]` |
| `/mysk-review-verify` | 最終確認 | 別ペイン(Opus) | `[run_id]` |
| `/mysk-workflow` | 全体ワークフロー参照 | メイン | なし |
| `/mysk-cleanup` | 残存する監視ジョブとサブペインを一括クリーンアップ | メイン | なし |

## 開発ワークフロー

### ブランチ戦略

**main 直コミット** - 機能ブランチや PR を挟まないシンプルな構成。

### コミット前チェックリスト

コミット前に必ず以下を確認すること：

1. 変更したコマンドファイルの frontmatter（description, argument-hint）が正しいか
2. テンプレート変数（`{RUN_ID}`, `{WORK_DIR}` など）に漏れがないか
3. コマンドとテンプレートの整合性（コマンドが参照するテンプレートが存在するか）

### コミットメッセージ規約

**Conventional Commits** に従う：

```
<type>: <description>
```

| Type | 用途 |
|------|------|
| `feat` | 新コマンド・テンプレート追加 |
| `fix` | バグ修正 |
| `docs` | ドキュメント更新 |
| `refactor` | リファクタリング（機能変更なし） |
| `chore` | 設定、依存関係の更新 |

例:
```
feat: mysk-review-verify コマンドを追加
fix: spec-draft のスラッグ生成でハイフン重複を修正
docs: README にテンプレート一覧を追記
```

## ドキュメント同期

コマンドやテンプレートを変更した際、該当ドキュメントの更新が必要か確認する：

| 変更内容 | 確認するドキュメント |
|----------|---------------------|
| コマンドの追加・削除 | `README.md`（コマンド一覧）、`CLAUDE.md`（スキル一覧） |
| コマンドの引数変更 | `README.md`、`CLAUDE.md`、`mysk-workflow.md` |
| テンプレートの追加・削除 | `README.md`（テンプレート一覧）、`CLAUDE.md`（ディレクトリ構成） |
| ワークフローの変更 | `README.md`（ワークフロー図）、`mysk-workflow.md` |

## Issue 管理

### ラベル運用

Issue 作成時は **種別ラベル** と **優先度ラベル** を必ず付与する。

#### 種別ラベル

| ラベル | 用途 | 例 |
|--------|------|-----|
| `bug` | 不具合報告 | コマンドがエラーで終了する、テンプレート変数が展開されない |
| `enhancement` | 機能追加・改善 | 新しいコマンド追加、テンプレート改善 |
| `documentation` | ドキュメント修正 | README 更新、コメント追加 |
| `question` | 確認事項・相談 | 仕様の判断保留、実装方針の相談 |

#### 優先度ラベル

| ラベル | 優先度 | 基準 |
|--------|--------|------|
| `priority: high` | 高 | コマンドが動作しない、データ損失 |
| `priority: medium` | 中 | 通常のバグ・機能要望 |
| `priority: low` | 低 | 改善案、余裕があれば対応 |

### Issue 作成時の記述内容

- **bug**: 再現手順、期待動作、実際の動作
- **enhancement**: 何をしたいか、なぜ必要か
- **documentation**: 対象ファイル、変更内容

### Issue のクローズ条件

- 修正/実装が完了し、main にコミットされた
- 質問が解決した
- 重複や対応不要と判断された（`duplicate` / `wontfix` を付与）

## 安全ルール

- テンプレート内の機密情報（API キー、トークンなど）を露出しない
- ユーザーのプロジェクトのファイルを誤って変更しない（このリポジトリ内のファイルのみ変更する）
- コマンドファイルとテンプレートの整合性を壊さない（コマンドが参照するテンプレートが存在すること）
- 1 コミット = 1 つの論理的変更。関係ない変更を同じコミットに混ぜない
