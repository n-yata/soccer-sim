# コミット前レビューレポート

## 第1回（2026-11-27）
- 対象: feature/remove-cut-ins の `git diff HEAD`（コード14ファイル・設計書12ファイル・`LICENSES.md`・`export_presets.cfg.example`・
  ステージ済みの削除）と `soccer-game/.steering/20261127-remove-cut-ins/` の3文書。`*.import` の改行コードのみの差は対象外
- 結果: Critical 0件 / High 0件 / Medium 0件 / Low 2件

## コミット前レビュー結果

対象: worktree `remove-cut-ins` の `git diff HEAD`（コード 14 ファイル、設計書 12 ファイル、`LICENSES.md`、`export_presets.cfg.example`、ステージ済みの削除 35 件。`*.import` の改行コードだけの差は除外）と、未追跡の `soccer-game/.steering/20261127-remove-cut-ins/` の requirements.md・design.md・tasklist.md。

### Critical（即時対応必須）
- 指摘なし

### High（優先対応）
- 指摘なし

### Medium（対応推奨）
- 指摘なし

### Low / 改善提案
- [バグ/テスト] `assert_object(_panel.find_child("GoalCutIn", true, false)).is_null()`（`match_board_panel_test.gd` の 687 行目と 698 行目）は、クラスを消したいまは必ず成り立つので、退行を防ぐ力はほとんどない。それぞれのテストで意味のある検査は別の行が担っている。
  - 687 行目のテスト: `board_settle_sec + beat_gap + 300ms` の後に `is_shifting()` が false であること（待たせる仕組みが残っていれば赤になる）。
  - 698 行目のテスト: `telop_visible()` であること。
  - 害はないので、残しても消してもよい。
- [運用/ドキュメント] 素材の容量の書き方が文書ごとに揃っていない。requirements.md は「約4.5MB」、non-functional-requirements.md の 107 行目は「約 4.6MB」。実害はない。
  - なお tasklist の「3D の素材（22ファイル）」は、削除 22 件（うち `.import` が 9 件）と一致しており正しい。

### 問題なし
- **セキュリティ**
  - ① ハードコーディング・シークレット: 差分は削除が中心。追加されたのは注記と 3 つのテストだけで、キー・URL・アカウント情報は入っていない。
    - `LICENSES.md` と設計書の新しい記述にも機密はない。消えた行には調達元のドメイン（itch.io・OpenGameArt・mocap.cs.cmu.edu）があったが、これは公開されている出典で、そもそも削除される側。
  - ② 認証・認可、③ インジェクション、④ 情報漏洩: オフラインのゲームの UI と設定の削除だけで、該当する面はない。
  - 書き出しの `include_filter` は狭める方向の変更なので、意図しないファイルを同梱するおそれはない。
- **バグ**
  - 削除の取りこぼし: `game/` 配下の .gd・.tscn・.tres・.cfg・.godot・.json を対象に、`cut_in`・`CutIn`・`GoalStage3D`・`GoalPlayerModel`・`resume_shift`・`"wait"`・`assets/models` を検索した。本番コードに参照は残っていない。
    - ヒットした `resume()` は `MatchController.resume`（中断した試合の再開）で、今回とは関係ない。
    - `quiz.json` の `"id": "wait"` も関係ない。
    - `game/assets/models/` はディレクトリごと無くなり、Git の管理下にも残っていない（参照先を失った `.import` も無い）。
  - `PhaseBanner.follow` の呼び出し元（試合画面・チュートリアル・テスト）は、すべて引数 1 つの形に揃っている。
  - `"wait"` を作る側（`reveal_keyframes`）、拍に写す側（`BoardShift.build_beats`）、止める側（`BoardReveal._wait`・`resume`・`_waiting`・`_resumed`）が揃って消えている。`stop()` で戻すべき状態も残っていない。
  - `MatchBoardPanel`: `unbind`・`start_turn`・`_on_turn_resolved`・`_build` からカットインへの参照が消えた。`_on_play_landed` は「`_reveal` が null なら何もしない → テロップを出す」だけになり、条件分岐の抜けもない。
  - `ConfigRepository`: 範囲の検査を 2 つ消した後も、残りの検査の並びと初期値に戻す扱いは変わっていない。同梱の `.tres` からも項目が消えており、読み込み時に未知の項目は生じない。
- **テスト**
  - `test_a_goal_reshapes_to_the_kickoff_without_waiting_for_a_cut_in`: 着地を待ってからテロップが出ていることを確かめ、組み直しが終わることを見ている。開示が動かずに素通りする空振りにはならない。
  - `test_the_phase_banner_shows_after_the_ball_changes_hands`: 局面を変える前と後の 2 回 `_on_turn_started` を呼び、帯が出ることとその文言を検査している。期待値は `MatchTexts` の関数から作っているが、検査しているのは画面の配線なので、実装の写しにはなっていない。
  - `frames[1].has("wait")` が false であることの検査: 仕様として妥当。
- **性能**: 削除だけなので、計算量の増加はない。SubViewport・3D の描画が無くなるので軽くなる方向（pck は 4.9MB から 1.07MB、という依頼元の記録と矛盾しない）。
- **運用・ドキュメント**
  - 設計書は 12 ファイルとも整合している。要件・機能概要・アーキテクチャ・非機能要件・リポジトリ構造・用語集・コンポーネント設計・画面設計・シーケンス図（drawio から `goal_cut_in_sec`・`transition_cut_in_sec`・`GoalCutIn.play`・`resume_shift` の記述を外した）・画面詳細 3 つ。
  - repo 全体の .md・.yml を検索した。カットインに触れる残りの記述は、どれも「2026-11-27 に外した」という経緯の注記で、現行の仕様として残っているものはない。
  - `LICENSES.md` には外した経緯と、Git の履歴のどこを見ればよいかが残っている。
  - 削除はすべて Git の履歴から戻せる（revert 可能）。
  - steering の 3 文書と実際の差分は一致している。

### 未検証
- テストを自分では流していない。86 スイート・1220 件の成功とブラウザ版での確認は、依頼元の報告をそのまま使っている。
- Android の実機で、カットインが消えて動くようになったかは確認していない。
- `*.import` の改行コードの差と、削除されたファイルの中身は、指示どおりレビューしていない。
- glossary.md の差分（2 行削除）と各設計書の細部は、検索結果と diff の要約で見ただけで、全文は読んでいない。

### 総合評価
Critical・High の指摘はない。Low が 2 件で、どちらも実害はなく、申し送りで足りる。このままコミットしてよい。

### 対応
- Low（`GoalCutIn` のノードが無いことの検査）: 残す。いまは必ず成り立つが、同じ名前のカットインを戻したときに赤になって、
  この PR の判断（Android で動かないので出さない）との食い違いに気づける。意味のある検査（組み直しが止まらない・テロップが出る）は同じテストにある
- Low（容量の表記ゆれ）: 直した。`requirements.md`（ステアリング）の「約4.5MB」を、台帳・非機能要件と同じ「約4.6MB」に揃えた（記述だけの修正）

## レビュー完了（2026-11-27）
- 最終ラウンド: 第1回
- 新たな Critical / High: なし
- 積み残し: なし（Low 1件は残す判断、1件は修正済み）
- 未検証のまま残るもの: Android の実機での確認（マージ後に Pages で確かめる）
