# verify.json の読み方

`verify.json` は final gate です。`verification_result: passed` だけを見るのではなく、acceptance ごとの証跡まで確認します。

## 先に見る場所

1. `verification_result`
2. `acceptance_verifications`
3. `out_of_scope_files`
4. `new_findings`

## 主な項目

- `verification_result`: `passed` か `failed` かです。
- `acceptance_verifications`: spec の受け入れ条件ごとの確認結果です。
- `out_of_scope_files`: spec の許可範囲外で触ったファイルです。
- `new_findings`: verify 時点で見つかった新しい問題です。

## `passed` でも見るべき場所

`passed` でも、次は必ず見ます。

- 各 acceptance に `status` が入っているか
- `evidence_path` が具体的か
- `evidence_text` または `evidence_line` があるか

これで「なぜ passed と判断したか」を追えます。

## 安心材料と不足点の区別

安心材料:

- `verification_result: passed`
- `acceptance_verifications` が空でない
- `out_of_scope_files` が空

不足点:

- evidence がファイル名だけで粗い
- acceptance ごとの記録が少ない
- `passed` でも確認範囲が読み取りづらい

## 小さな例

```json
{
  "verification_result": "passed",
  "acceptance_verifications": [
    {
      "acceptance_id": "A1",
      "status": "met",
      "evidence_path": ["commands/mysk-review.md"],
      "evidence_text": "Do not stop after the Read tool output."
    }
  ],
  "out_of_scope_files": []
}
```

この場合は、A1 を `commands/mysk-review.md` の文言で確認して passed にした、と読みます。
