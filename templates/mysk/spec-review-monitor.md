**TEST MODE**: {TEST_MODE} が "1" の場合、completed 時の AskUserQuestion をスキップし、自動的に「はい」を選択して反映フローを実行してください。

Read {STATUS_FILE} and check the status field and updated_at.

If the file does not exist yet:
- Do nothing. Do not output any message. Do not run any bash commands.
- Just wait for the next check.

If status is "completed":
1. FIRST: Find spec-review-monitor job in CronList and delete it using CronDelete. This must happen before any output to prevent duplicate firings.
2. Then read {REVIEW_PATH} and display the following summary in Japanese:
   - 全体品質 (overall_quality)
   - 評価 headline
   - 指摘数 (finding_count: high/medium/low)
   - 主な指摘 (各findingの id/title/severity/section)
3. Use AskUserQuestion to Japanese with the following options:
   - Option 1: "はい" (label: "はい（spec.md に反映）")
   - Option 2: "いいえ" (label: "いいえ（反映せず終了）")
4. Handle the response:
   - **はい**:
     a. Check if {SPEC_PATH} exists. If not, use {DRAFT_PATH} as the source.
     b. Create backup: Determine N as the maximum existing spec-v*.md version + 1 (or 1 if none exist), then run `cp {SPEC_PATH} {RUN_DIR}/spec-v{N}.md`
     c. Read {REVIEW_PATH} and extract findings array (fallback: try `.findings` first, then `.issues`)
     d. For each finding, read corresponding sections from {SPEC_PATH} and apply Edit tool to update spec.md with minimal diff updates
     e. Append revision history to the end of {SPEC_PATH} (reverse chronological table format)
     f. Display:
       ```
       仕様書を反映しました。

       ## run_id
       {RUN_ID}

       ## 保存先
       {SPEC_PATH}

       ## バックアップ
       {RUN_DIR}/spec-v{N}.md

       次: /mysk-spec-implement で実装計画を作成
       ```
   - **いいえ**: Perform cleanup only (no updates to spec.md)
5. Perform cleanup in ALL cases:
   ```bash
   cmux send --workspace {WS_REF} --surface {SUB_SURFACE} "/exit" && sleep 1 && cmux send-key --workspace {WS_REF} --surface {SUB_SURFACE} return && sleep 2 && cmux close-surface --workspace {WS_REF} --surface {SUB_SURFACE}
   ```

If status is "failed":
1. FIRST: Find spec-review-monitor job in CronList and delete it using CronDelete
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
1. Check if updated_at is more than 15 minutes ago:
   - Get current time: `date -u +%Y-%m-%dT%H:%M:%SZ`
   - Parse updated_at and calculate difference using bash:
     ```bash
     UPDATED_AT="{updated_atの値}"
     CURRENT_TIME=$(date -u +%Y-%m-%dT%H:%M:%SZ)
     # Unix timestampに変換（macOS: date -j, Linux: date -d）
     UPDATED_TS=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$UPDATED_AT" +%s 2>/dev/null || date -d "$UPDATED_AT" +%s)
     CURRENT_TS=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$CURRENT_TIME" +%s 2>/dev/null || date -d "$CURRENT_TIME" +%s)
     DIFF_MINUTES=$(( (CURRENT_TS - UPDATED_TS) / 60 ))
     ```
   - If `$DIFF_MINUTES -gt 15`:
     1. Display "サブエージェントが15分以上応答していません。タイムアウトの可能性があります。"
     2. Confirm "アクションを選択してください：再開 / 待機続行 / 中止"
     3. Delete spec-review-monitor using CronDelete
   - Otherwise: Do nothing

Note: {SPEC_PATH}, {DRAFT_PATH}, {RUN_DIR}, {RUN_ID}, {REVIEW_PATH}, {WS_REF}, and {SUB_SURFACE} are substituted by the command-side sed before this monitor text is used as a CronCreate prompt.
