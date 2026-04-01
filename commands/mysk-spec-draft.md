---
description: 別ペインで仕様策定
argument-hint: "[topic]"
user-invocable: true
---

# mysk-spec-draft

別ペインでOpus・medium effortのサブエージェントを起動し、仕様策定を行う。

## ディレクトリ構造

`~/.local/share/claude-mysk/{timestamp}-{slug}/` に spec.md、spec-draft.md などを保存。

timestamp: UTCの`YYYYMMDD-HHMMSSZ`形式、slug: トピックから生成（英訳、小文字、ハイフン区切り、最大20文字）

## 前提条件

- `CMUX_SOCKET_PATH`環境変数が存在すること

## 実行フロー

**注意: 二重起動防止**: このコマンドは1回の呼び出しで1回だけサブペインを起動すること。同じターン内でフローを再開始しないこと。コンテキスト圧縮後も、既にサブペインが起動済み（READY: を受信済み）なら step 3 以降を続行し、step 1-2 をやり直さないこと。

### 1. 初期化

- `$ARGUMENTS` または確認でトピックを決定
- **データ保存先**: `~/.local/share/claude-mysk/`
- `WORK_DIR`: `git rev-parse --show-toplevel 2>/dev/null || pwd`（サブエージェント作業ディレクトリ）
- タイムスタンプ: `date -u +%Y%m%d-%H%M%SZ`
- スラッグ: 日本語→英訳→小文字→ハイフン区切り→最大20文字
- run_id: `{timestamp}-{slug}`
- runディレクトリ作成: `~/.local/share/claude-mysk/{run_id}/`
- **run-meta.json生成**:

```bash
# Create run-meta.json
RUN_META_PATH="$RUN_DIR/run-meta.json"
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
cat > "$RUN_META_PATH" << EOF
{
  "run_id": "$RUN_ID",
  "project_root": "$WORK_DIR",
  "created_at": "$TIMESTAMP",
  "topic": "$TOPIC"
}
EOF
```

### 2. サブペインの準備と起動完了待ち

テンプレートファイルの存在確認:
```bash
for f in cmux-launch-procedure.md spec-draft-prompt.md spec-draft-monitor.md; do
  [ -f "$HOME/.claude/templates/mysk/$f" ] || { echo "Error: Template not found: $f"; exit 1; }
done
```

`$HOME/.claude/templates/mysk/cmux-launch-procedure.md` を読み、`{WORK_DIR}`→`$WORK_DIR` に置換して実行。

**重要**: テンプレートには2つのスクリプトブロック（起動スクリプト＋待機スクリプト）が含まれている。両方を順番に実行すること。
待機スクリプトはTrust確認をユーザー操作待ちとし、`❯` プロンプトを検出するまでポーリングする。
`READY:` が出力されるまで次のステップに進まないこと。`TIMEOUT:` の場合はエラーとして扱ってください。

### 3. プロンプトの送信

`READY:` が確認できたら、プロンプトを送信する:

1. sed でテンプレート変数を置換し、一時ファイルに保存
2. 短い読み込み指示を `cmux send` でサブペインに送信

```bash
sed -e "s|{TOPIC}|$TOPIC|g" -e "s|{STATUS_FILE}|$STATUS_FILE|g" -e "s|{DRAFT_PATH}|$DRAFT_PATH|g" \
  $HOME/.claude/templates/mysk/spec-draft-prompt.md > "/tmp/mysk-${RUN_ID}-prompt.txt"

cmux send --workspace "$WS_REF" --surface "$SUB_SURFACE" \
  "Read /tmp/mysk-${RUN_ID}-prompt.txt and follow all instructions in it exactly."
cmux send-key --workspace "$WS_REF" --surface "$SUB_SURFACE" return
```

### 4. 状態監視

bashでsedを実行してモニターテキストを生成し、そのテキストを使って **CronCreateツール**（bashコマンドではない）で監視ジョブを登録する。

```bash
sed -e "s|{STATUS_FILE}|$STATUS_FILE|g" -e "s|{DRAFT_PATH}|$DRAFT_PATH|g" -e "s|{SPEC_PATH}|$SPEC_PATH|g" \
    -e "s|{WS_REF}|$WS_REF|g" -e "s|{SUB_SURFACE}|$SUB_SURFACE|g" \
    -e "s|{RUN_ID}|$RUN_ID|g" \
    $HOME/.claude/templates/mysk/spec-draft-monitor.md
```

上記の出力テキストをpromptに指定し、CronCreateツールを呼ぶ:
- cron: `*/1 * * * *`
- recurring: true

### 5. このコマンドで返す内容

このコマンドでは、下書き生成の開始と監視ジョブ登録までを行う。
生成完了前にユーザー確認（はい/いいえ/修正して）へ進めてはならない。

メイン会話には以下を返す:
- run_id
- 保存先
- 状態: `started`

spec-draft.md の生成完了後、monitor 側が要約を表示し、AskUserQuestion でユーザー確認（はい/いいえ/修正して）を行い、コピー/破棄/修正処理とクリーンアップまで完結します。

## トラブルシューティング

**結果が空の場合**:
thinking ブロックに回答が含まれている可能性があります。thinking を展開して内容を確認してください。

## スラッグ生成ルール

日本語→英訳→小文字→ハイフン区切り→最大20文字

## 例

`/mysk-spec-draft トピック`

