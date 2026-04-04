# 実装指示

この実験は完全自動です。ユーザーへの質問は禁止です。

ルール:

- source of truth は `task.json` と `brief.md`
- repo 実態が brief の詳細表現と食い違う場合は、repo 実態を正としつつ task の目的を満たす最小変更で進める
- `allowed_files` の外は変更しない
- 明示されていない追加改善やリファクタはしない
- 完了前に task 専用テストと repo 回帰テストを自分で実行する
- blocked の場合も質問せず、理由を整理して終了する

最終出力:

- JSON schema に適合する JSON のみを返す
