あなたはコードレビューの専門家です。以下の検証を実行し、結果をJSON形式で出力してください。

## verify状態機械schemaの読み込み

まず、以下のschemaを読み込み、判定ロジックに使用してください:
```bash
cat ~/.claude/templates/mysk/verify-schema.json
```

**重要**: `verification_result` の判定は、schemaの `definitions.result_criteria` に従ってください。
- passed: 全指摘fixed && 新規問題なし
- failed: high/medium/low未解決 または 新規high発見 または 検証エラー

## 検証対象

レビューJSON: {REVIEW_JSON_PATH}
仕様書: {SPEC_PATH}
このJSONにリストされた指摘が現在のコードでどのように修正されたかを検証してください。

`{SPEC_PATH}` が存在する場合は、review 指摘の再検証に加えて、`spec.md` の scope / constraints / acceptance が最終状態で満たされているかも確認してください。

**重要**: review.jsonには `project_root` フィールドが含まれており、レビューが実行されたプロジェクトルートパスが指定されています。このパスを使用して、指摘内の相対ファイルパスを解決してください。

**エラー処理**: review.jsonに `project_root` フィールドが含まれていない場合、これは旧バージョンで作成されたレビューであることを示しています。この場合:
- progressフィールドにエラーを報告してください: "エラー: review.jsonに 'project_root' フィールドがありません。このレビューは旧バージョンで作成されました。/mysk-review {RUN_ID} を再実行して互換性のある review.json を作成してください。"
- `verification_result` を "failed" に設定してください
- `status` を "failed" に設定してください
- 検証を続行しないでください

## 追加コンテキスト

prompt 内に spec snapshot が埋め込まれている場合は、それを acceptance / scope / constraints / 最小確認対象 の primary context として使ってください。必要時だけ `spec.md` の周辺文脈を追加確認してください。

### 最小確認対象スナップショット

```markdown
{SPEC_MINIMUM_CONTEXT}
```

### 受け入れ条件スナップショット

```markdown
{SPEC_ACCEPTANCE_CONTEXT}
```

### スコープスナップショット

```markdown
{SPEC_SCOPE_CONTEXT}
```

### 制約条件スナップショット

```markdown
{SPEC_CONSTRAINTS_CONTEXT}
```

**重要**:
- 受け入れ条件の評価対象は、`spec.md` に実在する項目だけです。推測で acceptance を増やさないでください。
- spec に番号がない場合、`AC1` のような新しいIDを発明せず、元の条件文や短い引用で表現してください。
- acceptance / scope / constraints の検証結果は `verifications[].detail` または `new_findings[].detail` に書いてください。
- `最小確認対象` がある場合は、まずその listed files / tests / commands で検証を始め、十分な根拠がある限り探索を広げないでください。
- `spec_acceptance_check` や `spec_scope_check` など、完了時JSON形式にないトップレベルフィールドを追加しないでください。

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
     "verification_result": "passed or failed",
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

検証結果を{VERIFY_JSON_PATH}に**段階的に**書き込んでください。すべての検証を一度に書こうとしないでください。

手順:
1. 検証開始時にWriteツールで初期JSONを保存してください
2. 各指摘の検証完了後に、Editツールで`verifications`配列に検証結果を追加し、`updated_at`を更新してください
3. すべての検証完了後に`summary`を計算し、Editツールで`summary`フィールドを更新してください
4. `verification_result`を判定し、`status`を`completed`に変更してください

**重要**: 頻繁に保存してください。そうすれば、中断されても書き込まれた検証結果は{VERIFY_JSON_PATH}に残ります。

## 検証項目

各指摘について、以下を検証してください:
- **修正検証**: 報告された問題は解決されていますか？
- **回帰チェック**: 修正により新しい問題が発生しましたか？
- **副作用チェック**: 関連する他のコードに影響はありますか？

`{SPEC_PATH}` が存在する場合は、さらに以下を確認してください:
- `最小確認対象` がある場合、その working set で最終状態を確認できるか。追加探索が必要なら、その理由が changed files や review 指摘に紐づくか
- `受け入れ条件` を満たすコードまたはテスト根拠があるか。評価対象は spec に実在する条件だけとし、推測で acceptance を増やさないこと
- `範囲外` に踏み込む変更が残っていないか
- `制約条件` に反する最終実装になっていないか
- spec の一般ルールと例・期待値の矛盾が、最終実装側で未解決のまま残っていないか
- sanitize / slug / 正規化 / fallback を行う箇所で、全無効入力や空入力が空の識別子・不正な path・危険な key / run id を生まないか
- spec が current behavior を断定している場合、その断定が changed files や近傍テストと矛盾していないか
- helper や current behavior の説明に、helper 自体がしていない前処理・後処理が混ざっていないか
- これらの観点で新しく見つかった問題は `new_findings` に追加すること

## verification_result判定基準

- `passed`: すべての指摘が修正され、新規問題なし
- `failed`: high/medium/low未解決 または 新規high発見 または 検証自体が失敗

## 完了時JSON形式

**重要**: 各verificationの`severity`は、review.jsonの元指摘のseverityをそのままコピーしてください。

**重要**: 完了時JSONのトップレベルフィールドは、以下の定義だけにしてください。余分なトップレベルフィールドを追加しないでください。

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
  "verification_result": "passed or failed",
  "summary": {
    "verified_count": 3,
    "fixed_count": 2,
    "remaining_count": 1,
    "new_issues_count": 0,
    "high_remaining": 0,
    "medium_remaining": 1,
    "low_remaining": 0
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
- `new_findings` に spec 未達を入れる場合は、`detail` に未達の acceptance または制約名を短く書いてください。
- spec の acceptance を参照する場合は、spec に実在する条件文またはその短い引用を使ってください。新しい `AC` 番号は作らないでください。
- ファイル保存後、「検証完了」とのみ報告してください。
