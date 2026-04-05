# FAQ / トラブルシューティング

## Q: cmux が未導入です。何が使えませんか？

**A**: `cmux` がないと `/mysk-spec` と `/mysk-review` は使えません。`/mysk-implement` と `/mysk-help` は引き続き使えます。`/mysk-reset` は monitor 削除には使えますが、cmux surface のクローズは行えません。

```bash
# macOS
brew install tmux
brew install cmux
```

## Q: `CMUX_SOCKET_PATH` 未設定エラーが出ます

**A**: 次のいずれかを設定してください。

```bash
# macOS
export CMUX_SOCKET_PATH="$HOME/Library/Application Support/cmux/cmux.sock"

# Linux
export CMUX_SOCKET_PATH="$HOME/.config/cmux/cmux.sock"
```

## Q: old command names が `/` 補完にまだ出ます

**A**: 以前の `~/.claude/commands/` に古い `mysk-*.md` が残っています。次で置き換えてください。

```bash
mkdir -p backup
find ~/.claude/commands -maxdepth 1 -type f -name 'mysk-*.md' -exec cp {} backup/ \; 2>/dev/null || true
find ~/.claude/commands -maxdepth 1 -type f -name 'mysk-*.md' -delete
cp commands/*.md ~/.claude/commands/
```

## Q: run_id を忘れました

**A**: `/mysk-implement` と `/mysk-review` は、現在のプロジェクトに一致する `project_root` を持つ最新 run を自動選択します。手動確認するなら次です。

```bash
ls -lt ~/.local/share/claude-mysk/ | head -5
```

## Q: `spec.md` が見つからないと言われます

**A**: まだ仕様策定が完了していません。`/mysk-spec` を実行して `spec.md` を確定させてください。

現行フローは `spec.md` を直接更新します。旧 run に `spec-draft.md` だけが残っている場合は、現行 `/mysk-spec` が `spec.md` へ移行してから続行します。

## Q: `/mysk-help` が 4 コマンドしか案内しません

**A**: `mysk-help` 自体は公開コマンドですが、表示内容は実運用の 4 コマンド (`/mysk-spec`、`/mysk-implement`、`/mysk-review`、`/mysk-reset`) を中心に要約する実装です。

## Q: `/mysk-review` を再実行したらすぐ修正せず、確認を求められました

**A**: 現行フローではそれが正しい挙動です。`/mysk-review` はまず `fix-plan.md` を作って承認を取り、承認後にだけ修正へ進みます。`diffcheck.json` の remaining が 0 になった後も、final verify の前にもう一度確認を取ります。

## Q: `spec-v1.md` のようなファイルが増えました

**A**: `spec-review.json` の指摘を `spec.md` に反映する際、現行 `/mysk-spec` はバックアップとして `spec-vN.md` を作成します。`spec.md` が最新の source of truth で、`spec-vN.md` は戻り先のスナップショットです。

## Q: `review.json` に `project_root` がないと言われます

**A**: その `review.json` は旧形式です。現行フローでは `project_root` が必須です。現在のプロジェクトで `/mysk-review` を再実行して新しい review を作り直してください。

## Q: `verify.json` と `verify-rerun.json` の違いは何ですか？

**A**: 初回 verify は `verify.json`、再実行は `verify-rerun.json` に保存されます。両方ある場合、現行フローは `verify-rerun.json` を最新の真実として扱います。

## Q: monitor やサブペインが残りました

**A**: `/mysk-reset` を実行してください。強制的に確認を飛ばしたい場合は `--force` を使えます。

## Q: `~/.local/share/claude-mysk/` を消してしまいました

**A**: コマンド自体には影響しませんが、過去の run 成果物は失われます。必要なら `/mysk-spec` から新しい run を作り直してください。

## Q: テンプレートが見つからないエラーが出ます

**A**: `~/.claude/templates/mysk/` が配置されているか確認してください。

```bash
ls ~/.claude/templates/mysk/
rm -rf ~/.claude/templates/mysk && ln -sfn "$(pwd)/templates/mysk" ~/.claude/templates/mysk
```

## Q: それでも解決しません

**A**: [GitHub Issues](https://github.com/ainoobmenpg/claude-code-myskills/issues) に状況を添えて報告してください。
