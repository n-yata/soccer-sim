# コミット前レビューレポート

## 第1回（2026-10-29）
- 対象: 作業ツリーの未コミットの変更すべて（戦績 FR-13。`.steering/20261029-match-records/` を含む）
- レビュー役: サブエージェント（opus。セキュリティ観点を含むため）
- 結果: Critical 0件 / High 0件 / Medium 2件 / Low 4件

## コミット前レビュー結果
対象: 作業ツリーの未コミット変更すべて（戦績 FR-13）。新規の domain/match_record・record_period、data/match_record_codec・record_store、application/user_data_service・match_finalizer、ui/common/record_texts、s11_records を読んだ。変更側は match_controller・suspend_keeper・app・app_screens・new_match_gate・title_screen・result_screen・match_screen・main_shell・suspended_match_encoder・review_aggregator を差分で見た。直近の呼び出し元として data/save_file_io.gd も読んだ。テストの user:// の差し替え状況と、仕様書・.steering 内のハードコーディングも確認した。

### Critical（即時対応必須）
指摘なし

### High（優先対応）
指摘なし

### Medium（対応推奨）
**M-1 [運用／データ完全性（NFR-09）] 本体が壊れていて .bak が読めるとき、壊れた本体が退避されず、次の書き込みで消える**
- 場所: `game/data/record_store.gd` の `load_all`。原因は `SaveFileIO.read` と `SaveFileIO.write` の組み合わせ。
- 何が起きるか: `SaveFileIO.read` は、本体が `_is_usable` を通らないと .bak を使う。.bak が通れば `_load_state = OK` になり、`_quarantine()` は呼ばれず通知も出ない。次に `append` から `SaveFileIO.write` が走ると、次の順で処理される。
  1. 正常な .bak を消す
  2. 壊れた本体を .bak へ移す
  3. 新しい本体を書く
  4. .bak（＝壊れていた本体）を消す
- 結果: 壊れた本体は退避されないまま消える。本体にだけあった新しい戦績も、利用者に知らされずに失われる。
- 起きる条件: 書き込みの手順 3〜4 の間で止まったあとにディスクが壊れた場合か、利用者が本体を書き換えた場合に限られる。頻度は低い。ただし、設計方針の「破損は退避」に対する静かな例外になっている。
- 修正例（load_all の先頭近くで、本体が使えず .bak で読んだ場合は本体だけ退避する）:
```gdscript
func load_all() -> Array[MatchRecord]:
	_is_quarantine_failed = false
	# 本体が壊れていて .bak だけが読める: 次の書き込みで本体が消えないよう、本体を先に退避する
	if FileAccess.file_exists(_path) and FileAccess.file_exists(_path + SaveFileIO.BAK_SUFFIX):
		var main_text: String = SaveFileIO._read_limited(_path)  # 公開の読み出しを SaveFileIO に足すのが望ましい
		if main_text.is_empty() or not _is_usable(main_text):
			if not _rename_to_free_name(_path, _path + CORRUPT_INFIX + _stamp()):
				_is_quarantine_failed = true
			# 通知も出したいなら、LoadState に「.bak から復旧した」を足し、UserDataService で USER_DATA_LOAD を出す
	... (以下は今のまま)
```
  テストに足すケース: 本体 `{ broken`、.bak は正しい v1 で 1 件、という状態で `append` した後に、`.corrupt-*` が残っていて戦績が 2 件になること。

**M-2 [性能] 試合が終わるたびに、戦績ファイル全体を JSON の解析と検証に 4 回かけ、メインスレッドで最終ターンの開示を止める**
- 場所: `UserDataService.append_record` から `RecordStore.append`、さらに `load_all` へ。
- 内訳: `RecordStore.append` 内の `load_all` で、`_is_usable` の解析＋decode と、本体の解析＋decode の 2 回。成功後の `_records = _record_store.load_all()` でさらに 2 回。合計 4 回、加えて `to_json` が 1 回。
- 問題になる規模: 3000 件で 1〜2MB 程度、上限の 4MB 付近になると、遅い端末では最終ターンの確定（`submit_turn` の中）で数百 ms〜1 秒前後止まる見込み。数十〜数百件なら問題にならない。
- 修正例:
  - `_is_usable` で解析した結果を使い回す（`_last_decoded` に持つ）。
  - `append` が書き込んだ配列を返し、UserDataService は再読み込みせずにそれを持つ。
```gdscript
# RecordStore
var _written: Array[MatchRecord] = []
func append(record) -> bool:
	...
	var ok := SaveFileIO.write(_path, text)
	if ok: _written = records
	return ok
func last_written() -> Array[MatchRecord]: return _written
# UserDataService.append_record（成功時）
_records = _record_store.last_written()
```
  重複で書かずに true を返す経路は、読み込んだ `records` をそのまま `_written` に入れる。

### Low / 改善提案
- **L-1 [性能] 4MB を超えたときの削り方が重い**: `append` の 4MB 超過ループは、1 件消すたびに全件を `to_json` し直す。正常に使う範囲では 1 件ずつ増えるので 1〜2 回で済む。ただし改変されて 5MB 近い有効なファイルなら、数千回の文字列化になる。1 件あたりの大きさから捨てる件数を見積もってまとめて `slice` すれば、O(n) にできる。
- **L-2 [バグ／表示] 推移の並びを検証していない**: `timeline` 内の half と from_turn の順序（単調に増えるか）を検証していない。改変されたファイルでも落ちはせず、表示の順が乱れるだけ。読み込み時に「前の区切りより後」を確かめれば破損として扱える。
- **L-3 [バグ] 終わった試合を、前のターンからやり直せる経路がある**: 最終ターンの IN_PROGRESS の保存（`submit_turn` の保存の時点①）と終了処理の両方が失敗した場合の話。`keep_pending` でメモリ上は FINALIZE_PENDING になるが、ディスクには1ターン前の IN_PROGRESS が残る。次に起動すると RESUMABLE として最終ターンをやり直せる。戦績を記録できていた場合は、同じ match_id の記録はされない（`append` が true を返す）。このため、2回目の結果（スコアが違いうる）は静かに捨てられ、1回目の結果が残る。二重記録にはならず、実害は小さい。仕様として受け入れるなら、design.md に一行書いておくとよい。
- **L-4 [保守]** `UserDataService.records()` は配列を写して返すが、中の MatchRecord は共有している。今は画面側が書き換えていないので問題ない。

### 問題なし
- **① ハードコーディング**: 差分・新規 .gd・.steering/20261029-match-records/・仕様書の差分を grep した（http(s)/ws(s)、api_key、secret、token、password、arn:aws、amazonaws、12 桁の数字）。該当なし。保存先は `App.save_dir`（既定 `user://`）と `RecordStore.FILE_NAME` で、外部 URL・鍵・アカウント情報はない。
- **② 認証・認可**: オフラインの単体ゲームで、保護リソースはない（対象外）。
- **③ インジェクション**: 表示はすべて Label.text で、BBCode/RichText は使っていない。陣形 ID は `ContentRepository.ID_PATTERN`、match_id と日時は正規表現、列挙型は enum_value、スコアは 0..99、件数は 0..3000、推移は 1..(ハーフの最大ターン数×2+2) で検証している。`HALF_NAMES[period.half]` は 1..2 で検証済みなので、範囲外の参照は起きない。
- **④ 情報漏洩**: 検証の誤りは `errors()` で開発時に参照するだけで、画面にもログにも出していない。
- **A08（保存データの検証）**: 1 か所でも誤りがあれば全体を null にし、読み込みは fail closed になっている。破損したら退避し、退避に失敗したら追記を拒む。新しい版（format_version が大きい）は中身を見ずに 0 件として扱い、書き込まない。古い版・不正な版は破損として退避する。5MB を超えるファイルは読まない。重複した match_id・record_id≠match_id・スコアと勝敗の不一致はどれも拒否する。M-1 以外に fail open は見つからなかった。
- **終了処理の順序（記録 → FINISHED で保存 → 削除）**: 記録に失敗した場合も、保存に失敗した場合も、中断データは IN_PROGRESS のまま残る。やり直すと同じ match_id は記録されないので、二重記録にはならない。`leave_result` は、終了処理が済んだときだけ中断データを消し、失敗したら `keep_pending` で残す。起動時は、FINISHED なら削除し、最終ターンの IN_PROGRESS ならやり直す。NewMatchGate は、まずやり直し、それも失敗したときだけ確認を出す（上書きするのは利用者が同意した後だけ）。終了処理を済ませる前に中断データを消す経路は見つからなかった。`suspend_to_title` と `_can_open_menu` で試合後の中断も防いでいる。終了日時は最初の試みの時刻に固定されている。`_open` では `_is_finalized` と `_finished_at` を戻している。
- **テストの user:// の隔離**: S-01・S-11・MainShell を開くテスト（title_screen・title_resume・records_screen・main_shell・match_flow・match_screens）は、どれも `use_user_data_in(create_temp_dir(...))` で差し替え、after_test で戻している。match_menu・review_screen・match_setup の各テストは user_data=null で作ったコントローラーを使い、画面の要求は記録用の関数で受けるだけなので、タイトルを開かない。App の自動ロードが持つ本物の RecordStore は、最初に使うまで読まない。テスト内の `user://` 直書きは、既存の「存在しないディレクトリ」のテスト 2 か所だけ。
- **後方互換**: `SuspendedMatchEncoder._setup` を公開名 `setup_fields` に変えただけで、出力の形は変わらない。`ReviewAggregator._segments` を公開にした件も、振る舞いは同じ。

### 未検証
- Godot とテストは実行していない（依頼どおり。依頼元が全テストと変異テストを実施済み）。
- `main_shell.gd` の起動時の `inspect_suspended()` が `storage_error` の接続より後に呼ばれるかは、差分外の既存コードなので見ていない。起動時のやり直しが失敗したときの通知が出るかは、そこで決まる。
- match_id の生成（同じ秒・同じ 4 桁で衝突すると、2 試合目の戦績が重複として記録されない）は差分外なので確かめていない。
- M-2 の所要時間は見積もりで、計測していない。
- 新規テストの各ケースが恒真になっていないかは、変異テストで全件検出されたという申告を前提にし、個別には読んでいない。

### 総合評価
Critical / High の指摘はない。保存データの検証・退避・上書き防止は概ね fail closed で、終了処理の失敗経路でも、戦績の消失・二重記録・中断データの誤った削除は見つからなかった。M-1（本体が壊れていて .bak が読めるときに退避されない）は NFR-09 に対する静かな例外なので、テストを固定して直すか、申し送ることを勧める。M-2 は件数が増えたときの体感の問題。コミットは可能と判断する。

### 対応
- **M-1（直した）**: `RecordStore.load_all` で、本体と `.bak` の両方があり本体が使えないときは、本体を先に退避してから `.bak` を読む（退避できなければ破損として追記を断る）。`.bak` を使った読み込みは「復旧できた」として `OK` のまま（初期状態にはしていないので通知は出さない）。本体だけを読む `SaveFileIO.read_limited` を公開した。テスト `test_a_valid_backup_is_used_when_the_main_file_is_broken` に「退避したファイルが残る」「追記しても退避したファイルは消えず、戦績が2件になる」を足し、退避を外す変異で落ちることを確かめた。
- **M-2（直した）**: `RecordStore` が、直前に解析した（または書いた）文字列とその結果だけを覚え、同じ文字列なら解析し直さない形にした。試合を終えたときの解析は、`.bak` の判定と本処理の2回から1回（最初の読み込み以降は、書いたものを覚えているので0回）になる。所要時間は計測していない。
- **L-1（直した）**: 大きさの上限を超えたときは、1件あたりの大きさから捨てる件数を見積もってまとめて捨てる（件数の上限も `slice` でまとめて）。既存の大きさの上限のテストと変異で確かめた。
- **L-2（直さない）**: 推移の区切りの順序の検証は、データ定義の件数の上限（（最大ターン数）× 2 ＋ 2）と両立しない（順序を守ると最大でも（最大ターン数）× 2 件で、上限ちょうどの正しいデータが作れない）。改変されたファイルで表示の順が乱れるだけで、落ちない。データ定義の上限を見直すときに合わせて扱う。
- **L-3（受け入れる。design.md に記載）**: 最終ターンの保存と終了処理が両方失敗した場合、次の起動で最終ターンを再びできる。戦績が記録済みなら同じ試合 ID は記録されず、最初の結果が残る（二重記録にはならない）。
- **L-4（直さない）**: 画面は戦績を読むだけ。書き換える画面を作るときに写しを返す形にする。
- 第1回で Critical / High は無く、直したのは Medium / Low だけなので、規則どおり再レビューは行わない（全テストと変異で確かめる）。

## レビュー完了（2026-10-29）
- 最終ラウンド: 第1回
- 新たな Critical / High: なし
- 積み残し: L-2（推移の区切りの順序の検証。データ定義の件数の上限の見直しと合わせる。改変されたファイルの表示が乱れるだけ）、L-4（戦績の写し）
