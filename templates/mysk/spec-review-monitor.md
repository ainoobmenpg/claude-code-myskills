**TEST MODE**: {TEST_MODE} が "1" の場合、completed 時の AskUserQuestion をスキップし、自動的に「はい」を選択して反映フローを実行してください。

Read {STATUS_FILE} and check the status field and updated_at.

If the file does not exist yet:
- Do nothing. Do not output any message. Do not run any bash commands.
- Just wait for the next check.

## JSON読み取り（フォールバック付き）

サブエージェントがJSON契約に完全準拠しない場合があるため、以下のフォールバックで読み取る:

- **status**: `.status` → ない場合、`"in_progress"` として扱う（フォールバックしない）
- **findings配列**: `.findings` → ない場合 `.issues` も試す
- **各finding**:
  - `severity`: `.severity`
  - `section`: `.section`
  - `title`: `.title`
  - `detail`: `.detail` → ない場合 `.description`
  - `suggestion`: `.suggestion` → ない場合 `.suggested_fix`
  - `id`: `.id`
- **summary**:
  - `overall_quality`: `.summary.overall_quality` → ない場合 `.summary.overall_risk` から推定
  - `headline`: `.summary.headline`
  - finding_count: `.summary.finding_count` → ない場合 `.summary.total` → ない場合 `findings.length`
- **source**: `.source.value` → ない場合 `.target`

**If the status field does not exist**:
1. FIRST: Find spec-review-monitor job in CronList and delete it using CronDelete
2. Display error: "エラー: {STATUS_FILE} に必須の 'status' フィールドがありません。サブエージェントがプロンプトの指示に従いませんでした。"
3. Display {STATUS_FILE} content for debugging: `cat {STATUS_FILE}`
4. Execute cleanup:
   - cmux send --workspace {WS_REF} --surface {SUB_SURFACE} "/exit"
   - cmux send-key --workspace {WS_REF} --surface {SUB_SURFACE} return
   - sleep 2
   - cmux close-surface --workspace {WS_REF} --surface {SUB_SURFACE}
5. Stop processing

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
   rm -f {GRACE_FILE}
   cmux send --workspace {WS_REF} --surface {SUB_SURFACE} "/exit" && sleep 1 && cmux send-key --workspace {WS_REF} --surface {SUB_SURFACE} return && sleep 2 && cmux close-surface --workspace {WS_REF} --surface {SUB_SURFACE}
   ```

If status is "failed":
1. FIRST: Find spec-review-monitor job in CronList and delete it using CronDelete
2. Read status.json and display the error content in progress field
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
     # Unix timestampに変換（macOS: date -j, Linux: date -d）
     UPDATED_TS=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$UPDATED_AT" +%s 2>/dev/null || date -d "$UPDATED_AT" +%s)
     CURRENT_TS=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$CURRENT_TIME" +%s 2>/dev/null || date -d "$CURRENT_TIME" +%s)
     DIFF_MINUTES=$(( (CURRENT_TS - UPDATED_TS) / 60 ))
     ```
   - If `$DIFF_MINUTES -gt 30`:
     # 猶予チェック（ここから追加）
     GRACE_FILE="{GRACE_FILE}"
     if [ -f "$GRACE_FILE" ]; then
       GRACE_UNTIL=$(cat "$GRACE_FILE" | grep -o '"grace_until":"[^"]*"' | cut -d'"' -f4)
       if [ -n "$GRACE_UNTIL" ]; then
         GRACE_TS=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$GRACE_UNTIL" +%s 2>/dev/null || date -d "$GRACE_UNTIL" +%s)
         CURRENT_TS=$(date -u +%s)
         if [ "$CURRENT_TS" -lt "$GRACE_TS" ]; then
           exit 0
         fi
       fi
     fi
     # 猶予チェックここまで
     1. Display "サブエージェントが30分以上応答していません。タイムアウトの可能性があります。"
     2. Display "サブペインを確認: cmux focus-surface --workspace {WS_REF} --surface {SUB_SURFACE}"
     3. Use AskUserQuestion with the following options:
        - "待機続行" → Execute bash to set grace:
         ```bash
         GRACE_FILE="{GRACE_FILE}"
         CURRENT_TIME=$(date -u +%Y-%m-%dT%H:%M:%SZ)
         GRACE_UNTIL=$(date -u -d "+10 minutes" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -v+10M +%Y-%m-%dT%H:%M:%SZ)
         echo "{\"grace_until\":\"$GRACE_UNTIL\",\"count\":1}" > "$GRACE_FILE"
         ```
         Then do nothing (監視を継続)
        - "中止" → Delete spec-review-monitor using CronDelete, then execute cleanup:
          ```bash
          rm -f {GRACE_FILE}
          cmux send --workspace {WS_REF} --surface {SUB_SURFACE} "/exit" && sleep 1 && cmux send-key --workspace {WS_REF} --surface {SUB_SURFACE} return && sleep 2 && cmux close-surface --workspace {WS_REF} --surface {SUB_SURFACE}
          ```
   - Otherwise: Do nothing

Note: {SPEC_PATH}, {DRAFT_PATH}, {RUN_DIR}, {RUN_ID}, {REVIEW_PATH}, {WS_REF}, and {SUB_SURFACE} are substituted by the command-side sed before this monitor text is used as a CronCreate prompt.
