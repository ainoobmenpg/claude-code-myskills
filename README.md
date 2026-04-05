# mysk - Claude Code Workflow Skills

mysk は、初心者向けに `仕様策定 -> 実装 -> レビュー` を単純な 3 段階で進める Claude Code 用スキル集です。公開コマンドは最小限に絞り、runtime では `spec.md` を唯一の仕様 artifact として扱います。旧コマンド群は `templates/mysk/legacy-commands/` に参考資料として退避し、`/` 補完に出ないようにしています。

## クイックスタート

前提:

- Claude Code CLI
- `jq`
- `python3`
- `cmux` と `tmux` を使う場合は `/mysk-spec` と `/mysk-review` が利用可能

```bash
# 1. clone
git clone https://github.com/ainoobmenpg/claude-code-myskills.git
cd claude-code-myskills

# 2. 既存の mysk コマンドを退避して公開面を置き換える
mkdir -p ~/.claude/commands ~/.claude/templates backup
find ~/.claude/commands -maxdepth 1 -type f -name 'mysk-*.md' -exec cp {} backup/ \; 2>/dev/null || true
find ~/.claude/commands -maxdepth 1 -type f -name 'mysk-*.md' -delete

# 3. 新しい公開コマンドだけを配置
cp commands/*.md ~/.claude/commands/
rm -rf ~/.claude/templates/mysk && ln -sfn "$(pwd)/templates/mysk" ~/.claude/templates/mysk

# 4. 確認
# Claude Code で /mysk-help を実行
```

コピーではなくシンボリックリンクで使いたい場合も、先に `find ~/.claude/commands ... -delete` で旧コマンドを消してから `ln -sf "$(pwd)/commands/"*.md ~/.claude/commands/` を実行してください。

## 公開コマンド

| コマンド | 役割 | 引数 |
|---------|------|------|
| `/mysk-spec` | Opus で対話しながら仕様を固める。再実行で続きから再開できる | `[topic_or_run_id]` |
| `/mysk-implement` | `spec.md` を主入力に実装する | `[run_id]` |
| `/mysk-review` | Opus review を開始または再開する。内部で fix / diffcheck / verify を回す | `[run_id]` |
| `/mysk-help` | 今の公開フローを表示する | なし |
| `/mysk-reset` | 残存 monitor とサブペインを片付ける | `[--force]` |

旧コマンドは公開廃止です。`/mysk-spec-draft` や `/mysk-review-check` のような名前は `commands/` には存在せず、`/` 補完にも出ません。

## 基本フロー

```mermaid
graph LR
    A["/mysk-spec"] --> B["/mysk-implement"]
    B --> C["/mysk-review"]
    C --> D["完了"]
```

### 使い方の目安

1. `/mysk-spec ユーザー認証機能`
2. `/mysk-implement`
3. `/mysk-review`

`/mysk-spec` と `/mysk-review` は 1 回で全工程を完了しないことがあります。その場合でも、ユーザーは同じコマンドをもう一度実行するだけで続きを進められます。

## コマンドごとの考え方

### `/mysk-spec`

- Opus で対話的に要件を固めます
- 成果物は `spec.md` と `spec-review.json` です
- 仕様が未確定なら、同じ `/mysk-spec {run_id}` で再開します

### `/mysk-implement`

- `spec.md` を source of truth として実装します
- 完了後は `/mysk-review` に進みます

### `/mysk-review`

- 初回は review を開始します
- 以後は run の状態を見て、内部で修正、差分確認、最終確認を切り替えます
- ユーザーに見える操作は最後まで `/mysk-review` だけです

### `/mysk-reset`

- Claude Code や cmux が途中で止まったときの後始末です
- 再開前に一度実行して環境を空にできます

## 依存関係

| 依存 | 必須 | 用途 |
|------|------|------|
| Claude Code CLI | はい | 実行環境 |
| `jq` | はい | JSON 読み取り |
| `python3` | はい | 補助的な JSON / text 処理 |
| `tmux` | `/mysk-spec` と `/mysk-review` で必要 | cmux の前提 |
| `cmux` | `/mysk-spec` と `/mysk-review` で必要 | 別ペイン実行 |
| CronCreate / CronDelete | `/mysk-spec` と `/mysk-review` で必要 | monitor 登録 |

cmux が未導入の場合:

- `/mysk-spec` と `/mysk-review` は利用できません
- `/mysk-implement`、`/mysk-help`、`/mysk-reset` は使えます

## 環境変数

### `CMUX_SOCKET_PATH`

```bash
# macOS
export CMUX_SOCKET_PATH="$HOME/Library/Application Support/cmux/cmux.sock"

# Linux
export CMUX_SOCKET_PATH="$HOME/.config/cmux/cmux.sock"
```

### `MYSK_SKIP_PERMISSIONS`

- 既定値は `false`
- `true` にすると legacy sub-pane 手順が従来寄りの権限スキップ動作を使います

```bash
export MYSK_SKIP_PERMISSIONS=true
```

## run directory

成果物は `~/.local/share/claude-mysk/{run_id}/` に保存されます。代表的なファイル:

- `run-meta.json`
- `spec-draft.md`
- `spec.md`
- `spec-review.json`
- `review.json`
- `fix-plan.md`
- `diffcheck.json`
- `verify.json`
- `verify-rerun.json`
- `status.json`
- `timeout-grace.json`

`run_id` を省略した `/mysk-implement` と `/mysk-review` は、現在の `project_root` に一致する最新 run を自動選択します。

## 内部アーキテクチャ

- `commands/` は公開コマンドだけを置く
- `templates/mysk/*.md` が public flow の prompt / monitor / verify 契約を持つ
- `templates/mysk/legacy-commands/` は過去フローの参考 archive であり、公開コマンドの runtime 依存先ではない

## テスト

```bash
bats tests/unit/*.bats
bats tests/integration/*.bats
bats tests/unit/*.bats tests/integration/*.bats
```

テスト観点の詳細は [docs/testing.md](docs/testing.md) を参照してください。

## 関連ドキュメント

- [docs/workflow.md](docs/workflow.md)
- [docs/implementation-survey.md](docs/implementation-survey.md)
- [docs/testing.md](docs/testing.md)
- [docs/MIGRATION.md](docs/MIGRATION.md)
- [FAQ.md](FAQ.md)
