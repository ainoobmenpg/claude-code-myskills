# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## プロジェクト概要

mysk は Claude Code のスキル集。default lane、discovery lane、review gate からなる **12 個のスラッシュコマンド** と対応テンプレートで、仕様策定からコードレビューまでを半自動化する。cmux（tmux ラッパー）と連携し、サブペインで Opus モデルのサブエージェントを起動する。

## ディレクトリ構成

```
claude-code-myskills(cc-mysk)/
+-- commands/                       # スラッシュコマンド定義（.md）
|   +-- mysk-fixed-spec-draft.md    # fixed-spec 下書き（別ペイン planner）
|   +-- mysk-fixed-spec-review.md   # fixed-spec レビュー（別ペイン reviewer）
|   +-- mysk-spec-draft.md          # 仕様書下書き（別ペイン Opus）
|   +-- mysk-spec-review.md         # 仕様レビュー（別ペイン Opus）
|   +-- mysk-spec-implement.md      # 任意の実装計画作成
|   +-- mysk-implement-start.md     # fixed-spec/spec を主入力に実装
|   +-- mysk-review-check.md        # コードレビュー（別ペイン Opus）
|   +-- mysk-review-fix.md          # 修正計画 + 修正
|   +-- mysk-review-diffcheck.md    # 差分確認（軽量）
|   +-- mysk-review-verify.md       # 最終確認（別ペイン Opus）
|   +-- mysk-workflow.md            # 全体ワークフロー参照
|   +-- mysk-cleanup.md             # 残存監視ジョブ・サブペインのクリーンアップ
+-- templates/mysk/                 # cmux 用プロンプト・モニターテンプレート
|   +-- cmux-launch-procedure.md    # サブペイン起動手順
|   +-- fixed-spec-draft-prompt.md  # fixed-spec 作成プロンプト
|   +-- fixed-spec-draft-monitor.md # fixed-spec 作成監視
|   +-- fixed-spec-review-prompt.md # fixed-spec レビュープロンプト
|   +-- fixed-spec-review-monitor.md # fixed-spec レビュー監視
|   +-- spec-draft-prompt.md        # 仕様策定プロンプト
|   +-- spec-draft-monitor.md       # 仕様策定監視
|   +-- spec-review-prompt.md       # 仕様レビュープロンプト
|   +-- spec-review-monitor.md      # 仕様レビュー監視
|   +-- review-check-prompt.md      # コードレビュープロンプト
|   +-- review-check-monitor.md     # コードレビュー監視
|   +-- review-verify-prompt.md     # 最終検証プロンプト
|   +-- review-verify-monitor.md    # 最終検証監視
|   +-- verify-schema.json          # verify判定基準のJSON Schema
+-- docs/                           # ドキュメント
|   +-- workflow.md                 # ワークフローの詳細ドキュメント
|   +-- implementation-survey.md    # 実装調査と責務分割
|   +-- testing.md                  # テスト方針と実行方法
+-- tests/                          # Bats テスト、fixture、補助スクリプト
+-- experiments/                    # fixed-spec ベンチマーク雛形
+-- README.md                       # 利用者向けドキュメント
+-- CLAUDE.md                       # このファイル
+-- LICENSE                         # MIT License
```

## コマンド一覧

| コマンド | 説明 | 実行場所 | 引数 |
|---------|------|---------|------|
| `/mysk-fixed-spec-draft` | fixed-spec 下書き作成 | 別ペイン(Opus) | `[topic]` |
| `/mysk-fixed-spec-review` | fixed-spec レビュー＋凍結 | 別ペイン(Opus) | `[run_id]` |
| `/mysk-spec-draft` | 仕様書下書き作成 | 別ペイン(Opus) | `[topic]` |
| `/mysk-spec-review` | 仕様レビュー＋反映確認 | 別ペイン(Opus) | `[run_id]` |
| `/mysk-spec-implement` | 実装計画作成（計画のみ） | メイン | `[run_id]` |
| `/mysk-implement-start` | fixed-spec/spec を主入力に実装を実行 | メイン | `[run_id]` |
| `/mysk-review-check` | コードレビュー | 別ペイン(Opus) | `[run_id] [path]` |
| `/mysk-review-fix` | 修正計画と修正 | メイン | `[run_id]` |
| `/mysk-review-diffcheck` | 差分確認（軽量） | メイン | `[run_id]` |
| `/mysk-review-verify` | 最終確認 | 別ペイン(Opus) | `[run_id]` |
| `/mysk-workflow` | 全体ワークフロー参照 | メイン | なし |
| `/mysk-cleanup` | 残存する監視ジョブとサブペインを一括クリーンアップ | メイン | なし |

## 開発ワークフロー

### ブランチ戦略

**main 直コミット** - メンテナー向けワークフロー。機能ブランチや PR を挟まないシンプルな構成。

外部貢献者の場合は [CONTRIBUTING.md](CONTRIBUTING.md) の「プルリクエスト」セクションを参照してください。

### コミット前チェックリスト

コミット前に必ず以下を確認すること：

1. 変更したコマンドファイルの frontmatter（description, argument-hint）が正しいか
2. テンプレート変数（`{RUN_ID}`, `{WORK_DIR}` など）に漏れがないか
3. コマンドとテンプレートの整合性（コマンドが参照するテンプレートが存在するか）
4. 関連する `docs/` と `tests/` が更新されているか

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

### テスト

コマンドやテンプレートを変更した場合は、少なくとも関連する Bats テストを実行すること。

```bash
bats tests/unit/*.bats
bats tests/integration/*.bats
```

テストレイヤの詳細は `docs/testing.md` を参照。

## ドキュメント同期

コマンドやテンプレートを変更した際、該当ドキュメントの更新が必要か確認する：

| 変更内容 | 確認するドキュメント |
|----------|---------------------|
| コマンドの追加・削除 | `README.md`（コマンド一覧）、`CLAUDE.md`（コマンド一覧）、`docs/workflow.md`、`docs/implementation-survey.md` |
| コマンドの引数変更 | `README.md`、`CLAUDE.md`、`docs/workflow.md`、`docs/implementation-survey.md` |
| テンプレートの追加・削除 | `README.md`（テンプレート一覧）、`CLAUDE.md`（ディレクトリ構成）、`docs/implementation-survey.md` |
| ワークフローの変更 | `README.md`（ワークフロー図）、`docs/workflow.md`、`docs/implementation-survey.md` |
| テスト方針の変更 | `docs/testing.md`、必要に応じて `README.md` と `CONTRIBUTING.md` |

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
