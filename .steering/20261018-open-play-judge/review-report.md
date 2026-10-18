# コミット前レビューレポート

## 第1回（2026-10-18）
- 対象: アルゴリズム5の未コミット差分すべて。
  - 新規ドメイン: `judge_detail.gd`・`judge_output.gd`・`judge/open_play_judge.gd`
  - 新規テスト: `judge_values_test.gd`・`judge/open_play_judge_test.gd`
  - 上記の `.uid`
  - `functional-overview.md`（アルゴリズム5の手順2に1行）・`component-design.md` の変更
  - `.steering/20261018-open-play-judge/` の3文書
- 結果: Critical 0件 / High 0件 / Medium 0件 / Low 3件
- 備考: 実装レビュー（review-implementation。総合 4.6/5、[必須] なし）の指摘は、このレビューの前に対応済み（tasklist.md に記録）
- 転記の注記: レビュー担当が検索した語の例のうち、ユーザー名とローカルパスの具体的な文字列は、コミットに残さないため伏せた（それ以外はそのまま）

## コミット前レビュー結果

対象: 未コミットの差分すべて。差分の正しさを確かめるため、直接の依存先（DefenseMover.apply、StyleLayoutCalculator.remark、TeamLayout、PlayerState、LayoutPair、LayoutStep、PitchArea.equals/forward/mirrored、MoveOptions.needs_target、MoveRules.attack_options のドリブル先生成）も読んだ。ファイルの書き込みや Godot の起動はしていない。

### Critical（即時対応必須）
- なし

### High（優先対応）
- なし

### Medium（対応推奨）
- なし

### Low / 改善提案
- [バグ] `_dribble` が不正な配置で例外になる: `current[copied.player_id] = pair.attacker.current_area_of(copied.player_id).duplicate_deep()` は、現在エリアを持たない選手がいると null 参照で落ちる。`compute` や `DefenseMover` が作る配置では全員が現在エリアを持つので、正規の経路では起きない。ただ、`TeamLayout.current_area_of` は API として null を返しうる。気になるなら、この選手を写すだけにして null を写さない形にできる。
  ```gdscript
  var area: PitchArea = pair.attacker.current_area_of(copied.player_id)
  if area != null:
  	current[copied.player_id] = area.duplicate_deep()
  ```
  今のままでも実害はない。申し送りで十分。
- [運用/文書] requirements.md の「未決事項」にある「ドリブルする選手」の項は、本文が旧ルール（「固定されていない選手を優先」）のまま。変更後のルールは括弧書きの注記にしかない。正本（design.md・component-design.md・コード）は新ルールで揃っている。ただ要求書だけを読むと逆の規則に見えるので、本文を新ルールに書き換え、旧ルールを「変更前」として注記する形を勧める。
- [運用] `git diff` で 2 つの .md に「LF will be replaced by CRLF」の警告が出る。作業ツリーのファイルは LF で（スキャンでも CR なし）、リポジトリの autocrlf 設定による既存の挙動。今回の差分が持ち込んだ問題ではない。

### 問題なし
- セキュリティ
  - ① ハードコーディング: 対象の全ファイル（.gd 5件、.md 5件、新規 .uid 5件、および同じディレクトリの既存 .uid）をスキャンした。URL（http/https）、メールアドレス、ローカルの絶対パス、ユーザー名、artifact リンク、AWS ARN/AKIA、secret/token/password/api_key の語はいずれも 0 件。.uid は `uid://...` の1行だけ。.gitignore には .env・.env.*・鍵ファイル・ローカルの設定ファイル・session-env が入っている。
  - 制御文字: BOM・CR・タブ以外の C0 制御文字・NUL・DEL・ゼロ幅文字・双方向制御文字（U+202D/202E/2066-2069）・NBSP・全角空白・私用領域の文字は全ファイルで 0 件。行の途中にリテラルの「\n」（バックスラッシュ＋n）が入った行もなし。.gd にスペースのインデントはない（タブだけ）。全ファイルが改行で終わる。
  - ②認証・認可、③インジェクション、④情報漏洩、OWASP A01〜A10: 差分は外部通信・永続化・入力の解析・ログ出力・依存の追加を含まない純粋な static ドメイン関数なので、該当しない。
- バグ・正しさ
  - 入力の検証: `ball == null`、family の取り違え、運ぶ先が必要な手での target 欠け（`MoveOptions.needs_target` を使う）、DefenseMover が null を返すケースは、すべて null を返す。これらはテスト `test_unavailable_or_mismatched_choices_return_null` で固定されている。
  - 入力の非破壊: DefenseMover は attacker を duplicate_deep し、remark は pair を丸ごと複製する。`_dribble` は選手と現在エリアを複製し、defender も duplicate_deep する。テストでは件数・固定・オブジェクトの同一性を確かめている。
  - 座標系: 守備側の人数は `count_at(area.mirrored())`、背後は `compare.forward()`（攻撃側の視点）。ドリブルの Movement は攻撃側の視点の ball/to で、「動いた選手のチーム自身から見た値」と矛盾しない。
  - 結果の分岐: SHOT は diff>0 で GOAL、それ以外は SAVE で、カバー判定をしない。diff≠0 はカバーなし。diff=0 で A ゾーンのとき、L2/R2 は OUT_OF_GK_REACH で ADVANCE、それ以外は GK で STALL。背後で守備>攻撃なら DEFENDER で STALL、同数ならカバーなし。仕様（要求書・design.md）と一致する。
  - ドリブル先とボール位置が同じになることは、MoveRules.attack_options の生成条件（forward、または同じゾーンでレーン差1）から起きない。from==to の Movement は生まれない。
  - 運び手の選び方: 固定された選手を優先し、同じ条件なら配置の順。carrier がいないときは動かさない。どれも分岐ごとにテストがある。
  - 動きの順序（守備の手 → 付け直し → ドリブル → 付け直し）は、テストで文字列の配列として完全一致で確かめている。
  - テストの質: 期待値は判定例と規則から手で書いた文字列で、実装をコピーした恒真テストではない。JE-01〜06（JE-02 の LOSS 変形を含む）、エッジケース、対称性（HOME/AWAY を入れ替える）、null、非破壊をカバーしている。tasklist には 11 個の変異で検出を確認したこと（等価変異が1つ、注入失敗を入れ直した記録も含む）が残っていて、空振りの懸念は小さい。
  - JudgeOutput/JudgeDetail: コンストラクタで配列をコピーする。duplicate_deep は detail が null でも動く。どちらもテストがある。
- 性能: 1回の判定は、選手数（最大 11）× 定数回の走査と複製を数回行うだけ。上限のない入力やループ内 I/O はない。
- 運用
  - 仕様の追記（functional-overview の手順2）と component-design の決めごとは、コードの挙動と一致する（付け直しの時点、運び手の優先、動きの順序、null の条件、手順7 は MatchRules に任せる、`_attacker_styles` を使わない理由）。
  - 呼び出し元はまだない（OpenPlayJudge・JudgeOutput・JudgeDetail はテスト以外から参照されていない）ので、既存の利用側は壊れない。新規ファイルの追加と文書の追記だけなので、revert で戻せる。

### 未検証
- テストの実行と、GDScript の型警告・禁止依存の検査（指示どおり Godot を起動していない。依頼元の実行結果は 240 件成功）。
- 新しい .uid がプロジェクト全体で重複していないか（対象ディレクトリの .uid は目視で重複なし。リポジトリ全体は走査していない）。
- 判定例 JE-01〜06 の期待値が functional-overview.md の判定例の表と一致するか（仕様本文と1行ずつの突き合わせはしていない。実装レビューの範囲と判断した）。

### 総合評価
Critical / High の指摘はない。このままコミットしてよい。Low の2件（`_dribble` の null への備え、requirements.md の旧ルールの記述）は申し送りで構わない。

### 対応
- Low（requirements.md の旧ルール）: 直した。本文を新しい規則にし、変更前の規則を注記にした。
- Low（`_dribble` の null への備え）: 申し送る。正規の経路（`compute`・`DefenseMover`・`remark` が作る配置）では全員が現在エリアを持つ。`TeamLayout` の現在エリアが欠ける経路を作る作業があれば、そこで扱う（振り返りに記録）。
- Low（CRLF の警告）: 対応しない。既存の設定による挙動で、今回の差分の問題ではない。
- 未検証の `.uid` の重複: 依頼元が確かめる（下の「レビュー完了」に結果を書く）。JE の期待値と仕様の突き合わせは、実装レビューで全件一致を確認済み。
- テストの実行: 依頼元がコミット直前に実行する（下の「レビュー完了」）。
- Critical / High を直したものではないため、再レビューは行わない（スキルの規則）。

## レビュー完了（2026-10-18）
- 最終ラウンド: 第1回
- 新たな Critical / High: なし
- コミット直前の確認: `bash tools/run-tests.sh` で 240 件成功（21スイート）、禁止依存の検査 0 件、SCRIPT ERROR なし。リポジトリ全体の `.uid` に重複なし
- 積み残し（Low）: `_dribble` の現在エリアの欠けへの備え（正規の経路では起きない）
