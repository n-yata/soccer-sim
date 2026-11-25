# タスクリスト

## 🚨 タスク完全完了の原則

**このファイルの全タスクが完了するまで作業を継続すること**

- 全てのタスクを `[x]` にする。未完了タスク（`[ ]`）を残したまま作業を終了しない
- スキップは技術的な理由で不要になった場合だけ。理由を明記する（`- [x] ~~タスク名~~（理由）`）

---

## フェーズ1: 試作
- [x] 出す瞬間と長さをシャビに確かめる（2026-11-08。「ボールが奪われた・奪った瞬間」「短く 1.5〜2 秒」）
- [x] 素材の動きを足す（UAL2 の Slide_Start・Slide_Exit。Slide・Hit_Knockback も試したが使わないので外した。使っていなかった Jump・Jump_Start も外した。animations.res は 108KB → 93KB）
- [x] ボールを奪う場面（StealCutInArt）と、シュートを止める場面（SaveCutInArt）を作り、スクリーンショットで見え方を確かめる
  - SAVE の題がキーパーを隠したので、題を上の3分の1にした
  - SAVE のつかむ点は、素材の体のキーパーの手で測った（ボールが手へ跳ばない）

## フェーズ2: つなぎ込みとテスト
- [x] テストを書き、失敗を確かめる（config_repository_test の transition_cut_in_sec・phase_banner_test の quiet・match_screens_test・match_board_panel_test。どれもメンバーが無く構文エラー）
- [x] 設定 `transition_cut_in_sec`・パネルの LOSS・SAVE のカットイン・局面の帯の quiet を作り、テストを通す
- [x] 場面の関数と舞台のテスト（steal_cut_in_art_test・save_cut_in_art_test・goal_cut_in_test）を書いて通す（滑り込む向きが長さ 1 でなく、滑る距離が 0.2% ずれていたのを見つけて直した）
- [x] `bash tools/run-tests.sh` を timeout 180 秒で流す（1299 件成功・158 秒。前回 146 秒から増えた）
- [x] シャビが遊んで判定する（2026-11-10。人形の選手と一緒に「OK」）

## フェーズ3: 仕様書・品質チェック・コミット
- [x] 変異で重要なテストが落ちることを確かめる（狙ったスイートだけ。3つとも落ちた）
- [x] 仕様書を更新する（docs/specs 全体を検索し .drawio も見る。設定の表・FR-24・用語集・画面設計・コンポーネント設計（部品・設定・名前の衝突）・S-03・S-08・画面共通・NFR-02・LICENSES.md）
- [x] コミット前レビュー（review-pre-commit。20261110-chibi-cut-in と一緒に。Critical / High なし）
- [x] 振り返りを retrospective.md に記録する
- [ ] シャビに報告し、main へコミットする（ファイルを名指しでステージする）
