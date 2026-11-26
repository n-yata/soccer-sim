# コミット前レビューレポート

## 第1回（2026-11-27）
- 対象: feature/portrait-match の未ステージ差分（コード・設定・テスト・設計書）と `soccer-game/.steering/20261127-portrait-match/`。
  `*.import` の改行コードのみの差は対象外
- 結果: Critical 0件 / High 0件 / Medium 1件 / Low 3件

## コミット前レビュー結果

対象: worktree `soccer-sim-worktrees/portrait-1`（feature/portrait-match）の未ステージ差分。`*.import` は改行コードのみの差なので除外した。見たのはコード（main_shell.gd, screen_switcher.gd, app_screen.gd, match_board_panel.gd, title_screen.gd/.tscn, match_setup_screen.gd/.tscn, match_screen.gd）、設定（project.godot, export_presets.cfg.example）、テスト5本とフィクスチャ、仕様書の差分、未追跡の `.steering/20261127-portrait-match/`（requirements.md, design.md, tasklist.md）。

### Critical（即時対応必須）
- 指摘なし

### High（優先対応）
- 指摘なし

### Medium（対応推奨）
- [バグ] 縦の S-03 が収まることを確かめているのは「余白なしの 720×1280」だけ: `test_portrait_puts_the_board_above_the_controls_inside_the_screen` は `screen.size = Vector2(720, 1280)` でしか検査していない。縦では MainShell がセーフエリアの分を ScreenRoot の上下の余白に足すので、16:9 の端末（keep_width だとちょうど 720×1280）で切り欠きがあると、画面が使える高さは 1280 を下回る。immersive_mode=true なので差し引かれるのは切り欠きの分だけだが、その分の高さの余裕が今回の差分のどこにも示されていない。NFR-25 は今回の改訂で「縦でも 16:9〜21:9 で欠けない」と約束している。足りなければ、作戦ボードの下端や主ボタンが**エラーも出さずに**画面の外へ切れる（静かに誤る型）。ブラウザで確かめたのは 390×844（約 19.5:9。この経路は `OS.has_feature("mobile")` が偽なのでセーフエリアの余白が掛からない）だけで、16:9 の高さぎりぎりで余白が付く場合は誰も確かめていない。
  → 余白込みの最小の高さで収まるかを検査するテストを足す。あわせて縦の S-03 の最小の高さ（12 + 96 + 72 + 600 + 16 + 操作の列の最小の高さ + 12）を設計書に書き、16:9 から何 px の余白まで収まるかを明示する。
  収まらないと分かったら、NFR-25 の文言（縦の 16:9 で切り欠きがある場合）を直すか、操作の列をスクロールにするかを決める。

### Low / 改善提案
- [運用] main_shell.gd 193 行目で改行が失われ、三項演算子の途中に連続したタブが入った約 200 文字の1行になっている。GDScript としては動く（テストも通っている）が読みにくい。`if portrait:` / `else:` の2分岐に書き直すのを勧める。
- [性能/バグ（実害なし）] `_apply_orientation`（MainShell）が `content_scale_aspect` と `content_scale_size` を書き換えると、その場で size_changed が来る。このとき `_switcher.set_portrait` はまだ呼ばれていないので、`_on_viewport_size_changed` がもう一度 `_apply_orientation.call_deferred` を積む。2回目は同じ値を入れ直すだけで、画面側は `set_portrait` の早期 return で組み替えないため、ループや状態の破損にはならない。`_switcher.set_portrait(portrait)` を書き換えより先に呼べば再投入されない。直すかは任意。
- [バグ（確認済みで問題なし、申し送り）] S-03 の `_apply_orientation` は、横へ戻すときに `reparent` でラベルを TopBar の末尾へ戻す。メニューのボタンは MatchMenuHost が `move_child(_button, 0)` で先頭に置いているので、並びは元と同じ。今後 TopBar の末尾に別の要素を足すとこの前提が崩れるので、元の位置に戻す形にしておくと安全。

### 問題なし
- セキュリティ①: 差分（コード・設定・仕様書・steering）に URL、API キー、トークン、アカウント ID、ARN は無い（追加行を URL・ARN・12桁の数字で走査した）。export_presets は `.example` の向きの値だけを変えており、署名鍵などは含まない。
- セキュリティ②〜④: 認証・認可・外部入力・ログ出力・エラー応答を持たないオフラインの UI 配置の変更で、該当なし。OWASP の各カテゴリに当たる差分も無い（依存の追加なし）。
- セキュリティ（設定）: `handheld/orientation` の 4→6（Sensor）と PWA `orientation` の 1→0（Any）は意図どおりの値。
- バグ: `side_margins` を `_edge_margins` へ切り出したが、計算は元と同じ（負にしない、0 除算の早期 return を保持）。`top_bottom_margins` も窓の大きさ 0・safe_area の大きさ 0・はみ出しの場合をテストしている。
- バグ: `ScreenSwitcher.open` は `add_child` の後、`enter` の前に `set_portrait` を呼んでいる。そのため title・setup の @onready 参照も、match の `_build` で作るノードも、組み替えの時点で揃っている。
- バグ: `AppScreen.set_portrait` は同じ向きなら何もしないので、横で開いた画面は組み替えを呼ばない（テストで固定済み）。
- バグ: 横へ戻すときの値は、tscn の既定値か @onready で保存した値と一致しており、元の配置に戻る。
- バグ: タイトルの `_fit_small_cards` は `place_tutorial_card` からも呼ばれ、チュートリアルのカードが移動して段の数が変わっても追随する。カードが 0 枚でも負にならない。
- バグ: HBoxContainer→BoxContainer で横の既定は vertical=false。挙動は同じで、既存テストが通っている（依頼元の報告: 1231 件）。
- バグ（テスト）: 新しいテストは具体的な矩形・状態・呼ばれた順を検証しており、恒真のアサーションは無い。
- 性能: 組み替えは向きが変わったときだけで、ループ内の I/O も上限の無い処理も無い。
- 運用: revert で戻せる変更。仕様書（NFR-25、requirements-definition、repository-structure、screen-common §1.2、各画面）を同じ差分で更新している。

### 未検証
- 実機の Android での表示（切り欠きのある端末、16:9・21:9 の縦、180° 回転）は確かめていない。読んだのはコードとテストだけで、Godot は実行していない。
- 縦の S-03 で、操作の列（手のボタンのスクロール）の最小の高さの実値は計算していない。
- `wireframes.drawio` の差分は、URL 等の機密を走査しただけで、図の中身の妥当性は見ていない。
- MatchBoardPanel を使う S-03 以外の画面（チュートリアル等）は縦の配置を持たない（設計書で「順に足す」と明記）。

### 総合評価
**Critical / High はなし。コミットしてよい。** Medium の1件は実機で表示が切れうる「静かに誤る」型なので、余白込みの検査テストを先に固定することを勧める。Low はどれも任意。

### 対応
- Medium（余白込みの 16:9 で収まるかを確かめていない）: テスト `test_portrait_fits_a_16_9_screen_with_cutout_margins` を足した
  （720 × 1184。上下合わせて 96px の余白）。作戦ボード・手のボタン・主ボタン・詳細が画面に収まり、画面の最小の高さが画面の高さ以下で
  あることを確かめた（通った。いまの配置で収まる）。`screen-common.md` §1.2 に「16:9 で上下合わせて 96px の余白まで収まる」を書いた。
  なお、このテストは今の実装の性質を固定するもので、実装前の Red は無い（収まらない配置に変えたときに赤になる）
- Low（三項演算子の行）: `if portrait:` / `else:` の2分岐に書き直した（前の編集で行の継続の `\` が失われていた）
- Low（向きを変えるたびの再投入）: `MainShell._apply_orientation` で、基準解像度を変える前に `_switcher.set_portrait` を呼ぶ順にした。
  ブラウザ版で、横へ回して戻しても配置が正しく組み替わり、画面が歪まないことを確かめ直した
- Low（TopBar へ戻すときの位置）: 直さない。いまの並びは元と同じで、申し送りとして記録する（TopBar の末尾に要素を足すときは、
  `_apply_orientation` で元の位置へ戻す形に変える）
- 修正後、`run-tests.sh` で 86 スイート・1232 件成功
- Medium 以下の修正のため、再レビューは行わない（収束条件は新たな Critical / High が無いこと）

## レビュー完了（2026-11-27）
- 最終ラウンド: 第1回
- 新たな Critical / High: なし
- 積み残し: Low 1件（TopBar へ戻すときの位置。上のとおり、要素を足すときに直す）
- 未検証のまま残るもの: Android 実機（切り欠きのある端末・16:9 と 21:9 の縦・180° 回転）。ワイヤーフレームの見た目（XML の検証のみ）
