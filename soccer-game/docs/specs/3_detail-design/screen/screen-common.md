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
| 基準解像度 | 1280 × 720（横向き）・720 × 1280（縦向き。2026-11-27） | 高さ（縦では幅）360dp の端末で 1dp = 2px になる。後続マイルストーンの Windows 版は横の基準解像度を使う。縦・横の切り替えは §1.2 |
| `display/window/handheld/orientation` | `sensor`（Android。2026-11-27 に `sensor_landscape` から変えた） | 端末の向きに合わせて回す（NFR-25）。ブラウザ版の PWA の manifest も向きを固定しない（`export_presets.cfg.example` の `progressive_web_app/orientation=0`） |

**本書と各画面の設計書の寸法は、すべて基準解像度上の px で書く。** dp との対応は Android の基準で 1dp = 2px。

### 1.1 画面の基本の配置（横向き）

`screen-design.md`「画面の向きと基本の配置」の「上にヘッダー、左に本体、右に操作の列」を、次の寸法で組む。

| 部分 | 寸法 | 備考 |
|---|---|---|
| ヘッダー | 高さ 96px。幅は画面いっぱい | 試合中の画面では、中継風のスコア表示（`ScoreBug`）・どちらのボールか（S-03。2026-10-24）・局面のタグを兼ねる。両チームの陣形・方式は操作の列の上端に置く（S-03） |
| 操作の列（右） | 幅 480px（16:9）。横に長い端末では広げ、上限 640px | 選択肢・解説・主ボタン。主ボタンは列の下端に置く。中身が入りきらない画面は列の中を縦にスクロールする |
| 本体（左） | 残りの幅（16:9 で 728px、21:9 で 968px）。高さ 576px（S-03・S-08 は上下の外周の余白を 12px にして 600px。2026-10-25。6列の作戦ボードの1エリアが NFR-19 を満たすため） | 作戦ボード・ミニピッチ・一覧など。作戦ボードは本体いっぱいに広げ、縦横比は固定しない（ピッチの白線はボードの大きさに合わせて描く） |
| 余白 | 外周と、本体と操作の列の間に 24px。S-03 と S-08（同じ作戦ボードを使う）は外周の上下を 12px にする（左右は 24px のまま） | — |

- 端末の切り欠きは横向きでは左右に来るため、`DisplayServer.get_display_safe_area()` で安全な範囲を求め、左右の余白に足す（`MainShell` が画面のルートの余白として設定する。各画面は意識しない）。左右には同じ余白（大きい方）を当てる。横向きのまま 180° 回すと切り欠きは反対側へ移るが、ビューポートの大きさが変わらず、余白を当て直すきっかけが無いため
- 本体と操作の列を持たない画面（S-10・S-12 など）も、ヘッダーの高さと外周の余白は同じにする
- ヘッダーの中身は 16:9 で使える幅（1232px）に収める。いちばん長くなる文言（局面のタグ `NEG.TRANSITION ネガティブトランジション`（英字と日本語の2行で表示する。1行では上部バーが幅を超えた。screen-03-match.md）、手と運ぶ先「サイドチェンジ → 攻撃・右ハーフスペース」など）で確かめ、可変の文言の `Label` には `text_overrun_behavior = ELLIPSIS` を付ける（全文は操作の列などで読めるようにする）
- 操作の列は「上端の固定部分 → 縦にスクロールする中身 → 下端の主ボタン（固定）」の3段にする。中身が入りきらないときも、主ボタンと上端の固定部分は動かない
- 16:9 より縦長の端末（4:3 のタブレットなど）は、横向きでは NFR-25 の範囲外とし、Google Play の対応端末の設定で配布の対象から外す（横幅が 1280px を下回り、1エリアの最小の幅を割るため）

### 1.2 縦向きの配置（2026-11-27）

`MainShell` が、ウィンドウが縦長（高さ ＞ 幅）なら基準解像度を 720 × 1280・`keep_width`（幅を 720px に固定し、縦に長い端末ほど高さが
1280px より広がる）に、横長なら 1280 × 720・`keep_height` に切り替える。切り替えはウィンドウの大きさが変わったフレームの処理の後に行う
（`size_changed` の中で変えると、ブラウザ版で拡大縮小の変換が古い大きさのまま残り、画面が歪んだ）。向きは `ScreenSwitcher` が、
表示中の画面と、その後に開く画面（`enter` の前）へ `AppScreen.set_portrait` で伝え、変わったときだけ各画面が `_apply_orientation` で
配置を組み替える。組み替えるのは配置だけで、画面の状態（選んだ手・開示中の盤面など）は変えない。

- 横で左右に並べていた区画を上下に積む。並べる箱は向きを変えられる `BoxContainer`（`HBoxContainer` は横に固定で変えられない）
- 主ボタンは画面の下端に置く。余った高さは、画面ごとに決めた区画が受ける（タイトルはプロダクト名の区画、試合準備は陣形のカード、
  試合は作戦ボードと操作の列で分ける）
- 端末の切り欠き・ジェスチャーの帯は縦では上下に来るため、上下の余白に足す（`MainShell.top_bottom_margins`。横と同じく両側に大きい方）
- S-03（試合）: 外周の左右の余白を 16px にする（幅 720px から作戦ボードの最小の幅 680px を取るため）。上部バーは2段（1段目 96px:
  メニュー・スコア、2段目 72px: どちらのボールか・局面のタグ／両者の選択の帯）。作戦ボードは最小の大きさ（5レーン × 6列のエリア）を保つ。
  16:9（720 × 1280）で切り欠きの余白が上下合わせて 96px 付いても、作戦ボード・手のボタン・主ボタンが収まる（`match_screens_test` で固定）
- 縦の配置をまだ持たない画面（S-04〜S-12）は、横の配置のまま縦の画面に出る（順に足す）

| 用途 | 最小の大きさ | 根拠 |
|---|---|---|
| ボタン・選択肢など、押せるものすべて | 高さ 96px（48dp）以上、幅 96px 以上 | NFR-19 |
| 作戦ボードの1エリア | 画面でいちばん小さい奥の行（敵陣）でも、幅・高さ 96px（48dp）以上（NFR-19）。平面図（縦向きのピッチを真上から見た図）の1エリアで幅 136px・高さ 100px 以上（`TacticsBoard.MIN_CELL`。奥では幅が 0.72 倍になる。縦は詰めず、上の余白（ボードの高さの 4%）の分だけ各行が 0.96 倍になる）。駒の間隔と大きさは、セルの幅に合わせて縮め、1チーム 2列×2段がエリアの半分に収まるようにする。基準の 16:9 で、作戦ボードは約 726×600px、平面図の1エリアは約 145×100px、画面の1エリアは奥の行で約 105×96px。横に長い端末ほど幅が広がる（2026-10-23 に縦向きの盤面へ変えた。2026-10-25 に6列にし、奥の行の高さを保つため縦を詰めるのをやめた） | `screen-design.md`「共通の部品と操作」 |
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
  | 作戦ボードのレーン名・ヒントの札（`+1`・`±0 カバーあり`） | 16px・18px（例外。盤面の情報を絞るため、駒より目立たせない。2026-10-22。コントラスト比は NFR-21 を満たす色にする）。レーン名は手前の行の各エリアの左下に書く（左上では、中央から左に並ぶ自分の駒の体に隠れた。1エリアに自分の駒が2人までなら重ならない。`BoardPainter.lane_name_baseline`。2026-11-06） |
  | 局面のタグ・比較エリアの札（`1対0`） | 26px（Barlow Condensed Bold） |
  | スコア | 52px（Barlow Condensed Bold） |
  | 結果のラベル（`ADVANCE`）・`KICK OFF` | 44px（Barlow Condensed Bold） |
  | 局面の帯の見出し（`NEG. TRANSITION`。S-03。2026-11-07） | 64px（Barlow Condensed SemiBold） |
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
| 結果の札（`YouOutcomeTagLabel`・`OpponentOutcomeTagLabel`） | 地は `you`／`opponent`、文字は `bg` の色 | 9.8 ／ 8.3 | 手が成功した側の色で結果のラベルを塗る（判定なしは `accent`）。記号（● ／ ◆）も添え、色だけで示さない（2026-10-24） |
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
| `zone_line` | `#F8FAFC`（不透明度 25%、点線） | — | 30エリアの境界 |
| `tag_muted_bg` | `#0B111C`（不透明度 70%） | — | 差が ±0 のヒントの札の地。文字は `text`（差がある札は `accent` の地に `bg` の文字） |
| `ball_area_fill` | `#FFFFFF`（不透明度 10%） | — | ボールのあるエリアの薄い塗り |
| `lane_text` | `#CBD5E1` | 5.4（`pitch`） | レーン名 |

- 駒はユニフォームを着たチェスのポーンで、色に加えて形で区別する。相手の胴は縦じま、胸の印は利用者が丸（●）、相手がひし形（◆）（2026-11-06 に、頭の形で区別するチェスの駒から変えた）。縦じまはチームの色を 0.55 暗くし、胴と 3:1 以上の差を付ける（`BoardPainter.stripe_color`）。ボールは `ball` の地に `bg` の五角形の模様で、駒と同じ光沢の 3D の絵（`PieceSprites.ball_texture`。本物のボールと同じ12の五角形の並びで、正面に1枚が来る向き。`BoardPainter.ball_rect` で縮めて置く。2026-11-07）。絵が無いときは平面の模様（`ball_patches`）。チームを文字で示す帯なども ●・◆ を使う
- 優劣は、作戦ボードではエリアの中の ●・◆ の駒の数（形で区別）で、ミニピッチでは記号（`▲`・`＝`・`▼`）で示し、色は補助にする。グレースケールでの確認は NFR-20 の手順で行う
- `pitch` 系の色は、駒の色（`you`・`opponent`）との比が 3:1 を下回らない範囲で調整する。値を変えたら本表の比を計算し直す

**得点のカットイン**（テーマの型 `GoalCutIn`）の色（キーパーのユニフォーム・髪・グローブ）は、3D のカットインと一緒に 2026-11-27 に外した。

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
| `TacticsBoard` | `show_snapshot(snapshot: BoardSnapshot)`、`set_selectable(areas: Array[String])`、`set_hints(hints: Dictionary, even_keys: Array[String] = [])`、`show_intent(from_area: String, to_area: String)`、`show_movements(movements: Array[Movement])`、`show_preview_motion(frames: Array)`（決定前のプレビュー。自分の選手の配置の並び（ターン開始時・次のターン開始時。`MatchController.user_preview_frames`。2026-11-06 に判定時を外して1拍にした）を、どこかで位置が変わる選手だけ半透明の駒で順に動かし、止めて最初へ戻すのをくり返す。動く選手のもとの駒は描かず、動かない駒はその場に残す。時間は `set_preview_style(style)`（`MatchController.preview_style()`）。空・`show_snapshot`・`clear_overlays` で消す。問い合わせは `preview_frames()`・`preview_ghost_ids()`・`preview_ghost_center(player_id)`・`is_previewing()`。2026-11-05 に、移動先の半透明の駒と点線の矢印の `show_preview` から変えた）、`start_shift(keyframes: Array[Dictionary], result: Dictionary = {})`（開示で、駒とボールを拍に分けて順に動かす。`keyframes` の各要素は拍の始まりの配置とその拍の時間 `{"user", "opponent", "ball", "sec"}`。i 番目の拍は `keyframes[i]` から `keyframes[i + 1]` へ、最後の拍はいまの盤面へ動く。開示では、判定前の配置だけを渡し、判定前 → 次のターン開始時の1拍で動かす。得点だけは判定時の配置も渡し、シュートとキックオフへの組み直しの2拍にする（2026-11-06。2026-11-03 からは 1拍目（プレー）= 判定前 → 判定時、2拍目（詰め直し）= 判定時 → 次のターン開始時の2拍だった。ボードは複数の拍を動かせるまま残す）。2026-11-03。各拍では、位置が変わった全選手の駒を、その拍の始まりのボールに近い順に少し遅れて動かし始め（ずらし）、加速して減速して止め（イージング）、動いている間は小さく浮かせる（弾み。`shifting_piece_lift(player_id, is_user)`。駒は自分・相手の別と id の組で見分ける。id は陣形の枠の id で、同じ陣形なら相手にも同じ id がいるため。2026-11-05）。値は `set_piece_style(style: Dictionary)`（`MatchController.piece_style()`）で入れる。拍と拍の間には `set_beat_gap_sec(sec)` 秒の小休止を置く（着地は待たない。2026-11-05）。ボールは拍の始まりと終わりのエリアが違うときだけ動かす。動きの無い拍・時間が 0 以下の拍は飛ばす。後の拍で動く駒は、それまでの拍の間はその拍の始まりの位置に描く。keyframe に `"flight"`（`BallFlight.Kind`）があれば、その拍のボールをその軌道で動かす（グラウンダー・浮き球・ドリブル・強いシュート。無ければまっすぐ等速。2026-11-03）。軌道の高さの値は `set_ball_style(style: Dictionary)`（`MatchController.ball_style()`）で入れ、いまの高さは `ball_lift()`。`result`（`ResultEffect.for_reveal` の値）があれば、得点は1拍目のボールをゴールの口（`goal_mouth(is_top)`）へ向けて2拍目をそこから始め、膠着は運ぶ先の方への跳ね返りにする。1拍目（keyframes[0] の拍）が終わると `play_landed` を出し（1拍目が無ければ `start_shift` の中ですぐ、途中で止めたらそのとき。1回の開示で1回だけ）、輪・ゴールの光・旗を `set_result_sec(sec)` 秒出す（`result_effect()`・`result_progress()`。次の `show_snapshot`・`clear_overlays` で消す。2026-11-03）。問い合わせは `shift_beat_count()`・`shift_beat_index()`・`shift_beat_paths(beat)`・`shift_beat_ball_path(beat)`、いまの拍の `shift_paths()`・`shift_ball_path()`。動いている間は駒を選手ごとに描き「+N」の札は出さない。そのため5人以上いるエリアでは、動いている間だけ4人目以降の駒が最後の位置で重なる（既知の制約）。エリアが同じでも、列の位置が変わった駒は動かす。次の `show_snapshot`・`clear_overlays` で止まる）、`show_compare(area: String, user_count: int, opponent_count: int)`、`show_tally(tally: Dictionary)`（振り返りの集計の札。駒は出さない。エリアのキー → 札の文で、空の文は描かない。選べるエリアに関係なく、エリアの中央に `accent` の札。字はヒントの札と同じ 18px で、エリアの幅に収まらなければ 11px まで縮める。2026-10-29）、`clear_overlays()` | `area_pressed(area_key: String)`、`play_landed()` | ピッチを縦に置いて斜めから見せ（半3D）、利用者の攻撃方向は常に上（上から A2〜D1 の6列、左から L2・L1・C・R1・R2 のレーン。2026-10-23 に横向き・右から変えた。2026-10-25 に6列にした）。位置は平面図の座標で持ち、`BoardProjection` の写し方（奥 = 上を狭く。奥の縮み 0.72。6列の奥の行も押せる高さを保つため縦は詰めない）で画面に描く。押した点は逆の写し方で平面図へ戻してエリアを引く（`area_at`。平面図の点は `plan_area_at`）。描き方: ①ピッチ（`pitch` 系の色・白線・センターサークル・上下のペナルティエリアとゴール）②ボールのあるエリアの薄い塗り（`ball_area_fill`）・選んだエリアの塗り・選べるエリアの点線の枠 ③30エリアの点線とレーン名（いちばん手前の行（自陣ゴール前 D1）の各エリアの左上に 16px）③.5オフサイドライン（利用者が攻撃中のとき、相手の最終ラインの列の相手ゴール側の境界に `opponent` の点線。ラインが敵陣ゴール前の列なら描かない。2026-10-25）④矢印（ボール＝`accent` 太線、寄せ・カバー＝`opponent` か `you` の実線。方式の動きと保持者の動きは描かない）、選んだ手の矢印（ボールを運ぶ手だけ） ⑤立っているもの（`standing_order()` の順に、奥から手前へ。手前の駒が奥の駒に重なる）: 駒（`BoardSnapshot.user_players` / `opponent_players` から、番号なしで描く。ユニフォームを着たチェスのポーンで、光沢のあるプラスチックの立体の絵（`PieceSprites`。起動後に盤面の中でチームごとに1回だけ 3D で描き、ミップマップつきの画像にする）を、台座が駒の半径・台座の中心が足元に来るよう縮めて置き（`BoardPainter.sprite_rect`）、床の影は平面の楕円で描く。絵が無いとき（画面の無い実行・描き終わる前）は、影・台座・胴（相手は暗い縦じま）・胸の印（自分 ●・相手 ◆）・首の輪・丸い頭の平面の図形で描き（`BoardPainter.player_parts`。顔や手足は描かない。2026-11-06）、奥ほど小さい。開示で動いている駒は弾みの分だけ持ち上げ、影は足元に残して浮くほど小さく薄くする（2026-11-05）。自分はエリアの左半分、相手は右半分に、2列×2段。各チーム5人以上いるときは、駒を3つと「+N」の札（`tag_muted_bg` の地）にする）、決定前のプレビューの駒（自分の駒を半透明で、配置ごとの駒の列の位置の間を動かす。自分の駒が5人以上いるエリアでは最後の位置で止まり「+N」の札に重なる。まれで判定に影響しないため、既知の制約とする）、ボール（エリアの上側の中央に、少し浮かせて地面に影を落とす。開示の浮き球・ドリブルの弾みでは `ball_lift()` の分だけボールを持ち上げ、影は地面に残す） ⑤.5開示の結果の演出（得点はゴールの四角を決めた側の色で塗り口から輪を広げる、セーブ・ボールを奪ったときはエリアの中央から輪を広げる、オフサイドはエリアの下寄りに旗。色は成功した側の `you`／`opponent`、進み具合で薄くする。2026-11-03） ⑥ヒントの札（選べるエリアの下端の中央に 18px。差がある札は `accent`、人数を比べる札の ±0 は `tag_muted_bg`（スルーパスの `読み次第`・`マーク注意` と `オフサイド` の札は ±0 でも `accent`。`MatchTexts.is_hint_muted`。2026-10-25）。駒と矢印の上に描いて字を隠さない）⑦比較エリアの光と人数の札。角の優劣記号と凡例は描かない。`set_hints(hints: Dictionary, even_keys: Array[String])` の `even_keys` が ±0 の札のキー。エリアを押せる範囲は、画面に写したエリア全体（奥の行でも 96px 以上） |
| `ChoicePanel` | `show_options(options: MoveOptions, turn_kind: GameEnums.TurnKind, user_has_ball: bool)`、`select_action(action)`、`actions()`、`number_of(action)` | `action_selected(family: GameEnums.ChoiceFamily, action: int)` | 画面に出す手のうち選べる手だけを、枠の並び（`MoveMenu.SLOTS`）で2列に並べる（4つまでで、スクロールせずに選べる）。ボタンは番号と行動の名前だけ（「① ショートパス」。2026-11-05）。1行に入らない名前（8文字以上）は語の切れ目で改行する（「① パスコースを／切る」。位置は `MatchTexts.BUTTON_LINE_BREAKS`。Godot の折り返しは、かなの間ならどこでも切るため。2026-11-05）。選べない手は出さない（`screen-design.md` S-03。2026-11-03） |
| `MoveDetailView` | `open(title: String, lines: Array[String])`、`close()`、`title()`・`text()`・`close_button()` | — | 選んだ手の詳細のポップアップ（`ModalOverlay`）。見出しは手の名前、本文は行き先・判断材料・手の説明（空の行は出さない）、「閉じる」（2026-11-05） |
| `MiniPitch` | `MiniPitch.new(cell_size: Vector2 = Vector2(44, 30))`、`show_counts(counts: Dictionary)`（1チーム。2026-10-29 に使っていなかった `two_teams` を外した）、`show_matchup(user_counts: Dictionary, opponent_counts: Dictionary)`（S-05 の噛み合わせ。各マスに「自分−相手」と優劣記号 `▲`（自分が多い）・`＝`・`▼` を続ける。動きとボールは描かない。両方 0 のマスは空。2026-11-03）、`show_turn(user_counts: Dictionary, opponent_counts: Dictionary, movements: Array[Movement], ball_area: String)`（S-07 の振り返りの各ターン。各マスに「自分−相手」の人数、`TacticsBoard` と同じ理由の動きをマスの中心から中心へチームの色の矢印、ボールのエリアの上側に小さな白丸。2026-10-29） | — | 作戦ボードと同じ向き（横5レーン×縦6列、攻撃方向が上。上が敵陣・左が左大外。2026-10-23 に縦向きへ揃えた）。遠近と立体の駒は付けない（真上から見た平面）。2チームを出すマスの大きさは、使う画面の作業で決める（数字 `1−0` が 24px で入る大きさ。S-07 は 横 56px・縦 34px。2026-10-29）。1チームの人数だけを出す陣形カードでは 横 44px・縦 30px（2026-10-25 に6列で 60px から変更。カードの 220×180 を保つため）。画面ごとに大きくしてよい（S-09）。押せない表示専用 |
| `NotesView` | `show_notes(notes: Array[MatchupNote], simplifications: Array[SimplificationDef] = [])`、`show_message(text: String)`（案内文1行）、`headings()`・`texts()`・`in_real_texts()`（確認用） | — | 続く同じ見出し（`MatchupNote.label`。`SectionTitleLabel`）を1つにまとめ、本文は「・」を頭に折り返して出す（`PanelLabel`）。案内文は `MutedLabel`。スクロールは置く側が持つ。項目が単純化 ID を持てば、そのすぐ下に単純化カタログの「実戦では: …」を `CautionLabel` で出す（FR-23。同じ ID は欄の中で最初の1回だけ。カタログを渡さなければ出さない。2026-11-03） |
| `ConfirmDialog` | `ask(message: String, ok_label: String, cancel_label: String)`、`cancel()`（「やめる」と同じ。戻る操作で使う） | `answered(ok: bool)` | 画面の上に重ねる。1つの画面で同時に1つだけ。閉じてから `answered` を出す（受けた側が続けて別の確認を出せるように）。コードで組む（シーンを持たない。2026-10-29） |
| `MatchMenu` | `open(has_unsaved_progress: bool)`、`close()`、`handle_back() -> bool`（確認・メニューのいちばん上を閉じたら `true`） | `settings_requested`、`suspend_requested`、`closed` | 試合中の画面（S-03〜S-05）のメニュー。本書で追加（`component-design.md` §5.5 に反映）。「設定」「中断してタイトルへ」「閉じる」。直前の保存に失敗していたら、「中断してタイトルへ」で警告つきの確認を出す（成功していれば確認なし。中断は試合を消さないため）。「設定」は設定の作業まで「設定（準備中）」で押せない（`settings_requested` はまだ出さない。2026-10-29） |
| `MatchMenuHost` | `MatchMenuHost.new(screen: Control, top_bar: HBoxContainer, can_open: Callable)`、`open()`、`handle_back() -> bool` | — | S-03〜S-05 の「≡」（96×96px。上部バーの先頭）と `MatchMenu` の持ち方をまとめた部品（`RefCounted`）。`can_open` が偽の間は開かない。「中断してタイトルへ」で `suspend_to_title()` を呼ぶ。戻る操作は、開いていれば閉じ、閉じていれば開く（いつも `true`）（2026-10-29） |
| `ModalOverlay` | — | — | `ConfirmDialog`・`MatchMenu` の土台。画面全体を暗い幕（テーマの型 `DialogPanel` の色 `dim`）で覆って下の入力を止め、中央の枠（`DialogPanel`。幅 720px）に中身を並べる。幕の外を押しても閉じない。幕はマウスとタッチしか止めないので、開いたら中の最初のボタンへフォーカスを移し、フォーカスが外へ出たら戻す（キー操作で下の画面を押せないように）（2026-10-29） |
| `SettingsPanel` | `show_settings(settings: UserSettings)` | `changed(settings: UserSettings)`（値が動くたび）、`committed(settings: UserSettings)`（スライダーを離したとき・ドラッグでない変更（キー操作・押した位置へ飛ぶ）のとき・トグルを切り替えたとき。2026-10-29 の設定の作業で、閉じるときの保存をやめ、ドラッグでない変更をその場で保存する形にした）、`license_requested` | S-12 の本体と、試合中のメニューから重ねて開く設定の両方で使う。音量のオーディオバスへの反映は、`changed` のたびにこの部品が行う（どちらの画面で開いても同じに効く。反映のしかたは [`screen-12-settings.md`](./screen-12-settings.md)「音量の反映」）。保存は、開いた側が `committed` を受けて `App.user_data.save_settings()` を呼ぶ。本書で追加（同上） |
| `MatchBoardPanel` | `bind(controller: MatchController, show_next: bool = true)`（画面の `enter` で1回だけ。2回目以降は何もしない）、`set_options_filter(actions: Array[String])`（チュートリアルの段階で選べる手を絞る。空なら絞らない）、`set_interactive(enabled: bool)`（偽なら `ChoicePanel` と主ボタンを隠し、盤面を見せるだけにする）、`side_top_slot()`・`side_bottom_slot()`（操作の列の上端・下端に部品を置く入れ物。チュートリアルの説明の吹き出しと「次へ」。2026-10-29）、`start_turn()`、`set_show_hints(is_on: bool)`（ヒント表示。OFF なら `user_hints()` を呼ばない。手を選んでいる間に変えたら、選択を保って描き直す。設計の `refresh_hints()` を、パネルが `App.user_data` を読まずに済むよう値を受け取る形にした。2026-10-29） | `turn_ready_to_leave`、`turn_started(snapshot: BoardSnapshot)`、`reveal_started(reveal: RevealView)`、`result_shown(snapshot: BoardSnapshot)`（画面側の上部バーを描き直すため） | 試合画面の盤面・手の選択・判定理由をまとめた部品。手の選択から判定理由の表示までの状態（`SELECT_ACTION`〜`SHOW_RESULT`）と、`controller` の `turn_resolved` の受信はこの部品が持つ。判定理由を出した後、`show_next` が真なら主ボタンを「次のターンへ」にして、押されたら `turn_ready_to_leave` を出す。偽なら主ボタンを隠し、判定理由を出した時点で `turn_ready_to_leave` を出す（S-08。「次へ」は画面側のボタン）。左の本体に `TacticsBoard`、右の操作の列に `ChoicePanel`・判定理由・主ボタンを置く。S-03 と S-08 で共用。ルートは `Control`（3D 演出の `ReplayLayer` は 2026-10-23 にやめた） |
| `PhaseBanner` | `follow(phase: GameEnums.Phase)`、`forget()`、`show_phase(phase)`、`dismiss()`、`is_showing()` | — | 局面の帯（S-03・S-08。2026-11-07）。`follow` は前に渡された局面と変わっていれば帯を出し、変わらなければ消す（最初の局面・`forget` の後は出さない）。画面の真ん中を横切り、1.2 秒で消え、タップを受けない。見た目は `screen-03-match.md` のノード構成 |
| `ScoreBug` | `show(snapshot: BoardSnapshot)` | — | 中継風のスコア表示（「● YOU 1 – 0 CPU ◆」と時計）。`show` は `CanvasItem.show()` とぶつかるので、作るときに別の名前（`show_snapshot` など）にする |
| `ScreenHeader` | `set_title(text: String)`、`set_back_label(text: String)`、`add_to_right(control: Control)`（右端に部品を置く。画面の組み立て中＝木に入る前にも呼べる。2026-10-29） | `back_pressed` | 左に戻る（またはやめる）、その右に画面名。右側は画面ごとの表示（タブ・段階の番号など）に使う |
| `FormationCard` | `show_formation(formation: FormationDef, counts: Dictionary, selected: bool, compact: bool)` | `pressed(formation_id: String)` | `compact` が真なら陣形名と ✓ だけの小さい版（S-05）。関数名は `CanvasItem.show()` とぶつかるため `show_formation`。ルートは `Control` で、中に全面のトグルボタン（選択中は押した状態＝黄色の縁）を置く（シグナル `pressed` が `Button.pressed` とぶつかるため）。選択の状態は画面が持ち、カードは受け取った値を出すだけ |
| `SimplificationList` | `show_items(items: Array[SimplificationDef])` | — | S-10 と S-08 の最後の段階で共用 |
| `NewMatchGate` | `NewMatchGate.new(controller: MatchController, request_screen: Callable)`、`begin(dialog: ConfirmDialog)` | `finished(started: bool)` | 「CPU 対戦」の確認の手順（[`screen-01-title.md`](./screen-01-title.md)「CPU 対戦を押す」）。ノードを持たない `RefCounted`。`host` の引数は使わないので外した（2026-10-29）。文言は `DISCARD_MESSAGE`・`UNRECORDED_MESSAGE`（戦績を記録できていない試合。2026-10-29 の戦績の作業で足した） |

`ToastView`（短い通知）は `MainShell` が1つだけ持ち、`App.storage_error` を受けて表示する。各画面は持たない。
画面の下端から 32px に、地 `surface`・縁 `accent` の枠（テーマの型 `ToastPanel`）で5秒出す。押せない表示（下の画面の操作を止めない）。
続けて出たときは新しい文に置き換える。タイトルを開く前に出たもの（起動時の中断データの破損など）は `MainShell` が保持し、
初めてタイトルを開いた後に出す。文言は `functional-overview.md`「エラーハンドリング」の書き写し（2026-10-29）。
