# コミット前レビューレポート

## 第1回（2026-10-19）
- 対象: 未コミットの差分すべて（application 層・ConfigRepository・調整値の .tres・テスト・設計書・ステアリング）
- 結果: Critical 0件 / High 0件 / Medium 2件 / Low 5件
- 注: レビュー役の返答をそのまま記録する。ローカルの絶対パスの例示は、レビュー役の段階で `<HOME>` に伏せてある。

## コミット前レビュー結果

対象: `git status` の未コミット差分すべて。変更4ファイル（docs/specs/1_requirements/repository-structure.md、docs/specs/2_basic-design/component-design.md、game/application/app.gd、game/tests/application/app_test.gd）は `git diff` で、新規ファイル（.steering/20261019-match-controller/*.md、game/application の6つの .gd と .uid、game/config の2つの .tres、game/data/config_repository.gd、テスト4本）は Read で全文を確認した。

### Critical（即時対応必須）
- なし

### High（優先対応）
- なし

### Medium（対応推奨）
- [バグ] **開示の確認待ちの状態がガードされていない**（`match_controller.gd` の `submit_turn` / `submit_style_change` / `submit_halftime`）: `submit_turn` は `stage == TURN` しか見ないため、開示中（`continue_after_reveal` を呼ぶ前）に2回目の `submit_turn` が通る。UI で確定ボタンが二度押しされると2ターンが連続で解決され、1ターン目の開示が黙って失われる。同様に、得点直後に `continue_after_reveal` を経ずに `submit_style_change` を呼ぶと、S-04 の要求・`stage_changed` が出ないまま再開できる。UI はまだ無いため現時点では表に出ないが、静かに誤る種類の欠陥。→ 開示待ちフラグを持たせる:
  ```gdscript
  var _awaiting_continue: bool = false
  # submit_turn: 冒頭ガードに `or _awaiting_continue` を足し、成功時に _awaiting_continue = true
  # continue_after_reveal: 冒頭で `if _state == null or not _awaiting_continue: return`、続けて _awaiting_continue = false
  # submit_style_change / submit_halftime: 冒頭ガードに `or _awaiting_continue` を足す
  # start_match: _awaiting_continue = false
  ```
  あわせて「`continue_after_reveal` 前の2回目の `submit_turn` は false」「得点直後に `continue_after_reveal` 前の `submit_style_change` は false」のテストを足すとよい。
- [バグ] **方式の選び直し・ハーフタイムの後も `snapshot().movements` に前のターンの動きが残る**（`match_controller.gd` の `snapshot()`）: `_last_record` は `submit_style_change` / `submit_halftime` でクリアされないため、得点のターンの矢印がキックオフの配置の上に重なる。ハーフタイムで陣形が変わった後は、前半の陣形の選手 ID を指す矢印が描かれる。仕様（component-design §3.5）の `movements` は「直前の判定で動いた選手」で、配置のリセット後の盤面と食い違う。→ 盤面用の動きを別に持ち（例: `_board_movements`）、`submit_turn` で設定、`apply_style_change` / `apply_halftime` の成功時に空にする。テストは「ハーフタイム後の `snapshot().movements` は空」で固定する。意図して残すなら設計書にそう書く。

### Low / 改善提案
- [バグ/テスト] **NaN・無限大を拒否するテストが無い**（`config_repository_test.gd`）: 実装と設計書は「`is_finite` で NaN・無限大を拒否する」と書くが、そのケースのテストが無い。`is_finite` を消しても、`temperature = NaN` は `> 0.0` で、`floor_probability = INF` は `< 1.0` で落ちるため、`is_finite` の有無はどのテストでも区別できない。範囲を肯定形で確かめる書き方を守るためにも、`[NAN, 0.1]`・`[INF, 0.1]`・`[1.0, NAN]` を範囲外のケースに足すと、「範囲外なら拒否」の形への書き換えに気づける。
- [バグ] **試合終了後に `continue_after_reveal` を呼ぶたびに S-06 を要求する**: 何度呼んでも毎回要求が出る。上の開示待ちフラグで一緒に解消する。
- [バグ] **CPU の陣形が null のときのエラー文言がずれる**: `start_match` で `_opponent.choose_setup()` が null を返すと、`create_match` の結果次第で、利用者の陣形の ID を出す「陣形が無い」エラーになる。基底の OpponentPolicy を誤って注入した場合だけなので優先度は低い。
- [運用] **「選べる手の先頭」の処理が2か所にある**: `MatchController._first_choice` と `MatchControllerTestHelper.first_choice` が同じ処理の写し。置き換え経路のテストは期待値（PRESS・D-L1）を手で書いているので恒真ではないが、保守で片方だけ直されないよう注意。
- [運用/ドキュメント] **design.md と実装の小さなずれ**: 35行目の `snapshot` の引数に `layout_step` があるが実装には無い。64行目の `_fallback_choice` は実装では `_first_choice`。79行目の「`user://` に書いて」は実装では `create_temp_dir`。

### 問題なし
- セキュリティ①: 対象ファイルに URL・API キー・トークン・パスワード・クラウドアカウント情報は無い。`res://config` は同梱データのパスで秘匿値ではない。秘匿値が無いので .gitignore の確認は該当しない。
- 個人情報・ローカル情報: コミットされるファイル（.steering/・docs/ を含む）に、ローカルの絶対パス（`<HOME>` 配下など）・ユーザー名・メールアドレス・artifact のリンクは無い（差分の各ファイルを grep で確認）。
- 不可視文字: ゼロ幅文字・双方向制御文字・BOM（U+200B–200F、202A–202E、2066–2069、FEFF）は .uid 以外の対象ファイルで0件。.uid は ASCII 以外の文字を含まない。
- セキュリティ②〜④・OWASP: 認証・外部入力・DB・シェル・ネットワークは無い（オフライン単体）。ログ（push_error）に出るのはファイル名・設定値・内部のエラーメッセージだけで、機密情報は含まない。
- バグ（視点の変換）: `MatchState.ball_area` は保持側の視点、`TurnRecord` の座標は攻撃側の視点、選手と動きは各チーム自身の視点。ドメインのこの定義と、ViewConverter が変換元の側を選ぶ方法は一致する。人数の入れ替えと役割の判定も正しい。
- バグ（ConfigRepository）: 範囲は肯定形で確かめている。型が違えば（`as`）初期値に戻る。キャッシュあり。ファイルの有無は `ResourceLoader.exists` で先に確かめる。同梱の .tres（12 / 1.0 / 0.1）は範囲内。
- バグ（CPU の手の置き換え）: 書き出し版の経路のテストは期待値を手で書いている（PRESS・D-L1）。
- バグ（app.gd）: rng を1つ作り、CpuOpponent と MatchController で共有している。`request_screen` の Callable の先は Node（App）なので、RefCounted の循環参照は無い。
- 性能: 1ターンにドメインの関数を数回呼ぶだけで、固定盤面（15エリア・22人）なので上限がある。I/O は .tres を初回に1回読むだけ。
- 運用: 調整値は .tres に外出しされ、不正なときの挙動（初期値を使い push_error）は設計書に書かれている。revert で戻せない変更は無い。repository-structure.md と component-design.md は更新済み。

### 未検証
- テストと変異は自分では実行していない（374件成功・変異26個すべて検出は依頼元の申告）。
- Godot エディタで .tres を読めるか、class_name が解決できるか（.uid の整合）は実機で確かめていない。
- Medium の2件は読んで出した結論で、再現するテストは書いていない（書き込み禁止のため）。

### 総合評価
**Critical / High の指摘なし。コミットしてよい。** Medium の2件（開示待ちのガードが無い、選び直し・ハーフタイムの後に動きが残る）は、UI をつなぐ前にテストで固定してから直すことを勧める。

### 対応
- Medium 1（開示待ちのガード）: 直す。先にテストを書いて落ちることを確かめてから、開示待ちのフラグを入れる。終了後の S-06 の重複要求（Low）もこれで一緒に直る。
- Medium 2（選び直し・ハーフタイムの後に動きが残る）: 直す。先にテストを書いてから、盤面に出す動きを、選び直し・ハーフタイムで空にする。
- Low（NaN・無限大のテスト）: 範囲外のケースに NaN・INF を足し、`is_finite` を消す変異で検出できることを確かめる。
- Low（design.md のずれ）: 実装に合わせて直す。
- Low（CPU の陣形が null のときの文言）: 直さない。誤って基底クラスを注入したときだけ起き、そのときも push_error で止まる。保存の作業で開始の経路を見直すときに合わせる。
- Low（先頭の手の処理が2か所）: 直さない。本番のコードをテストから使うと、置き換えの経路の期待値が実装の写しになる。テストの期待値は手で書いているので、ずれても検出できる。

#### 対応の結果
- Medium 1: `_awaiting_continue` を足した。テストを先に書き、二度押しのテストが落ちることを確かめてから直した。足したテストは次のとおり。
  - 開示の確認前の2回目の `submit_turn` は false。
  - 確認待ちが無いときの `continue_after_reveal` は何もしない。
  - 得点直後・ハーフタイム直後に、確認前の `submit_style_change` / `submit_halftime` は false。
  - 結果の画面は1回だけ頼む。
- Medium 2: 盤面に出す動きを `_board_movements` に分けた。選び直し・ハーフタイムで空にする。ハーフタイム後と得点後の選び直し後に、`snapshot().movements` が空であることをテストで固定した。ハーフタイムの前に動きがあることも確かめ、テストが空振りしないようにした。
- Low（NaN・無限大）: `[INF, 0.1]`・`[NAN, 0.1]`・`[1.0, NAN]` を足した。
- 変異7個（上の各ガード・空にする処理・`is_finite`）は、すべて狙ったテストで検出された。テストは376件すべて成功した。
- `component-design.md` §3.2 の注記と design.md を、実装に合わせて直した。
- 再レビューはしない。Critical / High の修正ではないため（スキルの規則: Medium / Low はループを回す理由にならない）。

## レビュー完了（2026-10-19）
- 最終ラウンド: 第1回
- 新たな Critical / High: なし
- 積み残し（Low）:
  - CPU の陣形が null のときのエラーの文言。
  - 「選べる手の先頭」の処理が2か所にあること。
  - どちらも理由は上の「対応」に書いた。悪用しうる欠陥ではない。
