# コミット前レビューレポート

## 第1回（2026-11-26）
- 対象: feature/game-pwa の未コミット差分（`git diff`。`*.import` の改行コードのみの差は除外）と、未追跡の
  `soccer-game/tools/export-web.sh`・`soccer-game/tools/subset_noto_sans_jp.py`・`soccer-game/game/assets/fonts/noto-sans-jp/`・
  `.steering/20261126-game-pwa/`。subtree の取り込みコミット（c1befc6）の既存コードは対象外（取り込み前に全履歴の秘匿情報を走査済み）
- 結果: Critical 0件 / High 1件 / Medium 2件 / Low 4件

## コミット前レビュー結果

対象: worktree `C:/develop/workspace-claude/soccer-sim-worktrees/game-pwa`（feature/game-pwa）の未コミット差分。範囲は `git diff`（`*.import` の改行コードだけの差は除外）と、未追跡の `soccer-game/tools/export-web.sh`、`soccer-game/tools/subset_noto_sans_jp.py`、`soccer-game/game/assets/fonts/noto-sans-jp/`（.import 2つ、OFL.txt）、`.steering/20261126-game-pwa/` の3文書。woff2 のバイナリの中身は見ていない。

### Critical（即時対応必須）
- なし

### High（優先対応）
- [バグ/運用] `export-web.sh` に実行ビットが付かず、CI の書き出しステップが Permission denied で落ちる: `git config core.filemode` が `false`（Windows）なので、新しいファイルは `git add` で `100644` として登録される。比較すると既存の `soccer-game/tools/run-tests.sh` は `100755`。一方 workflow は `run: GODOT_BIN=... soccer-game/tools/export-web.sh dist/game` と直接実行しているので、exit 126 でジョブが落ちる。fail closed なので壊れたサイトは公開されないが、main への push ごとにデプロイが止まる（ラボの更新も公開されなくなる）。
  → 次のどちらかで直す。
  ```
  git add --chmod=+x soccer-game/tools/export-web.sh   # 登録後に git ls-files -s で 100755 を確認
  ```
  または workflow を `run: GODOT_BIN="$HOME/godot/godot" bash soccer-game/tools/export-web.sh dist/game` にする（package.json の `game:export` は既に `bash` 経由なので、これで揃う）。

### Medium（対応推奨）
- [バグ/運用] `export-web.sh` は出力先の中身を無条件で全削除する（`find "$out_dir" -mindepth 1 -delete`）。ガードは「game ディレクトリの中」しか弾かない: `.`（リポジトリ直下。`.git` ごと消える）、`~`、`soccer-game` など、game_dir の祖先や無関係な既存ディレクトリを渡すと、確認なしに全部消える。`npm run game:export`（固定の `public/game`）と CI（`dist/game`）は安全だが、手で実行して引数を間違えたときの被害は回復できない。
  → 例: 空でない出力先は、前回の書き出し物（`index.pck` か `index.service.worker.js`）があるときだけ消す。あわせて祖先も拒否する。
  ```bash
  case "$game_dir/" in "$out_dir"/*) echo "出力先がプロジェクトの祖先です: $out_dir" >&2; exit 1;; esac
  if [ -n "$(ls -A "$out_dir")" ] && [ ! -f "$out_dir/index.pck" ]; then
  	echo "出力先が空でなく、前回の書き出し物でもありません: $out_dir" >&2; exit 1
  fi
  ```
- [運用] キャッシュキーにハッシュが入っていない（`key: godot-${{ env.GODOT_VERSION }}-web-nothreads`）: 版を変えずに `GODOT_*_SHA512` だけ直しても（固定値の誤りを直すなど）、キャッシュが当たって検証ステップごと飛ばされ、古い中身が使われ続ける。キャッシュヒット時はハッシュを確かめ直さないので、「固定値で検証している」という説明が、キャッシュがある間は成り立たない。キャッシュの書き込みは main の push と手動実行に限られ、作成時に検証済みなので、実際に悪用される余地は小さい。
  → `key: godot-${{ env.GODOT_VERSION }}-${{ hashFiles('.github/workflows/deploy-pages.yml') }}` にするか、キーに2つのハッシュの先頭を入れる（例: `godot-${{ env.GODOT_VERSION }}-${{ env.GODOT_EDITOR_SHA512 }}-${{ env.GODOT_TEMPLATES_SHA512 }}`）。

### Low / 改善提案
- [性能/運用] `curl -fsSL` にタイムアウトもリトライもなく、job にも `timeout-minutes` がない。GitHub 側が遅いと、最悪で既定の6時間ぶら下がる。→ `curl --retry 3 --retry-all-errors --connect-timeout 20 --max-time 600`、job に `timeout-minutes: 30` 程度を付ける。
- [バグ] `subset_noto_sans_jp.py` の `strip_gd_comment` は行ごとに引用符の状態をリセットする。GDScript の複数行文字列（`"""..."""`）の継続行に `#` があると、それ以降をコメントとして捨てる。すると `--check` がそこにしかない文字の欠けを見逃す（静かに誤る経路）。今の文言に該当があるかは見ていない。直すなら、複数行文字列を含む fixture で `--check` が欠けを検出することを先にテストで固定してから。
- [運用] `LICENSES.md` の台帳は著作権表示を「© 2014-2021 Adobe」と書くが、`OFL.txt` とテストは「Copyright 2014-2021 Adobe」。台帳では「表の著作権表示を足した」と説明しているので、表記をどちらかに揃えておくと後で突き合わせやすい。
- [運用] `export-web.sh` は `--import` の出力を `/dev/null` に捨てる（stderr は残る）。Godot の `--import` はエラーがあっても終了コード 0 を返しうるので、失敗の検知は後段の `--export-release` の終了コードと成果物3つの存在確認に頼る形になる。成果物の確認があるので fail closed にはなっている。

### 問題なし
- セキュリティ①
  - 差分と `.steering` の3文書に、シークレット・トークン・パスワード・クラウドのアカウント情報はない（`.steering` は token/secret/password/api key/URL で grep して0件）。
  - workflow の `GODOT_*_SHA512` は公開値で、秘密ではない。
  - ハードコードされた URL は2つ。1つ目は workflow の `github.com/godotengine/godot-builds/releases` で、ハッシュで固定した取得元の識別そのもの。アプリが接続する設定可能なエンドポイントではないので許容と判断した。2つ目はドキュメントの `https://n-yata.github.io/soccer-sim/game/index.html` で、既存の文書と同じ公開 URL。
  - 署名パスワードを持つ `export_presets.cfg` は `soccer-game/.gitignore` で除外済み（`!export_presets.cfg.example` だけ管理）。CI が example から写して作るファイルも Git に入らない。追加した Web プリセットにも署名や鍵の項目はない。
  - `/public/game/` は `.gitignore` に追加済み。
- セキュリティ②〜④: 認証・認可、DB、ユーザー入力、ログ出力を持つ差分はない。PWA は `ensure_cross_origin_isolation_headers=false`、スレッドなし。ラボ側に Service Worker（vite-plugin-pwa 等）がないことを確認したので、ゲームの SW（スコープ `/soccer-sim/game/`）がラボの経路と干渉することはない。
- OWASP A08: 取得物を展開する前に `sha512sum -c` で検証している。固定値が空や誤りなら失敗するので fail closed。テンプレートは `unzip -j` で必要な2ファイルだけを取り出している。workflow の `permissions` は変えていない（`contents: read` のまま）。
- バグ
  - `license_view.gd` の出力形式は `"%s\n\n%s"` と `strip_edges()`。`OFL.txt` の先頭は「Copyright 2014-2021 Adobe (http://www.adobe.com/).」なので、追加したテストのアサーションと一致する。`not_contains(UNREADABLE_TEXT)` も意味のある検証になっている（恒真ではない）。
  - Web プリセットの `include_filter` に `assets/fonts/*/OFL.txt` が入っているので、書き出し版でもライセンスの本文を読める。
  - `app_theme.tres` の `load_steps` は 24→28 で、ext 2つと sub 2つの追加と数が合う。ext_resource の uid は `.import` の uid と一致する。
  - `export-web.sh` は引数の数の検査、`set -euo pipefail`、成果物3つの存在確認があり、失敗をきちんと検知する。
- 性能: ビルド時だけの処理。テンプレートは Web 用だけを展開し、1GB 超の tpz の全展開を避けている。
- 運用: lint・整形の除外（eslint、.prettierignore）、package.json のスクリプト、両方の repository-structure.md・architecture-overview.md への反映はそろっている。revert で戻せない変更（外部への送信、不可逆な移行）は含まない。

### 未検証
- CI の実際の実行（Godot 4.7.2 の URL、SHA512 が公式 `SHA512-SUMS.txt` と一致するか、tpz 内のパス `templates/web_nothreads_release.zip` が実在するか）。ネットワークで取得しての照合はしていない。
- Godot の `--import` と `--export-release` が失敗時に返す終了コード（4.7.2 の実際の挙動）。
- woff2 の中身（name テーブルが残っているか、文言の全文字が入っているか）。`subset_noto_sans_jp.py --check` は実行していない。
- 書き出した PWA の実機確認（オフライン起動、IndexedDB への保存）。
- 取り込み済みの soccer-game の既存コード全体（依頼どおり対象外）。

### 総合評価
Critical はなし。High は1件ある（`export-web.sh` に実行ビットがなく、CI のデプロイが止まる）。これを直してから（`git add --chmod=+x`、または workflow で `bash` 経由にする）コミットしてよい。Medium の2件（出力先の無条件削除、キャッシュキーにハッシュがない）は、このコミットで一緒に直すことを推奨する。

### 対応
- High（`export-web.sh` に実行ビットが無い）: workflow を `bash soccer-game/tools/export-web.sh dist/game` で起動するよう変えた
  （`npm run game:export` と揃う）。あわせてステージ時に `git add --chmod=+x` で 100755 にする（手で直接起動する場合のため）
- Medium（出力先の無条件削除）: `export-web.sh` に2つのガードを足した。Godot のプロジェクトを含むディレクトリ（`.`・`soccer-game` など）を拒む。
  空でなく、前回の書き出し物（`index.pck`）も無いディレクトリを拒む。`.`・`soccer-game`・`soccer-game/game`・`soccer-game/game/ui`・
  無関係なファイルを持つディレクトリで、どれも終了コード 1 になり、中身が消えないことを確かめた
- Medium（キャッシュキーにハッシュが無い）: キーに2つの SHA512 を入れた（約290文字で、上限の512文字に収まる）
- Low（curl のタイムアウト・リトライ）: `--retry 3 --retry-all-errors --connect-timeout 20 --max-time 900` に変え、job に `timeout-minutes: 30` を付けた
- Low（複数行文字列の `#`）: コメントの除去を行単位からファイル全体の走査に変え、`"""`/`'''` を行をまたいで文字列として扱うようにした。
  4つの入力（文字列中の `#`、複数行文字列の中と外の `#`、エスケープした引用符、`##` の文書コメント）で期待どおりに除くことを確かめ、
  `--check` で文言の全文字がサブセットにあることを再確認した
- Low（台帳の © と Copyright）: 台帳の注記に「Barlow の `OFL.txt` に揃えて © を Copyright と書いた」と明記した
- Low（`--import` の出力を捨てる）: 直さない。stderr は残しており、成果物3つの確認で fail closed になっているため

## 第2回（2026-11-26）— 修正後の再レビュー
- 対象: 第1回の修正が触った5ファイル（`.github/workflows/deploy-pages.yml`・`soccer-game/tools/export-web.sh`・
  `soccer-game/tools/subset_noto_sans_jp.py`・`soccer-game/game/assets/LICENSES.md`・`soccer-game/docs/specs/1_requirements/repository-structure.md`）
- 結果: Critical 0件 / High 0件 / Medium 0件 / Low 2件

## コミット前レビュー結果（第2回・修正後の再レビュー）

対象: 修正が入った5ファイル。`.github/workflows/deploy-pages.yml`、`soccer-game/tools/export-web.sh`、`soccer-game/tools/subset_noto_sans_jp.py`、`soccer-game/game/assets/LICENSES.md`、`soccer-game/docs/specs/1_requirements/repository-structure.md`。各ファイルの修正箇所と、そのすぐ周辺だけを見た（読み取りのみ。ファイルは書いていない）。

### Critical（即時対応必須）
- なし

### High（優先対応）
- なし

### Medium（対応推奨）
- なし

### Low / 改善提案
- [バグ] `strip_gd_comments` の挙動を固定するテストがまだない。前回、この Low は「修正するなら、欠けを検出するテストを先に固定してから」としていたが、今回の修正は実装の差し替えだけになっている。`#` を含む複数行文字列や、閉じていない文字列などの入力で除去結果を確かめるテストが無いと、後で戻ってしまっても気づけない。tools/ に Python のテスト基盤が無いなら、doctest を数行足す程度で足りる。（`python -m doctest tools/subset_noto_sans_jp.py` で流せる）
- [運用] `export-web.sh` の空チェックは、前回の書き出しが途中で失敗して `index.pck` の無い中身が残ると、次の実行を拒否する。手で空にすれば済み、fail closed の方向なので問題はないが、エラー文に「途中で失敗した書き出しの残りなら手で消す」と一言あると親切。

### 前回指摘の解消状況
- High（実行ビットがなく、CI の書き出しステップが Permission denied で落ちる）: **解消**。workflow が `bash soccer-game/tools/export-web.sh dist/game` で呼ぶようになったので、ファイルのモードに関係なく動く。`git add --chmod=+x` はステージ時に行う予定とのことで、現時点では未確認。workflow 側の修正だけで CI は通るので、chmod は直接実行するときのための補助という位置づけになる。
- Medium（出力先の無条件削除）: **解消**。追加された2つの拒否を確認した。
  - 祖先の拒否: `case "$game_dir/" in "$out_dir"/*)` でリポジトリ直下や `soccer-game/` を拒否する。
  - 空でない出力先の拒否: 空でなく `index.pck` も無いディレクトリを拒否する。
  - 境界の確認: `out_dir` が `/` のときは祖先パターンが当たらないが空チェックで止まる。`$HOME` や無関係の既存ディレクトリも空チェックで止まる。`out_dir` が `game_dir` そのもののときは既存の「プロジェクトの中」チェックで止まる。CI の `dist/game` と `npm run game:export` の `public/game` は通る。拒否の判定はすべて `find -delete` より前にある。
  - 新しい欠陥は持ち込んでいない。
- Medium（キャッシュキーにハッシュがない）: **解消**。キーに2つの SHA512 が入った。キーの長さは約290文字で、上限512文字に収まる。
- Low（curl と job にタイムアウトがない）: **解消**。`-f` も残っているので HTTP エラーは失敗として扱われる。job に `timeout-minutes: 30` も付いた。
- Low（複数行文字列の `#`）: **実装は解消、テストは未固定**（上の Low）。接頭辞付きの文字列、閉じていない文字列（集める文字が増えるだけで欠けは見逃さない）、コメント中の `'` でも退行は見当たらない。
- Low（© と Copyright の表記差）: **解消**。
- Low（`--import` の出力を捨てる）: **直さない判断を了承する**。

### 問題なし
- セキュリティ: 修正箇所に新しいシークレットや URL は増えていない。キャッシュキーの SHA512 は公開値。ハッシュ検証は展開より前のまま。
- バグ: export-web.sh のチェックの順序（拒否判定 → presets の準備 → 削除 → 書き出し → 成果物の確認）は正しい。`set -euo pipefail` の下でも条件式の中の `ls -A` で意図せず終了しない。
- 性能: 変化なし。
- 運用: repository-structure.md の記述と実装が一致している。

### 未検証
- `git add --chmod=+x` の実施結果（まだステージされていない）。
- CI の実際の実行と、Godot 4.7.2 の `--import` と `--export-release` の終了コードの実際の挙動。
- 依頼元の確認済み事項（公式 SHA512-SUMS.txt と固定値の一致、tpz 内の2ファイルの存在、`--check` の結果）は依頼元の報告として受け取った。

### 総合評価
Critical / High の指摘はなし。前回の High 1件と Medium 2件はすべて解消している。残りは Low 2件で、コミットしてよい。

### 対応
- Low（テストの固定）: `strip_gd_comments` に doctest を5つ足した（`python -m doctest soccer-game/tools/subset_noto_sans_jp.py`）。
  三重引用符の扱いを外す変異を入れると doctest が失敗し、戻すと通ることを確かめた（最初の例だけでは変異を検出できなかったため、
  三重引用符の中に単独の `'` がある例を足した）
- Low（エラー文）: 「途中で失敗した書き出しの残りなら、手で空にしてください」を足した
- Medium 以下の修正のため、再レビューは行わない（収束条件は新たな Critical / High が無いこと）

## レビュー完了（2026-11-26）
- 最終ラウンド: 第2回
- 新たな Critical / High: なし
- 積み残し: なし（第1回の Low「`--import` の出力を捨てる」は、成果物の確認で fail closed になっているため直さない判断。第2回でレビュー役も了承）
- 未検証のまま残るもの: CI の実際の実行（PR のマージ後、`main` への push で初めて動く）、Android 実機でのフォント変更後の見た目
