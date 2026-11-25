# 設計（20261110-block-shot-on-ball）

## 変更
| 部品 | 変更 |
| --- | --- |
| `MoveRules.defense_options` | BLOCK_SHOT を、プレスの条件（隣に守備側）の内側から出し、「隣に守備側がいる、またはボールのエリアに守備側がいる」で足す。PRESS・CLOSE_DOWN の条件は変えない |
| `DefenseMover.apply` | BLOCK_SHOT で隣から動かせる選手がいないとき、ボールのエリアに守備側がいれば、配置をそのままに動きの無い `LayoutStep` を返す（null にしない） |
| `MatchTexts.target_rule` | 「シュートコースを塞ぐ: ボールを持つ選手のシュートを止めに行く（隣に味方がいれば1人寄せ、いなければボールのエリアの味方が塞ぐ）。相手のシュートを読む手」 |
| 仕様書 | functional-overview（選べる条件の表）・component-design（MoveRules のコメント・DefenseMover の決めごと）・glossary |

## テスト
- `move_rules_test`: ボールのエリアにだけ守備側がいても塞げる。プレスは隣だけ（ボールのエリアを含まない）のまま。
- `open_play_judge_test`: ボールのエリアにだけ守備側がいて塞ぐと、誰も動かず同数のシュートを止める（読まなければ得点）。
- `match_texts_test`: 条件の一言。
- CPU 同士の計測（一時スクリプト）: 出る割合 65% → 83%。残りは近くに誰もいない場面だけ。
- ゲームバランスの計測（`--with-balance`）を流し直す（ペナルティエリアのシュートが止まりやすくなるため）。
