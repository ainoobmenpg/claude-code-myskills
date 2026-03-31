---
description: 差分または指定パスをレビュー
argument-hint: "[run_id] [path]"
user-invocable: true
---

# mysk-review-check

別ペインでOpus・max effortのサブエージェントを起動し、レビュー結果をJSONで保存して要約を返す。

## 入力

引数解析:
- 引数なし: 新規 run_id を生成する、レビュー対象は現在の Git diff
- 引数1つ:
  - `~/.local/share/claude-mysk/` 内の既存 run_id と一致する場合 → その run_id を使う、レビュー対象は現在の Git diff
  - それ以外 → 新規 run_id を生成する、その引数をレビュー対象パスとして扱う
- 引数2つ:
  - 1つ目を run_id、2つ目をレビュー対象パス
- 引数3つ以上: エラー終了

run_id 解決順序:
- 2引数時: 第1引数
- 1引数で既存 run_id 一致時: その引数
- それ以外: `{timestamp}-review` を新規生成

- **データ保存先**: `~/.local/share/claude-mysk/`
- `WORK_DIR`: `git rev-parse --show-toplevel 2>/dev/null || pwd`（サブエージェント作業ディレクトリ）

## 保存先

`~/.local/share/claude-mysk/{run_id}/review.json`

## レビュー対象の記録

review.jsonには `project_root` フィールドに `WORK_DIR` の値を記録する。検証時にこのパスを使用する。

## 前提条件

- `CMUX_SOCKET_PATH` 環境変数が存在すること

## 実行フロー

**注意: 二重起動防止**: このコマンドは1回の呼び出しで1回だけサブペインを起動すること。同じターン内でフローを再開始しないこと。コンテキスト圧縮後も、既にサブペインが起動済み（READY: を受信済み）なら step 3 以降を続行し、step 1-2 をやり直さないこと。

### 1. 初期化

- run_id 解決、runディレクトリ作成
- WORK_DIR: `git rev-parse --show-toplevel 2>/dev/null || pwd`

**run-meta.json生成**（run_id自動解決用）:
```bash
RUN_META_PATH="$RUN_DIR/run-meta.json"
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
cat > "$RUN_META_PATH" << EOF
{
  "run_id": "$RUN_ID",
  "project_root": "$WORK_DIR",
  "created_at": "$TIMESTAMP"
}
EOF
```

### 2. サブペインの準備

テンプレート存在確認:
```bash
for f in cmux-launch-procedure.md review-check-prompt.md review-check-monitor.md; do
  [ -f "$HOME/.claude/templates/mysk/$f" ] || { echo "Error: Template not found: $f"; exit 1; }
done
```

`$HOME/.claude/templates/mysk/cmux-launch-procedure.md` を読み、`{WORK_DIR}`→`$WORK_DIR` に置換して実行。

**重要**: テンプレートには2つのスクリプトブロック（起動スクリプト＋待機スクリプト）が含まれている。両方を順番に実行すること。
待機スクリプトはTrust確認をユーザー操作待ちとし、`❯` プロンプトを検出するまでポーリングする。
`READY:` が出力されるまで次のステップに進まないこと。`TIMEOUT:` の場合はエラーとして扱ってください。

### 3. レビュープロンプトの送信

sedで置換後、一時ファイルに保存し、短い読み込み指示を送信:
```bash
sed -e "s|{REVIEW_TARGET}|$REVIEW_TARGET|g" -e "s|{RUN_ID}|$RUN_ID|g" \
    -e "s|{REVIEW_JSON_PATH}|$REVIEW_JSON_PATH|g" -e "s|{PROJECT_ROOT}|$WORK_DIR|g" \
  $HOME/.claude/templates/mysk/review-check-prompt.md > "/tmp/mysk-${RUN_ID}-prompt.txt"

cmux send --workspace "$WS_REF" --surface "$SUB_SURFACE" \
  "Read /tmp/mysk-${RUN_ID}-prompt.txt and follow all instructions in it exactly."
cmux send-key --workspace "$WS_REF" --surface "$SUB_SURFACE" return
```

### 4. 状態監視

bashでsedを実行してモニターテキストを生成し、そのテキストを使って **CronCreateツール**（bashコマンドではない）で監視ジョブを登録する。

```bash
sed -e "s|{REVIEW_JSON_PATH}|$REVIEW_JSON_PATH|g" -e "s|{RUN_ID}|$RUN_ID|g" -e "s|{WS_REF}|$WS_REF|g" -e "s|{SUB_SURFACE}|$SUB_SURFACE|g" \
  $HOME/.claude/templates/mysk/review-check-monitor.md
```

上記の出力テキストをpromptに指定し、CronCreateツールを呼ぶ:
- cron: `*/1 * * * *`
- recurring: true

### 5. このコマンドで返す内容

このコマンドでは、レビュー開始と監視ジョブ登録までを行う。
レビュー完了は待たずに終了する。

メイン会話には以下を返す:
- run_id
- 対象
- 保存先
- 状態: `started`

review.json の生成完了後、monitor 側がサマリ（全体/高/中/低/リスク）と主な指摘を返し、`/mysk-review-fix {run_id}` を案内する。

## トラブルシューティング

**結果が空の場合**:
thinking ブロックに回答が含まれている可能性があります。thinking を展開して内容を確認してください。

## run_id の既定動作

`/mysk-review-check` は開始コマンドなので、run_id を明示しない場合は新規 run_id を生成する。既存 run を流用しない。

## 例

`/mysk-review-check`、`/mysk-review-check 20260327-101530Z-user-auth`、`/mysk-review-check src/auth.ts`

## 完了後案内

レビュー完了後：
```
次: /mysk-review-fix で指摘を修正
```

（指摘がない場合: `次: 指摘なし。完了`）

- review.json に指摘が含まれる場合に出力
- 上記条件を満たさない（エラー等）場合は案内なし
