# 設計

- `MoveRules.defense_options`: `CLOSE_DOWN` の運ぶ先を、プレスと同じ全エリアにする（ボールのエリアだけをやめる）。`BLOCK_SHOT` はボールのエリアのまま
- `MoveMenu._defense_menu`: `CLOSE_DOWN` の予測先を、攻撃側のメニューのドリブルの枠（slot 2）の行き先にする。選べなければ `_nearest`
- `OpenPlayJudge`:
  - 「運ぶ前にボールのエリアで奪う」早期の分岐を消す
  - `read_for`: `CLOSE_DOWN` は、攻撃がドリブルで、切ったエリアが運ぶ先と同じときだけ EXACT。それ以外は NONE
  - 結果: `CLOSE_DOWN` で EXACT なら、人数に関係なく `LOSS`。比較エリアは運ぶ先なので、試合進行はそこで守備側のボールにする（寄せた守備の選手もそこにいる）
- `MatchTexts`: 表示名と説明の一言。`JudgeReasonFormatter`: 読み切ったとき（read が EXACT）だけ原因を読みにする
- `tutorial.json`: 守備の段階の説明文
- テスト・仕様書を合わせる
