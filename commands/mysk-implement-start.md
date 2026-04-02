---
description: impl-plan.mdを読み込み実装を実行
argument-hint: "[run_id]"
user-invocable: true
---

# mysk-implement-start

`/mysk-spec-implement` が保存した impl-plan.md を読み込み、フェーズ順にコード実装を一括実行する。

## 入力

- run_id指定 or `~/.local/share/claude-mysk/`最新を自動選択

- **データ保存先**: `~/.local/share/claude-mysk/`
- `WORK_DIR`: `git rev-parse --show-toplevel 2>/dev/null || pwd`（プロジェクト作業ディレクトリ）

## 読み込み対象

`~/.local/share/claude-mysk/{run_id}/impl-plan.md`（`/mysk-spec-implement` が保存）
`~/.local/share/claude-mysk/{run_id}/spec.md`（補助参照）

## 前提

- impl-plan.md が `/mysk-spec-implement` の出力形式であること
- impl-plan.md にはフェーズ構造（Phase N または フェーズ N）が含まれていること

## 実行ルール

1. run_id解決、impl-plan.md 読込・存在確認
2. impl-plan.md が存在しない場合、エラー終了
3. **impl-plan.md の解釈と実行**:
   - フェーズ順にコード実装を一括実行する
   - フェーズ間のユーザー承認を省略し連続実行する
   - エラー発生時は当該フェーズで停止しユーザーの指示を待つ
4. 各フェーズ完了時に status.json を更新する
5. 全フェーズ完了後、`/mysk-review-check` への案内を表示する

### impl-plan.md の解釈ガイドライン

**タスクの実行順序**:
- 依存タスクが指定されている場合、依存先を先に実行する
- 同一フェーズ内では、記述順序を尊重する

**タスクの実行方法**:
1. 対象ファイルを読み込む
2. 変更箇所（行番号または関数名）を特定する
3. 擬似コード/実装イメージを参考に、具体的なコードを実装する
4. 受け入れ条件を満たしていることを確認する
5. 次のタスクへ進む

**不明確な点の扱い**:
- impl-plan.md の記述が不十分な場合は、spec.md を参照して判断する
- spec.md でも判断できない場合は、ユーザーに質問する

## run_id 解決

統一アルゴリズムを使用:
1. 引数で run_id が指定されていればそれを使用（終了）
2. WORK_DIR を取得: `git rev-parse --show-toplevel 2>/dev/null || pwd`
3. `~/.local/share/claude-mysk/` 内のディレクトリを降順ソート
4. 各ディレクトリの run-meta.json を読み込む
5. run-meta.json が存在しないディレクトリは候補から除外
6. run-meta.json の project_root が WORK_DIR と一致する最初のディレクトリを選択
7. 該当なし → エラー終了、run_id 手動指定を促す

## エラーハンドリング

- run_id ディレクトリ自体が存在しない → エラー表示して終了
- impl-plan.md が存在しない → 「impl-plan.md が見つかりません。先に /mysk-spec-implement {run_id} で実装計画を作成してください」と表示して終了
- impl-plan.md が空 or 読み取り不可 → エラー表示して終了
- 実装中にエラーが発生した場合 → 当該フェーズで停止、status.json にエラー内容を記録、ユーザーに指示を仰ぐ

## impl-plan.md の期待フォーマット

- フェーズ見出し: `## フェーズ N` または `## Phase N` 形式（N は 1 起算の整数）
- 各フェーズの必須セクション:
  - 目標またはGoal
  - タスクまたはTasks（**コードブロックレベルで分解されたタスク**）
  - 受け入れ条件またはAcceptance Criteria（箇条書き）

**タスクの記述形式**:

各タスクは以下の情報を含むこと：

```
### タスクN: [タスク名]
- **対象ファイル**: `path/to/file.ts`
- **変更箇所**: L10-30 または `functionName()`
- **変更内容**: [具体的な変更内容]
- **対応する受け入れ条件**: [AC番号]
- **依存タスク**: [タスクID]
- **詳細手順**: [手順の羅列]
- **擬似コード/実装イメージ**: [コードブロック]
```

解析処理はこれらのパターンを前提とし、フォーマットが著しく異なる場合は spec.md へのフォールバックまたはエラー終了とする。

## status.json 進捗記録

保存先: `~/.local/share/claude-mysk/{run_id}/status.json`

**実行中**:
```json
{
  "status": "in_progress",
  "progress": "フェーズ 2/4 完了",
  "current_phase": 2,
  "total_phases": 4,
  "phases": [
    { "phase": 1, "status": "completed", "updated_at": "UTCタイムスタンプ" }
  ],
  "updated_at": "UTCタイムスタンプ"
}
```

**完了時**:
```json
{
  "status": "completed",
  "progress": "実装完了（全フェーズ完了）",
  "current_phase": 4,
  "total_phases": 4,
  "phases": [
    { "phase": 1, "status": "completed", "updated_at": "..." },
    { "phase": 2, "status": "completed", "updated_at": "..." },
    { "phase": 3, "status": "completed", "updated_at": "..." },
    { "phase": 4, "status": "completed", "updated_at": "..." }
  ],
  "updated_at": "UTCタイムスタンプ"
}
```

**エラー時**:
```json
{
  "status": "failed",
  "progress": "フェーズ 3/4 でエラー: [エラー内容]",
  "current_phase": 3,
  "total_phases": 4,
  "phases": [
    { "phase": 1, "status": "completed", "updated_at": "..." },
    { "phase": 2, "status": "completed", "updated_at": "..." },
    { "phase": 3, "status": "failed", "error": "エラー詳細", "updated_at": "..." }
  ],
  "updated_at": "UTCタイムスタンプ"
}
```

## 再実行時の挙動

同一コマンド再実行時、status.json の phases 配列を参照し、status が "completed" のフェーズをスキップして次の未完了フェーズから開始する。

## 完了後案内

全フェーズ完了後、以下を表示する:

```
実装完了。run_id: {run_id}
変更ファイル: [ファイル一覧]
次ステップ: /mysk-review-check {run_id} でレビューしてください
```

```
次: /mysk-review-check でコードレビュー
```

- 実装が完了した場合に出力
- 上記条件を満たさない（エラー等）場合は案内なし
