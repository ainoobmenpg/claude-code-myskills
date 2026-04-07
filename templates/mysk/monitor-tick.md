Monitor tick: {MONITOR_TYPE} ({RUN_ID})

Use Bash to read: cat {STATUS_FILE} 2>/dev/null || echo "NOT_FOUND"

- NOT_FOUND: Read {INSTRUCTIONS_FILE}, follow NOT_FOUND handler.
- status field missing: Read {INSTRUCTIONS_FILE}, follow error handler.
- "in_progress": run python3 -c "import json,datetime,sys; d=json.load(open(sys.argv[1])); t=datetime.datetime.fromisoformat(d['updated_at'].replace('Z','+00:00')); print('RECENT' if (datetime.datetime.now(datetime.timezone.utc)-t).total_seconds()<1800 else 'STALE')" {STATUS_FILE}
  - RECENT: produce no output, do nothing.
  - STALE or error: Read {INSTRUCTIONS_FILE}, follow timeout handler.
- "completed"/"failed"/"waiting_for_user": Read {INSTRUCTIONS_FILE}, follow handler for this status.
