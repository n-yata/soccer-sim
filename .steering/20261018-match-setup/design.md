# 設計書

## アーキテクチャ概要

```
App._ready(): ContentRepository.load_catalog() → LibraryService.new(catalog) → App.library
MatchSetupScreen.enter(): App.library.formations() / base_counts(id) → FormationCard × 4（MiniPitch を含む）
                          方式の2択 × 2、解説欄（案内文・準備中）、開始ボタン（S-03 があるときだけ押せる）
戻る（ScreenHeader.back_pressed・handle_back）→ App.request_screen(S01_TITLE)
```

## コンポーネント設計

### 1. `LibraryService`（`game/application/library_service.gd`）
- `class_name LibraryService extends RefCounted`。`_init(catalog: ContentCatalog)`。
- `formations() -> Array[FormationDef]`: カタログの陣形を、静的データの順で返す（呼び出し側が並べ替えても影響しないよう、配列はコピーして返す）。
- `base_counts(formation_id) -> Dictionary`: `BaseLayoutDeriver.derive(formation).counts()`。存在しない ID は `push_error` して `{}`。
- 依存の向き: アプリケーション層 → ドメイン（`BaseLayoutDeriver`・`ContentCatalog`）。データ層の `ContentRepository` は `App` が使う。

### 2. `App` の変更
- `var library: LibraryService` を足す。`_ready()` で `ContentRepository.new().load_catalog()` から作る。
  - 静的データに誤りがあれば、カタログは空になり、`ContentRepository` が `push_error` する（開発時の誤り）。画面は陣形0件で表示される。

### 3. `ScreenHeader`（`game/ui/common/screen_header.tscn`・`.gd`）
- `class_name ScreenHeader extends Control`。高さ 96px。中は HBox: `BackButton`（Button。既定の文字「← 戻る」。最小 160×96）・`TitleLabel`。
- `set_title(text)`・`set_back_label(text)`、シグナル `back_pressed`。

### 4. `MiniPitch`（`game/ui/common/mini_pitch.gd`）
- `class_name MiniPitch extends Control`。`_draw()` で描く表示専用の部品（マウスを受けない）。
- `show_counts(counts: Dictionary, two_teams: bool)`: 人数を持って描き直す。`two_teams` が真の描き方は、使う画面の作業で足す（今は1チーム分）。
- `static func cell_rect(area: PitchArea, cell_size: Vector2) -> Rect2`: 列 = ゾーン（D・M・A を左から）、行 = レーン（L2〜R2 を上から）。攻撃方向が右（`screen-common.md` §5）。
- 1マスの大きさは、1チームの陣形カード用の 72×36px（`custom_minimum_size` = 216×180）。
- 描き方: 地 `pitch`、外枠と中央の線 `pitch_line`、マスの境界 `zone_line`、人数は1以上のマスだけに数字（テーマの `Label` のフォント、24px）。
- 色はテーマの型 `MiniPitch` の色（`pitch`・`pitch_line`・`zone_line`・`font_color`）から取る。

### 5. `FormationCard`（`game/ui/common/formation_card.tscn`・`.gd`）
- `class_name FormationCard extends Control`。中に全面の `CardButton`（Button、`toggle_mode`）を置き、その上に `NameLabel`・`MiniPitch`・`CheckLabel`（✓）を重ねる（文字と図はマウスを受けない）。
  - ルートを `Button` にしないのは、仕様のシグナル `pressed(formation_id)` が `Button.pressed` とぶつかるため。
- `show_formation(formation, counts, selected, compact)`（`CanvasItem.show()` とぶつかるため改名）: 陣形名・人数・選択中（`CardButton` の押した状態＝黄色の縁、`CheckLabel` の表示）を反映する。`compact` は S-05 の作業で足す（今は無視する）。
- `CardButton` が押されたら `pressed(formation_id)` を出す。選択の状態は画面が持ち、カードは `show()` で受け取った値を出すだけにする（押しただけで印を変えない）。

### 6. `MatchSetupScreen`（`game/ui/screens/s02_match_setup/`）
- `screen-02-match-setup.md` のノード構成。
  - `Header`（`ScreenHeader`）。
  - `Columns` の左 `FormationPane`（題「① 陣形」・`FormationGrid` 2列）、右 `SideColumn`（幅 480px。「② 守備方式」・2択・「③ 攻撃方式」・2択・`NotesScroll`（案内文の `Label`）・`StartButton`（高さ 112px）・「準備中」）。
- 状態 `EDITING`・`READY`。持つ値 `_formation_id`（空文字）・`_defense`（-1）・`_attack`（-1）。
- `enter()`: `App.library` から陣形カードを作り直し（前に開いたときの値を持ち越さない）、3項目を未選択にして、`apply_start_availability(MainShell.SCREEN_SCENES)` を呼ぶ。
- 方式の2択は、`toggle_mode` のボタン（`ButtonGroup` は使わない）。選ぶと値を記録し、押した状態は記録した値から `set_pressed_no_signal` で決め直す（選択中のボタンをもう一度押しても外れない）。
- カードと陣形は陣形 ID で結び付け、基本配置の人数は画面を開いたときに1回だけ求める（実装レビューの指摘）。
- 選ぶたびに `_refresh()`: カードの選択中の印、解説欄（何も選んでいなければ案内文「陣形と方式を選ぶと、ここに解説が出ます」、何か選んでいれば「解説は準備中」）、状態、開始ボタン。
- `apply_start_availability(scene_paths)`: 試合画面（S-03）が `scene_paths` にあるかを記録する。開始ボタンは「`READY` かつ S-03 がある」ときだけ押せる。S-03 が無ければ「準備中」を出す。
- 戻る: `ScreenHeader.back_pressed` と `handle_back()` は、どちらも `App.request_screen(S01_TITLE)`。`handle_back()` は `true` を返す。
- 開始ボタンを押したときの処理（`start_match`）は、試合開始を作る作業で足す。今は押せないので、押されたら何もしない（`push_error` で知らせる）。

### 7. テーマの追加
- 型 `MiniPitch` の色: `pitch` #165C34、`pitch_line` #F8FAFC（80%）、`zone_line` #F8FAFC（25%）、`font_color` #F8FAFC（`screen-common.md` §3）。
- 型の変化形: `SectionTitleLabel`（題「① 陣形」など。文字 `text_sub`）、`CheckMarkLabel`（✓。文字 `accent`）。

### 8. `MainShell` の変更
- `SCREEN_SCENES` に S-02 を足す。これでタイトルの「CPU 対戦」が押せる。

## テスト戦略

### ユニットテスト（gdUnit4）
- `tests/application/library_service_test.gd`: 4陣形の順、`base_counts("4-4-2")` を表から書いた期待値で15エリア、存在しない ID（`push_error`・空）、`App.library` が4陣形を返す。
- `tests/ui/screen_header_test.gd`: 戻るボタンで `back_pressed` が1回、`set_title`・`set_back_label`。
- `tests/ui/mini_pitch_test.gd`: `cell_rect` の4隅と中央（D-L2 は左上、A-R2 は右下、M-C は中央）、`show_counts` で保持。
- `tests/ui/formation_card_test.gd`: `show` の陣形名・選択中の印、押すと `pressed(ID)`、押しただけでは印が変わらない。
- `tests/ui/match_setup_screen_test.gd`: カード4枚と人数、未選択から `READY` まで、同じ種類の選び直し、開始ボタンの押せる条件（S-03 の有無を渡して両方）、戻る。
- `tests/ui/main_shell_test.gd`（追加）: 組み立てた `MainShell` でタイトルの「CPU 対戦」を押すと、エラーなしで試合準備に切り替わる。
- `tests/ui/title_screen_test.gd`（追加）: 「CPU 対戦」が押せる（S-02 を登録したため。動く骨格の申し送り）。

### 実際の画面での確認
- PC: `--write-movie` で、タイトル → 試合準備 → 選ぶ → 戻る、を一時的なオートロード（`override.cfg`）で操作して撮る（16:9・20:9）。確認後に一時ファイルを消す。
- エミュレーター: 試合準備を開き、戻る操作でタイトルへ戻る（アプリは閉じない）ことを、ログ（`handled=true`）とプロセスで確かめる。

## ディレクトリ構造

```
game/
├── application/library_service.gd
├── ui/common/{screen_header.tscn, screen_header.gd, mini_pitch.gd, formation_card.tscn, formation_card.gd}
├── ui/screens/s02_match_setup/{match_setup_screen.tscn, match_setup_screen.gd}
└── tests/{application/library_service_test.gd, ui/{screen_header_test.gd, mini_pitch_test.gd, formation_card_test.gd, match_setup_screen_test.gd}}
```

## 実装の順序

1. `LibraryService` と `App.library`（テスト先行）
2. `ScreenHeader`・`MiniPitch`・`FormationCard`（テスト先行）とテーマの追加
3. `MatchSetupScreen`（テスト先行）と `SCREEN_SCENES` への登録、タイトル・MainShell のテストの追加
4. PC とエミュレーターでの確認
5. 文書の更新（`component-design.md` の `LibraryService`・名前の一覧、`screen-02-match-setup.md` の作る順序、`screen-common.md` §5 の `FormationCard` のルート）

## セキュリティ・パフォーマンス
- 外部通信・保存・秘匿値は扱わない。陣形は4つで、`base_counts` は画面を開くたびに4回の計算。問題にならない。
