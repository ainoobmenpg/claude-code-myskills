---
description: 仕様書をレビューしJSONで保存（別ペイン実行・Opus）
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

## 実行フロー

### 1. 初期化

- `$ARGUMENTS` から run_id を取得、または省略時は最新の run_id を自動選択
- **データ保存先**: `~/.local/share/claude-mysk/`
- `WORK_DIR`: `git rev-parse --show-toplevel 2>/dev/null || pwd`

### 2. run_id 解決と仕様書パス特定

```bash
# run_id の解決
if [ -n "$ARGUMENTS" ]; then
  RUN_ID="$ARGUMENTS"
else
  # 最新の run_id を自動選択
  RUN_ID=$(ls -t ~/.local/share/claude-mysk/ | head -1)
  if [ -z "$RUN_ID" ]; then
    echo "Error: レビューデータが見つかりません"
    exit 1
  fi
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
STATUS_FILE="$RUN_DIR/status-review.json"
```

### 3. 必須セクション確認

仕様書に以下のセクションが含まれていることを確認：
- 概要、目的、利用者、ユースケース、入出力、スコープ、受け入れ条件

欠如している場合はエラー終了。

### 4. サブペインの準備と起動完了待ち

テンプレートファイルの存在確認:
```bash
for f in cmux-launch-procedure.md spec-review-prompt.md spec-review-monitor.md; do
  [ -f "$HOME/.claude/templates/mysk/$f" ] || { echo "Error: Template not found: $f"; exit 1; }
done
```

`$HOME/.claude/templates/mysk/cmux-launch-procedure.md` を読み、`{WORK_DIR}`→`$WORK_DIR` に置換して実行。

**重要**: テンプレートには2つのスクリプトブロック（起動スクリプト＋待機スクリプト）が含まれている。両方を順番に実行すること。
待機スクリプトはTrust確認を自動で承認し、`❯` プロンプトを検出するまでポーリングする。
`READY:` が出力されるまで次のステップに進まないこと。`STALLED:` の場合は停滞状態を示す（stall_count >= 10でユーザーに継続/中止を確認）。

### 5. プロンプトの送信

`READY:` が確認できたら、プロンプトを送信する:

1. sed でテンプレート変数を置換し、一時ファイルに保存
2. 短い読み込み指示を `cmux send` でサブペインに送信

```bash
sed -e "s|{RUN_ID}|$RUN_ID|g" -e "s|{SPEC_PATH}|$SPEC_PATH|g" \
    -e "s|{REVIEW_PATH}|$REVIEW_PATH|g" -e "s|{STATUS_FILE}|$STATUS_FILE|g" \
  $HOME/.claude/templates/mysk/spec-review-prompt.md > "/tmp/mysk-${RUN_ID}-prompt.txt"

cmux send --workspace "$WS_REF" --surface "$SUB_SURFACE" \
  "Read /tmp/mysk-${RUN_ID}-prompt.txt and follow all instructions in it exactly."
cmux send-key --workspace "$WS_REF" --surface "$SUB_SURFACE" return
```

### 6. 状態監視

bashでsedを実行してモニターテキストを生成し、そのテキストを使って **CronCreateツール**（bashコマンドではない）で監視ジョブを登録する。

```bash
sed -e "s|{STATUS_FILE}|$STATUS_FILE|g" -e "s|{REVIEW_PATH}|$REVIEW_PATH|g" \
    -e "s|{WS_REF}|$WS_REF|g" -e "s|{SUB_SURFACE}|$SUB_SURFACE|g" \
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

レビュー完了後、monitor 側が以下を返す:
- レビュー結果の要約
- 次のステップ案内

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
  "version": "1.0",
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
      "category": "完全性|明確性|一貫性|実現可能性|テスト可能性",
      "section": "対象セクション名",
      "title": "指摘タイトル",
      "detail": "詳細な説明",
      "suggestion": "改善提案"
    }
  ]
}
```

## 完了後案内

レビュー完了後：
```
次: /mysk-spec-revise でレビュー指摘を反映
```

- spec-review.json が生成された場合に出力
- 上記条件を満たさない（エラー等）場合は案内なし

