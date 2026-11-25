# コミット前レビューレポート

## 第1回（2026-10-18）
- 対象: `.gitignore`、`docs/specs/1_requirements/` の architecture-overview・non-functional-requirements・repository-structure、`docs/specs/2_basic-design/component-design.md`、`.steering/20261018-dev-env-setup/`、追跡予定の `game/` 一式（529件。うち gdUnit4 が516件）
- 結果: Critical 0件 / High 0件 / Medium 1件 / Low 4件

## コミット前レビュー結果

### Critical（即時対応必須）
- なし

### High（優先対応）
- なし

### Medium（対応推奨）
- [運用/性能] フォントの原本が履歴に永続化される: `NotoSansJP-Regular.otf`（4.5MB）と `Bold.otf`（4.7MB）、合わせて約9.2MB をそのままコミットする。文書では「サブセットは後の作業で作る」としているが、一度コミットした原本は、後でサブセットに置き換えても Git の履歴に残り続ける。その分、クローンが永久に重くなる。→ 次のどちらかを選ぶ。(a) 今回はフォントをコミットに含めない。サブセット作成の作業で初めて追跡する（LICENSES.md の Noto の行は「未配置」と明記する）。(b) 履歴に約9MB 残ることを受け入れる。その場合は、受け入れたことを design.md か retrospective.md に書いておく。Git LFS は過剰だと思う。

### Low / 改善提案
- [運用] `.steering/20261018-dev-env-setup/design.md` §6 が実際のファイルと食い違っている。
  - `.example` に「画面の向き・API レベル」を書く、とあるが、実際の `.example` にはどちらも無い（向きは project.godot 側、API レベルは既定値 24/36 のまま）。
  - 「権限: すべて false」とあるが、明記しているのは `permissions/internet=false` だけ（ほかの権限は既定で false）。
  - 「aapt2 dump（build-tools 35.0.1）」とあるが、実際に入れたのは 36.0.0。
  - 「実施中に変えたこと」にも、この3点は書かれていない。→ 実際の内容に直すか、「実施中に変えたこと」へ追記する。
- [運用] architecture-overview.md の GDScript の行の末尾「採用する 4.7 系の記載そのもの）」は文が途中で切れていて意味が通らない。→ 例えば「確認したのは採用する 4.7 系のドキュメントそのもの）」に直す。
- [運用] Noto Sans JP の `OFL.txt` には著作権表示の行が無い（LICENSES.md にその旨の記載はある）。OFL は「各複製に著作権表示とライセンスを含める」ことを条件にしている。フォントの name テーブルにも表示はあるが、`OFL.txt` の先頭に `Copyright 2014-2021 Adobe (http://www.adobe.com/), with Reserved Font Name 'Source'` 相当ではなく、LICENSES.md に書いた表示をそのまま足しておくほうが安全。アプリ内のライセンス表示を作るときの申し送りでもよい。
- [バグ（将来）] `.example` の `exclude_filter="tests/*, addons/gdUnit4/*"` は、gdUnit4 のスクリプトを書き出しから外す。一方で、`.godot/global_script_class_cache.cfg` には gdUnit4 の class_name が残る。今回は仮のメインシーンで起動を確かめているが、本番のコードがうっかり `GdUnit*` を参照すると、実機でだけ壊れる。最初の機能の作業で、書き出した APK を起動するスモーク確認を CI か手順に固定することを勧める。

### 問題なし
- セキュリティ①（ハードコーディング/シークレット）
  - 調べた範囲: 追跡予定の全テキストファイル（gdUnit4 の .uid/.import/.cfg を含む）、新しい .steering、変更した文書。
  - 検索したもの: `C:\`・`C:/`、`AppData`、`/Users/`、`/home/`、ユーザー名、password・secret・token・api_key、`http(s)://`。
  - 該当は2種類だけで、問題ない。フォントの配布元・著作権表示の公開 URL（LICENSES.md、OFL.txt）と、`--remote-debug tcp://127.0.0.1:0`（ループバック。外部の接続先ではない）。
  - SDK・JDK のパスはプレースホルダ（`<Android SDK のパス>`）にしてある。クラウドのアカウント情報は無い。フォントの .import は `res://` 参照だけで、ローカルの絶対パスは入っていない。
- `export_presets.cfg` の除外
  - `git check-ignore` で、`game/export_presets.cfg` が `export_presets.cfg*` で除外されることを確かめた。`.example` は `!export_presets.cfg.example` で追跡される。
  - `game/.godot/` は `.godot/` で除外される。Godot 4 の `export_credentials.cfg` も `.godot/` の中にあるので一緒に除外される。
  - `*.keystore`・`*.jks` の除外を確かめた。`ls-files` の一覧に `export_presets.cfg` と `.godot` は無い。ローカルの `export_presets.cfg` は `.example` と同じバイト列で、署名の項目は無い。
- `.example` に署名の項目・鍵・パスワードは無い。`permissions/internet=false`。パッケージ名は仮の `com.example.soccergame`。
- NFR-10（外部通信なし）: 書き出し設定に、権限を有効にする項目は無い。
- 文書と実ファイルの整合: repository-structure.md の設定項目の表と project.godot の値を1項目ずつ照合した（警告3項目=2、1280×720、canvas_items/keep_height、orientation=4、gl_compatibility（.mobile も）、import_etc2_astc=true、editor_plugins）。手順5の `.example` の要点（プリセット名・include/exclude フィルタ・アーキテクチャ・internet=false・export_path）は実物と一致した。`.gitignore` の Godot セクションも、文書の check-ignore の表のパターンと一致した。
- gdUnit4 の改変の有無: v6.2.2 の展開物と `diff -rq` で比べ、.uid/.import 以外の差分は0件。追加の .uid/.import は Godot が生成したもの。LICENSE（MIT）は同梱。追跡予定の件数とディスク上の件数（516）は一致した。
- 認証・認可、インジェクション、情報漏洩: 差分に実行コード・入出力処理・ログ出力は無い。該当なし。
- 性能: 差分に実行時のコードは無い。リポジトリの大きさは Medium の指摘に挙げた。
- 運用: 手順・バージョン・未定事項（基準端末、持ち越し）は文書に記録されている。revert で戻せない変更は無い（フォントの履歴の件は Medium の指摘のとおり）。

### 未検証
- 実際に Godot を動かす確認は行っていない（エディタの起動、テストランナー、APK の書き出し、エミュレーターでの起動、aapt2 での権限の確認）。文書と .steering の記載を信じた状態。
- 外部の事実関係（Godot 4.7 の Android 要件、Google Play の API 36 の期限、フォントの配布元・版数・RFN の有無、gdUnit4 6.2 の Godot 4.7 対応）は確かめていない。
- gdUnit4 の中身のセキュリティ監査は対象外（指示どおり）。改変が無いことの確認だけ行った。
- フォントのバイナリが公式配布物と同じかどうか（ハッシュでの照合）は確かめていない。

### 総合評価
Critical / High の指摘は無い。コミットしてよい。ただし、フォントの原本約9MB を履歴に残すかどうか（Medium）だけは、コミット前に判断してほしい。Low の指摘は文書の食い違いだけなので、同じコミットで直すのが楽だと思う。

### 対応
- Medium（フォントの原本約9.2MB が履歴に残る）: シャビの判断で (a) を選んだ。Noto Sans JP のファイルを置かず、台帳の置き場所を「未配置」にして、取得元・版・RFN の確認結果だけを残した。Barlow Condensed（約0.3MB）は置いた。消したあと、`godot --headless --editor --quit` でエラー 0 件を確かめた。
- Low（design.md §6 の食い違い）: 直した。`.example` の項目（向き・API レベルは書かない、権限は INTERNET だけを明記）と、aapt2 の版（36.0.0）を実物に合わせ、「実施中に変えたこと」にも追記した。
- Low（architecture-overview.md の文の切れ）: 「確認したのは、採用する 4.7 系のドキュメントそのもの」に直した。
- Low（Noto Sans JP の OFL.txt に著作権表示の行が無い）: 今回は直さない。LICENSES.md に著作権表示と、アプリ内のライセンスの表示に両方を載せる旨を記録済み。アプリ内のライセンスの表示を作る作業で、表示する本文に著作権表示を含める（その作業で、書き出しに `OFL.txt` を含める設定も足す）。
- Low（書き出しで外した gdUnit4 のクラスを本番コードが参照すると実機でだけ壊れる）: 今回は直さない。最初の機能の作業で、書き出した APK を起動するスモーク確認を手順か CI に入れる（retrospective.md に申し送る）。
- 修正は文書だけで、Critical / High の修正ではないため、再レビューは行わない（スキルの規則: Medium / Low はループを回す理由にならない）。

## レビュー完了（2026-10-18）
- 最終ラウンド: 第1回
- 新たな Critical / High: なし
- 積み残し（Low）:
  - Noto Sans JP を置くときに、`OFL.txt` に著作権表示を足す。アプリ内のライセンスの表示を作るときに、書き出しに `OFL.txt` を含める（検出するテストは無い。台帳に手順を記録した）
  - 書き出した APK を起動するスモーク確認を、最初の機能の作業で手順か CI に入れる（いまは検出する仕組みが無い）
