# cmuxサブペイン起動手順

ペインを作成し、1つのBashコマンドでClaude Codeを起動し、Trust確認の検知とプロンプト待ちを行います。手順を分割しないでください。分割するとClaude Codeがスキップする可能性があります。

**重要**: cmuxコマンドでは常に長いオプション（--workspace/--surface）とref形式（workspace:N/surface:N）を使用してください。sendコマンドは短いオプション-w/-sを認識しません。

**前提依存**:
- `cmux`: 別ペイン実行に必須
- `python3`: JSON解析に必須
- `grep`, `sed`: テキスト処理に必須

**モデル指定の原則**:
- `MYSK_MODEL_ALIAS` が設定されていれば、その alias を `claude --model` に渡す
- alias (`opus` / `sonnet` / `haiku`) を source of truth とし、provider 固有の実モデル名は診断情報としてだけ扱う
- `MYSK_LAUNCH_META_PATH` が設定されていれば、requested alias と診断情報を JSON に保存する
- `MYSK_LAUNCH_DEBUG_FILE` が設定されていれば、debug log から observed model をベストエフォートで抽出する

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

MODEL_ALIAS="${MYSK_MODEL_ALIAS:-opus}"
MODEL_EFFORT="${MYSK_MODEL_EFFORT:-high}"
LAUNCH_META_PATH="${MYSK_LAUNCH_META_PATH:-}"
LAUNCH_DEBUG_FILE="${MYSK_LAUNCH_DEBUG_FILE:-}"

case "$MODEL_ALIAS" in
  opus)
    CONFIGURED_RUNTIME_MODEL="${ANTHROPIC_DEFAULT_OPUS_MODEL:-}"
    ;;
  sonnet)
    CONFIGURED_RUNTIME_MODEL="${ANTHROPIC_DEFAULT_SONNET_MODEL:-}"
    ;;
  haiku)
    CONFIGURED_RUNTIME_MODEL="${ANTHROPIC_DEFAULT_HAIKU_MODEL:-}"
    ;;
  *)
    CONFIGURED_RUNTIME_MODEL=""
    ;;
esac

if [ -n "$LAUNCH_DEBUG_FILE" ]; then
  mkdir -p "$(dirname "$LAUNCH_DEBUG_FILE")"
  DEBUG_FLAGS="--debug-file '$LAUNCH_DEBUG_FILE'"
else
  DEBUG_FLAGS=""
fi

# 環境変数による権限制御
if [ "$MYSK_SKIP_PERMISSIONS" != "true" ]; then
  PERMISSION_FLAGS=""
else
  PERMISSION_FLAGS="--dangerously-skip-permissions"
  echo "警告: MYSK_SKIP_PERMISSIONS=true により権限制限がスキップされます"
fi

if [ -n "$LAUNCH_META_PATH" ]; then
  mkdir -p "$(dirname "$LAUNCH_META_PATH")"
  python3 - "$LAUNCH_META_PATH" "$MODEL_ALIAS" "$MODEL_EFFORT" "$CONFIGURED_RUNTIME_MODEL" "$LAUNCH_DEBUG_FILE" <<'PY'
import json
import sys
from datetime import datetime, timezone
from pathlib import Path

meta_path = Path(sys.argv[1])
requested_model_alias = sys.argv[2]
requested_effort = sys.argv[3]
configured_runtime_model = sys.argv[4] or None
debug_log_path = sys.argv[5] or None

meta_path.write_text(json.dumps({
    "version": 1,
    "launch_status": "launching",
    "requested_model_alias": requested_model_alias,
    "requested_effort": requested_effort,
    "configured_runtime_model": configured_runtime_model,
    "resolved_runtime_model": None,
    "debug_log_path": debug_log_path,
    "launched_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    "workspace_ref": None,
    "surface_ref": None,
    "ready_at": None
}, ensure_ascii=False, indent=2) + "\n")
PY
fi

cmux send --workspace "$WS_REF" --surface "$SUB_SURFACE" \
  "cd {WORK_DIR} && claude --model $MODEL_ALIAS --effort $MODEL_EFFORT $DEBUG_FLAGS $PERMISSION_FLAGS"
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
WAIT_STATUS=$?

if [ -n "$LAUNCH_META_PATH" ] && [ -f "$LAUNCH_META_PATH" ]; then
  python3 - "$LAUNCH_META_PATH" "$LAUNCH_DEBUG_FILE" "$WS_REF" "$SUB_SURFACE" "$WAIT_STATUS" <<'PY'
import json
import re
import sys
from datetime import datetime, timezone
from pathlib import Path

meta_path = Path(sys.argv[1])
debug_log_path = Path(sys.argv[2]) if sys.argv[2] else None
workspace_ref = sys.argv[3]
surface_ref = sys.argv[4]
wait_status = sys.argv[5]

data = json.loads(meta_path.read_text())
data["workspace_ref"] = workspace_ref
data["surface_ref"] = surface_ref
data["ready_at"] = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
data["launch_status"] = "ready" if wait_status == "0" else "timeout"

resolved_runtime_model = None
if debug_log_path and debug_log_path.is_file():
    debug_text = debug_log_path.read_text(errors="replace")
    matches = re.findall(r"\bmodel=([A-Za-z0-9._-]+)", debug_text)
    if not matches:
        matches = re.findall(r'"model":"([^"]+)"', debug_text)
    if matches:
        resolved_runtime_model = matches[-1]

if resolved_runtime_model:
    data["resolved_runtime_model"] = resolved_runtime_model

meta_path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n")
PY
fi

exit "$WAIT_STATUS"
```

`READY:` が出力されたらサブペインの準備が完了です。`TIMEOUT:` の場合はエラーとして扱ってください。
