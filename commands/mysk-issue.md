# mysk-issue

spec.md をベースに対話的に GitHub Issue を作成する。

## 目的

- spec.md から GitHub Issue を作成する
- 対話的にタイトル・本文・ラベルを確認する
- GitHub リポジトリに直接 Issue を登録する
- 作成した Issue の情報を run ディレクトリに保存する

## 引数

- `[run_id]` - 省略時は現在の project_root の最新 run

## 実行手順

1. `WORK_DIR=$(git rev-parse --show-toplevel 2>/dev/null || pwd)` を決める
2. 引数がない場合は、`~/.local/share/claude-mysk/` から `project_root` が `WORK_DIR` に一致する最新 run を探す
3. `RUN_DIR="$HOME/.local/share/claude-mysk/$RUN_ID"`
4. `SPEC_PATH="$RUN_DIR/spec.md"`
5. `ISSUE_PATH="$RUN_DIR/issue.json"`

## spec.md からの情報抽出

spec.md を読み込み、以下の情報を抽出して AskUserQuestion で確認する:

- **タイトル**: `## 概要` の内容、または `# {title}` のタイトル
- **本文**: 以下のセクションを含める
  - 概要
  - 目的
  - スコープ（範囲内 / 範囲外）
  - 受け入れ条件
- **ラベル**: `## タスク種別` から推測
  - `docs/text-only` → `documentation`
  - `code` → `enhancement`

## Issue 作成

確認が取れたら、以下を実行:

```bash
cd {WORK_DIR}

gh issue create \
  --title "確認したタイトル" \
  --body "確認した本文" \
  --label "確認したラベル" \
  --json number,url,title,body,labels,state,createdAt \
  > {ISSUE_PATH}
```

## 返却形式

```
Issue を作成しました。

## run_id
{RUN_ID}

## Issue
- 番号: {number}
- URL: {url}
- タイトル: {title}
- ラベル: {labels}

次: /mysk-implement {RUN_ID}
```
