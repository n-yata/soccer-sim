# 設計: 解説の「実戦では」（FR-23）

## 1. 単純化 ID の付け方

ゲームでの扱いが文の内容と直接重なるものだけに付ける（関わりが薄いものまで付けると、毎回同じ補足が出て読まれなくなる）。

| 対象 | ID | 理由 |
|---|---|---|
| 方式 ZONE・MAN（既存） | SIM-07 | ゾーンとマンツーマンを二択にしている |
| 方式 POSSESSION | SIM-02 | 保持型は大外の前進だけで表し、ハーフスペースへの移動を扱わない |
| 方式ルール S01・S03・S05・S06（保持型が関わる） | SIM-02 | 同上 |
| 陣形ルール R07（ライン間で受ける）・R12（背後のスペース） | SIM-01 | ライン全体の押し上げ・ライン間の距離の調整を扱わない |
| 陣形ルール R02・R13（サイドの1対1） | SIM-03 | 個の能力を扱わない |
| 陣形ルール R14（中央3枚で挟み込む） | SIM-08 | 1ターンに寄せるのは1人 |

COUNTER・代わりの文・ほかのルールには付けない。

## 2. NotesView

```gdscript
func show_notes(notes: Array[MatchupNote], simplifications: Array[SimplificationDef] = []) -> void
func in_real_texts() -> Array[String]   # 出している「実戦では」（確認用）
```

- 項目の本文のすぐ下に、その項目の `simplification_ids` の順で「実戦では: {in_real}」を `CautionLabel` で出す
- 欄の中で一度出した ID は、後の項目では出さない
- カタログに無い ID は出さない（読み込み時の検査で弾かれるので、通常は起きない）
- 接頭辞は `SimplificationList.IN_REAL_PREFIX`（S-10・S-08 と同じ「実戦では: 」）を使う
- `texts()` は今までどおり本文（「・」付き）と案内文だけを返す

## 3. 画面

S-02（`_refresh_notes`）・S-04（噛み合わせ・選んだ方式）・S-05（`_redraw_matchup`）の `show_notes` に `App.library.simplifications()` を渡す。

## 4. テスト（最小限）
- `notes_view_test`: 「実戦では」が項目の下に出る・同じ ID は1回だけ・ID の無い項目には出ない・カタログに無い ID は出ない（1テストにまとめる）
- `match_setup_screen_test`: 保持型を選ぶと SIM-02 の「実戦では」が出る（つなぎ込み）
- ID の存在の検査は既存の読み込みのテストで足りる（`simplification_ids` の未知の ID は誤り）
