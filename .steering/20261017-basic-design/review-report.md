# コミット前レビューレポート

## 第1回（2026-10-17）
- 対象: `docs/specs/2_basic-design/{component-design.md, usecase.md, screen-design.md, wireframes.drawio}`、`.steering/20261017-basic-design/{requirements.md, design.md, tasklist.md}`、`docs/specs/1_requirements/{functional-overview.md, architecture-overview.md, glossary.md, repository-structure.md}` の変更、`docs/specs/2_basic-design/.gitkeep` の削除
- 結果: Critical 0件 / High 7件 / Medium 7件 / Low 9件

### Critical（即時対応必須）
指摘なし。

### High（優先対応）

**H1【バグ/運用】終了処理が失敗した試合も、結果画面からタイトルへ戻ると中断データが消え、戦績が二度と記録されない**
- 箇所: component-design.md §3.2「試合の終了処理」と `leave_result`、usecase.md UC-01③・UC-04（`leave_result` → `delete()`、削除の時点②）
- 内容: `RecordStore.append` が失敗すると中断データは `IN_PROGRESS` のまま残り、「次の起動時にやり直す」前提になっている。しかしアプリを閉じずに「タイトルへ」を押すと `leave_result()` が無条件に `delete()` し、やり直しの材料が消える。戦績は記録されず、気づく手段もない。起動時のやり直し（`FINALIZED`）で再び `append` が失敗し、そのまま CPU 対戦を始めた場合も、`start_match` の上書きで同じことが起きる
- 修正案: `MatchController` に終了処理の完了状態を持たせる。`leave_result` は未完了なら `append` → `finish` → `save` を再試行し、それでも失敗したら中断データを消さずに残す（次回の起動でやり直す）と明記する。正本（functional-overview.md「試合終了から破棄までの順序」③）にも「終了処理が済んでいる場合に限り削除する」旨を昇格させる

**H2【バグ】中断データを試合準備（S-02）に入る前に消すため、S-02 で「戻る」と試合を始めないまま中断データだけ失われる。正本の削除の時点①とも食い違う**
- 箇所: usecase.md UC-01①（`discard_suspended()` → `delete()` を S-02 遷移前に行う）、screen-design.md S-01「CPU 対戦を押す（中断中の試合あり）」、S-02「戻る → S-01（何も保存しない）」、S-11 の空の表示からの CPU 対戦
- 内容: 正本の削除の時点①は「新規試合**開始時**（利用者の確認後）」。設計は確認の直後に削除しており、S-02 から戻ると中断中の試合が消える
- 修正案: 確認の結果だけを受け渡し、実際の削除（または上書き）は `start_match` の中で行う。`save` は単一ファイルの上書きなので、`discard_suspended` は不要にできる

**H3【バグ】チュートリアルが本番と同じ `MatchController` を状態の切り替えで使い回しており、状態のリセットが漏れる**
- 箇所: component-design.md §3.2 `start_tutorial`・§3.3・保存の時点の表（`submit_turn` は無条件に `save`）、usecase.md UC-06（「相手を ScriptedOpponent に差し替え。保存しない」）、screen-design.md S-08「やめる」
- 内容と影響:
  - (a) `ScriptedOpponent` を `CpuOpponent` に戻す時点が未定義。チュートリアル後の CPU 対戦で、CPU の陣形・手が台本どおりになるおそれがある
  - (b) 「保存しない」の切り替えを戻し忘れると、本番の試合が保存されない。逆に切り替えが効かないと、チュートリアルの状態が利用者の中断データを上書きする
  - (c) 起動時に再開可能と判定した試合をメモリに持っている場合、チュートリアルで状態が置き換わり、`resume()` がチュートリアルの状態を再開しうる
- 修正案: チュートリアル専用のインスタンスを使う（`ScriptedOpponent` と保存しない Store を注入した別の `MatchController`、または `TutorialSession`）。`resume()` は必ず `SuspendedMatchStore.load()` から読み直すと明記する

**H4【バグ】結果画面の値の出どころが文書間で食い違い、どちらの通りに実装しても表示できない**
- 箇所: screen-design.md S-06（勝敗・最終スコア・推移は `match_finished` の `MatchRecord`）、usecase.md UC-01③（`Result->>MC: snapshot()`）、component-design.md §3.2（`match_finished` は `submit_turn` の中で出す）
- 内容: `match_finished` は結果画面ができる前（`continue_after_reveal` より前）に出る。さらに S-07 から S-06 に戻るときには出ないので、結果画面はシグナルを受け取れない。一方 `snapshot()`（`BoardSnapshot`）には勝敗と陣形・方式の推移がない
- 修正案: `MatchController.final_record() -> MatchRecord`（取得用のメソッド）を足し、S-06 は画面を開くたびに呼ぶ。usecase と screen-design の表記を揃える

**H5【バグ】タイトルの「再開カード」の有無が起動時にしか判定されず、同じセッションの中では古い状態のまま使われる**
- 箇所: screen-design.md S-01（再開カードは `inspect_suspended()` が `RESUMABLE` のときだけ。`MainShell` が起動時に呼ぶ）、component-design.md §5.1、`suspend_to_title`／`leave_result`／`discard_suspended`
- 影響:
  - 起動後に始めた試合をメニューから中断すると、タイトルに再開カードが出ない。「CPU 対戦（中断中の試合なし）」の経路になり、確認なしで `start_match` が中断データを上書きする（FR-01 の確認を素通りする）
  - 逆に、再開した試合を最後まで終えて `leave_result` で削除した後もカードが残り、削除済みの試合の `resume()` を呼ぶ
- 修正案: `MatchController.suspended_status()` を足し、`start_match`・`suspend_to_title`・`leave_result`・`discard_suspended` で状態を更新する。タイトルは画面を開くたびにこれを呼ぶ。`inspect_suspended()` は起動時の後始末（削除・やり直し）だけを受け持つ

**H6【バグ/運用・データ損失】戦績・回答結果・設定が壊れている（または今より新しい版の）場合、初期状態として扱った後の最初の保存で元のファイルを上書きし、恒久的に失う**
- 箇所: component-design.md §4.3（`load_all` は破損なら空配列、`append` で全体を書き直す、`format_version` が今より新しければ「破損」）、usecase.md UC-07・UC-09
- 内容: 正本は「初期状態として扱う」とだけ定め、上書きまでは求めていない。しかし今の設計では、破損と判定した直後の `append`／`save` が、新しい1件だけのファイルで本体を置き換える。次の場合に、過去の戦績・回答がすべて消える
  - 新しい版で保存したデータを古い版で開いた（ダウングレード。Steam のベータ版の切り替えなどで現実に起こる）
  - 検証が厳しすぎて、正常なデータを破損と誤判定した
- 修正案:
  - 破損と判定したファイルは、書き込む前に `<名前>.corrupt`（日時つき）へ退避する
  - `format_version` が今より新しい場合は「破損」と区別し、書き込みを禁止する（読み取りのみで初期状態を表示する）
  - NFR-09・NFR-26 のテスト観点に「破損時に元ファイルが残る」を加える

**H7【バグ】ハーフタイムのミニピッチの優劣を、視点を変換せずに比べる設計になっている**
- 箇所: screen-design.md S-05「前半の噛み合わせ（ミニピッチ）: `LibraryService.base_counts()`（両チーム分）」、component-design.md §3.4 `base_counts`、§3.5（UI は座標の変換をしない）
- 内容: `base_counts` は各チーム自身の視点の人数。相手を鏡像に変換しないまま比べると、自陣 `D-L2` の自分の人数が相手の `D-L2`（本来の対応は `A-R2`）と比べられ、優劣記号が何の警告もなく誤って表示される。UI に変換を禁じているため、正しく描く経路が設計上ない
- 修正案: `LibraryService.matchup_counts(user_formation_id, opponent_formation_id)` のように、利用者の視点に揃えた両チームの人数を返すメソッドを足し、S-05 はそれを使う

### Medium（対応推奨）
- **M1【バグ】`.bak` から削除済みの中断データが復活しうる**（component-design.md §4.3）: 「本体が無く `.bak` が読めるなら `.bak` を使う」一方、`delete()` が `.bak`・`.tmp` も消すとは書かれていない。書き込み手順2〜4の間で止まって `.bak` が残った後に `delete()` すると、次の読み込みで古い試合が復活する → `delete()` は本体・`.bak`・`.tmp` をすべて消すと明記する
- **M2【バグ】`resolve_turn` が `null` を返したときの扱いが無い**（component-design.md §2.5・§3.2、usecase.md UC-01②）: `submit_turn` は `void` で、`null` の場合が未定義。UI は `turn_resolved` を待ち続けて止まる → `submit_turn` は `bool` を返すか、拒否をシグナルで知らせ、状態を変えず `push_error` で記録する。CPU 側の手が不正な場合の扱い（開発時の誤りとして assert するなど）も書く
- **M3【バグ】手の候補・ヒント・判定の詳細を「誰の視点」で持つかが未定義で、UI が座標を変換する前提が残っている**（component-design.md §1.2・§3.5・§5.4・§5.5）: `MoveOptions`・`ChoiceHint`・`TurnChoice.target` の視点が未定義で、守備ターンに利用者がタップしたエリアを攻撃側の視点に変換する担当も書かれていない。`JudgeReasonFormatter`（比較エリアは攻撃側の視点）と `ReplayStage.play(record, viewer)` は UI 側の変換を前提にしており、§3.5 と矛盾する → アプリケーション層の値はすべて利用者の視点に揃えると明記し、変換は `MatchController` が行う。UI に変換を残すなら、その例外を §3.5 に書く
- **M4【バグ】`NO_CONTEST` の判定理由の文が奪取側から見た固定文**（screen-design.md S-03「判定なし（相手は撤退、こちらは保持）」）: 利用者がリトリートした喪失側だと内容が逆になる → 視点に応じた2通りの文にする
- **M5【運用】正本の画面遷移図にない遷移を基本設計で追加している**: S-02「戻る → S-01」、S-11「空の表示 → S-02」、S-08「やめる → S-01」、試合中のメニューから開く設定の重ね表示が functional-overview.md「画面遷移図」にない。screen-design.md 自身の「遷移の正本は同図」「画面一覧・遷移図を先に更新」、repository-structure.md「ワイヤーフレームの運用」に反する → 遷移図に追加する
- **M6【バグ/運用】直前の保存が失敗した後にメニューから中断すると、進行が黙って失われる**（functional-overview.md 遷移図の注記、component-design.md `suspend_to_title`、screen-design.md「試合中のメニュー」）: 「直前の保存の時点の状態が残っている」前提は保存失敗時に成り立たず、中断は保存の時点ではないので再試行されない → 直前の保存が失敗していれば `suspend_to_title` で再保存を試みる（正本の保存の時点に追記）。できないなら確認ダイアログで警告する
- **M7【バグ/レイヤー規則】3D 演出の上限秒を UI が得る経路が無い**: S-03 は上限を `PresentationConfig` から読むが、アプリケーション層にそれを返すメソッドが無く、このまま実装すると UI がデータ層の `ConfigRepository` を呼ぶ（規則違反） → `MatchController.replay_max_sec()` を足すか、`turn_resolved` の引数に含める

### Low / 改善提案
- 【運用】glossary.md「ターン記録」の定義に、ER 図に足した項目（ハーフ・攻撃側・判定前後のボール位置・選手の動き）が反映されていない。repository-structure.md の `review/` にも「アルゴリズム10」の表記が無い
- 【バグ】usecase.md UC-01① の `MC-->>Setup: state_changed` は、画面を入れ替えた後に S-02 へ通知する形になっている。screen-design のとおり「S-03 が開いたときに `snapshot()` を呼ぶ」形にすると順序に依存しない
- 【バグ】usecase.md UC-05: 終了処理のやり直しに `finish()` と失敗時の分岐がない。「途中」の分岐にも `is_play_complete` が false の確認が必要。「再開時に乱数生成器を作り直す」が component-design.md §3.2「起動時に1つ作る」と食い違う
- 【運用】起動時の `storage_error(SUSPEND_LOAD)` はタイトルを開く前に出る。`MainShell` が通知を保持してから表示することを明記する
- 【性能/運用】`settings()` を手の選択のたびに呼び、`records()`・`totals()` がそれぞれ `load_all()` する。破損時はそのたびに同じエラー通知が出る → `UserDataService` で読み込み結果をキャッシュする
- 【バグ】アルゴリズム10「時間帯」で、ハーフをまたいで陣形・方式が同じ場合にまとめるかが不明。S-07 の表示形式（「前半 1〜6ターン」）からは、ハーフの境で区切ると書くのがよい
- 【バグ】3D 演出の「①判定前の配置で並ぶ」を、ターン記録の「判定時の両者の配置」と `movements` から復元するには、配置を選手単位で持つ必要がある。ER 図の「判定時の両者の配置」が選手単位であることを明記する
- 【セキュリティ】読み込み時の検証（§4.3）に、改変されたファイルへの備えとしてサイズ・件数の上限（`turn_records` の件数 ≤ 2 × 1ハーフのターン数など）を加えるとよい
- 【運用】.steering/20261017-basic-design/tasklist.md が全項目未チェック

### 問題なし
- **ハードコーディング（観点1①）**: 新規の .md・.steering と 1_requirements の差分に、URL・エンドポイント・キー・トークン・パスワード・クラウドアカウント情報・ローカルの絶対パス・ユーザー名・メールアドレスは無い（grep で確認。出てくるのは `user://` の相対表記だけ）。JSON の例の試合 ID・選手 ID はダミー値
- **wireframes.drawio**: `<mxfile host="drawio" pages="12">`。ページ名は wireframe-s01-title〜wireframe-s12-settings の12個。URL・パス・キー・埋め込み画像（`image=`・`data:image`・`file:`・`link=`・`UserObject`）は無い
- **認証・認可・インジェクション・情報漏洩**: サーバー・外部通信が無く、攻撃面は無い。エラー表示は正本の固定文言で、内部情報を出さない。保存データは書き込み手順・`format_version`・`SaveMigrator`・読み込み時の検証が設計されている（破損時は H6）
- **アルゴリズム10 の勝ち負けの表**: glossary の TurnOutcome 表、およびアルゴリズム6 の「REGAIN_FAILED は奪取側の勝ち、NO_CONTEST は含めない」と矛盾しない。アルゴリズム番号（1〜10）も architecture-overview・repository-structure・glossary・モジュール構成図で揃っている
- **名前の一致**: usecase.md・screen-design.md のクラス名・メソッド名は component-design.md の定義と一致（H4 の値の出どころを除く）。§6 の範囲で `class_name`・enum 名の重複は無い
- **レイヤー規則**: ドメインは他層に依存せず、乱数・Resource は引数で受け取る。アプリケーション層はシグナルだけで UI に通知する。UI はデータ層を直接呼んでいない（M7 の経路の欠落と M3 の座標変換を除く）
- **性能**: 中断データの全体の書き直しは1ターンに1回・数十 KB 程度、戦績の全件の読み書きは試合の終了時だけで、数千試合の規模まで問題ない

### 未検証
- wireframes.drawio の各ページの中身（依頼どおり、ページ名と機密情報の有無だけを確認）
- kit の `coding-gdscript.md` 等、MCP 経由の規約との突き合わせ
- Godot 4.6 の組み込みクラス名との衝突（`App`・`Movement`・`ConfirmDialog` 等。記憶では衝突しないが実物では確認していない）
- non-functional-requirements.md は NFR-08・09・26 の該当行だけを確認

### 総合評価
Critical なし、High 7件（H1〜H7）。機密情報・ハードコーディングは見つからず、セキュリティ面の指摘はない。High はすべて「設計どおりに実装すると、気づかれないまま誤る」種類のもので、中断データ・戦績を失う経路（H1・H2・H5・H6）、チュートリアルとの状態の共有（H3）、結果画面の値の出どころ（H4）、視点の変換漏れ（H7）を修正してからコミットすることを推奨する。

### 対応
（作業の途中で、worktree をやめて `main` で作業する決定があった。修正は `main` の作業ツリーへ移してから行った）
- **H1**: 対応した。正本（functional-overview.md）の削除方針②と「試合終了から破棄までの順序」③に「終了処理が済んでいる場合に限り削除する。済んでいなければやり直し、なお失敗したら残す」を昇格させた。component-design.md の `leave_result` と終了処理の説明、usecase.md UC-04 の図を合わせた
- **H2**: 対応した。`discard_suspended` を廃止した。確認ダイアログは了承しても削除せず、`start_match` の保存で上書きする（＝削除の時点①）。S-02 から戻れば中断中の試合は残る（usecase UC-01①、screen-design S-01・S-02・S-11、functional-overview の遷移図の注記）
- **H3**: 対応した。`App.new_tutorial_controller()` が本番とは別の `MatchController`（`is_tutorial` が真、保存先なし、相手は `ScriptedOpponent`）を作り、チュートリアルを抜けたら捨てる。`start_tutorial` は `start_tutorial_step` に改め、このインスタンスだけが使う。`resume()` は毎回 `SuspendedMatchStore.load()` から読み直すと明記した
- **H4**: 対応した。`match_finished` シグナルを廃止し、`MatchController.final_record()` を足した。S-06 は開くたびに呼ぶ（usecase UC-01③・UC-04、screen-design S-06）
- **H5**: 対応した。`MatchController.suspended_status()`（`NONE`／`RESUMABLE`）を足し、タイトルは開くたびに呼ぶ。`inspect_suspended()` は起動時の後始末だけを受け持ち、戻り値を `StartupResult` にした
- **H6**: 対応した。戦績・回答結果・設定は、破損時に `<名前>.corrupt-<日時>` へ退避してから初期状態として扱う。新しい版の形式は「破損」と区別し、書き込まない（`USER_DATA_NEWER`）。正本のエラーハンドリングに「新しい版のアプリで保存されている」行を足し、破損の行に退避を書いた。NFR-09・NFR-26 の測定方法に「元のファイルが残ること」を足した。用語集のエラーの表にも行を足した
- **H7**: 対応した。`LibraryService.matchup_counts()`（利用者の視点に揃えた両チームの人数）を足し、S-05・UC-03 はこれを使う
- **M1**: 対応した。`delete()` は本体・`.bak`・`.tmp` をすべて消す
- **M2**: 対応した。`submit_turn` は `bool` を返し、選択不可なら状態を変えずに `false`（`push_error`）。CPU の手が選択不可なのは開発時の誤りとして `assert`
- **M3**: 対応した。§1.2 に「アプリケーション層と UI の間の値はすべて利用者の視点に揃え、変換は `MatchController` が行う」を表とともに明記した。開示用の値 `RevealView`（§3.5）を新設し、`turn_resolved`・`ReplayStage.play`・`JudgeReasonFormatter`・振り返りはこれを使う
- **M4**: 対応した。`NO_CONTEST` の文を利用者の役割で2通りにした（component-design §5.5、screen-design S-03）
- **M5**: 対応した。正本の画面遷移図に、試合準備の「戻る」、チュートリアルの「やめる」、戦績が0件のときの CPU 対戦を足した。試合中に開く設定は重ねて表示するもので遷移ではない、と注記した
- **M6**: 対応した。正本の保存の時点に④「メニューから中断する時（直前の保存に失敗していた場合だけ）」を足した。`has_unsaved_progress()` が真なら、確認ダイアログで警告する
- **M7**: 対応した。`MatchController.replay_max_sec()` を足した
- **Low**: 次を対応した
  - 用語集「ターン記録」の定義を ER 図に合わせた
  - repository-structure.md の `review/` にアルゴリズム10を書いた
  - UC-01① で、S-03 が開いたときに `snapshot()` を呼ぶ形にした
  - UC-05 に `finish()` と失敗の分岐、`is_play_complete` が偽の分岐を足した。乱数は作り直さない形に揃えた
  - `MainShell` が起動時の通知を保持すること
  - `UserDataService` のキャッシュ
  - アルゴリズム10 の時間帯をハーフの境で区切ること
  - ER 図の配置を「判定前と判定時（選手単位）」にした
  - 読み込み時のサイズ（5MB）と件数の上限
  - tasklist の更新
- **未検証の範囲**: Godot 4.6 の組み込みクラス名との衝突は、実装の開始時（環境構築時）にエディタで確かめる

## 第2回（2026-10-17）— 修正後の再レビュー
- 対象: `main` の作業ツリーにある basic-design の未コミットの変更（第1回の指摘の解消確認と、修正箇所の周辺）
- 結果: Critical 0件 / High 1件 / Medium 2件 / Low 8件

### 第1回の指摘の解消状況
H1〜H7・M1〜M7 は、いずれも解消を確認した（H1・H5 は N2 の残りの経路を除く。M3 は N3 を除く）。新しい API（`suspended_status`・`StartupResult`・`submit_turn -> bool`・`final_record`・`replay_max_sec`・`has_unsaved_progress`・`suspend_to_title -> bool`・`new_tutorial_controller`・`start_tutorial_step`・`RevealView`・`matchup_counts`・`USER_DATA_NEWER`・`load_state`）は、component-design・usecase・screen-design・functional-overview の4文書の間で、名前・引数・戻り値・呼ぶ時点が一致する。旧名（`discard_suspended`・`start_tutorial(`・`match_finished`・`has_load_error`）は残っていない。

### High
- **N1【バグ】戦績のキャッシュが試合の終了で古くなる（Low の対応で持ち込んだ欠陥）**: `UserDataService` は戦績を1回だけ読んでメモリに持つが、戦績を書くのは `MatchController`（`RecordStore.append` を直接呼ぶ）で、`UserDataService` を通らない。一度戦績画面を開いた後に試合を終えると、同じ起動の中では S-11 に新しい試合が出ない。エラーにもならない → 戦績の追加を `UserDataService.append_record()` に一本化するか、書き込みの通知でキャッシュを無効にするか、戦績だけはキャッシュしない

### Medium
- **N2【バグ】H1 の対応が、同じ起動の中の次の CPU 対戦で崩れる**: 終了処理が未完了で残した中断データは再開の対象にしないため `suspended_status()` が `NONE` を返し、次の CPU 対戦は確認なしで `start_match` の保存が上書きする。正本の③「戦績を失わないため残す」が、次の試合までしか守られない → `start_match` の前に未完了の終了処理をやり直すか、`suspended_status()` に第3の値（例: `FINALIZE_PENDING`）を足して上書きの確認を出す
- **N3【レイヤー規則】ドメインの `ReviewSummary` が、アプリケーション層の `RevealView` を含む形になっている**（component-design §3.2 `review()`、usecase UC-04）: 「ドメインは他層に依存しない」（NFR-13）に反する → `review()` の戻り値をアプリケーション層の値（例: `ReviewView` = 集計値 ＋ `Array[RevealView]`）にし、§6 に足す

### Low / 改善提案
- screen-design S-06「タイトルへ」の結果が「中断データを削除して S-01 へ」のまま。終了処理が済んでいる場合だけ削除する条件を反映する
- メニューからの中断の伝え方が、正本（やり直しに失敗したら確認ダイアログ）と設計（事前に確認ダイアログで警告し、失敗は事後に通知）で食い違う
- 中断データが新しい版の形式だった場合に破損として削除する方針が、component-design・UC-05 だけにある。正本のエラーハンドリングの行に書く
- `RevealView.user_role` の型が未定義。`GameEnums.Phase` と同じ4値なので、それを使うとよい
- `ScriptedOpponent` に段階ごとの手を渡す経路がない。`start_tutorial_step` が台本も差し替えると明記する
- 書き出し版で CPU の手が選択不可だった場合に `submit_turn` が `false` を返すと、CPU 側の誤りで利用者に選び直しを求めることになる。CPU の手を選び直す（または既定の手にする）
- UC-04 のやり直し失敗時の `storage_error(...)` の種類が未記入
- UC-05 の `FINALIZED` の分岐で、`save(finished_state)` の直後に `delete()` しており、保存が不要

### 問題なし
- ハードコーディング（観点1①）: 新規・変更の文書と .steering（review-report.md を含む）に、URL・キー・クラウド情報・ローカルの絶対パス・ユーザー名は無い。wireframes.drawio は12ページで、URL・画像の埋め込み・ファイル参照・パスは無い
- 認証・認可、インジェクション、情報漏洩: 攻撃面は無い。保存データの防御は強化された（サイズ・件数の上限、退避、新しい版の書き込み禁止）。fail open の箇所は無い
- 性能: 戦績以外はキャッシュで読み込みが減った。新たな懸念は無い

### 未検証
- wireframes.drawio の各ページの中身が、修正後の画面設計（S-01 の確認文言、S-06 など）と一致しているか
- Godot 4.6 の組み込みクラス名との衝突（実装の開始時に確認）
- kit の `coding-gdscript.md` との突き合わせ

### 総合評価
Critical なし、High 1件（N1）。第1回の High 7件・Medium 7件は対応を確認した。N1 を直してからコミットする。N2・N3 も同じ変更で直すのがよい。

### 対応
- **N1**: 対応した。戦績の追加を `UserDataService.append_record()` に一本化した（キャッシュも更新する）。`MatchController` は `RecordStore` を持たず、`UserDataService` を受け取る（component-design §3.2・§3.4、usecase UC-01③・UC-04・UC-05）
- **N2**: 対応した。`SuspendedStatus` に `FINALIZE_PENDING` を足した。タイトル・戦績の0件の表示で CPU 対戦を選んだら、先に `retry_pending_finalize()` でやり直し、なお失敗したら「前の試合の戦績は記録されない」と確認してから試合準備へ進む（component-design §3.2、usecase UC-01①・UC-04・UC-05、screen-design S-01・S-11）
- **N3**: 対応した。アプリケーション層に `ReviewView`（集計値 ＋ 得失点の流れの各ターンの `RevealView`）を設け、`review()` の戻り値にした。`ReviewSummary` はターンの通し番号だけを持ち、アプリケーション層の型を含まない（§3.5・§6・§7）
- **Low**: 次を対応した
  - S-06「タイトルへ」の条件
  - 中断の伝え方を設計に揃え、正本の注記を「事前に確認ダイアログで警告、やり直しに失敗したら通知」にした
  - 正本のエラーハンドリングの中断データの行に「新しい版を含む」を足した
  - `user_role` の型を `GameEnums.Phase` にした
  - `start_tutorial_step` が台本も差し替えると明記した
  - 書き出し版で CPU の手が選択不可なら、選べる手の先頭に置き換えて解決する
  - UC-04 の `storage_error` の種類を書いた
  - UC-05 の不要な保存を消した（戦績を記録できたらそのまま削除）
- usecase.md の12枚の図すべてで、矢印・注記に出てくる参加者が定義済みであることをスクリプトで確かめた

## 第3回（2026-10-17）— 修正後の再レビュー
- 対象: 第2回の指摘への対応分（component-design.md §3.2・§3.4・§3.5・§6・§7、usecase.md UC-01①③・UC-04・UC-05、screen-design.md S-01・S-06・S-07・S-11、functional-overview.md の遷移図の注記とエラーハンドリングの表、およびその周辺）
- 結果: Critical 0件 / High 0件 / Medium 2件 / Low 3件

### 第2回の指摘の解消状況
- N1: 解消。`UserDataService.append_record()` を足し、`MatchController` は `RecordStore` ではなく `UserDataService` を受け取る。終了処理（UC-01③）・`leave_result`（UC-04）・起動時（UC-05）のすべてが `append_record` を通り、キャッシュも更新される
- N2: 解消（手順の不揃いは P1、正本への昇格は P2）。`FINALIZE_PENDING` と `retry_pending_finalize()` が UC-01①・UC-04・UC-05・S-01・S-11 に反映され、再開カードは `RESUMABLE` のときだけ出る
- N3: 解消。アプリケーション層の `ReviewView` を新設し、`ReviewSummary` は集計値とターンの通し番号だけを持つ。`review() -> ReviewView`、UC-04、S-07、§6、§7 が一致する
- Low 8件: すべて対応を確認（UC-05 の不要な保存の削除は P1 の食い違いを持ち込んだ）

### Medium
- **P1【バグ／正本との食い違い】終了処理のやり直しの手順が3通りあり、起動時の手順は正本の削除の時点に当てはまらない**: UC-05 は戦績を記録できたら `FINISHED` で保存せずに削除する。一方 `retry_pending_finalize` と UC-04 は「戦績の記録 → `FINISHED` で保存 → 削除」。正本は起動時のやり直しを「戦績の記録 → `FINISHED`」とし、削除の時点③は「起動時に `FINISHED` の中断データが見つかった時」。起動時は `IN_PROGRESS` のまま削除しており、4つの削除の時点のどれにも当たらない（動作は安全側） → 3か所を「戦績の記録 → `FINISHED` で保存 → 削除」に揃えるか、正本の削除の時点③を改める
- **P2【運用／正本への昇格漏れ】記録できなかった戦績を、利用者の了承のうえで失う経路が正本にない**: 正本の③は「なお失敗した場合は削除せずに残す（次の起動時にやり直す）」までで、次の CPU 対戦の前にもやり直すこと、了承したら上書きして戦績を失うことが書かれていない → ③と削除の時点①に追記する

### Low / 改善提案
- 保存エラーの通知が二重に出る: §3.4 では `UserDataService` が失敗時に自分で `App.storage_error` を出すのに、UC-01③・UC-05 では `append_record` の失敗の後に `MatchController` も `storage_error(USER_DATA_SAVE)` を出している → 通知を出す側を `UserDataService` だけにする
- screen-design S-11「空の表示から CPU 対戦」が `FINALIZE_PENDING` のときに `retry_pending_finalize()` を先に呼ぶか読み取れない → 「S-01 の CPU 対戦と同じ手順」と書く。正本の注記も `FINALIZE_PENDING` を含むことが読み取りにくい（P2 と合わせて直す）
- component-design §3.5 の見出しに `ReviewView` が無い

### 問題なし
- 新しい API（`append_record`・`FINALIZE_PENDING`・`retry_pending_finalize`・`ReviewView`）の名前と呼ぶ時点が、component-design・usecase・screen-design の間で一致する
- チュートリアル用のインスタンスは `user_data` が null で終了処理を行わないため、戦績を書く経路はない
- `FINALIZE_PENDING` の試合が残っていても、S-02 から戻れば消えず、了承しなければ上書きされない
- セキュリティ: 修正範囲にハードコーディング・機密情報・新しい攻撃面はない
- 性能: 戦績の読み込みは1回に減り、追加はキャッシュの更新だけ

### 未検証
- 今回触っていない部分の再精査（依頼どおり行っていない）
- wireframes.drawio の中身が S-01（`FINALIZE_PENDING` の確認文言）・S-06 の修正と一致しているか
- Godot 4.6 の組み込みクラス名との衝突（実装の開始時に確認する方針）

### 総合評価
Critical・High ともに指摘なし。第2回の N1〜N3 と Low 8件は対応を確認した。残りの Medium 2件と Low 3件はコミットを止めるものではないが、正本との整合のため P1・P2 は同じ変更で直すことを推奨する。

### 対応
- **P1**: 対応した。UC-05 を「戦績の記録 → `FINISHED` で保存 → 削除（削除の時点③）」に戻し、UC-01③・UC-04・`retry_pending_finalize` と揃えた（正本どおり）
- **P2**: 対応した。正本の「試合終了から破棄までの順序」③に、残した試合は再開の対象にせず、次の起動時と次の CPU 対戦の前にやり直すこと、CPU 対戦の前のやり直しにも失敗したら戦績が記録されないことを確認して上書きすることを書いた。削除の時点①にもその確認を含むと書き、遷移図の注記も揃えた
- **Low**: 次を対応した
  - 戦績の記録の失敗の通知は `UserDataService` だけが出す、と component-design §3.4 と UC-01③・UC-04・UC-05 に書いた
  - S-11 を「S-01 の CPU 対戦と同じ手順」にした
  - §3.5 の見出しに `ReviewView` を足した
- **未検証への対応**: wireframes.drawio の S-01（CPU 対戦の注記）と S-06（タイトルへの注記）を、修正後の設計に合わせて作り直した
- Medium / Low のみのため、第4回の再レビューは行わない（review-pre-commit の規則）

## レビュー完了（2026-10-17）
- 最終ラウンド: 第3回
- 新たな Critical / High: なし
- 積み残し
  - Godot 4.6 の組み込みクラス名との衝突の確認（`App`・`Movement`・`ConfirmDialog` など）: 開発環境の構築時に、エディタで確かめる。テストはまだない
  - kit の `coding-gdscript.md` との突き合わせ: 詳細設計・実装の開始時に行う
