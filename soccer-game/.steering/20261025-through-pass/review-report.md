# コミット前レビューレポート

## 第1回（2026-10-25）
- 対象: 未コミットの変更すべて（追跡済みの30ファイル `game/domain`・`game/ui`・`game/tests`・`docs/specs` と、未追跡の `.steering/20261025-through-pass/`）
- 結果: Critical 0件 / High 0件 / Medium 0件 / Low 4件
- 実施: review-pre-commit（opus のサブエージェント。読み取りのみ）

## コミット前レビュー結果

対象: 未コミットの変更すべて。追跡済みの30ファイル（`game/domain`・`game/ui`・`game/tests`・`docs/specs`）と、未追跡の `.steering/20261025-through-pass/`（requirements.md・design.md・tasklist.md）。ファイルは一切変更していない。

**結論: Critical / High は無い。コミットしてよい。** Low が4件あるが、どれも申し送りで足りる。

### Critical（即時対応必須）
- 指摘なし

### High（優先対応）
- 指摘なし

### Medium（対応推奨）
- 指摘なし

### Low / 改善提案
- **[バグ] 0件のとき NaN になる:** `match_balance_probe.gd` の `through_pass_rate()` と `through_pass_loss_rate()` は、0件だと `float(0)/0` を計算する。CPU がスルーパスを一度も選ばない設定やシードでは、`summary()` に `through_loss=nan%` と出る。エラーにはならない。既存の `read_loss_rate` なども同じ書き方で、使うのはテスト補助だけ。直すなら `return 0.0 if through_passes == 0 else float(through_losses) / through_passes`。
- **[運用] 判定の内訳でカバーの表示が実際の判定と食い違う:** `JudgeReasonFormatter.detail()` は、スルーパスでも「カバー あり/なし」を出す。スルーパスはカバーを判定しない（`through_pass_outcome`）ので、「カバー あり」と出ても結果には効いていない。仕様の「判定理由は読みだけを原因にする」とは矛盾しない。気になるなら、スルーパスのときはカバー欄を出さないか「—」にする。
- **[運用] ステアリングの記述が古い:** `tasklist.md` には「609件・失敗0」とあるが、依頼時の実績は613件。「ワイヤーフレームの手のボタンの図（.drawio）の描き直しは積み残し」とあるので、仕様書のうち図だけが6つの手に追い付いていない。振り返りで申し送ってほしい。
- **[運用] 改行コード:** `match_board_panel.gd` だけ、作業コピーの改行が CRLF になっている（index は LF）。Git が LF に正規化して取り込むので、コミットの中身には影響しない。参考情報。

### 問題なし（観点ごと）

**セキュリティ**
- ハードコーディング: 追加行に URL・エンドポイント・WebSocket の記載は無い。唯一の文字列は `res://ui/screens/...tscn` で、Godot の内部リソースパス。シークレット・キー・トークン・パスワード、その代わりのフォールバック値も無い。AWS のアカウントID・ARN も無い。仕様書と .steering にも実際の URL・キーは書かれていない。
- 入れてはいけないもの: `game/export_presets.cfg` は `.gitignore` で除外されている。署名鍵・.env はステージ対象に無い。ローカルの絶対パスと claude.ai のリンクは、差分にも .steering にも無い。
- 認証・認可・インジェクション・情報漏洩: オフライン単体のゲームで、外部入力・DB・シェル・ログ出力・通信を持たないので該当なし。OWASP Top 10 に当たる変更も無い。
- ヒントから人数差が漏れない: スルーパスの札は人数を比べない手として扱われる（`is_compared=false`）。`hint_counts` は空、控えめな色は `is_compared and diff()==0` に限られる。テストで固定されている。

**シェル経由の編集による化け**
- 追加行（.steering を含む）を走査した。NUL・不可視文字（ゼロ幅スペース・BOM・NBSP・双方向制御文字）・制御文字は0件。.md の追加行にタブは無い。.gd の追加行で、インデントが空白になっている行も無い。
- バックスラッシュは全9か所を目で確認し、すべて正常（行の継続が7か所。文字列リテラル中の `\n` は `"スルーパス\n選択不可"` の1か所で、`ChoicePanel.UNAVAILABLE_SUFFIX` と一致）。
- 日本語の文字化けは無い。

**バグ・正しさ**
- enum の並べ替え: `PlayType` の途中に `THROUGH_PASS` を入れたが、番号に依存する箇所（`MatchTexts.ACTION_NAMES`、`ChoicePanel` のボタンの添字、`MoveHints` の `PlayType.values()`）はどれも追随済み。.tres・.json・.tscn に番号は埋め込まれていない。保存形式は区分値を enum の名前で持つ。`MovementReason.THROUGH_RUN` は末尾に足したので既存の番号は変わらない。
- 受け手の選び方と走り込み: `through_pass_runner` を選べるか（`MoveRules`）と動かす（`apply_attack`）で共有。ヒント・プレビュー・判定とも攻撃側の配置がターン開始時と同じ状態で呼ばれるので、選べた運ぶ先で受け手がいなくなることは無い。
- `_move_and_fix` への切り出し: ドリブルの移動元が `ball` から `from` に変わったが、運ぶ選手は ball にいる選手に限られるので結果は同じ。受け手がもう `T` にいれば固定だけする分岐はテストで通っている。
- CPU: 評価値は0、カウンター型の好む手に入っている。
- 判定理由: `_is_through_pass` は攻守ターンに限り、攻撃側の選択を利用者の役割から正しく選ぶ。null も確認している。
- テストの中身: 読みの全段階を人数の大小と逆の場面で検証。受け手の優先順位（両方の並び）、マンツーマンの追従、文言、札の色も入っている。前提を確かめる assert があり、空振りする構造ではない。恒真テストは見当たらない。

**性能**
- `through_pass_runner` は運ぶ先ごとに攻撃側の選手を全員なめる（30エリア × 数人）。盤面の大きさは固定。
- `_scroll_to_target_info` は2フレーム待つだけ。

**運用**
- `await` の後の安全確認: 待つ前とフレームごとに `is_inside_tree()` を見て、`is_instance_valid(_target_info)` と `visible` を確かめてからスクロールする。手を連打すると処理が重なるが、どれもスクロールするだけで害は無い。
- 仕様書: functional-overview（アルゴリズム3・5、JE-09、CPU）、glossary、requirements-definition、component-design、screen-design、screen-03-match に反映されている。ノード名 `SideScroll` も実装と一致する。
- 切り戻し: 不可逆な変更は無く、revert で戻せる。

### 未検証
- テストの実行（613件・失敗0）と変異（20個すべて KILLED）は依頼文の申告をもとにしており、このレビューでは再実行していない。
- 画面の見た目（ボタン6つの収まり、白線と3マスの一致、スクロールの実際の動き）は実機で確認していない。
- `.drawio` の差分は無い（積み残し）ため、図の中身は見ていない。
- 仕様書の差分は追加行を中心に読み、変更の無い部分との整合は見ていない。

### 総合評価
Critical / High は無い。コミットしてよい。Low の4件は申し送りで足りる。直すなら、NaN の件は数行で済むのでコミット前に入れてもよい。

### 対応
- Low（NaN）: 直した。`through_pass_rate`・`through_pass_loss_rate` とも、0件なら 0 を返す（既存の率の関数は今回の差分の外なので触らない）。
- Low（判定の内訳のカバー）: 申し送り。結果には効かない表示で、読みを原因にする判定理由とは矛盾しない。シャビが遊んで気になれば直す。
- Low（ステアリングの記述）: tasklist の件数を 613件に直した。ワイヤーフレームの図の描き直しは振り返りで申し送る。
- Low（改行コード）: 対応不要（Git が LF に正規化する）。

## レビュー完了（2026-10-25）
- 最終ラウンド: 第1回
- 新たな Critical / High: なし
- 積み残し（Medium / Low を申し送る場合）: 判定の内訳のカバー欄（スルーパスでは結果に効かない）、ワイヤーフレームの手のボタンの図
