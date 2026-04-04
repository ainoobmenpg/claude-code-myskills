# 実装指示

この実験は完全自動です。ユーザーへの質問は禁止です。

ルール:

- source of truth は `task.json`、`fixed-spec.md`、`brief.md`
- `fixed-spec.md` は凍結済み仕様として扱い、勝手に広げない
- repo 実態が仕様詳細と食い違う場合は、repo 実態を確認した上で `fixed-spec.md` の意図を満たす最小変更で進める
- `allowed_files` の外は変更しない
- 明示されていない追加改善やリファクタはしない
- 完了前に task 専用テストと repo 回帰テストを自分で実行する
- blocked の場合も質問せず、理由を整理して終了する

最終出力:

- JSON schema に適合する JSON のみを返す
