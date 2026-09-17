# 設計書

## アーキテクチャ概要

既存の3層構成（`data/`＝静的データ・純粋導出ロジック、`pages/`＝画面、`components/`＝表示専用）を
そのまま踏襲する。自由配置モードは新規レイヤーを増設せず、以下の3点を追加する。

1. `src/data/radarScoreEstimator.ts`（新規） — タグ差分からスコアを概算する純粋関数
2. `src/components/FreeLayoutPitchDiagram.vue`（新規） — 実座標を線形マッピングして描画し、
   Aチームのみドラッグを受け付けるピッチ図
3. `ComparisonPage.vue`（変更） — トグル状態・一時的なAチーム配置(`Position[]`)を保持し、
   `MatchupPitchDiagram`（通常時）と`FreeLayoutPitchDiagram`（自由配置時）を出し分ける

```
ComparisonPage.vue
 ├─ isFreeLayoutMode: ref<boolean>
 ├─ freePositionsA: ref<Position[] | null>   … 自由配置モード中の一時状態（永続化しない）
 ├─ effectiveFormationA = computed: freePositionsAがあれば positions を差し替えたFormation
 ├─ effectiveMatchup = computed:
 │     freePositionsAが無ければ既存の getMatchup(id,id) をそのまま使う（現状維持）
 │     freePositionsAがあれば matchupGenerator.generateMatchup(effectiveFormationA, formationB) を都度呼ぶ
 ├─ effectiveStatsA = computed:
 │     freePositionsAが無ければ formationA.stats（現状維持）
 │     freePositionsAがあれば radarScoreEstimator.estimateStats(getTags(effectiveFormationA), formationA.stats)
 ├─ MatchupPitchDiagram（isFreeLayoutMode=false時。変更なし）
 └─ FreeLayoutPitchDiagram（isFreeLayoutMode=true時。新規）
      - props: formationA(=effectiveFormationA), formationB, draggableTeam="A"
      - emit: update-position (positionId, x, y)  ← ComparisonPageがfreePositionsAへ反映
```

## コンポーネント設計

### 1. `src/data/radarScoreEstimator.ts`（新規）

**責務**:
- `estimateStats(tags: FormationTag[], baseStats: FormationStats): FormationStats` を提供する純粋関数
- 元フォーメーションの静的な`stats`を基準に、現在のタグ構成との差分（元のタグ構成に無い/ある
  タグ）から5軸の増減を計算し、0-100にクランプして返す

**実装の要点**:
- `formationTags.ts`と同じ「positions/statsを直接見ない・タグだけを入力にする」設計を踏襲し、
  責務を分離する（`estimateStats`はタグ配列とbaseStatsのみを引数に取り、Formationを直接
  受け取らない）
- 呼び出し側（`ComparisonPage.vue`）が「元のタグ配列」と「現在のタグ配列」の両方を
  `getTags`で算出し、その差分（新たに立った/消えたタグ）だけを加減算対象にする。
  差分ベースにすることで、初回（配置未変更時）は必ず`baseStats`と完全一致することを保証する
  （二重計上防止・境界条件のテストが書きやすい）
- タグ→軸の加減算テーブルは、`matchupRules.ts`のようにモジュール内の定数テーブルとして持つ。
  例: `"3バック"`が立つと`defense -5 / attack +5`、`"5バック"`が立つと`defense +10 / attack -10`等
  （具体的な数値は実装時に開発者本人がレビューして決定する。未決事項）
- 複数タグが同一軸に影響する場合の二重計上防止として、**軸ごとに合計を出してから
  最後に一度だけ`Math.min(100, Math.max(0, base + delta))`でクランプする**
  （タグ単位でクランプすると、順序依存でおかしな挙動になるため）

### 2. `src/components/FreeLayoutPitchDiagram.vue`（新規）

**責務**:
- Aチーム（`formationA`）・Bチーム（`formationB`）を1つのSVGピッチ上に描画する
- Aチームの選手のみドラッグ操作を受け付け、ドラッグ中/後の座標を`update-position`イベントで
  親に通知する（自身では状態を持たない。表示専用コンポーネントの原則を維持）
- Bチームは固定表示のみ（ドラッグ不可）

**実装の要点**:
- 座標変換は「実座標(0-100) → SVG座標」の単純な線形マッピングとする
  （`MatchupPitchDiagram`のクラスタリング・列アンカー補間・衝突回避は使わない）。
  ピッチを横長のSVG（例: `viewBox="0 0 270 160"`）とし、
  - lateral（横幅方向）: `position.x`(0-100) を `cy`(10-150) へ線形マッピング
  - depth（深さ方向）: Aチームは`position.y`(0-100, 自陣0→敵陣100)を`cx`(0-130)へ、
    Bチームは同じ`y`を反転して`cx`(270-140=130-270)へマッピングする
    （中央=130でAとBの陣形が向き合う。既存の「非対称展開率」は自由配置モードでは採用しない
    ＝ドラッグでつまんだ位置と実座標を一致させることを優先する設計判断。要件のトレードオフ通り）
- ドラッグ実装: 選手の`<circle>`に`pointerdown`、SVGルートに`pointermove`/`pointerup`を
  バインドする。`pointerdown`時に`setPointerCapture`。`pointermove`で
  `svg.getScreenCTM()!.inverse()`を使いクライアント座標をSVG内部座標へ変換し、
  上記の線形マッピングの逆関数で0-100座標を求める
- クランプ: 逆算した`x`/`y`を`Math.min(100, Math.max(0, value))`でクランプしてから
  emitする（ピッチ外に出さない要件）
- 描画自体は`update-position`のemit後、親から新しい`formationA` propが降りてきて再描画される
  一方向データフローを維持する（コンポーネント内部にドラッグ座標のローカルstateを
  持たない。ドラッグ中の追従感のために、`pointermove`のたびにemitして親のrefを更新する
  形にする。頻度は`pointermove`のブラウザ既定間隔で許容範囲と判断）

### 3. `ComparisonPage.vue`（変更）

**責務**:
- 自由配置モードのON/OFFトグルUIとリセットボタンを追加する
- 一時的なAチーム配置状態(`freePositionsA`)を保持し、既存の`matchup`/`radarSeries`の
  算出を「自由配置中かどうか」で出し分ける

**実装の要点**:
- `freePositionsA`は`formationA`（route paramsから解決される静的Formation）とは
  完全に分離したrefとして持つ。トグルON時に`structuredClone(formationA.value.positions)`
  （またはスプレッドによる浅いコピー配列＋各Positionのスプレッド）で初期化する
- 以下のタイミングで`freePositionsA`を`null`に戻し、`isFreeLayoutMode`も`false`にする
  （既存の`watch(() => [formationA.value?.id, formationB.value?.id], ...)`と同じ監視対象に
  相乗りする形で実装する。組み合わせ切替時にシミュレーション結果をリセットしている
  既存の`watch`パターンを踏襲）:
  - 組み合わせ(A/BいずれかのID)が変わったとき
- リセットボタン押下時は、`isFreeLayoutMode`は維持したまま`freePositionsA`だけを
  元の`formationA.value.positions`のコピーで再初期化する
- `matchup`の算出を次のように分岐する（既存の`getMatchup`呼び出しは自由配置モードでない
  限り変更しない）:
  ```
  const effectiveMatchup = computed(() => {
    if (!formationA.value || !formationB.value) return undefined;
    if (!freePositionsA.value) return getMatchup(formationA.value.id, formationB.value.id);
    return generateMatchup({ ...formationA.value, positions: freePositionsA.value }, formationB.value);
  });
  ```
- `radarSeries`のAチーム側`values`を、`freePositionsA`がある場合は
  `estimateStats(getTags(effectiveFormationA.value), formationA.value.stats)` に差し替える
- テンプレート側は`isFreeLayoutMode`で`MatchupPitchDiagram`/`FreeLayoutPitchDiagram`を
  `v-if`/`v-else`で出し分ける。既存の対戦演出アニメーション（スライドイン等）は
  `MatchupPitchDiagram`側にのみ残し、`FreeLayoutPitchDiagram`はアニメーションを持たない
  （モード切替時に一度表示が切り替わることは要件の許容事項として明記済み）

## データフロー

### 自由配置モードでのドラッグ→再計算

```
1. 利用者が自由配置トグルをONにする
   → ComparisonPage: isFreeLayoutMode=true, freePositionsA=formationA.positionsのコピー
2. FreeLayoutPitchDiagramがformationA(=effectiveFormationA)を描画する
3. 利用者がAチームの選手をドラッグする
   → FreeLayoutPitchDiagramがpointermoveのたびに0-100座標へ逆変換し、
     クランプ後の座標で update-position(positionId, x, y) をemit
4. ComparisonPageがfreePositionsA内の該当Positionを更新する（新しい配列に差し替え、
   Vueのリアクティビティをトリガー）
5. effectiveFormationA / effectiveMatchup / effectiveStatsA が再計算される（computed）
6. FreeLayoutPitchDiagram・優位ポイント表示・レーダーチャートが新しい値で再描画される
```

### モードOFF・組み合わせ切替・リセット

```
- トグルOFF: freePositionsA=null, isFreeLayoutMode=false
  → 既存のMatchupPitchDiagram・静的matchup・静的statsの表示に戻る
- 組み合わせ切替(A/B入れ替え・切替): 既存watchに相乗りしfreePositionsA=null, isFreeLayoutMode=false
- リセットボタン: freePositionsA = formationA.positionsの新しいコピー（モードはONのまま）
```

## エラーハンドリング戦略

新規の例外的失敗ケースは想定しない（既存の「存在しないフォーメーションID」等のエラー
ハンドリングは`ComparisonPage`のv-if構造内でそのまま機能し、自由配置モードに影響されない）。
ドラッグでの座標はクランプにより常に有効な0-100範囲に収まるため、`deriveTags`/
`generateMatchup`/`estimateStats`に不正な座標が渡ることはない。

## テスト戦略

### ユニットテスト
- `radarScoreEstimator.test.ts`（新規）:
  - タグ変化が無い場合、`estimateStats(tags, baseStats)`が`baseStats`と完全一致すること
  - 特定タグの追加/削除で該当軸が期待通り増減すること
  - 複数タグが同一軸に影響する場合、クランプ(0-100)が正しく働くこと（下限・上限の境界値）
- `FreeLayoutPitchDiagram.vue`の単体テスト（新規）:
  - 座標(0-100)→SVG座標の変換とその逆変換が可逆であること（往復して元の値に戻ること）
  - ピッチ外へドラッグしたとき、emitされる値が0-100にクランプされていること
  - Bチームの選手にはドラッグハンドラが付与されない（`pointerdown`しても`update-position`が
    emitされない）こと

### 統合テスト
- `ComparisonPage.vue`のテスト（既存があれば拡張、無ければ新規）:
  - トグルONでAチームの座標を変更する操作をシミュレートし、優位ポイント・総合判定・
    レーダーチャートの表示が変化すること
  - トグルOFF、または組み合わせ切替で、変更内容が破棄され元の表示に戻ること
  - リセット操作で配置・タグ・判定・レーダーが初期状態に戻ること

## 依存ライブラリ

新規ライブラリの追加は不要（Pointer Events APIは標準DOM API、Vueの標準機能のみで実装する）。

## ディレクトリ構造

```
src/
├── components/
│   └── FreeLayoutPitchDiagram.vue   # 新規
├── data/
│   ├── radarScoreEstimator.ts       # 新規
│   └── radarScoreEstimator.test.ts  # 新規
└── pages/
    └── ComparisonPage.vue           # 変更
```

## 実装の順序

1. `radarScoreEstimator.ts`（純粋関数・タグ→スコア差分ロジック）とテストを先に実装する
   （UIに依存しない部分から着手し、ロジックの正しさを先に固める）
2. `FreeLayoutPitchDiagram.vue`（線形マッピング描画＋ドラッグ）とテストを実装する
3. `ComparisonPage.vue`にトグル・一時状態・出し分け・リセットボタンを実装する
4. 既存の`ComparisonPage`関連テスト（あれば）を自由配置モードのシナリオで拡張する
5. 手動確認（`npm run dev`でドラッグ操作・再計算・リセット・組み合わせ切替時の挙動を確認）

## セキュリティ考慮事項

該当なし（ユーザー入力はドラッグ操作のみで、外部送信・永続化を行わないため新規のリスクは
発生しない）。

## パフォーマンス考慮事項

- `pointermove`のたびにVueのcomputed再計算（`deriveTags`→`generateMatchup`→
  `estimateStats`）が走るが、8種のフォーメーション・数十件のルール走査程度の計算量であり、
  既存の`matchupGenerator`もインタラクティブな比較画面上で同程度の頻度を想定していないものの、
  実データ規模的に体感遅延が出るとは考えにくい。体感で問題が出た場合は`pointermove`の
  間引き（`requestAnimationFrame`単位への集約）を検討する余地を残す

## 将来の拡張性

- Bチームのドラッグ対応や、自由配置の座標を`localStorage`へ保存する拡張は、
  `freePositionsA`と同様のパターンを`freePositionsB`として追加する形で対応できる設計にしてある
- `extraTags`のドラッグ追従（座標に現れない手動タグの再評価）は本フェーズのスコープ外のまま
  据え置く
