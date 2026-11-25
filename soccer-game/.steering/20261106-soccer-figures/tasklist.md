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

## 手直し（2026-11-06。「もう少しコマっぽく」）
- [x] 台座のテストに書き換え、失敗することを確かめる（台座が無く失敗）
- [x] 台座に立つ駒の形にし、テストを通す（board_figures_test 6件・tactics_board_test 63件）
- [x] スクリーンショット（全体・拡大・グレースケール）で確かめる（縦じまを暗い色にした）
- [x] 仕様書（functional-overview・screen-common）を直す
- [x] 全体のテスト・コミット前レビュー・振り返り・コミット（インデックスの中身だけで 1183 件成功・128 秒。レビューは Critical / High なし、Low 3件）

## 手直し2（2026-11-06。「台座をもっと大きくして、コマっぽく」）
- [x] 2段の厚い台座と胴より広い台座のテストを書き、失敗することを確かめる（上の段が無く失敗）
- [x] 2段の台座と細めの選手にし、テストを通す（board_figures_test 7件・tactics_board_test 63件）
- [x] スクリーンショット（全体・拡大・グレースケール）で確かめる
- [x] 仕様書（functional-overview・screen-common）を直す
- [x] ~~全体のテスト・コミット前レビュー・振り返り・コミット~~（2段の台座の版は、シャビの「全然ダメ」でコミットせずに方向を決め直した）

## 方向の決め直しと 3D の駒（2026-11-06）
- [x] 案を画像で並べて見せる（人型・ポーン・円柱・ミープル／マグネット3案／ポーン5案／3D 3案）
- [x] 案A ポーン型の平面の形とテスト（人の部品が無いこと）
- [x] 3D-1 光沢プラスチックの `PieceSprites` と、`BoardPainter` の置き方・平面への切り替え
- [x] テスト（縦じまのコントラスト・絵の置き方・色分け・輪郭・画面が無いときの切り替え）。縦じまは 0.45 に戻すと落ちることを確かめた
- [x] 実際の画面で、3D の駒・プレビューの半透明をスクリーンショットで確かめる（透明な絵と、正面の継ぎ目を直した）
- [x] 仕様書（functional-overview・glossary・requirements-definition・architecture-overview・screen-design・component-design・screen-common・wireframes.drawio）
- [x] 全体のテスト（インデックスの中身だけで 1200 件成功・160 秒）
- [x] コミット前レビュー・振り返り・コミット（Critical / High なし。Medium 1件と Low 5件を直した）
