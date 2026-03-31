# 移行ガイド: サブエージェント権限制限とverify状態機械統一

## 変更内容の概要

Issue #5（サブエージェント権限過多）と Issue #6（verify状態機械不一致）に対処するための変更です。

### 主な変更点

1. **サブエージェントの権限制限**
   - `--dangerously-skip-permissions` フラグの削除（既定動作）
   - trust確認の自動承認の廃止
   - 環境変数 `MYSK_SKIP_PERMISSIONS` による制御

2. **verify状態機械の統一**
   - 単一のJSON schemaファイル (`verify-schema.json`) の作成
   - 各テンプレートからのschema参照

## 互換性情報

### 既存ワークフローの維持範囲

**維持される機能**:
- 全てのスラッシュコマンドの引数形式
- 各コマンドの戻り値形式
- JSONファイルのデータ構造

**変更される動作**:
- trust確認: 自動承認 → ユーザー操作待機
- 権限確認: 常にスキップ → 環境変数制御

### 破壊的変更

なし。既存のワークフローは機能し続けます。

## 移行手順

### 1. 環境変数の設定（オプション）

既存の動作（権限スキップ）を維持したい場合:

```bash
export MYSK_SKIP_PERMISSIONS=true
```

### 2. テンプレートの更新

新しいテンプレートは自動的に使用されます:

- `~/.claude/templates/mysk/cmux-launch-procedure.md`
- `~/.claude/templates/mysk/review-verify-prompt.md`
- `~/.claude/templates/mysk/review-verify-monitor.md`
- `~/.claude/templates/mysk/verify-schema.json`

### 3. 既存ワークフローの確認

以下のコマンドで動作を確認してください:

```
/mysk-spec-draft [topic]
/mysk-review-check [run_id]
```

## 既知の問題

### trust確認の待機時間

trust確認時にユーザー操作が必要なため、コマンド実行時間が長くなる可能性があります。

### 対処法

- 自動実行が必要な場合は `MYSK_SKIP_PERMISSIONS=true` を設定してください
- または、Claude Codeのtrust設定を事前に確認してください

## 移行スケジュール

1. **2026-03-31**: 変更のリリース
2. **警告期間**: 2バージョン間（約2ヶ月間）
3. **完全移行**: 警告期間経過後、権限スキップオプションの検討

## サポート

移行に関する問題や質問がある場合は、GitHub Issuesにて報告してください。
