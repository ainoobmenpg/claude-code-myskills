# テストガイド

`mysk` のテストは、Markdown ベースのコマンド定義とテンプレートが壊れていないことを Bats で検証する構成になっています。

## 前提

必要なツール:

- `bats`
- `jq`
- `python3`

インストール確認:

```bash
which bats
which jq
which python3
```

## 実行コマンド

```bash
# ユニットテスト
bats tests/unit/*.bats

# モック統合テスト
bats tests/integration/*.bats

# 全テスト
bats tests/unit/*.bats tests/integration/*.bats
```

個別ファイルだけ確認したい場合:

```bash
bats tests/unit/template-vars.bats
bats tests/integration/review-workflow-mock.bats
```

## テストレイヤ

| レイヤ | 主なファイル | 目的 |
|--------|-------------|------|
| 静的契約 | `tests/unit/frontmatter.bats`, `tests/unit/template-vars.bats`, `tests/unit/json-schema.bats` | 公開コマンド frontmatter、public template 参照、JSON ブロック例の破損を防ぐ |
| ロジック単体 | `tests/unit/run-id.bats`, `tests/unit/path-resolution.bats`, `tests/unit/status-state-machine.bats`, `tests/unit/json-fallback.bats` | run_id 解決、相対パス解決、状態遷移、フォールバック読み取りを確認する |
| モック統合 | `tests/integration/spec-workflow-mock.bats`, `tests/integration/review-workflow-mock.bats`, `tests/integration/monitor-logic.bats`, `tests/integration/verify-termination.bats` | run directory と JSON fixture を使ってフローの接続を検証する |

## helper / fixture の役割

| 場所 | 用途 |
|------|------|
| `tests/helpers/test-common.bash` | 公開コマンド一覧、legacy archive 一覧、テンプレート一覧、frontmatter、テンプレート変数抽出の共通処理 |
| `tests/helpers/fixture-loader.bash` | run directory fixture の展開と最小 JSON 生成 |
| `tests/helpers/validate-json-blocks.py` | Markdown 内の JSON サンプルをプレースホルダ置換して検証 |
| `tests/fixtures/` | 正常系と異常系の run directory / malformed JSON サンプル |

## 変更時の見どころ

### コマンドを変えたとき

- frontmatter が壊れていないか
- public command が top-level template を正しく参照しているか
- 対応テンプレート名が変わったなら `tests/unit/template-vars.bats` が通るか
- run_id 解決や path 解決を変えたなら `tests/unit/run-id.bats` と `tests/unit/path-resolution.bats` を更新したか

### テンプレートを変えたとき

- `{RUN_ID}` などの変数がコマンド側で埋め込まれているか
- monitor の状態名が `in_progress / waiting_for_user / completed / failed` と整合しているか
- JSON サンプルのキー名が monitor のフォールバック読み取りと矛盾していないか

### verify 周りを変えたとき

- `templates/mysk/verify-schema.json`
- `templates/mysk/review-verify-prompt.md`
- `templates/mysk/review-verify-monitor.md`
- `tests/integration/verify-termination.bats`

この 4 箇所はセットで確認するのが前提です。

## カバーしていないもの

現在のテストは主に **静的契約とモックフロー** を見ています。次は直接は検証していません。

- 実際の cmux / tmux 起動
- CronCreate / CronDelete の実動作
- Claude Code 上での live な AskUserQuestion 体験
- ユーザープロジェクトを相手にした本番運用

これらは必要に応じて手動確認や `experiments/` 側のベンチマークで補います。

## 関連ドキュメント

- [README.md](../README.md)
- [workflow.md](workflow.md)
- [implementation-survey.md](implementation-survey.md)
