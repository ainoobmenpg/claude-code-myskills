---
description: 仕様書をレビューし反映確認まで実施（別ペイン・Opus）
argument-hint: "[run_id]"
user-invocable: true
---

# mysk-spec-review

`/mysk-spec-draft` が保存した仕様書をレビューし、不備や改善点を指摘する。
cmux 別ペインで Opus モデルを実行し、レビュー結果をJSONで保存する。

## ディレクトリ構造

- **データ保存先**: `~/.local/share/claude-mysk/`
- `WORK_DIR`: `git rev-parse --show-toplevel 2>/dev/null || pwd`（プロジェクト作業ディレクトリ）

## 前提条件

- `CMUX_SOCKET_PATH`環境変数が存在すること
- cmux-launch-procedure.md テンプレートが存在すること

**必要ツール**:
- `python3`: JSON解析用
- `jq`: JSON解析用（フォールバック）
- `grep`, `sed`: テキスト処理用

## 実行フロー

**注意: 二重起動防止**: このコマンドは1回の呼び出しで1回だけサブペインを起動すること。同じターン内でフローを再開始しないこと。コンテキスト圧縮後も、既にサブペインが起動済み（READY: を受信済み）なら step 4 以降を続行し、step 1-3 をやり直さないこと。

### 1. 初期化

- `$ARGUMENTS` から run_id を取得、または省略時は最新の run_id を自動選択
- **データ保存先**: `~/.local/share/claude-mysk/`
- `WORK_DIR`: `git rev-parse --show-toplevel 2>/dev/null || pwd`

### 2. run_id 解決と仕様書パス特定

```bash
# run_id resolution with unified algorithm
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

# 仕様書パスの特定
RUN_DIR="$HOME/.local/share/claude-mysk/$RUN_ID"
if [ -f "$RUN_DIR/spec.md" ]; then
  SPEC_PATH="$RUN_DIR/spec.md"
elif [ -f "$RUN_DIR/spec-draft.md" ]; then
  SPEC_PATH="$RUN_DIR/spec-draft.md"
else
  echo "Error: Spec not found for run_id: $RUN_ID"
  exit 1
fi

# 出力パス
REVIEW_PATH="$RUN_DIR/spec-review.json"
STATUS_FILE="$RUN_DIR/status.json"
DRAFT_PATH="$RUN_DIR/spec-draft.md"
```

### 3. セクション確認（参考）

仕様書に以下のセクションが含まれているか確認：
- 概要、目的、利用者、ユースケース、入出力、スコープ、受け入れ条件

欠如しているセクションがある場合:
- エラー終了しない（I/Oエラーのみハードフェイル）
- 欠如セクションはレビュー観点「完全性」にて high severity 指摘として報告される
- レビューを通常通り続行する

### 4. サブペインの準備と起動完了待ち

テンプレートファイルの存在確認:
```bash
for f in cmux-launch-procedure.md spec-review-prompt.md spec-review-monitor.md; do
  [ -f "$HOME/.claude/templates/mysk/$f" ] || { echo "Error: Template not found: $f"; exit 1; }
done
```

`$HOME/.claude/templates/mysk/cmux-launch-procedure.md` を読み、`{WORK_DIR}`→`$WORK_DIR` に置換して実行。

**重要**: テンプレートには2つのスクリプトブロック（起動スクリプト＋待機スクリプト）が含まれている。両方を順番に実行すること。
待機スクリプトはTrust確認をユーザー操作待ちとし、`❯` プロンプトを検出するまでポーリングする。
`READY:` が出力されるまで次のステップに進まないこと。`TIMEOUT:` の場合はエラーとして扱ってください。

### 5. プロンプトの送信

`READY:` が確認できたら、プロンプトを送信する:

1. sed でテンプレート変数を置換し、一時ファイルに保存
2. 短い読み込み指示を `cmux send` でサブペインに送信

```bash
sed -e "s|{RUN_ID}|$RUN_ID|g" -e "s|{SPEC_PATH}|$SPEC_PATH|g" \
    -e "s|{REVIEW_PATH}|$REVIEW_PATH|g" -e "s|{STATUS_FILE}|$STATUS_FILE|g" \
    -e "s|{PROJECT_ROOT}|$WORK_DIR|g" \
  $HOME/.claude/templates/mysk/spec-review-prompt.md > "/tmp/mysk-${RUN_ID}-prompt.txt"

cmux send --workspace "$WS_REF" --surface "$SUB_SURFACE" \
  "Read /tmp/mysk-${RUN_ID}-prompt.txt and follow all instructions in it exactly."
cmux send-key --workspace "$WS_REF" --surface "$SUB_SURFACE" return
```

### 6. 状態監視

bashでsedを実行してモニターテキストを生成し、そのテキストを使って **CronCreateツール**（bashコマンドではない）で監視ジョブを登録する。

```bash
GRACE_FILE=$(dirname "$STATUS_FILE")/timeout-grace.json
sed -e "s|{STATUS_FILE}|$STATUS_FILE|g" -e "s|{REVIEW_PATH}|$REVIEW_PATH|g" \
    -e "s|{WS_REF}|$WS_REF|g" -e "s|{SUB_SURFACE}|$SUB_SURFACE|g" \
    -e "s|{SPEC_PATH}|$SPEC_PATH|g" -e "s|{DRAFT_PATH}|$DRAFT_PATH|g" -e "s|{RUN_DIR}|$RUN_DIR|g" \
    -e "s|{GRACE_FILE}|$GRACE_FILE|g" \
    $HOME/.claude/templates/mysk/spec-review-monitor.md
```

上記の出力テキストをpromptに指定し、CronCreateツールを呼ぶ:
- cron: `*/1 * * * *`
- recurring: true

### 7. このコマンドで返す内容

このコマンドでは、レビュー開始と監視ジョブ登録までを行う。
レビュー完了前にユーザー確認へ進めてはならない。

メイン会話には以下を返す:
- run_id
- 保存先
- 状態: `started`

レビュー完了後、monitor 側が要約と次ステップ案内を表示し、クリーンアップまで完結する。

## トラブルシューティング

**結果が空の場合**:
thinking ブロックに回答が含まれている可能性があります。thinking を展開して内容を確認してください。

## レビュー観点

- 完全性: 必須セクションが揃っているか
- 明確性: 説明が明確で解釈の余地がないか
- 一貫性: 内容に矛盾がないか
- 実現可能性: 技術的に実装可能か
- テスト可能性: 受け入れ条件が検証可能か

## 出力JSON形式

```json
{
  "version": 1,
  "run_id": "{run_id}",
  "created_at": "UTCタイムスタンプ",
  "source": {"type": "spec", "value": "仕様書タイトル"},
  "summary": {
    "overall_quality": "high|medium|low",
    "headline": "全体評価の1行要約",
    "finding_count": {"high": N, "medium": N, "low": N}
  },
  "findings": [
    {
      "id": "F1",
      "severity": "high|medium|low",
      "section": "完全性|明確性|一貫性|実現可能性|テスト可能性",
      "title": "指摘タイトル",
      "detail": "詳細な説明",
      "suggestion": "改善提案"
    }
  ]
}
```


