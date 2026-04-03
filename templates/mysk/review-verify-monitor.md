Read {VERIFY_JSON_PATH} and check the status field.

If the file does not exist yet:
- Do nothing. Do not output any message. Do not run any bash commands.
- Just wait for the next check.

## JSON読み取り（フォールバック付き）

サブエージェントがJSON契約に完全準拠しない場合があるため、以下のフォールバックで読み取る:

- **status**: `.status` → ない場合、`"in_progress"` として扱う（フォールバックしない）
- **verification_result**: `.verification_result` → ない場合以下の順序で推定（schemaと同じ優先順位）:
  1. high_remaining > 0 または medium_remaining > 0 または low_remaining > 0 または new_findingsにseverity=="high"/"medium"/"low"が存在 → "failed"
  2. 全て fixed/passed → "passed"
  3. エラーのみ → "failed"
- **verifications配列**: `.verifications` → ない場合 `.findings` も試す
- **各verification**:
  - original_finding_id: `.original_finding_id` → ない場合 `.id` → ない場合 `.finding_id`
  - status: `.status`（"fixed"/"not_fixed"/"open"/"unresolved" → "open"/"unresolved"は"not_fixed"として扱う）
  - detail/evidence: `.detail` → ない場合 `.evidence` → ない場合 `.description`
- **summary**:
  - verified_count: `.summary.verified_count` → ない場合 verifications.length
  - fixed_count: `.summary.fixed_count` → ない場合 verificationsからstatus=="fixed"を数える
  - remaining_count: `.summary.remaining_count` → ない場合 verified_count - fixed_count
  - high_remaining: `.summary.high_remaining` → ない場合 verificationsからseverity=="high"かつstatus!="fixed"を数える
  - medium_remaining: `.summary.medium_remaining` → ない場合 verificationsからseverity=="medium"かつstatus!="fixed"を数える
  - low_remaining: `.summary.low_remaining` → ない場合 verificationsからseverity=="low"かつstatus!="fixed"を数える
  - new_issues_count: `.summary.new_issues_count` → ない場合 0
- **new_findings**: `.new_findings` → ない場合空配列

If status is "completed":
1. FIRST: Find review-verify-monitor job in CronList and delete it using CronDelete. This must happen before any output to prevent duplicate firings.
2. Read {VERIFY_JSON_PATH} and extract data using fallback rules above
3. Determine verification_result using fallback rules
4. Execute termination logic (see below). Each path includes cleanup at the end.

**If the status field does not exist**:
1. FIRST: Delete review-verify-monitor using CronDelete
2. Display error: "エラー: {VERIFY_JSON_PATH} に必須の 'status' フィールドがありません。サブエージェントがプロンプトの指示に従いませんでした。"
3. Display file content for debugging: `cat {VERIFY_JSON_PATH}`
4. Execute cleanup:
   - cmux send --workspace {WS_REF} --surface {SUB_SURFACE} "/exit"
   - cmux send-key --workspace {WS_REF} --surface {SUB_SURFACE} return
   - sleep 2
   - cmux close-surface --workspace {WS_REF} --surface {SUB_SURFACE}

If status is "failed":
1. FIRST: Find review-verify-monitor job in CronList and delete it using CronDelete
2. Read {VERIFY_JSON_PATH} and display the error content in progress field
3. Perform cleanup:
   ```bash
   cmux send --workspace {WS_REF} --surface {SUB_SURFACE} "/exit" && sleep 1 && cmux send-key --workspace {WS_REF} --surface {SUB_SURFACE} return && sleep 2 && cmux close-surface --workspace {WS_REF} --surface {SUB_SURFACE}
   ```

If status is "in_progress":
1. Check if updated_at is more than 30 minutes ago:
   - Get current time: `date -u +%Y-%m-%dT%H:%M:%SZ`
   - Parse updated_at and calculate difference using bash:
     ```bash
     UPDATED_AT="{updated_atの値}"
     CURRENT_TIME=$(date -u +%Y-%m-%dT%H:%M:%SZ)
     UPDATED_TS=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$UPDATED_AT" +%s 2>/dev/null || date -d "$UPDATED_AT" +%s)
     CURRENT_TS=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$CURRENT_TIME" +%s 2>/dev/null || date -d "$CURRENT_TIME" +%s)
     DIFF_MINUTES=$(( (CURRENT_TS - UPDATED_TS) / 60 ))
     ```
   - If `$DIFF_MINUTES -gt 30`:
     # 猶予チェック（Claude プロンプトレベル）
     GRACE_FILE="{GRACE_FILE}"

     # Step 1: Grace file の存在確認と読み取り
     Use Bash to check if file exists and read content:
     ```bash
     if [ -f "$GRACE_FILE" ]; then
       cat "$GRACE_FILE"
     else
       echo "NO_GRACE_FILE"
     fi
     ```

     # Step 2: 猶予期限内かどうかを判定
     If grace file exists and has grace_until:
     - Use Bash to convert grace_until to timestamp:
       ```bash
       GRACE_UNTIL=$(cat "$GRACE_FILE" | grep -o '"grace_until":"[^"]*"' | cut -d'"' -f4)
       date -j -f "%Y-%m-%dT%H:%M:%SZ" "$GRACE_UNTIL" +%s 2>/dev/null || date -d "$GRACE_UNTIL" +%s
       ```
     - Use Bash to get current timestamp:
       ```bash
       date -u +%s
       ```
     - If current_timestamp < grace_timestamp: Do nothing (猶予期限内、監視を継続)
     - If current_timestamp >= grace_timestamp: Continue to timeout display

     (grace file doesn't exist or grace period expired)

     # Read count for warning message
     Use Bash to get count:
     ```bash
     if [ -f "$GRACE_FILE" ]; then
       cat "$GRACE_FILE" | grep -o '"count":[0-9]*' | cut -d: -f2
     else
       echo "0"
     fi
     ```

     If count >= 3:
       1. Display "サブエージェントが30分以上応答していません（{count}回目の確認）。長時間の extended thinking が続いている可能性があります。"
       2. Display "サブペインを確認: cmux focus-surface --workspace {WS_REF} --surface {SUB_SURFACE}"
       3. Use AskUserQuestion with the following options:
        - "待機続行" → Execute bash to set grace with progressive extension:
         ```bash
         GRACE_FILE="{GRACE_FILE}"

         # Read current count (default 0)
         if [ -f "$GRACE_FILE" ]; then
           CURRENT_COUNT=$(cat "$GRACE_FILE" | grep -o '"count":[0-9]*' | cut -d: -f2)
           CURRENT_COUNT=${CURRENT_COUNT:-0}
         else
           CURRENT_COUNT=0
         fi

         # Calculate new count and grace duration
         NEW_COUNT=$((CURRENT_COUNT + 1))
         case $NEW_COUNT in
           1) EXTEND_MINUTES=10 ;;
           2) EXTEND_MINUTES=15 ;;
           *) EXTEND_MINUTES=20 ;;
         esac

         # Calculate grace_until with macOS/Linux fallback
         GRACE_UNTIL=$(date -u -d "+${EXTEND_MINUTES} minutes" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -v+${EXTEND_MINUTES}M +%Y-%m-%dT%H:%M:%SZ)
         echo "{\"grace_until\":\"$GRACE_UNTIL\",\"count\":$NEW_COUNT}" > "$GRACE_FILE"
         ```
         Then do nothing (監視を継続)
        - "中止" → Delete review-verify-monitor using CronDelete, then execute cleanup:
          - cmux send --workspace {WS_REF} --surface {SUB_SURFACE} "/exit" && sleep 1 && cmux send-key --workspace {WS_REF} --surface {SUB_SURFACE} return && sleep 2 && cmux close-surface --workspace {WS_REF} --surface {SUB_SURFACE}
     Else:
       1. Display "サブエージェントが30分以上応答していません。タイムアウトの可能性があります。"
       2. Display "サブペインを確認: cmux focus-surface --workspace {WS_REF} --surface {SUB_SURFACE}"
       3. Use AskUserQuestion with the following options:
        - "待機続行" → Execute bash to set grace with progressive extension:
         ```bash
         GRACE_FILE="{GRACE_FILE}"

         # Read current count (default 0)
         if [ -f "$GRACE_FILE" ]; then
           CURRENT_COUNT=$(cat "$GRACE_FILE" | grep -o '"count":[0-9]*' | cut -d: -f2)
           CURRENT_COUNT=${CURRENT_COUNT:-0}
         else
           CURRENT_COUNT=0
         fi

         # Calculate new count and grace duration
         NEW_COUNT=$((CURRENT_COUNT + 1))
         case $NEW_COUNT in
           1) EXTEND_MINUTES=10 ;;
           2) EXTEND_MINUTES=15 ;;
           *) EXTEND_MINUTES=20 ;;
         esac

         # Calculate grace_until with macOS/Linux fallback
         GRACE_UNTIL=$(date -u -d "+${EXTEND_MINUTES} minutes" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -v+${EXTEND_MINUTES}M +%Y-%m-%dT%H:%M:%SZ)
         echo "{\"grace_until\":\"$GRACE_UNTIL\",\"count\":$NEW_COUNT}" > "$GRACE_FILE"
         ```
         Then do nothing (監視を継続)
        - "中止" → Delete review-verify-monitor using CronDelete, then execute cleanup:
          - cmux send --workspace {WS_REF} --surface {SUB_SURFACE} "/exit" && sleep 1 && cmux send-key --workspace {WS_REF} --surface {SUB_SURFACE} return && sleep 2 && cmux close-surface --workspace {WS_REF} --surface {SUB_SURFACE}

Otherwise (in_progress with recent updated_at):
Do nothing

### verify状態機械schemaの参照

終了判定ロジックは、以下のschemaの定義に従ってください:
```bash
cat ~/.claude/templates/mysk/verify-schema.json
```

**重要**: `verification_result` の判定は、schemaの `definitions.result_criteria` に従ってください。

### Termination Logic (when status is completed)

**Important**: verifyの再実行ポリシーに従ってください。初回はverify.json、再実行時はverify-rerun.jsonに保存されます。verify-rerun.jsonが存在する場合はそちらを最新の真実として扱います。

以下のフローに従って結果を表示し、次のアクションを決定してください。

```
検証完了
       ↓
┌──────────────────────────────────┐
│ verification_result == "passed" ? │
│ → Yes: 【End】                    │
│ → No: continue                   │
└──────────────────────────────────┘
       ↓
┌──────────────────────────────────┐
│ new_findings has high?           │
│ → Yes: error report → 【End】    │
│ → No: continue                   │
└──────────────────────────────────┘
       ↓
┌──────────────────────────────────┐
│ summary.high_remaining > 0 ?      │
│ → Yes: error report → 【End】    │
│ → No: continue                   │
└──────────────────────────────────┘
       ↓
┌──────────────────────────────────┐
│ any non-high (medium/low)?       │
│ → Yes: /mysk-review-fix に戻る   │
│ → No: 【End】                    │
└──────────────────────────────────┘
```

### 終了条件と表示メッセージ

| 条件 | verification_result | 次のアクション |
|-----------|---------------------|-------------|
| すべて修正済み、新規問題なし | `passed` | **終了** |
| 新規`high`発見 | （fallbackにより "failed"） | エラーレポート → **終了** |
| 未修正の`high`あり | （fallbackにより "failed"） | エラーレポート → **終了** |
| `high`なし、non-high（medium/low）あり | （fallbackにより "failed"） | /mysk-review-fix に戻る |
| `high`なし、未解決なし | `passed` | **終了** |

**When ending**:

```
検証が完了しました。

## run_id
{RUN_ID}

## ステータス
passed

## 結果
- 修正検証: すべて修正済み
- 新規問題: なし

## 保存先
{VERIFY_JSON_PATH}

レビューサイクルが完了しました。
```

Then perform cleanup:
```bash
rm -f {GRACE_FILE}
cmux send --workspace {WS_REF} --surface {SUB_SURFACE} "/exit" && sleep 1 && cmux send-key --workspace {WS_REF} --surface {SUB_SURFACE} return && sleep 2 && cmux close-surface --workspace {WS_REF} --surface {SUB_SURFACE}
```

**When high exists (failed)**:

```
検証が完了しました。

## run_id
{RUN_ID}

## ステータス
failed

## 高優先度の問題
- [新規] N001: src/auth/middleware.ts:25 - 型定義なし
- [未修正] F003: src/auth/jwt.ts:10 - nullチェックなし

## 保存先
{VERIFY_JSON_PATH}

高優先度の未解決問題があるため、レビューサイクルを終了します。
```

Then perform cleanup:
```bash
rm -f {GRACE_FILE}
cmux send --workspace {WS_REF} --surface {SUB_SURFACE} "/exit" && sleep 1 && cmux send-key --workspace {WS_REF} --surface {SUB_SURFACE} return && sleep 2 && cmux close-surface --workspace {WS_REF} --surface {SUB_SURFACE}
```


**When error**:

```
検証が失敗しました。

## run_id
{RUN_ID}

## エラー内容
{error message}
```

Then perform cleanup:
```bash
rm -f {GRACE_FILE}
cmux send --workspace {WS_REF} --surface {SUB_SURFACE} "/exit" && sleep 1 && cmux send-key --workspace {WS_REF} --surface {SUB_SURFACE} return && sleep 2 && cmux close-surface --workspace {WS_REF} --surface {SUB_SURFACE}
```
