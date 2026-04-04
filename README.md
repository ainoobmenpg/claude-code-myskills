# mysk - Claude Code Workflow Skills

mysk は Claude Code で仕様策定からコードレビューまでを半自動化するスキル集。既定フローは **fixed-spec を作る planner / 実装する executor / 品質を止める reviewer** の3役分担で、cmux（tmux ラッパー）と連携して別ペインで重い作業を任せる。interactive に仕様を詰める discovery lane も引き続き利用できる。

## クイックスタート（3分）

前提: Claude Code CLI がインストール済み

**用語説明**:
- `~/.claude/`: Claude Code の設定ディレクトリ。スキルやテンプレートを配置する場所
- スラッシュコマンド（`/mysk-workflow` など）: Claude Code のプロンプト内で入力するコマンド

```
1. リポジトリをクローン
   git clone https://github.com/ainoobmenpg/claude-code-myskills.git && cd claude-code-myskills

2. スキルを配置
   mkdir -p ~/.claude/commands ~/.claude/templates  # -p で既存ディレクトリは無視
   cp commands/*.md ~/.claude/commands/
   rm -rf ~/.claude/templates/mysk && ln -sfn "$(pwd)/templates/mysk" ~/.claude/templates/mysk

3. 確認
   Claude Code で /mysk-workflow を実行
```

**cmux が未導入の場合**:
別ペイン実行コマンド（`/mysk-fixed-spec-draft`、`/mysk-fixed-spec-review`、`/mysk-spec-draft`、`/mysk-spec-review`、`/mysk-review-check`、`/mysk-review-verify`）は使用できません。メイン実行のコマンドのみ利用可能です。
また、cmux の前提として tmux が必要です。

## 前提条件

### 依存関係

```
Claude Code CLI (必須)
  ├── cmux (オプション: 別ペイン実行に必要)
  │     ├── tmux (cmuxの前提)
  │     └── python3 (JSON解析用)
  ├── jq (JSON解析用)
  ├── date (BSD/GNU差異あり)
  └── CronCreate/CronDelete ツール (Claude Code組み込み: 監視自動化時は必須)
```

### 各依存関係の詳細

#### Claude Code CLI (必須)

- **役割**: mysk の実行環境
- **確認コマンド**: `claude --version`
- **導入手順**: [Claude Code](https://docs.anthropic.com/en/docs/claude-code) 参照

#### tmux (cmux使用時は必須)

- **役割**: cmux の前提ターミナルマルチプレクサ
- **確認コマンド**: `which tmux && echo "tmux: OK"`
- **導入手順**: macOS: `brew install tmux`、Linux: ディストリビューションのパッケージマネージャ

#### cmux (オプション)

- **役割**: 別ペイン実行に使用。未導入でもメインセッションで動作するコマンドは利用可能
- **確認コマンド**: `which cmux && echo "cmux: OK"`
- **導入手順**:
  - macOS: `brew install cmux` または [cmux リポジトリ](https://github.com/anthropics/cmux) 参照
  - Linux: ソースからビルド

#### CronCreate ツール (監視自動化時は必須)

- **役割**: 進捗監視に使用。Claude Code で有効になっていることを確認
- **確認コマンド**: Claude Code の設定を確認
- **導入手順**: Claude Code の標準機能（CronList/CronDelete も組み込み）

#### python3 (JSON解析用)

- **役割**: JSON データの解析に使用
- **確認コマンド**: `which python3 && echo "python3: OK"`
- **導入手順**: macOS: `brew install python3`、Linux: ディストリビューションのパッケージマネージャ

#### jq (JSON解析用)

- **役割**: JSON データの解析に使用
- **確認コマンド**: `which jq && echo "jq: OK"`
- **導入手順**: macOS: `brew install jq`、Linux: `apt install jq` 等

#### date (BSD/GNU差異あり)

- **役割**: 日時処理に使用
- **注意**: macOS(BSD) と Linux(GNU) でオプション形式が異なる

### データ保存先

成果物は `~/.local/share/claude-mysk/` に保存されます（詳細は[データ保存先](#データ保存先)参照）。

### 別ペイン実行に必要な設定

以下のコマンドは別ペインでの実行のため、追加の設定が必要です：

- `/mysk-fixed-spec-draft`、`/mysk-fixed-spec-review`、`/mysk-spec-draft`、`/mysk-spec-review`、`/mysk-review-check`、`/mysk-review-verify`

**必須環境変数**:
```bash
export CMUX_SOCKET_PATH="$HOME/Library/Application Support/cmux/cmux.sock"  # macOS
# または
export CMUX_SOCKET_PATH="$HOME/.config/cmux/cmux.sock"  # Linux
```

**CronCreate ツール**: 進捗監視に CronCreate ツールを使用します。Claude Code で有効になっていることを確認してください。

### セットアップ確認

```bash
# 1. ディレクトリ作成
mkdir -p ~/.claude/commands ~/.claude/templates

# 2. tmux の確認
which tmux && echo "tmux: OK" || echo "tmux: 未インストール（cmux使用時に必要）"

# 3. cmux の確認
which cmux && echo "cmux: OK" || echo "cmux: 未インストール（別ペイン実行時に必要）"

# 4. 環境変数確認
echo "CMUX_SOCKET_PATH: ${CMUX_SOCKET_PATH:-未設定}"
```

## ワークフロー確認

Claude Code で `/mysk-workflow` を実行

## 環境変数

### MYSK_SKIP_PERMISSIONS

サブエージェントの権限制限を制御します。

- **既定値**: `false`（権限制限あり）
- **設定値**: `true` | `false`
- **用途**: `true` の場合、従来の権限スキップ動作（`--dangerously-skip-permissions`相当）

**設定方法**:
```bash
export MYSK_SKIP_PERMISSIONS=true  # 権限スキップ（従来動作）
export MYSK_SKIP_PERMISSIONS=false # 権限制限（既定）
```

**注意**:
- 既定値（`false`）では、trust確認時にユーザー操作が必要です
- 自動実行が必要な場合は `MYSK_SKIP_PERMISSIONS=true` を設定してください

## インストール

`commands/` と `templates/` の中身を `~/.claude/` 配下に配置する。

```bash
# 1. 既存ファイルのバックアップ（必要な場合のみ）
# ~/.claude/commands/ に mysk-*.md が既にある場合:
mkdir -p backup
cp ~/.claude/commands/mysk-*.md backup/

# 2. ディレクトリ準備
mkdir -p ~/.claude/commands ~/.claude/templates

# 3. ファイル配置（シンボリックリンク推奨）
mkdir -p ~/.claude/templates
ln -sf "$(pwd)/commands/"*.md ~/.claude/commands/
rm -rf ~/.claude/templates/mysk && ln -sfn "$(pwd)/templates/mysk" ~/.claude/templates/mysk

# またはコピー（既存ファイルがある場合はこちらが安全）
mkdir -p ~/.claude/commands ~/.claude/templates
cp commands/*.md ~/.claude/commands/
rm -rf ~/.claude/templates/mysk && cp -r templates/mysk ~/.claude/templates/mysk
```

**注意**:
- シンボリックリンク先に同名ファイルが既にある場合、意図せず上書きされる。他のスキルを既に導入している場合は、コピー方式を使うか、既存ファイルをバックアップしてから実行すること。
- バックアップ先はリポジトリ内の `backup/` ディレクトリを指定してください（例: `mkdir -p backup && cp ~/.claude/commands/mysk-*.md backup/`）

## コマンド一覧

### default lane

| コマンド | 説明 | 実行場所 | 引数 |
|---------|------|---------|------|
| `/mysk-fixed-spec-draft` | 別ペインで fixed-spec を下書き作成 | 別ペイン(Opus) | `[topic]` |
| `/mysk-fixed-spec-review` | fixed-spec をレビューして凍結 | 別ペイン(Opus) | `[run_id]` |
| `/mysk-implement-start` | fixed-spec.md または impl-plan.md を使って実装を実行 | メイン | `[run_id]` |
| `/mysk-spec-implement` | 任意で実装計画を作成（大規模変更向け） | メイン | `[run_id]` |

### discovery lane

| コマンド | 説明 | 実行場所 | 引数 |
|---------|------|---------|------|
| `/mysk-spec-draft` | 別ペインで仕様書を策定 | 別ペイン(Opus) | `[topic]` |
| `/mysk-spec-review` | 仕様書をレビューし反映確認まで実施 | 別ペイン(Opus) | `[run_id]` |

### コードレビュー

| コマンド | 説明 | 実行場所 | 引数 |
|---------|------|---------|------|
| `/mysk-review-check` | 差分または指定パスをレビュー | 別ペイン(Opus) | `[run_id] [path]` |
| `/mysk-review-fix` | レビュー指摘の修正計画と修正 | メイン | `[run_id]` |
| `/mysk-review-diffcheck` | 修正状況を軽量確認 | メイン | `[run_id]` |
| `/mysk-review-verify` | 最終確認で修正サイクル完了 | 別ペイン(Opus) | `[run_id]` |

### 全体

| コマンド | 説明 | 引数 |
|---------|------|------|
| `/mysk-workflow` | 全体ワークフローの参照・管理 | なし |
| `/mysk-cleanup` | 残存する監視ジョブとサブペインを一括クリーンアップ | なし |

引数省略時は最新の run_id を自動選択する（`/mysk-review-check` は新規 run_id を生成）。

## ワークフロー

### 全体図

```mermaid
graph TD
    subgraph default["default lane"]
        FSD["/mysk-fixed-spec-draft<br/>別ペイン planner"] --> FSR["/mysk-fixed-spec-review<br/>別ペイン reviewer"]
        FSR --> IS["/mysk-implement-start<br/>メイン executor"]
        FSR --> SI["/mysk-spec-implement<br/>任意"]
        SI --> IS
    end

    subgraph discovery["discovery lane"]
        SD["/mysk-spec-draft<br/>別ペイン Opus"] --> SR["/mysk-spec-review<br/>別ペイン Opus"]
        SR --> IS
        SR --> SI
    end

    subgraph review["review gate"]
        RC["/mysk-review-check<br/>別ペイン Opus<br/>コードレビュー"] --> RF["/mysk-review-fix<br/>メイン Sonnet<br/>修正計画 + 修正"]
        RF --> DC["/mysk-review-diffcheck<br/>メイン Sonnet<br/>差分確認"]
        DC -->|high 未修正| RF
        DC -->|ユーザー確認| RV["/mysk-review-verify<br/>別ペイン Opus<br/>最終確認"]
        RV -->|未修正の指摘あり| RF
        RV -->|passed| DONE["完了"]
    end

    IS --> DONE
```

**既定フロー**: `/mysk-fixed-spec-draft -> /mysk-fixed-spec-review -> /mysk-implement-start -> /mysk-review-check`

**注記**: discovery lane は要件整理が必要なときだけ使ってください。各コマンドの完了後は、コマンド内の案内行に従って次のステップへ進んでください。

### fix-diffcheck ループ

コードレビューでは、修正と差分確認を繰り返す。中間確認はメインセッション（Sonnet）で軽量実行する。

```mermaid
graph LR
    A["check<br/>Opus"] --> B["fix<br/>Sonnet"]
    B --> C["diffcheck<br/>Sonnet"]
    C -->|"high 残り"| B
    C -->|"ユーザー確認"| D["verify<br/>Opus"]
```

### 終了条件

| 条件 | アクション |
|------|----------|
| diffcheck: ユーザー確認あり | `/mysk-review-verify` へ |
| diffcheck: high 未修正あり | `/mysk-review-fix` ループ継続 |
| verify: passed | **終了** |
| verify: failed（検証エラー） | エラー報告 → **終了** |
| verify: 新たな high 発生 | エラー報告 → **終了** |
| verify: 未修正の high あり | エラー報告 → **終了** |
| verify: 未修正の指摘あり | /mysk-review-fix に戻る |
| verify: high なし、未解決なし | **終了** |

> 終了条件のフロー図は [docs/workflow.md](docs/workflow.md) を参照してください。

## テンプレート一覧

`templates/mysk/` に格納されているファイル。

| ファイル | 役割 |
|---------|------|
| `cmux-launch-procedure.md` | cmux サブペイン起動 + Claude Code 待機手順 |
| `fixed-spec-draft-prompt.md` | fixed-spec 下書き作成プロンプト |
| `fixed-spec-draft-monitor.md` | fixed-spec 下書きの進捗監視 |
| `fixed-spec-review-prompt.md` | fixed-spec レビュープロンプト |
| `fixed-spec-review-monitor.md` | fixed-spec レビューの進捗監視 |
| `spec-draft-prompt.md` | 仕様策定プロンプト |
| `spec-draft-monitor.md` | 仕様策定の進捗監視 |
| `spec-review-prompt.md` | 仕様レビュープロンプト |
| `spec-review-monitor.md` | 仕様レビューの進捗監視 |
| `review-check-prompt.md` | コードレビュープロンプト |
| `review-check-monitor.md` | コードレビューの進捗監視 |
| `review-verify-prompt.md` | 最終検証プロンプト |
| `review-verify-monitor.md` | 最終検証の進捗監視 |
| `verify-schema.json` | verify判定基準のJSON Schema定義 |

## データ保存先

すべての成果物は `~/.local/share/claude-mysk/` に保存される。

**run_id について**: `{YYYYMMDD-HHMMSSZ}-{slug}` 形式の一意識別子。各実行の成果物をディレクトリ単位で管理する。run_id を省略した場合は `run-meta.json` の `project_root` と現在のプロジェクトを照合して自動選択する。手動確認は各 run ディレクトリの `run-meta.json` を参照。

```
~/.local/share/claude-mysk/
+-- {YYYYMMDD-HHMMSSZ}-{slug}/    # run_id
    +-- fixed-spec-draft.md       # fixed-spec 下書き
    +-- fixed-spec.md             # fixed-spec 確定版
    +-- fixed-spec-review.json    # fixed-spec レビュー結果
    +-- spec.md                   # 仕様書（確定版）
    +-- spec-draft.md             # 仕様書（下書き）
    +-- spec-review.json          # 仕様レビュー結果
    +-- impl-plan.md              # 実装計画
    +-- review.json               # コードレビュー結果
    +-- fix-plan.md               # 修正計画
    +-- diffcheck.json            # 差分確認結果
    +-- verify.json               # 最終検証結果
    +-- verify-rerun.json         # 再検証結果
    +-- run-meta.json             # run_id自動解決用メタデータ
    +-- status.json               # 進捗管理（汎用/spec-review専用）
```

### コマンド間のデータ連携

各コマンドがどのファイルを読み、どのファイルを出力するかを整理する。

| コマンド | 読み込み | 出力 | ステータス |
|---------|---------|------|----------|
| `/mysk-fixed-spec-draft` | なし | `fixed-spec-draft.md`, `fixed-spec.md` | `status.json` |
| `/mysk-fixed-spec-review` | `fixed-spec.md`（存在時）、`fixed-spec-draft.md`（フォールバック） | `fixed-spec-review.json` | `status.json` |
| `/mysk-spec-draft` | なし | `spec-draft.md`, `spec.md` | `status.json` |
| `/mysk-spec-review` | `spec.md`（存在時）、`spec-draft.md`（フォールバック） | `spec-review.json` | `status.json` |
| `/mysk-spec-implement` | `fixed-spec.md`（優先）または `spec.md` | `impl-plan.md`（任意・大規模変更向け） | なし |
| `/mysk-implement-start` | `fixed-spec.md`（優先）または `spec.md`、`impl-plan.md`（任意） | プロジェクトコードの変更（myskファイルは更新しない） | `status.json` |
| `/mysk-review-check` | Git diff または指定パス | `review.json` | なし |
| `/mysk-review-fix` | `review.json` | `fix-plan.md` | なし |
| `/mysk-review-diffcheck` | `review.json`, `verify-rerun.json`（優先）または`verify.json`（存在時） | `diffcheck.json` | なし |
| `/mysk-review-verify` | `review.json`, `diffcheck.json` | `verify.json`（再実行時は`verify-rerun.json`） | なし |

## 使用例

```
# default lane（既定）
/mysk-fixed-spec-draft ユーザー認証機能

# （サブエージェントが下書きを作成 → 確認 → fixed-spec.md に確定）

# fixed-spec レビュー
/mysk-fixed-spec-review

# 実装開始（必要なら /mysk-spec-implement を任意で挟む）
/mysk-implement-start

# コードレビュー
/mysk-review-check

# レビュー指摘の修正
/mysk-review-fix

# 修正状況の確認
/mysk-review-diffcheck

# 最終確認
/mysk-review-verify

# discovery lane（要件整理が必要なときだけ）
/mysk-spec-draft ユーザー認証機能
/mysk-spec-review
/mysk-spec-implement   # 任意
/mysk-implement-start
```

## スキルの更新

mysk スキルを更新する場合は、以下のフローで行ってください。

### 基本原則

1. **リポジトリ側で修正**: `commands/` と `templates/mysk/` のファイルを編集
2. **環境に展開**: 修正を `~/.claude/commands/` と `~/.claude/templates/mysk/` に反映
3. **確認**: Claude Code でスキルが正しく動作することを確認

### インストール方式による展開方法の違い

**シンボリックリンクで導入済みの場合**:
- リポジトリ側の修正が自動反映されるため、再展開は不要です
- 修正したファイルはすぐに反映されます

**コピーで導入した場合**:
- 以下のコマンドで再展開が必要です:

```bash
# 個別に更新
cp commands/mysk-workflow.md ~/.claude/commands/

# 全スキルを一括更新
cp commands/mysk-*.md ~/.claude/commands/
rm -rf ~/.claude/templates/mysk && cp -r templates/mysk ~/.claude/templates/mysk
```

### コマンド例

```bash
# 1. リポジトリ側で修正（お好みのエディタで）
vim commands/mysk-workflow.md

# 2. シンボリックリンクの場合は何もしなくてOK
#    コピーの場合は以下を実行
cp commands/mysk-*.md ~/.claude/commands/
rm -rf ~/.claude/templates/mysk && cp -r templates/mysk ~/.claude/templates/mysk
```

**注意**: `~/.claude/commands/` 内のファイルを直接編集すると、リポジトリ側との同期が取れなくなります。必ずリポジトリ側で修正してください。
