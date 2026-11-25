# コミット前レビューレポート

## 第1回（2026-10-18）
- 対象: アルゴリズム7の未コミット差分すべて（変更6ファイル、新規19ファイル）。
  - 新規ドメイン: `team_setup.gd`・`match_state.gd`・`turn_record.gd`・`turn_resolution.gd`・`config/match_rule_config.gd`・`match/match_rules.gd`
  - 変更: `judge/move_rules.gd`・`move_options.gd`・`layout/style_layout_calculator.gd`・`component-design.md`
  - テスト: `match_values_test.gd`・`match/match_rules_test.gd`（新規）、`judge/move_rules_test.gd`・`move_values_test.gd`（追加）
  - 各 `.uid`、`.steering/20261018-match-rules/` の3文書
- 結果: Critical 0件 / High 0件 / Medium 0件 / Low 3件
- 備考: 実装レビュー（review-implementation。総合 4.4/5、[必須] なし）の指摘は、このレビューの前に対応済み（tasklist.md に記録）

## コミット前レビュー結果

対象: 未コミットの差分すべて（変更6ファイルの `git diff`、新規ファイル19件の全文。内訳は .gd・.uid・.steering の .md 3件・テスト）。直近の呼び出し先として `TransitionJudge.judge` / `counter_layout` を読み、入力を書き換えないことを確認した。ファイルの書き込み・Godot の起動はしていない。

**Critical / High の指摘はない。**

### Critical（即時対応必須）
- なし

### High（優先対応）
- なし

### Medium（対応推奨）
- なし

### Low / 改善提案
- [運用] 設計書の記述が古いまま残っている: `docs/specs/2_basic-design/component-design.md` §2.5 の `apply_style_change` のコメントが今も「方式の選び直し（STYLE_CHANGE → TURN）。キックオフを行う」のまま。同じ差分で足した「決めごと」の「`apply_style_change` は方式を差し替えて `TURN` に戻すだけ（キックオフは得点の時点で済ませる）」と食い違っている。→ 修正例: `## 方式の選び直し（STYLE_CHANGE → TURN）。方式を差し替えるだけ（失点側のキックオフは得点の時点で済ませてある）`
- [バグ（防御的）] 呼び出し側の誤りへのガードが揃っていない。
  - `resolve_turn` は `status` が FINISHED のとき null を返すが、`apply_style_change` と `apply_halftime` は `stage` しか見ていない。
  - `rules`・`home`・`away` が null のとき、null を返さずに実行時エラーで落ちる。
  - 今の画面遷移では到達しない経路なので実害はない。揃えるなら、`apply_*` の先頭を `if state.status != GameEnums.MatchStatus.IN_PROGRESS or state.stage != ... or home == null or away == null: return null` にし、テストで固定する。
- [性能] ターン記録を毎回すべて写している: `resolve_turn`・`apply_*`・`finish` は呼ぶたびに `MatchState.duplicate_deep` で `turn_records` を全件写す。試合全体の計算量はターン数の2乗になる。初期値の12ターン×2（記録は最大24件）なら問題にならない。`turns_per_half` を数百まで上げると目に見えて重くなる見込みだが、今の設定範囲では申し送りでよい。

### 問題なし
- **セキュリティ**
  - ① ハードコーディング: 対象の全ファイル（.uid・.md を含む）を機械的に走査した。URL・エンドポイント、キー・トークン・パスワード、ARN・アカウントID、ローカルの絶対パス・ユーザー名・メールアドレス・artifact リンクは見つからなかった。
    - 検出されたのは `uid://…`（Godot のリソース ID）と、差分外の既存行にある `res://content`・`user://` だけで、いずれも機密ではない。
    - テストの `match_id` "20261018-120000-0001" はダミー値。
  - ②〜④: オフラインのドメイン層で、認証・入力の取り込み・外部通信・永続化・ログ出力は差分に無い。OWASP の該当項目もない。
  - `push_error` の文言に出るのは手の enum 値だけで、機密は含まれない。
- **制御文字**: 新規・変更ファイルすべてを確認した。タブ・LF 以外の制御文字、NUL、不可視文字（ゼロ幅文字、BOM、NBSP、双方向制御文字、ソフトハイフンなど）、行の途中のリテラル `\n`、.gd のスペースインデントは無い。CR も無く、どのファイルも改行で終わっている。
- **バグ・正しさ**
  - 結果の反映を結果ごとに読み、どれも仕様のとおりだった:
    - GOAL: 加点し、失点側のキックオフをして STYLE_CHANGE へ。
    - LOSS・SAVE: 保持を交代し、ボールをミラーして、トランジションの起点を新しい保持側の向きで作る。
    - REGAIN: 保持を交代し、攻守ターンに戻して配置区間をリセットする。
    - REGAIN_FAILED・NO_CONTEST・STALL・ADVANCE: 保持はそのまま。トランジション明けのときだけ固定を解除する。
    - SAVE の後のボール: 攻撃側の視点で A-C、ミラーして守備側の D-C。
  - ハーフの最終ターン: GOAL・LOSS・SAVE のどれでも HALFTIME または試合終了に正しく切り替わり、トランジションの起点は null に戻る。後半は前半と反対側のキックオフで始まる。
  - 入力を書き換えない:
    - `resolve_turn` は写しを書き換えている。
    - `TransitionJudge.judge` と `counter_layout` は起点を写してから使っている。
    - `turn_start` もトランジションでは起点の写しを返す。
  - 表示と確かめの一致: `options_for` を、選択肢の表示と `resolve_turn` の手の確かめの両方で使っており、両者がずれない。
  - `MoveOptions` の `push_error` ガード: 誤った呼び出しを受け付けず、それをテストで確認している（受け付けないことをエラー文言と `is_available` の両方で検証）。
  - テスト: 恒真テストや空振りしているテストは見当たらない。期待値は具体的なエリアのキー・点数・段階で、境界（最終ターン、範囲外の手の値、段階違い、未知の陣形）、ホームとアウェイを入れ替えた対称性、入力を書き換えないこと、試合の通しまでそろっている。
- **性能**: ループの中の I/O は無い。差分が持ち込んだ計算量は上の Low に書いた1点だけ。
- **運用**
  - 調整値（`turns_per_half`）は Resource に外出しされ、範囲外の値はデータ層で初期値に戻す方針がコメントに書かれている。
  - API の変更（`catalog` 引数の削除、`started_at` の追加）は設計書に反映され、決めた理由も記録されている。
  - 中断データの形式を見直す件も、保存の作業への申し送りとして設計書に書かれている。
  - 変更は新規追加と小さな修正だけで、revert で戻せる。

### 未検証
- テストは実行していない（指示どおり。依頼元の実行結果は 307 件成功）。
- `.steering/` の3文書は機密情報と制御文字の走査だけ行い、内容が仕様と合っているかの照合はしていない。
- 仕様の正本 `functional-overview.md` とは全文を突き合わせていない。設計書の「決めごと」と実装が一致していることだけ確認した。
- `match_rules_test.gd` は、テスト名・主なアサーション・補助関数の冒頭を読んだ。586行すべての期待値を手で計算し直してはいない。

### 総合評価
Critical / High はないので、コミットしてよい。Low の3件は申し送りでよいが、設計書のコメントの食い違いは一行の修正なので、このコミットで直すことを勧める。

### 対応
- Low（設計書の古いコメント）: 直した（`apply_style_change` のコメントを「方式を差し替えるだけ」に）。記述だけの変更なので再レビューは行わない。
- Low（ガードの揃え）: 申し送る。`MatchController` を作る作業で、呼び出し経路とあわせて `status`・null のガードを揃え、テストで固定する。
- Low（ターン記録の全件の写し）: 申し送る。ターン数の範囲（初期値12）では問題にならない。中断データの保存を作る作業で、記録の持ち方とあわせて見直す。
- 未検証のテスト実行: 依頼元がコミット直前に実行する（下の「レビュー完了」）。期待値は実装レビューで結果の反映の表と全行照合済み。
- Critical / High を直したものではないため、再レビューは行わない（スキルの規則）。

## レビュー完了（2026-10-18）
- 最終ラウンド: 第1回
- 新たな Critical / High: なし
- コミット直前のテスト: `bash tools/run-tests.sh` で 307 件成功（24スイート）、禁止依存の検査 0 件、SCRIPT ERROR なし
- 積み残し（Low）: `apply_*` のガードの揃え（`MatchController` の作業）、ターン記録の全件の写し（保存の作業）
