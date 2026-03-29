Read {STATUS_FILE} and check the status field and updated_at.

If the file does not exist yet:
- Do nothing. Do not output any message. Do not run any bash commands.
- Just wait for the next check.

If status is "completed":
1. FIRST: Find spec-draft-monitor job in CronList and delete it using CronDelete. This must happen before any output to prevent duplicate firings.
2. Then read {DRAFT_PATH} and display the following summary in Japanese:
   - Overview
   - Purpose
   - Scope (in-scope and out-of-scope)
   - Acceptance criteria
3. Finally, confirm "この内容で確定しますか？（はい / いいえ / 修正して）"

If status is "failed":
1. Display error content
2. Delete spec-draft-monitor using CronDelete

If status is "waiting_for_user":
1. Display only once (not every check): "サブエージェントが質問を待っています。サブペインで回答してください。"
2. Display: "cmux focus-surface --workspace {WS_REF} --surface {SUB_SURFACE}"
Do nothing else (do not delete job)

If status is "started" or "initialized":
- Do nothing. Do not output any message.

If status is "in_progress" and updated_at is more than 15 minutes ago:
1. Display "サブエージェントが15分以上応答していません。タイムアウトの可能性があります。"
2. Confirm "アクションを選択してください：再開 / 待機続行 / 中止"
3. Delete spec-draft-monitor using CronDelete

If status is "in_progress" with recent updated_at:
- Do nothing. Do not output any message.
