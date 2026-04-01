**TEST MODE**: {TEST_MODE} が "1" の場合、partially_passed 時の AskUserQuestion をスキップし、自動的に「いいえ」（レビューサイクル完了）を選択して完了メッセージを表示し cleanup に進んでください。

Read {VERIFY_JSON_PATH} and check the status field.

If the file does not exist yet:
- Do nothing. Do not output any message. Do not run any bash commands.
- Just wait for the next check.

## JSON読み取り（フォールバック付き）

サブエージェントがJSON契約に完全準拠しない場合があるため、以下のフォールバックで読み取る:

- **status**: `.status` → ない場合、`"in_progress"` として扱う（フォールバックしない）
- **verification_result**: `.verification_result` → ない場合以下の順序で推定（schemaと同じ優先順位）:
  1. high_remaining > 0 または new_findingsにseverity=="high"が存在 → "failed"
  2. medium_remaining > 0 または low_remaining > 0 または new_findingsにseverity=="medium"/"low"が存在 → "partially_passed"
  3. 全て fixed/passed → "passed"
  4. エラーのみ → "failed"
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
  - low_remaining: `.summary.low_remaining` → ない場合 verificationsからseverity=="low"かつstatus!="fixed"を数える
  - new_issues_count: `.summary.new_issues_count` → ない場合 0
- **new_findings**: `.new_findings` → ない場合空配列

If status is "completed":
1. FIRST: Find review-verify-monitor job in CronList and delete it using CronDelete. This must happen before any output to prevent duplicate firings.
2. Read {VERIFY_JSON_PATH} and extract data using fallback rules above
3. Determine verification_result using fallback rules
4. Execute termination logic (see below). Each path includes cleanup at the end.

**If the status field does not exist**:
1. FIRST: Delete review-verify-monitor using CronDelete
2. Display error: "エラー: {VERIFY_JSON_PATH} に必須の 'status' フィールドがありません。サブエージェントがプロンプトの指示に従いませんでした。"
3. Display file content for debugging: `cat {VERIFY_JSON_PATH}`
4. Execute cleanup:
   - cmux send --workspace {WS_REF} --surface {SUB_SURFACE} "/exit"
   - cmux send-key --workspace {WS_REF} --surface {SUB_SURFACE} return
   - sleep 2
   - cmux close-surface --workspace {WS_REF} --surface {SUB_SURFACE}

If status is "failed":
1. FIRST: Find review-verify-monitor job in CronList and delete it using CronDelete
2. Read {VERIFY_JSON_PATH} and display the error content in progress field
3. Perform cleanup:
   ```bash
   cmux send --workspace {WS_REF} --surface {SUB_SURFACE} "/exit" && sleep 1 && cmux send-key --workspace {WS_REF} --surface {SUB_SURFACE} return && sleep 2 && cmux close-surface --workspace {WS_REF} --surface {SUB_SURFACE}
   ```

If status is "in_progress" and updated_at is more than 15 minutes ago:
1. Display "サブエージェントが15分以上応答していません。タイムアウトの可能性があります。"
2. Display "サブペインを確認: cmux focus-surface --workspace {WS_REF} --surface {SUB_SURFACE}"
3. Confirm "アクションを選択してください：再開 / 待機続行 / 中止"
4. Delete review-verify-monitor using CronDelete

Otherwise (in_progress with recent updated_at):
Do nothing

### verify状態機械schemaの参照

終了判定ロジックは、以下のschemaの定義に従ってください:
```bash
cat ~/.claude/templates/mysk/verify-schema.json
```

**重要**: `verification_result` の判定は、schemaの `definitions.result_criteria` に従ってください。

### Termination Logic (when status is completed)

**Important**: verifyの再実行ポリシーに従ってください。初回はverify.json、再実行時はverify-rerun.jsonに保存されます。partially_passedの場合はfix → diffcheck → verify再実行で応答してください。verify-rerun.jsonが存在する場合はそちらを最新の真実として扱います。

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
│ → Yes: error report → 【End】    │
│ → No: continue                   │
└──────────────────────────────────┘
       ↓
┌──────────────────────────────────┐
│ summary.high_remaining > 0 ?      │
│ → Yes: error report → 【End】    │
│ → No: continue                   │
└──────────────────────────────────┘
       ↓
┌──────────────────────────────────┐
│ any non-high (medium/low)?       │
│ → Yes: ask user                  │
│ → No: 【End】                    │
└──────────────────────────────────┘
```

### 終了条件と表示メッセージ

| 条件 | verification_result | 次のアクション |
|-----------|---------------------|-------------|
| すべて修正済み、新規問題なし | `passed` | **終了** |
| 検証失敗 | `failed` | エラーレポート → **終了** |
| 新規`high`発見 | `failed` | エラーレポート → **終了** |
| 未修正の`high`あり | `failed` | エラーレポート → **終了** |
| `high`なし、non-high（medium/low）あり | `partially_passed` | ユーザーに確認（デフォルト：終了） |
| `high`なし、未解決なし | `passed` | **終了** |

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
{VERIFY_JSON_PATH}

レビューサイクルが完了しました。
```

Then perform cleanup:
```bash
cmux send --workspace {WS_REF} --surface {SUB_SURFACE} "/exit" && sleep 1 && cmux send-key --workspace {WS_REF} --surface {SUB_SURFACE} return && sleep 2 && cmux close-surface --workspace {WS_REF} --surface {SUB_SURFACE}
```

**When high exists (failed)**:

```
検証が完了しました。

## run_id
{RUN_ID}

## ステータス
failed

## 高優先度の問題
- [新規] N001: src/auth/middleware.ts:25 - 型定義なし
- [未修正] F003: src/auth/jwt.ts:10 - nullチェックなし

## 保存先
{VERIFY_JSON_PATH}

高優先度の未解決問題があるため、レビューサイクルを終了します。
```

Then perform cleanup:
```bash
cmux send --workspace {WS_REF} --surface {SUB_SURFACE} "/exit" && sleep 1 && cmux send-key --workspace {WS_REF} --surface {SUB_SURFACE} return && sleep 2 && cmux close-surface --workspace {WS_REF} --surface {SUB_SURFACE}
```

**When non-high (medium/low) only (asking)**:

```
検証が完了しました。

## run_id
{RUN_ID}

## ステータス
partially_passed

## 高優先度
- なし ✓

## 中優先度・低優先度（2件）
- M001: src/auth/jwt.ts:30 - 変数名が長すぎる
- M002: src/auth/jwt.ts:45 - コメントが不足している

## 保存先
{VERIFY_JSON_PATH}
```

Then use AskUserQuestion with the following options:
- Option 1: "はい" (label: "はい（/mysk-review-fix で修正）")
- Option 2: "いいえ" (label: "いいえ（レビューサイクル完了）")

Handle the response:
- **はい**: Display "次のステップ: /mysk-review-fix {RUN_ID} → /mysk-review-diffcheck {RUN_ID} → /mysk-review-verify {RUN_ID}" then perform cleanup
- **いいえ**: Display "レビューサイクルが完了しました。" then perform cleanup

Cleanup (in both cases):
```bash
cmux send --workspace {WS_REF} --surface {SUB_SURFACE} "/exit" && sleep 1 && cmux send-key --workspace {WS_REF} --surface {SUB_SURFACE} return && sleep 2 && cmux close-surface --workspace {WS_REF} --surface {SUB_SURFACE}
```

**When error**:

```
検証が失敗しました。

## run_id
{RUN_ID}

## エラー内容
{error message}
```

Then perform cleanup:
```bash
cmux send --workspace {WS_REF} --surface {SUB_SURFACE} "/exit" && sleep 1 && cmux send-key --workspace {WS_REF} --surface {SUB_SURFACE} return && sleep 2 && cmux close-surface --workspace {WS_REF} --surface {SUB_SURFACE}
```
