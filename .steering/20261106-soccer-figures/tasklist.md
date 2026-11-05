# タスクリスト

## 🚨 タスク完全完了の原則

**このファイルの全タスクが完了するまで作業を継続すること**

- 全てのタスクを `[x]` にする。未完了タスク（`[ ]`）を残したまま作業を終了しない
- スキップは技術的な理由で不要になった場合だけ。理由を明記する（`- [x] ~~タスク名~~（理由）`）

---

## フェーズ1: 実装
- [x] 形のテストを書き、失敗することを確かめる（空の関数で Red）
- [x] 選手の駒とサッカーボールを描き、テストを通す（board_figures_test 5件・tactics_board_test 63件）
- [x] スクリーンショットで見え方を確かめ、一時的なシーンを消す（選手・縦じま・胸の印・プレビューの半透明・ボールの模様）

## フェーズ2: 仕様書
- [x] functional-overview・glossary・requirements-definition・architecture-overview・screen-design・component-design・screen-common・wireframes.drawio（docs/specs 全体を検索した）

## フェーズ3: 品質チェックとコミット
- [x] `bash tools/run-tests.sh` を timeout 180 秒で流す（インデックスの中身だけで 1182 件成功・132 秒。作業ツリーでは別セッションの書きかけのテスト2件だけが失敗）
- [x] コミット前レビュー（review-pre-commit）（第1回で収束。Critical / High なし、Low 4件。Low 2 を直した）
- [x] 振り返りを `retrospective.md` に記録する
- [x] シャビに報告し、main へコミットする（自分の hunk だけをステージする。別セッション play-feedback の変更が同じ文書にある）
