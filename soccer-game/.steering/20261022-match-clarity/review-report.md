# コミット前レビューレポート

## 第1回（2026-10-22）
- 対象: 未コミットの差分すべて（`.steering/20261022-move-preview/` は別作業のため除く）。保持者を置く・CPU の方式の癖と設定値・作戦ボードのシンプル案・テスト・仕様書・ステアリング
- 結果: Critical 0件 / High 0件 / Medium 1件 / Low 4件
- 注: レビュー役（opus）の返答をそのまま記録する。ローカルの絶対パスは含まれていない（検索した文字列の種類だけを書いている）

## コミット前レビュー結果

対象: 未コミット差分すべて（`.steering/20261022-move-preview/` は除く）。内訳は次のとおり。
- 変更 24 ファイル: game/domain・game/config・game/data・game/ui・game/tests・docs/specs
- 新規: game/tests/domain/match/ball_holder_invariant_test.gd（と .uid）、.steering/20261022-match-clarity/ の 3 ファイル

**結論: Critical / High の指摘はありません。**

### Critical（即時対応必須）
- なし

### High（優先対応）
- なし

### Medium（対応推奨）
- **[バグ] 最小のセル幅では駒が隣のエリアにはみ出す（game/ui/board2d/tactics_board.gd `_draw_pieces`）**
  - 1 チームの駒は中央から最大 `PIECE_STEP*0.5 + 6 + 3*PIECE_STEP + 半径13 = 117px` まで広がります。セルの半幅として 117px 以上が要ります。
  - `MIN_CELL.x = 192`（半幅 96px）では、4 つ目の駒（または「+N」）が左右の隣のエリアに約 21px 食い込みます。
  - 基準の 16:9（セル幅約 242px、半幅 121px）では収まります。小さいウィンドウや最小サイズまで縮めた場合だけ起きます。
  - ここで起きると、FR-16（人数をエリアの中の ● ◆ の数で読む）が誤読される可能性があります。
  - `MIN_CELL` のコメント「幅は両チームの駒を4つずつ横に並べる分」も実際の値と合っていません。
  - 修正は次のどちらかです。
    - `MIN_CELL` を `Vector2(240, 112)` 程度に上げる（screen-common.md §1.1 の最小幅も合わせる）。
    - 間隔をセル幅から求める。例: `var step: float = minf(PIECE_STEP, (rect.size.x / 2.0 - 6.0 - radius) / (MAX_PIECES - 0.5))`。
    - 判定に使う値（例: 駒の中心の x の範囲を返す関数）で、最小セル幅でもはみ出さないテストを先に固定することを推奨します。

### Low / 改善提案
- **[運用/ドキュメント] screen-common.md の古い記述**
  - 作戦ボードの最小の大きさの行（§1.1 の表）に、「高さは、上端の帯 32px ＋ 駒 40px × 2段」が残っています。
  - 帯と 2 段の駒は今回の差分で無くなったので、根拠の記述を新しいレイアウト（上段にボール・中段に駒の列・下段に札）に直してください。
- **[運用/ドキュメント] .steering の design.md とコード・仕様の数値違い**
  - design.md: 「`lane_size` を 14 に下げ」
  - コードとテーマ: `lane_size = 16`、仕様書も 16px
  - どちらかに揃えてください（実害なし）。
- **[バグ（将来）] 実際には起きない BALL_HOLDER がターン記録に残る**
  - `resolve_turn` は HALFTIME・試合終了・GOAL（STYLE_CHANGE）のターンでも `_place_holder` を呼び、その動きをそのターンの記録に足します。
  - HALFTIME と試合終了の配置は、`apply_halftime` の再導出か試合の終了で捨てられます。それでも記録には「ボールへ寄った選手」の動きが残ります。
  - 2D 盤面は描かないので、いまは実害がありません。3D 演出や振り返りでこの記録を描くときに、架空の動きになりえます。
  - 申し送りにするか、次のどちらかにしてください。
    - `next.stage == HALFTIME` と `is_play_complete` のときは記録に足さない。
    - 3D 側が理由で扱いを分けることを design に明記する。
- **[バグ] `_stop_dribble` の `before` / `carrier` の null 確認が無い**
  - 運んだ選手は保持側の選手なので、通常は null になりません。
  - `_player_of` が null を返す経路を作っているので、防御的に `if before == null or carrier == null: continue` を足すと安全です。

### 問題なし
**セキュリティ①（ハードコーディング/シークレット）**
- 対象は差分全体、新規ファイル、.steering/20261022-match-clarity/*.md、docs/specs の差分です。次の語を grep し、該当はありませんでした。
  - URL（http/ws）
  - `arn:`・`amazonaws`・12 桁の数字
  - api key・secret・token・password・hmac
  - メールアドレスの形
  - ドライブ文字付きのパス・`/Users/`・`/home/`・ユーザー名
  - claude.ai・artifact
- 1 件だけ一致しましたが、Godot のリソースパス `res://config`（requirements または tasklist 内の既存の記述の引用）で、問題ありません。
- `.uid` は `uid://...` の Godot の識別子です。

**秘密ファイル**
- `game/export_presets.cfg`、署名鍵（.keystore/.jks/.p12/.pem）、`.env` は差分にありません。

**不可視文字**
- 対象の 29 ファイルを UTF-8 で読み、次のものを確かめました。いずれもありませんでした。
  - 制御文字（NUL を含む）
  - 行の途中のタブ
  - ゼロ幅文字・双方向制御文字・BOM・NBSP
- CRLF は screen-common.md と team_layout.gd の 2 ファイルにあります。どちらも HEAD の時点で CRLF で、今回の行も揃っています（混在なし）。

**セキュリティ②〜④・OWASP**
- 認証・認可、インジェクション、外部通信、永続化の変更はありません（オフライン単体ゲーム）。
- `ConfigRepository` の push_error は設定値（数値）だけを出していて、機密はありません。
- 範囲外の値は fail-closed で初期値に戻ります。`style_bonus` の負・NaN・INF もテストで固定されています。
- `CpuPlanner.probabilities` は、点数が非有限なら一様分布にするので、加点が異常な値でも壊れません。

**バグ・正しさ**
- `_is_preferred` の `is_x == (action == Y)` について。DefenseAction・NegTransAction・PosTransAction はどれも 2 値の enum なので、表と正確に一致します。
  - 「前へのドリブル」は `Zone {D, M, A}` の順で `target.zone > ball.zone` と判定しています。正しいです。
- `_stop_dribble` は、判定を `output.pair` で行い、そのあと固定だけを判定前に戻します。`pair_at_judgement` は変えていません。
  - テストで、判定の人数・前の固定を保つこと・ADVANCE では戻さないことを確かめています。
- `_place_holder` について。
  - 距離はゾーン差＋レーン差で、同じ距離なら `<` により配置の順で先の選手を選びます。順を入れ替えるテストがあります。
  - トランジションは `transition_origin.attacker` と `players_of(possession)` の両方を更新します。`with_fixed` は deep copy です。
- MovementReason は末尾に足しているので、既存の値の番号は変わりません。製品コードで理由に応じて分岐しているのは tactics_board だけで、新しい値を描かないことをテストで固定しています。
- 不変条件のテストは、20 試合・固定シードで回しています。STYLE_CHANGE・HALFTIME・create_match 直後を含み、確かめた回数の下限も検査しているので、空振りしません。
- tactics_board のテストは、描くかどうかを決める値（`drawn_movements`・`drawn_hint_keys`・`is_hint_even`・駒の数と人数の一致）を検証しています。恒真テストではありません。
- match_board_panel は ±0 を `hint.diff()` で判定しています（札の文字列から推し量っていない）。

**性能**
- `_place_holder` は 1 ターンに `turn_start` を 1 回足すだけで、10 人・15 エリアの固定サイズです。
- `drawn_movements()` は `_draw` のたびに配列を作りますが、要素は十数件なので無視できます。

**運用**
- 新しい設定値 `style_bonus` は cpu_config.tres に外出しされています。範囲の検査と、範囲外のとき初期値に戻すことも定義済みです。
- 仕様書（アルゴリズム 5・7・8、設定値の一覧、表示仕様、画面設計・詳細設計、データ定義）に反映されています（上の Low の 1 行を除く）。
- 不可逆な変更はなく、revert で戻せます。

### 未検証
- テストは実行していません（依頼元の結果「453 件成功、終了コード 0」に依拠）。
- 描画の見た目（重なり・はみ出し）は実機やスクリーンショットで確かめていません。Medium の指摘はコードの値からの計算です。
- 中断・再開（保存データ）と、新しい MovementReason の互換性は見ていません。保存は今回のスコープ外です。
- docs/specs の差分は、機密情報と記述の整合の観点で抜き出して見ました。全文の精読はしていません。

### 総合評価
**Critical / High はありません。コミットしてよいです。**
Medium（最小のセル幅で駒がはみ出す）は、`MIN_CELL` の見直しか、間隔をセル幅から求める修正を推奨します。今回直さないなら、検出するテストを固定したうえで申し送ってください。

### 対応
- Medium（最小のセル幅で駒がはみ出す）: 直した。駒の間隔と半径をセル幅から求める `piece_step()`・`piece_radius()`・`piece_center()` を足し、描画とテストで共有した。基準の 16:9 では間隔 28px・半径 13px のまま（見た目は変わらない）。基準の大きさと `MIN_CELL` の大きさの両方で、4つの駒がエリアの自分の側の半分に収まり、重ならないことをテストで固定した。間隔を固定値に戻す変異で、このテストが落ちることを確かめた。
- Low（screen-common.md §1.1 の古い根拠）: 新しい並べ方の根拠に書き直した。
- Low（design.md のレーン名 14px）: 実装（16px・色は薄くしない。NFR-21 のため）に合わせて直した。
- Low（起きない BALL_HOLDER が記録に残る）: 直した。`resolve_turn` は、ハーフタイムと試合の終わりでは保持者を置かない。前半の最終ターンの得点で記録に BALL_HOLDER が残らないことを、テストで固定した。条件を外す変異で、このテストが落ちることを確かめた。不変条件のテストは、ハーフタイムの時点を確かめないように合わせた。
- Low（`_stop_dribble` の null 確認）: 直した。見つからなければ何も戻さない。

### 実装レビュー（review-implementation、opus）の結果と対応
- 総合 4.6/5、[必須] 0件。規約（coding-gdscript・coding-common・testing）は、時間を詰めるため、レビュー役が `get_rule` で取得した（スキルの手順では依頼元が本文を埋め込む。取得できなかった場合に「コード品質は未検証」と報告させる指示を付けた。3つとも取得できた）。
- [推奨] 最小のセル幅で駒が収まらない → 上の Medium と同じ対応。
- [推奨] glossary.md・screen-common.md に「優劣記号で示す」が残っている → 直した。
- [推奨] FR-16 の本文と新しい表示の対応 → requirements-definition.md の FR-16 に、作戦ボードでは形の違う駒の数で区別するという注記を足した。NFR-20 のグレースケールでの確認は、シャビの PC での確認とあわせて行う（申し送り）。
- [推奨] 距離の計算が2か所にある → `PitchArea.distance_to` に1つにまとめ、アルゴリズム2のマーカーの選び方と保持者の選び方の両方から使う。テストを足した。
- [推奨] design.md と実装の軽い相違 → レーン名の記述と、CPU の値の目標を事前に決めず実測で判断したことを書いた。
- [提案] 後ろへのドリブルが加点の対象外であること → テストの表に1行足した。
- [提案] `DRIBBLE_STOPPED` の移動先の前提 → `_stop_dribble` にコメントを足した。
- [提案] `turn_probabilities` の用途 → 変更なし（状態を変えない問い合わせで、`choose_turn` と同じ計算を通る）。

#### 対応の結果
- テストは 455 件・38 スイートすべて成功、終了コード 0。
- 再レビューはしない。Critical / High の修正ではないため（スキルの規則: Medium / Low はループを回す理由にならない）。

## レビュー完了（2026-10-22）
- 最終ラウンド: 第1回
- 新たな Critical / High: なし
- 積み残し: なし（Medium・Low はすべて直した）。NFR-20 のグレースケールでの確認は、シャビの PC での確認とあわせて行う。
