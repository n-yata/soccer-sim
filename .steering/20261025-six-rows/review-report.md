# コミット前レビューレポート

## 第1回（2026-10-25）
- 対象: 未コミットの変更すべて（作業ツリーの変更 68 ファイル、ステージ済みの削除 2 件 `game/tests/domain/judge/judge_example_layouts.gd`・`.uid`、未追跡の `.steering/20261025-six-rows/`）
- 結果: Critical 0件 / High 0件 / Medium 1件 / Low 3件
- 実施: review-pre-commit（opus のサブエージェント。読み取りのみ）

## コミット前レビュー結果

対象: 未コミットの変更すべて（作業ツリーの変更 68 ファイル、ステージ済みの削除 2 件（`game/tests/domain/judge/judge_example_layouts.gd`・`.uid`）、未追跡の `.steering/20261025-six-rows/`（design・requirements・tasklist））。本体コード（domain・application・config・ui）の差分は全行、テストは抜き取りで確認した（下の「未検証」）。ファイルは一切変更していない。

### Critical（即時対応必須）
- 指摘なし

### High（優先対応）
- 指摘なし

### Medium（対応推奨）
- [バグ] カバーの補足文の「自陣の列」が、6列化で別の列を指すようになった: `game/ui/common/match_texts.gd:50`（`target_rule` の COVER）の文「カバー: 味方1人が、選んだエリアの背後へ下がる。自陣の列と、その場にも横にも背後にも味方がいないエリアは選べない…」は変わっていない。3列のころは「自陣」が選べない D の列の名前だったが、今回の `ZONE_NAMES` では「自陣」は D2 の名前で、選べないのは D1（「自陣ゴール前」）だけになった（`move_rules.gd` の `restricted.zone != GameEnums.Zone.D1`）。結果、画面は「D2 は選べない」と読める誤った説明を出す。例外も警告も出ず、テスト（`game/tests/ui/match_texts_test.gd:200`）も古い文のまま緑になるので気づけない。glossary.md:72 は「守備側のゴール前（1列目）」に正しく直してある。→ 修正例（テストの期待値も同じ文に）: 「カバー: 味方1人が、選んだエリアの背後へ下がる。自陣ゴール前の列と、その場にも横にも背後にも味方がいないエリアは選べない（前にいる味方は届かない）」

### Low / 改善提案
- [運用] 仕様書に「15 エリア」が1か所残っている: `docs/specs/2_basic-design/component-design.md:249`「守備側が選べる 15 エリアのすべてが候補」。30 エリアに直す。ほかに残っている 15 エリア・3ゾーン・`D-C` の記述は、どれも「〜のころ」「〜から変更」という履歴の書き方で問題ない。`docs/ideas/learning-goals-and-tactical-principles.md:50` の「15エリアの人数を導出」は ideas 側の古い記述で、直すかどうかは任意。
- [運用] 作戦ボードの縦の余裕がちょうど 0 になる: 本体の高さ 720 − 96 − 12×2 = 600px が、作戦ボードの最小の高さ（`MIN_CELL.y` 100 × 6 = 600）とぴったり同じ。奥の行の押せる高さも 600 × 0.96 / 6 = 96px で、48dp の下限ちょうど。今は成り立つが、上部バーや余白を 1px でも増やせば下限を割る。数値の関係はコメントに書いてあるので申し送りでよい。
- [バグ（念のため）] `BaseLayoutDeriver._zone_of` に NaN が来ると、`int(floor(NaN))` を `clampi` で丸めて黙って D1 になる。コメントのとおり読み込み側で NaN を弾いているので実害は無い。

### 問題なし
- セキュリティ①（ハードコーディング・シークレット）: 追加行と .steering の3ファイルを、URL（http/https）・claude.ai・api key・secret・token・password・AWS の ARN・12桁の数字・ローカルの絶対パス・`export_presets`・`.env`・keystore・jks で検索し、該当なし。`.gitignore` に `.env`・`.env.*`・`export_presets.cfg*`（`.example` だけ除外）・`*.keystore` が入っている。追跡しているのは `game/export_presets.cfg.example` だけ。`cpu_config.tres` の変更はゲームの調整値（0.75・1.0）だけ。
- セキュリティ②〜④・OWASP: 差分に認証・外部通信・永続化・ログ出力・入力の取り込みは無く、該当しない。`PitchArea.from_key` は区切りの数と名前一覧との照合で入力を検証しており、新しい列名でも正しく働く。
- 混入文字: 変更した全ファイルと .steering を UTF-8 として厳密に読めた。NUL・制御文字・ゼロ幅文字・BOM・U+FFFD・NBSP・CR は 0 件。.gd 以外にタブは無く、追加した .gd の行にスペースのインデントも無い。追加行のバックスラッシュ8か所は、どれも GDScript の行継続として正しい形。
- バグ観点（コード）: `PitchArea` の鏡像（`ZONE_COUNT - 1 - zone`）は6列でも対称、`is_own_half` は `zone < 3`。`_zone_of` は掛けてから割るので境界ちょうどが手前の列に落ちず、`clampi` で y=100 も最後の列に入る。`kickoff_areas` の切り捨てと `_spread_rows` への受け渡し、`xs` と `areas` の添字も正しい。`place_for_kickoff` は両チームとも自陣に置き、全員に `moved_in_turn = true` を立て、GOAL のときは `mark_moved` を飛ばすのでキックオフのターン開始では誰も動かない。`reset_to_base` を呼ぶ箇所も削除した `JudgeExampleLayouts` への参照も残っていない。`MoveRules` の各規則はコメントと仕様の読み替えのとおり。`StyleLayoutCalculator._mark` の `<= M2` は3列のころの D・M と同じ範囲。`BoardProjection.to_plan` は `far_weight = 0` の0除算を分岐で避けている。コードに `Zone.D` 等や `"M-C"` 形式のキーは残っていない（不正なキーの否定ケースだけ）。
- テスト（抜き取り。base_layout_deriver_test・board_projection_test）: 境界値（y = 100/6、100/3、50、200/3、100）、キックオフの期待値、散らす順番は手で書いた期待値で検証しており、恒真テストや実装を写した期待値は無い。
- 性能: 増えた計算は 30 エリアを一定回数ループするものとチームの人数に比例するものだけで、問題になる規模は無い。
- 運用: 調整値の変更理由と日付が `cpu_config.gd` のコメントに残っている。変更はすべて revert で戻せ、永続データが無いのでキー形式の変更に移行は要らない。

### 未検証
- テストの差分（約 40 ファイル）は2ファイルを抜き取って読んだだけ。残りの恒真テスト・空振りの有無は確認していない。
- 仕様書は古い用語の検索結果と該当箇所の周りしか読んでいない。文書全体の書き直しの正しさは確認していない。
- wireframes.drawio は古い用語の検索だけで、図の配置は見ていない。
- テストは再実行していない（594件・失敗0 は依頼元の報告）。
- 画面の実際の見た目（長くなった列名のはみ出し）は見ていない。

### 総合評価
Critical / High の指摘は無い。コミットしてよい。ただし Medium のカバーの補足文は利用者に誤った説明を出す実バグで、直すのは2行（本体とテストの期待値）だけなので、このコミットに含めることを勧める。component-design.md:249 の「15 エリア」もついでに直すとよい。

### 対応
- Medium（カバーの補足文）: 直した。本体とテストの期待値を「自陣ゴール前の列」に。テストを先に直して落ちることを確かめてから本体を直した。
- Low（component-design.md の「15 エリア」）: 30 エリアに直した。ideas の記述は履歴として残す。
- Low（縦の余裕 0）: 申し送り。テスト（`match_screens_test` の盤面の大きさ・`tactics_board_test` の最小の大きさ）が下限を割れば落ちるので、余白を増やす変更は検出できる。実機での押しやすさはシャビが確かめる。
- Low（NaN）: 申し送り。読み込み側で NaN を弾く既存のテストがある。

## レビュー完了（2026-10-25）
- 最終ラウンド: 第1回
- 新たな Critical / High: なし
- 積み残し（Medium / Low を申し送る場合）: 作戦ボードの縦の余裕 0（下限を割る変更は既存の画面のテストで検出できる）、`_zone_of` の NaN（読み込み側で弾く）
