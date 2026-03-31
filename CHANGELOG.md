# Changelog

All notable changes to mysk will be documented in this file.

## [Unreleased]

### Added
- `MYSK_SKIP_PERMISSIONS` 環境変数による権限制御
- `~/.claude/templates/mysk/verify-schema.json` - verify状態機械の単一schema
- `docs/MIGRATION.md` - 移行ガイド

### Changed
- `cmux-launch-procedure.md`: 権限制限対応（`--dangerously-skip-permissions`削除、trust自動承認削除）
- `review-verify-prompt.md`: verify-schema.json参照対応
- `review-verify-monitor.md`: verify-schema.json参照対応

### Fixed
- Issue #5: サブエージェントの権限が強すぎる（安全設計）
- Issue #6: verify の状態機械が 3 か所で食い違っている

### Security
- サブエージェントの権限制限（既定値: 制限モード）
- trust確認の自動承認廃止（ユーザー操作待機）

## [1.0.0] - 2026-03-31

### Added
- 仕様策定ワークフロー（spec-draft, spec-review, spec-revise, spec-implement）
- コードレビューワークフロー（review-check, review-fix, diffcheck, verify）
- cmux連携による別ペイン実行
- run-meta.jsonによるrun_id解決の統一

### Fixed
- Issue #1: spec-draft の完了フローが成立していない
- Issue #2: spec-review / spec-implement の run_id 省略時解決が壊れている
- Issue #3: implement-start の run_id 解決ルールが自己矛盾
- Issue #4: verify-rerun.json の再実行仕様に実装経路がない
