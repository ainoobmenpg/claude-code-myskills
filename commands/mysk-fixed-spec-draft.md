---
description: 別ペインでfixed-specを下書き作成
argument-hint: "[topic]"
user-invocable: true
---

# mysk-fixed-spec-draft

別ペインで planner 用のサブエージェントを起動し、**fixed-spec artifact** の下書きを作成する。

## 目的

- brief を短く固定された実装仕様に落とす
- 下位モデル executor が質問なしで実装を始められる状態にする
- interactive な要件収集ではなく、artifact-heavy guidance を default にする

## ディレクトリ構造

`~/.local/share/claude-mysk/{timestamp}-{slug}/` に fixed-spec 関連成果物を保存。

```
~/.local/share/claude-mysk/{run_id}/
├── fixed-spec-draft.md
├── fixed-spec.md
├── fixed-spec-review.json
├── run-meta.json
└── status.json
```

timestamp: UTC の `YYYYMMDD-HHMMSSZ` 形式、slug: トピックから生成（英訳、小文字、ハイフン区切り、最大20文字）

## 前提条件

- `CMUX_SOCKET_PATH` 環境変数が存在すること

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
- 出力パス:
  - `DRAFT_PATH="$RUN_DIR/fixed-spec-draft.md"`
  - `FIXED_SPEC_PATH="$RUN_DIR/fixed-spec.md"`
  - `STATUS_FILE="$RUN_DIR/status.json"`

**run-meta.json 生成**:

```bash
RUN_DIR="$HOME/.local/share/claude-mysk/$RUN_ID"
DRAFT_PATH="$RUN_DIR/fixed-spec-draft.md"
FIXED_SPEC_PATH="$RUN_DIR/fixed-spec.md"
STATUS_FILE="$RUN_DIR/status.json"
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

テンプレート存在確認:
```bash
for f in cmux-launch-procedure.md fixed-spec-draft-prompt.md fixed-spec-draft-monitor.md; do
  [ -f "$HOME/.claude/templates/mysk/$f" ] || { echo "Error: Template not found: $f"; exit 1; }
done
```

`$HOME/.claude/templates/mysk/cmux-launch-procedure.md` を読み、`{WORK_DIR}`→`$WORK_DIR` に置換して実行。

**重要**: テンプレートには2つのスクリプトブロック（起動スクリプト＋待機スクリプト）が含まれている。両方を順番に実行すること。
待機スクリプトは Trust 確認をユーザー操作待ちとし、`❯` プロンプトを検出するまでポーリングする。
`READY:` が出力されるまで次のステップに進まないこと。`TIMEOUT:` の場合はエラーとして扱ってください。

### 3. プロンプトの送信

`READY:` が確認できたら、プロンプトを送信する:

```bash
sed -e "s|{TOPIC}|$TOPIC|g" -e "s|{STATUS_FILE}|$STATUS_FILE|g" -e "s|{DRAFT_PATH}|$DRAFT_PATH|g" \
  "$HOME/.claude/templates/mysk/fixed-spec-draft-prompt.md" > "/tmp/mysk-${RUN_ID}-prompt.txt"

cmux send --workspace "$WS_REF" --surface "$SUB_SURFACE" \
  "Read /tmp/mysk-${RUN_ID}-prompt.txt and follow all instructions in it exactly."
cmux send-key --workspace "$WS_REF" --surface "$SUB_SURFACE" return
```

### 4. 状態監視

bash で sed を実行してモニターテキストを生成し、そのテキストを使って **CronCreate ツール**（bash コマンドではない）で監視ジョブを登録する。

```bash
GRACE_FILE=$(dirname "$STATUS_FILE")/timeout-grace.json
sed -e "s|{STATUS_FILE}|$STATUS_FILE|g" -e "s|{DRAFT_PATH}|$DRAFT_PATH|g" \
    -e "s|{FIXED_SPEC_PATH}|$FIXED_SPEC_PATH|g" \
    -e "s|{WS_REF}|$WS_REF|g" -e "s|{SUB_SURFACE}|$SUB_SURFACE|g" \
    -e "s|{RUN_ID}|$RUN_ID|g" -e "s|{TEST_MODE}|${MYSK_TEST_MODE:-0}|g" \
    -e "s|{GRACE_FILE}|$GRACE_FILE|g" \
    "$HOME/.claude/templates/mysk/fixed-spec-draft-monitor.md"
```

上記の出力テキストを prompt に指定し、CronCreate ツールを呼ぶ:
- cron: `*/1 * * * *`
- recurring: true

### 5. このコマンドで返す内容

このコマンドでは、下書き生成の開始と監視ジョブ登録までを行う。
生成完了前にユーザー確認へ進めてはならない。

メイン会話には以下を返す:
- run_id
- 保存先
- 状態: `started`

fixed-spec-draft.md の生成完了後、monitor 側が要約を表示し、ユーザー確認（はい/いいえ/修正して）を行い、`fixed-spec.md` への確定または破棄まで完結する。

## fixed-spec の必須セクション

- Goal
- In-scope
- Out-of-scope
- Constraints
- Acceptance Criteria
- Edge Cases / Failure Modes
- Allowed Paths / Non-goals
- Test Notes

## 例

`/mysk-fixed-spec-draft 認証リファクタ`
