# タスクリスト

## 🚨 タスク完全完了の原則

**このファイルの全タスクが完了するまで作業を継続すること**

- 全てのタスクを `[x]` にする。未完了タスク（`[ ]`）を残したまま作業を終了しない
- スキップは技術的な理由で不要になった場合だけ。理由を明記する（`- [x] ~~タスク名~~（理由）`）
- タスクが大きすぎる場合は、サブタスクに分割して1つずつ完了させる

---

## フェーズ1: 調整値

- [x] `tests/data/config_repository_test.gd` を書き、失敗することを確かめる
- [x] `ConfigRepository` と `game/config/*.tres` を作り、テストを通す（346件）

## フェーズ2: 画面に渡す値と視点の変換

- [x] `tests/application/view_converter_test.gd` を書き、失敗することを確かめる
- [x] `BoardSnapshot`・`RevealView`・`ViewConverter` を作り、テストを通す（358件）

## フェーズ3: 相手と MatchController

- [x] `OpponentPolicy`・`CpuOpponent` を作る
- [x] `tests/application/match_controller_test.gd` を書き、失敗することを確かめる
- [x] `MatchController` を作り、テストを通す（371件。最初は `[] if ... else ...` の型なしの配列を `Array[Movement]` に入れて全テストが落ちた。分けて直した。自分のテストの1本が条件付きで空振りしうる形だったので、無条件に確かめる形に直した）
- [x] `App` に組み込み、`app_test.gd` を足す（372件。試合を最後まで進めて、結果の画面を App 経由で頼むことまで確かめた）
- [x] 変異で、重要なテストが落ちることを確かめる（15個すべて、狙ったテストで検出: 視点の変換5つ、運ぶ先を持たない手、利用者の手の変換・確かめ、画面の要求2つ、キックオフ側、CPU の手の確かめ、調整値の範囲3つ）

## フェーズ4: 文書の更新

- [x] `component-design.md` §3.1〜3.3・§3.5・§4.2、`repository-structure.md` の game/config/・application/

## フェーズ5: 品質チェックとコミット

- [x] `tools/run-tests.sh` が成功する（372件）
- [x] 実装レビュー（review-implementation）を行い、指摘を直す（規約は全文を渡す。4.4/5・必須の指摘なし。推奨5件を直した: 得点後の S-04 の要求・選び直し後の state_changed・CPU の陣形と方式の選び直しのテスト、試合前の問い合わせのガード、start_match の注記、利用者が攻撃側の開示のテスト、CPU の手の置き換えの期待値を手で導いた値に。提案から時刻を1回だけ読む・current_layouts を使う・ドキュメントコメントも入れた。374件）
- [x] コミット前レビュー（review-pre-commit）を行い、新たな Critical / High が無くなるまで直す（第1回で Critical / High 0。Medium 2件・Low 1件をテストを先に書いて直した。変異7個すべて検出。376件）
- [x] 振り返りを `retrospective.md` に記録する
- [x] シャビに報告し、main へコミットする（ファイルを名指しでステージする）
