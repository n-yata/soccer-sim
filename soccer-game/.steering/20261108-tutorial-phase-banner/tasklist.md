# タスクリスト

## 🚨 タスク完全完了の原則

**このファイルの全タスクが完了するまで作業を継続すること**

- 全てのタスクを `[x]` にする。未完了タスク（`[ ]`）を残したまま作業を終了しない
- スキップは技術的な理由で不要になった場合だけ。理由を明記する（`- [x] ~~タスク名~~（理由）`）

---

## フェーズ1: 実装
- [x] テストを先に書き、Red を確かめる（`follow`・`forget` が無くて落ちる）
- [x] `PhaseBanner.follow`・`forget`、`MatchScreen` の置き換え、`TutorialScreen` への組み込み、`ui/common/` への移動
- [x] チュートリアルの開示で消す処理を外して、テストが落ちることを確かめる（4件落ちた。戻した）
- [x] 実際の画面で撮る（チュートリアル 4／9 の守備の段階で「DEFENSE ／ 守備 ― ゴールを守る」。帯は説明の吹き出しに 1.2 秒かぶる）

## フェーズ2: 仕様書
- [x] screen-03-match・screen-08-tutorial・screen-common §5・screen-design・component-design（docs/specs 全体を古い置き場とチュートリアルでは出さないの記述で検索した。.drawio に該当なし）

## フェーズ3: 品質チェックとコミット
- [x] `bash tools/run-tests.sh` を timeout 180 秒で流す（インデックスの中身だけで 1274 件成功・152 秒）
- [x] コミット前レビュー（review-pre-commit）（第1回で収束。Critical / High なし、Low 3件のうち2件を直し、直した後も全体 1274 件成功・150 秒）
- [x] 振り返りを `retrospective.md` に記録する
- [x] シャビに報告し、main へコミットする
