# コミット前レビューレポート

## 第1回（2026-11-07）
- 対象: 得点の3Dカットインの差分（新規 goal_cut_in・goal_cut_in_art・goal_stage_3d・goal_player_model、変更 match_board_panel・board_reveal・board_shift・tactics_board・match_controller・presentation_config(.gd/.tres)・config_repository・app_theme.tres、素材 assets/models/goal_cut_in・LICENSES.md・export_presets.cfg.example、テスト6本、docs/specs 11ファイル）。別セッションの phase-banner の変更は対象外
- 結果: Critical 0件 / High 0件 / Medium 4件 / Low 6件

## コミット前レビュー結果

対象: 得点の3Dカットインの差分（新規4スクリプト goal_cut_in.gd / goal_cut_in_art.gd / goal_stage_3d.gd / goal_player_model.gd、変更コード match_board_panel.gd / board_reveal.gd / board_shift.gd / tactics_board.gd / match_controller.gd / presentation_config.gd・.tres / config_repository.gd / app_theme.tres、素材の扱い（assets/models/goal_cut_in の .import・License.txt・kick_motion.json の先頭、LICENSES.md、export_presets.cfg.example）、テスト3本の新規分と3本の変更分、仕様書11ファイルの差分（grep で確認。screen-common / NFR / screen-03 は本文も読んだ））。ファイルの書き込み・Godot とテストの実行はしていない。

### Critical（即時対応必須）
- 指摘なし

### High（優先対応）
- 指摘なし

### Medium（対応推奨）
- [バグ/テスト] **キーパーのテストが描画に使っていない骨組みを検証していて空振りしている**: goal_cut_in_art_test.gd の L248〜289 の4本（`keeper_waits_on_the_goal_line…` / `dives_toward_the_corner` / `never_reaches_the_ball` / `lands_on_the_ground_and_stays_above_it`）は、すべて `GoalCutInArt.keeper_joints()`（独自の手足の長さ THIGH・UPPER_ARM などで組む解析上の骨組み）を見ている。実際の描画は `GoalPlayerModel`（Quaternius の体の骨）に `keeper_model_transform`・`set_motion`・`place_feet` を掛けたもので、体の寸法も置き方も別物。そのため「キーパーの指先がボールに届く」「着地で体が芝に沈む」が実物で起きても、テストは緑のまま通る。`skeleton()`・`keeper_joints()` は本番コードから呼ばれておらず、テストのためだけに残った旧実装。→ 届かない・地面の上の2つの性質は goal_cut_in_test.gd と同じく実物で測る（`_cut_in.play(...)` → `_set_progress(p)` → `keeper.transform * keeper.bone_position("hand_l"/"hand_r")` と ball の距離、着地は全骨の y）。解析上の骨組み（skeleton・keeper_joints と、それだけが使う定数）は消す。例:
  ```gdscript
  func test_the_keeper_never_reaches_the_ball() -> void:
      _cut_in.play(true, 1, 0, 2.0)
      for step: int in range(21):
          var p: float = lerpf(GoalCutInArt.BALL_START, GoalCutInArt.BALL_NET, step / 20.0)
          _cut_in._set_progress(p)
          var keeper: GoalPlayerModel = _cut_in.stage().keeper()
          for hand: String in ["hand_l", "hand_r"]:
              var at: Vector3 = keeper.transform * keeper.bone_position(hand)
              assert_float(at.distance_to(GoalCutInArt.ball_position(p))).override_failure_message("%s %s" % [p, hand]).is_greater(0.3)
  ```
- [運用/ライセンス記録] **CMU のモーションキャプチャの記録が「使い方の制限が無い」と言い切っている**: BVH 版の READMEFIRST の文言はそうだが、本家 mocap.cs.cmu.edu の FAQ には「製品に含めてよいが、データそのもの（変換した形でも）を再販してはならない」趣旨の条件があったと記憶している（Web で現行の文言は確かめていない）。kick_motion.json は変換したデータそのもので、リポジトリにもアプリにも入る。ゲームへの同梱は許される範囲のはずだが、記録が条件を落としていると、後でデータを単体で配る判断を誤らせる。→ 本家サイトの利用条件を確かめ、「再販しない」条件があれば LICENSES.md に1行残す（謝辞の文はすでに入っていて問題ない）。
- [性能] **初回の得点で止まりやすい**: `play()` の中で同期のまま、体のメッシュを GDScript のループで作り直し（`with_rest_positions`。選手とキーパーで2回）、2400人の観客の MultiMesh を組み、シェーダーを4種（KIT・ボール・ネット・空）初めてコンパイルする。Android の Compatibility レンダラーだと、NFR-02 の「0.5秒以上の停止なし」に触れうる。→ 作り直したメッシュは static にキャッシュして2回目以降の作り直しを無くす（素材は固定なので結果は毎回同じ）。可能なら試合開始時に一度だけ組んでおく（またはシェーダーを温める）。NFR-02 の実機計測項目に「初回の得点」を明示して入れる。
- [性能/メモリ] **SubViewport と素材が試合の間ずっと確保されたまま**: SubViewport（全画面・`stretch`・MSAA 4x）はパネルの `_init` で作られ、得点が無くても常に存在する。`UPDATE_WHEN_VISIBLE` は描画を止めるだけで、レンダーターゲット（4x MSAA の全画面バッファ）の確保は解かれない可能性がある。加えて `GoalPlayerModel` の `const preload`（gltf 2つと 1024px のテクスチャ群）は、MatchBoardPanel のスクリプトが読まれた時点で常駐する。NFR-24（512MB）に対する実測は未実施（未検証）。→ SubViewport（またはその `size`）を `play` で作り `_end` で消す（`size = Vector2i.ZERO` にする・コンテナごと `queue_free` するなど）。素材は `load()` で play のときに読む。

### Low / 改善提案
- [バグ] **kick_motion.json が壊れたときの影響が、試合画面の全体に及ぶ**: `const KICK_MOTION: JSON = preload(...)` は、JSON の構文が壊れていると読み込みに失敗し、スクリプトのコンパイルエラーになる。GoalCutInArt と、それを参照する GoalStage3D・GoalCutIn・MatchBoardPanel まで読めなくなり、試合画面ごと開けなくなる。ファイルは res:// に同梱する固定の素材で、利用者が書き換える経路は無く、テストが読み込みで落ちてコミット前に気づけるので Low。構文は正しくても形が違う場合（キーが欠ける・配列の長さが hips と違う）は、`kick_frame` が毎フレーム添字エラーになる。その場合は絵が止まるだけで、Tween は進むので `finished` が出て盤面は再開する（止まったままにはならない）。→ 全 `KICK_KEYS`・root・hips・chest・head の配列が同じ長さで、各要素が3要素（root は2要素）であることを確かめるテストを1本固定する。
- [運用] goal_stage_3d.gd の冒頭のコメントが「素材を使わず基本の形とシェーダーで組む」のまま。選手は Quaternius の素材に変わったので直す。
- [運用] ノード名に `"%s" % Vector3` や小数を入れている（`Mast(-16.0, 0.0, -38.0)`、`Post-3.66` など）。`.` と `:` は Godot が `_` に置き換えるだけで実害は無いが、番号の名前のほうが無難。
- [運用] UAL・UAL2 の zip に同梱の License.txt は置かず、Base Characters の分だけを `License.txt` として置いている。CC0 なので義務は無く、記録（LICENSES.md の表）で足りている。ただ、`License.txt` がどの素材の分かを、ファイル名か表で明示すると後で迷わない。
- [テスト] 時間で待つテスト（goal_cut_in_test の `ends_by_itself` の 250ms / 600ms、panel・board の `await_millis`）は負荷で揺れうる。いまの余裕で通るなら申し送りでよい。
- [運用] 新しいスイートは3Dの体を何度も組む（goal_player_model_test で約10回、goal_cut_in_test で約9回、観客2400人つき）。全体のテストが3分以内に収まるかは、この場では計っていない（未検証）。

### 問題なし
- **セキュリティ①（ハードコーディング）**:
  - 新規・変更コードに API の URL・キー・トークン・アカウント情報は無い。
  - URL は、第三者の License.txt（作者のサイト・Patreon・Discord）と、LICENSES.md の調達元の記録（itch.io・OpenGameArt・GitHub のリポジトリ名）にだけある。どれも公開の出典表示で、機密ではない。
  - 乱数の種 20261106 は観客の配置用で、秘匿値ではない。
  - 新しい設定値 `goal_cut_in_sec` は PresentationConfig（.tres）に外出しされている。データ層が範囲 0〜6 と有限かを検証し、範囲外・NaN・INF なら初期値に戻してエラーを出す。この挙動はテストで固定されている。
- **セキュリティ②〜④・OWASP**: 差分は認証・入力のエスケープ・ログ出力・外部通信・デシリアライズのどれにも触れていない。素材は res:// に同梱する固定のファイルで、利用者のファイルを読む経路は増えていない（A08 該当なし）。
- **盤面が止まったままになる経路が無いか**: 次の経路を追い、止まったままにならないことを確かめた。
  - `cut_in` の判定（GOAL かつ sec > 0）と、`_on_play_landed` の `play()` は同じ値を使う。sec はデータ層で有限が保証されるので、「wait を付けたのに play が false」は起きない。false なら `resume_shift` を呼ぶ。
  - 待つ前に再開が来たら、`_resumed` で `_wait` を素通りする（テストあり）。
  - `start_shift` の中で同期に着地しても、`_reveal` は先に代入済み。
  - start_turn・clear_overlays で `_reveal` が null の間に前のターンの着地が来ても、Tween ごと止めるので待ちが残らない。
  - `unbind`・`start_turn` での stop は、`finished` → resume → `show_snapshot` / `clear_overlays` で reveal を止める。`stop()` は `_waiting`・`_resumed` を戻す。
  - 押して飛ばす・自動で終わる・stop のどれでも、`finished` は1回だけ出る。play をやり直したときは古い分の `finished` を出さない（テストあり）。
  - 試合中のプレビューは BoardReveal を使わないので混線しない。
- **SubViewport の3D舞台の解放**:
  - `_end` は毎回 `_free_stage()`（queue_free）を呼び、`_build_stage` も先に前の舞台を消す。
  - 舞台の子（メッシュ・マテリアル・MultiMesh・髪のコピー）は、舞台ノードの下にあるか、参照で数えるリソース。外部への signal 接続は無い。
  - 髪の元シーンは `hair.free()` している。
  - 気になるのは、上の Medium（常駐するビューポートと preload）だけ。
- **テスト**:
  - goal_cut_in_test・goal_player_model_test・tactics_board・match_board_panel・config_repository のテストは、どれも実物の値で性質を確かめている（実物の骨でボールに当たる足、軸足の位置、2拍目で止まって再開、0・上限・範囲外・NaN・INF）。
  - 恒真なアサーションは無い。
  - test_the_stage_follows_the_progress は期待値を `GoalCutInArt` の関数から取っているが、舞台への結線を確かめる目的なので妥当。
- **書き出し**: include_filter に `assets/models/*/*.json` を足しており、kick_motion.json が書き出しから漏れない。gltf・png・res は .import 経由で入る。
- **ライセンス（Quaternius）**: 素材ごとに、調達元・バージョン（取得日）・作者・手を加えたこと（テクスチャの縮小、動きの抜き出し、cm → m）が記録され、CC0 の原文も同梱している。
- **仕様書**: カットイン、wait/resume、テーマの色、NFR-02 の計測項目、3D の舞台の扱いが、screen-common・screen-03・NFR などに反映されている。差分に機密は無い。

### 未検証
- CMU の本家サイトの現在の利用条件の文言（Web は参照していない）。
- バイナリ素材（gltf・bin・png・animations.res）の中身そのもの。見たのは扱いと記録だけ。
- Android 実機での FPS・停止時間・メモリ（NFR-02・NFR-24）、Compatibility レンダラーでの MSAA・霧・影の見え方。
- テストが実際に緑になるか、全体が3分以内か（指示どおり実行していない）。
- docs の drawio は差分の行数（1行）だけを見て、図の中身は確認していない。

### 総合評価
**Critical / High の指摘は無い。コミットしてよい。**

近いうちに直すことを勧めるのは次の3点。
- キーパーのテストの空振り（いちばん実害に近い）
- CMU の利用条件の記録の精度
- 初回の得点での止まりと、常駐するビューポートのメモリ

Low のうち kick_motion.json の形を確かめるテストは、欠陥を検出する手段なので、申し送るなら先にテストを固定すること。

### 対応
- **Medium: キーパーのテストの空振り** → 直した。
  - 解析上の骨組み（`skeleton`・`keeper_joints`）と、それだけが使う体の寸法の定数を消した。
  - キーパーの4本は goal_cut_in_test へ移し、描く体の骨で測る形にした。
    - 構え: 腰が立ったときより 0.1 m 以上低く、足が地面に着いている。
    - 跳ぶ: 手が -z へ 1 m 以上伸び、足が地面を離れる。
    - 届かない: 両手がボールから 0.3 m 以上離れている。
    - 沈まない: どの時刻もどの骨も芝の下 3 cm より上。
  - 実物で測ったら、2つの欠陥が見つかったので直した。
    - 着地の後、左手の骨が芝の下 11.5 cm に沈んでいた → `KEEPER_LAND` の高さを 0.2 から 0.33 にした。
    - 構えで、つま先立ちになっていた（足首の角度をすねからの差で決めるので、すねが前へ傾くぶんつま先が下がる）→ 構え・踏み込みの姿勢に、足の裏が平らになる足首の角度（`FOOT_FLAT`）を入れた。
  - 変異（着地を元の高さに戻す・つま先立ちに戻す）で、それぞれのテストが落ちることを確かめた。
- **Medium: CMU の利用条件** → 直した。本家の利用条件（mocap.cs.cmu.edu）を検索で確かめた。「製品に含めてよいが、データそのものを変換した形でも単体で売ってはならない」とあった。LICENSES.md にこの条件と、単体で配らないことを書いた。
- **Medium: 初回の得点での止まり** → 一部を直した。
  - 体の形の作り直し（`with_rest_positions`）は static にキャッシュし、2回目以降の得点では作り直さない。
  - シェーダーの温めと、試合開始時に組んでおくことはしない。待たない演出（押せば飛ばせる）で、まず実機で測ってから決める。
  - NFR-02 の測り方に「アプリを起動して最初の得点を必ず含める」と書いた。
- **Medium: 常駐するビューポートと素材** → ビューポートは直した。
  - 出していない間は `SubViewportContainer.stretch` を切り、描く先の画を 2×2 にする。play で広げる。
  - テスト（出していない間は最小・出している間は全画面・止めたら最小に戻る）を足した。変異で落ちることも確かめた。
  - 素材の `preload` はそのままにした。
    - `load` に替えると、初回の得点で読む分だけ止まりが増える（上の指摘と相反する）。
    - テクスチャは 1024px 以下で計 4.5MB と小さく、NFR-24（512MB）の余裕は大きい。
    - 実機のメモリは NFR-24 の計測で確かめる（申し送り）。
- **Low: kick_motion.json の形** → 直した。同梱の記録の形（各キーが同じ長さ、向きは3つ・腰の位置は2つの数、インパクトの番号が並びの中）を確かめるテストを足した。
- **Low: goal_stage_3d.gd の冒頭のコメント** → 直した（選手は外部の素材の体）。
- **Low: ノード名の小数** → 直さない。Godot が `_` に置き換えるだけで、名前で引いていない。
- **Low: License.txt がどの素材の分か** → 直さない。LICENSES.md の表に「`License_Standard.txt` を `License.txt` として置いた」と書いてある。
- **Low: 時間で待つテスト** → 直さない。いまの全体実行（1270件・146秒）では揺れていない。揺れたら直す。
- **Low: 全体のテストの時間** → 計った。直す前の全体実行は 1270件・146秒で 3分以内。直した後も、コミットの前に全体を流して確かめる。

## レビュー完了（2026-11-07）
- 最終ラウンド: 第1回（Critical / High が無かったので、再レビューのループは回していない）
- 新たな Critical / High: なし
- 積み残し:
  - 初回の得点での止まりと、メモリ（NFR-02・NFR-24）を Android の基準端末で測る。いま検出するテストは無い（実機の計測項目）。
  - ノード名の小数。実害なし。
