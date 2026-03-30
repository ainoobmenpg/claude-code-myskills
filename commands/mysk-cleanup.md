---
description: 残存する監視ジョブとサブペインを一括クリーンアップ
user-invocable: true
argument-hint: なし
---

# mysk-cleanup

mysk ワークフローで使用する監視ジョブ（monitor）とサブペインを一括クリーンアップする。

## 使用場面

- セッション中断（Ctrl+C）後の残存リソース削除
- Claude Code クラッシュ後の環境リセット
- 監視ジョブの異常終了時の後始末

## 実行フロー

1. CronList ツールで全ジョブ一覧を取得
2. ジョブの prompt 内に以下のキーワードを含むものを mysk 関連と判定:
   - "spec-draft-monitor"
   - "spec-review-monitor"
   - "review-check-monitor"
   - "review-verify-monitor"
3. 該当ジョブが 0 件の場合:
   - "クリーンアップ対象のジョブはありません"と表示して終了
4. 該当ジョブがある場合:
   - ジョブ一覧を表示
   - "N件のジョブを削除しますか？（はい / いいえ）"で確認
   - "いいえ"の場合は処理を中止
   - 各ジョブを CronDelete で削除
   - ジョブの prompt 内の cmux コマンド行から --workspace と --surface オプション値を正規表現で抽出（例: `--workspace\\s+(\\S+)`）
   - 抽出できた場合、該当サブペインに /exit を送信してクローズ
5. 結果サマリーを表示:
   - 削除したジョブ数
   - クローズしたサブペイン数
   - 処理できなかったサブペイン（手動削除が必要なもの）

## エラーハンドリング

クリーンアップ時の cmux コマンドエラーは `|| true` で無視し、最終サマリーに失敗件数を含める。

## 完了後の案内

```
クリーンアップが完了しました。
新しいワークフローを開始するには /mysk-spec-draft または /mysk-review-check を使用してください。
```
