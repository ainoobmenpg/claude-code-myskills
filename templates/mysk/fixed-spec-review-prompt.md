あなたは fixed-spec reviewer です。以下の fixed-spec をレビューし、executor が迷わない短い artifact になっているかを JSON で評価してください。

## 対象

- fixed-spec: {SPEC_PATH}
- 出力先: {REVIEW_PATH}
- ステータスファイル: {STATUS_FILE}
- project_root: {PROJECT_ROOT}

## レビュー観点

1. **executor clarity**: executor が質問なしで着手できるか
2. **scope discipline**: in-scope / out-of-scope / allowed paths が十分か
3. **acceptance clarity**: 受け入れ条件が客観的で検証可能か
4. **edge cases**: failure modes が不足していないか
5. **implementation fit**: repo 実態に照らして実装可能か

## 出力JSON形式

```json
{
  "version": 1,
  "run_id": "{RUN_ID}",
  "created_at": "UTCタイムスタンプ",
  "project_root": "{PROJECT_ROOT}",
  "source": {
    "type": "fixed-spec",
    "value": "fixed-spec タイトル"
  },
  "summary": {
    "overall_quality": "high|medium|low",
    "headline": "全体評価の1行要約",
    "finding_count": {
      "high": 0,
      "medium": 0,
      "low": 0
    }
  },
  "findings": [
    {
      "id": "F1",
      "severity": "high|medium|low",
      "section": "executor_clarity|scope|acceptance|edge_cases|implementation_fit",
      "title": "指摘タイトル",
      "detail": "詳細な説明",
      "suggestion": "改善提案"
    }
  ]
}
```

## ステータス管理

保存先: `{STATUS_FILE}`

### レビュー開始時
```json
{
  "status": "in_progress",
  "progress": "fixed-spec のレビューを開始",
  "updated_at": "UTCタイムスタンプ"
}
```

### 完了時
```json
{
  "status": "completed",
  "progress": "fixed-spec レビュー完了",
  "updated_at": "UTCタイムスタンプ"
}
```

### 失敗時
```json
{
  "status": "failed",
  "progress": "エラー内容",
  "updated_at": "UTCタイムスタンプ"
}
```

## 完了時の手順

1. `{REVIEW_PATH}` にレビュー結果 JSON を保存してください
2. `{STATUS_FILE}` を completed に更新してください
3. 「fixed-spec レビュー完了」とのみ報告してください
