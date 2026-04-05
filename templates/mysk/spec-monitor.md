**TEST MODE**: {TEST_MODE} が "1" の場合、completed 時の AskUserQuestion をスキップし、自動的に「はい」を選択して完了メッセージを表示し、cleanup に進んでください。

Use Bash to read the status file and check the status field and updated_at:
```bash
cat {STATUS_FILE} 2>/dev/null || echo "NOT_FOUND"
```
Parse the JSON output to extract status and updated_at fields.

If the file does not exist yet:
- Do nothing. Do not output any message. Do not run any bash commands.
- Just wait for the next check.

**If the status field does not exist**:
1. FIRST: Find spec-monitor job in CronList and delete it using CronDelete
2. Display error: "エラー: {STATUS_FILE} に必須の 'status' フィールドがありません。サブエージェントがプロンプトの指示に従いませんでした。"
3. Display file content for debugging: `cat {STATUS_FILE}`
4. Execute cleanup:
   - cmux send --workspace {WS_REF} --surface {SUB_SURFACE} "/exit"
   - cmux send-key --workspace {WS_REF} --surface {SUB_SURFACE} return
   - sleep 2
   - cmux close-surface --workspace {WS_REF} --surface {SUB_SURFACE}
5. Stop processing

If status is "completed":
1. FIRST: Find spec-monitor job in CronList and delete it using CronDelete. This must happen before any output to prevent duplicate firings.
2. Use Bash to read the spec and display a summary in Japanese:
```bash
cat {SPEC_PATH} 2>/dev/null || echo "NOT_FOUND"
```
   - 概要
   - 目的
   - スコープ（範囲内 / 範囲外）
   - 制約条件
   - 受け入れ条件
3. Use AskUserQuestion to Japanese with the following options:
   - Option 1: "はい" (label: "はい（仕様書を確定して次へ進む）")
   - Option 2: "いいえ" (label: "いいえ（破棄）")
   - Option 3: "修正して" (label: "修正して（spec.md を修正）")

   Track the number of times the user selects "修正して" (cumulative counter starts at 0).

4. Handle the response:
   - **はい**: Display:
     ```
     仕様書を保存しました。

     ## run_id
     {RUN_ID}

     ## 保存先
     {SPEC_PATH}

     次: /mysk-spec {RUN_ID} で仕様レビューを開始
     ```
   - **いいえ**: Run `rm -f {SPEC_PATH}` via Bash. Then display:
     ```
     仕様書を破棄しました。

     ## run_id
     {RUN_ID}
     ```
   - **修正して**: Use the Edit tool to modify {SPEC_PATH} directly. Increment the "修正して" counter.
     If the counter reaches 3, warn: "修正回数が上限(3回)に達しました。最終確認を行います。" and use AskUserQuestion with only "はい" and "いいえ" options (no "修正して").
     Otherwise, re-display the summary and step 3 with "はい/いいえ/修正して" options again.
     After any "はい" or "いいえ" response, proceed to cleanup.

5. Cleanup (run in ALL cases after user response):
   ```bash
   rm -f {GRACE_FILE}
   cmux send --workspace {WS_REF} --surface {SUB_SURFACE} "/exit" && sleep 1 && cmux send-key --workspace {WS_REF} --surface {SUB_SURFACE} return && sleep 2 && cmux close-surface --workspace {WS_REF} --surface {SUB_SURFACE}
   ```

If status is "failed":
1. FIRST: Find spec-monitor job in CronList and delete it using CronDelete
2. Use Bash to read the error content and display it:
```bash
cat {STATUS_FILE} 2>/dev/null || echo "NOT_FOUND"
```
Display the progress field content.
3. Perform cleanup:
   ```bash
   rm -f {GRACE_FILE}
   cmux send --workspace {WS_REF} --surface {SUB_SURFACE} "/exit" && sleep 1 && cmux send-key --workspace {WS_REF} --surface {SUB_SURFACE} return && sleep 2 && cmux close-surface --workspace {WS_REF} --surface {SUB_SURFACE}
   ```

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

         if [ -f "$GRACE_FILE" ]; then
           CURRENT_COUNT=$(cat "$GRACE_FILE" | grep -o '"count":[0-9]*' | cut -d: -f2)
           CURRENT_COUNT=${CURRENT_COUNT:-0}
         else
           CURRENT_COUNT=0
         fi

         NEW_COUNT=$((CURRENT_COUNT + 1))
         case $NEW_COUNT in
           1) EXTEND_MINUTES=10 ;;
           2) EXTEND_MINUTES=15 ;;
           *) EXTEND_MINUTES=20 ;;
         esac

         GRACE_UNTIL=$(date -u -d "+${EXTEND_MINUTES} minutes" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -v+${EXTEND_MINUTES}M +%Y-%m-%dT%H:%M:%SZ)
         echo "{\"grace_until\":\"$GRACE_UNTIL\",\"count\":$NEW_COUNT}" > "$GRACE_FILE"
         ```
         Then do nothing (監視を継続)
        - "中止" → Delete spec-monitor using CronDelete, then execute cleanup:
          ```bash
          rm -f {GRACE_FILE}
          cmux send --workspace {WS_REF} --surface {SUB_SURFACE} "/exit" && sleep 1 && cmux send-key --workspace {WS_REF} --surface {SUB_SURFACE} return && sleep 2 && cmux close-surface --workspace {WS_REF} --surface {SUB_SURFACE}
          ```
     Else:
       1. Display "サブエージェントが30分以上応答していません。タイムアウトの可能性があります。"
       2. Display "サブペインを確認: cmux focus-surface --workspace {WS_REF} --surface {SUB_SURFACE}"
       3. Use AskUserQuestion with the following options:
        - "待機続行" → Execute bash to set grace with progressive extension:
         ```bash
         GRACE_FILE="{GRACE_FILE}"

         if [ -f "$GRACE_FILE" ]; then
           CURRENT_COUNT=$(cat "$GRACE_FILE" | grep -o '"count":[0-9]*' | cut -d: -f2)
           CURRENT_COUNT=${CURRENT_COUNT:-0}
         else
           CURRENT_COUNT=0
         fi

         NEW_COUNT=$((CURRENT_COUNT + 1))
         case $NEW_COUNT in
           1) EXTEND_MINUTES=10 ;;
           2) EXTEND_MINUTES=15 ;;
           *) EXTEND_MINUTES=20 ;;
         esac

         GRACE_UNTIL=$(date -u -d "+${EXTEND_MINUTES} minutes" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -v+${EXTEND_MINUTES}M +%Y-%m-%dT%H:%M:%SZ)
         echo "{\"grace_until\":\"$GRACE_UNTIL\",\"count\":$NEW_COUNT}" > "$GRACE_FILE"
         ```
         Then do nothing (監視を継続)
        - "中止" → Delete spec-monitor using CronDelete, then execute cleanup:
          ```bash
          rm -f {GRACE_FILE}
          cmux send --workspace {WS_REF} --surface {SUB_SURFACE} "/exit" && sleep 1 && cmux send-key --workspace {WS_REF} --surface {SUB_SURFACE} return && sleep 2 && cmux close-surface --workspace {WS_REF} --surface {SUB_SURFACE}
          ```
   - Otherwise: Do nothing

Note: {SPEC_PATH}, {RUN_ID}, {WS_REF}, and {SUB_SURFACE} are substituted by the command-side render step before this monitor text is used as a CronCreate prompt.
