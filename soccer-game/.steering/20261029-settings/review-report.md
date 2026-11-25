# コミット前レビューレポート

## 第1回（2026-10-29）
- 対象: 作業ツリーの未コミットの変更すべて（設定 FR-15。`.steering/20261029-settings/` を含む）
- レビュー役: サブエージェント（opus。セキュリティ観点を含むため）
- 結果: Critical 0件 / High 1件 / Medium 1件 / Low 5件

## コミット前レビュー結果
対象: 作業ツリーの未コミット変更すべて。設定機能（FR-15）の追跡済み23ファイルと新規ファイル（settings_store / user_settings / audio_buses / settings_panel / settings_overlay / license_view / s12_settings / default_bus_layout.tres / テスト / .steering/20261029-settings）。読み取り、git diff、grep だけで確認し、ファイルは一切変更していない。

### Critical（即時対応必須）
指摘なし。

### High（優先対応）
**H-1 [セキュリティ ③インジェクション / A08 安全でないデシリアライズ] 利用者が書き換えられる settings.cfg を `ConfigFile.parse` に生のまま渡している**
- 場所: `game/data/settings_store.gd` の `_is_usable` と `load`。本体と .bak の両方が対象。
- ConfigFile の値は VariantParser（`str_to_var` と同じ書式）で解析される。値の位置に `Object(クラス名, "プロパティ": 値)` を書くと ClassDB からオブジェクトが作られ、プロパティも設定される。`Resource("パス")` を書くと ResourceLoader でそのパスが読み込まれる。
- 後段の型検査（`typeof` が FLOAT/INT/BOOL か）で値は捨てられるが、オブジェクトの生成と読み込みは parse の時点で済んでいる。どのキーにでも書けて、検査されない未知のキーでも同じ。
- 埋め込みスクリプトを持つリソースを読ませると、スクリプトのインスタンス化を通じて任意のコードが実行されうる。ConfigFile にはオブジェクトを禁止するオプションが無い。
- 前提条件: 攻撃者が user:// にファイルを置ける必要がある（デスクトップでは同じユーザーの他プロセス、または「この設定ファイルを入れて」という配布）。Android ではアプリ専用領域なので、現実の危険度は下がる。それでも NFR-09（改変ファイルの検証）の趣旨に反して fail open しているので、OWASP 該当として High に置いた。
- 修正案（どちらか）: (a) parse の前に字句で `Object(`・`Resource(` などを弾き、破損と同じ扱いにする。(b) より堅いのは、ConfigFile.parse を使わない限定パーサー。`[section]`、`key=整数|小数|true|false`、`;`/`#` のコメントだけを受け付ける。書き込みは今の `encode_to_text` のままでよい。
- 先に固定する検出テスト: `y=Object(RefCounted)` と `y=Resource("res://...")` のケースを足す。
- 補足: Godot 4.7 本体のソースでの再確認はしていない（未検証欄を参照）。

### Medium（対応推奨）
**M-1 [バグ / 運用: 元のファイルを失わない] 本体が壊れていて .bak が読めるとき、壊れた本体を退避しないので、次の保存で静かに消える**
- 場所: `settings_store.gd` の `load()`。
- `SaveFileIO.read` は .bak を返し、状態は OK になる。本体は壊れたまま残る。次の `save()` で `SaveFileIO.write` が動くと、壊れた本体は .bak へ回り、最後に .bak ごと消される。退避も通知も無い。
- RecordStore はこのケースを明示的に処理している（壊れた本体を退避してから .bak を使う）。設定だけが抜けていて、共用化の途中で揃っていない。
- 修正案: `load()` の `SaveFileIO.read` の前に RecordStore と同じ分岐を入れる。テストに「壊れた本体と正しい .bak」のケースを足す。

### Low / 改善提案
- **L-1 [運用 / テストの独立性]** 試合中の設定のテストは実際の AudioServer の SE バスを変えるが、after_test で戻していない。MainShell のテストも起動時の反映でバスを初期値 0.7 に変える。settings_screen_test の after_test は「元へ戻す」と言いながら、元の 0dB ではなく初期設定 0.7 を当てている。今のところ誤判定にはならない。直すなら、テスト前の音量とミュートを控えて書き戻す。
- **L-2 [バグ / 操作性]** 重ねた設定を閉じた後、メニューの `focus_first()` を呼ばないので、キーボードやゲームパッドではフォーカスが無い状態になる（タッチ操作では影響なし）。
- **L-3 [バグ / 未テスト経路]** `set_show_hints` で、READY かつ運ぶ先がある状態から描き直す経路はテストが無い（SELECT_TARGET だけ）。コードを読む限り正しく動く。
- **L-4 [運用 / ドキュメント]** `game/application/app.gd` のコメントに「設定は、それぞれの作業で足す」が残っている。
- **L-5 [バグ / 軽微]** settings.cfg に刻み 5 に乗らない値（例 0.33）があると、スライダーは 35 に丸めて表示し、持っている値は 0.33 のまま。次に操作すれば揃う。

### 問題なし
- **① ハードコーディング / シークレット**: `export_presets.cfg.example` の差分は include_filter に `assets/fonts/*/OFL.txt` を足しただけ。keystore やパスワードの項目は無い。実ファイル `export_presets.cfg*` は .gitignore で除外を確認した。.steering、docs の差分、default_bus_layout.tres に URL、キー、アカウント情報、個人のパスは無い。LicenseView のパスは同梱素材の res:// だけ。
- **② 認証・認可**: 該当なし（オフライン単体、アカウントなし）。
- **④ 情報漏洩**: push_error に出るのはバス名と res:// パスだけ。設定の値はログに出していない。
- **settings.cfg の値の検証**: 音量は INT/FLOAT のみ受け付け、`is_finite` と範囲を肯定形で確かめるので、NaN と inf も弾ける。真偽値は TYPE_BOOL のみ。format_version が無い、整数でない、1未満の場合は破損として退避する。新しい版は書き込まない。退避に失敗したら保存を断る。読み込みは 5MB で上限がかかる。
- **RecordStore の退避の共用化（退行なし）**: `SaveFileIO.move_aside` は移す前と同じ名前を作る。連番の上限、ファイルやディレクトリがあるときの扱い、戻り値も同じ。.bak の後始末も残っている。
- **UserDataService**: 写しを返す。保存に失敗しても持っている値は更新する。失敗の通知は続く間1回で、新しい版は読み込みの時点で失敗中として扱う。読み込みは最初の1回だけ。
- **テストの保存先**: 試合画面や設定を開くスイートは、どれも一時ディレクトリへ差し替え、after_test で戻している。本物の user:// を読み書きする経路は見当たらない。
- **ヒント OFF**: `user_hints()` を呼ばない。試合中に切り替えると描き直す。
- **性能**: 保存はスライダーを離したとき、キー操作の1刻み、トグルの切り替えのときだけ。数百バイトのファイルを1回読んで1回書くだけ。

### 未検証
- H-1 の前提である「Godot 4.7 の ConfigFile.parse が `Object(...)` と `Resource(...)` を解析して生成・読み込みする」点は、記憶している実装と公式ドキュメントの関連警告に基づく判断で、4.7 本体のソースや実行では確かめていない。
- 書き出した APK に OFL.txt が実際に入るか（include_filter の照合）は、書き出しをしていないので確かめていない。
- docs/specs の差分は component-design.md だけ読んだ。screen-01 / 03 / 12 / common の文面は、機密情報の grep だけ。

### 総合評価
Critical は無し、High は1件（H-1）。H-1 の検出テストを先に固定し、字句チェックか限定パーサーで fail open を塞いでからコミットするのを勧める。M-1 も、RecordStore と揃える小さな修正なので同じコミットで直すのが望ましい。それ以外は Low で、コミットを止める理由にはならない。

### 対応
- **H-1（直した）**: `SettingsStore` の読み込みで `ConfigFile.parse` を使うのをやめ、この設定が使う書式だけを受け付ける限定の読み方（`SettingsStore.parse`）にした。受け付ける行は「[節]」「キー=値」「;・# の注釈」「空行」、値は整数・小数・true・false。単純な文字列と英字だけの語は型違いとしてキーごとに初期値（data-definition.md §2.4 のキー単位の扱いを保つ）。組み立てる書き方（`Object(...)`・`Resource(...)`・`Vector2(...)` など）と、引用符で囲んだキーを含むファイルは破損として退避する。書き込みは `encode_to_text` のまま。
  - 先に検出テスト `test_values_that_would_build_objects_or_load_resources_are_rejected_as_broken` を書き、直す前は `Resource(...)`・`Vector2(...)`・引用符のキーのケースが破損にならない（`OK` で読める）ことを確かめた（Red。`Resource(...)` が通ったことで、ConfigFile が解析していたことも確かめられた）。直した後は通る。限定の読み方の誤りを素通しにする変異（値が読めなくても続ける）で落ちることを確かめた
- **M-1（直した）**: 戦績と同じく、本体と `.bak` の両方があり本体が使えないときは、本体を退避してから `.bak` を使う。テスト `test_a_broken_main_file_is_moved_aside_when_the_backup_is_used`（退避したファイルが残り、保存しても消えない）を足し、変異で落ちることを確かめた。あわせて実装検証の推奨2の「退避できなければ保存を断る」のテスト `test_a_broken_file_that_cannot_be_moved_aside_is_not_overwritten` を足した
- **L-1（直した）**: バスの音量とミュートを before_test で控え、after_test で戻す補助（`ScreenTestHelper.save_buses`・`restore_buses`）を足し、設定の画面・試合中のメニュー・MainShell のテストで使う
- **L-2（直した）**: 重ねた設定を閉じたら、メニューの最初のボタンへフォーカスを戻す（テストと変異で確かめた）
- **L-3（直した）**: 運ぶ先まで選んだ後（READY）に切り替えても選択が保たれるテストを足した（変異で確かめた）
- **L-4（直した）**: `app.gd` の古いコメントを直した
- **L-5（直さない）**: 刻み 5 に乗らない値は、次に操作すれば揃う。手で書き換えたときだけ起きる
- 変異: `volume_nan`（`is_finite` を外す）は生き残る。限定の読み方は NaN を作らず、`1e999` から作られる無限大は範囲の比較で外れるため、外しても結果が変わらない（等価な変異）。規約（「`is_finite` で NaN・無限大を拒否する」）に合わせて残す

## 第2回（2026-10-29）— 修正後の再レビュー
- 対象: H-1・M-1・L-1〜L-4 の修正と、それが触った箇所の周辺（settings_store.gd・save_file_io.gd・match_menu_host.gd・modal_overlay.gd・screen_test_helper.gd・settings_store_test.gd・component-design.md）
- レビュー役: サブエージェント（opus）
- 結果: Critical 0件 / High 0件 / Medium 0件 / Low 4件

### 前回指摘の解消状況
- **H-1: 解消。** 読み込みの経路から ConfigFile.parse / load は無くなった（game/ 配下に ConfigFile の読み込みも str_to_var / bytes_to_var も残っていない。ConfigFile は書き込みの encode_to_text だけ）。`_scalar` が返すのは bool・int・float・String だけで、それ以外は null（破損）なので、オブジェクトの生成やリソースの読み込みにつながる道は無い。節より前のキー・空の値・末尾に注釈が付いた値・引用符で囲んだキー・`Object(`・`Resource(`・`Vector2(` は破損、文字列や nan・inf は型違いとしてキーごとに初期値、1e999 は inf になり is_finite で初期値、format_version が小数・bool・文字列なら破損。encode_to_text の出力（`key=value`、"0.25"・"1.0"・"1e-05"、"true"/"false"、CRLF も strip_edges で読める）とも噛み合う。設定のファイルは今回新しく足すので、既に保存された古い形式の問題は無い。
- **M-1: 解消。** 本体が壊れていて .bak が読めるとき（本体を退避 → .bak で OK → 次の save で .bak が消え、退避したファイルは残る）、両方壊れているとき（両方退避。同じ秒なら連番）、退避できないとき（CORRUPTED・save は false）、新しい版の本体（退避しない）のどれも正しい。
- **L-1: 解消。** 3つのスイートが save_buses / restore_buses を呼んでいる。
- **L-2: 解消。** `_settings.closed.connect(_menu.focus_first)`。メニューが閉じた後に呼ばれても害は無い。
- **L-3: 解消。** READY からの描き直しのテストが入った（フォーカスも確認）。
- **L-4: 解消。**
- **L-5:** 受け入れ済み。変化なし。

### Critical / High / Medium
なし

### Low / 改善提案
- **L-6 [運用 / 先の版との互換]** `_is_usable` は先に `parse` を通すので、将来の版の settings.cfg に配列・Color(...)・エスケープを含む文字列などが入ると、format_version=2 でも NEWER_VERSION にならず CORRUPTED として退避され、v1 のファイルで上書きされる。戦績（新しい版は中身を確かめない）とも、仕様の「新しい版は上書きしない」とも食い違う。退避するのでデータは消えず、起きるのは古い版へ戻したときだけ。直し方: 厳密な読み方に失敗したときだけ、`format_version=<整数>` の行を緩く拾い、今の版より大きければ NEWER_VERSION にする（Object/Resource は評価しないので安全性は変わらない）。あるいは、将来の版でも値を限ると仕様書に書く。
- **L-7 [テスト]** M-1 の分岐の「退避に失敗した」経路（本体が壊れていて .bak があり、退避先がすべて塞がっている）を直接通すテストが無い（今のテストは .bak が無い状態）。
- **L-8 [性能]** 1回の load() で同じ本文を最大3回解析している。数百バイトなので実害は無い。
- **L-9 [テスト補助]** `restore_buses` はバスの index が -1 でも呼ぶ。今はレイアウトがあるので問題ない。

### 問題なし
- 修正箇所・新しいファイルに URL・シークレット・クラウドのアカウント情報のハードコーディングは無い（grep で確認）。
- 正規表現はどれも ^…$ で固定され、後戻りが爆発する書き方は無い。18 桁を超える整数は文字列（型違い）。
- component-design.md の記述と、match_menu_host の冒頭コメント・戻る操作の順は実装と一致している。

### 未検証
- ConfigFile.parse が Object/Resource を組み立てる前提は 4.7 のソースでは確かめていないが、読み込みに使わなくなったので結論は左右されない（依頼元の Red のテストで、直す前に `Resource(...)` を含むファイルが OK で読めたことは確かめてある）。
- encode_to_text の小数の書式（指数表記・inf_neg）は 4.7 で実行して確かめていない。読み戻しのテストは 0.25・1.0・0.7 の範囲。
- 修正が触っていない部分は、指示どおり再レビューしていない。

### 総合評価
H-1・M-1・L-1〜L-4 はすべて解消し、修正による Critical / High / Medium は無い。コミットは進めてよい。L-6 は直すか制約として書くかを今回のうちに決めるのがよい。

### 対応（第2回）
- **L-6（直した）**: 限定の書式で読めないファイルでも、`format_version=<整数>` の行だけを拾い、今の版より新しければ新しい版として扱う（中身を確かめず、退避も上書きもしない。値は組み立てない）。テスト `test_a_newer_version_with_values_this_version_cannot_read_is_kept_as_newer`（Color(...)・配列を含む版 3 のファイル）を足し、変異で落ちることを確かめた
- **L-7（直した）**: 本体が壊れていて .bak があり、退避先がすべて塞がっている経路のテスト `test_a_broken_main_file_that_cannot_be_moved_aside_is_kept_even_with_a_backup` を足した（退避先を塞ぐ補助を共用にした）
- **L-8（直さない）**: 数百バイトのファイルで、起動時と保存時だけ
- **L-9（直さない）**: バスのレイアウトを同梱している間は起きない
- 第2回は Low だけなので、規則どおり再レビューは行わない（テストと変異で確かめた）

## レビュー完了（2026-10-29）
- 最終ラウンド: 第2回
- 新たな Critical / High: なし
- 積み残し: L-5（刻み 5 外の値の表示のずれ。手で書き換えたときだけ）、L-8（同じ本文の解析が最大3回）、L-9（バスが無いときの restore_buses）。いずれも悪用できる欠陥ではない
