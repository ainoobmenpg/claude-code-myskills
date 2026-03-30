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
2. review.jsonから`project_root`を読み取り、これを`WORK_DIR`に設定
3. review.jsonのfindings読込（フォールバック付き）、verify.jsonのnew_findingsがあれば追加

## パススキーマ

**定義**: `project_root`はreview.jsonに記録されたプロジェクトルートディレクトリを指す。

`file`フィールドは、`project_root`からの相対パスで記録されます（例: `src/auth.ts`、`lib/utils.py`）。

### パス解決アルゴリズム

ファイルを読み取る際は、以下の手順でパスを解決します:

1. `resolved_path = project_root + "/" + file`
2. ファイルが存在する → そのまま使用
3. ファイルが存在しない場合:
   - エラーとして報告（ファイルが見つからない）

## 判定基準

各指摘について以下の基準で判定すること:

- fixed: 問題が完全に解消されており、同等の問題が同じ箇所で再発しない。根本原因が取り除かれていること。
- not_fixed: 問題が未解決、または修正が不十分で問題が残存している。
- unclear: 判断困難（実行結果や動作確認が必要、またはコード差分だけでは判断できない）

**適用上の注記**: diffcheckでは、コード差分に基づいて上記基準で判定する（実行結果は確認しない）。

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

**重要**: verifyへの遷移にはユーザー確認が必要です。

| 条件 | 次アクション |
|------|-------------|
| 未修正highあり | `/mysk-review-fix` で残りの指摘を修正（ループ継続） |
| 全highがfixed | ユーザー確認「verifyを実行しますか？」→ 承認時のみ `/mysk-review-verify` |
| highなし、未修正mediumあり | ユーザー確認「verifyを実行しますか？（medium重要度の指摘が残っています）」→ 承認時のみ `/mysk-review-verify` |

## JSON形式

version, run_id, created_at, type, summary(total/findings/fixed/not_fixed/unclear/high_remaining/medium_remaining), checks[](finding_id/severity/status/note), next_step

**next_stepフィールドの値**:
- highが残っている場合: "/mysk-review-fix で残りの指摘を修正してください。"
- high全fixedの場合: "verifyの実行にはユーザー確認が必要です。diffcheck結果を確認し、ユーザーの指示を待ってください。"

## 完了後案内

diffcheck 完了後：

high 未修正ありの場合：
```
次: /mysk-review-fix で残りの指摘を修正
```

high 全 fixed の場合：
```
次: /mysk-review-verify で最終確認
```

※ high 指摘が存在しない場合は high 全 fixed と同等に扱い、verify へ誘導する

- 上記条件を満たさない（エラー等）場合は案内なし
