# 設計書

## アーキテクチャ概要

既存の2画面とルート定義に小さく手を入れる。新しいモジュール・依存は増やさない。

```
FormationLearningPage ──router-link /board?blue={id}──> router（props: query.blue → initialBlueFormationId）
                                                              └──> FreeLayoutBoardPage（props で初期の青陣形を受け取る）
```

## コンポーネント設計

### 1. ルート定義（`src/router/index.ts`）

**責務**: `/board` のクエリ `blue` を、ボード画面の props `initialBlueFormationId` に変換する。

**実装の要点**:
- `props: (route) => ({ initialBlueFormationId: typeof route.query.blue === "string" ? route.query.blue : undefined })`。
  クエリが配列（`?blue=a&blue=b`）や null の場合は `undefined` にする（URL は利用者が自由に書き換えられるため、型を絞ってから渡す）。
- 陣形 ID が実在するかの判定はボード画面側で行う（ルート定義は型の変換だけを担う）。

### 2. FreeLayoutBoardPage

**責務**: props `initialBlueFormationId?: string` を受け取り、青チームの初期陣形を決める。

**実装の要点**:
- `formations.find((f) => f.id === initialBlueFormationId) ?? formations[0]` を青の初期陣形にし、従来どおり
  `restoreFormation("A", …)` で保存配置を適用する。実在しない ID・空文字・未指定はすべて `formations[0]` に倒す。
- 初期化はマウント時の1回だけ。props の変化には追従しない（ボード上の操作中にクエリで上書きしないため）。
  ボード表示中に主ナビで `/board` へ移る（または戻る・進むで `/board?blue=X` と `/board` を行き来する）と、同じ
  ルートなので画面は使い回され、青の陣形は変わらない。これを仕様とする（コミット前レビュー第1回の Medium を受けて、
  当初の「同じ画面でクエリだけ変わる遷移は無い」という誤った前提を訂正）。
- vue-router には依存しない（既存テストが router 無しでマウントしている前提を保つ）。

### 3. FormationLearningPage

**責務**: 学習中の陣形でボードを開く導線を2か所に置く。

**実装の要点**:
- `router-link` の `:to="{ path: '/board', query: { blue: formation.id } }"`、文言「この陣形をボードで試す →」。
- 位置: 概要欄の基本配置ミニピッチ（キャプション）の下、`TacticalReplay` の直後。どちらも `formation && lesson` の
  ブロック内に置くため、不明な陣形 ID では出ない。
- スタイルは既存のテキストリンク（`color: var(--color-primary)`・`min-height: 44px`・`inline-flex`）に合わせる。

## データフロー

1. 学習画面で「この陣形をボードで試す →」をクリック → `/board?blue=4-3-3`
2. ルート定義の props 関数が `initialBlueFormationId: "4-3-3"` を渡す
3. ボード画面が 4-3-3 を青の初期陣形にし、保存配置 `A:4-3-3` があれば適用して表示

## エラーハンドリング戦略

- 不正なクエリ（未指定・空・配列・実在しない ID）は既定へ倒し、エラー表示はしない（クエリは利用者が編集できる入力のため、
  信用せずに実在する陣形 ID だけを採用する）。

## テスト戦略

### ユニットテスト
- ルート定義: `router.resolve` した `/board?blue=...` に props 関数を適用し、文字列・未指定・配列で期待どおりの値になる
  （ルート定義専用のテストファイルは作らず、`FreeLayoutBoardPage.test.ts` 内に置く）
- ボード表示中に `/board?blue=3-5-2` から `/board` へ遷移しても、青が 3-5-2 のまま（実ルート定義）
- FreeLayoutBoardPage: props の有無・実在/非実在 ID・空文字で青の陣形が決まる。保存配置の復元。赤とボールが変わらない
- FormationLearningPage: 2か所の導線のリンク先（全8陣形）、不明 ID で導線が無い、実ルーターでクリックしてボードが学習中の陣形で開く

### 回帰
- `wireframeConsistency.test.ts`（wireframe とルート・主ナビの一致）、既存のボード・学習画面のテスト

## 依存ライブラリ

追加なし。

## ディレクトリ構造

```
src/router/index.ts                     （/board に props 関数）
src/pages/FreeLayoutBoardPage.vue       （props initialBlueFormationId）
src/pages/FormationLearningPage.vue     （導線2か所）
src/pages/FreeLayoutBoardPage.test.ts / src/pages/FormationLearningPage.test.ts（テスト追加）
docs/specs/...                          （requirements.md の「ドキュメントの同時更新」参照）
```

## 実装の順序

1. ルート定義とボード画面（props）→ テスト
2. 学習画面の導線 → テスト（実ルーターでの遷移を含む）
3. ドキュメント（機能概要 → wireframe → 画面設計 → コンポーネント設計 → 詳細設計 → テスト仕様）
4. 検証・レビュー・振り返り

## セキュリティ考慮事項

- クエリは利用者が自由に書き換えられる入力。値は描画に直接使わず、`formations` に実在する ID との完全一致だけで採用する
  （任意文字列が表示や保存キーに流れ込まない）。

## パフォーマンス考慮事項

- `formations`（8件）の線形探索1回のみ。
