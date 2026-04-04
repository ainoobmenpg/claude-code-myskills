# 現状実装調査

2026-04-04 時点の `mysk` 実装を、利用者向け説明ではなく「このリポジトリが実際にどう動くか」という観点で整理したメモ。

## リポジトリの性格

このリポジトリは通常のアプリケーションではなく、Claude Code で読み込ませる **スラッシュコマンド定義とテンプレート集** です。実装の中心はソースコードではなく Markdown にあります。

主な層:

| 層 | 主な場所 | 役割 |
|----|----------|------|
| コマンド層 | `commands/` | スラッシュコマンドごとの責務、引数、実行手順、入出力を定義する |
| テンプレート層 | `templates/mysk/` | サブペインへ送る prompt と monitor prompt を定義する |
| 契約層 | `templates/mysk/verify-schema.json` | verify の判定基準と source-of-truth を統一する |
| テスト層 | `tests/` | frontmatter、テンプレート変数、run_id、JSON 契約、状態遷移を検証する |
| 実験層 | `experiments/tri-arm-fixed-spec/` | fixed-spec 運用の比較実験を行う雛形 |

## ワークフロー構成

現在のワークフローは 3 つの塊に分かれています。

### 1. default lane

固定仕様を先に作る標準フローです。

1. `/mysk-fixed-spec-draft`
2. `/mysk-fixed-spec-review`
3. `/mysk-implement-start`
4. `/mysk-review-check`
5. 必要に応じて `/mysk-review-fix -> /mysk-review-diffcheck -> /mysk-review-verify`

### 2. discovery lane

要件整理が必要なときだけ使う対話型フローです。

1. `/mysk-spec-draft`
2. `/mysk-spec-review`
3. 必要なら `/mysk-spec-implement`
4. `/mysk-implement-start`

### 3. review gate

実装後の品質ゲートです。

- `/mysk-review-check`: サブペインでレビュー JSON を作成
- `/mysk-review-fix`: メインセッションで修正計画と修正
- `/mysk-review-diffcheck`: 既存指摘が直ったかを軽量確認
- `/mysk-review-verify`: サブペインで再検証

## コマンド責務マップ

| コマンド | 主入力 | 主出力 | 実装上の要点 |
|---------|--------|--------|-------------|
| `/mysk-fixed-spec-draft` | topic | `fixed-spec-draft.md` | planner prompt は `AskUserQuestion` を禁止し、短い fixed-spec を作る |
| `/mysk-fixed-spec-review` | `fixed-spec.md` か `fixed-spec-draft.md` | `fixed-spec-review.json` | reviewer が fixed-spec を短く実装可能な artifact に整える |
| `/mysk-spec-draft` | topic | `spec-draft.md` | discovery lane。質問を許可し、`waiting_for_user` 状態を使う |
| `/mysk-spec-review` | `spec.md` か `spec-draft.md` | `spec-review.json` | spec の完全性、明確性、一貫性、実現可能性、テスト可能性を評価する |
| `/mysk-spec-implement` | `fixed-spec.md` か `spec.md` | `impl-plan.md` | 任意の補助計画。default lane の必須入力ではない |
| `/mysk-implement-start` | `fixed-spec.md` / `spec.md` / `impl-plan.md` | プロジェクトコードの変更 | 情報の優先順位は「ユーザー指示 -> fixed-spec/spec -> repo 実態 -> impl-plan」 |
| `/mysk-review-check` | Git diff または任意パス | `review.json` | `project_root` を必ず記録し、monitor がその後の検証に引き継ぐ |
| `/mysk-review-fix` | `review.json` | `fix-plan.md` | まず計画を提示して確認を取る。`project_root` がない review はエラー |
| `/mysk-review-diffcheck` | `review.json` と最新 verify | `diffcheck.json` | `verify-rerun.json` を優先し、`new_findings` も確認対象に含める |
| `/mysk-review-verify` | `review.json` と任意の `diffcheck.json` | `verify.json` または `verify-rerun.json` | `verify-schema.json` を使って passed/failed を決める |
| `/mysk-workflow` | なし | なし | `docs/workflow.md` を表示する薄い参照コマンド |
| `/mysk-cleanup` | Cron ジョブ一覧 | なし | 監視ジョブと残存サブペインを一括で掃除する |

## 共通ランタイム

### run directory

成果物は `~/.local/share/claude-mysk/{run_id}/` に保存されます。主要ファイルは次の通りです。

- `run-meta.json`: `run_id`、`project_root`、`created_at`、`topic`
- `status.json`: draft/review 系 monitor が見る状態ファイル
- `review.json`: review gate の入力。`project_root` が必須
- `diffcheck.json`: fix 後の軽量確認結果
- `verify.json` / `verify-rerun.json`: verify の結果
- `timeout-grace.json`: 長時間実行時に monitor が猶予時間を延長したときだけ作る補助ファイル

### run_id 解決

複数コマンドが同じアルゴリズムを使います。

1. 明示的な `run_id` 引数があればそれを使う
2. なければ `git rev-parse --show-toplevel 2>/dev/null || pwd` で `WORK_DIR` を取得する
3. `~/.local/share/claude-mysk/` を新しい順に見て、`run-meta.json.project_root == WORK_DIR` の最初の run を選ぶ
4. 該当がなければエラー

### サブペイン起動

別ペイン系コマンドはすべて `templates/mysk/cmux-launch-procedure.md` を共有します。

このテンプレートが行うこと:

1. `cmux identify` で現在 workspace を特定
2. `cmux new-split` で右ペインを作成
3. `claude --model opus --effort high` を起動
4. `MYSK_SKIP_PERMISSIONS=true` のときだけ `--dangerously-skip-permissions` を付ける
5. Trust 確認を監視しつつ、Claude Code の `❯` プロンプトが出るまで待つ

### monitor 登録

サブペイン起動後、各コマンドは monitor テンプレートを sed で埋め込み、CronCreate に渡します。

monitor の共通動作:

- 完了時は **最初に CronDelete** して重複発火を防ぐ
- その後に要約表示、AskUserQuestion、cleanup を行う
- 長時間 `in_progress` が続く場合は 30 分基準で警告する
- 「待機続行」を選ぶと `timeout-grace.json` に猶予期限と回数を保存する

## JSON 契約

### `status.json`

主に draft/review 系で使います。基本状態は次の 4 つです。

- `in_progress`
- `waiting_for_user`
- `completed`
- `failed`

monitor は `status` 欠落をプロトコル違反として扱い、エラーと cleanup に進みます。

### `review.json`

`/mysk-review-check` の成果物です。重要フィールド:

- `status`
- `progress`
- `updated_at`
- `project_root`
- `source`
- `summary`
- `findings`

review monitor と後続コマンドは、厳密契約に加えて `.issues`、`.location`、`.description` などのフォールバック読み取りも持っています。

### `verify.json` / `verify-rerun.json`

`/mysk-review-verify` の成果物です。`verify-rerun.json` が存在する場合、こちらが最新の真実です。

判定基準は `templates/mysk/verify-schema.json` に集約されています。

- `passed`: すべて fixed、`new_findings` なし、remaining 0
- `failed`: high/medium/low の残存、または新規 finding、または検証エラー

### `diffcheck.json`

`/mysk-review-diffcheck` の成果物です。`checks[]` に既存 finding ごとの `fixed / not_fixed / unclear` 判定を持ちます。`next_step` は verify に自動で進まず、「ユーザー確認待ち」を返す設計です。

## 実装上の重要ポイント

### fixed-spec は first-class artifact

default lane では `fixed-spec.md` が主入力です。`impl-plan.md` は optional で、`/mysk-implement-start` は fixed-spec がある前提で自己決定を優先します。

### `project_root` は review 系の生命線

`/mysk-review-fix`、`/mysk-review-diffcheck`、`/mysk-review-verify` は `review.json.project_root` を使って finding の相対パスを解決します。これがない旧形式 review は、現行フローでは互換扱いではなくエラーです。

### source-of-truth は verify-rerun 優先

verify を再実行すると `verify-rerun.json` が生成されます。後続の diffcheck や運用ドキュメントは、常に rerun を優先して解釈する必要があります。

### discovery lane だけが質問前提

`spec-draft-prompt.md` は質問を許可します。一方、`fixed-spec-draft-prompt.md` は `AskUserQuestion` を禁止し、情報不足は `Assumptions` か `Open Questions` として残す設計です。

## テストとの対応

実装の信頼性は主に Bats で担保されています。

| レイヤ | 主なテスト | 見ているもの |
|--------|-----------|-------------|
| 静的契約 | `tests/unit/frontmatter.bats`, `tests/unit/template-vars.bats`, `tests/unit/json-schema.bats` | frontmatter、テンプレート変数、JSON サンプルの整合 |
| ロジック単体 | `tests/unit/run-id.bats`, `tests/unit/path-resolution.bats`, `tests/unit/status-state-machine.bats` | run_id 解決、相対パス解決、状態遷移 |
| モック統合 | `tests/integration/spec-workflow-mock.bats`, `tests/integration/review-workflow-mock.bats`, `tests/integration/verify-termination.bats` | run directory を使ったフローの接続 |

詳細は [testing.md](testing.md) を参照。

## 補足

- このリポジトリの「実装」は Markdown の手順そのものなので、仕様変更時は `commands/`、`templates/mysk/`、`docs/`、`tests/` をまとめて見る必要がある
- `README.md` と `docs/workflow.md` は利用者向けの整理であり、厳密な truth source は各コマンド定義とテンプレートにある
