# spec-review.json の読み方

`spec-review.json` は、「この spec が repo 実態と整合しているか」を確認した結果です。実装前の gate と考えると読みやすくなります。

## 先に見る場所

1. `summary.finding_count`
2. `findings`
3. `checked_paths`
4. `checked_lines`

## 主な項目

- `summary.finding_count`: 指摘件数です。特に `high` と `medium` を優先します。
- `findings`: 何が問題かの本文です。
- `checked_paths`: reviewer が根拠として見たファイルです。
- `checked_lines`: どの行を根拠にしたかです。

## high / medium / low の読み方

- `high`: spec のまま実装すると大きく壊れる可能性があります。先に直します。
- `medium`: 実装者が取り違えやすい、または仕様不足です。基本的に先に直します。
- `low`: 今すぐ壊れないが、誤解や保守事故につながりうる点です。

## `finding_count: 0` の見方

`0` は「何も見ていない」ではなく、「見たうえで大きな問題がなかった」ことを意味します。そこで `checked_paths` と `checked_lines` を必ず確認します。

見るポイント:

- `spec.md` 自体が `checked_paths` に入っているか
- 根拠にしたコードやテストが `checked_paths` に入っているか
- `checked_lines` が空でないか

## 次にどう動くか

- `high` または `medium` がある: `spec.md` を更新して再 review
- `low` だけ: 内容を読んで明確化価値があるか判断
- `0 findings`: 実装に進んでよい

## 小さな例

```json
{
  "summary": { "finding_count": { "high": 1, "medium": 0, "low": 0 } },
  "checked_paths": ["spec.md", "commands/mysk-review.md"],
  "checked_lines": [{"file": "commands/mysk-review.md", "start_line": 170, "end_line": 180}]
}
```

この場合は、`commands/mysk-review.md` の実装と spec がずれている high が 1 件ある、という読み方です。実装に進まず、先に spec を直します。
