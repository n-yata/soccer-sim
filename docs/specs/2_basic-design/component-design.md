# コンポーネント設計（レイヤー別インターフェース詳細）

> 機能概要の一部。親・モジュール構成図（画面×静的データモジュール）の正本は
> `docs/specs/1_requirements/functional-overview.md`。本ファイルはコンポーネントごとの責務・
> インターフェース（擬似コード）・依存関係の詳細のみを置く。
> データモデルは functional-overview.md の「データモデル」を参照。

## UIレイヤー: FormationListPage（`pages/FormationListPage.vue`）

**責務**:
- フォーメーション一覧の表示（FR-01）
- 比較対象2件の選択状態の管理（FR-02）
- 2件選択された時点で比較画面（`/compare/:formationAId/:formationBId`）へ遷移する
- 相性マトリクス画面（`/matrix`）への導線を提供する（FR-07）
- 用語集画面（`/glossary`）への導線を提供する（FR-10）

**インターフェース**:
```typescript
interface FormationListPageState {
  // 選択中のフォーメーションID（最大2件）
  selectedIds: string[];
}

// カードクリック時のハンドラ。選択・選択解除を切り替える
function toggleSelection(id: string): void;

// selectedIds が2件になった時点で呼ばれる。比較画面へ router.push する
function navigateToComparison(): void;

// 「相性表を見る」ボタン押下時に呼ばれる。相性マトリクス画面へ router.push する
function goToMatrix(): void;
```

**依存関係**:
- 依存可能: `components/FormationCard.vue`, `data/formations.ts`（一覧取得）,
  `vue-router`（画面遷移）
- 依存禁止: `data/matchups.ts`（マッチアップ解説の参照は比較画面の責務）

## UIレイヤー: FormationCard（`components/FormationCard.vue`）

**責務**:
- フォーメーション1件の名称・説明文・ミニピッチ図（`FormationMiniPitch`）を表示する（FR-08）
- 選択状態の表示（オレンジの枠線・バッジ）とクリック・キーボード操作（Enter/Space）による
  `select` イベントのemitを行う

**インターフェース**:
```typescript
interface FormationCardProps {
  formation: Formation;
  selected: boolean;
}

interface FormationCardEmits {
  select: [id: string];
}
```

**依存関係**:
- 依存可能: `components/FormationMiniPitch.vue`, `types/formation.ts`
- 依存禁止: `pages/`, `data/`（コンポーネントは props 経由でデータを受け取る）

## UIレイヤー: FormationMiniPitch（`components/FormationMiniPitch.vue`）

**責務**:
- 1つのフォーメーション（`formation`）の全選手を、攻撃方向を上にした縦向きのミニピッチ図として
  SVGで描画する（FR-08）
- ピッチ座標系（左下原点・`y`が大きいほど攻撃方向）を、SVG座標系（左上原点・下方向が正）に
  `cy = 100 - y` で変換する
- `MatchupPitchDiagram`とは座標系・用途が異なる別コンポーネントとする（あちらは2チームを
  向き合わせる専用の座標ロジックを持ち、本コンポーネントは単独フォーメーションの配置を
  そのまま見せる用途のため、共通化すると双方の座標ロジックが読みにくくなる）
- カード内で小さく表示するため、ポジションラベルは描画せず点のみとする
- `label`（省略可）が無い場合は`aria-hidden="true"`を付与した装飾専用コンポーネントとする。
  カード（`FormationCard`）が名称・説明文というテキストで既にアクセシブルネームを持つため、
  ミニピッチ図に`role="img"`/`aria-label`を重ねると同じ内容が二重に読み上げられる
- `label`が渡された場合は`role="img"`と`:aria-label="label"`を付与し、読み上げ対象にする。
  クイズの陣形識別設問（FR-12、`QuizQuestionCard`）では図そのものが設問の内容であり、
  装飾扱いのままだと支援技術で解答できないため、呼び出し側が具体的なラベルを与える

**インターフェース**:
```typescript
interface FormationMiniPitchProps {
  formation: Formation;
  label?: string; // 省略時は装飾（aria-hidden）。指定時は role="img" + aria-label
}
```

**依存関係**:
- 依存可能: `types/formation.ts`
- 依存禁止: `data/`（表示専用コンポーネント）

## UIレイヤー: ComparisonPage（`pages/ComparisonPage.vue`）

**責務**:
- ルートパラメータ（`formationAId`, `formationBId`）から対象フォーメーションとマッチアップ解説を取得する
- `MatchupPitchDiagram` に `formationA`/`formationB` を渡し、1つのピッチ図上に両チームの
  選手を重ねて表示する（FR-03）
- 各フォーメーションの優位ポイント（`matchup.advantagesForA`/`advantagesForB`）を、フォーメーション名を
  見出しにした箇条書きで表示する（FR-04）。**テキスト補間（`{{ }}`）で表示し、`v-html` は
  使わない**（現状は静的データのみで外部入力は無いが、将来解説文を外部化した場合のXSS事故を
  設計時点で予防する）
- 優位ポイント・総合判定理由（`matchup.overallReason`）は`TermAnnotatedText`経由で表示し、
  含まれるサッカー用語をその場で確認できるようにする（FR-11）
- 表示できた組み合わせ（`formationA.id`/`formationB.id`）を、確定した時点で
  `data/learningProgress.ts`の`markPairViewed`へ渡して学習進捗として記録する（FR-13）。
  監視対象はIDの組（`matchup`オブジェクトの参照差では発火しない）とし、A/B入れ替え・切替
  （FR-09。`router.replace`による同一コンポーネント内のパラメータ変更）でも記録する
- `matchup.overallEdge`/`overallReason` を元に、「どちらが有利か」の総合判定を優位ポイントの
  箇条書きより上（凡例の下）に一言見出しで表示する（優位ポイントの箇条書きだけでは結局どちらが
  有利なのか読み取りにくいというフィードバックを受けて追加）
- `formationA.stats`/`formationB.stats` を `RadarChart` の `series` props として組み立て、
  ピッチ図の右側に横並びでレーダーチャートを表示する（FR-05。優位ポイントの箇条書きとは
  併存させる。狭い画面幅では自動的に縦積みに折り返す）
- 画面表示時にピッチ図のスライドイン→総合判定のポップインの順でCSSアニメーションを
  再生する（FR-06。`prefers-reduced-motion: reduce`時は無効化する）
- 存在しないフォーメーションID、または同一フォーメーション同士のIDの場合、エラー表示と
  一覧画面への導線を出す
- A/Bの入れ替え、およびA側・B側フォーメーションの切替を行う（FR-09）。UIは
  `ComparisonControls` に委譲し、そこから受け取る `swap`/`select-a`/`select-b` イベントを
  `router.replace` による画面遷移に変換する（ルーティングの責務は`pages/`側に残す）
- 用語集画面（`/glossary`）への導線を提供する（FR-10）

**インターフェース**:
```typescript
interface ComparisonPageRouteParams {
  formationAId: string;
  formationBId: string;
}

// data/formations.ts, data/matchups.ts から取得したデータを保持する算出プロパティ
interface ComparisonPageState {
  formationA: Formation | undefined;
  formationB: Formation | undefined;
  // matchup は formationA/B が両方検出できた場合のみ算出する。同一フォーメーション同士の
  // IDが指定された場合はここが undefined になる（functional-overview.md「エラーハンドリング」
  // 参照）。3つのうちいずれかが undefined ならエラー表示に切り替える。
  // matchup.advantagesForA/advantagesForB は、それぞれ formationA/formationB の優位ポイント
  // （getMatchupが呼び出し順序に正規化済みのため、入れ替えを意識する必要はない）。
  matchup: Matchup | undefined;
}

// ComparisonControlsのswapイベントハンドラ。router.replaceで
// /compare/:formationB/:formationAへ遷移する（履歴を積まない）
function swap(): void;

// ComparisonControlsのselect-a/select-bイベントハンドラ。選択されたIDと
// 現在の相手側IDでrouter.replaceする
function onSelectA(id: string): void;
function onSelectB(id: string): void;
```

**依存関係**:
- 依存可能: `data/formations.ts`, `data/matchups.ts`, `data/radarAxes.ts`,
  `data/learningProgress.ts`, `components/ComparisonControls.vue`,
  `components/MatchupPitchDiagram.vue`, `components/RadarChart.vue`,
  `components/TermAnnotatedText.vue`, `vue-router`
- 依存禁止: なし

## UIレイヤー: ComparisonControls（`components/ComparisonControls.vue`）

**責務**:
- 比較画面のA/B入れ替えボタンと、A側・B側それぞれのフォーメーション切替セレクトを
  表示する（FR-09）
- 相手側に選択中のフォーメーションIDと一致する `<option>` を `disabled` にし、UI操作で
  同一フォーメーション同士の組み合わせを発生させない
- ルーティングは行わない。ボタン操作・セレクト変更をそれぞれ `swap`/`select-a`/`select-b`
  イベントとしてemitするだけの表示専用コンポーネント（`ComparisonPage.vue:418行`が
  コンポーネント250行の目安を超えていたため、A/B選択UIを独立した責務として切り出した）

**インターフェース**:
```typescript
interface ComparisonControlsProps {
  formations: Formation[];
  formationAId: string;
  formationBId: string;
}

interface ComparisonControlsEmits {
  swap: [];
  "select-a": [id: string];
  "select-b": [id: string];
}
```

**依存関係**:
- 依存可能: `types/formation.ts`
- 依存禁止: `pages/`, `data/`（コンポーネントは props 経由でデータを受け取る）

## UIレイヤー: MatchupPitchDiagram（`components/MatchupPitchDiagram.vue`）

**責務**:
- `formationA`/`formationB` の2つのフォーメーション全選手を、1つのピッチ図上に重ねて
  描画する（ポジションごとに円+ラベル、青=A、赤=B）
- GK/DF/MF/FWの深さ（横軸）は、青チームと赤チームで独立した列位置を持つ（`colXByTeam`）。
  青はGK（画面左端）から右へ、赤はGK（画面右端）から左へ展開するが、その展開率を
  非対称にすることで、青の攻撃陣（FW）が赤の守備陣（DF）に、赤の攻撃陣（FW）が青の
  守備陣（DF）に近づく、「両チームが向き合って対戦している」配置を表現する。GK同士は
  最も離れ、中盤（MF）同士は中央付近で最も近くなる
- 各列（DF/MF/FW）の中では、自チームの選手を幅方向の元のx座標でソートし均等配置する
  ことで、「DFラインが一列に並ぶ」といった陣形本来の形（滑らかなライン）を保つ
- GKは、自チームのDFラインの中で最も中央（x=50）に近い選手と同じ高さに配置する
  （同着の場合はそれらの平均）。これにより敵チームの選手がGKの正面に来る回帰を防ぐ
- チームA/Bの選手をそれぞれ専用の`<g>`にグルーピングし、画面表示時にチームAが左から、
  チームBが右からスライドインするCSSアニメーションを再生する（FR-06。座標計算ロジック
  自体には影響しない見た目のみの演出）

**インターフェース**:
```typescript
interface MatchupPitchDiagramProps {
  formationA: Formation;
  formationB: Formation;
}
```

**依存関係**:
- 依存可能: `types/formation.ts`
- 依存禁止: `data/`（データモジュールを直接インポートしない。呼び出し元から props 経由で
  データを受け取る表示専用コンポーネントとする）

## UIレイヤー: RadarChart（`components/RadarChart.vue`）

**責務**:
- 軸メタデータ（`RadarAxisMeta[]`）と最大1〜複数系列のスコアデータを受け取り、SVGで
  レーダーチャートを描画する（FR-05）
- 軸の並び順に従い、中心から等角度で軸線・25/50/75/100%の同心多角形（目盛り）・軸ラベルを描画する
- 各系列（`series`）ごとに、各軸のスコアを`maxValue`で正規化した頂点を結ぶ`<polygon>`と
  頂点`<circle>`を描画する。色は呼び出し元から`colorVar`（CSS変数名）として受け取り、
  チーム配色（`--color-team-a`/`--color-team-b`）を再利用する
- 軸数・系列数に依存しない汎用実装とする（フォーメーション・軸の追加時にこのコンポーネント自体の
  変更は不要）
- `series`の値が変化した際、頂点をその場で瞬時にジャンプさせず、`requestAnimationFrame`で
  300ms かけて旧値から新値へ補間する（2026-09-26追加。UI/UXアップグレード第2弾）。
  SVGの`<polygon>`の`points`属性はCSS transitionの対象外のため、JS側での座標補間を採る。
  ただし以下の場合は補間せず即座に確定させる:
  - 系列数・軸数・軸の並び順が変わった場合（補間の対応が取れないため）
  - `prefers-reduced-motion: reduce`が有効な場合
  - 直前の変化から120ms未満で連続して値が変化した場合（自由配置モードのドラッグ中は
    `pointermove`のたびに値が変わるため、都度補間をやり直すと指の動きに対して常に
    遅れ続ける「追従負け」が起きる。連続変化は補間せず即座に反映し、指の動きに
    そのまま追従させる）

**インターフェース**:
```typescript
interface RadarChartProps {
  axes: readonly RadarAxisMeta[]; // radarAxes.ts の readonly 配列をそのまま渡せる
  maxValue: number;
  series: { label: string; colorVar: string; values: FormationStats }[];
}
```

**依存関係**:
- 依存可能: `types/formation.ts`（`FormationStats`型）, `data/radarAxes.ts`（`RadarAxisMeta`型）
- 依存禁止: `data/formations.ts`, `data/matchups.ts`（`MatchupPitchDiagram`と同様、表示専用
  コンポーネントとしデータモジュールを直接インポートしない）

## UIレイヤー: MatrixPage（`pages/MatrixPage.vue`）

**責務**:
- 全フォーメーションを行・列に並べたN×Nの表を表示し、`getMatchup`の結果（`overallEdge`）に
  応じて行有利/列有利/互角の色分けをする（FR-07）
- 対角線（同一フォーメーション同士）はクリック不可のセルとして視覚的に区別する
- マッチアップが存在しないセル（データ追加漏れ）は「データ未定義」として独立した状態で表示する
  （`resolveEdge`が`undefined`を返すケース。互角と区別する）
- セルをクリックすると対応する比較画面へ遷移する
- `data/learningProgress.ts`から読み込んだ進捗を元に、確認済みの組み合わせのセルへチェック印を
  付け、`aria-label`にも確認済みか否かを含める（FR-13）。チェック印は**色以外の手段**であり、
  既存の行有利/列有利/互角の色分けに重ねても意味が判別できるようにする
- 「確認済み N / 全 M 組み合わせ」を数値で表示する（Mは`countAllPairs`でフォーメーション件数
  から算出し、コードに固定しない）
- 進捗の消去操作を提供する。`window.confirm`は使わず、ボタン押下→インライン確認→確定の
  2段階UIとする（ブラウザのネイティブダイアログは自動テスト・ブラウザ自動操作を止めるため）

**インターフェース**:
```typescript
// 進捗はマウント時に一度読み、消去操作でのみ更新する（描画のたびにlocalStorageを読まない）
interface MatrixPageState {
  progress: LearningProgress;
  isConfirmingClear: boolean;
}

function isViewed(rowId: string, colId: string): boolean;
function onClearProgress(): void; // clearProgress()を呼び、progressを更新する
```

**依存関係**:
- 依存可能: `data/formations.ts`, `data/matchups.ts`, `data/learningProgress.ts`, `vue-router`
- 依存禁止: なし

## UIレイヤー: GlossaryPage（`pages/GlossaryPage.vue`）

**責務**:
- サッカー用語（`data/soccerTerms.ts`）をカテゴリ別にグルーピングし、定義リストで表示する（FR-10）
- 一覧画面（`/`）への導線を提供する

**インターフェース**:
```typescript
// カテゴリ表示順を固定するための定数（データ配列の登場順に依存しない）
const categoryOrder: SoccerTermCategory[];
```

**依存関係**:
- 依存可能: `data/soccerTerms.ts`, `types/formation.ts`, `vue-router`（一覧画面への遷移）
- 依存禁止: なし

## UIレイヤー: TermAnnotatedText（`components/TermAnnotatedText.vue`）

**責務**:
- 表示するテキスト（`text`）を`data/termAnnotation.ts`の`annotateText`で「平文/用語」に
  切り出し、用語をボタンとして描画する（FR-11）。**セグメント配列を`v-for`+`{{ }}`で
  組み立て、`v-html`は使わない**（用語データにHTMLが混入しても描画されない）
- 用語ボタンの押下で対応する`TermPopover`を開閉する。開閉状態は自身のローカル状態として持つ
  （画面に複数配置されるため、開くのは押下したボタンのポップオーバーのみ。`aria-expanded`/
  `aria-describedby`で状態を伝える）
- `Escape`キー、本文外のクリック、同じ用語の再押下、別の用語の押下のいずれでも閉じる
  （同時に開くポップオーバーは1つ）
- `text` propsが差し替わったら開いているポップオーバーを閉じる（FR-09のA/B入れ替え・切替で
  開いたインデックスが別の用語を指してしまうのを防ぐ）

**インターフェース**:
```typescript
interface TermAnnotatedTextProps {
  text: string;
}
```

**依存関係**:
- 依存可能: `types/formation.ts`, `data/termAnnotation.ts`（副作用を持たない純粋関数。
  詳細は`repository-structure.md`「components/の依存関係」の例外規定を参照）,
  `components/TermPopover.vue`
- 依存禁止: `pages/`, `data/`配下の静的データ定義・副作用を持つモジュール

## UIレイヤー: TermPopover（`components/TermPopover.vue`）

**責務**:
- サッカー用語1件（`term`）の用語・読み方・説明を吹き出し表示する表示専用コンポーネント
- `role="tooltip"`を付与し、呼び出し元（`TermAnnotatedText`）が`aria-describedby`で
  参照できるよう一意な`id`をpropsで受け取る

**インターフェース**:
```typescript
interface TermPopoverProps {
  id: string;
  term: SoccerTerm;
}
```

**依存関係**:
- 依存可能: `types/formation.ts`
- 依存禁止: `pages/`, `data/`（コンポーネントは props 経由でデータを受け取る）

## UIレイヤー: QuizQuestionCard（`components/QuizQuestionCard.vue`）

**責務**:
- クイズの設問1問（`question`）と回答状態（`answeredChoiceId`）をpropsで受け取り、
  選択肢を表示する（FR-12）
- 選択肢の押下で`answer`イベント（選択した`choiceId`）をemitする。ルーティング・状態管理は
  行わない（呼び出し元の`QuizPage`が担う）
- `answeredChoiceId`が非nullのとき（回答確定後）は全選択肢を`disabled`にし、正解の選択肢を
  示しつつ正誤・解説を表示する。正誤は**色だけで示さない**（○/×の記号と読み上げ用テキストを
  併用する）
- `question.kind === "formation"`のとき、`question.formation`を`FormationMiniPitch`へ
  `label`付きで渡す。図そのものが設問内容のため、装飾扱い（`aria-hidden`）にしない
- 解説文（`question.explanation`）・設問文（`question.prompt`）は`TermAnnotatedText`経由で
  表示し、含まれる用語をその場で確認できるようにする（FR-11との整合）

**インターフェース**:
```typescript
interface QuizQuestionCardProps {
  question: QuizQuestion;
  answeredChoiceId: string | null;
}

interface QuizQuestionCardEmits {
  answer: [choiceId: string];
}
```

**依存関係**:
- 依存可能: `types/formation.ts`, `components/FormationMiniPitch.vue`,
  `components/TermAnnotatedText.vue`
- 依存禁止: `pages/`, `data/`（コンポーネントは props 経由でデータを受け取る。
  設問の生成は`QuizPage`が`data/quiz.ts`を呼んで行う）

## UIレイヤー: QuizPage（`pages/QuizPage.vue`）

**責務**:
- `data/quiz.ts`の`buildQuiz`で設問一覧を生成し、1問ずつ`QuizQuestionCard`へ渡して
  出題を進行する（FR-12）
- 設問idをキーに回答を保持する（配列のindexではなくidで持つことで、再挑戦で出題順が
  変わっても前回の回答が混ざらない）
- 全問終了後に正答数と結果を表示する
- 「もう一度挑戦する」で、設問一覧・現在位置・回答状態のすべてを作り直す（個別フィールドを
  消すのではなく状態オブジェクトごと作り直すことで、消し忘れによる持ち越しを防ぐ）
- `buildQuiz`が空配列を返した場合（出題できる設問が無い）、クラッシュせずその旨を表示する
- 一覧画面への「戻る」、用語集画面への導線を提供する

**インターフェース**:
```typescript
interface QuizPageState {
  questions: QuizQuestion[];
  currentIndex: number;
  // 設問id -> 選んだ選択肢id
  answers: Record<string, string>;
}

function onAnswer(choiceId: string): void; // 1問につき最初の回答のみ確定する
function goNext(): void;
function restart(): void; // questions/currentIndex/answersをすべて作り直す
```

**依存関係**:
- 依存可能: `data/formations.ts`, `data/matchups.ts`, `data/quiz.ts`,
  `components/QuizQuestionCard.vue`, `vue-router`
- 依存禁止: なし

## UIレイヤー: App（`App.vue`）

**責務**:
- ルートコンポーネント。全画面共通の`AppHeader`を配置し、`<router-view />`で各画面を描画する
- カップ戦導線の出し分け（`formations.length === CUP_REQUIRED_FORMATION_COUNT`）を判定し、
  `AppHeader`へ`showCupLink` propとして渡す。`components/`は`data/`配下の静的データ定義に
  直接依存できないため（後述`AppHeader`の依存関係）、判定は呼び出し元である`App.vue`が担う

**インターフェース**:
```typescript
// App.vue が data/formations.ts から算出して AppHeader へ渡す
const showCupLink: ComputedRef<boolean>;
```

**依存関係**:
- 依存可能: `data/formations.ts`（`CUP_REQUIRED_FORMATION_COUNT`・件数判定）,
  `components/AppHeader.vue`
- 依存禁止: なし（ルートコンポーネントは`pages/`の親であり、レイヤー制約の対象外）

## UIレイヤー: AppHeader（`components/AppHeader.vue`）

**責務**:
- 全画面共通のグローバルナビゲーション。一覧・相性表・リーグ戦・カップ戦・理解度チェック・
  用語集への遷移導線を常時提供する
- 現在のルート名（`useRoute().name`）と一致するナビ項目に`aria-current="page"`を付与する
- モバイル幅（640px以下）ではハンバーガーボタンでナビをたたむ。ナビ項目のクリックで開閉状態を
  閉じる（`closeMenu`）
- カップ戦導線は`showCupLink` propsが`true`のときのみ表示する（判定はApp.vueが担う。下記
  「依存関係」参照）

**インターフェース**:
```typescript
interface AppHeaderProps {
  showCupLink: boolean;
}
```

**依存関係**:
- 依存可能: `vue-router`（`useRoute`。現在地判定のため画面遷移は行わない）
- 依存禁止: `pages/`, `data/`配下の静的データ定義（`formations.ts`等）。カップ戦導線の
  出し分けに必要な`formations.length`はコンポーネントが自ら参照せず、呼び出し元（`App.vue`）が
  propsとして渡す（`repository-structure.md`「components/の依存関係」原則に従う）

## UIレイヤー: PageHeader（`components/PageHeader.vue`）

**責務**:
- グラデーション背景のページヘッダー（タイトル・サブタイトル）を表示する共通コンポーネント
  （`FormationListPage`/`GlossaryPage`で個別実装されていたグラデーションヘッダーを統合した）
- デフォルトスロットで、タイトル行右側のアクション領域（ボタン・リンク群）を差し込めるようにする

**インターフェース**:
```typescript
interface PageHeaderProps {
  title: string;
  subtitle?: string;
}
```

**依存関係**:
- 依存可能: なし
- 依存禁止: `pages/`, `data/`（コンポーネントはpropsとスロット経由でのみ内容を受け取る）

## UIレイヤー: BackButton（`components/BackButton.vue`）

**責務**:
- 「← 戻る」ボタンの表示と、押下時の戻り先解決を1箇所に集約する（`MatrixPage`/`QuizPage`/
  `LeaguePage`/`CupPage`/`ComparisonPage`で同一ロジックが重複していたものを統合した）
- `window.history.state?.back`の有無を判定し、アプリ内遷移の履歴があれば`router.back()`、
  無ければ`fallbackTo`（既定`"/"`）へ`router.push()`する

**インターフェース**:
```typescript
interface BackButtonProps {
  fallbackTo?: string; // 既定値: "/"
}
```

**依存関係**:
- 依存可能: `vue-router`（`useRouter`）
- 依存禁止: `pages/`, `data/`

## データレイヤー: termAnnotation / quiz（`data/termAnnotation.ts`, `data/quiz.ts`）

**責務**:
- `termAnnotation.ts`: 解説文を「平文/用語」の区間へ切り出す純粋関数`annotateText`を提供する。
  用語が部分的に重なる場合は**最長一致**で切り出す（短い用語を先に採ると、本文が別の意味の
  用語へ静かに化けるため）。長さ降順のインデックスは呼び出しのたびに作り直さず、引数の配列
  参照をキーにキャッシュする
- `quiz.ts`: `formations`/`matchups`から3種類のクイズ設問（優劣判定・陣形識別・優位ポイント
  帰属）を生成する純粋関数`buildQuiz`を提供する。設問数は対象データから導かれ、コードに
  固定しない（NFR-03）。並べ替え（`shuffle`）は差し替え可能にし、既定は`Math.random`
  ベース、テストでは決定的な関数を渡す（本番コードにテスト用の分岐を入れない）
- どちらも**副作用を持たない**。データを保持・取得するのではなく、渡された値を加工して返す
  だけであるため、`components/`からの直接依存を例外的に許可している
  （`repository-structure.md`「components/の依存関係」参照）

**インターフェース**:
```typescript
// data/termAnnotation.ts
export function annotateText(text: string, terms?: readonly SoccerTerm[]): TextSegment[];

// data/quiz.ts
export const DEFAULT_QUIZ_LENGTH: number;
export const defaultShuffle: Shuffle;
export function buildQuiz(
  formations: readonly Formation[],
  matchups: readonly Matchup[],
  options?: { shuffle?: Shuffle; limit?: number },
): QuizQuestion[];
```

**依存関係**: `types/formation.ts` のみ（外部依存なし）。`termAnnotation.ts`は
`data/soccerTerms.ts`を既定値として参照する。

## データレイヤー: learningProgress（`data/learningProgress.ts`）

**責務**:
- 学習進捗（確認済みの組み合わせ）を`localStorage`へ読み書きする。`data/`配下で唯一
  副作用を持つモジュール（FR-13）
- フォーメーション2件の組み合わせを、順序に依存しないキーへ正規化する
  （`[idA, idB].sort().join("__")`。順序違いでの二重計上を防ぐ）
- 読み込み時に保存値の形式を検証する。`viewedPairs`が文字列配列であることを確認し、
  1つでも満たさなければ空の進捗として扱う（`localStorage`の中身は利用者が自由に書き換え
  られるため、信用して描画しない）。重複したキーも読み込み時に取り除く
- 読み込み・書き込み・削除のすべてを`try/catch`で囲み、`localStorage`が使えない環境
  （プライベートモード・容量超過等）でも例外を外へ伝播させない。記録できないだけで、
  他の機能は従来どおり動作する

**インターフェース**:
```typescript
export function buildPairKey(idA: string, idB: string): string;
export function countAllPairs(formations: readonly Formation[]): number;
export function loadProgress(): LearningProgress;
export function markPairViewed(idA: string, idB: string): LearningProgress;
export function isPairViewed(progress: LearningProgress, idA: string, idB: string): boolean;
export function clearProgress(): LearningProgress;
```

**依存関係**: `types/formation.ts` のみ（外部依存なし）。呼び出し元は`pages/ComparisonPage.vue`
（記録）と`pages/MatrixPage.vue`（読み取り・消去）に限る。`components/`からは呼ばない
（`repository-structure.md`「components/の依存関係」参照）。

## データレイヤー: formations / matchups / radarAxes / soccerTerms（`data/formations.ts`, `data/matchups.ts`, `data/radarAxes.ts`, `data/soccerTerms.ts`）

**責務**:
- フォーメーション定義（レーダーチャート用の`stats`5軸を含む）・マッチアップ解説文・
  レーダー軸メタデータ・サッカー用語定義を型付きの静的データとして提供する
- IDによる検索関数を提供する

**インターフェース**:
```typescript
// data/formations.ts
export const formations: Formation[]; // 各要素は stats: FormationStats を含む
export function getFormationById(id: string): Formation | undefined;
// カップ戦（8フォーメーション固定のノックアウト方式）の導線出し分けに使う閾値。
// App.vue（AppHeaderへのprops）とFormationListPage.vueの双方が参照し、値の二重定義を避ける
export const CUP_REQUIRED_FORMATION_COUNT: number;

// data/matchups.ts
export const matchups: Matchup[];
// フォーメーションAとBの順序に依存せず、同一のマッチアップを返す。
// レコードの格納順序と呼び出し順序が逆の場合は、advantagesForA/BとoverallEdge(A/B)を
// 入れ替えて返す（呼び出し側は常に「戻り値の formationAId = 呼び出し時の formationAId」を
// 前提にできる）。overallEdgeが"even"の場合は入れ替えても変化しない。
export function getMatchup(formationAId: string, formationBId: string): Matchup | undefined;

// data/radarAxes.ts
export interface RadarAxisMeta {
  id: RadarAxisId;
  label: string;
  description: string;
}
export const radarAxes: readonly RadarAxisMeta[]; // 表示順もこの配列順に従う

// data/soccerTerms.ts
export const soccerTerms: SoccerTerm[]; // matchups.ts等の実文言から抽出した用語のみ収録する
```

**依存関係**: `types/formation.ts` のみ（外部依存なし）。

> このレイヤーは外部依存を持たない純粋なデータ・関数のみで構成される。UIレイヤーへの依存も
> 無いため、`getFormationById` / `getMatchup` は単体テストの対象として最もテストしやすい層である
> （`requirements-definition.md` §5 NFR-03「保守性」に対応）。
