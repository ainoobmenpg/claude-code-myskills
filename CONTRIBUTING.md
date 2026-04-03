# Contributing to mysk

このガイドでは、**外部貢献者**向けの mysk プロジェクトへの貢献方法を説明します。

メンテナー向けの開発フローについては [CLAUDE.md](CLAUDE.md) の「ブランチ戦略」セクション（main 直コミット）を参照してください。

## バグ報告

バグを見つけた場合は、Issue テンプレートを使用して報告してください。

### バグ報告の手順

1. 既存の Issue を検索して、同じ問題が報告されていないか確認
2. 「Bug Report」テンプレートを選択
3. 以下の情報を記入:
   - **再現手順**: バグを再現できる具体的な手順
   - **期待動作**: 本来あるべき動作
   - **実際の動作**: 実際に発生した動作
   - **環境**: OS、Claude Code のバージョン
   - **スクリーンショット**: 可能であればエラーメッセージやスクリーンショットを添付

## 機能要望

新しい機能や改善の提案がある場合は、Issue を作成してください。

### 機能要望の手順

1. 既存の Issue を検索して、同じ要望がないか確認
2. 「Feature Request」テンプレートを選択
3. 以下の情報を記入:
   - **何をしたいか**: 実現したい機能や改善の内容
   - **なぜ必要か**: その機能が必要な理由、ユースケース
   - **優先度**: 高 / 中 / 低

## プルリクエスト

**外部貢献者向けワークフロー**: コードの変更を提案する場合は、プルリクエスト（PR）を作成してください。

メンテナーの場合は [CLAUDE.md](CLAUDE.md) の「ブランチ戦略」セクションを参照してください（main 直コミット）。

### PR の手順

1. フォーク: リポジトリをフォークする
2. ブランチ作成: `git checkout -b feature/your-feature-name`
3. 変更: コードを変更し、コミットする
4. プッシュ: `git push origin feature/your-feature-name`
5. PR 作成: GitHub でプルリクエストを作成

### PR の記述内容

- **変更内容**: 何を変更したか、なぜ変更したか
- **関連 Issue**: 関連する Issue 番号（例: #1）
- **テスト方法**: 変更内容を検証する手順

## コミットメッセージ規約

コミットメッセージは [Conventional Commits](https://www.conventionalcommits.org/) に従ってください。

```
<type>: <description>
```

### Type

| Type | 用途 |
|------|------|
| `feat` | 新コマンド・テンプレート追加 |
| `fix` | バグ修正 |
| `docs` | ドキュメント更新 |
| `refactor` | リファクタリング（機能変更なし） |
| `chore` | 設定、依存関係の更新 |

### 例

```
feat: mysk-review-verify コマンドを追加
fix: spec-draft のスラッグ生成でハイフン重複を修正
docs: README にテンプレート一覧を追記
```

## ドキュメント更新のルール

コマンドやテンプレートを変更した際は、必ずドキュメントを更新してください。詳細は `CLAUDE.md` の「ドキュメント同期」セクションを参照してください。

| 変更内容 | 確認するドキュメント |
|----------|---------------------|
| コマンドの追加・削除 | `README.md`、`CLAUDE.md` |
| コマンドの引数変更 | `README.md`、`CLAUDE.md`、`mysk-workflow.md` |
| テンプレートの追加・削除 | `README.md`、`CLAUDE.md` |
| ワークフローの変更 | `README.md`、`mysk-workflow.md` |

## ラベル運用

Issue や PR には適切なラベルを付与してください。

### 種別ラベル

| ラベル | 用途 |
|--------|------|
| `bug` | 不具合報告 |
| `enhancement` | 機能追加・改善 |
| `documentation` | ドキュメント修正 |
| `question` | 確認事項・相談 |

### 優先度ラベル

| ラベル | 優先度 | 基準 |
|--------|--------|------|
| `priority: high` | 高 | コマンドが動作しない、データ損失 |
| `priority: medium` | 中 | 通常のバグ・機能要望 |
| `priority: low` | 低 | 改善案、余裕があれば対応 |

## 開発環境のセットアップ

```bash
# 1. リポジトリをクローン
git clone https://github.com/ainoobmenpg/claude-code-myskills.git
cd claude-code-myskills

# 2. 既存ファイルのバックアップ（必要な場合のみ）
# ~/.claude/commands/ に mysk-*.md が既にある場合:
mkdir -p backup
cp ~/.claude/commands/mysk-*.md backup/

# 3. スキルを配置
mkdir -p ~/.claude/commands ~/.claude/templates
cp commands/*.md ~/.claude/commands/
ln -sfn "$(pwd)/templates/mysk" ~/.claude/templates/mysk

# 4. 動作確認
claude --model opus
# Claude Code プロンプト内で /mysk-workflow を実行
```

### スキルの更新

mysk スキルを更新する場合は、以下のフローで行ってください。

#### 基本原則

1. **リポジトリ側で修正**: `commands/` と `templates/mysk/` のファイルを編集
2. **環境に展開**: 修正を `~/.claude/commands/` と `~/.claude/templates/mysk/` に反映
3. **確認**: Claude Code でスキルが正しく動作することを確認

#### インストール方式による展開方法の違い

**シンボリックリンクで導入済みの場合**:
- リポジトリ側の修正が自動反映されるため、再展開は不要です

**コピーで導入した場合**:
- 以下のコマンドで再展開が必要です:

```bash
# 全スキルを一括更新
cp commands/mysk-*.md ~/.claude/commands/
rm -rf ~/.claude/templates/mysk && cp -r templates/mysk ~/.claude/templates/mysk
```

#### コマンド例

```bash
# 1. リポジトリ側で修正（お好みのエディタで）
vim commands/mysk-workflow.md

# 2. シンボリックリンクの場合は何もしなくてOK
#    コピーの場合は以下を実行
cp commands/mysk-*.md ~/.claude/commands/
rm -rf ~/.claude/templates/mysk && cp -r templates/mysk ~/.claude/templates/mysk
```

**注意**: `~/.claude/commands/` 内のファイルを直接編集すると、リポジトリ側との同期が取れなくなります。必ずリポジトリ側で修正してください。

## コードレビュー

すべての PR はコードレビューを経てからマージされます。レビュアーからのフィードバックには迅速に対応してください。

## 行動規範

- 建的なフィードバックを心がけてください
- 他の貢献者を尊重してください
- 不適切な行為が見つかった場合は、メンテナに報告してください
