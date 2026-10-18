# コミット前レビューレポート

## 第1回（2026-10-18）
- 対象: アルゴリズム8・ヒントの未コミット差分すべて（22ファイル）。
  - 新規ソース: `choice_hint.gd`・`config/cpu_config.gd`・`judge/move_hints.gd`・`cpu/cpu_planner.gd`
  - 変更ソース: `judge/open_play_judge.gd`・`judge/transition_judge.gd`
  - テスト: `hint_values_test.gd`・`judge/move_hints_test.gd`・`cpu/cpu_planner_test.gd`
  - `.uid` 7件
  - 文書: `functional-overview.md`・`component-design.md`・`usecase-sequences.drawio`・`.steering/20261018-cpu-planner/*.md`
- 結果: Critical 0件 / High 0件 / Medium 0件 / Low 4件
- 備考: 実装レビュー（review-implementation。総合 4.2/5、[必須] なし）の指摘は、このレビューの前に対応済み（tasklist.md に記録）
- 転記の注記: レビュー担当が検索したローカルパスの具体的な書き方の例は、コミットに残さないため伏せた（それ以外はそのまま）

## コミット前レビュー結果

ファイルは一切変更していません。Godot も起動していません。

### Critical（即時対応必須）
- 指摘なし

### High（優先対応）
- 指摘なし

### Medium（対応推奨）
- 指摘なし

### Low / 改善提案
- [バグ] `CpuPlanner.probabilities` に非有限の評価値が入ると NaN になる
  - 起きること: 公開関数なので scores に `INF` が入りえます。その場合 `highest = INF` で `(s - highest)` が `INF - INF = NaN` になり、全要素が NaN になります。`_draw` では `r < NaN` が常に偽なので、抽選が最後の手へ黙って偏ります。scores に NaN が入った場合も `scores.max()` の結果が不定になります。
  - 実害の範囲: `choose_turn` から渡る評価値は `score()` が int から作るので、現状この経路では起きません。実害が出るのは将来、評価値の計算を変えたときだけです。
  - 修正の方向: τ・floor が壊れたときと同じく一様な確率へ倒します。あわせて `[INF, 0.0]`・`[NAN, 0.0]` を渡すと一様になるテストを先に固定しておくのが望ましいです。
- [バグ] `MoveHints.evaluate` は null の場合に null を返さず落ちる
  - トランジションで `state.transition_origin` が null のとき、または `state.ball_area` が null のとき、null を返さずに実行時エラーになります。
  - `OpenPlayJudge.judge` は ball が null なら null を返す方針なので、それとは非対称です。
  - 呼び出し側（試合進行）が保証する前提なら、コメントで明記する程度で足ります。
- [運用] τ・floor が壊れていたときの一様確率への切り替えは無音で行われる
  - 検査はデータ層（ConfigRepository）の責務と明記されているので、ドメイン側はこれで妥当です。
  - 申し送り: データ層の範囲検査で、エラーとして扱うのかログに残すのかを決めておいてください。
- [運用・情報] usecase-sequences.drawio の作業コピーの末尾の改行だけが LF から CRLF に変わっている
  - `core.autocrlf=true` で、.gitattributes に drawio の `-text` 指定がないため、コミット時に LF へ正規化されます。差分には出ず、実害はありません。

### 問題なし
**セキュリティ**
- 全22ファイル（.gd・.uid・.md・.drawio）を走査し、以下が無いことを確認した。
  - URL・エンドポイント
  - キー・トークン・パスワード
  - ARN・12桁のアカウントID
  - ローカルの絶対パス
  - ユーザー名・メールアドレス
  - artifact へのリンク
- 検出されたのは `res://`・`user://`・`uid://` だけで、これは誤検知。.uid は `uid://...` の1行だけ。
- 認証・認可、インジェクション、情報漏洩: 外部通信・入力処理・ログ出力がない差分なので該当なし。

**乱数**
- `cpu_planner.gd` は乱数生成器を生成していない。使っているのは引数の `rng.randf()` と `rng.randi_range()` だけ。
- `tools/check_domain_deps.gd` の random ルールとも整合している。
  - `(?<![\w.])randi_range\(` はメソッド呼び出し（直前が `.`）を除外する。
  - `RandomNumberGenerator.new(` はドメイン内に無い。
- グローバルの `randi`・`randf`・`randomize`・`seed`、`shuffle`、`pick_random` も使っていない。
- `RandomNumberGenerator.new()` はテスト（cpu_planner_test.gd）の中だけ。

**数値**
- `_is_usable` は「範囲の内側にある」ことを確かめる形で書かれており、次の値はすべて一様な確率になる。
  - τ: 0・負・NaN・INF
  - floor: 1.0・負・NaN
- テスト `test_broken_settings_fall_back_to_uniform_probabilities` で固定済み。
- 最大値を引いてから softmax を取っているので、最大の要素の重みは exp(0)=1 になり、`total >= 1` でゼロ除算は起きない。
- 極端に小さい正の τ（非正規化数）でも、指数の引数が -INF なら exp は 0 になり、NaN は出ない。
- ±1000 の評価値は既存のテストで確認済み。

**apply_attack の切り出し**
- 切り出し前と同じ動作であることを確認した。
  - ドリブルの後は、守備がマンツーマンのときだけ remark する。
  - ドリブル以外は配置の写しを返す。
- `_dribble`・`remark` は入力を書き換えない（コピーを返す）。そのため MoveHints が同じ `start` を手ごとに使い回しても汚染は起きない。

**ヒントと判定の整合**
- カウンター: `counter_layout` の後に `detail_at` で数えており、判定と同じ。
- 即時奪回: `total_around(origin.attacker, ball)` と `total_around(origin.defender, ball.mirrored())` で数えており、判定と同じ。
- 評価値の向き: 守備の手は「攻撃側 − 守備側」、それ以外は「自分 − 相手」になっており、functional-overview.md の追記と一致。

**`_total_around` の公開**
- `total_around` への改名は、呼び出し元2か所すべてに反映済み。

**テスト**
- 恒真テストや期待値の実装コピーは無い。期待値は手で書いた値か、判定（judge）の出力との突き合わせ。
- 境界と異常系を含んでいる。
  - 空の入力
  - 選べる手が無い場合に null
  - 陣形が無い場合に null
  - 状態を変更しないこと
  - 多数のシードで、選んだ手が `is_allowed` を通ること

**usecase-sequences.drawio**
- XML として正常にパースできる。
- タグ単位の差分は mxCell の value 属性6か所だけで、どれも関数の引数の文字列の変更。
  - catalog の削除
  - create_match への started_at の追加
- 変更後の引数は、実装（match_rules.gd・move_rules.gd）と component-design.md のシグネチャに一致する。

**混入文字のチェック**
- .gd・.md・.uid のどこにも、次のものは無い。
  - タブ以外の制御文字・NUL・BOM
  - ゼロ幅文字・NBSP
  - 行の途中に紛れ込んだリテラルの `\n`
  - スペースによるインデント・行末の空白
- 行継続のバックスラッシュは、`if` の条件式（open_play_judge・transition_judge・cpu_planner）で正しく残っている。
- 不自然に長い連結行も無い（200桁を超える行は無い）。

**性能**
- 計算量は選択肢の数（エリア数の程度）に比例し、上限がある。
- I/O もループ内での重い処理も無い。

**運用**
- 設定値（τ・floor）は CpuConfig（Resource）に外部化されている。
- 初期値は functional-overview.md の表と一致し、テストで固定されている。
- 仕様の変更（アルゴリズム8の追記、引数から catalog を削除）は component-design.md と drawio に反映済み。
- revert で戻せない変更は無い。

### 未検証
- テストの実行（指示により実行していない。依頼元がコミット直前に実行する前提）。
- `.steering/` の3文書は機密・混入文字の走査だけ行った。内容の妥当性はレビューしていない。
- 次の座標系の前提は、判定のコードと同じ前提に立っていることだけを確認した。
  - `state.ball_area` は保持側の視点の座標であること
  - MoveOptions の守備の運ぶ先は攻撃側の視点の座標であること
- MoveRules・MoveOptions 本体は差分外なので読んでいない。

### 総合評価
Critical / High の指摘は無く、コミットしてよい状態です。Low のうち非有限の評価値で NaN になる件は、テストを先に固定してから直すか、申し送りにすることを勧めます。

### 対応
- Low（非有限の評価値）: 直した。先に `[INF, 0.0]`・`[NAN, 0.0]`・`[-INF, 1.0]` で一様になるテストを書いて失敗を確かめ、評価値に非有限があれば一様な確率にする形にした（`_are_finite`）。
- Low（`MoveHints.evaluate` の null）: Doc comment に前提（`MatchRules` が作った試合中の状態。ボール位置があり、トランジションでは起点がある）を明記した。
- Low（一様への切り替えが無音）: 申し送る。`ConfigRepository` の作業で、範囲外の値をエラー・ログのどちらで扱うかを決める。
- Low（drawio の改行）: 対応しない。コミット時に正規化され、差分に出ない。
- 修正は Low の対応で、Critical / High を直したものではないため、再レビューは行わない（スキルの規則）。依頼元が修正後のテストを実行した（下の「レビュー完了」）。

## レビュー完了（2026-10-18）
- 最終ラウンド: 第1回
- 新たな Critical / High: なし
- コミット直前のテスト: `bash tools/run-tests.sh` で 337 件成功（27スイート）、禁止依存の検査 0 件、SCRIPT ERROR なし
- 積み残し（Low）: 設定値が壊れたときの扱い（`ConfigRepository` の作業）
