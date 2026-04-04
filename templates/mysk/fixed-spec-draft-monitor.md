**TEST MODE**: {TEST_MODE} が "1" の場合、completed 時の AskUserQuestion をスキップし、自動的に「はい」を選択して `cp {DRAFT_PATH} {FIXED_SPEC_PATH}` を実行し、完了メッセージを表示して cleanup に進んでください。

Use Bash to read the status file and check the status field and updated_at:
```bash
cat {STATUS_FILE} 2>/dev/null || echo "NOT_FOUND"
```
Parse the JSON output to extract status and updated_at fields.

If the file does not exist yet:
- Do nothing. Do not output any message. Do not run any bash commands.
- Just wait for the next check.

**If the status field does not exist**:
1. FIRST: Find fixed-spec-draft-monitor job in CronList and delete it using CronDelete
2. Display error: "エラー: {STATUS_FILE} に必須の 'status' フィールドがありません。サブエージェントがプロンプトの指示に従いませんでした。"
3. Display file content for debugging: `cat {STATUS_FILE}`
4. Execute cleanup:
   - cmux send --workspace {WS_REF} --surface {SUB_SURFACE} "/exit"
   - cmux send-key --workspace {WS_REF} --surface {SUB_SURFACE} return
   - sleep 2
   - cmux close-surface --workspace {WS_REF} --surface {SUB_SURFACE}
5. Stop processing

If status is "completed":
1. FIRST: Find fixed-spec-draft-monitor job in CronList and delete it using CronDelete. This must happen before any output to prevent duplicate firings.
2. Use Bash to read the draft and display a summary in Japanese:
```bash
cat {DRAFT_PATH} 2>/dev/null || echo "NOT_FOUND"
```
Display:
   - Goal
   - In-scope
   - Constraints
   - Acceptance Criteria
   - Allowed Paths / Non-goals
3. Use AskUserQuestion to Japanese with the following options:
   - Option 1: "はい" (label: "はい（fixed-spec.md にコピーして確定）")
   - Option 2: "いいえ" (label: "いいえ（破棄）")
   - Option 3: "修正して" (label: "修正して（fixed-spec-draft.md を修正）")
4. Handle the response:
   - **はい**: Run `cp {DRAFT_PATH} {FIXED_SPEC_PATH}` via Bash. Then display:
     ```
     fixed-spec 下書きを確定しました。

     ## run_id
     {RUN_ID}

     ## 保存先
     {FIXED_SPEC_PATH}

     次: /mysk-fixed-spec-review で fixed-spec をレビュー
     ```
   - **いいえ**: Display:
     ```
     fixed-spec 下書きを破棄しました。

     ## run_id
     {RUN_ID}
     ```
   - **修正して**: Use the Edit tool to modify {DRAFT_PATH} directly, then re-display summary and ask again.
5. Cleanup (run in ALL cases after user response):
   ```bash
   rm -f {GRACE_FILE}
   cmux send --workspace {WS_REF} --surface {SUB_SURFACE} "/exit" && sleep 1 && cmux send-key --workspace {WS_REF} --surface {SUB_SURFACE} return && sleep 2 && cmux close-surface --workspace {WS_REF} --surface {SUB_SURFACE}
   ```

If status is "failed":
1. FIRST: Find fixed-spec-draft-monitor job in CronList and delete it using CronDelete
2. Use Bash to read the error content and display it:
```bash
cat {STATUS_FILE} 2>/dev/null || echo "NOT_FOUND"
```
3. Perform cleanup:
   ```bash
   rm -f {GRACE_FILE}
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
     1. Display "planner が30分以上応答していません。サブペインを確認してください。"
     2. Display "cmux focus-surface --workspace {WS_REF} --surface {SUB_SURFACE}"
   - Otherwise: Do nothing

Note: {DRAFT_PATH}, {FIXED_SPEC_PATH}, {RUN_ID}, {WS_REF}, and {SUB_SURFACE} are substituted by the command-side sed before this monitor text is used as a CronCreate prompt.
