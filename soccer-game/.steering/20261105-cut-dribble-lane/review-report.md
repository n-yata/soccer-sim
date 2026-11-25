# コミット前レビューレポート

## 第1回（2026-11-05）
- 対象: game_enums・move_rules・move_menu・open_play_judge、match_texts・judge_reason_formatter・tutorial.json、関連テスト（match_controller_test は AlternatingStylesOpponent.choose_setup だけ）、docs/specs の CLOSE_DOWN に関わる差分。並行セッションの作業（プレビュー・駒の動き）は対象外
- 結果: Critical 0件 / High 1件 / Medium 1件 / Low 3件

## コミット前レビュー結果

対象: 守備の CLOSE_DOWN を「ボールに寄せる」から「ドリブルのコースを切る」に変えた差分。範囲は game_enums / move_rules / move_menu / open_play_judge、match_texts / judge_reason_formatter / tutorial.json、指定されたテスト、docs/specs の CLOSE_DOWN に関わる部分。読み取りだけで確認し、ファイルは一切書き換えていない。

### Critical
指摘なし

### High
**H-1【バグ／空振りテスト】CLOSE_DOWN の「人数に関係なく LOSS」の分岐を検証するテストが無い**
- `open_play_judge.gd` の `elif defense.action == CLOSE_DOWN and detail.read == EXACT: outcome = LOSS` を確かめるテストは2本ある。`open_play_judge_test.gd::test_cutting_the_dribble_lane_where_the_dribble_goes_wins_the_ball_there` と `match_rules_test.gd::test_a_dribble_read_by_cutting_its_lane_is_lost_where_it_went` で、どちらも比較エリアが 1対1。
- 1対1 は、ぴったり読まれたときに要る +2 を満たさないので、`outcome_of` に任せても LOSS になる。同じテスト内の PRESS の対照ケースも `"LOSS A1-L1 1-1 NONE EXACT"` で、CLOSE_DOWN と同じ結果になっている。
- そのため、仕様の要の「人数に関係なく奪う」を実装している分岐（elif）を消しても、全テストが通る（変異が生き残る）。分岐が回帰しても、検出されずに静かに弱体化する。
- 修正例: 運ぶ先で攻撃側が2人以上多い配置を足す（例: `_team([["a1","M2-C",""],["a2","A1-L1",""],["a3","A1-L1",""]])` と `d1@D2-C`）。そのうえで次の2つを並べて検証する。
  - `DRIBBLE→A1-L1` × `CLOSE_DOWN A1-L1` は `"LOSS A1-L1 3-1 NONE EXACT"`
  - 同じ配置で `PRESS A1-L1` は `"ADVANCE A1-L1 3-1 NONE EXACT"`

### Medium
**M-1【バグ（ゲーム性）】ショートパスの枠が無い局面で、PRESS と CLOSE_DOWN が同じエリアを指す**
- `MoveMenu._defense_menu` で、PRESS はショートパスの枠が無いときドリブルの枠の行き先へフォールバックする。CLOSE_DOWN の予測先もドリブルの枠なので、2つのボタンが同じ行き先になる。
- このとき、ドリブルに対しては CLOSE_DOWN が常に奪え、PRESS は 2人差があると通される。PRESS が優位なのは、ロングパスがその隣のレーンへ来たときの NEAR だけ。PRESS がほぼ CLOSE_DOWN の下位互換になり、守備の選択肢が実質1つ減る。メモリの「毎ターンの読み合いを消さない」に触れうる。
- 規則の範囲内なので不具合ではない。要求どおりか、シャビに確認したい。対案は2つ。
  - PRESS のフォールバックを CLOSE_DOWN と重ならない先にする
  - 同じ行き先になるときは PRESS を出さない

### Low / 改善提案
- **L-1【運用／ドキュメント】** `match_rules.gd` の `_ball_after` のコメント「ボールに寄せてドリブルを読んだときだけボールのエリア（2026-11-03）」が、この変更で事実と違うものになった。今は常に運ぶ先になる。match_rules.gd は並行セッションの対象ファイルなので、コミットは hunk 単位で分けること。
- **L-2【運用／ドキュメント】** `cpu_planner.gd` のコメント「ボールに寄せる・シュートコースを塞ぐもプレス」が旧名のまま。動作はそのままで正しいので、名前を直すだけでよい。
- **L-3【テスト品質】** `judge_reason_formatter_test.gd` の `other_way` は `read` を設定せず、既定値の NONE に頼っている。`other_way.read = GameEnums.ReadKind.NONE` と明示した方が意図が読みやすい。

### 問題なし
- **セキュリティ①〜④**: URL・キー・アカウント情報の追加は無い（tutorial.json は文言の差し替えだけ）。オフラインの単体ゲームで、差分に攻撃面は無い。保存データやファイル読み込みにも触れていない。該当する OWASP の項目は無い。
- **判定**: `read_for` が EXACT になるのは「DRIBBLE かつ `defense.target == compare`（= attack.target）」のときだけ。パス、別方向へのドリブル、シュート、スルーパスは NONE。スルーパスは従来どおり `defender_entered` で判定される。バックパスとオフサイドは先に抜ける。
- **奪った場所**: `_ball_after` の LOSS は `detail.compare_area`（= 運ぶ先）を使う。
- **守備側の配置**: `DefenseMover.apply` は COVER 以外をプレスとして扱い、守備の選手を制限エリアへ動かして固定する。マンツーマンの付け直しでも、固定された選手は動かない。奪った場所に守備側がいることは、テストの `d1:D2-C>D2-R1` で確かめられている。
- **ボールの保持者**: 旧仕様の「ドリブルを適用しない」特例を外し、保持者は運ぶ先へ動いてそこで奪われる。match_rules_test で、奪った後の `next.ball_area` が D2-R1 になることも確認済み。
- **BLOCK_SHOT**: ボールのエリアに限る条件はそのまま。ペナルティエリアで寄せが届かないケースのテスト（far_shot）も足されている。
- **ball == null**: CLOSE_DOWN も BLOCK_SHOT も足さない（テストあり）。
- **MoveMenu**: ドリブルの枠が無ければ CLOSE_DOWN を出さない。予測先へ寄せられなければ、いちばん近いエリアを選ぶ（テスト3件）。
- **UI**: `_is_closed_down_dribble` に `read == EXACT` を足したので、外れたドリブルは人数で原因を説明する（テストあり）。
- **性能**: CLOSE_DOWN の候補が最大1件から最大30件になったが、計算量のオーダーは変わらない。
- **後方互換**: enum の名前と並び順は据え置き。保存した記録を再判定する経路も無い。
- **ドキュメント**: 規則・判定・行き先の選び方・LOSS の場所まで一貫して直されている。旧名は手の名前としては残っていない。

### 未検証
- テストの実行はしていない。
- `.steering/20261105-cut-dribble-lane/` の要求・設計は細部まで突き合わせていない。
- tutorial の defense ステップで、CLOSE_DOWN のボタンがどの行き先を出すかは確かめていない。
- match_controller_test の choose_setup の変更で、入れ替わりが毎回起きるかは実行で確かめていない。

### 総合評価
Critical なし、High 1件（H-1）。本番コードの規則の実装は仕様書に合っており、静かに誤る欠陥は見つからなかった。H-1 のテストを足してからコミットすることを勧める。M-1 はゲーム性の判断なのでシャビに確認したい。L-1・L-2 はコメントの修正で済む。

### 対応
- H-1: 行き先で 3対1（攻撃側が2人多い）の配置で、ドリブルのコースを切ると "LOSS A1-L1 3-1 NONE EXACT"、同じ場所へのプレスは "ADVANCE A1-L1 3-1 NONE EXACT" になることを確かめるテストを足した（open_play_judge_test）。分岐を一時的に無効にするとこのテストだけが落ちることを確かめ、元に戻した
- M-1: 対応せず、シャビに判断を仰ぐ（ショートパスの枠が無い局面だけで起きる。ゲーム性の判断のため）
- L-1: 並行セッションの match_rules.gd の書き換えで、古いコメントは既に消えていた
- L-2: cpu_planner.gd のコメントの名前を直した
- L-3: other_way に `read = NONE` を明示した

## 第2回（2026-11-05）— 修正後の再レビュー
- 対象: 第1回の指摘に対応した箇所とその周辺（open_play_judge_test・cpu_planner.gd・judge_reason_formatter_test）
- 結果: Critical 0件 / High 0件 / Medium 0件 / Low 1件

### 前回指摘の解消状況
- H-1: 解消。行き先で 3対1・差は 2 のため、`outcome_of` に任せると ADVANCE、分岐があるときだけ LOSS になり、テストが分岐を判別できる。同じ配置のプレスが ADVANCE になる対比も押さえている。周辺で書き換えた既存テスト（行き先を A1-L1 にした `_close_down_pair` 系）も実装の規則と矛盾しない。新しい欠陥は持ち込んでいない
- L-1: 対象外（既に消えていた）
- L-2: 解消（コメントだけの変更で、ロジックはそのまま）
- L-3: 解消。other_way は `_is_closed_down_dribble` の `read != EXACT` の判定を守るケースになっている
- M-1: 今回は対象外（ユーザーに確認する予定）

### Critical / High / Medium
指摘なし

### Low
- L-4【運用】作業ツリーに並行セッションの変更（チーム全体のプレビューの作業など）が混ざっている。コミットするときは自分の hunk だけをステージすること

### 未検証
- テストは実行していない（1158 件の成功と変異の確認は申告に頼った。ただし、分岐の有無で期待値が割れることはコードを読んで確認した）

### 総合評価
Critical / High はどちらも指摘なし。自分の hunk だけをコミットすれば進んでよい。

### 対応（第2回）
- L-4: 共有のファイルは、HEAD の版に自分の変更だけを当ててステージする

## レビュー完了（2026-11-05）
- 最終ラウンド: 第2回
- 新たな Critical / High: なし
- 積み残し: M-1（ショートパスの枠が無い局面で、パスコースを切るとドリブルのコースを切るが同じエリアを指す。シャビの判断待ち）
