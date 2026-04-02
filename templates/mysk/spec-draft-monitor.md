**TEST MODE**: {TEST_MODE} が "1" の場合、completed 時の AskUserQuestion をスキップし、自動的に「はい」を選択して `cp {DRAFT_PATH} {SPEC_PATH}` を実行し、完了メッセージを表示して cleanup に進んでください。

Read {STATUS_FILE} and check the status field and updated_at.

If the file does not exist yet:
- Do nothing. Do not output any message. Do not run any bash commands.
- Just wait for the next check.

If status is "completed":
1. FIRST: Find spec-draft-monitor job in CronList and delete it using CronDelete. This must happen before any output to prevent duplicate firings.
2. Read {DRAFT_PATH} and display a summary in Japanese:
   - Overview (概要)
   - Purpose (目的)
   - Scope (スコープ: in-scope and out-of-scope)
   - Acceptance criteria (受け入れ条件)
3. Use AskUserQuestion to Japanese with the following options:
   - Option 1: "はい" (label: "はい（spec.md にコピーして確定）")
   - Option 2: "いいえ" (label: "いいえ（破棄）")
   - Option 3: "修正して" (label: "修正して（spec-draft.md を修正）")

   Track the number of times the user selects "修正して" (cumulative counter starts at 0).

4. Handle the response:
   - **はい**: Run `cp {DRAFT_PATH} {SPEC_PATH}` via Bash. Then display:
     ```
     仕様書下書きを確定しました。

     ## run_id
     {RUN_ID}

     ## 保存先
     {SPEC_PATH}

     次: /mysk-spec-review で仕様レビューを実施
     ```

   - **いいえ**: Display:
     ```
     仕様書下書きを破棄しました。

     ## run_id
     {RUN_ID}
     ```

   - **修正して**: Use the Edit tool to modify {DRAFT_PATH} directly. Increment the "修正して" counter.
     If the counter reaches 3, warn: "修正回数が上限(3回)に達しました。最終確認を行います。" and use AskUserQuestion with only "はい" and "いいえ" options (no "修正して").
     Otherwise, re-display the summary and step 3 with "はい/いいえ/修正して" options again.
     After any "はい" or "いいえ" response, proceed to cleanup.

5. Cleanup (run in ALL cases after user response):
   ```bash
   cmux send --workspace {WS_REF} --surface {SUB_SURFACE} "/exit" && sleep 1 && cmux send-key --workspace {WS_REF} --surface {SUB_SURFACE} return && sleep 2 && cmux close-surface --workspace {WS_REF} --surface {SUB_SURFACE}
   ```

If status is "failed":
1. FIRST: Find spec-draft-monitor job in CronList and delete it using CronDelete
2. Read status.json and display the error content in progress field
3. Perform cleanup:
   ```bash
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
     1. Display "サブエージェントが30分以上応答していません。タイムアウトの可能性があります。"
     2. Display "サブペインを確認: cmux focus-surface --workspace {WS_REF} --surface {SUB_SURFACE}"
     3. Use AskUserQuestion with the following options:
        - "待機続行" → Do nothing (監視を継続)
        - "中止" → Delete spec-draft-monitor using CronDelete, then execute cleanup:
          ```bash
          cmux send --workspace {WS_REF} --surface {SUB_SURFACE} "/exit" && sleep 1 && cmux send-key --workspace {WS_REF} --surface {SUB_SURFACE} return && sleep 2 && cmux close-surface --workspace {WS_REF} --surface {SUB_SURFACE}
          ```
   - Otherwise: Do nothing

Note: {DRAFT_PATH}, {SPEC_PATH}, {RUN_ID}, {WS_REF}, and {SUB_SURFACE} are substituted by the command-side sed before this monitor text is used as a CronCreate prompt.

