---
description: fixed-spec.mdまたはimpl-plan.mdを読み実装を実行
argument-hint: "[run_id]"
user-invocable: true
---

# mysk-implement-start

`fixed-spec.md` を主入力として実装を開始する executor 専用コマンド。`impl-plan.md` は任意の補助入力として扱う。

## 入力

- run_id 指定 or `~/.local/share/claude-mysk/` 最新を自動選択
- **データ保存先**: `~/.local/share/claude-mysk/`
- `WORK_DIR`: `git rev-parse --show-toplevel 2>/dev/null || pwd`

## 読み込み対象

優先順位:

1. `~/.local/share/claude-mysk/{run_id}/fixed-spec.md`
2. `~/.local/share/claude-mysk/{run_id}/spec.md`
3. `~/.local/share/claude-mysk/{run_id}/impl-plan.md`（存在する場合のみ）

## 前提

- `fixed-spec.md` または `spec.md` のどちらかが存在すること
- default lane では `fixed-spec.md` を source of truth にする
- `impl-plan.md` は optional。大規模変更や段階実装時だけ使う

## 実行ルール

### 情報の判断優先順位

`/mysk-implement-start` は以下の優先順位で情報を判断する:

1. **ユーザーの明示指示**
2. **fixed-spec.md / spec.md の要求** — scope、constraints、acceptance、allowed paths
3. **repo の実コード** — 実際のファイル、関数、型、テストの実態
4. **impl-plan.md の詳細記述** — ある場合のみ、順序と実装ヒントに使う

`impl-plan.md` の情報が fixed-spec や repo 実態と矛盾する場合、fixed-spec / repo 実態を正とする。

### 質問ルール

- fixed-spec が存在する場合、**`max_clarification_questions = 0` を基本とする**
- fixed-spec と repo 探索で解決できる範囲は自己決定する
- 本当に block した場合のみ、どこが fixed-spec に欠けているかを明示して質問する

### プリフライト手順

各タスク着手前に以下を行う:

1. `fixed-spec.md` または `spec.md` の該当箇所（scope / constraints / acceptance）を読む
2. `impl-plan.md` がある場合は対象タスクを読む
3. repo 内で関連ファイル・類似実装・既存パターンを探す
4. 今回触る最小単位のファイル / 関数 / テストを決める
5. 必要ならタスクを実行可能な粒度に再分解する

具体化が不十分なら自己再分解してから進む。再分解結果はコンソールに出力するが、ユーザー確認は待たない。

### メイン実行フロー

1. run_id 解決、`fixed-spec.md` / `spec.md` / `impl-plan.md` の存在確認
2. `fixed-spec.md` があれば primary input として使用
3. `fixed-spec.md` がなく `spec.md` があれば fallback として使用
4. `impl-plan.md` がある場合はフェーズ順で実行
5. `impl-plan.md` がない場合は、受け入れ条件と allowed paths から最小実装 plan をその場で組み立てる
6. エラー発生時は当該フェーズで停止し、status.json に記録する
7. 全フェーズ完了後、review gate として `/mysk-review-check` を案内する

### implementation hints の解釈

#### impl-plan.md がある場合

- 依存タスクが指定されている場合、依存先を先に実行する
- 同一フェーズ内では記述順序を尊重する
- 「調査必要」の項目は repo 探索で具体化する

#### impl-plan.md がない場合

fixed-spec から以下を抽出して最小実装計画を組み立てる:

- 受け入れ条件
- allowed paths
- edge cases / failure modes
- test notes

最低でも以下を定めてから実装する:

- 変更対象ファイル候補
- 実装順序
- 検証方法
- タスク完了条件

### repo 探索手順

- **ファイル探索**: `rg --files`
- **類似実装探索**: `rg -n`
- **呼び出し元探索**: 変更対象がどこから使われているかを確認
- **テスト探索**: 関連テストを読んで期待動作を把握
- **既存規約確認**: 近いディレクトリの責務の切り方とスタイルを確認

### 不明確な点の扱い

repo 探索と `fixed-spec.md` / `spec.md` 参照でも解決できない場合:

1. `fixed-spec.md` を再度読み直す
2. `spec.md` がある場合は補助参照する
3. repo 内のより広い範囲を探索する
4. 実行可能な部分から先に進め、不明箇所は `status.json` に記録する
5. それでも block した場合のみユーザーに質問する

## run_id 解決

統一アルゴリズムを使用:
1. 引数で run_id が指定されていればそれを使用
2. `WORK_DIR` を取得: `git rev-parse --show-toplevel 2>/dev/null || pwd`
3. `~/.local/share/claude-mysk/` 内のディレクトリを降順ソート
4. 各ディレクトリの `run-meta.json` を読み込む
5. `project_root == WORK_DIR` の最初のディレクトリを選択
6. 該当なしならエラー終了

## エラーハンドリング

- run_id ディレクトリ自体が存在しない → エラー表示して終了
- `fixed-spec.md` と `spec.md` の両方が存在しない → 「fixed-spec.md / spec.md が見つかりません。先に /mysk-fixed-spec-draft または /mysk-spec-draft を実行してください」と表示して終了
- `impl-plan.md` が空 or 読み取り不可 → 警告に留め、fixed-spec/spec だけで続行してよい
- 実装中にエラーが発生した場合 → 当該フェーズで停止し、status.json にエラー内容を記録する

## status.json 進捗記録

保存先: `~/.local/share/claude-mysk/{run_id}/status.json`

### 実行中

```json
{
  "status": "in_progress",
  "progress": "フェーズ 2/4 完了",
  "current_phase": 2,
  "total_phases": 4,
  "updated_at": "UTCタイムスタンプ"
}
```

### 完了時

```json
{
  "status": "completed",
  "progress": "実装完了",
  "updated_at": "UTCタイムスタンプ"
}
```

### エラー時

```json
{
  "status": "failed",
  "progress": "フェーズ 3/4 でエラー: [エラー内容]",
  "updated_at": "UTCタイムスタンプ"
}
```

## 完了後案内

全フェーズ完了後、以下を表示する:

```text
実装完了。run_id: {run_id}
変更ファイル: [ファイル一覧]
次ステップ: /mysk-review-check {run_id} でレビューしてください（review gate）
```
