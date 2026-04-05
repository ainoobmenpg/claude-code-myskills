# Benchmark v2: hidden tests 前提の 3-arm 実験設計

この文書は、`GLM4.7 direct` / `GLM4.7 + spec.md` / `GLM4.7 + fixed spec` / `GLM5.1 direct` のような handoff 差分を壊れにくく比較するための task schema と runner contract を定義する。

## 目的

測りたいものは 3 つだけに絞る。

1. `GLM4.7 direct` でそのまま実装できるか
2. `spec.md` または `fixed spec` が `GLM4.7` の実装品質を改善するか
3. `GLM5.1 direct` が handoff 付き `GLM4.7` より実用的に強いか

## なぜ v2 が必要か

次のような benchmark は壊れやすい。

- no-op でも repo 回帰だけ通る
- model の自己申告 JSON をそのまま採点に使う
- hidden tests がなく、visible tests にだけ overfit できる
- 評価 task 自体が meta すぎる

v2 では、patch の有無と hidden tests を primary にする。

## task パッケージ

各 task は `experiments/tri-arm-fixed-spec/tasks/<task_id>/` 以下に置く。

repo 内に置く visible artifact:

- `task.json`
- `brief.md`
- `spec.md`
- `fixed-spec.md`
- `allowed-paths.txt`
- `public-tests.sh`

repo 外に置く hidden artifact:

- `$MYSK_HIDDEN_TEST_ROOT/<task_id>/hidden-tests.sh`
- 必要なら fixture / secrets / expected outputs

hidden tests は agent から見えてはいけない。runner が実装完了後にのみ実行する。

## 推奨 task 条件

- 過去に人間が直した実 PR / issue を replay できる
- 変更ファイル数は 3 以上
- 既存コード読解が必要
- 仕様漏れで regress しやすい
- visible tests だけでは完全には判定できない
- hidden tests で境界条件、逆入力、負荷寄りケースを落とせる
- slug / sanitize / fallback のような変換系 task なら、全無効入力や collision を hidden tests に入れられる

## task.json schema

最小フィールド:

```json
{
  "benchmark_version": "v2",
  "task_id": "task-foo-01",
  "title": "Implement feature X in repo Y",
  "repo_path": "/absolute/path/to/target-repo",
  "suggested_base_commit": "abc123...",
  "time_budget_minutes": 45,
  "max_clarification_questions": 0,
  "allowed_paths_file": "experiments/tri-arm-fixed-spec/tasks/task-foo-01/allowed-paths.txt",
  "review_paths": [
    "src/foo.py",
    "tests/test_foo.py"
  ],
  "acceptance_criteria": [
    "Feature X works for the documented happy path.",
    "Existing behavior Y is preserved.",
    "The change stays within allowed paths."
  ],
  "public_test_command": "bash experiments/tri-arm-fixed-spec/tasks/task-foo-01/public-tests.sh",
  "task_test_command": "bash experiments/tri-arm-fixed-spec/tasks/task-foo-01/public-tests.sh",
  "repo_test_command_override": "bats tests/unit/ tests/integration/",
  "hidden_test_id": "task-foo-01",
  "no_op_is_failure": true,
  "wrong_files_is_failure": true
}
```

意味:

- `allowed_paths_file`: patch が触ってよい path prefix 一覧
- `repo_path`: benchmark 対象 repo。省略時は harness を置いた repo 自身
- `suggested_base_commit`: `run-experiment.sh auto ...` のときに task ごとに使う base commit
- `public_test_command`: model に見える deterministic test
- `task_test_command`: 既存 runner 互換用
- `repo_test_command_override`: task 単位で repo regression を差し替えたい時だけ使う
- `hidden_test_id`: repo 外 bundle の解決キー
- `no_op_is_failure`: diff が空なら失敗
- `wrong_files_is_failure`: allowed path 外に書いたら失敗

## allowed-paths.txt

1 行 1 path prefix。directory でも file でもよい。

例:

```text
src/parser/
src/runtime/eval.py
tests/test_parser.py
docs/parser-notes.md
```

runner は `git diff --name-only` の全 path がここに含まれるかを検証する。

## public-tests.sh

役割:

- happy path を見る
- task 固有の deterministic 判定をする
- hidden tests ほど細かくしすぎない

要件:

- `set -euo pipefail`
- stdout は短く、fail 時に何が壊れたか分かる
- repo 内だけで完結する
- 環境依存を減らす

public tests が通っても hidden tests で落ちる設計が望ましい。

## hidden-tests.sh

hidden tests の役割は「spec を読んで visible tests にだけ合わせた patch」を落とすこと。

最低限入れるべきもの:

- 境界条件
- 逆入力
- backward compatibility
- 変更対象外への副作用チェック
- no-op を見逃さない assertion
- normalize / slug / sanitize を含む task では、全無効入力で空値にならないか、fallback 後も同じルールが適用されるか、collision が起きないか

実行場所の例:

```bash
$MYSK_HIDDEN_TEST_ROOT/task-foo-01/hidden-tests.sh
```

runner は作業 worktree に対してこの script を実行する。agent prompt には path も内容も渡さない。

## runner contract

各 arm は同じ task 内では同じ `base commit` から fresh worktree / fresh container で走らせる。
複数 task をまとめて回すときは、`run-experiment.sh auto ...` により task ごとの `suggested_base_commit` を使える。

### 前処理

1. `git worktree add` で arm ごとの clean worktree を作る
2. task metadata をコピーする
3. prompt を組み立てる
4. `max_clarification_questions=0` を prompt に明記する

### 実行

1. `claude -p --model <model>` で非対話実行
2. prompt, stdout, stderr, run.json を保存
3. timeout で止まったら `failure_type=timeout`

### 生成後の機械判定

1. `git diff --quiet`
   - diff なしなら `patch_non_empty=0`, `failure_type=no_op`
2. `git diff --name-only`
   - allowed path 外があれば `allowed_paths_only=0`, `failure_type=wrong_files`
3. `public_test_command`
4. `repo_test_command_override` または config の repo test
5. hidden test bundle 実行

### acceptance 判定

`acceptance_met=1` にする条件:

- `patch_non_empty=1`
- `allowed_paths_only=1`
- `public_tests_passed=1`
- `hidden_tests_passed=1`
- `repo_regression_tests_passed=1`

どれか 1 つでも欠けたら `acceptance_met=0`。

## scorecard の primary / secondary

Primary:

- `patch_non_empty`
- `allowed_paths_only`
- `task_specific_tests_passed`
- `hidden_tests_passed`
- `repo_regression_tests_passed`
- `acceptance_met`

Secondary:

- `elapsed_minutes`
- `total_cost_usd`
- `clarification_questions`
- `user_interventions`
- `files_changed_count`
- `lines_changed`
- `review_high_remaining`
- `review_medium_remaining`
- `hidden_fail_review_pass`
- `hidden_pass_review_block`

## reviewer の位置づけ

review は primary ではなく secondary。

理由:

- reviewer も model なので false positive / false negative がある
- hidden tests の方が再現可能
- reviewer は「なぜ失敗したか」を読む用途に向いている

今回の学びとして、reviewer には次の弱点が出やすい。

- spec の一般ルールと具体例の内部矛盾を見逃す
- sanitize / slug の退化ケースを low に寄せすぎる

したがって、これらは reviewer 任せにせず hidden tests と task 設計で先に塞ぐ。

必要なら `MYSK_EXPERIMENT_SKIP_REVIEW=true` で reviewer を完全に外し、objective metrics のみで比較してよい。

ただし reviewer 自体の gate 精度を見たい run では skip しないこと。特に次を併記するとよい。

- hidden tests fail かつ review high/medium = 0
- hidden tests pass かつ review high/medium > 0

## 推奨サンプル数

pilot でも `12〜20 tasks` は欲しい。

内訳の目安:

- bugfix: 4〜6
- feature: 4〜6
- refactor: 2〜4
- integration / migration: 2〜4

できれば各 arm を `2 runs` ずつ回して、timeout / no-op のばらつきも見る。

## 最低限の判定ルール

`GLM4.7 + fixed spec` を常用候補にするには、`GLM4.7 direct` と比べて次のどちらかが必要。

- `acceptance_met` が task 群で明確に改善
- `hidden_tests_passed` が明確に改善し、時間増が許容範囲

改善なしで時間だけ増えるなら不採用。

`GLM5.1 direct` と比べる時も同様で、hidden tests と完走率で見て勝てなければ採用価値は薄い。
