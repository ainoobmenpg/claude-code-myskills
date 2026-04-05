# 実装調査メモ

2026-04-04 時点の現状実装を、公開面と内部面に分けて整理したメモです。

## 全体像

| 層 | 場所 | 役割 |
|----|------|------|
| 公開コマンド層 | `commands/` | 利用者に見せる最小コマンド面 |
| legacy archive 層 | `templates/mysk/legacy-commands/` | 旧コマンドの具体手順を参考資料として保持 |
| prompt / monitor 層 | `templates/mysk/` | cmux sub-pane に送る prompt / monitor |
| 契約層 | `templates/mysk/verify-schema.json` | verify の判定基準 |
| テスト層 | `tests/` | 公開面、legacy 手順、JSON 契約を Bats で検証 |

## 公開コマンド

| コマンド | 役割 | 主な出力 |
|---------|------|----------|
| `/mysk-spec` | 仕様策定の開始または再開 | `spec.md`, `spec-review.json`, `status.json`, 必要時 `spec-vN.md` |
| `/mysk-implement` | `spec.md` を主入力に実装 | プロジェクトコードの変更 |
| `/mysk-review` | review の開始または再開 | `review.json`, `fix-plan.md`, `diffcheck.json`, `verify*.json` |
| `/mysk-help` | 公開フロー表示 | なし |
| `/mysk-reset` | monitor / サブペイン掃除 | なし |

## legacy archive

`templates/mysk/legacy-commands/` には旧公開コマンドが残っています。

- `spec-draft.md`
- `spec-review.md`
- `implement-start.md`
- `review-check.md`
- `review-fix.md`
- `review-diffcheck.md`
- `review-verify.md`
- そのほか fixed-spec 系と旧 help / cleanup

これらは slash command ではなく、比較や移行確認のための archive です。

## ルーティングの考え方

### `/mysk-spec`

- 新規 topic なら `spec.md` 作成を起動
- spec prompt は `spec.md` を直接更新する
- 旧 run に `spec-draft.md` だけがある場合のみ、互換移行として `spec.md` へコピーする
- 既存 run に `spec.md` があれば spec review へ進める
- spec review 指摘の反映時は `spec-vN.md` バックアップを作成する
- `spec-review.json` の high / medium が 0 なら完了扱い

### `/mysk-implement`

判断優先順位は次の通りです。

1. ユーザー指示
2. `spec.md`
3. repo 実態
4. なし

### `/mysk-review`

- `review.json` がなければ現在の作業ツリー差分を対象に初回 review
- `spec.md` があれば、review-check / verify はそれを scope / constraints / acceptance の source of truth として追加参照する
- 2 回目以降は `review.json` を source of truth に `fix-plan.md` を先に作る
- 修正はユーザー承認後にだけ行い、結果を `diffcheck.json` に反映する
- `diffcheck.json` の remaining がすべて 0 のときだけ、承認後に verify を開始する
- `verify-rerun.json` があれば `verify.json` より優先する
- verify で new high または未解決 high があれば停止し、medium / low だけなら `/mysk-review` に戻す
- ユーザー向けには常に `/mysk-review` とだけ見せる

## run artifacts

現行の run directory で重要なのは次のファイルです。

- `run-meta.json`
- `spec.md`
- `spec-review.json`
- `spec-vN.md`
- `review.json`
- `fix-plan.md`
- `diffcheck.json`
- `verify.json`
- `verify-rerun.json`
- `status.json`

legacy run では次も存在しえます。

- `spec-draft.md`
- `fixed-spec-draft.md`
- `fixed-spec.md`
- `fixed-spec-review.json`
- `impl-plan.md`

## source of truth

### 実装

現行公開フローでは `spec.md` が source of truth です。`spec-vN.md` は review 反映前のバックアップで、`fixed-spec.md` は legacy 互換の補助入力です。

### review

`review.json.project_root` が finding の相対パス解決に必要です。これがない旧 review artifact は現行 `/mysk-review` では再作成が前提です。

### verify

`verify-rerun.json` があれば、それを最新の真実として優先します。判定基準は `templates/mysk/verify-schema.json` に集約されています。

## テストとの対応

- `tests/unit/frontmatter.bats`: 公開コマンド面
- `tests/unit/cross-reference.bats`: legacy 手順と template 参照
- `tests/unit/template-vars.bats`: template 変数の埋め込み漏れ
- `tests/integration/review-workflow-mock.bats`: review state machine
- `tests/integration/spec-workflow-mock.bats`: spec artifact の流れ

## 実装上の含意

- 公開面を減らしても、内部の JSON 契約と state machine は温存できる
- 変更時は `commands/` と `templates/mysk/*.md` を先に確認し、archive は必要時だけ読む
- `/mysk-help` は存在するが、表示内容は実運用の 4 コマンド中心に保つ
- 利用者向け docs では old command names を出さず、内部 docs でのみ archive を説明するのが前提
