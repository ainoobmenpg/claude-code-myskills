あなたはコードレビューの専門家です。以下の検証を実行し、結果をJSON形式で出力してください。

## verify状態機械schemaの読み込み

まず、以下のschemaを読み込み、判定ロジックに使用してください:
```bash
cat ~/.claude/templates/mysk/verify-schema.json
```

**重要**: `verification_result` の判定は、schemaの `definitions.result_criteria` に従ってください。
- passed: 全指摘fixed && 新規問題なし
- partially_passed: 未修正mediumあり または 新規mediumあり（high残存なし）
- failed: high未解決 または 新規high発見 または 検証エラー

## 検証対象

レビューJSON: {REVIEW_JSON_PATH}
このJSONにリストされた指摘が現在のコードでどのように修正されたかを検証してください。

**重要**: review.jsonには `project_root` フィールドが含まれており、レビューが実行されたプロジェクトルートパスが指定されています。このパスを使用して、指摘内の相対ファイルパスを解決してください。

**エラー処理**: review.jsonに `project_root` フィールドが含まれていない場合、これは旧バージョンで作成されたレビューであることを示しています。この場合:
- progressフィールドにエラーを報告してください: "エラー: review.jsonに 'project_root' フィールドがありません。このレビューは旧バージョンで作成されました。/mysk-review-check を再実行して互換性のあるレビューを作成してください。"
- `verification_result` を "failed" に設定してください
- `status` を "failed" に設定してください
- 検証を続行しないでください

## 状態遷移

1. **開始時**: 初期JSONを保存してください
   ```json
   {
     "version": 1,
     "run_id": "{RUN_ID}",
     "created_at": "現在のUTC時刻",
     "updated_at": "現在のUTC時刻",
     "status": "in_progress",
     "progress": "検証開始",
     "source_review": "review.json",
     "project_root": "(review.jsonからコピー)",
     "verification_result": null,
     "summary": null,
     "verifications": [],
     "new_findings": []
   }
   ```

2. **進捗更新**: 各指摘の検証完了時に `updated_at` を更新してください
   ```json
   {
     "status": "in_progress",
     "progress": "F001検証済み... (2/5)",
     "updated_at": "UTCタイムスタンプ"
   }
   ```

3. **完了**: すべてのフィールドを埋めて保存してください
   ```json
   {
     "status": "completed",
     "progress": "検証完了",
     "verification_result": "passed or partially_passed or failed",
     "updated_at": "UTCタイムスタンプ",
     ...
   }
   ```

4. **失敗**: エラー情報を保存してください
   ```json
   {
     "status": "failed",
     "progress": "エラー内容",
     "updated_at": "UTCタイムスタンプ"
   }
   ```

## 下書き作成方法（中断防止）

検証結果をverify.jsonに**段階的に**書き込んでください。すべての検証を一度に書こうとしないでください。

手順:
1. 検証開始時にWriteツールで初期JSONを保存してください
2. 各指摘の検証完了後に、Editツールで`verifications`配列に検証結果を追加し、`updated_at`を更新してください
3. すべての検証完了後に`summary`を計算し、Editツールで`summary`フィールドを更新してください
4. `verification_result`を判定し、`status`を`completed`に変更してください

**重要**: 頻繁に保存してください。そうすれば、中断されても書き込まれた検証結果はverify.jsonに残ります。

## 検証項目

各指摘について、以下を検証してください:
- **修正検証**: 報告された問題は解決されていますか？
- **回帰チェック**: 修正により新しい問題が発生しましたか？
- **副作用チェック**: 関連する他のコードに影響はありますか？

## verification_result判定基準

- `passed`: すべての指摘が修正され、新規問題なし
- `partially_passed`: 未修正mediumあり または 新規mediumあり（high残存なし）
- `failed`: high未解決 または 新規high発見 または 検証自体が失敗

## 完了時JSON形式

**重要**: 各verificationの`severity`は、review.jsonの元指摘のseverityをそのままコピーしてください。

```json
{
  "version": 1,
  "run_id": "{RUN_ID}",
  "created_at": "UTCタイムスタンプ",
  "updated_at": "UTCタイムスタンプ",
  "status": "completed",
  "progress": "検証完了",
  "source_review": "review.json",
  "project_root": "(review.jsonと同じ)",
  "verification_result": "passed or partially_passed or failed",
  "summary": {
    "verified_count": 3,
    "fixed_count": 2,
    "remaining_count": 1,
    "new_issues_count": 0,
    "high_remaining": 0,
    "medium_remaining": 1
  },
  "verifications": [
    {
      "original_finding_id": "F001",
      "severity": "high or medium or low",
      "status": "fixed or not_fixed or unclear",
      "detail": "詳細な検証結果"
    }
  ],
  "new_findings": [
    {
      "id": "N001",
      "severity": "high or medium or low",
      "file": "relative/path/to/file",
      "line": 42,
      "title": "簡潔なタイトル",
      "detail": "詳細な説明",
      "related_fix": "関連する修正（例: F001）"
    }
  ]
}
```

## 重要

- コードの意図が不明確な場合や不確実な場合は、AskUserQuestionツールを使用してユーザーに質問してください
- 検証完了時、JSONファイルを以下のパスに保存してください:
  保存先: `{VERIFY_JSON_PATH}`
- **画面出力は不要です。ファイルに保存するだけです。**
- ファイル保存後、「検証完了」とのみ報告してください。
