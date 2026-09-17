# タスクリスト

## 🚨 タスク完全完了の原則

**このファイルの全タスクが完了するまで作業を継続すること**

### 必須ルール
- **全てのタスクを`[x]`にすること**
- 「時間の都合により別タスクとして実施予定」は禁止
- 「実装が複雑すぎるため後回し」は禁止
- 未完了タスク（`[ ]`）を残したまま作業を終了しない

### タスクスキップが許可される唯一のケース
以下の技術的理由に該当する場合のみスキップ可能:
- 実装方針の変更により、機能自体が不要になった
- アーキテクチャ変更により、別の実装方法に置き換わった
- 依存関係の変更により、タスクが実行不可能になった

スキップ時は必ず理由を明記:
```markdown
- [x] ~~タスク名~~（実装方針変更により不要: 具体的な技術的理由）
```

---

## 🚨 この作業の絶対条件

以下を破ったら設計が崩れたサイン。**回避策で取り繕わず、一度立ち止まること。**

1. **`.vue` ファイルを1つも変更しない**
2. **既存テストを1行も変更しない**
   （`matchups.test.ts` / `soccerTerms.test.ts` / `quiz.test.ts` / 各ページのテスト）
3. **`matchups` / `getMatchup()` の公開APIを変えない**
4. **本番コードにテスト用の分岐を入れない**（`if (testMode)` の類は禁止）

---

## フェーズ1: タグ導出の実装

- [x] `src/types/formation.ts` に `extraTags?: readonly FormationTag[]` を追加
  - [x] `FormationTag` は `formationTags.ts` から import する（型の定義場所は導出ロジック側）
  - [x] 既存の型定義・コメントを壊さない
- [x] `src/data/formationTags.ts` を新規作成
  - [x] `FormationTag` 型を定義（design.md の導出表の13種）
  - [x] `deriveTags(formation)` を実装（`positions` のみを参照。`stats` は見ない）
  - [x] `getTags(formation)` を実装（`deriveTags` + `extraTags` をマージ、重複除去）
  - [x] `ライン間が空く` は `deriveTags` から**出さない**（`extraTags` 専用）
  - [x] 各導出条件の根拠をコメントで残す（特に `ウイングバック有` の `y<=50` の理由）
- [x] `src/data/formationTags.test.ts` を新規作成
  - [x] 現行4種すべてについて design.md の導出表どおりのタグになる（全走査）
  - [x] 境界値: 4-4-2 のサイドMF（`x=15, y=55`）が `ウイングバック有` に含まれない
  - [x] `extraTags` が導出結果にマージされる
  - [x] `ライン間が空く` が `deriveTags` の結果に現れない
- [x] `src/data/formations.ts` の 4-4-2 に `extraTags: ["ライン間が空く"]` を付与
  - [x] `positions` と `stats` は**変更しない**

## フェーズ2: ルール表の実装

- [x] `src/data/matchupRules.ts` を新規作成
  - [x] `MatchupRule` インターフェースを定義（design.md のとおり）
  - [x] **必須ルール R01〜R07 を文言ごと実装**（9つの孤立用語を回収する）
  - [x] 追加ルール R08〜R17 を実装（校正アンカーの再現に必要）
  - [x] 各ルールに複数の言い回し（`advantages`）を持たせる
  - [x] 文言は用語集の語彙で書く。新しい専門用語を持ち込まない（NFR-02）
  - [x] 文中で「Aの」「Bの」を使わない。相手は「相手の〜」と書く
- [x] `src/data/matchupRules.test.ts` を新規作成
  - [x] **`advantages` 全文を連結したとき `soccerTerms` の18件すべてが出現する**
        （最大の関門。落ちたらルール文言を足す。用語を消して通すのは禁止）
  - [x] ルールIDが一意
  - [x] 全ルールの `advantages` が1件以上・空文字を含まない
  - [x] 同一ルールの `advantages` 内に重複文言がない

## フェーズ3: 生成ロジックの実装

- [x] `src/data/matchupGenerator.ts` を新規作成
  - [x] ルールの適用判定（`selfTags` / `opponentTags` をすべて満たすか）
  - [x] `advantages` の決定的な選択（`hash(pairId + ruleId) % length`。`Math.random` 禁止）
  - [x] `overallEdge` の算出（`diff >= 2` → `A` / `diff <= -2` → `B` / それ以外 → `even`）
  - [x] **`stats` を優劣算出に使わない**（フォールバック文の生成にのみ使う）
  - [x] `overallReason` の組み立て（フォーメーション名を明示。A/B相対表現を使わない）
  - [x] フォールバック（ルール未適用側に `stats` 由来の汎用文を返す。空配列にしない）
  - [x] `generateMatchup(a, b)` / `buildAllMatchups(formations)` を export
- [x] `src/data/matchupGenerator.test.ts` を新規作成
  - [x] 全組み合わせで `advantagesForA` / `advantagesForB` がそれぞれ1件以上
  - [x] **校正アンカー表6件のとおりに `overallEdge` が算出される**
  - [x] `overallReason` にA/B相対表現が含まれない
  - [x] 同じ入力で2回呼んだ結果が完全一致する（決定性）
  - [x] ルールが当たらないダミー `Formation` でフォールバック文が返る
- [x] **校正アンカーを合わせる**
  - [x] 6組すべてが design.md の表と一致することを確認
  - [x] 一致しない場合、**閾値ではなくルール表を補って**合わせる
        （閾値で辻褄を合わせると A-2 で破綻する）

## フェーズ4: 既存データの置換

- [x] `src/data/matchups.ts` を置換
  - [x] 手書きの `matchups` 配列を削除
  - [x] `export const matchups: Matchup[] = buildAllMatchups(formations);` に置き換え
  - [x] `getMatchup()` の実装は**変更しない**
  - [x] `getMatchup` の既存コメント（正準 id・入れ替え semantics）を維持する
- [x] **既存テストが無修正で通ることを確認**
  - [x] `npx vitest run src/data/matchups.test.ts`
  - [x] `npx vitest run src/data/soccerTerms.test.ts` ← 用語回収の最終確認
  - [x] `npx vitest run src/data/quiz.test.ts`
  - [x] `npx vitest run src/pages/` （各ページのテスト）
- [x] `.vue` ファイルに変更が入っていないことを `git status` で確認

## フェーズ5: 品質チェックと修正

- [x] すべてのテストが通ることを確認
  - [x] `npm test`
- [x] リントエラーがないことを確認
  - [x] `npm run lint`
- [x] 型エラーがないことを確認
  - [x] `npm run typecheck`
- [x] ビルドが成功することを確認
  - [x] `npm run build`
- [x] **テストが実際に実行されたことを確認**（実行件数・スキップ数を出力で確認する。
      「失敗0」だけを見て通ったと判断しない）

## フェーズ6: 生成結果の確認

- [x] 全6組の生成結果をテキストで書き出し、目視で読む
  - [x] 日本語として自然に読めるか
  - [x] 手書き時代と比べて明らかな品質退行がないか
  - [x] 同じ言い回しが全組で繰り返されて単調になっていないか
- [x] `docs/content-review-checklist.md` に沿って戦術的妥当性をセルフレビュー
- [x] 退行が見つかった場合はルール表の文言を改善する
      （上書き機構は作らない。ルール表で解決する）

## フェーズ7: ドキュメント更新

- [x] `docs/specs/1_requirements/functional-overview.md` のデータモデル／アルゴリズム設計に
      タグ導出とルール表の仕組みを反映（マッチアップが手書きデータから導出へ変わったため）
- [x] `docs/specs/3_detail-design/screen/screen-02-comparison.md` に
      優位ポイントの供給元の変更が影響しないか確認し、必要なら更新
- [x] 実装後の振り返りを記録（別ファイル `retrospective.md` に記録 → flow-steering モード3）

---

> **振り返りについて**: 実装後の振り返りはこのファイルではなく、同じディレクトリの
> `retrospective.md` に記録する。全タスクが `[x]` になり、かつコミット前レビューが
> 収束してから作成すること（レビュー結果欄が必須のため）。
