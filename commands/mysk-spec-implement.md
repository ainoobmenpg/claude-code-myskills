---
description: 仕様書を読み実装計画を作成
argument-hint: "[run_id]"
user-invocable: true
---

# mysk-spec-implement

`/mysk-spec-draft` が保存した仕様書を読み、実装計画を作る。このコマンドは計画作成のみを行い、コード変更は責務外。

## 入力

- run_id指定 or `~/.local/share/claude-mysk/`最新を自動選択

- **データ保存先**: `~/.local/share/claude-mysk/`
- `WORK_DIR`: `git rev-parse --show-toplevel 2>/dev/null || pwd`（プロジェクト作業ディレクトリ）

## 読み込み対象

`~/.local/share/claude-mysk/{run_id}/spec.md`

## 出力先

`~/.local/share/claude-mysk/{run_id}/impl-plan.md`（実装計画の保存）

## 前提

- 仕様書は `/mysk-spec-draft` の出力形式であること
- 必須セクション: 概要、目的、利用者、ユースケース、入出力、スコープ、受け入れ条件

## 実行ルール

1. run_id解決、仕様書読込・構造確認
2. 必須セクション欠如ならエラー終了
3. 実装は行わず、実装計画のみ提示する:
   - 実装概要、ファイル構成、フェーズ分割、各フェーズのタスク、受け入れ条件対応
4. 必要に応じて計画を修正する
5. このコマンドの成果物は「実装計画」であり、コード変更は責務外とする

## 初回レスポンス形式

run_id、対象仕様書、実装概要、ファイル構成、実装フェーズ（目標/タスク/受け入れ条件）を表示。

## 完了後案内

「実装計画作成完了。run_id: {run_id}。次ステップ: /mysk-implement-start {run_id} で実装を開始してください」と表示。

```
次: /mysk-implement-start で実装を開始
```

- impl-plan.md が生成された場合に出力
- 上記条件を満たさない（エラー等）場合は案内なし

## impl-plan.md 保存処理

実装計画の表示内容と同じ内容を `impl-plan.md` に保存する。

- 保存先: `~/.local/share/claude-mysk/{run_id}/impl-plan.md`
- 保存形式: Markdown（表示内容と同一）
- 保存タイミング: 実装計画作成完了時
- 保存失敗時の処理: 警告に留め、計画表示は完了扱いとする（戻り値は成功(0)）
