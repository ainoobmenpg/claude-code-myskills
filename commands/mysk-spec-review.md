---
description: 仕様書をレビューしJSONで保存
argument-hint: "[run_id]"
user-invocable: true
---

# mysk-spec-review

`/mysk-spec-draft` が保存した仕様書をレビューし、不備や改善点を指摘する。

## 入力

- run_id指定 or `~/.local/share/claude-mysk/`最新を自動選択

- **データ保存先**: `~/.local/share/claude-mysk/`
- `WORK_DIR`: `git rev-parse --show-toplevel 2>/dev/null || pwd`（プロジェクト作業ディレクトリ）

## 読み込み対象

優先: `~/.local/share/claude-mysk/{run_id}/spec.md`
代替: `~/.local/share/claude-mysk/{run_id}/spec-draft.md`

## 保存先

`~/.local/share/claude-mysk/{run_id}/spec-review.json`

## 前提

- 仕様書は `/mysk-spec-draft` の出力形式であること
- 必須セクション: 概要、目的、利用者、ユースケース、入出力、スコープ、受け入れ条件

## 実行ルール

1. run_id解決、仕様書読込・構造確認
2. 必須セクション欠如ならエラー終了
3. レビュー観点: 完全性、明確性、一貫性、実現可能性、テスト可能性
4. JSONで保存、要約を返す

## JSON形式

version, run_id, created_at, source(type/value), summary(overall_quality/headline/finding_count), findings[](id/severity/category/section/title/detail/suggestion)

## メイン会話返却

「仕様書レビュー完了。run_id、対象、サマリ（全体/高/中）、主な指摘（ID/タイトル/対象/影響/提案）、保存先、次ステップ(/mysk-spec-revise)」を表示。
