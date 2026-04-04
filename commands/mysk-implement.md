---
description: spec.mdを主入力に実装を進める
argument-hint: "[run_id]"
user-invocable: true
---

# mysk-implement

確定済みの `spec.md` を主入力に実装を進める。公開面では `/mysk-spec` の次に使う唯一の実装コマンド。

## 入力

- run_id 指定、または `~/.local/share/claude-mysk/` から現在のプロジェクトに対応する最新 run を自動選択
- データ保存先: `~/.local/share/claude-mysk/`
- `WORK_DIR`: `git rev-parse --show-toplevel 2>/dev/null || pwd`

## 読み込み優先順位

1. ユーザーの明示指示
2. `~/.local/share/claude-mysk/{run_id}/spec.md`
3. repo の実コードと既存テスト
4. legacy 互換の補助ファイル
   - `fixed-spec.md`
   - `impl-plan.md`

`spec.md` と repo 実態が矛盾する場合は、まず repo を確認し、必要ならその差分をユーザーに短く報告すること。`fixed-spec.md` と `impl-plan.md` は補助入力であり、source of truth ではない。

## 実行ルール

1. run_id を解決する
2. `spec.md` を探す
3. `spec.md` がない場合のみ legacy 互換として `fixed-spec.md` を探す
4. `spec.md` も `fixed-spec.md` もない場合は、`先に /mysk-spec を実行してください` と伝えて終了する
5. 対象 spec の scope / constraints / acceptance を読み、repo を探索して最小変更単位を決める
6. 必要なコード変更とテスト変更を実装する
7. 完了したら変更ファイルと検証結果を要約し、次に `/mysk-review {run_id}` を案内する

## 実装原則

- 初心者向けフローなので、曖昧な点は repo 探索で埋めてから進める
- `spec.md` に書かれていない作業を広げすぎない
- テストや既存規約を壊さない
- 大きい変更でも、ユーザーに legacy コマンド名を見せない

## 完了時の返却

以下を短く返すこと。

- `run_id`
- 主な変更ファイル
- 実行した確認
- 次ステップ: `/mysk-review {run_id}`

