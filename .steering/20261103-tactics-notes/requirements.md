# 要求内容

## 概要

戦術の解説（FR-17。アルゴリズム9: 解説の導出）を作り、試合準備（S-02）・方式の選び直し（S-04）・ハーフタイム（S-05）の
解説欄を埋める。S-05 には前半の噛み合わせのミニピッチ（両チームの基本配置の人数と優劣記号。FR-16）も足す。

## 背景

- 2026-10-19 の試合画面の作業で「噛み合わせ・陣形・方式の解説」「アルゴリズム9」をスコープ外にし、そのまま拾う作業が
  立っていなかった。S-02 は選んでも「解説は準備中」と出るだけで、S-04・S-05 には解説欄が無い
- FR-17 は P0。リリース判定基準（要件定義書 §6.3）は P0 の受け入れ基準を満たすことを求める

## 実装対象の機能

### 1. 静的データ

- `styles.json`（4方式の特徴・強み・弱みの固定文と、根拠の原則・単純化。data-definition.md §3.2）
- `matchup_rules.json`（噛み合わせルール。data-definition.md §3.3）
  - `FORMATION`: フォーメーションラボ（`soccer-sim`）の `matchupRules.ts` から、4陣形のタグで成り立つルールだけを移植する
  - `STYLE`: 守備方式 × 相手の攻撃方式、攻撃方式 × 相手の守備方式のルールを新しく書く
- 陣形の単独の解説（特徴・得意な攻め方・弱点）。FR-17「提供するすべてのフォーメーションと方式について、特徴・得意な攻め方・
  弱点の解説がある」を満たすため、`formations.json` に強み・弱みの固定文を足す
- すべてのルール・固定文は戦術原則カタログの原則 ID に紐づける（§7 #14・NFR-17 ①）

### 2. 解説の導出（ドメイン。アルゴリズム9）

- 特徴タグの導出（移植元の `formationTags.ts` の `deriveTags`・`getTags`。4陣形に関係するタグだけ）
- 噛み合わせルールの適用（移植元の `matchupGenerator.ts` の `applicableRules`。同一テーマからは配列で先のもの1件だけ）
- 方式どうしのルールの適用、陣形・方式の単独の解説

### 3. 画面向けの参照（`LibraryService`）

- `matchup_counts`・`formation_notes`・`style_notes`・`defense_style_notes`・`attack_style_notes`（component-design.md §3.4）

### 4. 画面

- S-02: 解説欄に、選んだ項目（陣形・守備方式・攻撃方式）の単独の解説を出す（screen-02-match-setup.md）
- S-04: 「直前の噛み合わせ」（両者の方式の噛み合わせ）と、変えた方式の単独の解説（screen-04-style-change.md）
- S-05: 前半の噛み合わせのミニピッチ（`自分−相手` と優劣記号 `▲`・`＝`・`▼`）と、陣形・方式の噛み合わせの解説。
  選び直すと見出しが「後半の噛み合わせ（予測）」に変わり、描き直す（screen-05-halftime.md）
- 解説を出す共通部品 `NotesView`

## 受け入れ条件

- [ ] 4陣形・4方式のすべてに、特徴・強み・弱みの解説がある（FR-17）
- [ ] 陣形どうしの解説は、タグとルールから導出する（組み合わせごとに手書きしない）。4陣形どうしの16通りすべてで、
      どちらの側にも1件以上の解説が出る
- [ ] 同じ噛み合わせで、同一テーマのルールは1件しか出ない
- [ ] すべてのルール・固定文の原則 ID が `principles.json` にあり、単純化 ID が `simplifications.json` にある。
      誤りがあれば `ContentRepository.validation_errors()` が報告する（NFR-17）
- [ ] 4陣形の導出タグが移植元と同じ（4-4-2・4-3-3・4-2-3-1・3-5-2 のタグの表をテストで固定する）
- [ ] S-02: 何も選んでいなければ案内文、選んだ項目の解説だけを「陣形・守備方式・攻撃方式」の順に出す。「解説は準備中」は出ない
- [ ] S-04: 直前の方式の噛み合わせを出す。方式を変えたら、変えた項目の単独の解説を出し、元に戻したら隠す
- [ ] S-05: ミニピッチの人数が `matchup_counts` と一致し（相手は利用者の視点へ鏡像）、各マスに優劣記号が付く。
      陣形・方式を変えると見出しと解説とミニピッチが変わる
- [ ] 解説文は、ゲームの規則（アルゴリズム1・2・6）と矛盾しない（セルフレビューのチェック観点）
- [ ] `tools/run-tests.sh` がすべて通る

## スコープ外

- 「実戦では」の表示（FR-23。`MatchupNote.simplification_ids` は持たせるが、表示は次の作業）
- 判定理由（`JudgeReasonFormatter`）の言い回し。アルゴリズム9の正本は陣形・方式の解説だけを定めており、判定理由は含まない
  （ソースの「解説（アルゴリズム9）の作業で言い回しを差し替える」という注記を直す）
- 理解度チェック（S-09）のミニピッチの優劣記号
- BGM（FR-15）

## 参照ドキュメント

- `docs/specs/1_requirements/requirements-definition.md` - FR-16・FR-17
- `docs/specs/1_requirements/functional-overview.md` - アルゴリズム1・2・6・9、戦術原則カタログ、セルフレビューのチェック観点
- `docs/specs/2_basic-design/component-design.md` - §2.7 `CommentaryGenerator`、§3.4 `LibraryService`
- `docs/specs/2_basic-design/screen-design.md` - S-02・S-04・S-05
- `docs/specs/3_detail-design/data/data-definition.md` - §3.1〜§3.3
- `docs/specs/3_detail-design/screen/screen-02-match-setup.md`・`screen-04-style-change.md`・`screen-05-halftime.md`・`screen-common.md`
- 移植元: `../soccer-sim/src/data/formationTags.ts`・`matchupRules.ts`・`matchupGenerator.ts`
