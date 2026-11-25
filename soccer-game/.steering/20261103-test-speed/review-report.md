# コミット前レビューレポート

## 第1回（2026-11-03）
- 対象: ステージ済みの差分（tools/run-tests.sh、docs/specs/1_requirements/repository-structure.md、game/tests 配下の8ファイル。ball_holder_invariant_test は改名）
- 結果: Critical 0件 / High 0件 / Medium 2件 / Low 6件（うち1件は「問題なし」の確認として記されたもの）

## コミット前レビュー結果

対象: `git diff --cached` のステージ済み10ファイル（tools/run-tests.sh、docs/specs/1_requirements/repository-structure.md、game/tests 配下の8ファイル。ball_holder_invariant_test は改名）。静的に読んだだけで、Godot のテストは実行していない。gdUnit4 の挙動は同梱の addon のソース（JUnitXmlReportWriter.gd・XmlElement.gd・GdUnitTestCIRunner.gd）で確かめた。

### Critical（即時対応必須）
- なし

### High（優先対応）
- なし

### Medium（対応推奨）
- [運用] 失敗したときの手がかりが消える: 標準出力は捨てていて、`stderr$group.log` も `trap 'rm -rf "$work_dir"' EXIT` で終了時に消える。画面に出るのは `SCRIPT ERROR|Parse Error` に合う行だけになる。そのため次の2つの場面で、何が起きたのか分からないまま「NG」だけが出る。(a) results.xml が欠けた場合（Godot がクラッシュした、timeout 以外の異常終了）。(b) 終了コード 101 の場合。GdUnitTestCIRunner.report_exit_code() はオーファンノードがあると 101 を返す。このときは failures=0・errors=0 なので FAILED 行が出ず、「gdUnit4 が失敗した（終了コード 101）」としか表示されない。どちらも fail closed で、判定は正しく失敗になる。問題は調べにくいことだけ。→ 失敗時は work_dir を残し、終了コードが非0のバッチではエラー出力の末尾を出す。
- [運用/性能] timeout で止めた後に Godot が残る恐れ（未検証）: `timeout` が SIGTERM を送るのは直接起動したプロセスだけ。GODOT_BIN が Windows の `*_console.exe`（本体を子プロセスとして起動するラッパー）なら、ラッパーだけが終わって本体は動き続ける可能性がある。→ `timeout -k 10` にし、timeout したときは Godot の残りを検出して警告する。

### Low / 改善提案
- [バグ] スイートが0件のとき `cat` が標準入力を待つ（非対話なら tests=0 で NG。fail closed）。
- [バグ] `tests/` 直下に置いたスイートは流れない（スイートの数が合わずに NG。fail closed。今は該当ファイルが無い）。
- [バグ] `status` には最後に起きた非0の終了コードしか残らない（表示だけ。判定には影響しない）。
- [運用/ドキュメント] repository-structure.md の「`*_test.gd` の数と合わなければ失敗」は、既定の実行では `tests/balance/` を除いた数との比較であることを補うと正確。
- [テスト] finalize の統合で、保存先も記録先も無い状態で `final_record()` を作る確認が消えた。実害は小さい。
- [テスト] 回数を絞ったことで偶然の経路に当たる確率は下がるが、通るべき経路の網羅の確認（one_step の全種類、codec の段階、CPU の方式の入れ替わり）は残っており、空振りして緑になる心配はない。

### 問題なし
- セキュリティ: シークレット・URL・アカウント情報のハードコーディングは無い（`127.0.0.1:0` は既存の、デバッガ回避のための指定）。引数は `--with-balance` 以外を拒否。スイートのパスはすべてクォートしてあり、シェルインジェクションの余地は無い。`mktemp -d` の一時ディレクトリ。APPDATA の差し替えで本物の保存データに触れない。ドキュメントに機密情報は無い。
- fail open の主要な経路はすべて塞がっている（テストの失敗・スイートの読み込み失敗・results.xml の欠け・timeout・終了コード 101〜105）。
- XML の集計（属性の並び、`<testsuite ` と `<testsuites` の区別、グループごとに別の `-rd` と `-rc 1` で二重に数えない）。
- `*_test.gd` でない GdUnitTestSuite は無い。列挙方式に変えて黙って漏れるスイートは無い。
- match_board_panel_test の `[LOST_TRANSITION_SEED] + range(100)` は、シードが合わなくなっても退行しない。
- ball_holder_invariant_test の旧パスを参照しているのは `.steering/` の過去の記録だけ。
- 性能: 順に流すのでメモリは Godot 1本分。切り戻しは revert でできる。

### 未検証
- 実際の実行時間と、`-rd` に `cygpath -m` のパスを渡したときに results.xml が出ること（テストを実行しない指示のため）。
- timeout したときに Godot の子プロセスが残るかどうか。
- 標準出力をファイルに書いた場合の速度。

### 総合評価
Critical / High の指摘は無い。コミットしてよい。Medium の2件は近いうちの対応を勧める。

### 対応
- Medium（手がかりの消失）: 失敗したときは作業用のディレクトリを消さずに場所を出すようにした。終了コードが非0のバッチは、ディレクトリ名とエラー出力の末尾20行を出す。
- Medium（Godot の残り）: `timeout -k 10` にした。timeout したときは `tasklist` で Godot の残りを調べ、残っていれば注意を出す。
- Low（ドキュメント）: repository-structure.md に「既定の実行では `tests/balance/` を除いた数」と、失敗時にディレクトリの場所を出すことを足した。
- Low（そのほか）: どれも fail closed のため直さない。未検証のうち実行時間と results.xml の出力は、修正後に `tools/run-tests.sh` を流して確かめた（160秒・78スイート・1092件・失敗0）。

## レビュー完了（2026-11-03）
- 最終ラウンド: 第1回
- 新たな Critical / High: なし
- 積み残し（Low）: スイート0件・`tests/` 直下のスイート・`status` の表示・保存先なしの `final_record()`。前の3つは fail closed（NG になる）。最後の1つは検出するテストが無いが、`final_record()` は状態から組み立てるだけで実害は小さい
