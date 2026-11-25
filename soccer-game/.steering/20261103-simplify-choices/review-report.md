# コミット前レビューレポート

## 第1回（2026-11-04）
- 対象: 手の選択の簡素化の差分（MoveMenu 新規、move_rules・move_hints・open_play_judge・match_rules・cpu_planner・game_enums、match_controller、choice_panel・match_board_panel・ball_flight・match_texts・judge_reason_formatter・match_screen、tutorial.json、関連テスト、docs/specs）。並行セッション分（作戦ボードの分割）は対象外
- 結果: Critical 0件 / High 0件 / Medium 0件 / Low 6件

## コミット前レビュー結果
対象: 手の選択の簡素化の差分。MoveMenu（新規）、move_rules / move_hints / open_play_judge / match_rules / cpu_planner / game_enums、match_controller、choice_panel / match_board_panel / ball_flight / match_texts / judge_reason_formatter / match_screen、tutorial.json、move_menu_test（新規）と変更されたテスト、docs/specs の差分。並行セッション分（tactics_board ほか）は対象外とした。ファイルは書き換えていない。

**結論: Critical / High の指摘はなし。**

### Critical（即時対応必須）
指摘なし

### High（優先対応）
指摘なし

### Medium（対応推奨）
指摘なし

### Low / 改善提案
1. **[バグ] チュートリアルの守備段階で、読みを当てられるか保証がない（未検証）**
   - tutorial.json の "defense" 段階では、相手の手が `SHORT_PASS M2-L1` に決め打ちされている。
   - 一方、利用者の「パスコースを切る」の行き先は MoveMenu が決める。攻撃側メニューの第1枠の行き先（スルーパスに替わることもある）か、それに近いエリアになる。
   - このため M2-L1 と一致する保証がない。本文の「ショートパスを読むならパスコースを切る」のとおりに選んでも、読みが外れる場合がある。
   - 一致を確かめるテストは差分に見当たらない。
   - 提案: この段階の局面で `MoveMenu.options_for(state, HOME).targets(DEFENSE, PRESS)` が M2-L1 になることを確かめるテストを足す。一致しない場合は、決め打ちの手を MoveMenu の行き先に合わせる。

2. **[バグ] ボールに寄せてドリブルを奪ったときの判定理由が、人数の話になることがある**
   - 判定は人数に関係なく LOSS（open_play_judge.gd の CLOSE_DOWN 分岐）。
   - JudgeReasonFormatter._cause は、攻撃側の人数が守備以上のときだけ「読まれて」を出す。攻撃側の人数が少ないと「相手が数的優位でロスト」と出て、本当の原因（読み）と食い違う。
   - スルーパスと同じく、手の組み合わせで原因の句を決める分岐を足すとよい（例: `_is_close_down_read(reveal)` なら読みの句）。
   - この組み合わせ（攻撃側が少ない）を検出するテストは、judge_reason_formatter_test の差分では確認できなかった。

3. **[バグ/保守] シュートに使われなくなった分岐が残っている**
   - read_for で、PRESS・CLOSE_DOWN はシュートの読みに数えなくなった（攻守ターンのシュートの読みは EXACT か NONE だけ）。
   - そのため judge_reason_formatter の GOAL かつ NEAR の分岐（「隣を読まれたが同数で」）には、シュートの場合もう入らない。
   - 害はないが、仕様の読み違いを招くので整理を推奨する。

4. **[UI] 同じエリアに複数の手の行き先が重なると、札の表記が崩れる**
   - match_board_panel._show_destinations は番号を後ろに足すため、札が「① +1②」のように、ヒントの後ろに番号が付く形になる。
   - 見た目だけの問題。

5. **[運用] 切り戻すと、新しい中断データが読めない**
   - enum は末尾に足して名前で保存するので、既存の保存データは読める。
   - ただし BACK_PASS / CLOSE_DOWN / BLOCK_SHOT を含む新しい中断データは、旧版へ切り戻すと読めず、中断中の試合が失われる。
   - ローカルの単体ゲームなので影響は小さい。切り戻し手順に一言添える程度でよい。

6. **[性能] 守備側のメニューを作るたびに、攻撃側のメニューも作り直している**
   - 守備の MoveMenu は、内部で攻撃側の MoveMenu を作る（MoveRules.options_for と MoveHints.evaluate を全候補で回す）。
   - CPU は毎ターン1回これを作り、さらに CpuPlanner がメニューのヒントを再評価する。
   - 盤面は固定サイズ（5レーン×6列）で上限があるので、通常の試合では問題にならない。
   - 気をつける規模: 大量のシミュレーション（match_balance_probe）では、ターンあたりの計算が守備側の分だけ増える。全体テストを3分以内に収める条件に関わるので、balance 系が既定の実行に入っていないかだけ確認を勧める。
   - user_hints は MoveHints.evaluate をキャッシュしないが、呼ばれるのはターン開始とヒントの切り替えだけなので許容範囲。

### 問題なし
- **セキュリティ①〜④・OWASP**: ハードコードされたシークレット・URL・アカウント情報はコードにもドキュメント差分にもない（差分全体を grep して確認）。
  - オフラインの単体ゲームで、認証・認可・インジェクション・SSRF に当たる攻撃面は差分にない。
  - 外部入力の取り込み（A08）は増えていない。tutorial.json は同梱データで、読み方も変わっていない。中断データの読み込みも既存の enum 名の照合のまま。
  - ログ・エラーメッセージにも機密情報の出力はない。
- **MatchController の `_user_menu` キャッシュ（同一インスタンスかで比較）**: `_state` への代入（開く・解決・選び直し・ハーフタイム・終了処理・null）はすべてオブジェクトの差し替えだった。state()/snapshot() は写しを返し、ViewConverter.options_to_user・restricted_to も入力を書き換えない。キャッシュが古くなる経路は見つからなかった。
- **`_ball_after` の LOSS**: compare_area に変えたが、LOSS を出す経路では、どれも detail が null にならず、比較エリアが運ぶ先と一致する。
  - 経路はスルーパス、outcome_of、カウンター（TransitionJudge は target で detail_at）。
  - ボールに寄せた LOSS だけがボールのエリアになり、意図どおり。
- **BACK_PASS の NO_CONTEST**: judge が null になるが、ViewConverter（has_detail）、JudgeReasonFormatter（攻守ターン用の文を追加済み）、中断データ（NO_CONTEST のときだけ judge が null、という一貫性の検査）のどれとも整合する。
  - 攻撃の終わり（`_ends_attack`）にも、攻守の入れ替えにも数えず、ボールは運ぶ先へ移る。
- **DefenseMover**: COVER 以外をプレスとして扱うので、CLOSE_DOWN / BLOCK_SHOT はボールのエリアへのプレスとして動く。CpuPlanner._is_preferred も COVER 以外をプレス側に数えていて一貫している。
- **CPU の選べる手の確認**: CPU の手はメニューから選び、MoveRules の全候補で確かめる。メニューは全候補の部分集合（行き先は候補から選び、守備は `_nearest` で候補から選ぶ）なので、確認に落ちない。
- **ChoicePanel の有効・無効**: start_turn は show_options の後で `set_enabled(true)` を呼ぶので、前のターンの無効状態は残らない。
- **テスト**: move_menu_test は具体的な局面と期待するキーを検証していて、恒真のアサーションはない。判定の新しい分岐（ボールに寄せてドリブルを奪う・パスコースを切るとボールに寄せるではシュートを読まない・バックパス）にも、判定とターン解決の両方の層でテストがある。

### 未検証
- テストは実行していない（読み取りに限ったレビューのため）。
- docs/specs の .drawio の差分は中身を確認していない。md の差分は機密情報の有無だけを確認し、仕様との整合までは読んでいない。
- チュートリアルの守備段階で、MoveMenu の行き先が決め打ちの手と一致するか（Low-1）。
- judge_reason_formatter_test・ball_flight_test・match_board_panel_test の差分の中身。
- MoveMenu を CPU に使ったことによるバランスの変化（match_balance_probe）。

### 総合評価
Critical / High はなく、コミットして差し支えない。ドメインの変更（バックパスの NO_CONTEST、ボールに寄せた LOSS の位置、読みの決め方）は、下流の開示・中断データ・判定理由と整合している。コミット前に Low-1（チュートリアルの読みが一致するか）だけは確認を推奨する。

### 対応
- Low-1（チュートリアルの守備）: 確認したところ、実際に一致していなかった（「パスコースを切る」の行き先と、相手の決め打ちのパスがずれていた）。決め打ちの相手の手を、ゲームが選ぶショートパスの枠の手（スルーパス）に合わせ、説明文に「スルーパスを含む」を足した。一致を確かめるテスト（tutorial_controller_test）を足した
- Low-2（ボールに寄せたロストの判定理由）: 手の組み合わせで原因の句を「読まれて／読み切って」にする分岐を足し、攻撃側が少ない場合のテストを足した
- Low-3（シュートの隣の読みの分岐）: 残す。旧版で記録したターン（シュートに隣の読みが付いたもの）を振り返りで表示するときに使うため
- Low-4（札の表記）: 番号を先に並べ、ヒントの札を後ろに置く形に直した（テストも合わせた）
- Low-5（切り戻し）: 対応なし。retrospective.md に申し送る
- Low-6（性能）: balance 系は既定の実行に入っていない（--with-balance のときだけ）。既定の全体テストは 162 秒で 3 分以内。MatchController は画面に出す手を状態ごとに1回だけ作る

## レビュー完了（2026-11-04）
- 最終ラウンド: 第1回（Critical / High が無かったため再レビューなし。Low の修正後に全体テスト 1121 件成功・162 秒）
- 新たな Critical / High: なし
- 積み残し: Low-3（旧記録の表示に使う分岐を残す）、Low-5（切り戻すと新しい中断データが読めない。オフラインの単体ゲームで影響は小さい）
