---
description: 仕様書にレビュー指摘を差分更新
argument-hint: "[run_id]"
user-invocable: true
---

# mysk-spec-revise

`/mysk-spec-review` で指摘された内容を既存仕様書に反映する。再生成ではなく差分更新。

## 入力

- run_id指定 or `~/.local/share/claude-mysk/`最新を自動選択

- **データ保存先**: `~/.local/share/claude-mysk/`
- `WORK_DIR`: `git rev-parse --show-toplevel 2>/dev/null || pwd`（プロジェクト作業ディレクトリ）

## 読み込み対象

- 仕様書: `~/.local/share/claude-mysk/{run_id}/spec.md`
- レビュー: `~/.local/share/claude-mysk/{run_id}/spec-review.json`

## 保存先

- 旧版: `~/.local/share/claude-mysk/{run_id}/spec-v{N}.md`（バックアップ）
- 改訂版: `~/.local/share/claude-mysk/{run_id}/spec.md`（上書き）

## 前提

- 仕様書とレビューJSONが両方存在すること

## 実行ルール

1. run_id解決、仕様書とレビューJSON読込
   - **run_id省略時**: カレントプロジェクト（WORK_DIR）に一致するproject_rootを持つ最新のrun_idのみを選択
   - **project_rootなしの古いrun**: 候補から除外する
   - 該当するrun_idがない場合: エラーで終了し、run_id手動指定を促す
2. どちらか不在ならエラー
3. レビュー指摘を確認し、修正計画を策定
4. 初回レスポンスで修正計画提示（ユーザー確認後実施）
5. 差分更新: 指摘箇所のみ修正、指摘なし箇所は維持、セクション構成は原則維持
6. バックアップ作成後、改訂履歴を末尾に追加（逆時系列テーブル）

### spec-review.json フォールバック

サブエージェントやメインセッションがJSON契約に完全準拠しない場合があるため、以下のフォールバックで読み取る:

- **findings配列**: `.findings` → ない場合 `.issues` も試す
- **各finding**:
  - `severity`: `.severity`
  - `section`: `.section` → ない場合 `.category`
  - `title`: `.title`
  - `detail`: `.detail` → ない場合 `.description`
  - `suggestion`: `.suggestion` → ない場合 `.suggested_fix`
  - `id`: `.id`
- **summary**:
  - finding_count: `.summary.finding_count` → ない場合 `.summary.total` → ない場合 `findings.length`
  - overall_quality: `.summary.overall_quality` → ない場合 findingsのseverity分布から推定

## 差分更新原則

原則として指摘なし箇所は維持する。ただし以下の最小限の調整は許可する:
- 指摘反映に伴う接続文・前後文脈の調整
- 同一仕様書内での表現統一（用語、敬体、文体の揺れ解消）
- 明らかな誤字・脱字の修正

許可される調整でも、意味や仕様の実質的変更をしてはならない。

例外: 改訂履歴セクションのみ追記許可。

## 初回レスポンス形式

run_id、対象、指摘サマリ、修正計画（ID/重要度/カテゴリ/現状/修正）を表示。「この内容で改訂しますか？（はい / いいえ / 修正して）」で確認。

## 完了報告

「改訂完了。run_id、変更内容、保存先、次ステップ(/mysk-spec-implement)」を表示。

## 完了後案内

改訂完了後：
```
次: /mysk-spec-implement で実装計画を作成
```

- spec.md の差分更新が完了した場合に出力
- 上記条件を満たさない（エラー等）場合は案内なし
