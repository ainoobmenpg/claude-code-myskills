# 長時間待ちのときに見る artifact の順番

Opus が長く考えている間は、見る順番を固定すると不安が減ります。

## まず見る順番

1. `status.json`
2. `spec-review.json` または `review.json` / `verify.json`
3. `*-launch-debug.log`
4. `timeout-grace.json`

## stage ごとの見方

- spec:
  `status.json` の `status` / `updated_at` / `progress`
- spec-review:
  `status.json` と `spec-review.json` の `phase` / `updated_at`
- review:
  `review.json` の `status` / `phase` / `progress`
- verify:
  `verify.json` または `verify-rerun.json` の `status` / `phase` / `progress`

## 止まって見えるときの確認手順

1. `updated_at` が動いているか見る
2. `phase` が `loading` から進んでいるか見る
3. 初期 artifact が作られているか見る
4. `*-launch-debug.log` に起動直後エラーがないか見る
5. timeout 待機中なら `timeout-grace.json` を見る

## よくある見え方

- `status=in_progress` で `updated_at` が更新される:
  進行中です。
- `status=in_progress` だが `updated_at` が長時間止まる:
  thinking 中か、起動直後で止まっている可能性があります。
- `status=waiting_for_user`:
  次はユーザー入力待ちです。
- `status=completed`:
  次のフェーズへ進めます。
- `status=failed`:
  まずエラー本文を見ます。

## 実務メモ

長く止まって見えるときでも、いきなりリセットせず、まず `phase`、`updated_at`、初期 artifact の有無を確認してください。review なら `review.json` がまだ無いのか、あるが進まないのかで原因が違います。
