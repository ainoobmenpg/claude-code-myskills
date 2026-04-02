Read {REVIEW_JSON_PATH} and check the status field.

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
2. Read {REVIEW_JSON_PATH} and extract data using fallback rules above
3. Display the following summary in Japanese:
   - run_id (from .run_id or "{RUN_ID}")
   - Target (source.value or .target)
   - Summary (total count, high/medium/low counts, overall risk)
   - Main findings (from high priority, ID, title, file:line, detail, suggested_fix)
   - 保存先パス
   - "次のステップ: 修正計画を作成するには /mysk-review-fix {RUN_ID}"
4. Cleanup:
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

If status is "in_progress" and updated_at is more than 15 minutes ago:
1. Display "サブエージェントが15分以上応答していません。タイムアウトの可能性があります。"
2. Display "サブペインを確認: cmux focus-surface --workspace {WS_REF} --surface {SUB_SURFACE}"
3. Confirm "アクションを選択してください：再開 / 待機続行 / 中止"
4. Delete review-check-monitor using CronDelete
5. Execute cleanup:
   - cmux send --workspace {WS_REF} --surface {SUB_SURFACE} "/exit"
   - cmux send-key --workspace {WS_REF} --surface {SUB_SURFACE} return
   - sleep 2
   - cmux close-surface --workspace {WS_REF} --surface {SUB_SURFACE}

Otherwise (in_progress with recent updated_at):
Do nothing
