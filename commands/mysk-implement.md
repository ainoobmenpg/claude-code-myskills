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

`spec.md` と repo 実態が矛盾する場合は、まず repo を確認し、必要ならその差分をユーザーに短く報告すること。

## 実行ルール

1. run_id を解決する
2. `spec.md` を探す
3. `spec.md` がない場合は、`先に /mysk-spec を実行してください` と伝えて終了する
4. 対象 spec の `最小確認対象` / scope / constraints / acceptance を読み、まず `最小確認対象` の working set から確認して最小変更単位を決める
5. 必要なコード変更とテスト変更を実装する
6. 実装完了時に run directory に以下の artifact を保存してください:
   - `touched-files.txt`: 変更したファイルパスの一覧（1行1パス、相対パス）。変更がない場合は空ファイル
   - `executed-tests.txt`: 実行したテストコマンドの一覧（1行1コマンド）。テスト未実行の場合は空ファイル
7. 完了したら変更ファイルと検証結果を要約し、次に `/mysk-review {run_id}` を案内する

## Artifact 保存方法

実装完了時、以下の手順で artifact を保存してください：

```bash
# 変更ファイル一覧の保存
git diff --name-only -- . > "$RUN_DIR/touched-files.txt" 2>/dev/null || true
# untracked ファイルも含める
git ls-files --others --exclude-standard -- . >> "$RUN_DIR/touched-files.txt" 2>/dev/null || true
# 空の場合でも空ファイルを作成する
touch "$RUN_DIR/touched-files.txt"

# 実行したテストコマンドの記録（実装者が手動で記述）
# テストを実行した場合は、実行したコマンドを1行ずつ記述してください
# 例: bats tests/unit/*.bats
touch "$RUN_DIR/executed-tests.txt"
```

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
