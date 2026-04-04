# Issue Draft: fixed-spec 前提の planner / executor / reviewer ワークフローへ再設計する

## 背景

現状の `mysk` ワークフローは、仕様策定から実装までを以下の直線フローで扱っている。

- `/mysk-spec-draft`
- `/mysk-spec-review`
- `/mysk-spec-implement`
- `/mysk-implement-start`

ドキュメント上も、`draft -> review -> implement` の対話型フローとして整理されている。

参照:

- `docs/workflow.md`
- `commands/mysk-spec-draft.md`
- `commands/mysk-spec-review.md`
- `commands/mysk-spec-implement.md`
- `commands/mysk-implement-start.md`
- `templates/mysk/spec-draft-prompt.md`
- `templates/mysk/spec-review-prompt.md`

ただし、最近の benchmark / pilot では、**対話型 spec フローを毎回挟む運用**と、**fixed spec を凍結して下位モデルに渡す運用**で、明確に性質が異なることが見えた。

### 観測 1: 対話型 Opus-assisted フローは小〜中規模タスクで改善を出せなかった

`experiments/ab-20260403-pilot/summary.md` では、比較対象 `task-01/02/03` において以下だった。

- Primary 指標の改善なし
- 比較対象計で elapsed が `1.92x`
- `task-03` では clarification / intervention / requirement misunderstanding が発生

この結果は、**「上位モデルが対話しながら spec を詰める」こと自体は、そのままでは費用対効果が悪い**ことを示している。

### 観測 2: fixed spec artifact を凍結して下位モデルに渡す形は、少なくとも悪化しなかった

`experiments/tri-arm-fixed-spec/` で実施した 3-arm benchmark では、

1. `GLM4.7 direct`
2. `GLM4.7 + fixed spec`
3. `GLM5.1 direct`

を hidden tests 前提で比較した。

直近 run:

- `experiments/tri-arm-fixed-spec/runs/20260404T041949Z-tri-arm/summary.md`

結果:

- `GLM4.7 + fixed spec`: `3/3 all_green`
- `GLM4.7 direct`: `2/3 all_green`
- `GLM5.1 direct`: `2/3 all_green`

特に `guardian-nvme-selftest-01` では、`GLM4.7 direct` が visible pass / hidden fail だったのに対し、`GLM4.7 + fixed spec` は hidden まで通した。

この結果は、**上位モデルを「実装者」ではなく「fixed spec の planner / reviewer」として使う方が期待値が高い**ことを示唆している。

## 問題

### 1. 現行ワークフローは「対話型仕様策定」を default にしている

`mysk-spec-draft` は prompt / template レベルで質問前提になっている。

- 「必要に応じて段階的に質問してください」
- `AskUserQuestion` の使用を明示
- cmux / monitor / cron を使った長い対話フロー

この設計は、曖昧な greenfield 仕様を人間と詰める用途には合うが、**「上位モデルが brief を整理して fixed spec に落とし、下位モデルに実装させる」運用には重すぎる**。

### 2. `impl-plan.md` が default path で強すぎる

現状の default path では、`spec.md` の後に `impl-plan.md` を経由する。

しかし今回の benchmark で有効だったのは、

- short / fixed な spec artifact
- 下位モデルへの直接 handoff

であり、`impl-plan.md` を毎回必須にすると次の問題が出る。

- 仕様 artifact が長くなり、planner のノイズが増える
- executor が repo 実態より plan の細部に引っ張られる
- 4.7 executor の token / reasoning を plan 解釈に使ってしまう

### 3. review が「品質 gate」ではなく「別フロー」になっている

現状でも review 系コマンドは存在するが、フロー上は spec 系と code review 系が別の塊として見える。

一方、欲しい運用は以下である。

1. planner: 上位モデルが fixed spec を作る
2. executor: 下位モデルが fixed spec に従って実装する
3. reviewer: 上位モデルが patch をレビューする
4. gate: high / medium が残る限り executor に戻す

つまり、review はオプションではなく **品質担保の中核** であるべきだが、現状の workflow docs ではその位置づけが弱い。

### 4. 現行ドキュメントと runner の知見が接続されていない

`experiments/tri-arm-fixed-spec/BENCHMARK_V2.md` では、no-op、hidden tests、allowed paths、fixed spec artifact がすでに整理されている。

しかし production workflow 側はまだ以下の前提で動いている。

- 対話型 spec
- impl-plan を中心に実装
- reviewer は secondary

実験から得た知見が default workflow に還元されていない。

## ゴール

- `5.1 planner -> 4.7 executor -> 5.1 reviewer` を default workflow として表現できるようにする
- default path では、質問を増やす対話型 draft ではなく、**fixed spec artifact** を first-class にする
- review を「最後に見るオプション」ではなく、**merge / 完了を止める gate** にする
- 現行の interactive spec フローは legacy / discovery lane として残しつつ、default lane を分ける

## 非ゴール

- 現行の `mysk-spec-draft` を即時削除すること
- あらゆるタスクを non-interactive に統一すること
- 下位モデル executor に repo 探索を一切させないこと
- reviewer を hidden tests の代替にすること

## 提案する設計

### A. ワークフローを 2 lane に分ける

#### 1. default lane: fixed-spec planner / executor / reviewer

これを日常運用の標準にする。

```text
brief
  -> fixed-spec draft (5.1)
  -> fixed-spec review/freeze (5.1)
  -> implementation (4.7)
  -> review gate (5.1)
  -> fix loop (4.7)
  -> verify / done
```

この lane では、上位モデルの責務は以下に固定する。

- brief の整理
- in-scope / out-of-scope / constraints / acceptance の固定
- patch review
- unresolved high / medium の gate 判定

下位モデルの責務は以下に固定する。

- repo 探索
- 実装
- reviewer 指摘の修正

#### 2. discovery lane: 現行 interactive spec フロー

これは以下のようなケースだけに寄せる。

- brief が薄く、要件収集が必要
- 利害関係者の確認が必要
- greenfield 機能で仕様を人間と一緒に詰める必要がある

現行の `/mysk-spec-draft` / `/mysk-spec-review` はこの lane に寄せる。

### B. fixed spec artifact を first-class にする

default lane の主 artifact は `impl-plan.md` ではなく `fixed-spec.md` にする。

run directory 例:

```text
~/.local/share/claude-mysk/{run_id}/
├── brief.md
├── fixed-spec.md
├── fixed-spec-review.json
├── executor-report.json
├── review.json
├── diffcheck.json
├── verify.json
└── status.json
```

`fixed-spec.md` の必須セクション:

- Goal
- In-scope
- Out-of-scope
- Constraints
- Acceptance Criteria
- Edge Cases / Failure Modes
- Allowed Paths / Non-goals
- Test Notes

ポイント:

- fixed spec は短く、解釈余地を減らす
- 実装計画は optional artifact に落とす
- file/line 断定を無理に増やさない

### C. `mysk-spec-implement` を default から外し、optional にする

`impl-plan.md` は完全に削除してもよいが、互換性を考えると **advanced mode** に降格するのが現実的である。

使いどころ:

- 変更ファイルが多い
- migration / refactor で段階実装が必要
- 複数人 / 複数 agent に分担したい

default lane では、

- `fixed-spec.md`
- repo 実態

だけで executor が着手できるようにする。

### D. `mysk-implement-start` を executor 専用コマンドに再定義する

default lane の executor では、`mysk-implement-start` の判断優先順位を次のように変える。

1. ユーザーの明示指示
2. `fixed-spec.md` の scope / constraints / acceptance
3. repo 実態
4. optional な implementation hints (`impl-plan.md` がある場合のみ)

重要なのは、**default lane では fixed spec が plan より強い**こと。

また、executor モードでは以下を強める。

- `max_clarification_questions = 0` を基本にする
- fixed spec がある時は質問せず自己決定する
- repo 探索はするが、scope は fixed spec に縛る
- 変更 path の制約を強く読む

### E. review を gate にする

`mysk-review-check` / `mysk-review-fix` / `mysk-review-diffcheck` / `mysk-review-verify` は残してよいが、default lane では **review gate** として整理し直す。

期待動作:

- reviewer は上位モデル固定
- high / medium が残っていれば完了不可
- executor は review findings を修正する
- diffcheck / verify は gate 補助として残す

理想的には次の見え方にする。

```text
fixed spec freeze
  -> executor run
  -> review gate
      -> pass: done
      -> fail: fix
              -> diffcheck
              -> review gate
```

### F. model routing を workflow に埋め込む

現行 docs には「Opus / Sonnet」とあるが、運用上の本質は model 名ではなく役割である。

default lane の routing:

- planner / reviewer: `5.1`
- executor: `4.7`

例外:

- executor が `blocked`
- no-op を繰り返す
- review gate で同じ high / medium を 2 回以上落とす

この場合だけ上位モデル executor に escalate する。

## 具体的な変更案

### 1. `commands/mysk-spec-draft.md` を split / rename する

選択肢は 2 つある。

#### 案 A: 新コマンド追加

- `/mysk-fixed-spec-draft`
- `/mysk-fixed-spec-review`

既存 `mysk-spec-draft` は discovery lane に据え置く。

#### 案 B: mode 追加

- `/mysk-spec-draft --mode=fixed`
- `/mysk-spec-draft --mode=interactive`

ただし prompt / monitor / status の分岐が増えるため、実装は重い。

現実的には **案 A の方が管理しやすい**。

### 2. fixed-spec 用 prompt / template を追加する

追加候補:

- `templates/mysk/fixed-spec-draft-prompt.md`
- `templates/mysk/fixed-spec-review-prompt.md`
- 必要なら monitor

要件:

- AskUserQuestion を default で禁止
- brief と repo 実態から short spec を作る
- output は `fixed-spec.md`

### 3. `commands/mysk-spec-review.md` を fixed-spec review として再利用または分岐する

review 対象を `spec.md` だけでなく `fixed-spec.md` に対応させる。

fixed-spec review では:

- high / medium を short list で出す
- 可能なら spec 自体への反映を軽くする
- 「長い仕様レビュー」より「executor が迷わない spec にする」ことを優先する

### 4. `commands/mysk-spec-implement.md` を optional advanced path に降格する

変更案:

- description から default 感を外す
- workflow docs では「大規模変更時のみ使う」と明記
- `impl-plan.md` を fixed-spec lane の必須 artifact から外す

### 5. `commands/mysk-implement-start.md` に fixed-spec mode を追加する

必須変更:

- `fixed-spec.md` の読み込み
- `impl-plan.md` なしでも動ける仕様
- fixed spec を source of truth にする判断優先順位
- executor が自己完結で進む前提の wording に変更

### 6. `docs/workflow.md` を dual-lane へ更新する

`mermaid` の全体像を 2 本に分ける。

- default lane: fixed-spec planner / executor / reviewer
- discovery lane: interactive spec

ここで初めて、workflow docs と benchmark で得た知見が一致する。

### 7. `README.md` と `commands/mysk-workflow.md` を同期する

README / workflow 表示コマンドが旧 default を案内しないようにする。

### 8. integration test を更新する

対象:

- `tests/integration/spec-workflow-mock.bats`
- 追加で fixed-spec lane の mock workflow test

最低限見たいこと:

- fixed-spec draft が non-interactive に完走する
- fixed-spec review が artifact を保存する
- implement-start が `fixed-spec.md` だけで動ける
- review gate が unresolved high / medium で止める

## 受け入れ条件

- workflow docs に default lane / discovery lane の 2 本が明記されている
- default lane が `5.1 planner -> 4.7 executor -> 5.1 reviewer` として説明されている
- fixed spec artifact が first-class として定義されている
- `mysk-implement-start` が `fixed-spec.md` を primary input にできる
- `mysk-spec-implement` が default 必須ステップではなく optional advanced step として位置づけ直されている
- review が gate として説明されている
- spec 系 template が non-interactive fixed-spec mode を持つ
- integration test が新しい default lane と整合している

## 実装タスク

### 1. 新しい artifact / 命名を決める

- `fixed-spec.md`
- `fixed-spec-review.json`
- `executor-report.json`

互換性のため、既存 `spec.md` / `spec-review.json` を alias にするかは別途判断する。

### 2. fixed-spec lane の command surface を実装する

候補:

- 新コマンド追加
- 既存 spec command への mode 追加

### 3. implement-start を fixed-spec first にする

- input 解決
- 判断優先順位更新
- plan optional 化
- wording / examples 更新

### 4. review lane を gate として再整理する

- high / medium blocker の明文化
- diffcheck / verify の位置づけ整理

### 5. docs / README / workflow / tests を同期する

## 補足メモ

今回変えたいのは「上位モデルを毎回たくさん使うこと」ではない。

変えたいのは責務分担である。

- 上位モデル: 解釈を固定する
- 下位モデル: 実装する
- 上位モデル: 結果を止める

つまり、default workflow を **conversation-heavy spec generation** から **artifact-heavy guidance + review gating** に寄せることが本質である。
