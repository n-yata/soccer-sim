# 設計

## 方針

- 動きの計算は判定と同じ関数を通す。画面では計算しない。
- 「相手が何もしない」は、相手が選手を動かさない手で表す。攻守ターンは相手の手を適用しない。トランジションは、奪取側なら保持、喪失側なら即時奪回を相手の手とする。どちらも配置を変えない手。
- 返すのは**自チームの動き**だけ（`Array[Movement]`）。動かない選手は、いまの盤面（`BoardSnapshot`）の位置のまま。そのため、配置そのものは返さない。

## ドメイン

### `OpenPlayJudge.apply_defense(pair, defender_styles, defense) -> LayoutStep`（新設。judge から切り出す）
- アルゴリズム5の手順2（守備の手）と、マンツーマンのマークの付け直しを行う。
- 適用できなければ null。
- `judge` はこれを呼ぶ形に直す（動作は変えない）。

### `MovePreview.own_movements(state, side, choice) -> Array[Movement]`（新設。`game/domain/judge/move_preview.gd`）
- 置き場所は MoveHints の隣にする。MoveHints は人数を出すクラスで、動きは返さない。そのため、別のクラスにする。
- choice は判定時の攻撃側（奪取側）の視点。動きは、動いたチーム自身の視点（Movement の約束どおり）。
- 手ごとの計算は次のとおり。

  | ターン | 側 | 計算 |
  |---|---|---|
  | 攻守 | 保持側 | `OpenPlayJudge.apply_attack(turn_start, 相手の方式, ball, choice)`。ドリブルの選手だけ。相手のマークの付け直しは除く |
  | 攻守 | 守備側 | `OpenPlayJudge.apply_defense(turn_start, 自分の方式, choice)` |
  | トランジション | 奪取側 | `TransitionJudge.judge(origin, …, choice, 即時奪回)` の自チームの動き（カウンターの飛び出し） |
  | トランジション | 喪失側 | `TransitionJudge.judge(origin, …, 保持, choice)` の自チームの動き（リトリート） |

- 選べるかどうかは見ない（呼び出し側が `MoveRules.is_allowed` で確かめる）。計算できなければ空。
- 入力の状態は書き換えない（使う関数はどれも写しを返す）。

## アプリケーション

### `MatchController.user_preview(user_choice) -> Array[Movement]`
- 利用者の視点の手を受け取る。
- 手をドメインの視点に直し、`MovePreview` で計算する。結果は `ViewConverter.movements_to_user` で、利用者の視点にして返す。
- 次の場合は空を返す。
  - 試合前（push_error）
  - 開示の確認待ち、進行段階が TURN でない、試合の後
  - 選べない手（push_error）

## UI

### TacticsBoard
- `show_preview(movements)`・`preview_movements()`・`preview_center(index)` を足す。`clear_overlays` で消す。
- 描き方は次のとおり。
  - 移動先は、自分の色の**輪（中抜きの ○）**にする。いまの位置の ● はそのまま残す。
  - 移動元のエリアの中央から輪へ、自分の色の**点線の矢印**（3px）を引く。
  - 開示後の動きの矢印は実線（4〜6px）。点線と中抜きで区別する。グレースケールでも形で分かる。
- 輪の位置は、移動先のエリアの自分の駒の列の続き。添字は「そのエリアの自分の駒の数 ＋ 同じエリアへの先の輪の数」で、`MAX_PIECES - 1` を上限にする。
  - 1エリアに5人以上が集まるのはまれなので、そのときは最後の位置で重なってよい。
- 方式の動きを描かない規則（`DRAWN_REASONS`）は、プレビューには当てはめない。プレビューは、その手で起きる自分の動きをすべて出す（リトリート・カウンターの飛び出しを含む）。
- 描く順: … 動きの矢印 → **プレビュー** → 意図の矢印 → 札 → 比較。

### MatchBoardPanel
- **運ぶ先を持つ手**
  - エリアを選んだら、`user_preview` の結果を `show_preview` に渡す。
  - ボールから運ぶ先への矢印（`show_intent`）は、ボールを運ぶ手（攻撃・奪取側）だけに出す。守備・喪失側では出さない。
- **運ぶ先を持たない手**: 手を選んだら、すぐにプレビューを出す。
- **手を選び直したとき**: プレビューを消す（`show_preview([])`）。
- **決定したとき**: `_submit` でプレビューを消す。開示（`clear_overlays`）・次のターン（`start_turn` の `clear_overlays`）でも消える。

### 選べる条件の一言（要求の機能3。入れる）
- `MatchTexts.target_rule(family, action)` を足す。
  - プレス: 「プレス: 隣のエリアの味方1人が、選んだエリアへ寄せる。隣に味方がいるエリアだけ選べる」
  - カバー: 「カバー: 味方1人が、選んだエリアの背後へ下がる。自陣の列と、その場にも隣にも味方がいないエリアは選べない」
  - ほかの手は空。
- SELECT_TARGET の間、運ぶ先の説明の欄（`TargetInfo`）に出す。エリアを選ぶと、エリアのヒントの説明に置き換わる。

## テスト
- `move_preview_test`（新設）
  - プレス・カバー（ゾーン／マンツーマン）・ドリブル・カウンター・リトリートの各場面。
  - 判定（`OpenPlayJudge.judge`・`TransitionJudge.judge`）で、相手が何もしない手を適用したときの自チームの動きと一致することを確かめる。
  - 期待値は手でも書く。
  - パス・シュート・保持・即時奪回は0件。
  - 入力の状態を書き換えない。
- `open_play_judge_test`: `apply_defense` の null（選べない手）と、judge の動作が変わらないこと（既存のテスト）。
- `match_controller_test`: 利用者が守備（AWAY 保持）のとき、利用者の視点に変換される。試合前・選べない手で空。
- `tactics_board_test`: プレビューの数・輪の位置（駒の列の続き・上限）・`clear_overlays` で消える。
- `match_board_panel_test`
  - エリアを選ぶとプレビューが出て、数がコントローラーの返す数と一致する。
  - 守備の手で意図の矢印を出さない。
  - 選び直すと消え、決定・次のターンでも残らない。
  - プレス・カバーで、選べる条件の一言が出る。

## 変更するドキュメント
- functional-overview.md（表示仕様）
- component-design.md（MovePreview・apply_defense・user_preview）
- screen-03-match.md・screen-common.md（TacticsBoard のプレビュー、選べる条件の一言）
- repository-structure.md（新しいファイル）。該当があれば glossary.md も直す。
