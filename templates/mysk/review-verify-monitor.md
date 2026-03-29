Read {VERIFY_JSON_PATH} and check the status field.

If the file does not exist yet:
- Do nothing. Do not output any message. Do not run any bash commands.
- Just wait for the next check.

## JSON読み取り（フォールバック付き）

サブエージェントがJSON契約に完全準拠しない場合があるため、以下のフォールバックで読み取る:

- **status**: `.status` → ない場合、`findings`または`verifications`配列が存在すれば "completed" とみなす
- **verification_result**: `.verification_result` → ない場合 findingsから推定:
  - 全て fixed/passed → "passed"
  - 一部 not_fixed/open/unresolved → "partially_passed"
  - エラーのみ → "failed"
- **verifications配列**: `.verifications` → ない場合 `.findings` も試す
- **各verification**:
  - original_finding_id: `.original_finding_id` → ない場合 `.id` → ない場合 `.finding_id`
  - status: `.status`（"fixed"/"not_fixed"/"open"/"unresolved" → "open"/"unresolved"は"not_fixed"として扱う）
  - detail/evidence: `.detail` → ない場合 `.evidence` → ない場合 `.description`
- **summary**:
  - verified_count: `.summary.verified_count` → ない場合 verifications.length
  - fixed_count: `.summary.fixed_count` → ない場合 verificationsからstatus=="fixed"を数える
  - remaining_count: `.summary.remaining_count` → ない場合 verified_count - fixed_count
  - high_remaining: `.summary.high_remaining` → ない場合 verificationsからseverity=="high"かつstatus!="fixed"を数える
  - medium_remaining: `.summary.medium_remaining` → ない場合 verificationsからseverity=="medium"かつstatus!="fixed"を数える
  - new_issues_count: `.summary.new_issues_count` → ない場合 0
- **new_findings**: `.new_findings` → ない場合空配列

If status is "completed" (or findings/verifications exist without status):
1. FIRST: Find review-verify-monitor job in CronList and delete it using CronDelete. This must happen before any output to prevent duplicate firings.
2. Read {VERIFY_JSON_PATH} and extract data using fallback rules above
3. Determine verification_result using fallback rules
4. Display result according to termination logic (see below)
5. Cleanup:
   - cmux send --workspace {WS_REF} --surface {SUB_SURFACE} "/exit"
   - cmux send-key --workspace {WS_REF} --surface {SUB_SURFACE} return
   - sleep 2
   - cmux close-surface --workspace {WS_REF} --surface {SUB_SURFACE}

**If no status AND no findings/verifications**:
1. FIRST: Delete review-verify-monitor using CronDelete
2. Display error: "エラー: verify.json に解析可能なデータがありません。"
3. Display verify.json content for debugging
4. Cleanup

If status is "in_progress" and updated_at is more than 15 minutes ago:
1. Display "サブエージェントが15分以上応答していません。タイムアウトの可能性があります。"
2. Display "サブペインを確認: cmux focus-surface --workspace {WS_REF} --surface {SUB_SURFACE}"
3. Confirm "アクションを選択してください：再開 / 待機続行 / 中止"
4. Delete review-verify-monitor using CronDelete

Otherwise (in_progress with recent updated_at):
Do nothing

### Termination Logic (when status is completed)

**Important**: verifyはrun_idごとに1回のみ実行されます。partially_passedでも再検証しないでください。fix → diffcheck → 終了で応答してください。

以下のフローに従って結果を表示し、次のアクションを決定してください。

```
検証完了
       ↓
┌──────────────────────────────────┐
│ verification_result == "passed" ? │
│ → Yes: 【End】                    │
│ → No: continue                   │
└──────────────────────────────────┘
       ↓
┌──────────────────────────────────┐
│ verification_result == "failed" ? │
│ → Yes: error report → 【End】     │
│ → No: continue                   │
└──────────────────────────────────┘
       ↓
┌──────────────────────────────────┐
│ new_findings has high?           │
│ → Yes: /mysk-review-fix → diffcheck → 【End】 │
│ → No: continue                   │
└──────────────────────────────────┘
       ↓
┌──────────────────────────────────┐
│ summary.high_remaining > 0 ?      │
│ → Yes: /mysk-review-fix → diffcheck → 【End】 │
│ → No: continue                   │
└──────────────────────────────────┘
       ↓
┌──────────────────────────────────┐
│ any medium?                      │
│ → Yes: ask user                  │
│ → No: 【End】                    │
└──────────────────────────────────┘
```

### 終了条件と表示メッセージ

| 条件 | verification_result | 次のアクション |
|-----------|---------------------|-------------|
| すべて修正済み、新規問題なし | `passed` | **終了** |
| 検証失敗 | `failed` | エラーレポート → **終了** |
| 新規`high`発見 | `partially_passed` | `/mysk-review-fix` → `/mysk-review-diffcheck` → **終了** |
| 未修正の`high`あり | `partially_passed` | `/mysk-review-fix` → `/mysk-review-diffcheck` → **終了** |
| `high`なし、`medium`あり | `partially_passed` | ユーザーに確認（デフォルト：終了） |
| `high`なし、`medium`なし | `passed` | **終了** |

**When ending**:

```
検証が完了しました。

## run_id
{RUN_ID}

## ステータス
passed

## 結果
- 修正検証: すべて修正済み
- 新規問題: なし

## 保存先
~/.local/share/claude-mysk/{RUN_ID}/verify.json

レビューサイクルが完了しました。
```

**When high exists (continuing)**:

```
検証が完了しました。

## run_id
{RUN_ID}

## ステータス
partially_passed

## 高優先度の問題
- [新規] N001: src/auth/middleware.ts:25 - 型定義なし
- [未修正] F003: src/auth/jwt.ts:10 - nullチェックなし

## 保存先
~/.local/share/claude-mysk/{RUN_ID}/verify.json

次のステップ: /mysk-review-fix {RUN_ID} → /mysk-review-diffcheck {RUN_ID}

注意: verifyはrun_idごとに1回のみ実行されます。以降はfix → diffcheckを使用してください。
```

**When medium only (asking)**:

```
検証が完了しました。

## run_id
{RUN_ID}

## ステータス
partially_passed

## 高優先度
- なし ✓

## 中優先度（2件）
- M001: src/auth/jwt.ts:30 - 変数名が長すぎる
- M002: src/auth/jwt.ts:45 - コメントが不足している

## 保存先
~/.local/share/claude-mysk/{RUN_ID}/verify.json

中優先度の指摘を修正しますか？（はい / いいえ）

注意: 「いいえ」の場合、レビューサイクルは完了とみなされます。
```

**When error**:

```
検証が失敗しました。

## run_id
{RUN_ID}

## エラー内容
{error message}
```
