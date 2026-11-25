# コミット前レビューレポート

## 第1回（2026-11-10）
- 対象: move_rules.gd・defense_mover.gd・match_texts.gd、テスト3本（move_rules_test・open_play_judge_test・match_texts_test）、仕様書3本（functional-overview・glossary・component-design）、.steering/20261110-block-shot-on-ball/。直近の呼び出し元（OpenPlayJudge・MovePreview・MoveHints・CpuPlanner・StyleLayoutCalculator）まで
- 結果: Critical 0件 / High 0件 / Medium 2件 / Low 3件

## コミット前レビュー結果

**結論: Critical と High はどちらも無し。コミットしてよい。ただし Medium の運用指摘1（ステージの仕方）だけは、コミット操作の中で必ず守ってほしい。**

読み取りだけで、ファイルの書き換えや実行はしていない。

### Critical（即時対応必須）
なし

### High（優先対応）
なし

### Medium（対応推奨）
1. [運用] **仕様書3本に、別作業の変更が混ざっている**
   - 混ざっている記述:
     - functional-overview: 「トランジションのカットインの時間」の行
     - glossary: 「得点のカットイン（選手は人形）」と「トランジションのカットイン」の行
     - component-design: `transition_cut_in_sec`・`PresentationConfig` の表・`GoalCutIn`・`GoalStage3D`・`StealCutInArt`・`SaveCutInArt`・`GoalPlayerModel`・`PhaseBanner` の行・UI の名前の一覧
   - この3本をファイル単位でステージすると、トランジションのカットインと chibi-cut-in の仕様記述が一緒にコミットされる。
   - 対処: hunk 単位でステージする。BLOCK_SHOT の hunk は、functional-overview と glossary に1つずつ、component-design に2つ（DefenseMover の決めごとと `defense_options` のコメント）。
   - コード6ファイルは、このフィックスの hunk しか無いので、ファイル単位で問題ない。
2. [バグ] **その場で塞ぐ選手を固定していない**
   - 既にある決めごととずれている。COVER では、行き先にもういる選手を「その場で固定し、動きには含めない」としている（component-design と `test_cover_by_a_player_already_behind_fixes_in_place_without_a_movement`）。
   - 今回の分岐は `pair.duplicate_deep()` を返すだけで、誰も固定しない。隣から寄せる BLOCK_SHOT では、寄せた選手が固定される。
   - マンツーマンでは、`apply_defense` が直後に `remark` を呼ぶ。ボールのエリアに攻撃側がいない場面では、塞ぐ選手が別の相手のマークへ1マス引き抜かれうる。そうなると、BLOCK_SHOT（読み EXACT）を選んだのにボールのエリアの守備が減り、例外も出ずに静かに誤る。
   - 修正案: 特別な分岐を作らず、COVER と同じ「その場で固定」の経路に乗せる（`source = restricted`）。
   - 固定しない方を選ぶなら、その理由を component-design に書く。
   - どちらを選んでも、マンツーマン（`MAN`）でボールのエリアに守備側だけがいる場面を、テストに1件足すとよい。

### Low / 改善提案
3. [運用] `DefenseMover.apply` の関数コメント（12〜13行目）が古い。BLOCK_SHOT の例外を一言足すとよい。
4. [バグ/テスト] 2つの条件の一致を確かめる整合テスト `test_apply_succeeds_exactly_for_the_defense_options` が、BLOCK_SHOT を見ていない。
   - `MoveRules.defense_options` と `DefenseMover.apply` は、同じ条件を別々に書いている。
   - ペナルティエリアの ball を渡し、「BLOCK_SHOT が選べる ⇒ `apply` が null でない」を全配置で確かめる一方向のアサーションを足すとよい。
5. [運用] 塞ぐ選手が動かないので、決定前のプレビュー（`MovePreview.own_movements`）が空になり、矢印も出ない。
   - COVER のその場固定と同じ扱いで、矛盾ではない。
   - 利用者には「選んだのに何も起きない」ように見える可能性がある。遊んで確認してもらう候補。

### 問題なし
- **セキュリティ**: ハードコーディング（URL・キー・トークン・アカウント情報）は0件。認証・インジェクション・情報漏洩・OWASP は、オフラインの純粋なルール計算と固定文言だけなので該当しない。
- **他の手の条件**: `can_press` の内側は PRESS と CLOSE_DOWN だけで、条件は元と同じ。COVER も変わっていない。BLOCK_SHOT は「ball・ペナルティエリア・隣かボールのエリアに守備側」がすべてそろうときだけ足される。視点もそろっている。
- **null を返さなくなったことの影響**: 次の呼び出し元を追い、問題が無いことを確かめた。
  - `OpenPlayJudge.judge`
  - `MovePreview.team_steps`・`MovePreview.own_movements`
  - `MoveHints`・`CpuPlanner`（`DefenseMover` を呼ばない）
- **テスト**: 空振り・恒真になっていない。変更前は `judge` が null になるので、新しいテストは確かに落ちる。
- **性能**: `count_at` の呼び出しが1回増えるだけ。

### 未検証
- テストと Godot は実行していない。
- マンツーマンで、塞ぐ選手が実際に引き抜かれるか（コードから推しただけ）。
- ゲームバランス（範囲外）。

### 総合評価
**Critical と High はどちらも無いので、コミットしてよい。**
- 必須: Medium 1。
- 推奨: Medium 2。

### 対応
- **Medium 1（仕様書に別作業の記述が混ざる）**: 守る。仕様書3本は、このフィックスの hunk だけをステージする（functional-overview・glossary に1つずつ、component-design に2つ）。
- **Medium 2（その場で塞ぐ選手を固定していない）**: 直した。
  - COVER のその場固定と同じ決めごと（行き先にもういる選手を固定し、動きには含めない）の具体化なので、ゲームの規則の新しい判断ではないと考え、レビューの案どおり `source = restricted` で COVER と同じ経路に乗せた。
  - テストを足した:
    - `defense_mover_test`: その場で固定し、動きは空。隣にいれば寄せる。
    - `open_play_judge_test`: マンツーマンで、塞いだ選手がボールのエリアに残り、SAVE になる。
  - 先にテストが落ちることを確かめた。変異（固定しない形に戻す）で落ちることも確かめた。
  - マンツーマンのテストは、ボールのエリアに攻撃側がいる普通の場面なので、固定しない形でも通る（レビューの見立てどおり実害は小さい）。固定の検出は `defense_mover_test` が持つ。
- **Low 3（DefenseMover の関数コメント）**: 直した。
- **Low 4（整合テストが BLOCK_SHOT を見ていない）**: 直した。`test_blocking_the_shot_applies_whenever_the_rules_offer_it` を足した。4つの配置 × ペナルティエリアの3つのボールで、選べるなら適用が null でないことを確かめる。
- **Low 5（その場で塞ぐとプレビューの矢印が出ない）**: 直さない。COVER のその場固定と同じ扱い。遊んで気になるか、シャビに伝える。
- 直した後: 関連の5スイート 169件成功、全体 1305件成功・157秒。

## レビュー完了（2026-11-10）
- 最終ラウンド: 第1回（Critical / High が無かったので、再レビューのループは回していない）
- 新たな Critical / High: なし
- 積み残し:
  - Low 5。遊んで判定する。
  - ゲームバランスの目安の外れ（得点 1.43 点・入れ替わり 10.2 回・保持者の不変条件）。この変更の前からの外れを含むので、シャビの判断で別の作業にする。
