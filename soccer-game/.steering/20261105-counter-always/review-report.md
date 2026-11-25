# コミット前レビューレポート

## 第1回（2026-11-05）
- 対象: move_rules.gd（pos_transition_options）、transition_judge.gd（carry_if_empty とカウンターの分岐）、open_play_judge.gd（carry_ball）、move_hints.gd（_add_winner_hints）、追加テスト、functional-overview.md（アルゴリズム3・6）と glossary.md の追記。並行セッションの作業（チーム全体のプレビュー）は対象外
- 結果: Critical 0件 / High 0件 / Medium 2件 / Low 5件

## コミット前レビュー結果

対象: 「前に味方がいなくてもカウンターを選べるようにする」変更。範囲は move_rules.gd（pos_transition_options）、transition_judge.gd（carry_if_empty とカウンターの分岐）、open_play_judge.gd（carry_ball）、move_hints.gd（_add_winner_hints）、それぞれの追加テスト、functional-overview.md（アルゴリズム3・6）と glossary.md の追記。直近の呼び出し元として MoveRules.options_for、MovePreview（TransitionJudge.judge 経由）、MatchRules.resolve_turn / _apply_judged / _ball_after / _apply_outcome、MatchPositions.place_holder / stop_dribble、ball_flight.gd も確認した。ファイルは一切書き換えていない。

### Critical
指摘なし

### High
指摘なし

### Medium
1. **[バグ] 膠着（STALL）した自力カウンターでは、運んだ選手が運ぶ先に残る。ドリブルの膠着と後始末が違う。**
   - 何が起きるか: カウンターの判定が STALL のとき、ボールは X に残るが、運んだ選手は X+1 列に固定されたまま `store_players` に入る。`stop_dribble`（DRIBBLE_STOPPED で元へ戻す処理）は `turn_kind == OPEN_PLAY` のときしか動かないので、トランジションでは呼ばれない。その後は `release_fixes` → `place_holder` の順に進む。
   - その結果: X に他の奪取側がいなければ、1マス以内のいちばん近い選手が BALL_HOLDER で X に置かれる（距離が同じなら配置の順なので、運んだ選手以外のこともある）。記録には「DRIBBLE で前進 → 別の選手が戻る」が並び、攻守ターンのドリブル膠着（運んだ選手が元に戻る）と食い違う。
   - 発生する場面: 1対1 で背後にカバーがいる。design.md の「膠着・ロストは保持者の配置に任せる」に沿った挙動ではあるが、仕様の「ドリブルと同じ動き」の読み方として食い違うので、意図どおりかシャビに確かめたい。
   - 修正例: `_apply_judged` の stop_dribble の条件を、トランジションのカウンターにも広げる（stop_dribble は DRIBBLE 理由の動きだけを戻すので、飛び出しは残る）。MatchRules の STALL のテストを1件足す。MatchRules は並行セッションの差分と重なる。

2. **[バグ] X に奪取側が1人もいなくても、自力カウンターの運ぶ先が出る。**
   - 何が起きるか: `place_holder` が誰も置けなかった場合、`_dribble` は誰も動かさない。そのため運ぶ先の攻撃側は0人で、守備側も0人なら `outcome_of` は diff=0 から ADVANCE になり、誰もいないのにボールだけが前へ進む。変更前は「前に味方が1人以上いる」ことが条件だったので、起きなかった。ヒントは「0-0」と出る。
   - 修正例: 自力の分岐を `winner.count_at(ball) >= 1` のときだけにする。

### Low / 改善提案
1. **[バグ／仕様確認]** RETREAT とマンツーマンの組み合わせで、マーカーが運んだ選手を追わない（judge の順序が「飛び出し → リトリート → 自力で運ぶ」のため、マーカーは運ぶ前の X へ向かう）。順序の意図を design.md に一言残すとよい。RETREAT×自力カウンターのテストも無い。
2. **[運用・表示]** 自力カウンターでも、ボールの軌道がグラウンダー（パス）のまま。選手は DRIBBLE 理由で動くので、見た目がずれる。
3. **[運用]** component-design.md §2.4 に `TransitionJudge.carry_if_empty` と `OpenPlayJudge.carry_ball` が載っていない。`pos_transition_options` と MoveHints の説明にも、自力で運ぶ分岐が反映されていない。
4. **[テスト]** 境界のテストが足りない（右の大外、A1 で奪って A2 へ運ぶ、自力カウンターの STALL・LOSS 後の保持者の配置、X に保持者がいない場合、飛び出しと自力運びの重なり）。追加済みのテストは、どれも具体的な入力と期待値を検証していて、恒真テスト・空振りテストではない。
5. **[コード品質]** `carry_ball` は `_dribble` への委譲だけなので、コメントに「ドリブルと同じ選び方（固定された選手を優先）」を書くと分かりやすい（任意）。

### 問題なし
- **セキュリティ①〜④**: オフラインの純粋なドメイン計算だけ。ハードコーディング・認証・インジェクション・情報漏洩の経路は無い。OWASP の該当も無い。
- **判定・ヒント・プレビューの一致**: ヒントは同じ `carry_if_empty` を通し、MovePreview は `TransitionJudge.judge` を通るので一致する。選べる運ぶ先と判定は同じ `counter_layout` を使うので、「空なら運ぶ」の判断が食い違わない。
- **境界**: 大外では盤の外は出ない（テストあり）。A2 で奪ったときは1列前が無いので、カウンターは出ない（既存テストで維持）。
- **LOSS・ADVANCE**: ボールは運ぶ先へ移り、運んだ選手もそこに固定される。
- **性能**: 無視できる増加だけ。
- **後方互換**: 保存データの形式は変わらない。前に味方がいる局面の挙動も変わらない（テストあり）。

### 未検証
- テストは実行していない。
- Medium 2 が実際の試合でどれくらい起きるか。
- MoveMenu・CpuPlanner の中身は読んでいない。
- review_texts / record_texts が、トランジションの DRIBBLE 理由の動きをどう文章にするか。

### 総合評価
Critical / High: 指摘なし。判定・ヒント・プレビューは同じ関数を通っていて、規則は差分のとおりに実装されている。Medium の2点は、仕様の判断か、小さな修正とテスト1件ずつで片付く。

### 対応
- Medium 2: 自力で運ぶ運ぶ先は、ボールのエリアに奪った側がいるときだけ出すようにした。いないときにカウンターが出ないことを確かめるテストを足し、functional-overview・component-design にも書いた
- Medium 1: 積み残し。直すには match_rules.gd（並行セッションが作業中）の `_apply_judged` を変える必要があり、ふるまいの判断（膠着したら運んだ選手を戻すか）も要るので、シャビに確かめる
- Low 3: component-design.md に `carry_if_empty` と、pos_transition_options・MoveHints の説明を足した
- Low 5: `carry_ball` のコメントに、運ぶ選手の選び方を書いた
- Low 1・2・4: 積み残し（Medium 1 とあわせて、遊んだ結果で直すか決める）

## レビュー完了（2026-11-05）
- 最終ラウンド: 第1回（Critical / High が無かったため再レビューなし。修正後に全体テスト 1165 件成功・128 秒）
- 新たな Critical / High: なし
- 積み残し: Medium 1（自力カウンターが膠着したとき、運んだ選手が前に残る）、Low 1（リトリート×マンツーマンのマーカーが運んだ選手を追わない）、Low 2（自力カウンターのボールの軌道がパスのまま）、Low 4（境界のテスト）
