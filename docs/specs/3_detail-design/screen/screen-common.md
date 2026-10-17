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

- 端末の切り欠きは横向きでは左右に来るため、`DisplayServer.get_display_safe_area()` で安全な範囲を求め、左右の余白に足す（`MainShell` が画面のルートの余白として設定する。各画面は意識しない）
- 本体と操作の列を持たない画面（S-10・S-12 など）も、ヘッダーの高さと外周の余白は同じにする
- ヘッダーの中身は 16:9 で使える幅（1232px）に収める。いちばん長くなる文言（局面のタグ `NEG.TRANSITION ネガティブトランジション`、手と運ぶ先「サイドチェンジ → 攻撃・右ハーフスペース」など）で確かめ、可変の文言の `Label` には `text_overrun_behavior = ELLIPSIS` を付ける（全文は操作の列などで読めるようにする）
- 操作の列は「上端の固定部分 → 縦にスクロールする中身 → 下端の主ボタン（固定）」の3段にする。中身が入りきらないときも、主ボタンと上端の固定部分は動かない
- 16:9 より縦長の端末（4:3 のタブレットなど）は NFR-25 の範囲外とし、Google Play の対応端末の設定で配布の対象から外す（横幅が 1280px を下回り、1エリアの最小の幅を割るため）

| 用途 | 最小の大きさ | 根拠 |
|---|---|---|
| ボタン・選択肢など、押せるものすべて | 高さ 96px（48dp）以上、幅 96px 以上 | NFR-19 |
| 作戦ボードの1エリア | 高さ 112px（56dp）・幅 192px（96dp）以上（高さは、上端の帯 32px ＋ 駒 40px × 2段）。基準の 16:9 で約 115×242px（§1.1）。横に長い端末ほど幅が広がる | `screen-design.md`「共通の部品と操作」 |
| 画面の外周の余白 | 24px。これに端末の切り欠き（カメラの穴など）の分を足す（§1.1） | `screen-design.md`「画面の向きと基本の配置」 |

## 2. フォント・文字

見た目の方向性（スタジアム中継風）の正本は `screen-design.md`「ビジュアルの方向性」。フォントの同梱・サブセット・
ライセンスの扱いの正本は `architecture-overview.md`（テクノロジースタックの注記）。ここでは画面で使う割り当てだけを決める。

| 書体 | 太さ | 使うところ |
|---|---|---|
| Noto Sans JP | Regular・Bold | 日本語の本文・ボタン・判定理由・解説 |
| Barlow Condensed | SemiBold・Bold | スコア・残りターン・局面のタグ（`ATTACK` など）・`REPLAY`・`KICK OFF`・結果のラベル（`ADVANCE` など）・背番号 |

- ボールは文字ではなく画像（アイコン）で描く（絵文字はフォントに含まれず、端末で見た目が変わるため）
- 記号 `▲`・`＝`・`▼`・`●`・`◆`・`−` は Noto Sans JP で描く（サブセットに必ず含める）
- 文字の大きさ（基準解像度上の px）

  | 用途 | 大きさ |
  |---|---|
  | 本文・ボタン | 28〜32px |
  | 補助・注記（凡例・「実戦では」） | 24px（これより小さくしない） |
  | 背番号・角の優劣記号 | 24px（Bold） |
  | 局面のタグ・札（`+1`・`1対0`） | 26px（Barlow Condensed Bold） |
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
| `accent` | `#F5C518` | 11.9（`bg`） | 強調（主ボタン・選んだエリア・タグ・札・リプレイ）。上に載せる文字は `bg` の色（11.9） |
| `you` | `#4CC3FF` | 9.8（`bg`） | 利用者のチームの色。駒の背番号は `bg` の色（9.8） |
| `opponent` | `#FF8A3D` | 8.3（`bg`） | CPU のチームの色。駒の背番号は `bg` の色（8.3） |
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
| `mark_bg` | `#0B111C`（不透明度 70%） | — | 角の優劣記号の地。記号の色は `accent`（優位）・`opponent`（不利）・`text`（同数） |

- 駒は、利用者が丸（●）、相手がひし形（◆）で、色に加えて形で区別する。チームを文字で示す帯なども ●・◆ を使う
- 優劣は記号（`▲`・`＝`・`▼`）で示し、色は補助にする。グレースケールでの確認は NFR-20 の手順で行う
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

## 5. 画面をまたいで使う部品

`component-design.md` §5.3〜§5.5 の部品のうち、複数の画面の設計書が前提にする外から見た形をここに置く。

| 部品（`class_name`） | 外から渡す値 | 出すシグナル | 備考 |
|---|---|---|---|
| `TacticsBoard` | `show_snapshot(snapshot: BoardSnapshot)`、`set_selectable(areas: Array[String])`、`set_hints(hints: Dictionary)`、`show_intent(from_area: String, to_area: String)`、`show_movements(movements: Array[Movement])`、`show_compare(area: String, user_count: int, opponent_count: int)`、`show_tally(tally: Dictionary)`（振り返りの集計の札。駒は出さない）、`clear_overlays()` | `area_pressed(area_key: String)` | ピッチを横に置き、利用者の攻撃方向は常に右（左から D・M・A のゾーン、上から L2・L1・C・R1・R2 のレーン）。描き方: ①ピッチ（`pitch` 系の色・白線・ペナルティエリア・ゴール）②15エリアの点線とレーン名（各レーンの左端）③各エリアの駒（`BoardSnapshot.user_players` / `opponent_players` から、選手ごとに背番号つきで描く。自分 ● をエリアの左半分・相手 ◆ を右半分に、直径 40px（背番号は 24px）。エリアの上端の高さ 32px は優劣記号とヒントの札の帯とし、駒はその下に2列×2段で並べる。各チーム5人以上いるときは、駒を3つと「+N」の札にする（人数は優劣記号の読み上げ用のラベルにも出す））④角の優劣記号（全エリアの左上に常時）⑤選べるエリアの点線の枠・選んだエリアの塗り・ヒントの札（エリアの右上）⑥矢印（ボール＝`accent` 太線、寄せ・カバー＝`opponent` か `you` の実線、方式の動き＝白の点線）⑦比較エリアの光と人数の札。動きの矢印の凡例はボードの左下の隅に重ねる。エリアを押せる範囲はエリア全体（16:9 で約 242×115px） |
| `ChoicePanel` | `show_options(options: MoveOptions, turn_kind: GameEnums.TurnKind, user_has_ball: bool)`、`select_action(family, action)` | `action_selected(family: GameEnums.ChoiceFamily, action: int)` | 運ぶ先が1つもない手は選択不可（`screen-design.md` S-03） |
| `MiniPitch` | `show_counts(counts: Dictionary, two_teams: bool)`、`show_movements(movements: Array[Movement])`（S-07 の振り返りの各ターン。矢印をマスの中心から中心へ描く） | — | 作戦ボードと同じ向き（3列×5行、攻撃方向が右）。1マス 横 80px・縦 44px（`1−0` の数字が 24px で入る大きさ）。1チームの人数だけを出す陣形カードでは 横 72px・縦 36px。画面ごとに大きくしてよい（S-09）。押せない表示専用 |
| `NotesView` | `show_notes(notes: Array[MatchupNote], simplifications: Array[SimplificationDef])` | — | 単純化 ID があれば「実戦では」を添える |
| `ConfirmDialog` | `ask(message: String, ok_label: String, cancel_label: String)` | `answered(ok: bool)` | 画面の上に重ねる。1つの画面で同時に1つだけ |
| `MatchMenu` | `open(has_unsaved_progress: bool)` | `settings_requested`、`suspend_requested`、`closed` | 試合中の画面（S-03〜S-05）のメニュー。本書で追加（`component-design.md` §5.5 に反映） |
| `SettingsPanel` | `show_settings(settings: UserSettings)` | `changed(settings: UserSettings)`（値が動くたび）、`committed(settings: UserSettings)`（スライダーを離したとき・トグルを切り替えたとき・パネルを閉じるとき。キー操作で変えた値も閉じるときに保存される） | S-12 の本体と、試合中のメニューから重ねて開く設定の両方で使う。音量のオーディオバスへの反映は、`changed` のたびにこの部品が行う（どちらの画面で開いても同じに効く。反映のしかたは [`screen-12-settings.md`](./screen-12-settings.md)「音量の反映」）。保存は、開いた側が `committed` を受けて `App.user_data.save_settings()` を呼ぶ。本書で追加（同上） |
| `MatchBoardPanel` | `bind(controller: MatchController, show_next: bool = true)`（画面の `enter` で1回だけ。2回目以降は何もしない）、`set_options_filter(actions: Array[String])`（チュートリアルの段階で選べる手を絞る。空なら絞らない）、`set_interactive(enabled: bool)`（偽なら `ChoicePanel` と主ボタンを隠し、盤面を見せるだけにする）、`start_turn()`、`refresh_hints()`（設定でヒント表示を変えたとき。選択は保つ） | `turn_ready_to_leave`、`turn_started(snapshot: BoardSnapshot)`、`reveal_started(reveal: RevealView)`、`result_shown(snapshot: BoardSnapshot)`（画面側の上部バーを描き直すため） | 試合画面の盤面・手の選択・3D 演出の表示場所・判定理由をまとめた部品。手の選択から判定理由の表示までの状態（`SELECT_ACTION`〜`SHOW_RESULT`）と、`controller` の `turn_resolved` の受信はこの部品が持つ。判定理由を出した後、`show_next` が真なら主ボタンを「次のターンへ」にして、押されたら `turn_ready_to_leave` を出す。偽なら主ボタンを隠し、判定理由を出した時点で `turn_ready_to_leave` を出す（S-08。「次へ」は画面側のボタン）。左の本体に `TacticsBoard`、右の操作の列に `ChoicePanel`・判定理由・主ボタンを置き、3D 演出は本体と操作の列を合わせた範囲に重ねる。S-03 と S-08 で共用。ルートは `Control` とし、`ReplayLayer` は全面のアンカーで重ねる |
| `ScoreBug` | `show(snapshot: BoardSnapshot)` | — | 中継風のスコア表示（「● YOU 1 – 0 CPU ◆」と時計） |
| `ScreenHeader` | `set_title(text: String)`、`set_back_label(text: String)` | `back_pressed` | 左に戻る（またはやめる）、その右に画面名。右側は画面ごとの表示（タブ・段階の番号など）に使う |
| `FormationCard` | `show(formation: FormationDef, counts: Dictionary, selected: bool, compact: bool)` | `pressed(formation_id: String)` | `compact` が真なら陣形名と ✓ だけの小さい版（S-05） |
| `SimplificationList` | `show_items(items: Array[SimplificationDef])` | — | S-10 と S-08 の最後の段階で共用 |
| `NewMatchGate` | `begin(host: Control, dialog: ConfirmDialog)` | `finished(started: bool)` | 「CPU 対戦」の確認の手順（[`screen-01-title.md`](./screen-01-title.md)「CPU 対戦を押す」）。ノードを持たない `RefCounted` |

`ToastView`（短い通知）は `MainShell` が1つだけ持ち、`App.storage_error` を受けて表示する。各画面は持たない。
