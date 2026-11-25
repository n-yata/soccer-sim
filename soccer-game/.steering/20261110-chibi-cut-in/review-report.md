# コミット前レビューレポート

トランジションのカットイン（`.steering/20261108-transition-cut-in/`）と人形の選手（本作業）をまとめてレビューした。
別セッションの BLOCK_SHOT の変更は対象外。

## 第1回（2026-11-10）
- 対象: 上の2作業のコード・テスト・仕様書の差分（BLOCK_SHOT のファイルと hunk を除く）
- 結果: Critical 0件 / High 0件 / Medium 1件 / Low 5件

## コミット前レビュー結果

対象: トランジションのカットイン（match_controller.gd・presentation_config.gd/.tres・config_repository.gd・goal_cut_in.gd・match_board_panel.gd・phase_banner.gd・match_screen.gd・tutorial_screen.gd・新規 steal_cut_in_art.gd/save_cut_in_art.gd）、人形の選手（goal_player_model.gd・goal_stage_3d.gd・goal_cut_in_art.gd・LICENSES.md・Hair_* の削除）、テスト（config_repository_test・goal_cut_in_test・goal_player_model_test・match_board_panel_test・match_screens_test・phase_banner_test・新規 save/steal_cut_in_art_test）、仕様書の差分（component-design.md はカットイン・PhaseBanner・設定・名前の一覧の部分のみ）。BLOCK_SHOT のファイル・hunk は対象外。ファイルは変更していない。

### Critical（即時対応必須）
- なし

### High（優先対応）
- なし

### Medium（対応推奨）
- [バグ/テスト] トランジションのカットインが使う動き（クリップ）が `animations.res` にあることを確かめるテストが無く、STEAL の後半（Roll・Slide_Exit）は舞台を通して一度も回っていない。`GoalPlayerModel.set_motion` は `ANIMATIONS.get_animation(clip)` を null 確認なしで使うので、名前の誤りや素材からの抜けは全体テストを通り抜け、遊んだときにだけ途中で止まる → 使う動きがライブラリにあることを確かめるテスト、または各 Kind で p を掃いて舞台を通すテストを足す。`set_motion` で anim が null なら push_error して戻すのも可。

### Low / 改善提案
- [バグ] トランジションのカットインを出した印が、チュートリアルの段階をまたいで残る。`_transition_cut_in_shown` は `_on_turn_resolved` でしか戻らず、チュートリアルの `_start_step` → `start_turn` でも戻らない。操作の段階が LOSS/SAVE で終わると、次の段階の最初の `follow` が quiet になり、局面が違っても帯が出ないことがある（screen-08-tutorial.md の「4回出る」と食い違いうる）→ パネルに戻す関数を足して `_start_step` で呼ぶ。試合画面は enter で forget するので該当しない。
- [テスト] チュートリアル画面の quiet の経路にテストが無い（`tutorial_screen.gd` で第2引数を落としても検出されない見込み）。
- [性能] 写実の体の gltf をテクスチャごと読み込んでいる（骨しか使わない）。髪のテクスチャも体の gltf が参照するので APK に残る → 後で骨だけの素材にする。
- [性能] 1回の build で選手1人あたり約35の MeshInstance と輪郭の next_pass を作る（2人で描画約140回）。顔の部品は1つずつ材質を作る。初回にシェーダーのコンパイルで引っかかる可能性 → 必要なら材質の共有・事前のウォームアップ。
- [運用] `finished` を常に `_board.resume_shift` へつないでいるので、トランジションのカットインが開示の途中で終わっても resume が立つ。LOSS/SAVE に待つ拍が無いので今は無害。将来トランジションに待つ拍を足すと、黙って飛ばされる → コメントで残す。

### 問題なし
- セキュリティ: シークレット・API キー・URL のハードコード無し（LICENSES の公開素材の調達元のドメイン名は CC0 の表記）。クラウドのアカウント情報無し。オフライン単体で保護資源無し。外部入力無し（画面の文は固定、Label3D は背番号の int）。push_error は設定のキーと値だけ。新しい設定値は既存の ConfigRepository の経路で範囲外（NaN・INF を含む）を初期値に戻し、fail open しない（0・4.0・-0.1・4.01・NaN・INF をテスト）。依存の追加無し。
- バグ: LOSS/SAVE の主役の側（turn_winner と holder_is_user の対応）を両方向でテスト。sec 0 以下・非有限は play が断り、印は false のまま。印の順序（turn_resolved で戻す → 着地で立てる → turn_started で読む）。start_turn の stop() は印を消さない。古い landed は _reveal == null で無視。quiet でも _last_phase を更新。dribbler_root は CONTACT・TRIP で連続。_span の割る数は 0 でない定数。SAVE はボールを動きの後に手の間へ置く。名前を変えた API の古い呼び出し元は無い。
- 性能: I/O・上限の無いループ無し。舞台は出す間だけ作って消す。
- 運用: 新しい設定は .tres に外出しされ範囲を持つ。範囲外は初期値と push_error。仕様書・部品一覧・名前の一覧・LICENSES を更新。revert で戻せる。

### 未検証
- 圧縮されたバイナリの `animations.res` に Slide_Start・Slide_Exit・Roll・Sprint・Idle・Yes が実際にあるか（読み取りだけのレビューで Godot を動かしていない）。Roll・Slide_Exit は未確認。
- `.drawio` の差分の中身（1行の変更であることだけ確認）。
- 見た目（カメラの画角・構図・人形の見え方）は遊んで確かめる必要がある。

### 総合評価
Critical / High は無く、コミットしてよい。コミット前に、Medium（動きの存在の確認か、各 Kind で p を掃くテスト）を足すことを勧める。

### 対応
- Medium（動きの存在・場面の後半を舞台に通していない）: 直した。`goal_player_model_test` に、場面の関数が使う動きがすべて素材にあることのテストを足した。`goal_cut_in_test` に、3つの場面を時刻 0〜1 で舞台に通し、2人の選手が動くことのテストを足した。奪う場面の `Slide_Exit` の名前をわざと壊すと、このテストが落ちることを確かめた。
- Low（チュートリアルで印が段階をまたいで残る）: 直した。`MatchBoardPanel.forget_transition_cut_in()` を足し、チュートリアルが段階を始めるときに呼ぶ（screen-08-tutorial.md「段階を始める」）。パネルの単体テストを足した。
- Low（チュートリアル画面の quiet の経路のテスト）: 積み残し。画面のテストで操作の段階を LOSS で終える仕込みが要るため。パネルの印と PhaseBanner の quiet はそれぞれ単体テストで固定済み。
- Low（写実の体のテクスチャを読み込む）: 積み残し。骨だけの素材にする作業で減らす（retrospective.md の「次に気をつけること」）。
- Low（部品と材質の数・初回のシェーダーのコンパイル）: 積み残し。遊んで引っかかりが気になれば、材質の共有と事前のウォームアップを考える。
- Low（finished が常に resume する）: 直さない。トランジションには待つ拍が無く、無害。待つ拍を足すときに見直す（コメントは足していない）。
- 直したのは Medium / Low だけなので、再レビューはしない（スキルの規則）。全体テスト 1308 件成功・155 秒。

## レビュー完了（2026-11-10）
- 最終ラウンド: 第1回
- 新たな Critical / High: なし
- 積み残し（Medium / Low）: チュートリアル画面の quiet の経路のテスト（パネルと帯は単体で固定済み）、写実の体のテクスチャの読み込み、部品・材質の数、finished の resume（いまは無害）
