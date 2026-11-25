# コミット前レビューレポート

## 第1回（2026-10-29）
- 対象: 振り返り画面 S-07 の追加（git diff の変更ファイル: docs/specs の4ファイル、game/application・domain/config・data・ui の変更、テスト5本。未追跡の新規: domain/review・review_summary/goal/segment、application/review_view、ui/common/review_texts、ui/screens/s07_review、テスト3本、.steering/20261029-review-screen）
- 結果: Critical 0件 / High 0件 / Medium 0件 / Low 3件

## コミット前レビュー結果

対象: 振り返り画面 S-07 の追加。依頼にあった変更ファイル（git diff）と未追跡の新規ファイル全部を読んだ。照合した仕様は functional-overview.md アルゴリズム10 と screen-07-review.md。ファイルは一切変更していない。

### Critical（即時対応必須）
- 指摘なし

### High（優先対応）
- 指摘なし

### Medium（対応推奨）
- 指摘なし

### Low / 改善提案
- [バグ（将来）] 得点後のスコアの出どころが二重になっている: `ReviewAggregator._goals` は、ターン記録の GOAL を数え直して `home_score` / `away_score` を作っている。いまは記録がすべてメモリ上にあるので、MatchState のスコアと一致する。ただし、中断と再開の作業でターン記録の一部しか戻さない形にすると、カードの「（1 − 0）」と S-06 のスコアが例外も出さずにずれる。今回の修正は不要。中断と再開の作業へ「turn_records を全件戻す」ことを申し送ってほしい。その作業で、「再開した試合の review の最終得点 = snapshot のスコア」を確かめるテストを足しておくと安全。
- [運用] `review_lookback_turns` には上限がない: 値が大きくても、ハーフの初めか直前の得点で打ち切られるので、実害はない。仕様も「0 以上」としか定めていないので、仕様どおりの実装。記録として残すだけでよい。
- [バグ／テスト] `test_review_matches_the_turn_records_seen_from_the_user` は、期待値の一部（area_tallies・phase_tallies）を `ReviewAggregator.aggregate(records, HOME, …)` という実装そのものから作っている。配線（viewer = HOME・設定値・視点の変換）の確認としては意味がある。集計の正しさそのものは review_aggregator_test が手書きの期待値で押さえているので、問題はない。補強したいなら、エリアの合計が NO_CONTEST 以外の記録の数と一致すること、つまり `sum(area_tallies) == count(outcome != NO_CONTEST)` を足すと、実装に頼らない確認になる。

### 問題なし
- **セキュリティ**
  - ① ハードコーディング: URL、エンドポイント、キー、トークン、クラウドのアカウント情報は、コードにも文書（repository-structure.md・component-design.md・screen-07/common.md）にもない。追加した設定値は表示の調整値 `review_lookback_turns=3` だけで、機密ではない。
  - ② 認証・認可: オフラインの単体ゲームなので対象がない。
  - ③ インジェクション: 画面に出る文字は内部の enum、定数の文言、数値だけ。Label は BBCode を解釈しないので、注入の経路がない。ファイル入力は、従来どおりの ConfigRepository による .tres 読み込みだけ。
  - ④ 情報漏洩: 追加した push_error は「ファイル名と範囲外の値」と「review を試合前に呼んだ」の2件で、どちらも機密を含まない。
  - OWASP: 該当なし。
- **バグ（集計の正しさ）**
  - 数え方の表: `tally_of` は表の9行すべてと一致している。攻撃側・奪取側の勝ち負けを守備側・喪失側では入れ替え、STALL はそのまま、NO_CONTEST は数えない。テストは enum の件数と表の行数が等しいことまで確かめている。
  - 局面: トランジションのターンでは、`TurnRecord.attacker` は奪取側を指す（turn_record.gd・transition_judge.gd で確認）。`phase_of` が奪取側を POS、喪失側を NEG にするのは仕様どおり。
  - 視点の鏡像: `compare_area` は攻撃側（奪取側）から見た座標。カウンターは `winner_choice.target`、即時奪回×保持は奪取側から見たボール X、オフサイドは受け手のいたエリアで、どれも同じ視点。viewer が相手側のときだけ `mirrored()` する。テストの M2-L1 → M1-R1、D2-R2 → A1-L2 も正しい。`judge == null` になるのは NO_CONTEST だけで、OFFSIDE にも内訳がある（open_play_judge.gd で確認）。数え漏れはない。
  - 得点の遡り: 遡ってよい範囲の起点 `window_start` は、ハーフが変わると現在位置に、得点の後は得点の次に動く。`range(max(window_start, index-N), index)` で、得点のターンそのものは含めない。ハーフの1ターン目の得点では0件、続けて得点したときは前の得点より前を含めない、N=0 なら得点のターンだけ。どれもテストがある。lookback が負でも `maxi(…,0)` で守られる。
  - 時間帯: 同じハーフで、陣形と両方式（defense・attack）の両チーム分が同じなら同じ時間帯にまとめる。TeamStyles の項目はこの2つしかないので、比べ漏れはない。後半の初めでは必ず区切る。setup は複製して持つ。
  - 空・0件: 記録0件、NO_CONTEST だけ、得点0件、試合前のどれでも落ちない（画面は `is_match_started` を見てから呼び、controller は null を返す）。
  - 状態のリセット: `enter` のたびに作り直してエリア別のタブへ戻す。`clear_overlays` は `_tally` も消す。`show_counts` は2チーム表示の状態を消す。タブの `tab_changed` と `select_tab` が互いを呼び続けることはない（値が同じなら代入しない）。ループ内のラムダは index を値で取り込むので問題ない。
  - S-06: 終了処理中（State が IDLE 以外）は「振り返り」ボタンを無効にし、`_open_review` の側でも状態を見て止めている。S-07 から戻ると、S-06 の `enter` が IDLE に戻す。
  - テスト: aggregator・texts・screen・controller・config のテストは、どれも具体的な入力と期待値を手で書いている。恒真のテストや空振りのテストは見当たらない（上の Low の1件を除く）。
- **性能**: 集計は記録の件数 n に比例する1回だけの処理で、開くたびに走る。n は1試合で数十件、上限はハーフのターン数とアディショナルタイムで決まる。RevealView を作るのは得点の数 ×（N+1）件までで、seq 引きは辞書で行う。集計の札の字を縮めるループは、18px から 11px までの最大7回。どの規模でも問題にならない。
- **運用**: 新しい設定値は .tres に外出しされ、範囲外なら push_error を出して初期値に戻る。範囲内・負の値・同梱の初期値はテストで固定されている。PresentationConfig の初期値と .tres の値はどちらも 3。後方互換は、Resource への @export の追加なので、古い .tres を読むと初期値になる。revert で戻せる。文書（component-design・screen-07・screen-common・repository-structure）は実装と一致している（400px への変更、MiniPitch 56×34、`add_to_right`、`show_tally`）。

### 未検証
- テストは実行していない。読み取りに限ったレビューのため。全件通過（46/46・697/697）と変異10個の検出は、依頼元の報告をそのまま記している。
- 実機（Android）での見え方は確かめていない。11px の札が奥の行に収まるか、タブの幅、`_bar` の色を enter の時点でテーマから取れているか（main_shell が木に入れてから enter を呼ぶ順序かどうか）。main_shell.gd の中で enter を呼ぶ箇所が見つからず、順序を追い切れなかった。テストとスクリーンショットで確かめたという記述があるので、実害はないと見ている。
- ViewConverter.reveal の動きの変換（movements の side と座標が利用者の視点か）は、既存のコードとして中まで追っていない。MiniPitch は、`side == HOME` を利用者として扱う前提で正しい。

### 総合評価
Critical / High の指摘はない。コミットしてよい。Low の申し送りは2件で、中断と再開の作業でスコアを照合するテストを足すことと、任意で配線テストを補強すること。

### 対応
- Low「スコアの出どころが二重」: 今回は直さない（レビューの判断どおり）。中断・再開の作業への申し送りとして `retrospective.md` に書いた（ターン記録を全件戻すこと、再開した試合で「review の最終得点 ＝ snapshot のスコア」を確かめるテストを足すこと）。
- Low「review_lookback_turns に上限がない」: 仕様（0 以上）どおりで、ハーフの初めと直前の得点で打ち切られるため直さない。記録のみ。
- Low「配線テストの期待値が実装由来」: `test_review_matches_the_turn_records_seen_from_the_user` に、集計の実装に頼らない確認を足した（判定なし以外のターン数 ＝ エリア別の合計 ＝ 局面別の合計）。

同時に、実装検証（review-implementation。[必須]なし・総合 4.5/5）の[推奨]にも対応した。
- `review_screen.gd` が 418 行で目安 300 行を超えていた → 局面別のページを `ReviewPhasePage`、得失点のページを `ReviewGoalsPage` に分けた（193・89・152 行）。子を消す処理は `MatchScreenLayout.clear` に1つだけ置き、ラベルは既存の `MatchScreenLayout.text` を使う。テストの呼び先をページへ付け替えた。
- `MiniPitch.show_counts` の使っていない引数 → 外した（呼び出し側の `formation_card.gd`・テスト・screen-common.md も直した）。
- `[勝ち, 負け, 膠着]` の位置に頼る配列 → 横棒は `GameEnums.JudgeTally` の値で添字を引く形にした。値クラスにするのは画面が増えたときに検討する（積み残し）。

修正後の確認: tools/run-tests.sh で 46/46 スイート・697/697 件成功。局面別・得失点のタブを撮り直し、組み替えの前と同じ表示であることを確かめた。

修正は Low と実装検証の[推奨]への対応だけで、Critical / High を直したものではないため、再レビューは行わない（review-pre-commit「Medium / Low はループを回す理由にならない」）。

## レビュー完了（2026-10-29）
- 最終ラウンド: 第1回
- 新たな Critical / High: なし
- 積み残し（Medium / Low を申し送る場合）:
  - 得点後のスコアをターン記録から数え直している（中断・再開の作業で、ターン記録を全件戻すことと、再開した試合で最終得点を照合するテストを足す。今は記録がすべてメモリにあり、ずれは起きない）
  - `review_lookback_turns` に上限がない（仕様どおり。実害なし）
  - `ReviewView.goals`・`segments` の Dictionary と `[勝ち, 負け, 膠着]` の配列は、値クラスにしていない（画面が増えたときに検討する）
