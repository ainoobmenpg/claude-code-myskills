---
description: 最終確認を実行し修正サイクルを完了
argument-hint: "[run_id]"
user-invocable: true
---

# mysk-review-verify

`/mysk-review-diffcheck` で全highが修正された後の最終確認。別ペインでOpusサブエージェント起動し、verify.jsonを保存して要約を返す。

**重要**: verifyの実行にはユーザー確認が必要です。diffcheck結果を確認し、ユーザーの指示を待ってから実行してください。

## 入力

- run_id指定 or `~/.local/share/claude-mysk/`最新を自動選択

- **データ保存先**: `~/.local/share/claude-mysk/`

## 保存先

`~/.local/share/claude-mysk/{run_id}/verify.json`

**再実行時**: verify.jsonが既に存在する場合、verify-rerun.jsonに保存する

## 前提

- `CMUX_SOCKET_PATH`環境変数が存在すること
- review.jsonが存在すること
- diffcheck.jsonが存在する場合は併せて読み込む（必須ではない）

## 実行フロー

**注意: 二重起動防止**: このコマンドは1回の呼び出しで1回だけサブペインを起動すること。同じターン内でフローを再開始しないこと。コンテキスト圧縮後も、既にサブペインが起動済み（READY: を受信済み）なら step 3 以降を続行し、step 1-2 をやり直さないこと。

### 1. 初期化

- run_id解決（統一アルゴリズム）:
  1. 引数で run_id が指定されていればそれを使用（終了）
  2. WORK_DIR を取得: `git rev-parse --show-toplevel 2>/dev/null || pwd`
  3. `~/.local/share/claude-mysk/` 内のディレクトリを降順ソート
  4. 各ディレクトリの run-meta.json を読み込む
  5. run-meta.json が存在しないディレクトリは候補から除外
  6. run-meta.json の project_root が WORK_DIR と一致する最初のディレクトリを選択
  7. 該当なし → エラー終了、run_id 手動指定を促す
- review.json存在確認
- diffcheck.jsonが存在する場合は読み込み、次ステップ判定の参考にする

### 2. 出力パス決定

verify.json の既存状態に基づいて出力パスを決定:

**手順**:
1. `VERIFY_JSON_PATH="$RUN_DIR/verify.json"` を初期値とする
2. verify.json が存在しない → `VERIFY_JSON_PATH` をそのまま使用
3. verify.json が存在する場合:
   - `jq` で `verification_result` を取得
   - `result == "passed"` → AskUserQuestion でユーザー確認（自然な対話）
   - `result != "passed"` → `VERIFY_JSON_PATH="$RUN_DIR/verify-rerun.json"` に変更
4. ユーザーが再実行を拒否した場合 → 処理を中止

**注意**: bash の `read` コマンドは Claude の Bash ツールでは動作しないため、必ず AskUserQuestion または自然な対話で確認すること。

### 3. サブペインの準備

テンプレート存在確認:
```bash
for f in cmux-launch-procedure.md review-verify-prompt.md review-verify-monitor.md; do
  [ -f "$HOME/.claude/templates/mysk/$f" ] || { echo "Error: Template not found: $f"; exit 1; }
done
```

`$HOME/.claude/templates/mysk/cmux-launch-procedure.md` を読み、`{WORK_DIR}`→`$WORK_DIR` に置換して実行。

**重要**: テンプレートには2つのスクリプトブロック（起動スクリプト＋待機スクリプト）が含まれている。両方を順番に実行すること。
待機スクリプトはTrust確認をユーザー操作待ちとし、`❯` プロンプトを検出するまでポーリングする。
`READY:` が出力されるまで次のステップに進まないこと。`TIMEOUT:` の場合はエラーとして扱う。

### 4. 検証プロンプト送信

sedで置換後、一時ファイルに保存し、短い読み込み指示を送信:
```bash
sed -e "s|{REVIEW_JSON_PATH}|$REVIEW_JSON_PATH|g" -e "s|{RUN_ID}|$RUN_ID|g" -e "s|{VERIFY_JSON_PATH}|$VERIFY_JSON_PATH|g" \
  $HOME/.claude/templates/mysk/review-verify-prompt.md > "/tmp/mysk-${RUN_ID}-prompt.txt"

cmux send --workspace "$WS_REF" --surface "$SUB_SURFACE" \
  "Read /tmp/mysk-${RUN_ID}-prompt.txt and follow all instructions in it exactly."
cmux send-key --workspace "$WS_REF" --surface "$SUB_SURFACE" return
```

### 5. 状態監視

bashでsedを実行してモニターテキストを生成し、そのテキストを使って **CronCreateツール**（bashコマンドではない）で監視ジョブを登録する。

```bash
sed -e "s|{VERIFY_JSON_PATH}|$VERIFY_JSON_PATH|g" -e "s|{RUN_ID}|$RUN_ID|g" -e "s|{WS_REF}|$WS_REF|g" -e "s|{SUB_SURFACE}|$SUB_SURFACE|g" \
  $HOME/.claude/templates/mysk/review-verify-monitor.md
```

上記の出力テキストをpromptに指定し、CronCreateツールを呼ぶ:
- cron: `*/1 * * * *`
- recurring: true

### 6. このコマンドで返す内容

このコマンドでは、verify 開始と監視ジョブ登録までを行う。
verify 完了は待たずに終了する。

メイン会話には以下を返す:
- run_id
- 保存先
- 状態: `started`

verify.json の生成完了後、monitor 側が終了判定ロジックに従い結果を返す。

## monitor 側の終了判定（verify.json 生成後）

verify.jsonが既に存在する場合の再実行ロジック:
- verify.jsonのverification_resultが`passed`の場合: 「既にpassedのverify結果があります。再実行しますか？」と確認
- verification_resultが`passed`以外の場合: verify-rerun.jsonに出力する旨を表示して続行

**※出力パス決定ロジック（step 2）で既に判定済み**: monitor側では判定済みの出力パス（VERIFY_JSON_PATH）を使用します。

出力パスの決定ロジック:
- verify.jsonが存在しない → verify.json
- verify.jsonが存在する場合:
  - verification_result == "passed" → 確認プロンプト表示
  - それ以外 → verify-rerun.json

| 条件 | 次アクション |
|------|-------------|
| passed | 終了 |
| failed | エラー報告→終了 |
| new highあり | /mysk-review-fix→/mysk-review-diffcheck→終了 |
| high残存 | /mysk-review-fix→/mysk-review-diffcheck→終了 |
| mediumのみ | ユーザー確認 |

