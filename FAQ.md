# FAQ / トラブルシューティング

このページでは mysk の使用中によくある問題とその解決方法を説明します。

## cmux 関連

### Q: cmux が未導入です。どうすればよいですか？

**A**: cmux が未導入の場合、別ペイン実行コマンド（`/mysk-spec-draft`、`/mysk-spec-review`、`/mysk-review-check`、`/mysk-review-verify`）は使用できません。メイン実行のコマンド（`/mysk-spec-implement`、`/mysk-implement-start`、`/mysk-review-fix`、`/mysk-review-diffcheck`、`/mysk-workflow`、`/mysk-cleanup`）のみ利用可能です。

cmux のインストール:
```bash
# macOS
brew install cmux

# Linux
# ソースからビルドするか、各ディストリビューションのパッケージマネージャーを使用
```

### Q: `CMUX_SOCKET_PATH` が未設定というエラーが出ます

**A**: 以下のように環境変数を設定してください。

```bash
# macOS
export CMUX_SOCKET_PATH="$HOME/Library/Application Support/cmux/cmux.sock"

# Linux
export CMUX_SOCKET_PATH="$HOME/.config/cmux/cmux.sock"
```

シェルの設定ファイル（`.zshrc`、`.bashrc` など）に追加することを推奨します。

### Q: サブエージェントがタイムアウトしました

**A**: サブエージェントが15分以上応答がない場合、タイムアウトの可能性があります。以下の手順で確認してください。

1. サブペインを確認:
   ```bash
   cmux read-screen --workspace {WS_REF} --surface {SUB_SURFACE}
   ```
2. thinking ブロックを展開して内容を確認
3. 必要に応じて手動で結果ファイルをコピーまたは修正

## ファイル関連

### Q: `review.json` や `spec-draft.md` が見つからないエラーが出ます

**A**: run_id を省略した場合、現在のプロジェクト（`git rev-parse --show-toplevel`）に一致する `project_root` を持つ最新の run_id を自動選択します。手動で確認する場合は、各 run ディレクトリの `run-meta.json` を確認してください。

### Q: `~/.local/share/claude-mysk/` の中身を誤って消しました

**A**: このディレクトリには成果物が保存されます。削除してもコマンド自体には影響しませんが、過去の実行結果が失われます。再度コマンドを実行して新しい run_id を作成してください。

### Q: run_id を忘れました

**A**: run_id の解決ルールは以下の通りです：

1. 引数で run_id が指定されていればそれを使用
2. 省略時は、現在のプロジェクト（`git rev-parse --show-toplevel`）に一致する project_root を持つ最新の run_id を自動選択
3. 該当する run_id がない場合はエラー

手動で確認する場合:
```bash
# 最新の run_id を確認
ls -lt ~/.local/share/claude-mysk/ | head -5
```

## CronCreate 関連

### Q: CronCreate が無効化されている場合の影響は？

**A**: CronCreate ツールが無効化されている場合、進捗監視が自動で行われません。サブエージェントの完了を手動で確認する必要があります。

## その他

### Q: スキルが見つからないエラーが出ます

**A**: スキルファイルが `~/.claude/commands/` に配置されているか確認してください。

```bash
ls ~/.claude/commands/mysk-*.md
```

ファイルがない場合は、リポジトリからコピーしてください。

```bash
cp commands/*.md ~/.claude/commands/
```

### Q: テンプレートが見つからないエラーが出ます

**A**: テンプレートファイルが `~/.claude/templates/mysk/` に配置されているか確認してください。

```bash
ls ~/.claude/templates/mysk/
```

ファイルがない場合は、リポジトリからコピーしてください。

```bash
ln -sfn "$(pwd)/templates/mysk" ~/.claude/templates/mysk
```

### Q: 別ペインが閉じられません

**A**: サブペインを強制的に閉じるには以下のコマンドを使用してください。

```bash
cmux send --workspace {WS_REF} --surface {SUB_SURFACE} "/exit"
sleep 1
cmux send-key --workspace {WS_REF} --surface {SUB_SURFACE} return
sleep 2
cmux close-surface --workspace {WS_REF} --surface {SUB_SURFACE}
```

## それでも解決しない場合

バグ報告や質問は、[GitHub Issues](https://github.com/ainoobmenpg/claude-code-myskills/issues) から作成してください。
