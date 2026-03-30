# mysk - Claude Code Workflow Skills

mysk は Claude Code で仕様策定からコードレビューまでを半自動化するスキル集。cmux（tmux ラッパー）と連携し、サブペインで Opus モデルのサブエージェントを起動して重い作業を任せる。メインセッションは Sonnet で軽量に進めるため、Opus のトークン消費を抑えられる。

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
   cp -r templates/mysk ~/.claude/templates/mysk

3. 確認
   Claude Code で /mysk-workflow を実行
```

**cmux が未導入の場合**:
別ペイン実行コマンド（`/mysk-spec-draft`、`/mysk-spec-review`、`/mysk-review-check`、`/mysk-review-verify`）は使用できません。メイン実行のコマンドのみ利用可能です。
また、cmux の前提として tmux が必要です。

## 前提条件

### 依存関係

```
Claude Code CLI (必須)
  ├── cmux (オプション: 別ペイン実行に必要)
  │     └── tmux (cmuxの前提)
  └── CronCreate ツール (監視自動化時は必須)
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
- **導入手順**: Claude Code の標準機能

### データ保存先

成果物は `~/.local/share/claude-mysk/` に保存されます（詳細は[データ保存先](#データ保存先)参照）。

### 別ペイン実行に必要な設定

以下のコマンドは別ペインでの実行のため、追加の設定が必要です：

- `/mysk-spec-draft`、`/mysk-spec-review`、`/mysk-review-check`、`/mysk-review-verify`

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

# 3. ワークフロー確認

Claude Code で `/mysk-workflow` を実行

## インストール

`commands/` と `templates/` の中身を `~/.claude/` 配下に配置する。

```bash
# ディレクトリ準備
mkdir -p ~/.claude/commands ~/.claude/templates

# シンボリックリンク（推奨）
# 注意: ln は同名ファイルがあるとエラー（または -n/-f で置換）、cp は上書きされる
# 既存のスキルがある場合は cp（コピー）を使うか、バックアップを取ってください
ln -sn "$(pwd)/commands/"*.md ~/.claude/commands/
ln -sn "$(pwd)/templates/mysk" ~/.claude/templates/mysk

# またはコピー（既存ファイルがある場合はこちらが安全）
cp commands/*.md ~/.claude/commands/
cp -r templates/mysk ~/.claude/templates/mysk
```

**注意**: シンボリックリンク先に同名ファイルが既にある場合、意図せず上書きされる。他のスキルを既に導入している場合は、コピー方式を使うか、既存ファイルをバックアップしてから実行すること。

## コマンド一覧

### 仕様策定

| コマンド | 説明 | 実行場所 | 引数 |
|---------|------|---------|------|
| `/mysk-spec-draft` | 別ペインで仕様書を策定 | 別ペイン(Opus) | `[topic]` |
| `/mysk-spec-review` | 仕様書をレビューしJSONで保存 | 別ペイン(Opus) | `[run_id]` |
| `/mysk-spec-revise` | レビュー指摘を差分更新 | メイン | `[run_id]` |
| `/mysk-spec-implement` | 実装計画を作成（計画のみ） | メイン | `[run_id]` |
| `/mysk-implement-start` | impl-plan.mdを読み込み実装を実行 | メイン | `[run_id]` |

### コードレビュー

| コマンド | 説明 | 実行場所 | 引数 |
|---------|------|---------|------|
| `/mysk-review-check` | 差分または指定パスをレビュー | 別ペイン(Opus) | `[run_id] [path]` |
| `/mysk-review-fix` | レビュー指摘の修正計画＋修正 | メイン | `[run_id]` |
| `/mysk-review-diffcheck` | 修正状況を軽量確認 | メイン | `[run_id]` |
| `/mysk-review-verify` | 最終確認で修正サイクル完了 | 別ペイン(Opus) | `[run_id]` |

### 全体

| コマンド | 説明 | 引数 |
|---------|------|------|
| `/mysk-workflow` | 全体ワークフローの参照・管理 | なし |
| `/mysk-cleanup` | 残存する監視ジョブとサブペインを一括クリーンアップ | なし |

引数省略時は最新の run_id を自動選択する（`/mysk-review-check` は新規 run_id を生成）。

## ワークフロー

```
仕様策定                                              コードレビュー
    |                                                      |
    v                                                      v
  +------------------+                          +------------------+
  | mysk-spec-draft  |                          |mysk-review-check |
  |  別ペイン(Opus)  |                          |  別ペイン(Opus)  |
  |   仕様書下書き    |                          |   コードレビュー   |
  +----+--------+----+                          +--------+---------+
       |        |                                        |
   シンプル   複雑                                       v
       |        |                             +------------------+
       |        v                             | mysk-review-fix  |
       |  +--------------+                   |  修正計画 + 修正   |
       |  |mysk-spec-    |                   +--------+---------+
       |  |  review      |                            |
       |  |  別ペイン     |                            v
       |  |  (Opus)       |                 +-------------------+
       |  |  仕様レビュー |                 | mysk-review-diffcheck |
       |  +------+-------+                 |  差分確認（軽量）   |
       |         |                         +---------+---------+
       |         v                                   |
       |  +--------------+                     high 未修正?
       |  |mysk-spec-    |                      | Yes    | No
       |  |  revise      |                  +----+       |
       |  |  指摘を反映   |                  | fix <------+---> loop
       |  +------+-------+                  +----+
       |         |                               |
       +---><----+                               v
             |                        +------------------+
             v                        |mysk-review-verify|
     +-----------------+              |  別ペイン(Opus)   |
     |mysk-spec-       |              +--------+---------+
     |  implement      |                       |
     |  実装計画作成    |                       v
     |  （計画のみ）    |                     完了
     +--------+--------+
              |
              v
         実装計画完了
              |
              v
     +-----------------+
     |mysk-implement-  |
     |start            |
     |実装を一括実行    |
     +--------+--------+
              |
              v
            完了
```

**注記**: 各コマンドの完了後は、コマンド内の案内行に従って次のステップへ進んでください。

### fix-diffcheck ループ

コードレビューでは、修正と差分確認を繰り返す。中間確認はメインセッション（Sonnet）で軽量実行する。

```
check(Opus) -> fix(Sonnet) -> diffcheck(Sonnet) -> fix -> diffcheck -> ... -> verify(Opus)
```

## テンプレート一覧

`templates/mysk/` に格納されているファイル。

| ファイル | 役割 |
|---------|------|
| `cmux-launch-procedure.md` | cmux サブペイン起動 + Claude Code 待機手順 |
| `spec-draft-prompt.md` | 仕様策定プロンプト |
| `spec-draft-monitor.md` | 仕様策定の進捗監視 |
| `spec-review-prompt.md` | 仕様レビュープロンプト |
| `spec-review-monitor.md` | 仕様レビューの進捗監視 |
| `review-check-prompt.md` | コードレビュープロンプト |
| `review-check-monitor.md` | コードレビューの進捗監視 |
| `review-verify-prompt.md` | 最終検証プロンプト |
| `review-verify-monitor.md` | 最終検証の進捗監視 |

## データ保存先

すべての成果物は `~/.local/share/claude-mysk/` に保存される。

**run_id について**: `{YYYYMMDD-HHMMSSZ}-{slug}` 形式の一意識別子。各実行の成果物をディレクトリ単位で管理する。run_id を忘れた場合は、最新のディレクトリを確認すること。

```
~/.local/share/claude-mysk/
+-- {YYYYMMDD-HHMMSSZ}-{slug}/    # run_id
    +-- spec.md                   # 仕様書（確定版）
    +-- spec-draft.md             # 仕様書（下書き）
    +-- spec-review.json          # 仕様レビュー結果
    +-- impl-plan.md              # 実装計画
    +-- review.json               # コードレビュー結果
    +-- fix-plan.md               # 修正計画
    +-- diffcheck.json            # 差分確認結果
    +-- verify.json               # 最終検証結果
    +-- status.json               # 進捗管理（汎用）
    +-- status-review.json        # 進捗管理（spec-review専用）
```

### コマンド間のデータ連携

各コマンドがどのファイルを読み、どのファイルを出力するかを整理する。

| コマンド | 読み込み | 出力 | ステータス |
|---------|---------|------|----------|
| `/mysk-spec-draft` | なし | `spec-draft.md`, `spec.md` | `status.json` |
| `/mysk-spec-review` | `spec.md` | `spec-review.json` | `status-review.json` |
| `/mysk-spec-revise` | `spec.md`, `spec-review.json` | `spec.md`（更新）, `spec-v1.md`（バックアップ） | なし |
| `/mysk-spec-implement` | `spec.md` | `impl-plan.md` | なし |
| `/mysk-implement-start` | `impl-plan.md` | プロジェクトコードの変更（myskファイルは更新しない） | なし |
| `/mysk-review-check` | Git diff または指定パス | `review.json` | なし |
| `/mysk-review-fix` | `review.json` | `fix-plan.md` | なし |
| `/mysk-review-diffcheck` | `review.json`, `verify.json`（存在時） | `diffcheck.json` | なし |
| `/mysk-review-verify` | `review.json`, `diffcheck.json` | `verify.json` | なし |

## 使用例

```
# 仕様策定
/mysk-spec-draft ユーザー認証機能

# （サブエージェントが下書きを作成 → 確認 → spec.md に確定）

# 仕様レビュー（複雑な場合）
/mysk-spec-review

# レビュー指摘の反映
/mysk-spec-revise

# 実装計画作成
/mysk-spec-implement

# --- ここから実装 ---

# コードレビュー
/mysk-review-check src/auth.ts

# レビュー指摘の修正
/mysk-review-fix

# 修正状況の確認
/mysk-review-diffcheck

# 最終確認
/mysk-review-verify
```
