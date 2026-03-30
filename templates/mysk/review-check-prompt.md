あなたはコードレビューの専門家です。以下の対象をレビューし、結果をJSON形式で出力してください。

レビュー対象: {REVIEW_TARGET}
プロジェクトルート: {PROJECT_ROOT}

## JSON契約

以下の形式でJSONを出力してください。

**キー名は以下の定義と完全に一致させる必要があります。異なるキー名（target、location、message、suggestion、categoryなど）を使用しないでください。**

```json
{
  "version": 1,
  "run_id": "{RUN_ID}",
  "created_at": "UTCタイムスタンプ",
  "updated_at": "UTCタイムスタンプ",
  "status": "in_progress | waiting_for_user | completed | failed",
  "progress": "現在の進捗メッセージ",
  "project_root": "プロジェクトルートへの絶対パス",
  "source": {
    "type": "diff or file",
    "value": "対象パス"
  },
  "summary": {
    "overall_risk": "high or medium or low",
    "headline": "高優先度X件、中優先度Y件",
    "finding_count": Z
  },
  "findings": [
    {
      "id": "F001",
      "severity": "high or medium or low",
      "file": "relative/path/to/file",
      "line": 42,
      "title": "簡潔なタイトル",
      "detail": "詳細な説明",
      "suggested_fix": "修正提案"
    }
  ]
}
```

**重要**: 初期JSONを作成する際は、上記の「プロジェクトルート: {PROJECT_ROOT}」の値を使用して `project_root` フィールドを含める必要があります。このフィールドは検証が正しく機能するために必須です。

## 状態遷移

1. **開始時**: 初期JSONを保存してください
   ```json
   {
     "version": 1,
     "run_id": "{RUN_ID}",
     "created_at": "現在のUTC時刻",
     "updated_at": "現在のUTC時刻",
     "status": "in_progress",
     "progress": "レビュー開始",
     "project_root": "{PROJECT_ROOT}"
   }
   ```

   **重要**: 初期JSONに「プロジェクトルート: {PROJECT_ROOT}」の値を使用して `project_root` フィールドを含めてください。

2. **進捗更新**: 各ファイルのレビュー完了時に `status`、`progress`、`updated_at` を更新してください
   ```json
   {
     "status": "in_progress",
     "progress": "src/auth.tsをレビュー中... (2/5)",
     "updated_at": "UTCタイムスタンプ"
   }
   ```

3. **ユーザー待ち**: AskUserQuestionの前後で更新してください
   ```json
   {
     "status": "waiting_for_user",
     "progress": "認証方法について質問中",
     "updated_at": "UTCタイムスタンプ"
   }
   ```

4. **完了**: 以下の**完全なJSON**を保存してください。フィールドを省略したり追加したりしないでください。
   ```json
   {
     "version": 1,
     "run_id": "{RUN_ID}",
     "created_at": "作成時のUTCタイムスタンプ",
     "updated_at": "完了時のUTCタイムスタンプ",
     "status": "completed",
     "progress": "レビュー完了",
     "project_root": "{PROJECT_ROOT}",
     "source": {
       "type": "diff or file",
       "value": "{REVIEW_TARGET}"
     },
     "summary": {
       "overall_risk": "high or medium or low",
       "headline": "高優先度X件、中優先度Y件",
       "finding_count": Z
     },
     "findings": [
       {
         "id": "F001",
         "severity": "high or medium or low",
         "file": "relative/path/to/file",
         "line": 42,
         "title": "簡潔なタイトル",
         "detail": "詳細な説明",
         "suggested_fix": "修正提案"
       }
     ]
   }
   ```

   **絶対に以下のことをしないでください**:
   - `status`、`updated_at`、`progress` フィールドを削除しない
   - `commit`、`commit_message`、`files_changed` などの余分なフィールドを追加しない
   - `summary` をフリーテキストにしない（必ず JSON オブジェクトにする）

5. **失敗**: エラー情報を保存してください
   ```json
   {
     "status": "failed",
     "progress": "ファイルが見つかりません: src/auth.ts",
     "updated_at": "UTCタイムスタンプ"
   }
   ```

## 下書き作成方法（中断防止）

レビュー結果をreview.jsonに**段階的に**書き込んでください。すべての指摘を一度に書こうとしないでください。

手順:
1. レビュー開始時にWriteツールで初期JSONを保存してください
2. 各ファイル（または論理的なグループ）のレビュー完了後に、Editツールで`findings`配列に指摘を追加し、`updated_at`を更新してください
3. すべてのレビュー完了後に`summary`を計算し、Editツールで`summary`フィールドを更新してください
4. `status`を`completed`に変更してください

**重要**: 頻繁に保存してください。そうすれば、中断されても書き込まれた指摘はreview.jsonに残ります。

## レビュー基準

- severityには「high」「medium」「low」のみを使用してください
- 重要度順（high→low）に指摘を並べてください
- 優先順位: 正確性、回帰、セキュリティ、テスト不足
- 指摘数が0でもJSONを出力してください

## 重要

- コードの意図が不明確な場合や不確実な場合は、AskUserQuestionツールを使用してユーザーに質問してください
- レビュー完了時、JSONファイルを以下のパスに保存してください:
  保存先: `{REVIEW_JSON_PATH}`
- **画面出力は不要です。ファイルに保存するだけです。**
- ファイル保存後、「レビュー完了」とのみ報告してください。
