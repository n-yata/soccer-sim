# コミット前レビューレポート

## 第1回（2026-10-18）
- 対象: アルゴリズム6の未コミット差分すべて。
  - 新規: `judge/transition_judge.gd`・`judge/transition_judge_test.gd`（各 `.uid`）、`.steering/20261018-transition-judge/` の3文書
  - 変更: `layout/style_layout_calculator.gd`・`judge/open_play_judge.gd`・`turn_choice.gd`・`style_layout_calculator_test.gd`・`move_values_test.gd`・`component-design.md`
- 結果: Critical 0件 / High 0件 / Medium 0件 / Low 3件
- 備考: 実装レビュー（review-implementation。総合 4.6/5、[必須] なし）の指摘は、このレビューの前に対応済み（tasklist.md に記録）
- 転記の注記: レビュー担当が検索したローカルパスの具体的な書き方の例は、コミットに残さないため伏せた（それ以外はそのまま）

## コミット前レビュー結果

対象: 未コミットの差分すべて。差分が依存している範囲として次を読んだ: StyleLayoutCalculator の既存ヘルパー（reset_segment / _start_areas / _slide / _mark / _layout_with）、MoveOptions.needs_target、MoveRules.is_allowed / pos_transition_options、PitchArea.mirrored / forward / neighbors4、functional-overview.md のアルゴリズム3末尾・アルゴリズム6・JE-07。

### Critical（即時対応必須）
- なし

### High（優先対応）
- なし

### Medium（対応推奨）
- なし

### Low / 改善提案
- [バグ] 手の値の範囲は judge では見ていない: `TransitionJudge.judge` は、奪取側の手が `COUNTER` でなければ一律 `SECURE`、喪失側の手が `RETREAT` でなければ一律 `COUNTER_PRESS` として扱う。`is_complete_for` は family と運ぶ先しか見ないため、範囲外の action（例: POS_TRANS で 99）を渡すと null にならず、保持として静かに判定される。ただ、呼び出し側の `MoveRules.is_allowed` は `options.is_available` で、許可していない action を拒否する。前段で必ず弾かれるので、今の時点で実害はない。doc コメントの「選べない手では null」は「手の種類の取り違え・運ぶ先の欠け」に限った話なので、記述と動作は食い違っていない。直す場合は、`match` で SECURE / COUNTER_PRESS を明示し、それ以外は null を返す形にできる:
  ```gdscript
  if winner_choice.action != GameEnums.PosTransAction.COUNTER and winner_choice.action != GameEnums.PosTransAction.SECURE:
  	return null
  if loser_choice.action != GameEnums.NegTransAction.RETREAT and loser_choice.action != GameEnums.NegTransAction.COUNTER_PRESS:
  	return null
  ```
  直すなら、範囲外の action が null になるテストを先に固定すること。
- [運用] .steering/20261018-transition-judge/design.md の名前の食い違い: 「即時奪回×保持」の関数名が `_area_total(layout, x)` になっているが、実装は `_total_around`。作業記録なので実害はない。
- [運用] 下流への申し送り: `NO_CONTEST` では `JudgeOutput.detail` が null になる（仕様どおりで、`JudgeOutput.duplicate_deep` も null を扱える）。アルゴリズム7・ターン記録・画面側で detail を読むときは null を扱う必要がある。今は差分の外に呼び出し元が無いので、問題としては挙げない。

### 問題なし
- セキュリティ①（ハードコーディング・シークレット）: 対象の 13 ファイルすべて（.uid・.md を含む）で、次が無いことを確認した。URL・WebSocket URL、API キー・トークン・パスワード、クラウドアカウント ID・ARN、ローカルの絶対パス、ユーザー名、メールアドレス、artifact リンク。.uid は `uid://...` の 1 行だけ。`.gitignore` には `.env` と `.env.*` が入っている。
- セキュリティ②〜④・OWASP: 差分は純粋関数のドメインロジックとテストと文書だけ。認証・入力処理・ログ出力・外部通信・永続化・依存の追加はなく、該当なし。
- 文字の衛生（Python で全ファイルをバイト単位で検査）:
  - タブと LF 以外の制御文字・NUL・DEL: なし
  - CR: なし（作業コピーは LF）
  - ゼロ幅文字・BiDi 制御・BOM・NBSP: なし
  - 行の途中のリテラル `\n`: 0 件
  - .gd の行頭スペースインデント・行末の空白: なし
  - 末尾の改行: 全ファイルにあり
- バグ（正しさ）:
  - `OpenPlayJudge` の書き換えは前と同じ動作: `_is_usable` が持っていた null 検査は呼び出し側に移り、family と運ぶ先の検査は `TurnChoice.is_complete_for` に移った。`detail_at` / `outcome_of` は名前を変えただけで、中身は変わっていない。
  - `retreat`:
    - 起点は `reset_segment`（固定を解除）から取っている。
    - ZONE は `ball.mirrored()` でスライドし、MAN は `pair.attacker` の現在の配置へマークする。
    - 動きの from は直前の位置で、変わった選手だけを出す。チームは `defender_side()`。
    - 入力は `duplicate_deep` してから使い、書き換えない。
  - `counter_layout`:
    - 現在エリアを起点にし、固定された選手は除外する。
    - 前が盤外（`forward()` が null）なら残る。
    - 保持型のときもコピーを返す。
  - 即時奪回の比較: 喪失側は `mirrored()` の座標で数え、`neighbors4` は盤内だけを返す。不等号は「喪失側 > 奪取側」なので、同数は REGAIN_FAILED になり、仕様どおり。
  - JE-07: テストの期待値（飛び出し後の配置 A 1 0 2 0 1 / M 1 0 2 0 1 / D 0 0 2 0 0、ADVANCE 1-0、REGAIN_FAILED 4-2）を仕様と突き合わせ、一致を確認した。テストの「D-C 2・M-C 2」は奪取側の視点で、仕様の「A-C 2・M-C 2」は喪失側の視点から見た同じ値。
  - テストの中身: 恒真テストや期待値の実装コピーは見当たらない。手計算で期待値を検算したのは次の 3 件で、いずれも正しかった。
    - retreat のスライドの向き（d1→D-L1、d3→M-R1）
    - マンツーマンのマーカー（m1→D-C）
    - カウンター×リトリートの同数で DEFENDER のカバーになる件
  - 状態の持ち越しや並行性の問題: 全関数が static で、共有状態を持たない。
- 性能: 1 回の判定は、5×3 の盤に対する数回の走査と配置のコピーで定数オーダー。ループの中で I/O はしていない。
- 運用:
  - component-design.md の §2.3・§2.4 に、`retreat`・`detail_at` / `outcome_of`・`counter_layout`・`is_complete_for` と、実装で決めたことが反映されている。
  - 内容は通常の revert で戻せる。後方互換に関わる公開 API・設定・スキーマの変更はない（`_detail` / `_outcome` は private からの昇格）。

### 未検証
- テストは実行していない（指示どおり。依頼元の報告では 263 件成功）。Godot の型警告・解析エラーも同じ理由で確かめていない。
- `GameEnums` の enum の並び（Zone D=0 / M=1 / A=2 など）は、テストのヘルパー `_rows` のラベルの付け方から推測しただけで、定義は読んでいない。

### 総合評価
Critical / High の指摘はない。Medium もない。Low は 3 件で、どれもコミットを止める理由にはならない。そのままコミットしてよい。Low の 1 件目（範囲外の action）は、今は `MoveRules.is_allowed` で防がれている。アルゴリズム7で judge の呼び出し経路を作るときに、`is_allowed` を必ず先に呼ぶことを確認するよう申し送るのが妥当。

### 対応
- Low（範囲外の action）: 申し送る。`MoveRules.is_allowed` が先に拒否する。アルゴリズム7で判定を呼ぶ経路を作るときに、`is_allowed` を先に呼ぶことをテストで固定する（振り返りに記録）。
- Low（design.md の名前の食い違い）: 直した（`_total_around`）。
- Low（`NO_CONTEST` の内訳が null）: 申し送る。ターン記録・画面で内訳を読む作業で扱う（振り返りに記録）。
- 未検証のテスト実行・型警告: 依頼元がコミット直前に実行する（下の「レビュー完了」）。`GameEnums` の並びは `game_enums.gd` で `Zone { D, M, A }`・`Lane { L2, L1, C, R1, R2 }` と定義されている（依頼元が確認）。
- Critical / High を直したものではないため、再レビューは行わない（スキルの規則）。

## レビュー完了（2026-10-18）
- 最終ラウンド: 第1回
- 新たな Critical / High: なし
- コミット直前のテスト: `bash tools/run-tests.sh` で 263 件成功（22スイート）、禁止依存の検査 0 件、SCRIPT ERROR なし
- 積み残し（Low）: 範囲外の action（`is_allowed` が先に拒否）、`NO_CONTEST` の内訳が null（読む側で扱う）
