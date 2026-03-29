# cmuxサブペイン起動手順

ペインを作成し、1つのBashコマンドでClaude Codeを起動し、Trust確認とプロンプト待ちを自動化します。手順を分割しないでください。分割するとClaude Codeがスキップする可能性があります。

**重要**: cmuxコマンドでは常に長いオプション（--workspace/--surface）とref形式（workspace:N/surface:N）を使用してください。sendコマンドは短いオプション-w/-sを認識しません。

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

cmux send --workspace "$WS_REF" --surface "$SUB_SURFACE" \
  "cd {WORK_DIR} && claude --model opus --effort max --dangerously-skip-permissions"
cmux send-key --workspace "$WS_REF" --surface "$SUB_SURFACE" return

echo "LAUNCHED: WS_REF=$WS_REF SUB_SURFACE=$SUB_SURFACE"
```

上記の出力からWS_REFとSUB_SURFACEの値を取得した後、**以下の待機スクリプトを実行してください**:

```bash
# Trust確認の自動承認 + プロンプト待ち（最大120秒）
# 読み取りコマンド: cmux read-screen --workspace "$WS_REF" --surface "$SUB_SURFACE"

WAIT_READY() {
  local ws="$1" surf="$2" max=120 elapsed=0 interval=3
  while [ "$elapsed" -lt "$max" ]; do
    sleep "$interval"
    elapsed=$((elapsed + interval))
    SCREEN=$(cmux read-screen --workspace "$ws" --surface "$surf" 2>/dev/null || echo "")

    # Trust確認が表示されたら "y" を押す（--dangerously-skip-permissions なら通常表示されない）
    if echo "$SCREEN" | grep -qi "do you trust\|trust this\|trust.*project"; then
      cmux send --workspace "$ws" --surface "$surf" "y"
      cmux send-key --workspace "$ws" --surface "$surf" return
      echo "TRUST: auto-accepted at ${elapsed}s"
      sleep 5
      continue
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
