# cmuxサブペイン起動手順

ペインを作成し、1つのBashコマンドでClaude Codeを起動し、Trust確認の検知とプロンプト待ちを行います。手順を分割しないでください。分割するとClaude Codeがスキップする可能性があります。

**重要**: cmuxコマンドでは常に長いオプション（--workspace/--surface）とref形式（workspace:N/surface:N）を使用してください。sendコマンドは短いオプション-w/-sを認識しません。

**前提依存**:
- `cmux`: 別ペイン実行に必須
- `python3`: JSON解析に必須
- `grep`, `sed`: テキスト処理に必須

以下のスクリプトを実行してください（{WORK_DIR}を作業ディレクトリに置換）:

```bash
WS_REF=$(cmux identify | python3 -c "import sys,json; print(json.load(sys.stdin)['caller']['workspace_ref'])")
[ -z "$WS_REF" ] && { echo "Error: WS_REF is empty"; exit 1; }
echo "WS_REF=$WS_REF"

SPLIT_OUTPUT=$(cmux new-split right --workspace "$WS_REF")
sleep 1
SUB_SURFACE=$(echo "$SPLIT_OUTPUT" | grep -oE 'surface:[0-9]+' | head -1)
[ -z "$SUB_SURFACE" ] && { echo "Error: SUB_SURFACE is empty"; exit 1; }
echo "SUB_SURFACE=$SUB_SURFACE"

# 環境変数による権限制御
if [ "$MYSK_SKIP_PERMISSIONS" != "true" ]; then
  PERMISSION_FLAGS=""
else
  PERMISSION_FLAGS="--dangerously-skip-permissions"
  echo "警告: MYSK_SKIP_PERMISSIONS=true により権限制限がスキップされます"
fi

cmux send --workspace "$WS_REF" --surface "$SUB_SURFACE" \
  "cd {WORK_DIR} && claude --model opus --effort max $PERMISSION_FLAGS"
cmux send-key --workspace "$WS_REF" --surface "$SUB_SURFACE" return

echo "LAUNCHED: WS_REF=$WS_REF SUB_SURFACE=$SUB_SURFACE"
```

上記の出力からWS_REFとSUB_SURFACEの値を取得した後、**以下の待機スクリプトを実行してください**:

```bash
# Trust確認の検知と待機 + プロンプト待ち（最大120秒）
# 読み取りコマンド: cmux read-screen --workspace "$WS_REF" --surface "$SUB_SURFACE"

WAIT_READY() {
  local ws="$1" surf="$2" max=120 elapsed=0 interval=3
  while [ "$elapsed" -lt "$max" ]; do
    sleep "$interval"
    elapsed=$((elapsed + interval))
    SCREEN=$(cmux read-screen --workspace "$ws" --surface "$surf" 2>/dev/null || echo "")

    # Trust確認が表示された場合は待機（ユーザー操作を待つ）
    if echo "$SCREEN" | grep -qi "do you trust\|trust this\|trust.*project"; then
      echo "TRUST: 確認待機中（ユーザー操作が必要です）"
      # 自動承認せず、ユーザー操作を待つ
    fi

    # `> ` プロンプトが表示されたら完了
    if echo "$SCREEN" | grep -q '❯'; then
      echo "READY: Claude Code prompt detected at ${elapsed}s"
      return 0
    fi

    echo "WAITING... ${elapsed}s / ${max}s"
  done
  echo "TIMEOUT: Claude Code did not start within ${max}s"
  return 1
}

WAIT_READY "$WS_REF" "$SUB_SURFACE"
```

`READY:` が出力されたらサブペインの準備が完了です。`TIMEOUT:` の場合はエラーとして扱ってください。
