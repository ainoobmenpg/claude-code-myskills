---
description: レビューJSONを読み高重要度指摘の修正計画を作成
argument-hint: "[run_id]"
user-invocable: true
---

# mysk-review-fix

`/mysk-review-check` が保存したJSONを読み、高重要度指摘の修正計画を作る。いきなり修正せず、まず計画を提示して確認を取る。

## 入力

- run_id指定 or `~/.local/share/claude-mysk/`最新を自動選択

- **データ保存先**: `~/.local/share/claude-mysk/`
- `WORK_DIR`: `git rev-parse --show-toplevel 2>/dev/null || pwd`（プロジェクト作業ディレクトリ）

## 読み込み対象

`~/.local/share/claude-mysk/{run_id}/review.json`

## 保存先

`~/.local/share/claude-mysk/{run_id}/fix-plan.md`

## 前提

- 入力は `/mysk-review-check` のJSON契約に従うこと
- Markdownレビュー文書や仕様書は入力として扱わない

## 実行ルール

1. run_id解決、review.jsonから`project_root`を読み取り、これを`WORK_DIR`に設定
2. レビューJSON読込・構造確認

## パススキーマ

**定義**: `project_root`はreview.jsonに記録されたプロジェクトルートディレクトリを指す。

`file`フィールドは、`project_root`からの相対パスで記録されます。

**正しい形式**: `.claude/`プレフィックスを含む相対パス
  - 例: `.claude/commands/mysk-workflow.md`

**不正な形式**（避けるべき）:
  - `commands/mysk-workflow.md`（`.claude/`がない）

### パス解決アルゴリズム

ファイルを読み取る際は、以下の手順でパスを解決します:

1. `resolved_path = project_root + "/" + file`
2. ファイルが存在する → そのまま使用
3. ファイルが存在しない かつ `file`が`.claude/`で始まらない場合:
   - `fallback_path = project_root + "/.claude/" + file` を試す
   - 存在すれば `fallback_path` を使用
4. 両方存在しない場合:
   - エラーとして報告（ファイルが見つからない）

**重要**: review.jsonの`file`フィールドには`.claude/`プレフィックスが含まれています（例: `.claude/commands/mysk-workflow.md`）。上記アルゴリズムに従い、`project_root`と連結して正しいファイルパスを解決してください。`.claude/`プレフィックスがないパスの場合は、フォールバック処理により自動で付与して両方試してください。

3. JSON不正または必須キー欠如ならエラー終了
4. 初回レスポンスで編集開始せず、高重要度指摘の修正計画を日本語で提示
5. 中・低重要度は既定で参考扱いのみ
6. 高重要度0件ならその旨返し、必要なら中重要度へ進むかユーザー確認
7. fix-plan.md保存後、「以上の修正を実施してよいですか？」で確認
8. 了承後、highのみ修正（medium以降へは勝手に広げない）

### review.json フォールバック

サブエージェントがJSON契約に完全準拠しない場合があるため、以下のフォールバックで読み取る:

- **findings配列**: `.findings` → ない場合 `.issues` も試す
- **各finding**:
  - `severity`: `.severity`
  - `file`: `.file` → ない場合 `.location` からコロン前を抽出
  - `line`: `.line` → ない場合 `.location` からコロン後を抽出（ハイフン区切りなら先頭）
  - `title`: `.title`
  - `detail`: `.detail` → ない場合 `.description`
  - `suggested_fix`: `.suggested_fix` → ない場合 `.suggestion`
  - `id`: `.id`
- **summary**:
  - finding_count: `.summary.finding_count` → ない場合 `.summary.total` → ない場合 `findings.length`
  - overall_risk: `.summary.overall_risk` → ない場合 findingsのseverity分布から推定（highあり→"high"、mediumのみ→"medium"、lowのみ→"low"）
- **source**: `.source.value` → ない場合 `.target`
- **project_root**: `.project_root`

## 初回レスポンス形式

run_id、対象JSON、高重要度件数、修正対象ファイル、修正方針（ID/ファイル/行/方針）を表示。「以上の修正を実施してよいですか？」で確認。

## 完了後案内

「修正完了。run_id、次ステップ: /mysk-review-diffcheck {run_id} で修正状況を確認してください」と表示。

```
次: /mysk-review-diffcheck で修正状況を確認
```

- fix-plan.md に基づく修正が完了した場合に出力
- 上記条件を満たさない（エラー等）場合は案内なし

## fix-diffcheckループ

修正完了後 `/mysk-review-diffcheck` 案内。未修正highがあれば再度fix、全high修正済みならユーザー確認を経て `/mysk-review-verify` で最終確認。

**重要**: diffcheckからverifyへの遷移にはユーザー確認が必要です。自動では進行しません。
