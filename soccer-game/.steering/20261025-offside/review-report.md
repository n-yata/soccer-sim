# コミット前レビューレポート

## 第1回（2026-10-25）
- 対象: 未コミットの変更すべて（変更済みの36ファイル `game/` 28・`docs/specs` 8、未追跡の `game/domain/judge/offside_rule.gd`・`game/tests/domain/judge/offside_rule_test.gd` と .uid、`.steering/20261025-offside/`）
- 結果: Critical 0件 / High 0件 / Medium 0件 / Low 4件
- 実施: review-pre-commit（opus のサブエージェント。読み取りのみ）

## コミット前レビュー結果

対象は未コミットの変更すべて。変更済みの36ファイル（game/ 配下28、docs/specs 配下8）、未追跡の `game/domain/judge/offside_rule.gd`・`game/tests/domain/judge/offside_rule_test.gd` と両方の .uid、`.steering/20261025-offside/`（design.md・requirements.md・tasklist.md）を見た。ファイルは一切変更していない。

### Critical（即時対応必須）
- なし

### High（優先対応）
- なし

### Medium（対応推奨）
- なし

### Low / 改善提案
1. **[バグ] `ChoiceHint.duplicate_deep` で `is_offside` を写す行がテストで固定されていない**: `game/domain/choice_hint.gd` の `copied.is_offside = is_offside` を消しても、どのテストも落ちない。今は本番コードからの呼び出しが見当たらないので実害は無いが、`hints_to_user` で一度起きた「写し漏れで札が出ない」と同じ型の欠陥を検出できない。→ hint_values_test に、真・偽の両方で `duplicate_deep().is_offside` を確かめるテストを足す。
2. **[バグ／テスト補助] `match_balance_probe._count` がオフサイドを「読まれなかった手」とスルーパスの母数に数えている**: OFFSIDE の判定は `JudgeDetail.read` を入れない（既定値 NONE）ので、オフサイドになった攻撃は `unread_moves` に入り、`unread_loss` 率を薄める。スルーパスがオフサイドになったときも `through_passes` には入るが `through_losses` には入らない。今の実測ではオフサイドが 0〜0.09 回/試合で、数字への影響は無視できる。→ `offsides += 1` の直後に `return` を足し、読みとスルーパスの集計から外すか、外すことをコメントで明示する。
3. **[バグ／表示] オフサイドラインの表示条件にステージを含めていない**: `ViewConverter.snapshot` は `user_has_ball and turn_kind == OPEN_PLAY` だけで線を出すので、方式変更画面（STYLE_CHANGE）・ハーフタイム・試合終了の盤面にも線が出うる。害は小さい。→ `state.stage == TURN and state.status == IN_PROGRESS` を条件に足す。
4. **[運用] 情報のみ: 改行コード**: `game/ui/board2d/match_board_panel.gd` は作業コピーが CRLF。インデックスは LF で、差分は3行だけ。対応不要。

### 問題なし
**セキュリティ**（①〜④必須項目と OWASP）
- 追加した行と未追跡ファイル全体を走査し、URL・エンドポイント、API キー・トークン・パスワード・HMAC キーとフォールバック値、AWS アカウントID・ARN・リージョンのエンドポイント、ローカルの絶対パス、claude.ai のリンクのどれも見つからなかった。仕様書と .steering にも実際の URL・キーの記載は無い。
- `game/export_presets.cfg` は ignored で差分に入っていない。.gitignore は `.env`・`.env.*`・`export_presets.cfg*`・`*.keystore` を除外している。差分に .env・署名鍵は無い。
- 認証・認可、インジェクション、情報漏洩、A01〜A10 は、オフラインの単体ゲームで外部入出力が無いため該当なし。`push_error` に出すのは設定の数値だけ。

**不可視文字・化け**
- NUL・ZWSP・BOM・NBSP・ソフトハイフン・bidi 制御・C0 制御文字は 0件。追加した行のバックスラッシュは2か所だけで、どちらも正当な GDScript の行継続（`config_repository.gd`・`move_preview.gd`）。.md の追加行にタブは無い。.gd のインデントはタブで統一。
- `cpu_config.tres` は ASCII のみで、末尾は `offside_penalty = 3.0` と LF。2つの .uid は `uid://` 1行だけ。

**バグ・正しさ**
- `OffsideRule.line_row` の境界（0人なら 5、自陣の境 2、ボールの列が前ならボールの列）は要求どおりで、テストで固定されている。
- `receiver_area` の各手は前提を満たす（ロングボール・前へのショートパスは運ぶ先に味方がいることを MoveRules が保証、スルーパスは判定と選べる条件が同じ関数）。
- `TurnOutcome.OFFSIDE` の影響を呼び出し元ごとに確かめた（番号・`OUTCOME_WORDS`・`turn_winner`・判定理由・`_ends_attack`・`hands_over`・`to_transition`）。
- 判定は守備の手の後・攻撃の手の前。`_ball_after`・固定の解除・アディショナルタイムはテストで固定（HOME と AWAY の入れ替えも含む）。
- ヒント・プレビュー・盤面のラインはターン開始の配置、判定は守備の手の後の配置を使う。この違いは仕様とコメントに明記されている。
- `ChoiceHint` を写す本番コードは `hints_to_user` と `duplicate_deep` の2か所で、両方とも `is_offside` を写している。
- `ConfigRepository` は `offside_penalty` を有限・0以上の検査に掛け、テストで固定している。
- 追加したテストは期待値を手で書いていて、オフサイドとオンサイドを対にしている。恒真テストは無い。

**性能**: 追加した処理は守備側の人数（最大10人）と選択肢の数に比例するループだけ。I/O は無い。

**運用**: 新しい設定値は .tres に外出しされ、範囲外なら初期値へ戻る。列挙値は末尾に足した。永続化は無く移行は要らない。revert で戻せる。仕様書は要件・機能概要・用語集・コンポーネント設計・画面設計・画面詳細・リポジトリ構造まで反映されている。

### 未検証
- テストと変異は実行していない（依頼元の報告「643件・失敗0、変異24個 KILLED」を受け取っている）。
- 実際の画面の見た目は見ていない。
- 仕様書の差分は、機密情報とコードとの矛盾だけを見た。.drawio は差分に無い。
- オフサイドの後に守備側の保持者を置く処理（既存）は差分の外で読んでいない。

### 総合評価
Critical / High の指摘はなし。コミットしてよい。Low 1 はコミット前に固定するのを勧める。Low 2・3 は申し送りでよい。

### 対応
- Low 1（`duplicate_deep` のテスト）: hint_values_test にテストを足した。写す行を消すと落ちることを変異で確かめた。
- Low 2（測定の補助）: オフサイドは `offsides` を数えたら `return` し、読みとスルーパスの集計から外した。
- Low 3（表示の条件）: ステージが TURN・試合が進行中のときだけ線を出すようにし、方式変更の段階で出ないことをテストに足した。
- Low 4（改行コード）: 対応不要。

## レビュー完了（2026-10-25）
- 最終ラウンド: 第1回
- 新たな Critical / High: なし
- 積み残し（Medium / Low を申し送る場合）: なし
