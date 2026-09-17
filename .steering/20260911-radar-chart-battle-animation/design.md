# 設計書

## アーキテクチャ概要

既存のロジック（`getMatchup`のA/B反転、選手配置計算 `buildTeamItems`）には一切手を入れず、
以下2点を追加する。

1. データ層: `Formation`型に静的スコア`stats`を追加し、`RadarChart.vue`で可視化する
2. 表現層: `MatchupPitchDiagram.vue`/`ComparisonPage.vue`にCSSアニメーションのみで
   対戦演出を追加する（Vue `<Transition>`は使わない。理由は下記「テスト戦略」参照）

```
src/
  types/formation.ts         ← RadarAxisId / FormationStats 型追加、Formationにstats追加
  data/
    radarAxes.ts              ← 新規。軸メタデータ（id/label/説明・表示順）
    formations.ts             ← 4フォーメーション分のstats値を追加
  components/
    RadarChart.vue             ← 新規。自前SVGレーダーチャート
    MatchupPitchDiagram.vue    ← チーム別<g>グルーピング + スライドインCSS
  pages/
    ComparisonPage.vue         ← RadarChart組み込み + 判定ポップイン + VSバッジ
```

## コンポーネント設計

### 1. `src/types/formation.ts`（型追加）

```ts
export type RadarAxisId = "attack" | "defense" | "balance" | "spaceControl" | "pressIntensity";
export type FormationStats = Record<RadarAxisId, number>; // 各軸0-100

export interface Formation {
  // 既存フィールド（id, name, description, positions）に加え
  stats: FormationStats;
}
```

**実装の要点**:
- `stats`は必須フィールドにする。新規フォーメーション追加時に値未設定を型エラーで検出でき、
  NFR-03「データファイルへの追加のみで拡張可能」と整合する
- `Matchup`型は変更しない（`Formation`はA/B概念を持たない中立データなので、
  `getMatchup`のA/B入れ替えロジックと干渉しない）

### 2. `src/data/radarAxes.ts`（新規）

軸のid・表示ラベル・簡潔な説明・表示順を持つ配列（`PositionType`のような区分値の扱いに準ずる）。
`RadarChart.vue`はこの配列をそのままpropsで受け取る。

```ts
export interface RadarAxisMeta {
  id: RadarAxisId;
  label: string;
  description: string;
}

export const radarAxes: readonly RadarAxisMeta[] = [
  { id: "attack", label: "攻撃力", description: "..." },
  { id: "defense", label: "守備力", description: "..." },
  { id: "balance", label: "バランス", description: "..." },
  { id: "spaceControl", label: "スペース支配力", description: "..." },
  { id: "pressIntensity", label: "プレッシング強度", description: "..." },
];
```

### 3. `src/data/formations.ts`（stats値追加）

各フォーメーションの`positions`（x/y座標・人数構成）から機械的に算出したベースラインを
人手で微調整し、調整根拠をコメントで残す（`advantagesForA/B`と同じ「理論に基づき作成し
開発者がレビューする」運用）。

算出ルールの目安（`formations.ts`にコメントとして明記）:
- `attack`: FW人数、攻撃的MFの比率、選手の平均y座標（高いほど前掛かり）
- `defense`: DF人数、最終ラインの低さ（平均y）、守備的MFの有無
- `balance`: DF/MF/FW人数配分の均等さ（偏りが少ないほど高い）
- `spaceControl`: 選手のx座標の広がり（幅）、サイド（x<25またはx>75）の選手数
- `pressIntensity`: FW平均yとDF平均yの差の小ささ（コンパクトなほど高い）、MF人数

### 4. `src/components/RadarChart.vue`（新規）

**責務**: 軸メタデータと系列データ（フォーメーションA/Bのstats）を受け取り、
自前SVGでレーダーチャートを描画する。

```
props:
  axes: RadarAxisMeta[]
  maxValue: number  // 通常100
  series: { label: string; colorVar: string; values: FormationStats }[]  // 最大2件
```

**実装の要点**:
- ライブラリは追加しない。`MatchupPitchDiagram.vue`と同じ自前SVG実装（三角関数で
  極座標→直交座標変換）。理由: 依存が`vue`/`vue-router`のみという現状の技術選定思想に合わせる
- 中心から各軸方向に伸びる軸線＋ラベル（`360/axes.length`度間隔）、目盛りの同心多角形
  （装飾のみ）、各系列の`<polygon>`（fill-opacity 0.3程度）＋頂点`<circle>`
- 色は`series[].colorVar`として`--color-team-a`/`--color-team-b`を渡す（新規に色を決め打ちしない）

### 5. `src/pages/ComparisonPage.vue`（RadarChart組み込み + 演出追加）

**責務**: 既存のcomputed（formationA/B/matchup）を使い、レーダーチャートセクションと
対戦演出用要素（VSバッジ、判定ポップイン）を追加する。ロジック（computed本体）は無変更。

**実装の要点**:
- RadarChartは新セクションとして、既存の優位ポイント表示の**前**（ピッチ図の下）に追加し、
  既存要素は削除・変更しない
- `series`は`[{label: formationA.name, colorVar: "--color-team-a", values: formationA.stats}, ...]`
  の形でテンプレート側から組み立てる
- VSバッジは新規`<div class="comparison-page__vs-badge">`。`<button>`にしない、
  戻るボタンより後（DOM順序で後）に配置し、既存テストの`wrapper.find("button")`
  インデックス依存を壊さない
- `.comparison-page__verdict`に`animation-delay`付きのポップインkeyframesを追加
  （スライドインの所要時間より後に発火するよう`animation-delay`を設定）

### 6. `src/components/MatchupPitchDiagram.vue`（チームグルーピング + スライドインCSS）

**責務**: 既存の`items`（A→B結合の単一配列）はそのままcomputedとして維持しつつ、
テンプレート側でチーム別の2つの`<g>`にグルーピングする。

**実装の要点**:
- `items.filter(i => i.team === "A")`/`"B"`の2つのcomputed、またはテンプレート内で
  `v-for`を2回に分けて団体ごとに`<g>`でラップする
- DOM順序・`circle.blue`/`circle.red`のクラス名は変えないこと（既存テストの
  `findGkCircle`等がDOM順序に依存しているため、グルーピング後も並び順が変わらないことを
  実装後に必ず確認する）
- `.matchup-pitch__team--a`に左からのスライドインkeyframes、`--b`に右からのスライドイン
  keyframesを付与

## アニメーション実装方針

**Vue `<Transition>`は使わず、CSS `@keyframes`のみを使う。**

理由:
- `ComparisonPage.vue`の`formationA`/`formationB`/`matchup`は全て同期`computed`
  （`route.params`由来）であり、マウント時点で既に表示条件（`v-if`）が真になっている。
  `<Transition>`は要素の出現/消失をフックする仕組みで、初回マウント時に発火させるには
  `appear`propが必要な上、テスト環境（`@vue/test-utils`）でのトランジションクラスの
  タイミング挙動はVueのバージョン依存で不安定になりやすい
- CSS `@keyframes`を要素に直接適用する方式なら、DOM構造・テキスト内容・要素の存在有無は
  一切変えず、見た目のスタイル（transform/opacity）だけが変化する。jsdomはCSSアニメーションを
  実行しないため、`wrapper.text()`や`wrapper.find()`を使う既存の同期アサーションに
  影響ゼロで安全
- `prefers-reduced-motion: reduce`時は、両コンポーネントの`<style scoped>`に
  `@media (prefers-reduced-motion: reduce) { ... { animation: none !important; } }`
  を追加する。CSSのみで完結し、JS側の`window.matchMedia`監視は不要

## テスト戦略

### ユニットテスト
- `formations.test.ts`: 全フォーメーションのstatsが0-100範囲内であること、
  statsベクトルが互いに完全一致しないこと（`matchups.test.ts`の「全走査で不変条件を
  検証する」パターンを踏襲）
- `RadarChart.test.ts`: 既知の軸数・スコアに対する`<polygon>`の頂点数、`<text>`ラベル数、
  既知角度でのcx/cy近似値を検証
- `MatchupPitchDiagram.test.ts`: 既存アサーションを維持しつつ、チームグループ`<g>`の
  存在検証を追加
- `ComparisonPage.test.ts`: RadarChartへのprops連携（formationA/Bのstatsが正しく渡ること）
  を追加。既存アサーションは維持

### 手動確認
- `npm run dev` + Chrome自動操作で比較画面を開き、演出とレーダーチャートの重ね描画を
  目視確認する
- `prefers-reduced-motion`をシミュレートしてアニメーションが無効化されることを確認する

## 依存ライブラリ

追加なし。

## 実装の順序

1. ドキュメント更新（要件定義・機能概要のMVP昇格・データモデル追記）
2. 型追加（`types/formation.ts`）→ `radarAxes.ts` → `formations.ts`のstats値 → テスト
3. `RadarChart.vue`単体実装 + テスト
4. `ComparisonPage.vue`へのレーダーチャート組み込み + テスト
5. 対戦演出（チームグルーピング・スライドインCSS・VSバッジ・判定ポップイン・
   `prefers-reduced-motion`対応）
6. 基本設計ドキュメント（screen-design.md/component-design.md/wireframes.drawio）の最終同期
7. `npm run test`/`lint`/`typecheck`/`build`確認、ブラウザ目視確認
8. コミット前レビュー → 振り返り

## セキュリティ考慮事項

なし（静的データ・CSS/SVG装飾の追加のみ、ユーザー入力を扱わない）。

## パフォーマンス考慮事項

なし（SVG描画要素・CSSアニメーションの追加のみで、計算量・I/Oへの影響は軽微）。

## 将来の拡張性

軸メタデータを`radarAxes.ts`に分離したことで、将来軸を追加・変更する場合もこのファイルの
変更のみで完結する。`RadarChart.vue`は軸数に依存しない汎用実装にする。
