# コミット前レビューレポート

## 第1回（2026-10-18）
- 対象: 「ルールの土台」の未コミット変更一式。仕様書の差分3本（non-functional-requirements・repository-structure・component-design）、`.steering/20261018-rule-foundation/`、`game/content/formations.json`、`game/data/content_repository.gd`、`game/domain/`（8ファイル）、`game/tests/`（テスト5本と fixture 5本）、`tools/check_domain_deps.gd`、`tools/run-tests.sh`、`.uid` 全件
- 結果: Critical 0件 / High 1件 / Medium 2件 / Low 5件
- 備考: 1回目の実行は利用上限で中断し、同じエージェントで最初からやり直した

## コミット前レビュー結果

### Critical（即時対応必須）
- なし

### High（優先対応）
- [運用／バグ] **禁止依存の検査が、実行時エラーで終了コード 0（違反なし・自己確認 OK）を返す（fail open）**
  - 何が起きるか: `_init()` は `quit(_run(...))` という形。GDScript では関数の途中で実行時エラー（範囲外アクセス、null の参照など）が起きるとその関数は打ち切られ、戻り値の型の既定値を返したことになる。`-> int` の既定値は `0` で、`EXIT_CLEAN` と同じ値。
  - 実測（リポジトリ外の最小のスクリプト）: `quit(_run())` で `_run()` の中でエラーを起こすと、`SCRIPT ERROR` を出したうえで EXIT=0。戻り値は int の 0。
  - 影響: 走査の途中（`_check_file`・`_class_names_in`・`_self_check_result` など）で実行時エラーが起きると、手順2（domain の検査）が 0 で通り、手順1の各カテゴリの自己確認も OK と表示される。「検査できない対象は 2」の確認は走査より前に return するため、この経路を捕まえられない。
  - 修正案: 完了フラグ方式（`_run` 内の return をすべて `_finish(code)` 経由にし、フラグが立っていなければ EXIT_ERROR で終える）。あわせて `run-tests.sh` で、成功を示す行（手順2の `check_domain_deps: .* を検査し`、手順1の `self-check: [<cat>] ルール N 件中 N 件`）が出ていることを必須にする。修正の前に、この経路を検出する仕組みを先に固定することを勧める。

### Medium（対応推奨）
- [運用] **1行の `class_name X extends Y` と内部クラス `class X extends Y:` は extends の検査をすり抜ける**
  - `_extends_regex` が `^\s*extends\s+(\S+)` で、行頭の `extends` にしか当たらない。`component-design.md` のシグネチャ例がこの1行の書き方なので、仕様どおりに書くと検査を外れる。
  - 修正案: `(?:^|\s)extends\s+(\S+)` で行内のどこでも拾い、fixture に1行の書き方と内部クラスの例を足す。より強い代案は、識別子ごとに `ClassDB.is_parent_class(id, "Node")` を見る方法。
- [運用] **ルールの網羅の隙間**
  - ファイル: インスタンスの `.load(`（例: `Image.new().load(...)`）は後読みで除外されて検出されない
  - 時刻: `var clock = Time` のように別名にすると `\bTime\s*\.` が当たらない。`\bTime\b` を勧める
  - ノード: `Engine.get_singleton(`・`ClassDB.instantiate(` は文字列でクラス名を渡すため検出されない
  - 乱数: `rand_from_seed(` がルールに無い
  - 足したルールごとに fixture にも行を足す

### Low / 改善提案
- [バグ] `_strip_comment_and_strings` は行単位のため、複数行の `"""` の閉じの行の後ろのコードが文字列扱いになって消える（意図的に書かないと起きない形）。
- [運用] `run-tests.sh` の Godot 呼び出しにタイムアウトが無い。CI に載せるときは `timeout` で包む。
- [運用] 手順3が成功した場合は `Parse Error` を見ていない。構文エラーのスイートが飛ばされた場合、全体0件のときしか気づけない可能性がある（未検証）。`Executed test suites: (n/n)` の一致を見るのが安全。
- [バグ] `PitchArea` は「作成後に値を変えない」としているが `lane`・`zone` は公開変数。`TeamLayout.at_base` は同じ `PitchArea` を `base_area` と `_current_areas` で共有している（今は書き換える箇所は無い）。
- [バグ] `PlayerState.duplicate_deep()` は `base_area` が null だと落ちる（今の生成経路では null にならない）。

### 問題なし
- セキュリティ①: 追跡予定の全ファイル（`.uid`・`.steering`・テスト・tools を含む）と仕様書の差分に、絶対パス・ユーザー名・メールアドレス・URL・キー・トークン・パスワード・アカウント ID・ARN は無い。URL らしき文字列は `tcp://127.0.0.1:0`（リモートデバッガ用のループバック指定）だけ。`.uid` は `uid://...` の1行だけ。`.gitignore` は `.env`・`export_presets.cfg*`・鍵ファイルを除外している。
- セキュリティ②〜④・OWASP: 認証・認可、DB、画面への出力、ネットワーク、秘匿値のログ出力は差分に無い。`push_error` に出るのは同梱 JSON の場所と理由だけ。
- NFR-10: domain・data に通信 API は無い。書き出し設定でテスト・fixture・gdUnit4 は除外され、`content/*.json` は含まれる。
- シェル: 変数と引数はすべてクォートされている。`set -u`、終了コードは `status=$?` で毎回明示的に見ている。
- 検査の fail closed: 引数不正・ディレクトリが無い・スクリプト0件・正規表現を解釈できない → 2、読めないファイル → 違反、自己確認、0件のテスト実行 → 失敗。High を除けば構造は筋が通っている。
- ContentRepository: 型・範囲・一意性・GK の人数・4陣形の過不足・inf の座標・整数の判定を検証し、誤りがあれば空のカタログを返す。`_errors` は読み込みのたびにリセットされる。
- ドメイン: 境界・鏡像・隣接・キーの往復を、仕様の表から直接書いた期待値で固定している。恒真テスト・空振りのテストは無い。
- テスト: `bash tools/run-tests.sh` で手順0〜3がすべて成功（5スイート・69件）。
- 性能: 対象は小さい固定のファイルだけで問題になる規模は無い。
- ドキュメント: 差分は実装と一致。revert で戻せない変更は無い。

### 未検証
- gdUnit4 が、構文エラーのあるテストスイートを失敗として扱うか（リポジトリ内にエラーを仕込む必要があり、変更禁止のため試していない）。
- High は、リポジトリ外の最小のスクリプトで実測したもの。`check_domain_deps.gd` そのものにエラーを仕込んでは試していない。
- CI での実行（CI の設定は差分に無い）。
- 書き出した AAB の権限一覧（書き出し設定は差分に無い）。

### 総合評価
Critical なし。High 1件（禁止依存の検査が実行時エラーで終了コード 0 になる fail open）を直し、`run-tests.sh` で成功を示す行を必須にしてからコミットすることを勧める。Medium 2件は検査の空振りにつながるため、近いうちに fixture とあわせて直すことを勧める。それ以外は問題なし。

### 対応
- High（禁止依存の検査が実行時エラーで終了コード 0 になる）: 直した。
  - 先に検出の仕組みを固定した: `run-tests.sh` で、終了コードに加えて「最後まで走ったときだけ出る行」（自己確認の「ルール N 件中 N 件」、検査の「禁止した参照が 0 件」）と、`SCRIPT ERROR` が無いことを必須にした。手順3でも `Executed test suites: (n/n)` の一致を必須にした。
  - 検査スクリプトに走査の途中の実行時エラーを入れて確かめたところ、単体では指摘どおり終了コード 0 になった。`run-tests.sh` は自己確認では捕まえたが、誤検出の確認と手順2の本番の検査はすり抜けた（1ファイルの検査の関数が打ち切られて 0 件を返し、外側は最後まで進んで「0 件」の行を出したため）。`_run` の完了フラグだけでは防げない形だった。
  - そこで検査スクリプトに、最後まで走ったファイル数・クラス名の収集・自己確認の判定・`_run` の完了を記録し、合わなければ終了コード 2 にした。
  - 実行時エラーを3か所（1ファイルの検査・クラス名の収集・自己確認の判定）に1つずつ入れ、単体の終了コードが 2 になること、`run-tests.sh` がすべての該当手順で NG になることを確かめた（変異が入ったことは行を出して確認し、確認後に元に戻した）。
- Medium（1行の `class_name ... extends` と内部クラスがすり抜ける）: 直した。行のどこにある `extends` も拾い、継承先が識別子でなければ（パス指定）許可しない。内部クラスの fixture（`node/inner_class_ref.gd`）を足した。1行の書き方とパス指定は、fixture に置くとグローバルなクラス名を登録してしまうため、リポジトリ外の probe で検出を確かめた。書式の `"%s" % 3` と剰余の `7 % 3` が誤検出されないことも確かめた。
- Medium（ルールの網羅の隙間）: 直した。`.load(`・`Time`（名前そのもの）・`Engine.get_singleton(`・`ClassDB.instantiate(`・`rand_from_seed(` を足し、fixture に行を足して自己確認で当たることを確かめた（node 8/8、file 4/4、time 2/2、random 3/3）。
- Low（複数行の `"""`）: 今回は直さない。申し送る（意図的に書かないと起きない形で、ドメインに複数行の文字列が出てきた時点で対応する）。
- Low（Godot 呼び出しにタイムアウトが無い）: 今回は直さない。CI を導入する作業で `timeout` で包む（申し送り）。
- Low（手順3が成功時に `Parse Error` を見ていない）: 直した（`Executed test suites: (n/n)` の一致を必須にした）。あわせて、未検証とされた「構文エラーのあるスイート」は、この作業の Red の段階（テストが参照するクラスが無い状態）で、終了コード 105 で失敗することを確かめている。
- Low（`PitchArea` の公開変数・`at_base` での共有）と Low（`PlayerState.duplicate_deep()` の null）: 今回は直さない。値を書き換える処理と null の生成経路はまだ無い。アルゴリズム2で配置を書き換える処理を作るときに、書き換えずに新しい値を作る形を守る（申し送り）。

## 第2回（2026-10-18）— 修正後の再レビュー
- 対象: 第1回の指摘に対する修正（`tools/check_domain_deps.gd`、`tools/run-tests.sh`、`game/tests/fixtures/forbidden_deps/`、`design.md` の該当箇所、本レポート）
- 結果: Critical 0件 / High 0件 / Medium 1件 / Low 5件

### Critical / High
- なし

### Medium
- [運用／バグ] **Medium 2件の修正に付けた fixture が空振りしている。修正を元に戻しても自己確認は緑のまま**
  - リポジトリ外で変異を入れて確かめた。`_extends_regex` を修正前の行頭だけの形に戻しても `ルール 8 件中 8 件`・終了コード 0（`inner_class_ref.gd` の内部クラスは検出されなくなるが、`node_ref.gd` の `extends Node` が同じルールに当たる）。time のルールを修正前の `\bTime\s*\.` に戻しても `2 件中 2 件`・終了コード 0（別名の行は検出されなくなるが、`Time.get_ticks_msec()` が同じルールに当たる）。
  - 原因: 自己確認は「各ルールが1回以上当たったか」しか見ておらず、「fixture の各行が検出されたか」を見ていない。
  - 修正案: fixture の検出されなければならない行に目印（例: 行末の `# expect`。除去前の生の行で読む）を付け、`--self-check` で目印の行がすべて検出されたかも確かめる。`run-tests.sh` の成功の行も「行 M 件中 M 件」に合わせる。上の2つの変異で自己確認が NG になることを確かめてから閉じる。

### Low / 改善提案
- [運用] 複数行の文字列の中の `class_name X` が extends の許可リストに入る（実測で fail open）。修正案: `ProjectSettings.get_global_class_list()` から、検査対象のディレクトリの下の `class` を許可する。
- [運用] 文字列で型名を渡す経路が残っている（`ClassDB.class_call_static`・`Expression`、`var R = RandomNumberGenerator; R.new()`）。修正案: `\bClassDB\b`・`\bExpression\b` を丸ごと禁止する。型注釈として使わないなら `\bRandomNumberGenerator\b` も。
- [運用] `_collect_scripts` に完了の記録が無い。
- [運用] 読めないファイルの扱いのコメント（「見つかった扱い」）と実際の動き（検査できない＝2）が違う。
- [運用] `design.md` の fixture の一覧に `node/inner_class_ref.gd` と `clean/` が載っていない。

### 前回指摘の解消状況
- High（実行時エラーで終了コード 0）: 解消。残る小さな穴は `_collect_scripts` だけ（Low）。
- Medium（1行の書き方・内部クラスの extends）: コードは解消。ただしテストが退行を検出できない（上の Medium）。パス指定の `extends "res://..."` と1行の `class_name ProbeA extends Node` は検出された。
- Medium（ルールの隙間）: 4件とも解消。ただし `\bTime\b` の別名の fixture は空振り（上の Medium）。新しい経路は Low に記載。
- Low（`Executed test suites (n/n)`）: 解消。
- Low（複数行の `"""`・タイムアウト・PitchArea・duplicate_deep）: 申し送りとして記録済み。

### 問題なし
- セキュリティ①〜④・OWASP: 変更ファイルに絶対パス・URL・キー・アカウント情報は無い（`res://` と `tcp://127.0.0.1:0` だけ）。
- バグ: `_finish` を通るすべての return、自己確認の結果と完了フラグの組み合わせ、`all_rules_hit` の空入力、`finished_clean` の行の一致、gdUnit4 のスイート数の比較はどれも正しい。`\.\s*load\s*\(` は `.reload(`・`.load_from_file(` に当たらない。
- 実行: `bash tools/run-tests.sh` がすべて成功。
- 性能・切り戻し: 問題なし。

### 未検証
- 実行時エラーの変異3か所の再現（依頼元が実施済み。再実行していない）。
- `_collect_scripts` の途中で実行時エラーが起きたときの実際の動き（コードを読んだうえでの推論）。
- CI での実行。

### 総合評価
Critical / High はなし。コミットしてよい。ただし Medium 1件は、行ごとの期待を確かめる仕組みを入れるまで「修正をテストで固定した」とは言えない。コミット前に直すか、申し送りとして明記することを勧める。

### 対応
- Medium（fixture の空振り）: 直した。fixture の違反行すべての末尾に `# expect` を付け、`--self-check` で「目印の行がすべて検出されたか」も確かめるようにした。成功の行は「ルール N 件中 N 件、行 M 件中 M 件を検出した」にし、`run-tests.sh` で両方の一致を必須にした（node 8/8・9/9、file 4/4・4/4、time 2/2・3/3、random 3/3・6/6）。指摘の2つの変異（`extends` の検出を行頭だけに戻す、`Time` のルールを `\bTime\s*\.` に戻す）を入れ、どちらも自己確認が NG になり、「検出されなかった行: inner_class_ref.gd:5」「time_ref.gd:10」と名指しされることを確かめた（変異が入ったことは該当行を出して確認し、確認後に元に戻した。最初の変異の試行はシェル経由で `\\` が `\` に変わって変異が入っておらず、それを確認してからスクリプトをファイルで書き直してやり直した）。
- Low（複数行の文字列の `class_name`）: 直した。許可する class_name を `ProjectSettings.get_global_class_list()` から、検査対象のディレクトリの下のものだけ取るようにした。リポジトリ外の probe（複数行の文字列に `class_name Control` を書き、内部クラスで `extends Control`）が検出されることを確かめた。
- Low（文字列で型を渡す経路）: `ClassDB`・`Expression` を名前ごと禁止し、fixture に `Expression.new()` の行を足した。`RandomNumberGenerator` は、生成器を型注釈付きの引数としてドメインへ渡す設計（`component-design.md` の `choose_setup(catalog, rng: RandomNumberGenerator)` など）のため名前ごとは禁止しない。別名経由の `new()` は検出できないことを、検査スクリプトのコメントに申し送りとして書いた。
- Low（`_collect_scripts` の完了の記録）: 直した（入ったディレクトリと最後まで走ったディレクトリの数を突き合わせる）。
- Low（読めないファイルのコメント）: 直した（「検査できなかった」扱い。戻り値も 0 にして、完了の記録の不一致で 2 になる形にそろえた）。
- Low（`design.md` の fixture の一覧）: 直した。
- 修正は Medium / Low に対するもので、新たな Critical / High を直したものではないため、第3回の再レビューは行わない（スキルの規則）。変異と probe による確認は上のとおり。

## レビュー完了（2026-10-18）
- 最終ラウンド: 第2回
- 新たな Critical / High: なし
- 積み残し（Low）:
  - 禁止依存の検査は行単位で、複数行の文字列（`"""`）の閉じの行の後ろのコードを文字列扱いにする。ドメインに複数行の文字列が出てきた時点で対応する（検出するテストは無い）
  - `RandomNumberGenerator` を変数に入れてから `new()` する別名の経路は検出できない（検出するテストは無い。生成器は引数で受け取る設計をコードレビューで守る）
  - `run-tests.sh` の Godot 呼び出しにタイムアウトが無い。CI を導入する作業で `timeout` で包む
  - `PitchArea` の `lane`・`zone` は公開変数で書き換えられ、`TeamLayout.at_base` は同じ `PitchArea` を基本エリアと現在エリアで共有している。`PlayerState.duplicate_deep()` は `base_area` が null だと落ちる。今は書き換え・null の生成経路が無い。アルゴリズム2で配置を書き換える処理を作るときに、新しい値を作る形を守る（検出するテストは無い）
