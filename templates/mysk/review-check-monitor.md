Use Bash to read the review file and check the status field:
```bash
cat {REVIEW_JSON_PATH} 2>/dev/null || echo "NOT_FOUND"
```
Parse the JSON output to extract the status field.

If the file does not exist yet:
- Do nothing. Do not output any message. Do not run any bash commands.
- Just wait for the next check.

## JSON読み取り（フォールバック付き）

サブエージェントがJSON契約に完全準拠しない場合があるため、以下のフォールバックで読み取る:

- **status**: `.status` → ない場合、`"in_progress"` として扱う（フォールバックしない）
- **findings配列**: `.findings` → ない場合 `.issues` も試す
- **各finding**:
  - `severity`: `.severity`
  - `file`: `.file` → ない場合 `.location` からコロン前を抽出
  - `line`: `.line` → ない場合 `.location` からコロン後を抽出（ハイフン区切りなら先頭）
  - `title`: `.title`
  - `detail`: `.detail` → ない場合 `.description`
  - `suggested_fix`: `.suggested_fix` → ない場合 `.suggestion`
  - `id`: `.id`
- **summary**:
  - `finding_count`: `.summary.finding_count` → ない場合 `.summary.total` → ない場合 `findings.length`
  - `overall_risk`: `.summary.overall_risk` → ない場合 findingsのseverity分布から推定（highあり→"high"、mediumのみ→"medium"、lowのみ→"low"）
  - high/medium/low件数: `.summary.high`等 → ない場合 findingsから集計
- **source**: `.source.value` → ない場合 `.target`
- **project_root**: `.project_root`
- **created_at**: `.created_at` → ない場合 `.reviewed_at`
- **run_id**: `.run_id`

**If the status field does not exist**:
1. FIRST: Find review-check-monitor job in CronList and delete it using CronDelete
2. Display error: "エラー: review.json に必須の 'status' フィールドがありません。サブエージェントがプロンプトの指示に従いませんでした。"
3. Display review.json content for debugging: `cat {REVIEW_JSON_PATH}`
4. Execute cleanup:
   - cmux send --workspace {WS_REF} --surface {SUB_SURFACE} "/exit"
   - cmux send-key --workspace {WS_REF} --surface {SUB_SURFACE} return
   - sleep 2
   - cmux close-surface --workspace {WS_REF} --surface {SUB_SURFACE}
5. Stop processing

If status is "completed":
1. FIRST: Find review-check-monitor job in CronList and delete it using CronDelete. This must happen before any output to prevent duplicate firings.
2. Use Bash to read the review file and extract data using fallback rules above:
   ```bash
   cat {REVIEW_JSON_PATH} 2>/dev/null || echo "NOT_FOUND"
   ```
3. Display the following summary in Japanese:
   - run_id (from .run_id or "{RUN_ID}")
   - Target (source.value or .target)
   - Summary (total count, high/medium/low counts, overall risk)
   - Main findings (from high priority, ID, title, file:line, detail, suggested_fix)
   - 保存先パス
   - "次のステップ: 修正計画を作成するには /mysk-review-fix {RUN_ID}"
4. Cleanup:
   - rm -f {GRACE_FILE}
   - cmux send --workspace {WS_REF} --surface {SUB_SURFACE} "/exit"
   - cmux send-key --workspace {WS_REF} --surface {SUB_SURFACE} return
   - sleep 2
   - cmux close-surface --workspace {WS_REF} --surface {SUB_SURFACE}

If status is "failed":
1. FIRST: Delete review-check-monitor using CronDelete
2. Display error content (.progress)
3. Execute same cleanup as completed step 4 above

If status is "waiting_for_user":
1. Display "サブエージェントが質問を待っています。サブペインで回答してください。"
2. Display "cmux focus-surface --workspace {WS_REF} --surface {SUB_SURFACE}"
Do nothing else (do not delete job)

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
        - "中止" → Delete review-check-monitor using CronDelete, then execute cleanup:
          - rm -f {GRACE_FILE}
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
        - "中止" → Delete review-check-monitor using CronDelete, then execute cleanup:
     - rm -f {GRACE_FILE}
     - cmux send --workspace {WS_REF} --surface {SUB_SURFACE} "/exit"
     - sleep 1
     - cmux send-key --workspace {WS_REF} --surface {SUB_SURFACE} return
     - sleep 2
     - cmux close-surface --workspace {WS_REF} --surface {SUB_SURFACE}

Otherwise (in_progress with recent updated_at):
Do nothing
