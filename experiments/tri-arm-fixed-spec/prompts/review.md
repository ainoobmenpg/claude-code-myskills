# レビュー指示

このレビューは完全自動です。ユーザーへの質問は禁止です。

レビュー観点:

- acceptance criteria を満たしているか
- high / medium / low の残存指摘があるか
- 主要な failure type があるなら 1 つ選ぶ
- style 指摘ではなく、正しさ・要件逸脱・回帰リスク・テスト不足を優先する

制約:

- read-only review とし、ファイルは変更しない
- 現在の worktree 差分だけを対象にする

最終出力:

- JSON schema に適合する JSON のみを返す
