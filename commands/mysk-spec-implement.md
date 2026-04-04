---
description: fixed-spec/specから任意で実装計画を作成（大規模変更向け）
argument-hint: "[run_id]"
user-invocable: true
---

# mysk-spec-implement

`fixed-spec.md` または `spec.md` を読み、**任意で** `impl-plan.md` を作る。default lane では必須ではなく、大規模変更や段階実装時の補助コマンドとして使う。

## 入力

- run_id 指定 or `~/.local/share/claude-mysk/` 最新を自動選択
- **データ保存先**: `~/.local/share/claude-mysk/`
- `WORK_DIR`: `git rev-parse --show-toplevel 2>/dev/null || pwd`

## 読み込み対象

優先順位:

1. `~/.local/share/claude-mysk/{run_id}/fixed-spec.md`
2. `~/.local/share/claude-mysk/{run_id}/spec.md`

## 出力先

`~/.local/share/claude-mysk/{run_id}/impl-plan.md`

## 前提

- `fixed-spec.md` または `spec.md` のどちらかが存在すること
- default lane ではこのコマンドは省略可能
- `impl-plan.md` は fixed-spec の scope / constraints / acceptance を具体化する補助であり、仕様を拡張してはならない

## 実行ルール

### 1. run_id 解決

統一アルゴリズムを使用:
1. 引数で run_id が指定されていればそれを使用
2. `WORK_DIR` を取得: `git rev-parse --show-toplevel 2>/dev/null || pwd`
3. `~/.local/share/claude-mysk/` 内のディレクトリを降順ソート
4. 各ディレクトリの `run-meta.json` を読み込む
5. `project_root == WORK_DIR` の最初のディレクトリを選択
6. 該当なしならエラー終了

### 2. 仕様書確認

- `fixed-spec.md` があればそれを主入力とする
- `fixed-spec.md` がなく `spec.md` がある場合は fallback として使う
- 両方ない場合はエラー終了

### 3. 実装計画の作成方針

1. 仕様書の全体を読み、制約条件、受け入れ条件、allowed paths、edge cases を把握する
2. 各タスクはコードブロックレベルまで分解する
3. タスクごとに対応する受け入れ条件を明示する
4. 未確認情報は「確定 / 候補 / 調査必要」で表現する
5. fixed-spec の scope を広げない

## 初回レスポンス形式

run_id、対象仕様書、実装概要、ファイル構成、実装フェーズ（目標 / タスク / 受け入れ条件）を表示。

各タスクは以下を含むこと:

```markdown
### タスクN: [タスク名]
- **対象ファイル**: `path/to/file.ts`（確定 | 候補 | 調査必要）
- **変更箇所**: `functionName()` または L10-30（確定 | 候補 | 調査必要）
- **変更内容**: [具体的な変更内容]
- **対応する受け入れ条件**: [AC番号]
- **依存タスク**: [タスクID]
- **探索キーワード**: [repo探索で使う語]
- **実装メモ**: [実装前に確認すべき点]
- **詳細手順**:
  1. [手順1]
  2. [手順2]
```

## 完了後案内

```
実装計画作成完了。run_id: {run_id}
次: /mysk-implement-start {run_id} で実装を開始
```

`impl-plan.md` が生成された場合にのみ表示する。
