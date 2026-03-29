---
description: review.jsonの指摘に対する修正状況を軽量確認
argument-hint: "[run_id]"
user-invocable: true
---

# mysk-review-diffcheck

メインセッションでreview.jsonの指摘リストに照らし、現在のコードが修正されているかを軽量確認する。別ペインは使わず、Sonnet相当で指摘の修正状況のみ確認。

## 入力

- run_id指定 or `~/.local/share/claude-mysk/`最新を自動選択

- **データ保存先**: `~/.local/share/claude-mysk/`
- `WORK_DIR`: `git rev-parse --show-toplevel 2>/dev/null || pwd`（プロジェクト作業ディレクトリ）

## 読み込み対象

1. `~/.local/share/claude-mysk/{run_id}/review.json` — 必須
2. `~/.local/share/claude-mysk/{run_id}/verify.json` — 存在する場合はnew_findingsも確認対象

## 保存先

`~/.local/share/claude-mysk/{run_id}/diffcheck.json`

## 前提

- review.jsonが存在すること

## 実行フロー

1. run_id解決、review.json存在確認
2. review.jsonのfindings読込（フォールバック付き）、verify.jsonのnew_findingsがあれば追加

### review.json フォールバック

サブエージェントがJSON契約に完全準拠しない場合があるため、以下のフォールバックで読み取る:

- **findings配列**: `.findings` → ない場合 `.issues` も試す
- **各finding**:
  - `severity`: `.severity`
  - `file`: `.file` → ない場合 `.location` からコロン前を抽出
  - `line`: `.line` → ない場合 `.location` からコロン後を抽出（ハイフン区切りなら先頭）
  - `title`: `.title`
  - `detail`: `.detail` → ない場合 `.description`
  - `id`: `.id`
- **verify.jsonのnew_findings**: `.new_findings` → ない場合空配列
- **summary**: `.summary.overall_risk` → ない場合 findingsのseverity分布から推定
3. 優先順位: high > medium > low（参考）
4. 各指摘について該当箇所を読み、判定:
   - fixed: 問題解決済み
   - not_fixed: 問題残存
   - unclear: 判断困難（手動確認推奨）
5. 結果報告: run_id、高/中/低重要度の修正状況、未修正high数、次ステップ
6. diffcheck.json保存

## 次ステップ判定

| 条件 | 次アクション |
|------|-------------|
| 全highがfixed | /mysk-review-verify |
| 未修正highあり | /mysk-review-fix |
| highなし、未修正mediumあり | ユーザー確認（既定はverify） |

## JSON形式

version, run_id, created_at, type, summary(total/findings/fixed/not_fixed/unclear/high_remaining/medium_remaining), checks[](finding_id/severity/status/note), next_step
