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
   - 主な指摘 (各findingの id/title/severity/category)
3. Finally, confirm "次のアクションを選択してください：/mysk-spec-revise で修正 / 終了"

If status is "failed":
1. Read status.json and display the error content in progress field
2. Delete spec-review-monitor using CronDelete

If status is "waiting_for_user":
1. Display only once (not every check): "サブエージェントが質問を待っています。サブペインで回答してください。"
2. Display: "cmux focus-surface --workspace {WS_REF} --surface {SUB_SURFACE}"
Do nothing else (do not delete job)

If status is "started" or "initialized":
- Do nothing. Do not output any message.

If status is "in_progress" and updated_at is more than 15 minutes ago:
1. Display "サブエージェントが15分以上応答していません。タイムアウトの可能性があります。"
2. Confirm "アクションを選択してください：再開 / 待機続行 / 中止"
3. Delete spec-review-monitor using CronDelete

If status is "in_progress" with recent updated_at:
- Do nothing. Do not output any message.
