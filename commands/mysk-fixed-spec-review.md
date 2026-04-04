---
description: fixed-specをレビューし凍結まで実施（別ペイン・Opus）
argument-hint: "[run_id]"
user-invocable: true
---

# mysk-fixed-spec-review

`/mysk-fixed-spec-draft` が保存した fixed-spec をレビューし、executor が迷わない short spec に整える。

## ディレクトリ構造

- **データ保存先**: `~/.local/share/claude-mysk/`
- `WORK_DIR`: `git rev-parse --show-toplevel 2>/dev/null || pwd`（プロジェクト作業ディレクトリ）

## 前提条件

- `CMUX_SOCKET_PATH` 環境変数が存在すること
- cmux-launch-procedure.md テンプレートが存在すること

## 実行フロー

**注意: 二重起動防止**: このコマンドは1回の呼び出しで1回だけサブペインを起動すること。同じターン内でフローを再開始しないこと。コンテキスト圧縮後も、既にサブペインが起動済み（READY: を受信済み）なら step 4 以降を続行し、step 1-3 をやり直さないこと。

### 1. 初期化

- `$ARGUMENTS` から run_id を取得、または省略時は最新の run_id を自動選択
- **データ保存先**: `~/.local/share/claude-mysk/`
- `WORK_DIR`: `git rev-parse --show-toplevel 2>/dev/null || pwd`

### 2. run_id 解決と fixed-spec パス特定

```bash
if [ -n "$ARGUMENTS" ]; then
  RUN_ID="$ARGUMENTS"
else
  WORK_DIR=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
  CANDIDATES=$(ls -t ~/.local/share/claude-mysk/ 2>/dev/null || echo "")
  SELECTED_RUN_ID=""

  for CANDIDATE in $CANDIDATES; do
    CANDIDATE_DIR="$HOME/.local/share/claude-mysk/$CANDIDATE"
    RUN_META_PATH="$CANDIDATE_DIR/run-meta.json"

    if [ -f "$RUN_META_PATH" ]; then
      CANDIDATE_ROOT=$(jq -r '.project_root // empty' "$RUN_META_PATH" 2>/dev/null)
      if [ "$CANDIDATE_ROOT" = "$WORK_DIR" ]; then
        SELECTED_RUN_ID="$CANDIDATE"
        break
      fi
    fi
  done

  if [ -z "$SELECTED_RUN_ID" ]; then
    echo "Error: 現在のプロジェクトに該当するrun_idがありません。run_idを明示的に指定してください"
    exit 1
  fi

  RUN_ID="$SELECTED_RUN_ID"
fi

RUN_DIR="$HOME/.local/share/claude-mysk/$RUN_ID"
if [ -f "$RUN_DIR/fixed-spec.md" ]; then
  SPEC_PATH="$RUN_DIR/fixed-spec.md"
elif [ -f "$RUN_DIR/fixed-spec-draft.md" ]; then
  cp "$RUN_DIR/fixed-spec-draft.md" "$RUN_DIR/fixed-spec.md"
  SPEC_PATH="$RUN_DIR/fixed-spec.md"
else
  echo "Error: fixed spec not found for run_id: $RUN_ID"
  exit 1
fi

REVIEW_PATH="$RUN_DIR/fixed-spec-review.json"
STATUS_FILE="$RUN_DIR/status.json"
DRAFT_PATH="$RUN_DIR/fixed-spec-draft.md"
```

### 3. サブペインの準備と起動完了待ち

テンプレート存在確認:
```bash
for f in cmux-launch-procedure.md fixed-spec-review-prompt.md fixed-spec-review-monitor.md; do
  [ -f "$HOME/.claude/templates/mysk/$f" ] || { echo "Error: Template not found: $f"; exit 1; }
done
```

`$HOME/.claude/templates/mysk/cmux-launch-procedure.md` を読み、`{WORK_DIR}`→`$WORK_DIR` に置換して実行。

### 4. プロンプトの送信

```bash
sed -e "s|{RUN_ID}|$RUN_ID|g" -e "s|{SPEC_PATH}|$SPEC_PATH|g" \
    -e "s|{REVIEW_PATH}|$REVIEW_PATH|g" -e "s|{STATUS_FILE}|$STATUS_FILE|g" \
    -e "s|{PROJECT_ROOT}|$WORK_DIR|g" \
  "$HOME/.claude/templates/mysk/fixed-spec-review-prompt.md" > "/tmp/mysk-${RUN_ID}-prompt.txt"

cmux send --workspace "$WS_REF" --surface "$SUB_SURFACE" \
  "Read /tmp/mysk-${RUN_ID}-prompt.txt and follow all instructions in it exactly."
cmux send-key --workspace "$WS_REF" --surface "$SUB_SURFACE" return
```

### 5. 状態監視

```bash
GRACE_FILE=$(dirname "$STATUS_FILE")/timeout-grace.json
sed -e "s|{STATUS_FILE}|$STATUS_FILE|g" -e "s|{REVIEW_PATH}|$REVIEW_PATH|g" \
    -e "s|{WS_REF}|$WS_REF|g" -e "s|{SUB_SURFACE}|$SUB_SURFACE|g" \
    -e "s|{SPEC_PATH}|$SPEC_PATH|g" -e "s|{DRAFT_PATH}|$DRAFT_PATH|g" -e "s|{RUN_DIR}|$RUN_DIR|g" \
    -e "s|{GRACE_FILE}|$GRACE_FILE|g" \
    -e "s|{RUN_ID}|$RUN_ID|g" \
    -e "s|{TEST_MODE}|${MYSK_TEST_MODE:-0}|g" \
    "$HOME/.claude/templates/mysk/fixed-spec-review-monitor.md"
```

上記の出力テキストを prompt に指定し、CronCreate ツールを呼ぶ:
- cron: `*/1 * * * *`
- recurring: true

### 6. このコマンドで返す内容

このコマンドでは、レビュー開始と監視ジョブ登録までを行う。

メイン会話には以下を返す:
- run_id
- 保存先
- 状態: `started`

レビュー完了後、monitor 側が要約と次ステップ案内を表示し、fixed-spec の軽微な反映確認まで完結する。

## レビュー観点

- executor clarity: executor が質問なしで着手できるか
- scope discipline: in-scope / out-of-scope / allowed paths が十分か
- acceptance clarity: 完了条件が客観的か
- edge cases: failure modes が不足していないか
- implementation fit: repo 実態に照らして実装可能か

## 完了後案内

既定の次ステップ:
```
次: /mysk-implement-start で実装を開始
```

大規模変更のみ任意で:
```
任意: /mysk-spec-implement で実装計画を追加作成
```
