# 実装 handoff 比較: direct vs spec.md vs fixed spec vs stronger direct

重ための実装タスクを、完全非対話で 3-arm 比較するための実験雛形。

既定 config の比較アーム:

1. `GLM4.7 direct`
2. `GLM4.7 + fixed spec`
3. `GLM5.1 direct`

追加 config として `config.spec-handoff.json` も用意している。こちらは次を比較する。

1. `GLM4.7 direct`
2. `GLM4.7 + spec.md`
3. `GLM4.7 + fixed spec`
4. `GLM5.1 direct`

## benchmark v2 方針

今回の反省を踏まえ、次の比較では以下を強く推奨する。

- task は「実運用に近い feature / bugfix / refactor」にする
- `repo_regression_tests_passed` は補助指標に下げる
- primary は `hidden tests` を含む task 専用評価にする
- `git diff --quiet` の no-op は自動失格にする
- hidden tests は repo 外に置き、agent から見えない状態で実行する

詳細な設計は [BENCHMARK_V2.md](./BENCHMARK_V2.md) を参照。

## 目的

`fixed spec` を前置することで、弱い実装モデルの結果が改善するかを、質問なし・同一条件で比較する。

この設計で測れるもの:

- `GLM4.7 direct` vs `GLM4.7 + fixed spec`
  - spec artifact 自体が弱い実装モデルを補えるか
- `GLM4.7 + fixed spec` vs `GLM5.1 direct`
  - 強いモデルの直実装より、弱いモデル + 良い spec の方が有効か

## なぜ interactive spec フローを使わないか

`/mysk-spec-draft` と `/mysk-spec-review` は確認質問が返るため、完全自動比較には向かない。

この実験では `fixed spec` または `spec.md` を事前に 1 本だけ作って凍結し、実行時の変動を消す。

## ディレクトリ構成

```text
experiments/tri-arm-fixed-spec/
+-- config.json
+-- prompts/
+-- schema/
+-- tasks/
|   +-- TEMPLATE/
+-- bin/
+-- runs/
```

## task の作り方

`tasks/TEMPLATE/` をコピーして 1 task ディレクトリを作る。

必須ファイル:

- `task.json`
- `brief.md`
- `spec.md`
- `fixed-spec.md`
- `public-tests.sh`
- `allowed-paths.txt`

互換性のため、`task-test.sh` は `public-tests.sh` の薄い wrapper として残してよい。

### 重ためタスクの推奨条件

- 変更ファイルが 3 以上
- 既存コード読解が必要
- 仕様の見落としで regress しやすい
- task 専用テストと repo 回帰テストの両方で成否が決まる

### task.json の要点

- `max_clarification_questions` は原則 `0`
- 外部 repo を対象にする場合は `repo_path` を task.json に入れる
- `allowed_files` または `allowed_paths_file` は狭く保つ
- `review_paths` は reviewer が重点確認すべきパス
- `task_test_command` / `public_test_command` は deterministic に pass/fail が決まる形にする
- `hidden_test_id` は repo 外の hidden test bundle と 1:1 に対応させる

## 実行方法

前提:

- `claude` CLI が使える
- `jq`, `python3`, `bats` が入っている
- 信頼済み repo で実行する

完全自動で permissions を止めたくない場合:

```bash
export MYSK_EXPERIMENT_SKIP_PERMISSIONS=true
```

hidden tests を使う v2 task では、repo 外 bundle root も渡す:

```bash
export MYSK_HIDDEN_TEST_ROOT=/absolute/path/to/hidden-tests
```

reviewer を切って objective metrics だけで回したい場合:

```bash
export MYSK_EXPERIMENT_SKIP_REVIEW=true
```

モデル名が環境依存なら `config.json` を編集する。

既定 config で実行:

```bash
experiments/tri-arm-fixed-spec/bin/run-experiment.sh <base_commit> [task_id...]
```

`spec.md` handoff を含む 4-arm 比較を回す場合:

```bash
experiments/tri-arm-fixed-spec/bin/run-experiment.sh \
  --config experiments/tri-arm-fixed-spec/config.spec-handoff.json \
  <base_commit> [task_id...]
```

`base_commit` は task ごとの target repo 上で解決される。`repo_path` を持つ task はその repo を対象に実行する。

例:

```bash
experiments/tri-arm-fixed-spec/bin/run-experiment.sh ac4b0aac5a1db126f6ebf6a0e398af1c022f2283 task-heavy-01
```

task を省略すると `TEMPLATE` 以外の全 task を実行する。

## 出力

各実行で `runs/<timestamp>-<experiment-slug>/` を生成する。`experiment-slug` は config の `experiment_id` を filesystem-safe に正規化した値で、空になる場合は `unnamed-experiment` を使う。

主な成果物:

- `scorecard.csv`
- `summary.md`
- `tasks/<task_id>/` の snapshot
- `<task_id>/<arm_id>/prompt.md`
- `<task_id>/<arm_id>/run.json`
- `<task_id>/<arm_id>/review.json`
- `<task_id>/<arm_id>/task-test.log`
- `<task_id>/<arm_id>/repo-test.log`
- `<task_id>/<arm_id>/diff.stat`
- `<task_id>/<arm_id>/diff.patch`

## 評価指標

Primary:

- `task_specific_tests_passed`
- `hidden_tests_passed`
- `patch_non_empty`
- `allowed_paths_only`
- `repo_regression_tests_passed`
- `acceptance_met`
- `review_high_remaining`
- `review_medium_remaining`

Secondary:

- `elapsed_minutes`
- `clarification_questions`
- `user_interventions`
- `files_changed_count`
- `lines_changed`
- `failure_type`
- `hidden_fail_review_pass`
- `hidden_pass_review_block`

推奨 failure type:

- `no_op`
- `wrong_files`
- `public_pass_hidden_fail`
- `repo_regression_fail`
- `requirement_misunderstanding`
- `timeout`
- `tool_error`

review signal の見方:

- `hidden_fail_review_pass`: hidden tests は落ちたのに reviewer が high/medium を 0 にした件数。review の見逃し臭い。
- `hidden_pass_review_block`: hidden tests は通ったのに reviewer が high/medium を残した件数。review の過検知臭い。

review の実用性を上げたい場合は、reviewer に full repo の再探索を期待しすぎないこと。現在の harness は Changed Paths、`diff.stat`、`diff.patch` を prompt に含め、これを primary context にする。

normalization / slug / sanitize 系の task では、hidden tests に少なくとも次を入れる。

- 全無効入力で空識別子にならないか
- fallback 後の値も同じ正規化ルールを通るか
- 具体例と一般ルールの食い違いに引きずられていないか

## 非対話ルール

全 arm 共通で以下を強制する:

- ユーザーへの質問禁止
- 情報不足時は task metadata / brief / fixed spec / repo 実態の順で自己決定
- blocked の場合も質問せず `status=blocked` で終了

## 注意

- reviewer も自動化しているので、最終判断前に重要 task だけ人間レビューを追加してよい
- `MYSK_EXPERIMENT_SKIP_REVIEW=true` の場合、review は実行せず `review.json` に skipped stub を書く
- review gate の精度を見たい run では `MYSK_EXPERIMENT_SKIP_REVIEW` を設定しないこと
- usage/cost の JSON 形式は CLI 実装差分があり得るため、取得できない場合は空欄で残す
- `hidden_tests.sh` は repo に置かないこと。`$MYSK_HIDDEN_TEST_ROOT/<task_id>/hidden-tests.sh` のような repo 外パスで運用する
