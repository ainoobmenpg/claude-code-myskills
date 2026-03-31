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
3. Perform cleanup:
   ```bash
   cmux send --workspace {WS_REF} --surface {SUB_SURFACE} "/exit" && sleep 1 && cmux send-key --workspace {WS_REF} --surface {SUB_SURFACE} return && sleep 2 && cmux close-surface --workspace {WS_REF} --surface {SUB_SURFACE}
   ```
4. Display: "次のステップ: /mysk-spec-revise でレビュー指摘を反映するか、終了してください。"

If status is "failed":
1. FIRST: Find spec-review-monitor job in CronList and delete it using CronDelete
2. Read status.json and display the error content in progress field
3. Perform cleanup:
   ```bash
   cmux send --workspace {WS_REF} --surface {SUB_SURFACE} "/exit" && sleep 1 && cmux send-key --workspace {WS_REF} --surface {SUB_SURFACE} return && sleep 2 && cmux close-surface --workspace {WS_REF} --surface {SUB_SURFACE}
   ```

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
