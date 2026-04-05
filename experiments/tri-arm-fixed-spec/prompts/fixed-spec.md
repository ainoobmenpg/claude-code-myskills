# 実装指示

この実験は完全自動です。ユーザーへの質問は禁止です。

ルール:

- source of truth は `task.json`、`fixed-spec.md`、`brief.md`
- `fixed-spec.md` は凍結済み仕様として扱い、勝手に広げない
- repo 実態が仕様詳細と食い違う場合は、repo 実態を確認した上で `fixed-spec.md` の意図を満たす最小変更で進める
- `fixed-spec.md` の一般ルールと具体例が衝突する場合は、安全側の一般ルールを優先し、その曖昧さを `notes` に残す
- `fixed-spec.md` の acceptance criteria 同士が衝突する場合は、他の acceptance が要求する変更を打ち消す読み方をしない。その曖昧さを `notes` に残す
- `fixed-spec.md` に `最小確認対象` がある場合は、それを最初の working set とし、必要になるまで repo 全体へ探索を広げない
- `fixed-spec.md` が current behavior や helper の既存挙動を述べている場合は、実際にコードやテストで確認してから変更する
- `fixed-spec.md` の current behavior 記述と repo 実態が食い違う場合、repo 実態を優先し、そのズレを `notes` に残す
- 狭い docs / text-only タスクで `fixed-spec.md` に共通パターンと箇所別の変更後文言が併記されている場合、箇所別の literal な変更後文言を source of truth とし、共通パターンは補助説明として扱う
- sanitize / slug / fallback を実装する場合、空の識別子や不正な path / key / run id を作らない最小 guard を入れる
- `allowed_files` の外は変更しない
- 明示されていない追加改善やリファクタはしない
- 完了前に task 専用テストと repo 回帰テストを自分で実行する
- blocked の場合も質問せず、理由を整理して終了する

最終出力:

- JSON schema に適合する JSON のみを返す
