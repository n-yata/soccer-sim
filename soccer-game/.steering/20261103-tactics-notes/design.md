# 設計

正本（component-design.md §2.7・§3.4、data-definition.md §3.1〜§3.3、各画面の詳細設計）に沿って作る。
正本から変える点・決めていなかった点を「決めたこと」に書く。

## 構成

| 層 | 追加・変更 |
|---|---|
| 静的データ | `styles.json`・`matchup_rules.json` を新しく作る。`formations.json` に `strengths`・`weaknesses`・`principle_ids` を足す |
| ドメイン | `StyleDef`・`MatchupRuleDef`・`MatchupNote`、`commentary/FormationTags`・`commentary/CommentaryGenerator`。`ContentCatalog` に方式・ルール・代わりの文を足す |
| データ | `CommentaryContentReader`（`styles.json`・`matchup_rules.json` の形と範囲）。`ContentRepository` が読み、陣形の強み・弱み・原則 ID も確かめる |
| アプリケーション | `LibraryService` に `matchup_counts`・`formation_notes`・`style_notes`・`defense_style_notes`・`attack_style_notes` |
| UI | `NotesView`（共通）、`MiniPitch.show_matchup`（優劣記号）、S-02・S-04・S-05 |

## 決めたこと

### 静的データ

- **陣形のルールの移植**: 移植元の `matchupRules.ts` の配列の順を保ち、4陣形どうしの16通りのどこかで当たるルール18件
  （R08・R09・R01・R03・R05・R02・R12・R18・R13・R15・R20・R06・R04・R14・R36・R07・R10・R16）だけを移す。
  当たらないルール（5バック・中盤ダイヤ・アンカー1枚が要るもの、同じテーマの先のルールに必ず吸収される R11）は移さない
- **文は1つ**: 移植元は1つのルールに2つの言い回しを持ち、ハッシュで選んでいた（左右で同じ文が並ばないため）。
  data-definition.md の `text` は1つなので、移植元の1つ目の言い回しを使う。同じ文が左右に並ぶのは同じ陣形どうしだけで、
  そのときは相手側を出さない（下の `formation_notes`）
- **代わりの文**: 16通りのうち 4-4-2 どうしだけ、どちらにもルールが当たらない。移植元は能力値（stats）から代わりの文を作ったが、
  本プロダクトは能力値を持たない。`matchup_rules.json` に `fallback`（`text`・`principle_ids`）を1件持ち、当たるルールが
  0件の側に出す。閾値で辻褄を合わせない（アルゴリズム9）
- **陣形の単独の解説**: FR-17 の「特徴・得意な攻め方・弱点」を満たすため、`formations.json` に `strengths`・`weaknesses`
  （1〜300文字）・`principle_ids`（1件以上）を足す。特徴は既存の `description`。4陣形の固定文で、組み合わせごとの手書きではない
- **方式のルール**: 守備方式 × 相手の攻撃方式（4件）と、攻撃方式 × 相手の守備方式（4件）の8件。各方式の組み合わせで2件ずつ出る。
  テーマはルールごとに別にする（間引きで落ちないため）
- **文の視点**: ルールの文は、解説を見る側から書き、相手チームは必ず「相手」と書く。「こちら」は使わない（下の言い換えのため）
- **単純化 ID**: 方式の固定文にだけ付ける（ゾーン・マンツーマンに SIM-07）。表示は FR-23 の作業。陣形のルールは空にしておく

### ドメイン（アルゴリズム9）

- `FormationTags.derive(formation)`: 移植元の `deriveTags` のうち、4陣形に関係するタグ（3バック・4バック・1〜3トップ・
  ウイング有・ウイングバック有・守備的MF2枚・攻撃的MF3枚・中盤3枚・中盤フラット4枚・中盤実質5枚）。しきい値は移植元の値。
  `FormationTags.of(formation)` が `extra_tags` を足す（重複は除く。導出の順を先に）
- `FormationTags.KNOWN`: 導出するタグと `extra_tags` に書けるタグ（ライン間が空く）。静的データの検証で使う
- `CommentaryGenerator.formation_matchup(viewer, opponent, catalog)`: `FORMATION` ルールを配列の順に見て、
  viewer のタグが `viewer_tags` をすべて、opponent のタグが `opponent_tags` をすべて持つものを、同じテーマは先の1件だけ。
  0件なら `catalog.matchup_fallback`
- `CommentaryGenerator.style_matchup(viewer, opponent, catalog)`: viewer の守備方式 × opponent の攻撃方式、viewer の攻撃方式 ×
  opponent の守備方式の順に、`STYLE` ルールのうち条件が一致するもの（同じテーマは1件）
- `formation_profile`・`style_profile`: 「特徴: 」「強み: 」「弱み: 」を頭に付けた3件（方式は守備・攻撃の順に6件）
- `MatchupNote` に `label`（見出し）を足す。ドメインは空のまま返し、見出しは `LibraryService` が付ける

### LibraryService

- `matchup_counts(user, opponent)`: キー → `[利用者, 相手]`。相手の基本配置は相手の視点なので `PitchArea.mirrored()` で利用者の視点へ
- `formation_notes(viewer, "")`: 単独の解説。見出し「陣形 4-4-2」
- `formation_notes(viewer, opponent)`: 見出し「こちらの狙いどころ」に viewer 側、「相手の狙いどころ」に opponent 側
  （`formation_matchup(opponent, viewer)`）。相手側の文は「相手」を「こちら」に言い換える（相手から見た「相手」は利用者）。
  同じ陣形どうしは両側が同じになるので、相手側を出さない
- `style_notes(viewer, null)`: `defense_style_notes` ＋ `attack_style_notes`。`style_notes(viewer, opponent)`: 見出し「方式の噛み合わせ」
- `defense_style_notes(style)`・`attack_style_notes(style)`: 見出し「守備方式 ゾーン」など

### UI

- `NotesView`（`ui/common/notes_view.gd`。`VBoxContainer` のスクリプトだけの部品）: `show_notes(notes)` は、続く同じ見出しを
  1つにまとめ、見出し（`SectionTitleLabel`）と本文（`・` を頭に、折り返し）を並べる。`show_message(text)` は案内文1行。
  詳細設計の `show_notes(notes, simplifications)` の単純化の引数は、「実戦では」を出す FR-23 の作業で足す
- `MiniPitch.show_matchup(user_counts, opponent_counts)`: 2チームの人数に優劣記号（`▲` 利用者が多い・`＝` 同数・`▼` 少ない）を
  続けて出す。両方 0 のマスは空。記号で示し、色は使わない（NFR-20）
- S-02: `NotesLabel` を `NotesView` に置き換える（`NotesScroll` の中）。「解説は準備中」の定数と分岐を消す
- S-04: 本体に「直前の噛み合わせ」の見出し・`MatchupNotes`・`PickedNotes`。`StylePicker.changed` で `PickedNotes` を作り直す
- S-05: 本体に見出し・`MatchupPitch`（1マス 76×40）・`MatchupNotes`。基本設計（screen-design.md S-05「その下に解説」）に合わせ、
  ミニピッチの下に解説を置く（詳細設計の横並び `MatchupRow` は、本体の幅 約 730px では解説の幅が 330px ほどに詰まるため）。
  陣形のカード・方式を変えたら描き直す
- `JudgeReasonFormatter` の「解説（アルゴリズム9）の作業で言い回しを差し替える」という注記を直す（判定理由はアルゴリズム9の範囲外）

## テスト

- `tests/domain/commentary/formation_tags_test.gd`: 4陣形のタグの表（移植元の導出結果と同じ）、`extra_tags` のマージ
- `tests/domain/commentary/commentary_generator_test.gd`: 小さなカタログで、タグの条件・同一テーマの間引き・代わりの文・
  方式のルール・単独の解説の並び
- `tests/content/commentary_content_test.gd`: 本物のデータで、16通りの両側に1件以上、4-4-2 どうしは代わりの文、
  方式の16通りで2件ずつ、ルールの文に「こちら」が無い（言い換えの前提。R16 のように「相手」を含まない文もある）、
  移植したルールの ID の並び
- `tests/data/commentary_content_reader_test.gd`・`content_repository_test.gd`: 形・範囲・原則 ID・単純化 ID・タグの誤り
- `tests/application/library_service_test.gd`: `matchup_counts` の鏡像、見出し、相手側の言い換え、同じ陣形で相手側を出さない
- UI: `mini_pitch_test`（記号）、`match_setup_screen_test`（解説の並び）、`match_screens_test`（S-04・S-05）
