# 画面詳細設計書: 陣形学習画面

> 画面一覧・ルート・対応コンポーネント・画面遷移の正本は
> [`functional-overview.md`](../../1_requirements/functional-overview.md)「画面設計」。レイアウト・画面項目・
> 画面イベントの外部設計は [`screen-design.md`](../../2_basic-design/screen-design.md)。本書は本画面の
> コンポーネント構成（props/state）・状態管理・詳細な画面遷移/イベント処理フロー・例外表示を記載する。

## 基本情報

| 項目 | 内容 |
|---|---|
| 画面名 | 陣形学習画面 |
| ルート(FE) | `/formations/:formationId/learn` |
| 対応コンポーネント | `FormationLearningPage` |
| 関連API | 該当なし（本プロダクトはバックエンドAPIを持たない） |
| 関連機能 | FR-20 |

外部設計（レイアウト・画面項目定義・画面イベント一覧）は
[`screen-design.md`](../../2_basic-design/screen-design.md)「画面7: 陣形学習画面」を参照。
本書は以下の実装レベル詳細に限定する。

## コンポーネント構成

```
FormationLearningPage
├── 「← 学習一覧へ」リンク（router-link。教材の有無にかかわらず表示）
├── PageHeader（タイトル・サブタイトル。戻るボタンなし）
├── 陣形切替ナビ（router-link × 陣形数）
├── 概要（FormationMiniPitch ＋ この陣形で学ぶこと）
├── 場面に登場する役割（攻撃側選手の一覧）
├── TacticalReplay（key = 陣形ID）
│   └── TacticalReplayPlayer（開いているときだけ描画）
│       └── TacticalReplayPitch
└── 用語説明（details。用語集へのリンクを含む）
```

### props / state 設計

| コンポーネント | props | 内部 state |
|---|---|---|
| `FormationLearningPage` | — | なし。`formationId`・`formation`・`lesson`・`lessonTerms` はルートパラメータから導出する `computed` |
| `TacticalReplay` | `scene: TacticalScene`, `description?: string`（`lesson.objective` を渡す） | `isOpen: boolean`（初期値 `false`）。開閉ボタンと内容の対応付けに `useId()` の ID を使う |
| `TacticalReplayPlayer` | `scene: TacticalScene` | `index: number`（現在の解説番号。初期値 0）、`progress: number`（次の解説へ移動する途中の割合 0〜1）、`isPlaying: boolean`、`shouldReduceMotion: boolean`（OS の「視差効果を減らす」設定）。`step`・`isLastStep`・`frame`（補間済み位置）は `computed` |
| `TacticalReplayPitch` | `scene`, `frame: ReplayFrame`, `step: ReplayStep`, `isMoving: boolean`, `isAtCheckpoint: boolean` | なし（表示専用） |

`computed` の導出:

| 名前 | 導出 |
|---|---|
| `formationId` | `route.params.formationId` が文字列ならその値、そうでなければ空文字 |
| `formation` | `getFormationById(formationId)` |
| `lesson` | `getFormationLesson(formationId)` |
| `lessonTerms` | 教材の目的・注意点・場面タイトル・各解説の見出し・説明・見るポイント・優位の条件を連結した文字列に、`term` が含まれる `soccerTerms` |

## 状態管理（クエリキー設計）

**該当なし**: 本画面はバックエンドAPIを呼ばず、静的データモジュール（`data/formations.ts`,
`data/formationLessons.ts`, `data/soccerTerms.ts`）を直接参照する。再生状態は
`TacticalReplayPlayer` の内部 state に閉じ、画面をまたいで保持しない（陣形切替・画面離脱で破棄する）。

## 画面遷移・イベント処理の詳細フロー

### 画面表示

1. ルートパラメータ `formationId` から `formation` と `lesson` を求める。どちらかが `undefined` なら、
   「← 学習一覧へ」リンクとエラー表示だけを描画する（「例外・エラー表示」参照）。
2. 見つかった場合、タイトル「{陣形名}を学ぶ」、陣形切替ナビ（表示中の陣形に `aria-current="page"`）、
   基本配置のミニピッチ、陣形の説明・教材の目的・注意点を表示する。
3. 役割一覧は `lesson.scene.players` のうち `team === "attack"` の選手を、
   「青{番号}：{役割}（基本配置の{ポジション名}）」で表示する。ポジション名は
   `formationPositionId` を `formation.positions` から引いて得る。
4. `TacticalReplay` を `key={formation.id}` で描画する。初期状態は閉じている。

### 陣形切替

1. 陣形切替ナビのリンクをクリックすると `router-link` で `/formations/:formationId/learn` へ遷移する。
2. 同じコンポーネントのままルートパラメータだけが変わるため、`formation`・`lesson`・`lessonTerms` が
   再計算される。
3. `TacticalReplay` は `key` が変わるため作り直され、開閉状態・再生状態が初期化される。
   再生中だった場合も、`TacticalReplayPlayer` の破棄時にタイマーを解除する。

### 戦術再生（TacticalReplay / TacticalReplayPlayer）

1. 「場面を見て学ぶ」をクリックすると `isOpen` を `true` にし、`TacticalReplayPlayer` を描画する。
   ボタンの文言は「教材を閉じる」に変わり、`aria-expanded` が `true` になる。自動再生はしない。
2. マウント時に `prefers-reduced-motion: reduce` を読み、`shouldReduceMotion` に反映する。
   設定の変更と、タブの表示状態（`visibilitychange`）を監視する。
3. 再生ボタンを押すと、32ms 間隔のタイマーで `progress` を
   `経過時間 / scene.durationMs` だけ進める。途中から再開した場合は、前回の `progress` に足し込む。
   `progress` が 1 に達したら次の解説へ移り（`go(index + 1)`）、タイマーを止める（要所での自動停止）。
4. 再生中にもう一度押すと一時停止する。位置（`progress`）は保持する。
5. 前の解説: 移動途中（`progress > 0`）なら現在の解説の始点へ戻し、そうでなければ1つ前の解説へ戻る。
   最初の解説の始点では `disabled`。
6. 次の解説: 1つ先の解説へ移る。最後の解説では `disabled`。最初から: 解説 0 へ戻る。
   いずれの操作も、再生中なら停止してから移る。
7. 最後の解説では、再生ボタンを `disabled` にし、文言を「再生完了」にする。
8. 動きを減らす設定のときは、再生ボタンでタイマーを使わず、次の解説へ静止画のまま進める
   （文言「次の静止画へ」）。設定が有効になったときは、移動途中（`progress > 0`。再生中・一時停止中を問わない）
   なら次の解説へ到着させて止め、そうでなければその場で止める。
9. タブが非表示になったら一時停止する。非表示の間は再生を開始しない。
10. ピッチ図は、到着時点（`progress === 0`）かつ停止中にだけ、走る道・パス・空間の強調を描く。
    `aria-label` は到着時点なら「{解説の見出し}。{見るポイント}」、移動途中なら
    「{解説の見出し}から次の解説へ移動途中のピッチ図」とする。
11. 解説パネル（`aria-live="polite"`）は、解説番号・状態（再生中／移動途中で一時停止／停止中）・
    見出し・優位の条件・説明・見るポイントを表示する。
12. 「教材を閉じる」をクリックすると `TacticalReplayPlayer` を破棄し、タイマーと監視を解除する。
    再度開くと解説 0 の初期状態から始まる。

### 画面遷移イベント

| 操作 | 遷移先 | 備考 |
|---|---|---|
| 「← 学習一覧へ」をクリック | `/learn`（`LearningListPage`） | `router-link` による静的遷移 |
| 陣形切替のリンクをクリック | `/formations/:formationId/learn` | 同一コンポーネントでパラメータのみ変わる |
| 「用語集ですべての言葉を見る →」をクリック | `/glossary`（`GlossaryPage`） | `router-link` による静的遷移 |

## 例外・エラー表示

- **不明な陣形ID（`formation` または `lesson` が `undefined`）**: 本文の代わりに `role="alert"` の
  エラー（見出し「陣形の教材が見つかりません」、本文「一覧から学びたいフォーメーションを選び直して
  ください。」）を表示する。「← 学習一覧へ」リンクは常に表示されるため、そこから復帰できる。
  再生中の陣形から不明IDへ遷移した場合も、`TacticalReplayPlayer` の破棄でタイマーは解除される。
- **教材に登場する登録用語が0件**: 用語説明の一覧は空になり、用語集へのリンクだけが残る
  （現在の教材では発生しない）。
- **`matchMedia` が使えない環境**: `shouldReduceMotion` を `false` として扱い、通常の再生にする。
