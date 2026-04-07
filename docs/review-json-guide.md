# review.json の読み方

`review.json` は current diff に対するレビュー結果です。`finding_count: 0` だけ見て「完全に安全」と判断しないことが重要です。

## 先に見る場所

1. `summary.finding_count`
2. `findings`
3. `checked_paths`
4. `checked_hunks`

## `finding_count: 0` と証跡の違い

- `finding_count: 0`: reviewer が重大な指摘を出さなかった、という結果です。
- `checked_paths` / `checked_hunks`: reviewer が実際にどこを見たかの証跡です。

`0 findings` でも、証跡が薄いなら「見逃しの余地があるかもしれない」と考えます。

## `checked_paths` の見方

ここには reviewer が確認したファイルが入ります。Changed Paths と大きくずれていないかを見ます。

## `checked_hunks` の見方

ここには reviewer が確認した差分位置が入ります。少なくとも主要な変更 hunk を含んでいるか見ます。

## 次に verify で何を見るか

review の次は verify です。verify では次を確認します。

- review で出た指摘が直っているか
- spec の acceptance を満たしているか
- scope 外のファイルを触っていないか

つまり、review は「問題発見」、verify は「修正確認と完了判定」です。

## 小さな例

```json
{
  "summary": { "finding_count": 0 },
  "checked_paths": ["commands/mysk-review.md", "tests/unit/benchmark-review-context.bats"],
  "checked_hunks": [
    {"file": "commands/mysk-review.md", "start_line": 170, "end_line": 177}
  ]
}
```

この場合は「少なくとも review 起動文まわりは見たうえで 0 findings」という意味です。次は verify で spec 整合と修正済み確認を見ます。
