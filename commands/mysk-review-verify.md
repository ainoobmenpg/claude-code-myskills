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

## 前提

- `CMUX_SOCKET_PATH`環境変数が存在すること
- review.jsonが存在すること

## 実行フロー

### 1. 初期化

- run_id解決、review.json存在確認
- review.jsonから `project_root` フィールドを読み取り、`WORK_DIR` に設定
- project_rootがない場合：旧バージョンで作成されたreview.jsonなのでエラーとして報告し、失敗させる
  - エラーメッセージ: `エラー: review.jsonに 'project_root' フィールドがありません。このレビューは旧バージョンで作成されました。/mysk-review-check を再実行して互換性のあるレビューを作成してください。`
  - 再レビューを案内する

### 2. サブペイン準備

テンプレート存在確認:
```bash
for f in cmux-launch-procedure.md review-verify-prompt.md review-verify-monitor.md; do
  [ -f "$HOME/.claude/templates/mysk/$f" ] || { echo "Error: Template not found: $f"; exit 1; }
done
```

`$HOME/.claude/templates/mysk/cmux-launch-procedure.md` を読み、`{WORK_DIR}`→`$WORK_DIR` に置換して実行。

**重要**: テンプレートには2つのスクリプトブロック（起動スクリプト＋待機スクリプト）が含まれている。両方を順番に実行すること。
待機スクリプトはTrust確認を自動で承認し、`❯` プロンプトを検出するまでポーリングする。
`READY:` が出力されるまで次のステップに進まないこと。`TIMEOUT:` の場合はエラーとして扱う。

### 3. 検証プロンプト送信

sedで置換後、一時ファイルに保存し、短い読み込み指示を送信:
```bash
sed -e "s|{REVIEW_JSON_PATH}|$REVIEW_JSON_PATH|g" -e "s|{RUN_ID}|$RUN_ID|g" -e "s|{VERIFY_JSON_PATH}|$VERIFY_JSON_PATH|g" \
  $HOME/.claude/templates/mysk/review-verify-prompt.md > "/tmp/mysk-${RUN_ID}-prompt.txt"

cmux send --workspace "$WS_REF" --surface "$SUB_SURFACE" \
  "Read /tmp/mysk-${RUN_ID}-prompt.txt and follow all instructions in it exactly."
cmux send-key --workspace "$WS_REF" --surface "$SUB_SURFACE" return
```

### 4. 状態監視

bashでsedを実行してモニターテキストを生成し、そのテキストを使って **CronCreateツール**（bashコマンドではない）で監視ジョブを登録する。

```bash
sed -e "s|{VERIFY_JSON_PATH}|$VERIFY_JSON_PATH|g" -e "s|{WS_REF}|$WS_REF|g" -e "s|{SUB_SURFACE}|$SUB_SURFACE|g" \
  $HOME/.claude/templates/mysk/review-verify-monitor.md
```

上記の出力テキストをpromptに指定し、CronCreateツールを呼ぶ:
- cron: `*/1 * * * *`
- recurring: true

### 5. このコマンドで返す内容

このコマンドでは、verify 開始と監視ジョブ登録までを行う。
verify 完了は待たずに終了する。

メイン会話には以下を返す:
- run_id
- 保存先
- 状態: `started`

verify.json の生成完了後、monitor 側が終了判定ロジックに従い結果を返す。

## monitor 側の終了判定（verify.json 生成後）

verifyは1run_idにつき1回のみ。partially_passedでも再verifyせずfix→diffcheckへ。

| 条件 | 次アクション |
|------|-------------|
| passed | 終了 |
| failed | エラー報告→終了 |
| new highあり | /mysk-review-fix→/mysk-review-diffcheck→終了 |
| high残存 | /mysk-review-fix→/mysk-review-diffcheck→終了 |
| mediumのみ | ユーザー確認 |

## 完了後案内

verify 完了後：

verify が passed の場合：
```
次: レビューサイクル完了
```

新たな high または未修正の high がある場合：
```
次: /mysk-review-fix で指摘を修正
```

medium のみの場合：
```
次: medium 指摘あり。/mysk-review-fix で対応するか終了
```

- 上記条件を満たさない（エラー等）場合は案内なし
