# 画面詳細設計書: 画面共通の決めごと

> 画面一覧・画面遷移の正本は [`functional-overview.md`](../../1_requirements/functional-overview.md)「画面設計」、
> 各画面の外部設計（レイアウト・項目・イベント）は [`screen-design.md`](../../2_basic-design/screen-design.md)、
> クラスとメソッドの形は [`component-design.md`](../../2_basic-design/component-design.md)。
> 本書は、各画面の詳細設計書（`screen-NN-*.md`）が前提にする**画面をまたいだ実装の決めごと**を置く。
> 各画面の設計書はここを繰り返さない。

## 1. 基準解像度と寸法の単位

Godot の画面の拡大縮小は、プロジェクト設定で次のようにする。

| 設定 | 値 | 理由 |
|---|---|---|
| `display/window/stretch/mode` | `canvas_items` | 文字と線を、端末の解像度でくっきり描くため |
| `display/window/stretch/aspect` | `keep_height` | 高さを 720px に固定し、アスペクト比 16:9〜21:9（NFR-25）の差は横の長さで吸収するため（横に長い端末ほど幅 1280〜1680px に広がる。§1.1） |
| 基準解像度 | 1280 × 720（横向き） | 高さ 360dp の端末で 1dp = 2px になる。MVP は Android の横向きだけ（要件定義書 §6.1）。後続マイルストーンの Windows 版も同じ基準解像度を使う |
| `display/window/handheld/orientation` | `sensor_landscape`（Android） | 横向きだけにする（NFR-25）。端末を左右どちらに倒しても正しい向きで表示する |

**本書と各画面の設計書の寸法は、すべて基準解像度上の px で書く。** dp との対応は Android の基準で 1dp = 2px。

### 1.1 画面の基本の配置（横向き）

`screen-design.md`「画面の向きと基本の配置」の「上にヘッダー、左に本体、右に操作の列」を、次の寸法で組む。

| 部分 | 寸法 | 備考 |
|---|---|---|
| ヘッダー | 高さ 96px。幅は画面いっぱい | 試合中の画面では、中継風のスコア表示（`ScoreBug`）と局面のタグを兼ねる。両チームの陣形・方式は操作の列の上端に置く（S-03） |
| 操作の列（右） | 幅 480px（16:9）。横に長い端末では広げ、上限 640px | 選択肢・解説・主ボタン。主ボタンは列の下端に置く。中身が入りきらない画面は列の中を縦にスクロールする |
| 本体（左） | 残りの幅（16:9 で 728px、21:9 で 968px）。高さ 576px | 作戦ボード・ミニピッチ・一覧など。作戦ボードは本体いっぱいに広げ、縦横比は固定しない（ピッチの白線はボードの大きさに合わせて描く） |
| 余白 | 外周と、本体と操作の列の間に 24px | — |

- 端末の切り欠きは横向きでは左右に来るため、`DisplayServer.get_display_safe_area()` で安全な範囲を求め、左右の余白に足す（`MainShell` が画面のルートの余白として設定する。各画面は意識しない）。左右には同じ余白（大きい方）を当てる。横向きのまま 180° 回すと切り欠きは反対側へ移るが、ビューポートの大きさが変わらず、余白を当て直すきっかけが無いため
- 本体と操作の列を持たない画面（S-10・S-12 など）も、ヘッダーの高さと外周の余白は同じにする
- ヘッダーの中身は 16:9 で使える幅（1232px）に収める。いちばん長くなる文言（局面のタグ `NEG.TRANSITION ネガティブトランジション`、手と運ぶ先「サイドチェンジ → 攻撃・右ハーフスペース」など）で確かめ、可変の文言の `Label` には `text_overrun_behavior = ELLIPSIS` を付ける（全文は操作の列などで読めるようにする）
- 操作の列は「上端の固定部分 → 縦にスクロールする中身 → 下端の主ボタン（固定）」の3段にする。中身が入りきらないときも、主ボタンと上端の固定部分は動かない
- 16:9 より縦長の端末（4:3 のタブレットなど）は NFR-25 の範囲外とし、Google Play の対応端末の設定で配布の対象から外す（横幅が 1280px を下回り、1エリアの最小の幅を割るため）

| 用途 | 最小の大きさ | 根拠 |
|---|---|---|
| ボタン・選択肢など、押せるものすべて | 高さ 96px（48dp）以上、幅 96px 以上 | NFR-19 |
| 作戦ボードの1エリア | 画面でいちばん小さい奥の行（敵陣）でも、幅・高さ 96px（48dp）以上（NFR-19）。平面図（縦向きのピッチを真上から見た図）の1エリアで幅 136px・高さ 140px 以上（`TacticsBoard.MIN_CELL`。奥では幅が 0.72 倍、高さが約 0.73 倍になる）。駒の間隔と大きさは、セルの幅に合わせて縮め、1チーム 2列×2段がエリアの半分に収まるようにする。基準の 16:9 で、平面図の1エリアは約 145×192px。横に長い端末ほど幅が広がる（2026-10-23 に縦向きの盤面へ変えた） | `screen-design.md`「共通の部品と操作」 |
| 画面の外周の余白 | 24px。これに端末の切り欠き（カメラの穴など）の分を足す（§1.1） | `screen-design.md`「画面の向きと基本の配置」 |

## 2. フォント・文字

見た目の方向性（スタジアム中継風）の正本は `screen-design.md`「ビジュアルの方向性」。フォントの同梱・サブセット・
ライセンスの扱いの正本は `architecture-overview.md`（テクノロジースタックの注記）。ここでは画面で使う割り当てだけを決める。

| 書体 | 太さ | 使うところ |
|---|---|---|
| Noto Sans JP | Regular・Bold | 日本語の本文・ボタン・判定理由・解説 |
| Barlow Condensed | SemiBold・Bold | スコア・残りターン・局面のタグ（`ATTACK` など）・`KICK OFF`・結果のラベル（`ADVANCE` など） |

- ボールは文字ではなく画像（アイコン）で描く（絵文字はフォントに含まれず、端末で見た目が変わるため）
- 記号 `▲`・`＝`・`▼`・`●`・`◆`・`−` は Noto Sans JP で描く（サブセットに必ず含める）
- 文字の大きさ（基準解像度上の px）

  | 用途 | 大きさ |
  |---|---|
  | 本文・ボタン | 28〜32px |
  | 補助・注記（凡例・「実戦では」） | 24px（これより小さくしない。下の作戦ボードの2つだけ例外） |
  | 作戦ボードのレーン名・ヒントの札（`+1`・`±0 カバーあり`） | 16px・18px（例外。盤面の情報を絞るため、駒より目立たせない。2026-10-22。コントラスト比は NFR-21 を満たす色にする） |
  | 局面のタグ・比較エリアの札（`1対0`） | 26px（Barlow Condensed Bold） |
  | スコア | 52px（Barlow Condensed Bold） |
  | 結果のラベル（`ADVANCE`）・`KICK OFF` | 44px（Barlow Condensed Bold） |
  | 勝敗（S-06） | 96px（Barlow Condensed Bold） |

## 3. 配色

テーマ（`game/ui/common/theme/app_theme.tres`）に色を定義し、各画面は色を直接書かない。チームの色と全体の方向性は
`functional-overview.md`「表示仕様」（利用者 = 水色、CPU = オレンジ、暗い地、黄色の強調）に従う。

**文字と地**（文字は 4.5:1 以上、24px 以上の大きな文字は 3:1 以上。NFR-21）

| 名前 | 色 | 主な地とのコントラスト比 | 用途 |
|---|---|---|---|
| `bg` | `#070D18` | — | 画面の地（夜のスタジアム） |
| `surface` | `#101827` | — | カード・パネル・帯の地 |
| `text` | `#F8FAFC` | 18.6（`bg`）／17.0（`surface`） | 本文 |
| `text_sub` | `#CBD5E1` | 13.1（`bg`） | 補助の文字 |
| `muted` | `#94A3B8` | 7.6（`bg`）／6.9（`surface`） | 注記・凡例 |
| `accent` | `#F5C518` | 11.9（`bg`） | 強調（主ボタン・選んだエリア・タグ・札）。上に載せる文字は `bg` の色（11.9） |
| `you` | `#4CC3FF` | 9.8（`bg`） | 利用者のチームの色 |
| `opponent` | `#FF8A3D` | 8.3（`bg`） | CPU のチームの色 |
| `caution` | `#FBBF77` | 10.9（`surface`） | 「実戦では」 |
| `telop_bg` / `telop_text` / `telop_sub` | `#F8FAFC` / `#070D18` / `#334155` | 18.6 ／ 9.9 | 判定理由のテロップ（白地に暗い文字） |
| `disabled_bg` / `disabled_text` | `#1E293B` / `#94A3B8` | 5.7 | 選択不可のボタン。「選択不可」の文字を添え、色だけで示さない |

**ピッチと駒**（駒・矢印など文字以外の図形は、隣り合う色と 3:1 以上。WCAG の非テキストのコントラストの目安）

| 名前 | 色 | 駒とのコントラスト比 | 用途 |
|---|---|---|---|
| `pitch` | `#165C34` | 自分 4.0 ／ 相手 3.4 | ピッチの地（芝目の暗い側） |
| `pitch_stripe` | `#18623A` | 自分 3.7 ／ 相手 3.2 | 芝目の明るい側 |
| `pitch_halfspace` | `#134E2D` | 自分 4.9 ／ 相手 4.2 | ハーフスペースのレーン |
| `pitch_line` | `#F8FAFC`（不透明度 80%） | — | 白線 |
| `zone_line` | `#F8FAFC`（不透明度 25%、点線） | — | 15エリアの境界 |
| `tag_muted_bg` | `#0B111C`（不透明度 70%） | — | 差が ±0 のヒントの札の地。文字は `text`（差がある札は `accent` の地に `bg` の文字） |
| `ball_area_fill` | `#FFFFFF`（不透明度 10%） | — | ボールのあるエリアの薄い塗り |
| `lane_text` | `#CBD5E1` | 5.4（`pitch`） | レーン名 |

- 駒は、利用者が丸（●）、相手がひし形（◆）で、色に加えて形で区別する。チームを文字で示す帯なども ●・◆ を使う
- 優劣は、作戦ボードではエリアの中の ●・◆ の駒の数（形で区別）で、ミニピッチでは記号（`▲`・`＝`・`▼`）で示し、色は補助にする。グレースケールでの確認は NFR-20 の手順で行う
- `pitch` 系の色は、駒の色（`you`・`opponent`）との比が 3:1 を下回らない範囲で調整する。値を変えたら本表の比を計算し直す

## 4. 画面の出入りの約束

すべての画面のルートは `Control`（全面に広げる）で、`component-design.md` §5.2 の `class_name` を持つ。
`MainShell` は画面を入れ替えるときに、次の順で呼ぶ。

```gdscript
## 画面を開く。params は App.screen_requested の params（画面ごとの意味は各画面の設計書）
func enter(params: Dictionary) -> void
## 画面を閉じる直前に呼ぶ。enter でつないだシグナルをすべて切る
func exit() -> void
## Android の戻る操作（NOTIFICATION_WM_GO_BACK_REQUEST）を MainShell から受ける。処理したら true
func handle_back() -> bool
```

- `App` のサービスのシグナルは `enter` でつなぎ、`exit` で必ず切る（閉じた画面がシグナルを受けて動くのを防ぐ）
- 画面は開くたびに、表示する値を `App` のサービスから取り直す（前に開いたときの値を持ち越さない。
  `screen-design.md` の各画面のイベント表「画面を開く」）
- `handle_back` が `false` を返したら、`MainShell` は既定の動き（タイトルではアプリを閉じる）をする

### 4.1 入力の扱い（タッチとマウス）

開発中の動作確認は PC のウィンドウで行う（2026-10-18 決定。`repository-structure.md`「動作確認の方法」）。
Android のタッチと PC のマウスで同じ処理が動くように、入力は次の形で受ける。後続マイルストーンの Windows 版でもそのまま使える。

- **押す操作は、部品のマウスのイベントで受ける**: `InputEventScreenTouch` を直接扱わない。Godot の既定
  （`input_devices/pointing/emulate_mouse_from_touch` が `true`）で、Android のタッチはマウスのイベントとしても届くため
  - ボタンは `Button.pressed` で受ける
  - 作戦ボードのエリア（`AreaCell`）は `gui_input` の `InputEventMouseButton`（左ボタン・`pressed == false`）で受け、
    離した位置がセルの内側（`Rect2(Vector2.ZERO, size).has_point(event.position)`）のときだけ選んだとみなす。
    押したセルが離すまでマウスを受け続けるため、この判定が無いと、取り消すつもりで指を外へずらして離しても選ばれてしまう
    （`Button` は同じ判定を内部で持つ）
- **`input_devices/pointing/emulate_touch_from_mouse` は有効にしない**: マウスのイベントにタッチのイベントが加わって、同じ操作が
  二重に届くおそれがあるため
- **戻る操作**: `MainShell` は、Android の戻る操作（`NOTIFICATION_WM_GO_BACK_REQUEST`）と PC の Esc キーを、どちらも表示中の画面の
  `handle_back()` へ渡す
  - `application/config/quit_on_go_back` は `false` にする（`project.godot`）。既定の `true` のままだと、`handle_back()` の戻り値に
    関係なく、Android の戻る操作で Godot がアプリを閉じてしまう。アプリを閉じるのは、`handle_back()` が `false` を返したときに
    `MainShell` が `get_tree().quit()` を呼ぶ経路だけにする
  - Esc は `MainShell._unhandled_input` で `event.is_action_pressed("ui_cancel")`（キーのリピートは受けない。既定の
    `allow_echo == false` のまま）として受け、処理したら `get_viewport().set_input_as_handled()` を呼ぶ。開いている
    ダイアログが先に `ui_cancel` を受けたときは、`MainShell` まで届かない
  - Android の戻る操作は `ui_cancel` ではなく通知で届くため、開いているダイアログを経由せず、直接 `handle_back()` に来る。
    ダイアログを開いている画面は、`handle_back()` でダイアログを閉じるところまで受け持つ（S-01 の `CONFIRMING` など）
  - タイトルで戻る操作をしたときの既定の動き（アプリを閉じる）は、Android と PC で同じにする
- **ホバーとフォーカスの表示は出さない**: タッチには無い状態のため（フォーカスの枠もタップ後に残る。キーボードでの操作は Windows 版の範囲）。Godot の `Button` はテーマに `hover` のスタイルを既定で持つうえ、Android では
  タップした位置にマウスが残ってホバーの見た目のままになる。そこで、テーマの `hover`（と `hover_pressed`）は `normal`（と `pressed`）と
  同じスタイルにする。マウス向けの表示は Windows 版の範囲（要件定義書 §6.2）

## 5. 画面をまたいで使う部品

`component-design.md` §5.3〜§5.5 の部品のうち、複数の画面の設計書が前提にする外から見た形をここに置く。

| 部品（`class_name`） | 外から渡す値 | 出すシグナル | 備考 |
|---|---|---|---|
| `TacticsBoard` | `show_snapshot(snapshot: BoardSnapshot)`、`set_selectable(areas: Array[String])`、`set_hints(hints: Dictionary, even_keys: Array[String] = [])`、`show_intent(from_area: String, to_area: String)`、`show_movements(movements: Array[Movement])`、`show_preview(movements: Array[Movement])`（決定前のプレビュー。自分の選手の動き）、`start_shift(user_before: Array[Dictionary], opponent_before: Array[Dictionary], ball_before: String, duration_sec: float)`（開示で、判定前の配置からいまの盤面へ、位置が変わった全選手の駒と、ボール（判定前のエリアが違うときだけ）を一緒に動かす。動いている間は駒を選手ごとに描き「+N」の札は出さない。そのため5人以上いるエリアでは、動いている間だけ4人目以降の駒が最後の位置で重なる（既知の制約）。エリアが同じでも、列の位置が変わった駒は動かす。次の `show_snapshot`・`clear_overlays` で止まる）、`show_compare(area: String, user_count: int, opponent_count: int)`、`show_tally(tally: Dictionary)`（振り返りの集計の札。駒は出さない）、`clear_overlays()` | `area_pressed(area_key: String)` | ピッチを縦に置いて斜めから見せ（半3D）、利用者の攻撃方向は常に上（上から A・M・D のゾーン、左から L2・L1・C・R1・R2 のレーン。2026-10-23 に横向き・右から変えた）。位置は平面図の座標で持ち、`BoardProjection` の写し方（奥 = 上を狭く・縦を詰める。奥の縮み 0.72）で画面に描く。押した点は逆の写し方で平面図へ戻してエリアを引く（`area_at`。平面図の点は `plan_area_at`）。描き方: ①ピッチ（`pitch` 系の色・白線・センターサークル・上下のペナルティエリアとゴール）②ボールのあるエリアの薄い塗り（`ball_area_fill`）・選んだエリアの塗り・選べるエリアの点線の枠 ③15エリアの点線とレーン名（自陣（手前の行）の各エリアの左上に 16px）④矢印（ボール＝`accent` 太線、寄せ・カバー＝`opponent` か `you` の実線。方式の動きと保持者の動きは描かない）、選んだ手の矢印（ボールを運ぶ手だけ）、決定前のプレビューの点線の曲線の矢印（`you`・3px。理由で絞らない） ⑤立っているもの（`standing_order()` の順に、奥から手前へ。手前の駒が奥の駒に重なる）: 駒（`BoardSnapshot.user_players` / `opponent_players` から、番号なしで描く。チェスのような立体の駒で、自分はポーンのような丸い頭・相手はビショップのようなとがった頭。影・台座・胴・首の輪・頭で描き、奥ほど小さい。自分はエリアの左半分、相手は右半分に、2列×2段。各チーム5人以上いるときは、駒を3つと「+N」の札（`tag_muted_bg` の地）にする）、決定前のプレビューの駒（移動先に自分の駒を半透明で立てる。移動先のエリアの自分の駒の並びの続きに置き、最後の位置で止める。自分の駒が5人以上いるエリアへの移動では「+N」の札に重なる。まれで判定に影響しないため、既知の制約とする）、ボール（エリアの上側の中央に、少し浮かせて地面に影を落とす） ⑥ヒントの札（選べるエリアの下端の中央に 18px。差がある札は `accent`、±0 の札は `tag_muted_bg`。駒と矢印の上に描いて字を隠さない）⑦比較エリアの光と人数の札。角の優劣記号と凡例は描かない。`set_hints(hints: Dictionary, even_keys: Array[String])` の `even_keys` が ±0 の札のキー。エリアを押せる範囲は、画面に写したエリア全体（奥の行でも 96px 以上） |
| `ChoicePanel` | `show_options(options: MoveOptions, turn_kind: GameEnums.TurnKind, user_has_ball: bool)`、`select_action(family, action)` | `action_selected(family: GameEnums.ChoiceFamily, action: int)` | 運ぶ先が1つもない手は選択不可（`screen-design.md` S-03） |
| `MiniPitch` | `show_counts(counts: Dictionary, two_teams: bool)`、`show_movements(movements: Array[Movement])`（S-07 の振り返りの各ターン。矢印をマスの中心から中心へ描く） | — | 作戦ボードと同じ向き（5列×3行、攻撃方向が上。上が敵陣・左が左大外。2026-10-23 に縦向きへ揃えた）。遠近と立体の駒は付けない（真上から見た平面）。2チームを出すマスの大きさは、使う画面の作業で決める（数字 `1−0` が 24px で入る大きさ）。1チームの人数だけを出す陣形カードでは 横 44px・縦 60px。画面ごとに大きくしてよい（S-09）。押せない表示専用 |
| `NotesView` | `show_notes(notes: Array[MatchupNote], simplifications: Array[SimplificationDef])` | — | 単純化 ID があれば「実戦では」を添える |
| `ConfirmDialog` | `ask(message: String, ok_label: String, cancel_label: String)` | `answered(ok: bool)` | 画面の上に重ねる。1つの画面で同時に1つだけ |
| `MatchMenu` | `open(has_unsaved_progress: bool)` | `settings_requested`、`suspend_requested`、`closed` | 試合中の画面（S-03〜S-05）のメニュー。本書で追加（`component-design.md` §5.5 に反映） |
| `SettingsPanel` | `show_settings(settings: UserSettings)` | `changed(settings: UserSettings)`（値が動くたび）、`committed(settings: UserSettings)`（スライダーを離したとき・トグルを切り替えたとき・パネルを閉じるとき。キー操作で変えた値も閉じるときに保存される） | S-12 の本体と、試合中のメニューから重ねて開く設定の両方で使う。音量のオーディオバスへの反映は、`changed` のたびにこの部品が行う（どちらの画面で開いても同じに効く。反映のしかたは [`screen-12-settings.md`](./screen-12-settings.md)「音量の反映」）。保存は、開いた側が `committed` を受けて `App.user_data.save_settings()` を呼ぶ。本書で追加（同上） |
| `MatchBoardPanel` | `bind(controller: MatchController, show_next: bool = true)`（画面の `enter` で1回だけ。2回目以降は何もしない）、`set_options_filter(actions: Array[String])`（チュートリアルの段階で選べる手を絞る。空なら絞らない）、`set_interactive(enabled: bool)`（偽なら `ChoicePanel` と主ボタンを隠し、盤面を見せるだけにする）、`start_turn()`、`refresh_hints()`（設定でヒント表示を変えたとき。選択は保つ） | `turn_ready_to_leave`、`turn_started(snapshot: BoardSnapshot)`、`reveal_started(reveal: RevealView)`、`result_shown(snapshot: BoardSnapshot)`（画面側の上部バーを描き直すため） | 試合画面の盤面・手の選択・判定理由をまとめた部品。手の選択から判定理由の表示までの状態（`SELECT_ACTION`〜`SHOW_RESULT`）と、`controller` の `turn_resolved` の受信はこの部品が持つ。判定理由を出した後、`show_next` が真なら主ボタンを「次のターンへ」にして、押されたら `turn_ready_to_leave` を出す。偽なら主ボタンを隠し、判定理由を出した時点で `turn_ready_to_leave` を出す（S-08。「次へ」は画面側のボタン）。左の本体に `TacticsBoard`、右の操作の列に `ChoicePanel`・判定理由・主ボタンを置く。S-03 と S-08 で共用。ルートは `Control`（3D 演出の `ReplayLayer` は 2026-10-23 にやめた） |
| `ScoreBug` | `show(snapshot: BoardSnapshot)` | — | 中継風のスコア表示（「● YOU 1 – 0 CPU ◆」と時計）。`show` は `CanvasItem.show()` とぶつかるので、作るときに別の名前（`show_snapshot` など）にする |
| `ScreenHeader` | `set_title(text: String)`、`set_back_label(text: String)` | `back_pressed` | 左に戻る（またはやめる）、その右に画面名。右側は画面ごとの表示（タブ・段階の番号など）に使う |
| `FormationCard` | `show_formation(formation: FormationDef, counts: Dictionary, selected: bool, compact: bool)` | `pressed(formation_id: String)` | `compact` が真なら陣形名と ✓ だけの小さい版（S-05）。関数名は `CanvasItem.show()` とぶつかるため `show_formation`。ルートは `Control` で、中に全面のトグルボタン（選択中は押した状態＝黄色の縁）を置く（シグナル `pressed` が `Button.pressed` とぶつかるため）。選択の状態は画面が持ち、カードは受け取った値を出すだけ |
| `SimplificationList` | `show_items(items: Array[SimplificationDef])` | — | S-10 と S-08 の最後の段階で共用 |
| `NewMatchGate` | `begin(host: Control, dialog: ConfirmDialog)` | `finished(started: bool)` | 「CPU 対戦」の確認の手順（[`screen-01-title.md`](./screen-01-title.md)「CPU 対戦を押す」）。ノードを持たない `RefCounted` |

`ToastView`（短い通知）は `MainShell` が1つだけ持ち、`App.storage_error` を受けて表示する。各画面は持たない。
