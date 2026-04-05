# mysk - Claude Code Workflow Skills

mysk は、初心者向けに `仕様策定 -> 実装 -> レビュー` を単純な 3 段階で進める Claude Code 用スキル集です。公開コマンド定義ファイルは 5 個だけに絞り、runtime では `spec.md` を実装入力の source of truth として扱います。旧コマンド群は `templates/mysk/legacy-commands/` に参考資料として退避し、`/` 補完に出ないようにしています。

## クイックスタート

前提:

- Claude Code CLI
- `jq`
- `python3`
- `tmux` と `cmux`
- CronList / CronCreate / CronDelete を使える Claude Code 環境

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

`/mysk-help` 自体は公開コマンドですが、表示内容は実運用の 4 コマンド (`/mysk-spec`、`/mysk-implement`、`/mysk-review`、`/mysk-reset`) を中心に案内します。

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

- `/mysk-spec` の初回実行では `spec.md` を作成し、monitor が確認 (`はい / いいえ / 修正して`) を取ります。確定後に同じ `/mysk-spec {run_id}` を再実行して仕様レビューへ進みます。
- `spec-review.json` に high または medium が残る場合、monitor が `spec.md` への反映可否を確認します。反映時は `spec-vN.md` バックアップを作成してから `spec.md` を更新します。
- `/mysk-review` の初回対象は原則として現在の作業ツリー差分です。run に `spec.md` があれば、それも scope / acceptance の判断材料として使います。2 回目以降は `review.json` を source of truth に、修正計画、承認後の修正、`diffcheck.json`、最終 verify を順に進めます。

## コマンドごとの考え方

### `/mysk-spec`

- Opus で対話的に要件を固めます
- spec 作成フェーズでは `spec.md` と `status.json` を段階的に更新します
- 狭いタスクでは、関連ファイルと近傍テストの最小集合から確認し、repo 全体探索は必要時だけに寄せます
- 作成完了後は monitor が `spec.md` の確認を取り、確定後に `/mysk-spec {run_id}` の再実行で仕様レビューへ進みます
- 仕様レビューでは `spec-review.json` を生成します
- review の high / medium が 0 になるまで、同じ `/mysk-spec {run_id}` で再開します

### `/mysk-implement`

- `spec.md` を source of truth として実装します
- 完了後は `/mysk-review` に進みます

### `/mysk-review`

- 初回は現在の作業ツリー差分を対象に `review.json` を生成します
- run に `spec.md` があれば、spec 逸脱や acceptance 未達も review / verify で確認します
- 以後は run の状態を見て、内部で `fix-plan.md` 作成、承認後の修正、`diffcheck.json` 更新、最終 verify を切り替えます
- final verify は `diffcheck.json` の remaining がすべて 0 になった後、ユーザー承認時だけ開始します
- verify で high の未解決や新規 high が見つかった場合は完了扱いにせず停止します
- ユーザーに見える操作は最後まで `/mysk-review` だけです

### `/mysk-reset`

- Claude Code や cmux が途中で止まったときの後始末です
- CronList / CronDelete で mysk monitor を列挙して削除します
- prompt から workspace / surface を復元できる場合だけ、対応する cmux サブペインも閉じます
- 再開前に一度実行して環境を空にできます

## 依存関係

| 依存 | 必須 | 用途 |
|------|------|------|
| Claude Code CLI | はい | 実行環境 |
| `jq` | はい | JSON 読み取り |
| `python3` | はい | 補助的な JSON / text 処理 |
| `tmux` | `/mysk-spec` と `/mysk-review` で必要 | cmux の前提 |
| `cmux` | `/mysk-spec` と `/mysk-review` で必要 | 別ペイン実行と後片付け |
| CronList / CronCreate / CronDelete | `/mysk-spec`、`/mysk-review`、`/mysk-reset` で必要 | monitor の列挙、登録、削除 |

cmux が未導入の場合:

- `/mysk-spec` と `/mysk-review` は利用できません
- `/mysk-implement` と `/mysk-help` は使えます
- `/mysk-reset` は monitor 削除には使えますが、cmux surface のクローズまでは行えません

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
- `true` にすると `cmux-launch-procedure.md` 内の権限制限をスキップします
- `/mysk-spec` と `/mysk-review` の sub-pane 起動に影響します

```bash
export MYSK_SKIP_PERMISSIONS=true
```

## run directory

成果物は `~/.local/share/claude-mysk/{run_id}/` に保存されます。代表的なファイル:

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
- `timeout-grace.json`

`run_id` を省略した `/mysk-implement` と `/mysk-review` は、現在の `project_root` に一致する最新 run を自動選択します。

旧 run や archive 互換では、`spec-draft.md`、`fixed-spec*.md`、`impl-plan.md` などが残ることがあります。現行の公開フローでは primary artifact ではありません。

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
