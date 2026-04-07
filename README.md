# mysk - Claude Code Workflow Skills

mysk は、初心者向けに `仕様策定 -> 実装 -> レビュー` を単純な 3 段階で進める Claude Code 用スキル集です。公開コマンド定義ファイルは 6 個だけに絞り、runtime では `spec.md` を実装入力の source of truth として扱います。旧コマンド群は `templates/mysk/legacy-commands/` に参考資料として退避し、`/` 補完に出ないようにしています。

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
| `/mysk-issue` | spec.md をベースに GitHub Issue を作成する | `[run_id]` |
| `/mysk-implement` | `spec.md` を主入力に実装する | `[run_id]` |
| `/mysk-review` | Opus review を開始または再開する。内部で fix / diffcheck / verify を回す | `[run_id]` |
| `/mysk-help` | 今の公開フローを表示する | なし |
| `/mysk-reset` | 残存 monitor とサブペインを片付ける | `[--force]` |

旧コマンドは公開廃止です。`/mysk-spec-draft` や `/mysk-review-check` のような名前は `commands/` には存在せず、`/` 補完にも出ません。

`/mysk-help` 自体は公開コマンドですが、表示内容は実運用の 5 コマンド (`/mysk-spec`、`/mysk-issue`、`/mysk-implement`、`/mysk-review`、`/mysk-reset`) を中心に案内します。

## 基本フロー

```mermaid
graph LR
    A["/mysk-spec"] --> B["/mysk-issue"]
    B --> C["/mysk-implement"]
    C --> D["/mysk-review"]
    D --> E["完了"]
```

### 使い方の目安

1. `/mysk-spec ユーザー認証機能`
2. `/mysk-issue`
3. `/mysk-implement`
4. `/mysk-review`

`/mysk-spec` と `/mysk-review` は 1 回で全工程を完了しないことがあります。その場合でも、ユーザーは同じコマンドをもう一度実行するだけで続きを進められます。

- `/mysk-spec` の初回実行では `spec.md` を作成し、monitor が確認 (`はい / いいえ / 修正して`) を取ります。確定後に同じ `/mysk-spec {run_id}` を再実行して仕様レビューへ進みます。
- `spec-review.json` に high または medium が残る場合、monitor が `spec.md` への反映可否を確認します。反映時は `spec-vN.md` バックアップを作成してから `spec.md` を更新します。
- `/mysk-review` の初回対象は原則として現在の作業ツリー差分です。run に `spec.md` があれば、それも scope / acceptance の判断材料として使います。2 回目以降は `review.json` を source of truth に、修正計画、承認後の修正、`diffcheck.json`、最終 verify を順に進めます。

## Practical Test Fixtures

`experiments/tri-arm-fixed-spec/` には、フレームワーク自体を検証するための practical test fixture があります。

利用可能な fixture:
- `prac-docs-1line`: 1 行のドキュメント修正
- `prac-docs-multi`: 複数行のドキュメント更新
- `prac-code-1`: シンプルなコード変更（runner スクリプト）

詳細は [experiments/tri-arm-fixed-spec/README.md](experiments/tri-arm-fixed-spec/README.md) を参照してください。

## コマンドごとの考え方

### `/mysk-spec`

- Opus で対話的に要件を固めます
- `opus` / `sonnet` / `haiku` の alias を source of truth とし、provider 固有の実モデル名は診断情報としてだけ扱います
- spec 作成フェーズでは `spec.md` と `status.json` を段階的に更新します
- 狭いタスクでは、関連ファイルと近傍テストの最小集合から確認し、repo 全体探索は必要時だけに寄せます
- `spec.md` には `最小確認対象` を持たせ、最初に見るファイル・テスト・コマンドを明示します
- helper の current behavior を書くときは、helper 本体がしていない前処理や後処理を混ぜません
- 狭い docs / text-only タスクでは、変更箇所ごとの literal な変更後文言を spec に残し、共通パターンは補助説明にとどめます
- `受け入れ条件` 同士が互いを打ち消さないようにし、「X 以外に変更がない」と書く場合は他の必須変更を禁止していないか確認します
- 作成完了後は monitor が `spec.md` の確認を取り、確定後に `/mysk-spec {run_id}` の再実行で仕様レビューへ進みます
- 仕様レビューでは `spec-review.json` を生成します
- 仕様レビューでは `status.json` と `spec-review.json` を早めに保存し、段階的に更新します
- 仕様レビューでは acceptance 条件同士の打ち消し合いも確認します
- review の high / medium が 0 になるまで、同じ `/mysk-spec {run_id}` で再開します

### `/mysk-issue`

- spec.md を読み取って対話的に GitHub Issue を作成します
- タイトル・本文・ラベルを確認しながら進めます
- `gh issue create` で GitHub リポジトリに直接 Issue を登録します
- 作成した Issue の情報は `run_dir/issue.json` に保存されます
- 完了後は `/mysk-implement` に進みます

### `/mysk-implement`

- `spec.md` を source of truth として実装します
- `最小確認対象` がある場合は、そこを最初の working set として実装判断を始めます
- 完了後は `/mysk-review` に進みます

### `/mysk-review`

- 初回は現在の作業ツリー差分を対象に `review.json` を生成します
- review / verify の sub-pane でも `requested_model_alias` を正とし、実解決モデルは診断情報としてだけ保存します
- 初回 review では Changed Paths / Diff Stat / bounded Diff Patch を prompt に含め、これを primary context として使います
- run に `spec.md` の `最小確認対象` があれば、review / verify でもそれを最初の working set として使います
- run に `spec.md` があれば、spec 逸脱や acceptance 未達も review / verify で確認します
- 狭い docs / text-only タスクでは、review でも箇所別の literal な変更後文言を優先し、共通パターンだけで pass させません
- verify では `spec.md` から抽出した acceptance / scope / constraints の snapshot を prompt に埋め込み、spec にない acceptance や extra field を増やさないようにします
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
| `gh` | `/mysk-issue` で必要 | GitHub Issue 作成 |

cmux が未導入の場合:

- `/mysk-spec` と `/mysk-review` は利用できません
- `/mysk-issue`、`/mysk-implement`、`/mysk-help` は使えます
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
- `spec-launch-meta.json`
- `spec-review-launch-meta.json`
- `spec.md`
- `spec-review.json`
- `issue.json`
- `spec-vN.md`
- `review-check-launch-meta.json`
- `review.json`
- `fix-plan.md`
- `diffcheck.json`
- `review-verify-launch-meta.json`
- `verify.json`
- `verify-rerun.json`
- `status.json`
- `timeout-grace.json`

`*-launch-meta.json` では `requested_model_alias` が source of truth です。`configured_runtime_model` と `resolved_runtime_model` は provider や CLI の都合で変わりうる診断情報で、workflow の routing 根拠にはしません。

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

run artifact の段階時間を見たい場合は次を使います。

```bash
bin/stage-time-summary.sh <run_id>
```

`status.json` / `spec-review.json` / `review.json` / `verify*.json` の `started_at` と `completed_at` を読み、stage ごとの所要時間と合計時間を表示します。

## 初学者向けガイド

artifact の読み方と運用判断は、次の 1 ページ資料を使ってください。

- [docs/spec-md-guide.md](docs/spec-md-guide.md)
- [docs/spec-review-json-guide.md](docs/spec-review-json-guide.md)
- [docs/review-json-guide.md](docs/review-json-guide.md)
- [docs/verify-json-guide.md](docs/verify-json-guide.md)
- [docs/low-finding-decision.md](docs/low-finding-decision.md)
- [docs/task-fit-checklist.md](docs/task-fit-checklist.md)
- [docs/waiting-runbook.md](docs/waiting-runbook.md)
- [docs/glossary.md](docs/glossary.md)

## 関連ドキュメント

- [docs/workflow.md](docs/workflow.md)
- [docs/implementation-survey.md](docs/implementation-survey.md)
- [docs/testing.md](docs/testing.md)
- [docs/MIGRATION.md](docs/MIGRATION.md)
- [docs/spec-md-guide.md](docs/spec-md-guide.md)
- [docs/spec-review-json-guide.md](docs/spec-review-json-guide.md)
- [docs/review-json-guide.md](docs/review-json-guide.md)
- [docs/verify-json-guide.md](docs/verify-json-guide.md)
- [docs/low-finding-decision.md](docs/low-finding-decision.md)
- [docs/task-fit-checklist.md](docs/task-fit-checklist.md)
- [docs/waiting-runbook.md](docs/waiting-runbook.md)
- [docs/glossary.md](docs/glossary.md)
- [FAQ.md](FAQ.md)
- [experiments/tri-arm-fixed-spec/PRACTICAL_CRITERIA.md](experiments/tri-arm-fixed-spec/PRACTICAL_CRITERIA.md) - Practical test evaluation criteria
