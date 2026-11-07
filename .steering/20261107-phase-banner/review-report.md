# コミット前レビューレポート

## 第1回（2026-11-07）
- 対象: ステージ済みの差分（`git diff --cached`、14ファイル）。別セッションの未ステージの変更は対象外
- 結果: Critical 0件 / High 0件 / Medium 0件 / Low 3件

## コミット前レビュー結果

対象: ステージ済みの差分のみ（`git diff --cached`、14ファイル）。game/ui/screens/s03_match/phase_banner.gd（新規）、match_screen.gd、game/ui/common/match_texts.gd、game/tests/ui/phase_banner_test.gd（新規）、match_screens_test.gd、.uid 2件、docs/specs 4件、.steering/20261107-phase-banner 3件。未ステージの差分は見ていない。

### Critical（即時対応必須）
- なし

### High（優先対応）
- なし

### Medium（対応推奨）
- なし

### Low / 改善提案
- [バグ] 文言の配列を enum の値で直接引いている: `MatchTexts.PHASE_BANNER_TITLES[phase]` と `PHASE_BANNER_LINES[phase]` は、`GameEnums.Phase { ATTACK, NEG_TRANSITION, DEFENSE, POS_TRANSITION }` の並びに暗黙で頼っている。いまは並びが合っていて、phase_banner_test が4局面すべての見出しと一言を検証しているので、並びが変わればテストが落ちる。実害は無いので申し送りでよい。
- [バグ／テスト] `test_the_banner_hides_itself_after_its_duration` は実時間のタイマー（0.6 秒と 0.8 秒）で判定している。負荷が高いとフレームが飛んで揺れる可能性はわずかにあるが、判定前後の余裕（表示中を 0.6 秒で確認、非表示を 1.4 秒で確認）は十分ある。
- [運用] 秒数（DURATION・FADE_IN・FADE_OUT）を presentation_config に出さず定数にしている。理由（別セッションがその設定を作業中で、いまは遊んで確かめる段階）は design.md に書いてあり、意図した判断として受け入れる。

### 問題なし
- セキュリティ① ハードコーディング: URL・エンドポイント・API キー・トークン・パスワード・HMAC キー・クラウドのアカウント ID・ARN・リージョン固有のエンドポイントは、コードにもドキュメント（docs/specs・.steering）にも無い。追加された文字列は画面の文言、テーマ名、res:// パス、.uid だけ。.gitignore と .env は差分に関係しない（秘匿値を新しく扱っていない）。
- セキュリティ②〜④: 認証・認可、DB、シェル、ファイル入出力、ネットワーク、ログ出力、外部入力、デシリアライズはどれも差分に無い。Label に出すのは固定の定数の文言だけなので、注入の経路は無い。OWASP A01〜A10 で該当する項目は無い。
- バグ: キックオフでは出さない（`enter` の先頭で `_last_phase = -1` に戻すので、早期 return の経路でも前の局面が残らない）。比べ方 `_last_phase != -1 and phase != _last_phase` は正しい。`_on_reveal_started` の `dismiss()` で、帯が次のターンに残らない。`show_phase` は出している途中の Tween を `_stop()` で止めてから出し直すので、Tween が二重に走らない。`dismiss()` も Tween を止めるので、あとから `hide` コールバックが走って食い違うことも無い。
- バグ: タップは素通しになる。帯、その下の VBoxContainer、2つの Label のすべてが `MOUSE_FILTER_IGNORE` で、テストが全部の子を見て確かめている。重なり順は盤面パネルの後・メニューの前で、メニューが帯より上に来る。
- バグ: `user_phase` の対応（TRANSITION で持っている側がポジトラ）と色の選び方（攻撃・ポジトラは you、守備・ネガトラは opponent）は合っている。
- 直近の呼び出し元: `MatchBoardPanel` の `turn_started`・`reveal_started` シグナルは、ステージ済み（インデックス）の版にある（18行目・20行目、送出は 132行目・424行目）。帯が使うテーマのキー（`TacticsBoard/colors/you・opponent・bg・text`、`TagLabel/fonts/font`）も、インデックスの app_theme.tres にある。未ステージの app_theme.tres の変更に頼っていない。
- テスト: 恒真テストではない。match_screens_test はシード固定で最大 20 ターン流し、局面が変わったターン（changes>0）と変わらないターン（stays>0）の両方を通ったことを確かめているので、空振りしない。tasklist には、出す条件を壊すとテストが落ちたこと（変異の確認）が記録されている。
- 性能: 局面が変わったターンに Tween を1つ作るだけ。毎フレームの処理もループ内の I/O も無い。
- 運用: revert で戻せる（新規ファイルと追加だけで、保存データ・設定キーに触れていない）。仕様書（screen-03-match の「ターンを始める」6. と開示 1.、screen-design、screen-common のフォント表、component-design）に反映されている。

### 未検証
- テストの実行は確かめていない。依頼元は「全体 1210 件成功」と報告しているが、作業ツリーには未ステージの変更（theme、match_board_panel 等）が混ざっている。tasklist の「インデックスの中身だけで run-tests.sh を流す」はまだ `[ ]` のまま。ステージ済みの内容だけで緑かどうかは、このレビューでは確かめていない（読み取りに限っているため）。依存するシグナルとテーマのキーがインデックスにあることは、静的には確かめた。
- 実際の画面での見た目（帯の重なり方、フェード）は確かめていない。

### 総合評価
Critical / High の指摘は無い。コミットしてよい。ただしその前に、tasklist にあるとおり、ステージ済みの内容だけで全体テストを timeout 180 秒で流して緑であることを確かめてほしい。

### 対応
- Low 1（enum の並びに頼る配列）: 直さない。4局面すべての見出しと一言をテストが固定しているので、並びが変われば落ちる。
- Low 2（実時間のタイマー）: 直さない。判定の前後に 0.6 秒の余裕がある。
- Low 3（秒数を定数にした）: 意図した判断（design.md）。
- 未検証のテスト実行: レビューの前に、インデックスの中身（`git checkout-index` で書き出したもの）で `tools/run-tests.sh` を timeout 180 秒で流していた（1210 件成功・140 秒。tasklist の更新がレビューの後だった）。見た目は実際の画面で撮って確かめた（tasklist フェーズ1）。

## レビュー完了（2026-11-07）
- 最終ラウンド: 第1回
- 新たな Critical / High: なし
- 積み残し: Low 3件（上の「対応」のとおり。Low 1 はテストで検出できる）

## 第2回（2026-11-07）— 守備の一言の修正
- 対象: ステージ済みの差分（4ファイル。match_texts.gd の守備の一言、phase_banner_test.gd の期待値、tasklist・retrospective の追記）
- 結果: Critical 0件 / High 0件 / Medium 0件 / Low 0件

## コミット前レビュー結果

対象: ステージ済みの差分だけ（`git diff --cached`、4ファイル、+12/-2）
- game/ui/common/match_texts.gd（PHASE_BANNER_LINES の DEFENSE 要素を「守備 ― ゴールを守る」に変更）
- game/tests/ui/phase_banner_test.gd（期待値を同じ文言に変更）
- .steering/20261107-phase-banner/tasklist.md、retrospective.md（追記）

### Critical（即時対応必須）
- なし

### High（優先対応）
- なし

### Medium（対応推奨）
- なし

### Low / 改善提案
- なし

### 問題なし
- セキュリティ①ハードコーディング: 差分に URL・エンドポイント、シークレット、キー、トークン、クラウドのアカウント ID や ARN はない。steering の追記にも機密情報はない（日付と会話の要約だけ）。
- セキュリティ②〜④と OWASP: 文字列定数を1つ変えただけ。認証、入力処理、ログ、デシリアライズに触れていないので該当しない。
- バグ: 配列の要素数（4）と並び（GameEnums.Phase の順）は変わっていない。呼び出し元は match_texts.gd:146 の `PHASE_BANNER_LINES[phase]` だけで、壊れる経路はない。テストは本番の定数をそのまま写した恒真テストではない。局面ごとにリテラルの期待値と照らしており、文言を戻せば落ちる。
- バグ（取り残し）: 旧文言「CPU のボールを守る」をインデックス全体で `git grep --cached` した。残っているのは今回の steering の追記2か所だけで、どちらも経緯の説明なので問題ない。docs/specs（.drawio を含む）、ソース、テストに旧文言は残っていない。
- 性能: 変化なし（定数文字列の差し替え）。
- 運用: 設定キーや API の変更はなく、revert で戻せる。tasklist と retrospective に経緯が書かれている。

### 未検証
- テストは再実行していない。1210 件成功は依頼元の報告による。
- 新しい文言がサッカーの言い方として適切かは仕様の判断なので、レビューの対象外とした。

### 総合評価
Critical・High の指摘はなし（Medium・Low もなし）。コミットしてよい。ファイルは一切書き換えていない。

### 対応
- 指摘なし。テストはレビューの前に、インデックスの中身だけで流した（1210 件成功・147 秒）。文言はシャビの指摘（守るのはゴール）に合わせた。

## レビュー完了（2026-11-07、第2回）
- 最終ラウンド: 第2回
- 新たな Critical / High: なし
- 積み残し: なし
