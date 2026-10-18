# 要求内容

## 概要

試合準備（S-02）の画面を作る。タイトルの「CPU 対戦」から開き、陣形（4つ）・守備方式・攻撃方式を選べて、戻る操作でタイトルへ戻れる。
あわせて、次の2つを作る。
- 陣形の一覧と基本配置の人数を返す `LibraryService`
- 画面をまたいで使う部品（`ScreenHeader`・`FormationCard`・`MiniPitch`）

## 背景

- 動く骨格（`../20261018-walking-skeleton/`）ができ、画面を作って `MainShell.SCREEN_SCENES` に足せば、タイトルから開けるようになった。
- 試合準備は、ルールの土台（陣形データ・基本配置の導出）をそのまま画面に出せる。PC で触って確かめられる最初の画面になる。
- 動く骨格からの申し送りが2つある。
  - 行き先の画面ができたら、タイトルのカードが押せるようになることをテストで確かめる。
  - 画面の入れ替えを遅らせて呼ぶので、押されたボタンの処理の途中でエラーが出ないことを確かめる。

## 決定事項（2026-10-18 シャビの指示「試合準備に進んで」を受けた範囲）

- **解説欄の中身は作らない**。
  - 方式の解説文（`styles.json`）は「新規に作る」とされていて、まだ無い（`functional-overview.md` アルゴリズム9）。
  - 陣形の解説には、噛み合わせルールと解説の導出が要る。
  - 戦術の解説文は製品の中身なので、画面の作業のついでには作らない。解説欄には案内文を出し、何かを選んだら「解説は準備中」と出す。
- **試合開始は作らない**。`MatchController`（試合の進行・保存）と試合画面（S-03）が無いため。
  - 3項目を選び終えても、試合画面ができるまでは「準備中」と出して押せないようにする。行き先の画面が無いものを押せなくする、という動く骨格の方針に合わせる。
- 画面の状態は、`EDITING`（選んでいる途中）と `READY`（3項目を選んだ）だけを持つ。`STARTING` は、試合開始を作る作業で足す。

## 実装対象の機能

### 1. `LibraryService`（`game/application/library_service.gd`）と `App.library`
- `formations() -> Array[FormationDef]` と `base_counts(formation_id) -> Dictionary` を持つ（`component-design.md` §3.4）。
  - 基本配置は `BaseLayoutDeriver` で求める（そのチーム自身の視点）。
- `App` は起動時に、`ContentRepository` で静的データを読み、`LibraryService` を作って `library` に持つ。
- ほかの関数（`matchup_counts`・解説・単純化）は、それを使う作業で足す。

### 2. 共通の部品（`game/ui/common/`。`screen-common.md` §5）
- `ScreenHeader`: 左に戻るボタン、その右に画面名。`set_title()`・`set_back_label()`、シグナル `back_pressed`。高さ 96px（`screen-common.md` §1.1）。
- `MiniPitch`: 15エリアの人数を、作戦ボードと同じ向きで描く。
  - 向きは、3列（左から D・M・A）×5行（上から L2〜R2）で、攻撃方向が右。
  - `show_counts(counts, two_teams)` を持つ。今回は1チームの人数だけを描く。
  - 2チームの表示（`two_teams` が真）と `show_movements()` は、使う画面の作業で足す。
- `FormationCard`: 陣形名・`MiniPitch`・選択中の印（枠と ✓）を持つ。`show(formation, counts, selected, compact)`、シグナル `pressed(formation_id)`。
  - 押せる範囲はカード全体。
  - `compact`（S-05 の小さい版）は、S-05 の作業で足す。

### 3. 試合準備の画面 `MatchSetupScreen`（`game/ui/screens/s02_match_setup/`）
- `screen-02-match-setup.md` のノード構成のとおりに作る。
  - 上にヘッダー（「← 戻る」・「試合準備」）。
  - 左の本体に、陣形カード4枚を2×2で置く。
  - 右の操作の列に、守備方式・攻撃方式の2択、解説欄、開始ボタンを置く。
- 3項目は未選択から始める。選ぶと、選択中の印が付く。
- 3項目すべてを選ぶと `READY` になる。
- 開始ボタンは、`READY` かつ行き先の画面（S-03）があるときだけ押せる。今は「準備中」と出して押せない。
- 戻る（ヘッダーのボタン・Android の戻る操作・Esc）で、タイトルへ戻る。`handle_back()` は `true` を返す。
- `MainShell.SCREEN_SCENES` に登録する。これで、タイトルの「CPU 対戦」が押せるようになる。

## 受け入れ条件

### LibraryService
- [ ] `formations()` が4陣形（4-4-2・4-3-3・4-2-3-1・3-5-2）を、静的データの順で返す。
- [ ] `base_counts("4-4-2")` が、アルゴリズム1の表（D: 1 0 2 0 1 など）と15エリアすべてで一致する。期待値は表から書く。
- [ ] 存在しない陣形 ID では、空の結果を返し、エラーを出す。
- [ ] `App.library` が起動時に作られ、4陣形を返す。

### 共通の部品
- [ ] `ScreenHeader`: 戻るボタンを押すと `back_pressed` が1回出る。`set_title()`・`set_back_label()` が表示に効く。
- [ ] `FormationCard`: `show()` で陣形名と人数が表示され、`selected` で印が切り替わる。押すと `pressed(陣形 ID)` が出る。
- [ ] `MiniPitch`: `show_counts()` で渡した人数を持ち、エリアのキーから描く位置（列 = ゾーン、行 = レーン）が正しい。

### 試合準備の画面
- [ ] 開くと陣形カードが4枚、静的データの順で並ぶ。各カードの人数は `base_counts()` と一致する。3項目は未選択で、開始ボタンは押せない。
- [ ] 陣形・守備方式・攻撃方式を選ぶと、選択中の印が付く。同じ種類の別のものを選ぶと、前の印が外れる。
- [ ] 3項目を選ぶと `READY` になる。行き先の画面（S-03）があれば開始ボタンが押せ、無ければ押せずに「準備中」が出る。対応を渡して両方を確かめる。
- [ ] 戻るボタン・`handle_back()` で、タイトルの画面が要求される。`handle_back()` は `true` を返す。
- [ ] タイトルの「CPU 対戦」が押せる（S-02 を登録したため）。押すと試合準備の画面に切り替わる（組み立てた `MainShell` で、押されたボタンの処理の途中でエラーが出ないことも確かめる）。

### 実際の画面での確認
- [ ] PC で、タイトル →「CPU 対戦」→ 試合準備 → 選ぶ → 戻る、を操作して画面を撮る（16:9 と 20:9）。
- [ ] 書き出した APK をエミュレーターで起動し、試合準備の画面を開いて、戻る操作でタイトルへ戻る（アプリは閉じない）ことを確かめる。

### 共通
- [ ] `tools/run-tests.sh` が成功する。型の警告（エラー扱い）が 0 件。

## 成功指標

- シャビが PC で、タイトルから試合準備の画面を開き、陣形と方式を選べる。
- 4陣形の違いが、ミニピッチの人数で見て分かる。

## スコープ外

- 解説欄の中身。方式の解説文（`styles.json`）、噛み合わせルール、解説の導出（アルゴリズム9）、`NotesView`。
- 試合開始（`MatchController.start_match`）、`STARTING` の状態、試合画面（S-03）。
- `FormationCard` の小さい版（`compact`）、`MiniPitch` の2チームの表示・動きの矢印。
- `LibraryService` のほかの関数。

## 参照ドキュメント

- `docs/specs/2_basic-design/screen-design.md` - S-02
- `docs/specs/3_detail-design/screen/screen-02-match-setup.md` - ノード構成・状態・イベント
- `docs/specs/3_detail-design/screen/screen-common.md` - §1.1（配置の寸法）、§3（配色）、§4.1（入力）、§5（共通の部品）
- `docs/specs/2_basic-design/component-design.md` - §3.1（`App`）、§3.4（`LibraryService`）
- `docs/specs/1_requirements/functional-overview.md` - アルゴリズム1
