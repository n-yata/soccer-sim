# 設計書

## アーキテクチャ概要

既存のUI層/データ層の2層構成に、`src/composables/` をロジック層として新設する。
データ層（`data/formations.ts` 等）は無変更。ロジック層は `Formation.stats` と
`Matchup.overallEdge` / `Matchup.id` のみを入力とし、純粋関数として実装する。

```
UIレイヤー
  pages/ComparisonPage.vue ─┬─ (props) → components/MatchSimulationPanel.vue（表示専用）
                            │
ロジック層（新設）           │
  composables/matchSimulation.ts ← simulateMatch(a, b, matchup)
                            │
データレイヤー               │
  data/formations.ts（stats参照のみ）
  data/matchups.ts（overallEdge/id参照のみ）
```

依存方向: `pages/` → `composables/` → `types/`（`data/`は`pages/`が別途importしてFormation/Matchupの実体を渡す。`composables/`自体は`data/`の関数を呼ばず、型と渡された値だけを使う）。

## コンポーネント設計

### 1. `composables/matchSimulation.ts`（新規・純粋関数のコア）

**責務**:
- シード付きPRNGの生成（`mulberry32`をFNV-1aハッシュした`matchup.id`でシード）
- 90分・1分刻みのポゼッション判定→チャンス判定→枠内判定→ゴール判定
- 集計結果（`MatchSimulationResult`）の組み立て

**実装の要点**:
- `matchup.id`は`getMatchup`がA/B入れ替え時にも正準の値（配列格納順）をそのまま返す
  （`types/formation.ts`の`Matchup.id`不変条件）ため、シードの基準として使う。
  「組み合わせ」は呼び出し順に依存しない不変条件（FR-14の受け入れ条件。`getMatchup`/
  `buildPairKey`が組み合わせを順序非依存に扱う既存設計と揃える）であるため、
  `simulateMatch`は内部で`matchup.id`が示す正準順（`${正準A}_vs_${正準B}`の前半をAとする）
  へ揃えてから計算し、呼び出し時のa/bが正準順と逆であれば結果を鏡写しにして返す
  （`runCanonicalSimulation` + `mirrorResult`）。これにより、A/Bを入れ替えて呼んでも
  同じ90分間の試合の鏡写しになり、勝敗が呼び出し順で変わることがない
  （review-implementationの検証で、この対称性を取らないと入れ替えボタン（FR-09）を
  押しただけで勝者が反転する実害があると指摘され、実装を修正した経緯がある）
- `Math.random`は一切使用しない。テストでも本番と同じ`simulateMatch`をそのまま呼べる
  （`quiz.ts`のようなShuffle注入は不要。乱数源が`matchup.id`から決定的に求まるため）
- 全ての確率計算は`clamp(min, max)`で境界を持たせ、0または1に張り付かないようにする
  （常にゴールが入る/常に無得点、を防ぐ）

**確率モデル（3段階: ポゼッション→チャンス→枠内→ゴール）**:

```ts
// ポゼッション判定の重み。spaceControlとpressIntensityが高いほどボールを握りやすく、
// balanceが高いほど安定して保持できるとみなす（3項の合計が重みになる。各stat 0-100）
const POSSESSION_WEIGHT = { spaceControl: 0.4, pressIntensity: 0.35, balance: 0.25 };
// overallEdgeがついている側に加える基礎重み。stats由来の重みが概ね30-100のスケールに
// 収まるため、明確だが逆転しうる差として15を採用（EDGE_THRESHOLDの2点差ルールとは独立）
const EDGE_POSSESSION_BONUS = 15;

// 1分あたりチャンス発生の基礎確率。ポゼッション45分（五分五分想定）・diff=0で
// 約10本のチャンス（=シュート数）になり、attack-defense差の反映後は概ね6-18本に収まる
const BASE_CHANCE_PROBABILITY = 0.22;
const CHANCE_ATTACK_FACTOR = 0.003; // (attack - 相手defense) [-100,100] を確率へ反映
const CHANCE_PROBABILITY_RANGE = { min: 0.08, max: 0.4 };

const BASE_ON_TARGET_PROBABILITY = 0.45;
const ON_TARGET_ATTACK_FACTOR = 0.002;
const ON_TARGET_PROBABILITY_RANGE = { min: 0.25, max: 0.75 };

const BASE_GOAL_PROBABILITY = 0.3;
const GOAL_ATTACK_FACTOR = 0.003;
const GOAL_PROBABILITY_RANGE = { min: 0.1, max: 0.6 };
```

**分単位ループ（擬似コード）**:
```
for minute in 1..=90:
  possessor = choosePossessor(a, b, overallEdge, rng())  // "A" | "B"
  chanceProb = clamp(BASE_CHANCE + (possessor.attack - opponent.defense) * FACTOR, range)
  if rng() < chanceProb:
    shots[possessor]++
    onTargetProb = clamp(...)
    if rng() < onTargetProb:
      shotsOnTarget[possessor]++
      goalProb = clamp(...)
      if rng() < goalProb:
        score[possessor]++
        timeline.push({ minute, team: possessor, kind: "goal", text: ... })
      else:
        timeline.push({ minute, team: possessor, kind: "shot", text: ... })  // 枠内・セーブ
    else:
      timeline.push({ minute, team: possessor, kind: "chance", text: ... })  // 枠外
  possessionMinutes[possessor]++
```

乱数消費は1分あたり最大4回（possessor, chance, onTarget, goal）。`rng()`は呼び出すたびに
mulberry32の内部状態を進める1つのジェネレータをクロージャで共有する。

**集計**:
- `possession = { a: round(possessionMinutes.A / 90 * 100), b: 100 - a }`
  （bをaの補数にすることで丸め誤差があっても合計100を保証する）
- `shots` / `shotsOnTarget` / `score` はそのまま件数
- `timeline` は生成順（分昇順は自明。同一分に複数イベントは発生しない設計のため同順位の
  tie-break不要）
- `summary` はスコア差・ポゼッション差から自然文を組み立てる（下記「データフロー」参照）

### 2. `components/MatchSimulationPanel.vue`（新規・表示専用）

**責務**:
- `MatchSimulationResult`をpropsで受け取り、スコアボード・ポゼッションバー・
  シュート/枠内シュートの対比・タイムラインを表示する
- `summary`文中の用語（下記グロッサリー追加分）を`TermAnnotatedText`でインライン表示する
  （FR-11の既存パターンを踏襲。`components/`は`data/termAnnotation.ts`のみ例外的に
  依存可能というルールに従う）

**実装の要点**:
- タイムラインは分昇順のリスト表示。件数は試合により変動する（概ね15〜35件）ため
  スクロール可能なコンテナに入れる
- ゴールイベントは視覚的に強調する（背景色・アイコン）
- `prefers-reduced-motion`時は既存の対戦演出（FR-06）同様、展開アニメーションを
  即時表示に切り替える

### 3. `pages/ComparisonPage.vue`（既存・変更）

**責務**:
- 「試合をシミュレートする」ボタンを追加し、押下時に`simulateMatch`を呼び出して結果を
  `ref`に保持、`MatchSimulationPanel`へpropsで渡す
- フォーメーション・組み合わせの切替（FR-09）時は表示中のシミュレーション結果をリセットする
  （切替後に古い試合結果が残ると、表示中のフォーメームと結果が食い違うため）

## データフロー

### シミュレーション実行〜表示

```
1. 利用者が比較画面で「試合をシミュレートする」ボタンを押す
2. ComparisonPage が simulateMatch(formationA.value, formationB.value, matchup.value) を呼ぶ
3. matchSimulation.ts が matchup.id からシードを導出し、90分のイベント駆動シミュレーションを実行
4. MatchSimulationResult（possession/shots/shotsOnTarget/score/timeline/summary）を返す
5. ComparisonPage が結果を ref に保持し、MatchSimulationPanel に props で渡す
6. MatchSimulationPanel がスコアボード・ポゼッションバー・シュート対比・タイムラインを描画する
```

### サマリー文の組み立て

```
1. score.a と score.b を比較し、勝敗（またはeven）を決める
2. 勝者側の possession/shots の優位性のうち、最も差が大きい指標を1つ選ぶ
   （例: ポゼッション差が最大なら「ポゼッションで上回り」、シュート数差が最大なら
   「シュート数で圧倒し」）
3. テンプレートに当てはめて自然文を生成する
   例:「{winner.name}が{scoreWinner}-{scoreLoser}で{loser.name}を下した。
       {differentiator}きった試合だった。」
   引き分け例:「{a.name}と{b.name}は{scoreA}-{scoreA}の互角の展開で決着がつかなかった。」
```

## エラーハンドリング戦略

本機能は例外を発生させる外部入出力（ネットワーク・ストレージ）を持たない。
唯一の防御的処理は確率の`clamp`（0/1への張り付き防止）であり、専用のエラークラスは設けない。
`Formation.stats`は型で0-100の数値が保証されている前提のため、入力バリデーションは行わない
（`data/`層が静的データであり不正値が入り得ないため。既存の`quiz.ts`等と同じ方針）。

## テスト戦略

### ユニットテスト（`composables/matchSimulation.test.ts`）

- 固定フォーメーションペア（例: 4-2-3-1 vs 4-4-2）で`simulateMatch`を実行し、
  スコア・ポゼッション・シュート数・タイムライン件数が期待値と一致することを検証
  （初回実行時に実際の出力を確認し、以降は回帰検知のための固定値として記述する）
- 決定性: 同一引数で3回呼び出し、3回とも完全に同じ結果（オブジェクトの深い等価性）になること
- 不変条件（全フォーメーションの全組み合わせに対してテーブル駆動で検証）:
  - `possession.a + possession.b === 100`
  - `shots.a >= score.a` かつ `shots.b >= score.b`
  - `shotsOnTarget.a <= shots.a` かつ `shotsOnTarget.b <= shots.b`
  - `score.a <= shotsOnTarget.a` かつ `score.b <= shotsOnTarget.b`
  - `timeline`の`minute`が1以上90以下、かつ非減少順に並んでいること
- 極端ケース: 全stats軸が同一の2つの仮想フォーメーション（テスト内でモック生成）でも
  例外を投げず、有効な結果を返すこと
- `Math.random`を使用していないことの検証（同一シードで異なるインスタンスの
  `simulateMatch`を呼んでも結果が一致することで間接的に保証される）

### コンポーネントテスト（`components/MatchSimulationPanel.test.ts`）

- 固定の`MatchSimulationResult`をpropsで渡し、スコア・ポゼッション・タイムラインの
  各要素が期待通り描画されることを検証（`@vue/test-utils`、既存コンポーネントテストと同様）

## 依存ライブラリ

追加なし。PRNG（mulberry32）とハッシュ（FNV-1a）は`matchupGenerator.ts`の`hash()`と
同方式で自前実装する（外部ライブラリへの依存を増やさない）。

## ディレクトリ構造

```
src/
├── composables/                       # 新設
│   ├── matchSimulation.ts
│   └── matchSimulation.test.ts
├── components/
│   ├── MatchSimulationPanel.vue       # 新規
│   └── MatchSimulationPanel.test.ts   # 新規
├── pages/
│   └── ComparisonPage.vue             # 変更（ボタン追加・パネル組み込み）
└── types/
    └── formation.ts                   # 変更（MatchEvent, MatchSimulationResult追加）
```

> **`data/soccerTerms.ts`は変更しない**（当初計画から変更。下記「NFR-02対応の設計判断」参照）。

## 実装の順序

1. `types/formation.ts` に `MatchEvent` / `MatchSimulationResult` を追加
2. `composables/matchSimulation.ts`（PRNG・確率モデル・ループ・集計）をテストと並行して実装（TDD）
3. `components/MatchSimulationPanel.vue` を実装
5. `pages/ComparisonPage.vue` にボタン・組み込みを追加
6. ドキュメント更新（requirements-definition.md / architecture-overview.md / repository-structure.md）
7. 品質チェック（lint/typecheck/test/build）→ コミット前レビュー

## セキュリティ考慮事項

該当なし（外部入力・認証・シークレットを扱わない。既存プロダクトの前提と同じ）。

## パフォーマンス考慮事項

1回のシミュレーションは90回のループ・最大360回の乱数生成のみで、体感的なコストはない。
メモ化やWeb Worker化は不要（既存のNFR: 性能目標は対象外）。

## NFR-02対応の設計判断（当初計画からの変更）

当初計画では「ポゼッション」「枠内シュート」を`data/soccerTerms.ts`へ用語として追加する
予定だったが、実装時に`matchupRules.test.ts`の不変条件（用語集の全用語がルール表
`matchupRules.ts`の文言に実際に登場すること）と衝突することが判明した。
`soccerTerms.ts`はmatchupRules起点のコンテンツパイプライン専用の用語集として設計されており、
FR-14のような別系統の文言の用語追加先としては想定されていなかった。

対応として、用語集への追加はやめ、NFR-02の「用語集 **または** 文中で説明を添える」の
後者を取る方針に変更した。「ポゼッション」は言い換えて「ボール保持率」という平易な
日本語に統一し、ジャーゴンそのものを持ち込まないようにした。「枠内シュート」は
「枠」「内」「シュート」いずれも既存UI（ミニピッチ図のGK/DF/MF/FWラベル等）と同様に
自明な語の組み合わせと判断し、glossary化せずそのまま使用する。

## 将来の拡張性

- タイムラインの生成ロジックはUIから独立しているため、将来「ハイライト動画風の再生」
  UIへ差し替える場合も`composables/matchSimulation.ts`は無変更で流用できる
- 分単位の粒度をイベント単位（可変長）に変える拡張も、`MatchEvent`の`minute`が
  単調非減少である不変条件を保てば可能
